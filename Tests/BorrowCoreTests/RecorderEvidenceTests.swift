import Foundation
import Testing
@testable import BorrowCore

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

// MARK: Strict time limit

@MainActor @Test func expiredSetupNeverAttemptsAnUnacquirableHold() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.failAcquisition = true
    var factoryCalls = 0
    let recorder = Recorder(
        record: RunRecord(kind: .command, seconds: 1, wakeMode: .idle, startedAt: Date().addingTimeInterval(-5)),
        directory: directory, leaseFactory: { _, _, _ in factoryCalls += 1; return lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.status == .timedOut)
    #expect(factoryCalls == 0)
    #expect(run.power?.cleanup == .nothingHeld)
    #expect(!run.events.contains { $0.kind == "wakeAcquisitionFailed" || $0.kind == "taskStarted" })
}

/// The limit falls between two recorder samples (0.5 s after launch; samples are about 1 s apart) and the child
/// exits after the limit but before the next sample. That is what a suspended or blocked recorder sees on resume:
/// a process that is already gone, first observed past the deadline. Backdating the start keeps this deterministic
/// without blocking the shared main actor or touching any process the test does not own.
private func recordWithDeadlineSoon(kind: RunKind) -> RunRecord {
    RunRecord(kind: kind, title: "fixture", seconds: 3, startedAt: Date().addingTimeInterval(-2.5))
}

@MainActor @Test func exitFirstObservedAfterDeadlineIsNotTimelyCompletion() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let recorder = Recorder(record: recordWithDeadlineSoon(kind: .command), directory: directory)
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["0.75"])
    #expect(run.observations.count == 2)
    #expect(run.events.contains { $0.kind == "taskStarted" })
    #expect(run.status == .timedOut)
    #expect(run.exitCode == nil)
    #expect(!run.events.contains { $0.kind == "taskExited" })
    #expect(run.events.contains { $0.kind == "timeout" })
    #expect(run.findings.first { $0.title == "Command exit" }?.state == .unverified)
    #expect(try RecordingStore.read(from: directory).status == .timedOut)
}

@MainActor @Test func codexTerminalEventFirstObservedAfterDeadlineIsNotTimelyCompletion() async throws {
    let directory = temporaryDirectory()
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    try Data().write(to: source)
    defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: source) }
    var saves = 0
    let recorder = Recorder(record: recordWithDeadlineSoon(kind: .codexSession), directory: directory,
        saveRecord: { run, directory in
            saves += 1
            // The first periodic write happens after the first poll, so this record is first seen by the second
            // poll, about a second later and past the limit.
            if saves == 2 {
                let writer = try FileHandle(forWritingTo: source)
                try writer.seekToEnd()
                try writer.write(contentsOf: Data("{\"type\":\"turn.completed\",\"message\":\"PRIVATE-OUTPUT\"}\n".utf8))
                try writer.close()
            }
            try RecordingStore.save(run, to: directory)
        })
    let run = try await recorder.observeCodex(sessionURL: source)
    #expect(run.status == .timedOut)
    // The logged outcome is still recorded as an observed event; only the timeliness claim is withheld.
    #expect(run.agent?.state == .turnEnded)
    #expect(run.events.contains { $0.kind == "timeout" && $0.detail.contains("first seen after the limit") })
    #expect(!run.events.contains { $0.kind == "agentObservationEnded" })
    #expect(!RecordingStore.markdown(run).contains("PRIVATE-"))
}

@MainActor @Test func taskIsNeverLaunchedOnceDeadlineAlreadyPassed() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    let record = RunRecord(kind: .command, seconds: 1, wakeMode: .idle, startedAt: Date().addingTimeInterval(-5))
    let recorder = Recorder(record: record, directory: directory, leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.status == .timedOut)
    #expect(!run.events.contains { $0.kind == "taskStarted" })
    #expect(run.exitCode == nil)
    #expect(run.endedAt != nil)
    #expect(lease.acquired == 0)
    #expect(lease.released == 0)
    #expect(run.power?.cleanup == .nothingHeld)
    #expect(run.power?.releaseReason == nil)
    #expect(try RecordingStore.read(from: directory).status == .timedOut)
}

@MainActor @Test func timelyExitStillCompletesAndCancellationStaysExplicit() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let timely = try await Recorder(record: RunRecord(kind: .command, seconds: 5), directory: directory)
        .run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(timely.status == .completed)
    #expect(timely.exitCode == 0)
    // An explicit stop is reported as a stop even when the limit has also passed.
    let late = Recorder(record: RunRecord(kind: .command, seconds: 1, startedAt: Date().addingTimeInterval(-5)), directory: directory)
    late.cancelled = true
    let stopped = try await late.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(stopped.status == .cancelled)
    #expect(!stopped.events.contains { $0.kind == "taskStarted" })
}

// MARK: Persistence errors

private enum StorageFailure: Error { case disk }

@MainActor @Test func transientWriteFailureDoesNotLeaveAnActiveSnapshot() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    var saves = 0
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
        leaseFactory: { _, _, _ in lease }, saveRecord: { run, directory in
            saves += 1
            // 1 = started, 2 = wake acquired, 3 = first periodic write after launch (fails once).
            if saves == 3 { throw StorageFailure.disk }
            try RecordingStore.save(run, to: directory)
        })
    do {
        _ = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
        Issue.record("A mid-run write failure must surface")
    } catch { #expect(error is RecorderError) }
    #expect(lease.released == 1)
    #expect(saves == 4)
    let snapshot = try RecordingStore.read(from: directory)
    #expect(snapshot.status == .interrupted)
    #expect(snapshot.endedAt != nil)
    #expect(snapshot.power?.state == .released)
    #expect(snapshot.exitCode == nil)
    let report = try String(contentsOf: directory.appendingPathComponent("report.md"), encoding: .utf8)
    let json = try String(contentsOf: directory.appendingPathComponent("recording.json"), encoding: .utf8)
    for text in [report, json] {
        #expect(!text.contains("StorageFailure"))
        #expect(!text.contains(directory.path))
        #expect(!text.contains("disk"))
    }
}

@MainActor @Test func persistentWriteFailureStillThrowsSanitizedErrorAfterOneFinalAttempt() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    var saves = 0
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
        leaseFactory: { _, _, _ in lease }, saveRecord: { run, directory in
            saves += 1
            if saves >= 3 { throw StorageFailure.disk }
            try RecordingStore.save(run, to: directory)
        })
    do {
        _ = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
        Issue.record("A persistent write failure must surface")
    } catch {
        let known = try #require(error as? RecorderError)
        #expect(!(known.errorDescription ?? "").contains(directory.path))
        #expect(!(known.errorDescription ?? "").contains("StorageFailure"))
    }
    #expect(saves == 4) // exactly one best-effort final attempt
    #expect(lease.released == 1)
}

// MARK: Stale exports

@Test func runningSnapshotWithoutRecentSampleOrPastDeadlineIsExplicitlyStale() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    var run = RunRecord(kind: .command, title: "fixture", seconds: 60, wakeMode: .idle, startedAt: start)
    run.power?.state = .active; run.power?.acquiredAt = start
    run.observations = [MachineSample(time: start.addingTimeInterval(20), lidClosed: false)]

    let fresh = run.findings(at: start.addingTimeInterval(30))
    #expect(!fresh.contains { $0.title == "Snapshot freshness" })
    #expect(fresh.first { $0.title == "Borrow wake hold" }?.detail.contains("not current protection") == false)

    let quiet = run.findings(at: start.addingTimeInterval(31))
    let gap = try #require(quiet.first { $0.title == "Snapshot freshness" })
    #expect(gap.state == .unverified)
    #expect(gap.detail.contains("11 seconds"))
    #expect(gap.detail.contains("cause is unknown"))
    let hold = try #require(quiet.first { $0.title == "Borrow wake hold" })
    #expect(hold.detail.contains("Last recorded state: active"))
    #expect(hold.detail.contains("not current protection"))
    #expect(quiet.first { $0.title == "Command exit" }?.state == .unverified)
    #expect(quiet.first { $0.title == "Actual post-task sleep" }?.state == .unverified)

    run.observations.append(MachineSample(time: start.addingTimeInterval(59), lidClosed: false))
    #expect(!run.findings(at: start.addingTimeInterval(59.5)).contains { $0.title == "Snapshot freshness" })
    let overdue = try #require(run.findings(at: start.addingTimeInterval(60)).first { $0.title == "Snapshot freshness" })
    #expect(overdue.state == .unverified)
    #expect(overdue.detail.contains("time limit"))

    let report = RecordingStore.markdown(run, now: start.addingTimeInterval(3600))
    #expect(report.contains("Snapshot freshness — unverified"))
    #expect(report.contains("Status: running (stale snapshot"))
    #expect(!RecordingStore.markdown(run, now: start.addingTimeInterval(59.5)).contains("stale"))

    // A finished recording is history by definition and never becomes "stale".
    run.status = .timedOut; run.endedAt = start.addingTimeInterval(60)
    #expect(!run.findings(at: start.addingTimeInterval(3600)).contains { $0.title == "Snapshot freshness" })
    #expect(!RecordingStore.markdown(run, now: start.addingTimeInterval(3600)).contains("stale"))
}

@Test func staleSnapshotNeverInfersSleepCompletionOrSuccess() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    var rehearsal = RunRecord(seconds: 30, startedAt: start)
    rehearsal.verifiedWorkerHeartbeat = 30; rehearsal.exitCode = 0
    let findings = rehearsal.findings(at: start.addingTimeInterval(500))
    #expect(findings.first { $0.title == "Expected result" }?.state == .unverified)
    let stale = findings.first { $0.title == "Snapshot freshness" }
    #expect(stale?.state == .unverified)
    #expect(stale?.detail.contains("No sleep") == true)
    // The compatibility property still works and evaluates against the current clock.
    #expect(rehearsal.findings.contains { $0.title == "Snapshot freshness" })
}

// MARK: Pending Codex records

private func append(_ text: String, to url: URL) throws {
    let writer = try FileHandle(forWritingTo: url)
    try writer.seekToEnd(); try writer.write(contentsOf: Data(text.utf8)); try writer.close()
}

@MainActor @Test(arguments: [true, false])
func observedAgentIsNotFinishedWhileARecordIsPending(tailStartsNewTurn: Bool) async throws {
    let directory = temporaryDirectory()
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    try Data().write(to: source)
    defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: source) }
    let recorder = Recorder(record: RunRecord(kind: .codexSession, seconds: 4), directory: directory)
    let update = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(200))
        // A terminal record followed by the beginning of another record whose meaning is not yet known.
        try append("{\"type\":\"turn.completed\"}\n{\"type\":\"" + (tailStartsNewTurn ? "turn.started" : "note"), to: source)
        try await Task.sleep(for: .milliseconds(1500))
        try append("\",\"message\":\"PRIVATE-OUTPUT\"}\n", to: source)
    }
    defer { update.cancel() }
    let run = try await recorder.observeCodex(sessionURL: source)
    if tailStartsNewTurn {
        // Finishing on the first poll would have released a hold while a new turn was already being written.
        #expect(run.status == .timedOut)
        #expect(run.agent?.state == .working, "events: \(run.events.map(\.kind)) agent: \(String(describing: run.agent))")
        #expect(!run.events.contains { $0.kind == "agentObservationEnded" })
    } else {
        // The earlier terminal result is reconsidered once the tail completes, without a new lifecycle signal.
        #expect(run.status == .completed)
        #expect(run.agent?.state == .turnEnded)
        #expect(run.events.filter { $0.kind.hasPrefix("agent.") }.count == 1)
        #expect(run.agent?.streamIncomplete == false)
    }
    #expect(!RecordingStore.markdown(run).contains("PRIVATE-"))
}

@MainActor @Test func observedAgentNeverFinishesFromHistoricalStateAlone() async throws {
    let directory = temporaryDirectory()
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    try Data("{\"type\":\"turn.completed\"}\n".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: source) }
    let run = try await Recorder(record: RunRecord(kind: .codexSession, seconds: 1), directory: directory).observeCodex(sessionURL: source)
    #expect(run.status == .timedOut)
    #expect(run.agent?.state == .unknown)
}
