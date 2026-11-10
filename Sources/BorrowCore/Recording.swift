import Foundation

public enum RunStatus: String, Codable { case running, completed, cancelled, interrupted, timedOut }
public enum RunKind: String, Codable { case rehearsal, command, codexSession }
public enum CheckState: String, Codable { case observed, failed, unverified, skipped }

public struct MachineSample: Codable, Identifiable {
    public var id: UUID = UUID()
    public var time: Date
    public var lidClosed: Bool?
    public var heartbeat: Int?
    public var networkReachable: Bool?
    public var thermalState: String
    public var batteryPercent: Int?
    public var agentActivityCount: Int?
    public init(time: Date, lidClosed: Bool?, heartbeat: Int? = nil,
                networkReachable: Bool? = nil, thermalState: String = "unknown", batteryPercent: Int? = nil,
                agentActivityCount: Int? = nil) {
        self.time = time; self.lidClosed = lidClosed; self.heartbeat = heartbeat
        self.networkReachable = networkReachable; self.thermalState = thermalState; self.batteryPercent = batteryPercent
        self.agentActivityCount = agentActivityCount
    }
}

public struct RunEvent: Codable, Identifiable {
    public var id: UUID = UUID()
    public var time: Date
    public var kind: String
    public var detail: String
    public init(_ kind: String, _ detail: String, time: Date = Date()) {
        self.kind = kind; self.detail = detail; self.time = time
    }
}

public struct Finding: Identifiable {
    public var id: String { title }
    public var title: String
    public var state: CheckState
    public var detail: String
}

public struct WorkerProof: Codable {
    public var runID: UUID
    public var heartbeat: Int
    public var completed: Bool
    public var time: Date
    public init(runID: UUID, heartbeat: Int, completed: Bool) {
        self.runID = runID; self.heartbeat = heartbeat; self.completed = completed; self.time = Date()
    }
}

public struct RunRecord: Codable, Identifiable {
    public var schemaVersion = 2
    public var id: UUID
    public var kind: RunKind
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    public var status: RunStatus
    public var macOS: String
    public var plannedSeconds: Int
    public var networkEnabled: Bool
    public var observations: [MachineSample] = []
    public var events: [RunEvent] = []
    public var exitCode: Int32?
    public var verifiedWorkerHeartbeat: Int?
    public var recorderPID: Int32?
    public var agent: AgentEvidence?

    public init(id: UUID = UUID(), kind: RunKind = .rehearsal, title: String = "Closed-lid rehearsal",
                seconds: Int, networkEnabled: Bool = false, startedAt: Date = Date()) {
        self.id = id; self.kind = kind; self.title = title; self.startedAt = startedAt
        self.status = .running; self.macOS = ProcessInfo.processInfo.operatingSystemVersionString
        self.plannedSeconds = seconds; self.networkEnabled = networkEnabled
    }

    public var closedLidHeartbeats: Int {
        zip(observations, observations.dropFirst()).reduce(0) { count, pair in
            guard pair.0.lidClosed == true, pair.1.lidClosed == true,
                  let previous = pair.0.heartbeat, let next = pair.1.heartbeat else { return count }
            return count + max(0, next - previous)
        }
    }

    public var statusLabel: String {
        switch status {
        case .running: return "Recording"
        case .completed: return "Recording finished"
        case .cancelled: return "Recording stopped"
        case .interrupted: return "Recording interrupted"
        case .timedOut: return "Time limit reached"
        }
    }

    public var closedLidAgentEvents: Int {
        zip(observations, observations.dropFirst()).reduce(0) { count, pair in
            guard pair.0.lidClosed == true, pair.1.lidClosed == true,
                  let previous = pair.0.agentActivityCount, let next = pair.1.agentActivityCount else { return count }
            return count + max(0, next - previous)
        }
    }

    public var findings: [Finding] {
        let closed = observations.filter { $0.lidClosed == true }
        let sleeps = events.filter { $0.kind == "systemSleep" }.count
        let wakes = events.filter { $0.kind == "systemWake" }.count
        let gaps = events.filter { $0.kind == "observationGap" }.count
        var checks: [Finding] = []
        if kind == .rehearsal {
            checks.append(Finding(title: "Work while closed", state: closedLidHeartbeats >= 3 ? .observed : .unverified,
                detail: closedLidHeartbeats >= 3
                    ? "Independent worker advanced \(closedLidHeartbeats) ticks between closed-lid samples. This covers those sampled intervals only."
                    : "Need at least 3 worker ticks between samples with the lid closed. An open-lid run does not establish this."))
            let proof = status == .completed && exitCode == 0 && (verifiedWorkerHeartbeat ?? 0) >= plannedSeconds
            checks.append(Finding(title: "Expected result", state: status == .running ? .unverified : (proof ? .observed : .failed),
                detail: proof ? "Worker exited zero and its run-specific final artifact contains the expected heartbeat count."
                    : "Requires a zero exit and a matching, complete worker artifact. Recording activity alone is insufficient."))
        } else if kind == .codexSession {
            let evidence = agent ?? AgentEvidence()
            checks.append(Finding(title: "Agent activity", state: evidence.activityCount > 0 ? .observed : .unverified,
                detail: "\(evidence.activityCount) new lifecycle events; \(evidence.toolCompletions) tool completions. These are logged events, not proof of useful progress or correctness."))
            checks.append(Finding(title: "Events logged while closed", state: closedLidAgentEvents > 0 ? .observed : .unverified,
                detail: "\(closedLidAgentEvents) lifecycle events were appended between closed-lid samples. Event delivery can be delayed. Intervals without events remain unknown; a slow model is not classified as stuck."))
            let ended = evidence.state == .turnEnded && !evidence.streamIncomplete
            checks.append(Finding(title: "Recorded turn outcome", state: ended ? .observed : evidence.state == .failed || evidence.state == .interrupted ? .failed : .unverified,
                detail: evidence.streamIncomplete ? "The stream had unreadable or oversized records. Its final state cannot establish a complete lifecycle."
                    : ended ? "Codex logged a turn end after attachment and no other logged turn remained active. This is not acceptance-test verification."
                    : evidence.state == .unknown ? "No turn boundary has been observed since attachment. Tool events do not establish whether the agent is now working or waiting."
                    : "Last logged state: \(evidence.state.rawValue). No approval state is inferred and no task-correctness claim is made."))
        } else {
            checks.append(Finding(title: "Command exit", state: exitCode == nil ? .unverified : (exitCode == 0 ? .observed : .failed),
                detail: exitCode.map { "Observed foreground process exit \($0). This does not establish task correctness or child-process completion." }
                    ?? "Waiting for the foreground command to exit. No semantic completion claim is made."))
            checks.append(Finding(title: "Agent progress", state: .unverified,
                detail: "This recorder observes process exit and machine conditions. Agent-specific progress and approval adapters are not implemented."))
        }
        let powerDetail: String
        if sleeps > 0 {
            powerDetail = "macOS posted \(sleeps) before-sleep and \(wakes) wake notification(s). " +
                (gaps > 0 ? "There were \(gaps) long sampling gap(s). " : "No long sampling gap was recorded. ") +
                (closedLidHeartbeats > 0 ? "Worker progress was also sampled with the lid closed. " : "") +
                "Notifications alone do not measure how long execution paused; uninterrupted operation remains unverified."
        } else if gaps > 0 {
            powerDetail = "\(gaps) observation gap(s). A gap may be sleep, scheduling delay, or a stalled recorder; its cause is unknown."
        } else if closed.count < 2 {
            powerDetail = "Insufficient closed-lid samples to assess this interval."
        } else {
            powerDetail = "No sleep notification or long sampling gap was recorded. This is bounded observation, not a guarantee."
        }
        checks.append(Finding(title: "Sleep and sampling",
            state: sleeps > 0 || gaps > 0 || closed.count < 2 ? .unverified : .observed, detail: powerDetail))
        let network = (closed.isEmpty ? observations : closed).compactMap(\.networkReachable)
        checks.append(Finding(title: "Connectivity probe", state: !networkEnabled ? .skipped : network.isEmpty ? .unverified : network.contains(false) ? .failed : .observed,
            detail: !networkEnabled ? "Off. Enable the optional Apple connectivity check before starting."
                : network.contains(false) ? "The Apple connectivity endpoint failed at least once. Provider/API health is not determined."
                : "Apple's connectivity endpoint answered during \(network.count) sample(s). This does not test the agent's live connection, VPN, or remote-control bridge."))
        checks.append(Finding(title: "Sleep settings restored", state: .skipped,
            detail: "Borrow made no sleep-setting changes and holds no wake assertion. Restoration and actual post-task sleep are not tested in this prototype."))
        return checks
    }
}

public enum RecordingStore {
    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Borrow/Runs", isDirectory: true)
    }
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder
    }
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
    public static func save(_ record: RunRecord, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try encoder().encode(record).write(to: directory.appendingPathComponent("recording.json"), options: .atomic)
    }
    public static func read(from directory: URL) throws -> RunRecord {
        try decoder().decode(RunRecord.self, from: Data(contentsOf: directory.appendingPathComponent("recording.json")))
    }
    public static func markdown(_ record: RunRecord) -> String {
        var lines = ["# Borrow recording", "", "\(record.title)", "", "Status: \(record.status.rawValue)",
                     "Started: \(record.startedAt.formatted())", "System: \(record.macOS)",
                     "Run: \(record.id.uuidString)", "", "## Observations", ""]
        for finding in record.findings {
            lines += ["### \(finding.title) — \(finding.state.rawValue)", "", finding.detail, ""]
        }
        lines += ["## Timeline", ""]
        for event in record.events { lines.append("- \(event.time.formatted(date: .omitted, time: .standard)): \(event.detail)") }
        lines += ["", "This recording covers one setup and one interval. It does not certify future runs or physical safety.", ""]
        return lines.joined(separator: "\n")
    }
}
