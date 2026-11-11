import Foundation
import Testing
@testable import BorrowCore

@MainActor final class TestWakeLease: WakeLeaseControlling {
    var acquired = 0
    var released = 0
    var failAcquisition = false
    var releaseSucceeds = true
    var currentHealth: WakeLeaseHealth = .active
    var onAcquire: (() -> Void)?
    func acquire() async throws {
        acquired += 1
        onAcquire?()
        if failAcquisition { throw WakeLeaseError.unavailable }
    }
    func health() -> WakeLeaseHealth { currentHealth }
    var releaseOutcome: WakeReleaseOutcome?
    func release() async -> WakeReleaseOutcome { released += 1; return releaseOutcome ?? (releaseSucceeds ? .released : .unconfirmed) }
}

@MainActor @Test func cancellationDuringAcquisitionNeverLaunchesForegroundTask() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    lease.onAcquire = { recorder.cancelled = true }
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.status == .cancelled)
    #expect(lease.released == 1)
    #expect(run.power?.releaseReason == .cancelled)
    #expect(!run.events.contains { $0.kind == "taskStarted" })
    #expect(run.exitCode == nil)
}

@MainActor @Test func offModeDoesNotAcquireAnyLease() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(lease.acquired == 0)
    #expect(lease.released == 0)
    #expect(run.power == nil)
}

@MainActor @Test(arguments: ["/usr/bin/true", "/usr/bin/false"])
func foregroundExitReleasesBeforeFinalPersistence(executable: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease()
    var finalSaveSawRelease = false
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
        leaseFactory: { _, _, _ in lease }, saveRecord: { run, directory in
            if run.status != .running { finalSaveSawRelease = run.power?.state == .released && lease.released == 1 }
            try RecordingStore.save(run, to: directory)
        })
    let run = try await recorder.run(executable: URL(fileURLWithPath: executable), arguments: [])
    #expect(lease.acquired == 1)
    #expect(lease.released == 1)
    #expect(finalSaveSawRelease)
    #expect(run.power?.acquiredAt != nil)
    #expect(run.power?.releasedAt != nil)
    #expect(run.power?.releaseReason == .completed)
    #expect(RecordingStore.markdown(run).contains("Actual post-task sleep — unverified"))
}

@MainActor @Test func failedAcquisitionDoesNotLaunchTaskOrClaimProtection() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.failAcquisition = true
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .experimentalAC), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.status == .interrupted)
    #expect(run.power?.state == .released)
    #expect(run.power?.issue == .acquisitionFailed)
    #expect(run.power?.acquiredAt == nil)
    #expect(!run.events.contains { $0.kind == "taskStarted" })
}

@MainActor @Test func cancellationAndTimeoutReleaseTheirOwnHold() async throws {
    for cancelled in [true, false] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lease = TestWakeLease()
        let recorder = Recorder(record: RunRecord(kind: .command, seconds: 1, wakeMode: .idle), directory: directory,
                                leaseFactory: { _, _, _ in lease })
        recorder.cancelled = cancelled
        let run = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
        #expect(lease.released == (cancelled ? 0 : 1))
        #expect(run.power?.cleanup == (cancelled ? .nothingHeld : .released))
        #expect(run.power?.releaseReason == (cancelled ? nil : .timedOut))
        #expect(run.exitCode == nil)
    }
}

@MainActor @Test func launchFailureAndSaveFailureStillRelease() async throws {
    enum Failure: Error { case storage }
    for storageFails in [true, false] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lease = TestWakeLease()
        var saves = 0
        let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
            leaseFactory: { _, _, _ in lease }, saveRecord: { run, directory in
                saves += 1
                if storageFails && saves > 1 { throw Failure.storage }
                try RecordingStore.save(run, to: directory)
            })
        do {
            _ = try await recorder.run(executable: URL(fileURLWithPath: storageFails ? "/usr/bin/true" : "/missing/borrow-test"), arguments: [])
            Issue.record("Expected a launch or persistence error")
        } catch { }
        #expect(lease.acquired == 1)
        #expect(lease.released == 1)
    }
}

@MainActor @Test(arguments: [WakeLeaseHealth.lost, .powerDisconnected, .expired])
func lossOfProtectionEndsRecordingWithoutInventingSuccess(health: WakeLeaseHealth) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.currentHealth = health
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .experimentalAC), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
    #expect(run.status == .interrupted)
    #expect(run.power?.issue != nil)
    #expect(run.power?.state == .released)
    #expect(lease.released == 1)
    #expect(run.exitCode == nil)
}

@MainActor @Test func unknownEvidenceStopsConservativelyWithoutClaimingUnplugOrLoss() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.currentHealth = .unknown
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .experimentalAC), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
    #expect(run.status == .interrupted)
    #expect(run.power?.issue == .stateUnknown)
    #expect(run.power?.releaseReason == .stateUnknown)
    #expect(run.power?.state == .released)
    #expect(run.power?.cleanup == .released)
    #expect(lease.released == 1)
    #expect(run.exitCode == nil)
    #expect(run.events.contains { $0.kind == "wakeStateUnknown" })
    #expect(!run.events.contains { $0.kind == "wakeLost" })
    let report = RecordingStore.markdown(run)
    #expect(report.contains("stateUnknown"))
    #expect(!report.contains("powerDisconnected"))
    #expect(!report.contains("holdLost"))
}

@MainActor @Test func confirmedReadingsKeepTheirSpecificReasons() async throws {
    for (health, issue, reason) in [(WakeLeaseHealth.powerDisconnected, WakeLeaseIssue.powerDisconnected, WakeReleaseReason.powerDisconnected),
                                    (.lost, .assertionLost, .holdLost), (.expired, .expired, .expired)] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lease = TestWakeLease(); lease.currentHealth = health
        let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .experimentalAC), directory: directory,
                                leaseFactory: { _, _, _ in lease })
        let run = try await recorder.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
        #expect(run.power?.issue == issue)
        #expect(run.power?.releaseReason == reason)
        #expect(run.events.contains { $0.kind == "wakeLost" })
    }
}

@MainActor @Test func nilPowerSourceOrAssertionInventoryIsUnknownNotUnplugOrLoss() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    backend.ac = nil
    #expect(lease.health() == .unknown)
    backend.ac = false
    #expect(lease.health() == .powerDisconnected)
    backend.ac = true; backend.helperAssertion = nil
    #expect(lease.health() == .unknown)
    backend.helperAssertion = false
    #expect(lease.health() == .lost)
    backend.helperAssertion = true
    #expect(lease.health() == .active)
    #expect(await lease.release() == .released)
}

@MainActor @Test func helperCleanupWithUnreadableInventoryIsUnconfirmed() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    backend.helperAbsenceUnknown = true
    #expect(await lease.release() == .unconfirmed)
    #expect(await lease.release() == .unconfirmed)
    #expect(backend.helperStops == 1)
}

@MainActor @Test func acquisitionFailureWithNothingHeldIsNotReportedAsARelease() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.failAcquisition = true; lease.releaseOutcome = .nothingHeld
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .experimentalAC), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.status == .interrupted)
    #expect(run.power?.state == .failed)
    #expect(run.power?.issue == .acquisitionFailed)
    #expect(run.power?.cleanup == .nothingHeld)
    #expect(run.power?.releasedAt == nil)
    #expect(run.power?.acquiredAt == nil)
    #expect(!run.events.contains { $0.kind == "wakeReleased" })
    #expect(!run.events.contains { $0.kind == "taskStarted" })
    #expect(run.findings.first { $0.title == "Borrow wake hold" }?.state == .failed)
    let release = try #require(run.findings.first { $0.title == "Borrow wake hold released" })
    #expect(release.state == .skipped)
    #expect(release.detail.contains("No Borrow-owned hold was created"))
    let saved = try RecordingStore.read(from: directory)
    #expect(saved.power?.cleanup == .nothingHeld)
    #expect(saved.power?.state == .failed)
}

@MainActor @Test func acquisitionFailureKeepsItsIssueWhenProvisionalHoldIsCleaned() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.failAcquisition = true; lease.releaseOutcome = .released
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.power?.state == .released)
    #expect(run.power?.cleanup == .released)
    #expect(run.power?.issue == .acquisitionFailed)
    #expect(run.power?.releasedAt != nil)
    #expect(run.events.contains { $0.kind == "wakeReleased" })
    #expect(run.findings.first { $0.title == "Borrow wake hold" }?.state == .failed)
    #expect(run.findings.first { $0.title == "Borrow wake hold released" }?.state == .observed)
}

@MainActor @Test func normalAndUnconfirmedCleanupAreRecorded() async throws {
    for outcome in [WakeReleaseOutcome.released, .unconfirmed] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lease = TestWakeLease(); lease.releaseOutcome = outcome
        let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
                                leaseFactory: { _, _, _ in lease })
        let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
        #expect(run.power?.cleanup == outcome)
        #expect(run.power?.state == (outcome == .released ? .released : .failed))
        #expect((run.power?.releasedAt != nil) == (outcome == .released))
    }
}

@Test func cleanupFieldIsOptionalForOlderRecordings() throws {
    var fresh = RunRecord(seconds: 30, wakeMode: .idle, startedAt: Date(timeIntervalSince1970: 1))
    let legacy = try RecordingStore.encoder().encode(fresh)
    #expect(!String(decoding: legacy, as: UTF8.self).contains("cleanup"))
    #expect(try RecordingStore.decoder().decode(RunRecord.self, from: legacy).power?.cleanup == nil)
    fresh.power?.cleanup = .nothingHeld
    let decoded = try RecordingStore.decoder().decode(RunRecord.self, from: RecordingStore.encoder().encode(fresh))
    #expect(decoded.power?.cleanup == .nothingHeld)
    #expect(WakeReleaseOutcome(rawValue: "unconfirmed") == .unconfirmed)
}

@MainActor @Test func releaseFailureIsNeverReportedAsReleased() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let lease = TestWakeLease(); lease.releaseSucceeds = false
    let recorder = Recorder(record: RunRecord(kind: .command, seconds: 3, wakeMode: .idle), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    let run = try await recorder.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    #expect(run.power?.state == .failed)
    #expect(run.power?.issue == .releaseUnconfirmed)
    #expect(run.power?.releasedAt == nil)
    #expect(run.findings.first { $0.title == "Borrow wake hold released" }?.state == .failed)
}

@Test func powerEvidenceRoundTripsAndOldRecordingsKeepMeaning() throws {
    let legacyURL = try #require(Bundle.module.url(forResource: "physical-lid-close-2026-11-10", withExtension: "json", subdirectory: "Fixtures"))
    let old = try RecordingStore.decoder().decode(RunRecord.self, from: Data(contentsOf: legacyURL))
    #expect(old.power == nil)
    #expect(old.findings.first { $0.title == "Sleep settings restored" }?.state == .skipped)
    let fresh = RunRecord(seconds: 30, wakeMode: .idle, startedAt: Date(timeIntervalSince1970: 1))
    let decoded = try RecordingStore.decoder().decode(RunRecord.self, from: RecordingStore.encoder().encode(fresh))
    #expect(decoded.power?.mode == .idle)
    #expect(decoded.power?.state == .requested)
    #expect(decoded.power?.deadline == fresh.power?.deadline)
}

@MainActor final class TestWakeBackend: WakeLeaseBackend {
    var ac: Bool? = true
    var idle: Bool? = true
    var createSucceeds = true
    var releaseSucceeds = true
    var releaseCalls = 0
    var helperStarts = 0
    var helperStops = 0
    var helperRunning = false
    var helperAssertion: Bool? = true
    var helperPID: Int32? { helperStarts > 0 ? 12345 : nil }
    var failLaunch = false
    var timeout: TimeInterval?
    var name: String?
    var ownerPID: Int32?
    func onACPower() -> Bool? { ac }
    func createIdle(name: String, timeout: TimeInterval) -> UInt32? {
        self.name = name; self.timeout = timeout
        return createSucceeds ? 42 : nil
    }
    func idleActive(_ assertion: UInt32) -> Bool? { idle }
    func releaseIdle(_ assertion: UInt32) -> Bool {
        releaseCalls += 1
        if releaseSucceeds { idle = false }
        return releaseSucceeds
    }
    func startExperimental(ownerPID: Int32, timeout: Int) throws {
        if failLaunch { throw WakeLeaseError.unavailable }
        helperStarts += 1; helperRunning = true; self.ownerPID = ownerPID; self.timeout = TimeInterval(timeout)
    }
    var helperAbsenceUnknown = false
    func helperAssertionActive() -> Bool? { helperRunning ? helperAssertion : (helperAbsenceUnknown ? nil : false) }
    func terminateHelper() { helperStops += 1; helperRunning = false }
}

@MainActor @Test func idleLeaseIsBoundedOwnedAndIdempotentlyReleased() async throws {
    let backend = TestWakeBackend()
    let id = UUID()
    let lease = SystemWakeLease(mode: .idle, runID: id, deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    #expect(lease.health() == .active)
    #expect(backend.name == "Borrow \(id.uuidString)")
    #expect(try #require(backend.timeout) > 0)
    #expect(try #require(backend.timeout) <= 5)
    #expect(await lease.release() == .released)
    #expect(await lease.release() == .released)
    lease.releaseFallback()
    #expect(backend.releaseCalls == 1)
    #expect(lease.health() == .lost)
}

@MainActor @Test func idleLeaseRequiresConfirmedAssertionAndCleansProvisionalHold() async throws {
    for createSucceeds in [false, true] {
        let backend = TestWakeBackend(); backend.createSucceeds = createSucceeds; backend.idle = false
        let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
        do { try await lease.acquire(); Issue.record("Unconfirmed assertion must fail") } catch { }
        // Nothing created is not a release; a provisional assertion confirmed absent is.
        #expect(await lease.release() == (createSucceeds ? .released : .nothingHeld))
        #expect(await lease.release() == (createSucceeds ? .released : .nothingHeld))
        #expect(backend.releaseCalls == (createSucceeds ? 1 : 0))
    }
}

@MainActor @Test func assertionLossAndReleaseFailureRemainUnknown() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    backend.idle = nil
    #expect(lease.health() == .unknown)
    backend.idle = false
    #expect(lease.health() == .lost)
    backend.idle = nil
    backend.releaseSucceeds = false
    #expect(await lease.release() == .unconfirmed)
    #expect(await lease.release() == .unconfirmed)
    #expect(backend.releaseCalls == 1)
}

@MainActor @Test func experimentalLeaseRequiresKnownACBeforeLaunchingHelper() async throws {
    for ac: Bool? in [false, nil] {
        let backend = TestWakeBackend(); backend.ac = ac
        let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
        do { try await lease.acquire(); Issue.record("AC is required") } catch { }
        #expect(backend.helperStarts == 0)
        #expect(await lease.release() == .nothingHeld)
        #expect(backend.helperStops == 0)
    }
}

@MainActor @Test func experimentalHelperHasOwnerAndTimeoutAndLosesProtectionOnUnplug() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    #expect(backend.ownerPID == ProcessInfo.processInfo.processIdentifier)
    #expect(try #require(backend.timeout) > 0)
    #expect(try #require(backend.timeout) <= 5)
    #expect(lease.health() == .active)
    backend.ac = false
    #expect(lease.health() == .powerDisconnected)
    #expect(await lease.release() == .released)
    #expect(await lease.release() == .released)
    #expect(backend.helperStops == 1)
}

@MainActor @Test func helperExitIsNotActiveProtection() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    try await lease.acquire()
    backend.helperRunning = false
    #expect(lease.health() == .lost)
    #expect(await lease.release() == .released)
}

@MainActor @Test func launchedHelperWithoutAssertionIsNotProtection() async throws {
    let backend = TestWakeBackend(); backend.helperAssertion = false
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    do { try await lease.acquire(); Issue.record("Process presence is insufficient") } catch { }
    #expect(backend.helperStarts == 1)
    #expect(lease.health() == .lost)
    #expect(await lease.release() == .released)
    #expect(backend.helperStops == 1)
}

@MainActor @Test func helperLaunchFailureAndFallbackRemainBounded() async throws {
    let backend = TestWakeBackend(); backend.failLaunch = true
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: backend)
    do { try await lease.acquire(); Issue.record("Launch failure must propagate") } catch { }
    #expect(await lease.release() == .nothingHeld)
    let fallbackBackend = TestWakeBackend()
    let fallback = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(5), backend: fallbackBackend)
    try await fallback.acquire()
    fallback.releaseFallback()
    #expect(fallbackBackend.helperStops == 1)
    #expect(fallback.health() == .lost)
}

@MainActor @Test func elapsedDeadlineEndsLeaseAndPastDeadlineNeverAcquires() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(0.05), backend: backend)
    try await lease.acquire()
    try await Task.sleep(for: .milliseconds(70))
    #expect(lease.health() == .expired)
    #expect(await lease.release() == .released)
    for mode in WakeMode.allCases {
        let expired = SystemWakeLease(mode: mode, runID: UUID(), deadline: Date.distantPast, backend: TestWakeBackend())
        do { try await expired.acquire(); Issue.record("Expired leases cannot start") } catch { }
    }
}

@MainActor @Test func idleOSTimeoutRoundsUpSoItCannotExpireBeforeRecordingDeadline() async throws {
    let backend = TestWakeBackend()
    let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(2.5), backend: backend)
    try await lease.acquire()
    #expect(backend.timeout == 3)
    #expect(await lease.release() == .released)
}

@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["BORROW_POWER_INTEGRATION"] == "1"))
func nativeIdleHoldAcquiresAndReleasesOnlyItsOwnAssertion() async throws {
    let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(3))
    do {
        try await lease.acquire()
        #expect(lease.health() == .active)
        #expect(await lease.release() == .released)
        #expect(lease.health() == .lost)
    } catch { _ = await lease.release(); throw error }
}

@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["BORROW_POWER_INTEGRATION"] == "1"))
func nativeIdleOSExpiryIsConfirmedAbsentBeforeClaimingRelease() async throws {
    let lease = SystemWakeLease(mode: .idle, runID: UUID(), deadline: Date().addingTimeInterval(0.5))
    do {
        try await lease.acquire()
        try await Task.sleep(for: .milliseconds(1300))
        #expect(lease.health() == .expired)
        #expect(await lease.release() == .released)
    } catch { _ = await lease.release(); throw error }
}

@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["BORROW_POWER_INTEGRATION"] == "1" && MachineProbe.onACPower() == true))
func nativeExperimentalHoldConfirmsItsOwnHelperAssertionAndRelease() async throws {
    let lease = SystemWakeLease(mode: .experimentalAC, runID: UUID(), deadline: Date().addingTimeInterval(3))
    do {
        try await lease.acquire()
        #expect(lease.health() == .active)
        #expect(await lease.release() == .released)
        #expect(lease.health() == .lost)
    } catch { _ = await lease.release(); throw error }
}

@MainActor @Test(arguments: ["turn.completed", "turn.failed", "turn.interrupted", "source-loss", "malformed", "cancelled"])
func observationTerminalPathsReleaseWithoutOwningAgent(outcome: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    try Data().write(to: source)
    defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: source) }
    let lease = TestWakeLease()
    let recorder = Recorder(record: RunRecord(kind: .codexSession, seconds: 2, wakeMode: .idle), directory: directory,
                            leaseFactory: { _, _, _ in lease })
    recorder.cancelled = outcome == "cancelled"
    let update = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(100))
        if outcome == "source-loss" { try FileManager.default.removeItem(at: source) }
        else {
            let content = outcome == "malformed" ? "{bad\n" : "{\"type\":\"\(outcome)\",\"message\":\"PRIVATE-OUTPUT\"}\n"
            let writer = try FileHandle(forWritingTo: source)
            try writer.seekToEnd(); try writer.write(contentsOf: Data(content.utf8)); try writer.close()
        }
    }
    defer { update.cancel() }
    let run = try await recorder.observeCodex(sessionURL: source)
    #expect(lease.acquired == (outcome == "cancelled" ? 0 : 1))
    #expect(lease.released == (outcome == "cancelled" ? 0 : 1))
    #expect(run.power?.cleanup == (outcome == "cancelled" ? .nothingHeld : .released))
    #expect(run.exitCode == nil)
    #expect(!run.events.contains { $0.kind == "taskStarted" })
    if outcome == "source-loss" { #expect(run.power?.releaseReason == .sourceLost) }
    if outcome == "malformed" { #expect(run.status == .timedOut) }
    #expect(!RecordingStore.markdown(run).contains("PRIVATE-"))
}
