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
        record.recorderPID = ProcessInfo.processInfo.processIdentifier
        record.events.append(RunEvent("started", "Recorder started. No sleep overrides or wake assertions requested."))
        try RecordingStore.save(record, to: directory)
        let child = Process()
        child.executableURL = executable; child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        if record.kind == .rehearsal {
            child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
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
            if child.isRunning { child.terminate() }
        }
        do { try child.run() }
        catch {
            record.status = .interrupted; record.endedAt = Date()
            record.events.append(RunEvent("launchFailed", "Could not launch the task: \(error.localizedDescription)"))
            try RecordingStore.save(record, to: directory)
            throw error
        }
        record.events.append(RunEvent("taskStarted", "Started owned foreground process \(child.processIdentifier)."))
        var lastSample: Date?
        var lastLid: Bool?
        var lastNetwork: Bool?
        var lastSave = Date.distantPast
        let deadline = record.startedAt.addingTimeInterval(TimeInterval(record.plannedSeconds + (record.kind == .rehearsal ? 15 : 0)))
        while true {
            let now = Date()
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
                networkReachable: network, thermalState: MachineProbe.thermalState, batteryPercent: MachineProbe.batteryPercent()))
            lastSample = now
            if cancelled {
                record.status = .cancelled
                record.events.append(RunEvent("cancelled", "Recording cancelled. Sent termination only to the owned foreground process; descendants are not managed."))
                break
            }
            if !child.isRunning {
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
            if Date() >= deadline {
                record.status = .timedOut
                record.events.append(RunEvent("timeout", "Recording reached its time limit. Sent termination to the owned foreground process."))
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
