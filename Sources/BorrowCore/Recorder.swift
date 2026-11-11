import AppKit
import Foundation

@MainActor
public final class Recorder {
    public var cancelled = false
    private var record: RunRecord
    private let directory: URL
    private var observers: [NSObjectProtocol] = []
    private let leaseFactory: @MainActor (WakeMode, UUID, Date) -> any WakeLeaseControlling
    private let saveRecord: (RunRecord, URL) throws -> Void

    public init(record: RunRecord, directory: URL,
                leaseFactory: @escaping @MainActor (WakeMode, UUID, Date) -> any WakeLeaseControlling = {
                    SystemWakeLease(mode: $0, runID: $1, deadline: $2)
                },
                saveRecord: @escaping (RunRecord, URL) throws -> Void = RecordingStore.save) {
        self.record = record; self.directory = directory
        self.leaseFactory = leaseFactory; self.saveRecord = saveRecord
    }

    public func run(executable: URL, arguments: [String], proofURL: URL? = nil) async throws -> RunRecord {
        try await capture(executable: executable, arguments: arguments, proofURL: proofURL)
    }

    public func observeCodex(sessionURL: URL) async throws -> RunRecord {
        try await capture(sessionURL: sessionURL)
    }

    private func capture(executable: URL? = nil, arguments: [String] = [], proofURL: URL? = nil,
                         sessionURL: URL? = nil) async throws -> RunRecord {
        let agentReader: CodexLogReader?
        do { agentReader = try sessionURL.map { try CodexLogReader(url: $0) } }
        catch { throw RecorderError.sourceUnavailable }
        var lease: (any WakeLeaseControlling)?
        var cleanupFinished = false
        defer { if !cleanupFinished { lease?.releaseFallback() } }
        do {
            if let agentReader {
                record.agent = AgentEvidence()
                record.agent?.streamIncomplete = agentReader.historyIncomplete
                record.events.append(RunEvent("agentAttached", "Attached to the selected Codex log at its current end. Historical activity is excluded; conversation and tool content are discarded."))
            }
            record.recorderPID = ProcessInfo.processInfo.processIdentifier
            record.events.append(RunEvent("started", record.power == nil
                ? "Recorder started. No sleep overrides or wake assertions requested."
                : "Recorder started. A bounded Borrow-owned wake hold was explicitly requested; no global power settings changed."))
            try saveRecord(record, directory)
            let deadline = record.startedAt.addingTimeInterval(TimeInterval(record.plannedSeconds + (record.kind == .rehearsal ? 15 : 0)))
            if cancelled || Date() >= deadline {
                record.status = cancelled ? .cancelled : .timedOut
                record.endedAt = Date()
                record.events.append(cancelled
                    ? RunEvent("cancelled", "Recording stopped before a wake hold or foreground task was created. An external agent was left untouched.")
                    : RunEvent("timeout", "The recording limit passed during setup. No wake hold or foreground task was created; an external agent was left untouched."))
                if record.power != nil {
                    record.power?.cleanup = .nothingHeld
                    record.events.append(RunEvent("wakeNothingHeld", "No Borrow-owned hold was created, so there was nothing to release."))
                }
                try persistFinal()
                return record
            }
            if let power = record.power {
                let requested = leaseFactory(power.mode, record.id, power.deadline)
                lease = requested
                do {
                    try await requested.acquire()
                } catch {
                    record.status = .interrupted; record.endedAt = Date()
                    record.power?.state = .failed; record.power?.issue = .acquisitionFailed
                    record.events.append(RunEvent("wakeAcquisitionFailed", "Could not confirm the requested Borrow-owned hold. No foreground task was launched."))
                    await release(requested, reason: .error); cleanupFinished = true
                    try persistFinal()
                    return record
                }
                record.power?.state = .active; record.power?.acquiredAt = Date()
                record.events.append(RunEvent("wakeAcquired", "Confirmed the explicitly requested Borrow-owned wake assertion. Closed-lid operation remains unverified."))
                try saveRecord(record, directory)
            }
            if cancelled {
                record.status = .cancelled; record.endedAt = Date()
                record.events.append(RunEvent("cancelled", "Recording stopped before foreground task launch. An observed external agent was left untouched."))
                if let lease { await release(lease, reason: .cancelled); cleanupFinished = true }
                try persistFinal()
                return record
            }
            // Setup and hold acquisition can outlast the limit. Nothing is launched or observed after it.
            if Date() >= deadline {
                record.status = .timedOut; record.endedAt = Date()
                record.events.append(RunEvent("timeout", executable == nil
                    ? "The time limit passed before observation could begin. The agent was left untouched."
                    : "The time limit passed before the foreground task could be launched. Nothing was launched."))
                if let lease { await release(lease, reason: .timedOut); cleanupFinished = true }
                try persistFinal()
                return record
            }
            let child = executable.map { executable -> Process in
                let child = Process()
                child.executableURL = executable; child.arguments = arguments
                child.standardInput = FileHandle.nullDevice
                return child
            }
            if record.kind == .rehearsal {
                child?.standardOutput = FileHandle.nullDevice; child?.standardError = FileHandle.nullDevice
            }
            for (name, kind, detail) in [
                (NSWorkspace.willSleepNotification, "systemSleep", "macOS posted a before-sleep notification; this does not measure an execution pause."),
                (NSWorkspace.didWakeNotification, "systemWake", "macOS posted a wake notification."),
                (NSWorkspace.screensDidSleepNotification, "displaySleep", "Displays slept; this does not establish system sleep."),
                (NSWorkspace.screensDidWakeNotification, "displayWake", "Displays woke.")
            ] {
                let observer = NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.record.events.append(RunEvent(kind, detail)) }
                }
                observers.append(observer)
            }
            defer {
                for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
                observers.removeAll()
                if let child, child.isRunning { child.terminate() }
            }
            do { try child?.run() }
            catch {
                record.status = .interrupted; record.endedAt = Date()
                record.events.append(RunEvent("launchFailed", "Could not launch the explicitly selected foreground task. Executable paths and arguments were not recorded."))
                if let lease { await release(lease, reason: .launchFailed); cleanupFinished = true }
                try persistFinal()
                throw RecorderError.launchFailed
            }
            if let child { record.events.append(RunEvent("taskStarted", "Started owned foreground process \(child.processIdentifier).")) }
            var lastSample: Date?
            var lastLid: Bool?
            var lastNetwork: Bool?
            var lastSave = Date.distantPast
            let terminalStates: [AgentState] = [.turnEnded, .failed, .interrupted]
            while true {
                let now = Date()
                var agentFinished = false
                var agentOutcomeLate = false
                if let agentReader {
                    do {
                        let batch = try agentReader.poll()
                        // Read after the poll: an outcome counts as timely only if it was seen before the limit.
                        let polledAt = Date()
                        for signal in batch.signals {
                            record.agent?.apply(signal, observedAt: now)
                            let detail: String
                            switch signal.kind {
                            case .turnStarted: detail = "Codex logged a turn start."
                            case .toolCompleted: detail = "Codex logged a completed tool item; contents discarded."
                            case .turnEnded: detail = "Codex logged a turn end; this does not verify the result."
                            case .failed: detail = "Codex logged a failed turn; error contents discarded."
                            case .interrupted: detail = "Codex logged a turn interruption."
                            }
                            record.events.append(RunEvent("agent.\(signal.kind.rawValue)", detail, time: signal.time))
                        }
                        record.agent?.activeTurns = batch.activeTurns
                        if batch.skippedLines > 0 {
                            record.agent?.streamIncomplete = true
                            record.events.append(RunEvent("agentStreamIncomplete", "Skipped \(batch.skippedLines) malformed or oversized records; lifecycle completeness is unknown."))
                        }
                        if record.agent?.streamIncomplete == true { record.agent?.state = .unknown }
                        else if batch.activeTurns > 0, record.agent?.state == .turnEnded { record.agent?.state = .working }
                        // The state starts unknown and only becomes terminal through signals observed in this recording,
                        // so history alone can never end it. A terminal result from an earlier poll is reconsidered
                        // once a partially written record completes, even when that record carried no lifecycle signal.
                        let outcomeObserved = batch.activeTurns == 0 && !batch.pendingRecord &&
                            record.agent?.streamIncomplete != true &&
                            terminalStates.contains(record.agent?.state ?? .unknown)
                        agentFinished = outcomeObserved && polledAt < deadline
                        agentOutcomeLate = outcomeObserved && !agentFinished
                    } catch {
                        record.agent?.state = .unknown; record.agent?.streamIncomplete = true
                        record.status = .interrupted
                        record.events.append(RunEvent("agentSourceLost", "Selected Codex log became unreadable, replaced, or truncated. No automatic source switch or agent restart was attempted."))
                        break
                    }
                }
                if let lastSample, now.timeIntervalSince(lastSample) > 8 {
                    record.events.append(RunEvent("observationGap", "No sample for \(Int(now.timeIntervalSince(lastSample))) seconds; cause unknown."))
                }
                let lid = MachineProbe.lidClosed()
                if lid != lastLid || lastSample == nil {
                    record.events.append(RunEvent("lid", lid == true ? "Lid sampled closed." : lid == false ? "Lid sampled open." : "Lid state unavailable."))
                    lastLid = lid
                }
                var heartbeat: Int?
                if let proofURL, let data = try? Data(contentsOf: proofURL),
                   let proof = try? RecordingStore.decoder().decode(WorkerProof.self, from: data), proof.runID == record.id {
                    heartbeat = proof.heartbeat
                    if proof.completed { record.verifiedWorkerHeartbeat = proof.heartbeat }
                }
                let network = record.networkEnabled ? await MachineProbe.connectivity() : nil
                if let network, network != lastNetwork {
                    record.events.append(RunEvent("connectivity", network ? "Apple connectivity endpoint answered." : "Apple connectivity endpoint failed; agent connection state unknown."))
                    lastNetwork = network
                }
                record.observations.append(MachineSample(time: now, lidClosed: lid, heartbeat: heartbeat,
                    networkReachable: network, thermalState: MachineProbe.thermalState, batteryPercent: MachineProbe.batteryPercent(),
                    agentActivityCount: record.agent?.activityCount, onACPower: MachineProbe.onACPower()))
                lastSample = now
                if cancelled {
                    record.status = .cancelled
                    record.events.append(RunEvent("cancelled", child == nil ? "Stopped observing. The agent and its processes were left running." : "Recording cancelled. Sent termination only to the owned foreground process; descendants are not managed."))
                    break
                }
                // The clock is read after the process check. An exit first seen at or after the limit may have
                // happened late (blocked or suspended recorder), so it is never reported as timely completion.
                let childExited = child.map { !$0.isRunning } ?? false
                let checkedAt = Date()
                if let child, childExited, checkedAt < deadline {
                    if let proofURL, let data = try? Data(contentsOf: proofURL),
                       let proof = try? RecordingStore.decoder().decode(WorkerProof.self, from: data),
                       proof.runID == record.id, proof.completed {
                        record.verifiedWorkerHeartbeat = proof.heartbeat
                    }
                    record.exitCode = child.terminationStatus
                    record.status = .completed
                    record.events.append(RunEvent("taskExited", "Foreground process exited \(child.terminationStatus)."))
                    break
                }
                if agentFinished {
                    record.status = .completed
                    record.events.append(RunEvent("agentObservationEnded", "Recording ended after the observed turn outcome. The agent was left untouched; any Borrow-owned hold will be released."))
                    break
                }
                if checkedAt >= deadline {
                    record.status = .timedOut
                    let detail: String
                    if child == nil {
                        detail = agentOutcomeLate
                            ? "Observation time limit reached. A turn outcome was first seen after the limit, so timely completion is not established. The agent was left untouched."
                            : "Observation time limit reached. The agent was left running."
                    } else if childExited {
                        detail = "Recording reached its time limit. The owned foreground process was first found exited after the limit; its exit status was not recorded and timely completion is not established."
                    } else {
                        detail = "Recording reached its time limit. Sent termination to the owned foreground process."
                    }
                    record.events.append(RunEvent("timeout", detail))
                    break
                }
                if let lease {
                    let health = lease.health()
                    if health != .active {
                        record.status = .interrupted
                        switch health {
                        case .active: break
                        case .expired: record.power?.issue = .expired; record.power?.releaseReason = .expired
                        case .powerDisconnected: record.power?.issue = .powerDisconnected; record.power?.releaseReason = .powerDisconnected
                        case .lost: record.power?.issue = .assertionLost; record.power?.releaseReason = .holdLost
                        case .unknown: record.power?.issue = .stateUnknown; record.power?.releaseReason = .stateUnknown
                        }
                        record.events.append(health == .unknown
                            ? RunEvent("wakeStateUnknown", "Borrow could not read its power source or assertion inventory, so the state of its hold is unknown. Recording stopped conservatively; no unplug or lost hold is claimed. An observed external agent remains untouched.")
                            : RunEvent("wakeLost", "The Borrow-owned hold is no longer confirmed active. Recording stopped; an observed external agent remains untouched."))
                        break
                    }
                }
                if Date().timeIntervalSince(lastSave) >= 5 {
                    try saveRecord(record, directory)
                    lastSave = Date()
                }
                try await Task.sleep(for: .seconds(1))
            }
            if let lease {
                let reason: WakeReleaseReason = record.power?.releaseReason ?? (record.status == .cancelled ? .cancelled
                    : record.status == .timedOut ? .timedOut : record.status == .interrupted ? .sourceLost : .completed)
                await release(lease, reason: reason); cleanupFinished = true
            }
            record.endedAt = Date()
            try persistFinal()
            return record
        } catch {
            if let lease, !cleanupFinished { await release(lease, reason: .error); cleanupFinished = true }
            // A launch failure was already persisted in full before it was thrown.
            if let known = error as? RecorderError { throw known }
            // Cleanup has been observed, so a snapshot that still says "running" with an active hold would be wrong.
            // One best-effort attempt covers a transient write failure; the caller still gets a sanitized error.
            if record.status == .running { record.status = .interrupted }
            if record.endedAt == nil { record.endedAt = Date() }
            record.events.append(RunEvent("recorderError", "A recorder operation failed, so this recording ended early. Error details and file locations were not recorded."))
            try? persistFinal()
            throw RecorderError.operationFailed
        }
    }

    private func persistFinal() throws {
        try saveRecord(record, directory)
        try RecordingStore.markdown(record).write(to: directory.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
    }

    private func release(_ lease: any WakeLeaseControlling, reason: WakeReleaseReason) async {
        var outcome = await lease.release()
        // "Nothing held" after a confirmed acquisition contradicts earlier evidence; never read it as a clean result.
        if outcome == .nothingHeld, record.power?.acquiredAt != nil { outcome = .unconfirmed }
        record.power?.cleanup = outcome
        switch outcome {
        case .released:
            // An earlier issue such as acquisitionFailed is kept: cleaning a provisional hold does not undo it.
            record.power?.releaseReason = reason
            record.power?.state = .released; record.power?.releasedAt = Date()
            record.events.append(RunEvent("wakeReleased", "Confirmed release of Borrow's own wake hold. Actual system sleep remains unverified."))
        case .nothingHeld:
            // No hold existed, so there is no release time, reason, or release event to report.
            record.power?.state = .failed
            record.events.append(RunEvent("wakeNothingHeld", "No Borrow-owned hold was created, so there was nothing to release."))
        case .unconfirmed:
            record.power?.releaseReason = reason
            record.power?.state = .failed; record.power?.issue = .releaseUnconfirmed
            record.events.append(RunEvent("wakeReleaseUnconfirmed", "Could not confirm release of Borrow's own hold. Its finite OS timeout and owner-lifetime bound remain; actual sleep is unknown."))
        }
    }
}

public enum RecorderError: LocalizedError {
    case sourceUnavailable, launchFailed, operationFailed
    public var errorDescription: String? {
        switch self {
        case .sourceUnavailable: return "The selected Codex source could not be opened. Its path was not recorded."
        case .launchFailed: return "The selected foreground task could not be launched. Its path and arguments were not recorded."
        case .operationFailed: return "Recording could not finish because an operation failed. Any owned wake hold was released or bounded by its OS timeout."
        }
    }
}
