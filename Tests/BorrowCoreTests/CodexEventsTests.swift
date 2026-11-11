import Foundation
import Testing
@testable import BorrowCore

private func journal(_ type: String, turn: String = "turn-a", extra: [String: Any] = [:]) throws -> Data {
    var payload: [String: Any] = ["type": type, "turn_id": turn]
    extra.forEach { payload[$0] = $1 }
    var data = try JSONSerialization.data(withJSONObject: ["type": "event_msg", "timestamp": "2026-11-10T15:00:00.123Z", "payload": payload])
    data.append(10); return data
}

private func append(_ data: Data, to url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd(); try handle.write(contentsOf: data)
}

@Test func codexParserDiscardsContentAndIgnoresMessages() throws {
    let data = try journal("item_completed", extra: ["item": ["type": "CommandExecution", "command": "SECRET-COMMAND", "aggregated_output": "SECRET-OUTPUT"]])
    let signal = try #require(CodexEventParser.parse(data))
    #expect(signal.kind == .toolCompleted)
    let message = try journal("item_completed", extra: ["item": ["type": "AgentMessage", "content": "SECRET-MESSAGE"]])
    #expect(CodexEventParser.parse(message) == nil)
    #expect(CodexEventParser.parse(Data("{bad".utf8)) == nil)
}

@Test func execJSONLUsesItsActualTurnEvents() throws {
    #expect(CodexEventParser.parse(Data(#"{"type":"turn.completed","usage":{"input_tokens":123}}"#.utf8))?.kind == .turnEnded)
    #expect(CodexEventParser.parse(Data(#"{"type":"turn.failed","error":{"message":"PRIVATE"}}"#.utf8))?.kind == .failed)
    #expect(CodexEventParser.parse(Data(#"{"type":"error","message":"retrying"}"#.utf8)) == nil)
    #expect(CodexEventParser.parse(Data(#"{"type":"item.completed","item":{"type":"agent_message","text":"PRIVATE"}}"#.utf8)) == nil)
}

@Test func attachingDoesNotReplayHistoricalActivity() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try journal("task_started").write(to: file)
    let reader = try CodexLogReader(url: file)
    #expect(try reader.poll().signals.isEmpty)
    try append(journal("task_complete", extra: ["last_agent_message": "PRIVATE-FINAL"]), to: file)
    let batch = try reader.poll()
    #expect(batch.signals.map(\.kind) == [.turnEnded])
    #expect(batch.activeTurns == 0)
}

@Test func multipleLoggedTurnsDoNotEndOnFirstCompletion() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try (journal("task_started", turn: "a") + journal("task_started", turn: "b")).write(to: file)
    let reader = try CodexLogReader(url: file)
    try append(journal("task_complete", turn: "a"), to: file)
    #expect(try reader.poll().activeTurns == 1)
    try append(journal("task_complete", turn: "b"), to: file)
    #expect(try reader.poll().activeTurns == 0)
}

@Test func incompleteNewLineWaitsForItsTerminator() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try Data().write(to: file)
    let reader = try CodexLogReader(url: file)
    let line = try journal("task_complete")
    try append(Data(line.dropLast()), to: file)
    #expect(try reader.poll().signals.isEmpty)
    try append(Data([10]), to: file)
    #expect(try reader.poll().signals.count == 1)
}

@Test func attachingMidLinePreservesHistoricalBookkeepingWithoutCountingItAsMalformed() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try Data(journal("task_started", turn: "historical").dropLast()).write(to: file)
    let reader = try CodexLogReader(url: file)
    try append(Data([10]) + journal("item_completed", extra: ["item": ["type": "McpToolCall"]]), to: file)
    let batch = try reader.poll()
    #expect(batch.skippedLines == 0)
    #expect(batch.activeTurns == 1)
    #expect(batch.signals.map(\.kind) == [.toolCompleted])
    try append(journal("task_complete", turn: "historical"), to: file)
    #expect(try reader.poll().activeTurns == 0)
}

@Test func turnEndWithAnUnfinishedFollowingRecordKeepsTheBoundaryPending() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try Data().write(to: file)
    let reader = try CodexLogReader(url: file)
    let next = try journal("task_started", turn: "next")
    try append(journal("task_complete") + Data(next.dropLast()), to: file)
    let boundary = try reader.poll()
    #expect(boundary.signals.map(\.kind) == [.turnEnded])
    #expect(boundary.pendingRecord)
    try append(Data([10]), to: file)
    let continued = try reader.poll()
    #expect(continued.signals.map(\.kind) == [.turnStarted])
    #expect(continued.activeTurns == 1)
    #expect(!continued.pendingRecord)
}

@MainActor @Test(arguments: [true, false])
func recorderWaitsForPendingBytesAfterAnObservedTurnEnd(nextTurn: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try journal("task_started").write(to: file)
    let writer = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(150))
        let following = nextTurn ? try journal("task_started", turn: "next")
            : Data("{\"type\":\"session_meta\",\"payload\":{}}\n".utf8)
        try append(journal("task_complete") + Data(following.dropLast()), to: file)
        try await Task.sleep(for: .milliseconds(1500))
        try append(Data([10]), to: file)
        if nextTurn { try append(journal("task_complete", turn: "next"), to: file) }
    }
    defer { writer.cancel() }
    let recorder = Recorder(record: RunRecord(kind: .codexSession, seconds: 6), directory: root.appendingPathComponent("out"))
    let run = try await recorder.observeCodex(sessionURL: file)
    #expect(run.status == .completed)
    #expect(run.agent?.activityCount == (nextTurn ? 3 : 1))
    #expect(run.agent?.streamIncomplete == false)
    #expect(run.observations.count >= 3)
}

@Test func truncatedOrReplacedSourceIsNotSilentlyReplayed() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try journal("task_started").write(to: file)
    let reader = try CodexLogReader(url: file)
    let writer = try FileHandle(forWritingTo: file)
    try writer.truncate(atOffset: 0); try writer.close()
    #expect(throws: CodexLogError.self) { try reader.poll() }
    let second = try CodexLogReader(url: file)
    try journal("task_complete").write(to: file, options: .atomic)
    #expect(throws: CodexLogError.self) { try second.poll() }
}

@Test func oversizedLineIsBoundedAndMarkedIncomplete() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try Data().write(to: file)
    let reader = try CodexLogReader(url: file)
    var large = Data(repeating: 65, count: 1_048_600); large.append(10)
    try append(large + journal("task_complete"), to: file)
    let batch = try reader.poll()
    #expect(batch.skippedLines == 1)
    #expect(batch.signals.count == 1)
}

@MainActor @Test func recorderFollowsALogWithoutPersistingItsContents() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("PRIVATE-SOURCE.jsonl")
    let output = root.appendingPathComponent("recording")
    try journal("task_started").write(to: source)
    let writer = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(250))
        try append(journal("item_completed", extra: ["item": ["type": "McpToolCall", "arguments": "PRIVATE-ARGUMENT", "result": "PRIVATE-RESULT"]]), to: source)
        try append(journal("task_complete", extra: ["last_agent_message": "PRIVATE-MESSAGE"]), to: source)
    }
    defer { writer.cancel() }
    let recorder = Recorder(record: RunRecord(kind: .codexSession, title: "Codex session", seconds: 5), directory: output)
    let result = try await recorder.observeCodex(sessionURL: source)
    #expect(result.status == .completed)
    #expect(result.agent?.activityCount == 2)
    #expect(result.agent?.toolCompletions == 1)
    #expect(result.agent?.state == .turnEnded)
    #expect(result.exitCode == nil)
    for file in try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil) {
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(!content.contains("PRIVATE-"))
        #expect(!content.contains("turn-a"))
    }
}

@MainActor @Test func malformedEventsPreventAutomaticCompletion() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("selected.jsonl")
    try Data().write(to: file)
    let writer = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(200))
        try append(Data("not-json\n".utf8) + journal("task_complete"), to: file)
    }
    defer { writer.cancel() }
    let recorder = Recorder(record: RunRecord(kind: .codexSession, seconds: 2), directory: root.appendingPathComponent("out"))
    let result = try await recorder.observeCodex(sessionURL: file)
    #expect(result.status == .timedOut)
    #expect(result.agent?.streamIncomplete == true)
    #expect(result.agent?.state == .unknown)
}

@Test func oldRecordingSchemaStillDecodes() throws {
    let run = RunRecord(seconds: 3)
    var object = try #require(JSONSerialization.jsonObject(with: RecordingStore.encoder().encode(run)) as? [String: Any])
    object["schemaVersion"] = 1; object.removeValue(forKey: "agent")
    let data = try JSONSerialization.data(withJSONObject: object)
    let decoded = try RecordingStore.decoder().decode(RunRecord.self, from: data)
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.agent == nil)
}
