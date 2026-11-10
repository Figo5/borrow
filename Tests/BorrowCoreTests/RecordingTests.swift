import Foundation
import Testing
@testable import BorrowCore

@Test func openLidSuccessDoesNotClaimClosedLidSupport() {
    var run = RunRecord(seconds: 3)
    run.status = .completed; run.exitCode = 0; run.verifiedWorkerHeartbeat = 3
    run.observations = [MachineSample(time: Date(), lidClosed: false, heartbeat: 0),
                        MachineSample(time: Date(), lidClosed: false, heartbeat: 3)]
    #expect(run.findings.first { $0.title == "Work while closed" }?.state == .unverified)
    #expect(run.findings.first { $0.title == "Expected result" }?.state == .observed)
}

@Test func progressAcrossLidTransitionDoesNotCountAsClosedWork() {
    var run = RunRecord(seconds: 10)
    run.observations = [MachineSample(time: Date(), lidClosed: false, heartbeat: 0),
                        MachineSample(time: Date(), lidClosed: true, heartbeat: 8),
                        MachineSample(time: Date(), lidClosed: false, heartbeat: 10)]
    #expect(run.closedLidHeartbeats == 0)
}

@Test func closedIntervalsCountOnlyForwardWorkerProgress() {
    var run = RunRecord(seconds: 10)
    run.observations = [MachineSample(time: Date(), lidClosed: true, heartbeat: 0),
                        MachineSample(time: Date(), lidClosed: true, heartbeat: 4),
                        MachineSample(time: Date(), lidClosed: true, heartbeat: 3)]
    #expect(run.closedLidHeartbeats == 4)
    #expect(run.findings.first { $0.title == "Work while closed" }?.state == .observed)
}

@Test func samplingGapAndSleepAnnouncementLeaveContinuityUnverified() {
    var run = RunRecord(seconds: 10)
    run.observations = [MachineSample(time: Date(), lidClosed: true)]
    run.events = [RunEvent("observationGap", "fixture gap")]
    #expect(run.findings.first { $0.title == "Sleep and sampling" }?.state == .unverified)
    run.events.append(RunEvent("systemSleep", "fixture sleep"))
    #expect(run.findings.first { $0.title == "Sleep and sampling" }?.state == .unverified)
}

@Test func oneClosedSampleDoesNotEstablishCoverage() {
    var run = RunRecord(seconds: 3)
    run.observations = [MachineSample(time: Date(), lidClosed: true)]
    #expect(run.findings.first { $0.title == "Sleep and sampling" }?.state == .unverified)
}

@Test func physicalLidCloseCanShowProgressAlongsidePowerNotifications() throws {
    let url = try #require(Bundle.module.url(forResource: "physical-lid-close-2026-11-10", withExtension: "json", subdirectory: "Fixtures"))
    let record = try RecordingStore.decoder().decode(RunRecord.self, from: Data(contentsOf: url))
    #expect(record.closedLidHeartbeats == 15)
    #expect(record.verifiedWorkerHeartbeat == 30)
    #expect(record.findings.first { $0.title == "Work while closed" }?.state == .observed)
    #expect(record.findings.first { $0.title == "Expected result" }?.state == .observed)
    let power = try #require(record.findings.first { $0.title == "Sleep and sampling" })
    #expect(power.state == .unverified)
    #expect(power.detail.contains("Worker progress was also sampled"))
    #expect(power.detail.contains("No long sampling gap"))
}

@Test func successfulExitWithoutArtifactIsNotRehearsalProof() {
    var run = RunRecord(seconds: 3)
    run.status = .completed; run.exitCode = 0
    #expect(run.findings.first { $0.title == "Expected result" }?.state == .failed)
}

@Test func commandExitDoesNotCertifyAgentProgress() {
    var run = RunRecord(kind: .command, title: "fixture", seconds: 3)
    run.status = .completed; run.exitCode = 0
    #expect(run.findings.first { $0.title == "Command exit" }?.state == .observed)
    #expect(run.findings.first { $0.title == "Agent progress" }?.state == .unverified)
}

@Test func connectivityFailuresDoNotDisappearAmongSuccesses() {
    var run = RunRecord(seconds: 3, networkEnabled: true)
    run.observations = [MachineSample(time: Date(), lidClosed: true, networkReachable: true),
                        MachineSample(time: Date(), lidClosed: true, networkReachable: false)]
    #expect(run.findings.first { $0.title == "Connectivity probe" }?.state == .failed)
}

@Test func cancelledArtifactDoesNotPass() {
    var run = RunRecord(seconds: 3)
    run.status = .cancelled; run.exitCode = 0; run.verifiedWorkerHeartbeat = 3
    #expect(run.findings.first { $0.title == "Expected result" }?.state == .failed)
}

@Test func recordingsRoundTripAndExport() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    var run = RunRecord(seconds: 3)
    run.events = [RunEvent("started", "fixture")]
    try RecordingStore.save(run, to: directory)
    let decoded = try RecordingStore.read(from: directory)
    #expect(decoded.id == run.id)
    #expect(decoded.events.count == 1)
    #expect(RecordingStore.markdown(decoded).contains("Sleep settings restored — skipped"))
}
