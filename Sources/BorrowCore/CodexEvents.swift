import Foundation

public enum AgentState: String, Codable { case unknown, working, turnEnded, failed, interrupted }
public enum AgentSignalKind: String, Codable { case turnStarted, toolCompleted, turnEnded, failed, interrupted }

public struct AgentSignal: Equatable {
    public let kind: AgentSignalKind
    public let time: Date
    let turnID: String?
}

public struct AgentEvidence: Codable {
    public var adapter = "codex-local-v1"
    public var state: AgentState = .unknown
    public var activityCount = 0
    public var toolCompletions = 0
    public var completedTurns = 0
    public var lastActivityAt: Date?
    public var streamIncomplete = false
    public var activeTurns = 0
    public init() {}

    public mutating func apply(_ signal: AgentSignal, observedAt: Date = Date()) {
        activityCount += 1; lastActivityAt = observedAt
        switch signal.kind {
        case .turnStarted: state = .working
        case .toolCompleted: toolCompletions += 1
        case .turnEnded: state = .turnEnded; completedTurns += 1
        case .failed: state = .failed
        case .interrupted: state = .interrupted
        }
    }
}

/// Decodes only whitelisted lifecycle shapes. Content fields never enter a recording.
public enum CodexEventParser {
    public static func parse(_ data: Data, observedAt: Date = Date()) -> AgentSignal? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        let payload: [String: Any]
        let event: String
        if type == "event_msg", let inner = object["payload"] as? [String: Any], let innerType = inner["type"] as? String {
            payload = inner; event = innerType
        } else {
            payload = object; event = type
        }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = (object["timestamp"] as? String).flatMap { formatter.date(from: $0) } ?? observedAt
        let turn = payload["turn_id"] as? String
        let kind: AgentSignalKind
        switch event {
        case "task_started", "turn.started": kind = .turnStarted
        case "task_complete", "turn.completed": kind = .turnEnded
        case "turn_aborted", "turn.interrupted": kind = .interrupted
        case "turn.failed": kind = .failed
        case "item_completed", "item.completed":
            guard let item = payload["item"] as? [String: Any], let itemType = item["type"] as? String,
                  ["McpToolCall", "CommandExecution", "FileChange", "command_execution", "mcp_tool_call", "file_change", "web_search"].contains(itemType) else { return nil }
            kind = .toolCompleted
        default: return nil
        }
        return AgentSignal(kind: kind, time: timestamp, turnID: turn)
    }
}

public enum CodexLogError: LocalizedError {
    case unavailable, replaced, truncated
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Selected Codex log is no longer readable."
        case .replaced: return "Selected Codex log was replaced. Recording stopped rather than switching sources."
        case .truncated: return "Selected Codex log was truncated. Earlier lifecycle state is no longer reliable."
        }
    }
}

public struct CodexBatch {
    public var signals: [AgentSignal]
    public var skippedLines: Int
    public var activeTurns: Int
    public var pendingRecord: Bool
}

/// Follows one explicitly selected file from its current end; never scans unrelated sessions.
public final class CodexLogReader {
    private let url: URL
    private let handle: FileHandle
    private let inode: UInt64
    private var pending = Data()
    private var discardingLine = false
    private var pendingHistorical = false
    private var offset: UInt64 = 0
    private var activeTurns: Set<String> = []
    private var anonymousTurn = false
    private let maximumLineBytes = 1_048_576
    public private(set) var historyIncomplete = false
    public var pendingRecord: Bool { !pending.isEmpty || discardingLine }

    public init(url: URL) throws {
        self.url = url
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let inode = attributes[.systemFileNumber] as? UInt64,
              let handle = try? FileHandle(forReadingFrom: url) else { throw CodexLogError.unavailable }
        self.inode = inode; self.handle = handle
        let historical = try consume(collect: false)
        historyIncomplete = historical.skippedLines > 0
    }
    deinit { try? handle.close() }

    public func poll() throws -> CodexBatch { try consume(collect: true) }

    private func consume(collect: Bool) throws -> CodexBatch {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64 else { throw CodexLogError.unavailable }
        guard attributes[.systemFileNumber] as? UInt64 == inode else { throw CodexLogError.replaced }
        guard size >= offset else { throw CodexLogError.truncated }
        var signals: [AgentSignal] = []
        var skipped = 0
        // Only read the bytes present at this poll's start, even if the writer remains busy.
        while offset < size {
            guard let chunk = try handle.read(upToCount: min(65_536, Int(size - offset))), !chunk.isEmpty else { break }
            offset += UInt64(chunk.count)
            for byte in chunk {
                if byte == 10 {
                    if discardingLine { skipped += 1 }
                    else if !pending.isEmpty {
                        if let signal = CodexEventParser.parse(pending) {
                            updateTurns(signal)
                            if collect && !pendingHistorical { signals.append(signal) }
                        } else if (try? JSONSerialization.jsonObject(with: pending)) == nil { skipped += 1 }
                    }
                    pending.removeAll(keepingCapacity: true); discardingLine = false; pendingHistorical = false
                } else if !discardingLine {
                    if pending.count < maximumLineBytes { pending.append(byte) }
                    else { pending.removeAll(keepingCapacity: true); discardingLine = true }
                }
            }
        }
        // Finish parsing a historical tail for bookkeeping, but never count it as fresh activity.
        if !collect, pendingRecord { pendingHistorical = true }
        if skipped > 0 { activeTurns.removeAll(); anonymousTurn = false }
        return CodexBatch(signals: signals, skippedLines: skipped,
                          activeTurns: activeTurns.count + (anonymousTurn ? 1 : 0), pendingRecord: pendingRecord)
    }

    private func updateTurns(_ signal: AgentSignal) {
        switch signal.kind {
        case .turnStarted:
            if let turn = signal.turnID { activeTurns.insert(turn) } else { anonymousTurn = true }
        case .turnEnded, .failed, .interrupted:
            if let turn = signal.turnID { activeTurns.remove(turn) } else { anonymousTurn = false }
        case .toolCompleted: break
        }
    }
}
