import AppKit
import Foundation

@MainActor
public final class Recorder {
    public var cancelled = false
    private var record: RunRecord
    private let directory: URL
    private var observers: [NSObjectProtocol] = []

    public init(record: RunRecord, directory: URL) {
        self.record = record; self.directory = directory
    }

    public func run(executable: URL, arguments: [String], proofURL: URL? = nil) async throws -> RunRecord {
        try await capture(executable: executable, arguments: arguments, proofURL: proofURL)
    }

    public func observeCodex(sessionURL: URL) async throws -> RunRecord {
        try await capture(sessionURL: sessionURL)
    }

    private func capture(executable: URL? = nil, arguments: [String] = [], proofURL: URL? = nil,
                         sessionURL: URL? = nil) async throws -> RunRecord {
        let agentReader = try sessionURL.map { try CodexLogReader(url: $0) }
        if let agentReader {
            record.agent = AgentEvidence()
            record.agent?.streamIncomplete = agentReader.historyIncomplete
            record.events.append(RunEvent("agentAttached", "Attached to the selected Codex log at its current end. Historical activity is excluded; conversation and tool content are discarded."))
        }
        record.recorderPID = ProcessInfo.processInfo.processIdentifier
        record.events.append(RunEvent("started", "Recorder started. No sleep overrides or wake assertions requested."))
        try RecordingStore.save(record, to: directory)
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
            (NSWorkspace.willSleepNotification, "systemSleep", "macOS announced system sleep."),
            (NSWorkspace.didWakeNotification, "systemWake", "macOS announced system wake."),
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
            record.events.append(RunEvent("launchFailed", "Could not launch the task: \(error.localizedDescription)"))
            try RecordingStore.save(record, to: directory)
            throw error
        }
        if let child { record.events.append(RunEvent("taskStarted", "Started owned foreground process \(child.processIdentifier).")) }
        var lastSample: Date?
        var lastLid: Bool?
        var lastNetwork: Bool?
        var lastSave = Date.distantPast
        let deadline = record.startedAt.addingTimeInterval(TimeInterval(record.plannedSeconds + (record.kind == .rehearsal ? 15 : 0)))
        while true {
            let now = Date()
            var agentFinished = false
            if let agentReader {
                do {
                    let batch = try agentReader.poll()
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
                    agentFinished = !batch.signals.isEmpty && batch.activeTurns == 0 &&
                        [.turnEnded, .failed, .interrupted].contains(record.agent?.state ?? .unknown)
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
                agentActivityCount: record.agent?.activityCount))
            lastSample = now
            if cancelled {
                record.status = .cancelled
                record.events.append(RunEvent("cancelled", child == nil ? "Stopped observing. The agent and its processes were left running." : "Recording cancelled. Sent termination only to the owned foreground process; descendants are not managed."))
                break
            }
            if let child, !child.isRunning {
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
                record.events.append(RunEvent("agentObservationEnded", "Recording ended after the observed turn outcome. No agent process or power setting was changed."))
                break
            }
            if Date() >= deadline {
                record.status = .timedOut
                record.events.append(RunEvent("timeout", child == nil ? "Observation time limit reached. The agent was left running." : "Recording reached its time limit. Sent termination to the owned foreground process."))
                break
            }
            if Date().timeIntervalSince(lastSave) >= 5 {
                try RecordingStore.save(record, to: directory)
                lastSave = Date()
            }
            try await Task.sleep(for: .seconds(1))
        }
        record.endedAt = Date()
        try RecordingStore.save(record, to: directory)
        try RecordingStore.markdown(record).write(to: directory.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        return record
    }
}
