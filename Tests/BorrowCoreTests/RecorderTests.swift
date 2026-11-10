import Foundation
import Testing
@testable import BorrowCore

@MainActor @Test func recorderCapturesActualNonzeroProcessExit() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recorder = Recorder(record: RunRecord(kind: .command, title: "false", seconds: 3), directory: directory)
    let result = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [])
    #expect(result.exitCode == 1)
    #expect(result.findings.first { $0.title == "Command exit" }?.state == .failed)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("report.md").path))
}

@MainActor @Test func recorderDoesNotAcceptAnotherRunsArtifact() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let proofURL = directory.appendingPathComponent("worker.json")
    try RecordingStore.encoder().encode(WorkerProof(runID: UUID(), heartbeat: 9999, completed: true)).write(to: proofURL)
    let recorder = Recorder(record: RunRecord(seconds: 3), directory: directory)
    let result = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [], proofURL: proofURL)
    #expect(result.verifiedWorkerHeartbeat == nil)
    #expect(result.findings.first { $0.title == "Expected result" }?.state == .failed)
}

@MainActor @Test func cancellationIsRecordedWithoutClaimingCompletion() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recorder = Recorder(record: RunRecord(kind: .command, title: "sleep", seconds: 10), directory: directory)
    let cancel = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(200)); recorder.cancelled = true
    }
    defer { cancel.cancel() }
    let result = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
    #expect(result.status == .cancelled)
    #expect(result.exitCode == nil)
    #expect(result.events.contains { $0.kind == "cancelled" })
}

@MainActor @Test func timeoutIsDifferentFromSuccessfulCompletion() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recorder = Recorder(record: RunRecord(kind: .command, title: "sleep", seconds: 1), directory: directory)
    let result = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
    #expect(result.status == .timedOut)
    #expect(result.exitCode == nil)
}
