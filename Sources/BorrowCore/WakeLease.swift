import Darwin
import Foundation
import IOKit.pwr_mgt

public enum WakeMode: String, Codable, CaseIterable, Identifiable {
    case off
    case idle
    case experimentalAC = "experimental-ac"
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .off: return "Off"
        case .idle: return "Prevent idle sleep"
        case .experimentalAC: return "Experimental AC hold"
        }
    }
    public var detail: String {
        switch self {
        case .off: return "Record only. Borrow requests no wake hold."
        case .idle: return "Prevents idle system sleep until this recording ends. Lid close can still sleep the Mac."
        case .experimentalAC: return "AC power required. Uses Apple's caffeinate system hold; closed-lid behavior is experimental and must be measured on your setup."
        }
    }
}

public enum WakeLeaseState: String, Codable { case requested, active, released, failed }
public enum WakeReleaseReason: String, Codable {
    case completed, cancelled, timedOut, sourceLost, powerDisconnected, holdLost, expired, launchFailed, error
    /// Borrow could not read its power source or assertion inventory. Nothing is claimed about an unplug or a lost hold.
    case stateUnknown
}
public enum WakeLeaseIssue: String, Codable {
    case acquisitionFailed, assertionLost, powerDisconnected, expired, releaseUnconfirmed, stateUnknown
}
/// `unknown` means the evidence itself was unavailable; `lost` and `powerDisconnected` require a confirmed reading.
public enum WakeLeaseHealth: Equatable { case active, expired, powerDisconnected, lost, unknown }
/// What cleanup established about Borrow's own hold. `nothingHeld` means no assertion or helper was ever created.
public enum WakeReleaseOutcome: String, Codable { case released, nothingHeld, unconfirmed }

public struct PowerEvidence: Codable {
    public var mode: WakeMode
    public var state: WakeLeaseState = .requested
    public var deadline: Date
    public var acquiredAt: Date?
    public var releasedAt: Date?
    public var releaseReason: WakeReleaseReason?
    public var issue: WakeLeaseIssue?
    /// Optional so recordings written before this field existed still decode.
    public var cleanup: WakeReleaseOutcome?
    public init(mode: WakeMode, deadline: Date) { self.mode = mode; self.deadline = deadline }
}

public enum WakeLeaseError: LocalizedError {
    case unavailable
    public var errorDescription: String? { "Borrow could not confirm its requested wake hold. No task was started." }
}

@MainActor public protocol WakeLeaseControlling: AnyObject {
    func acquire() async throws
    func health() -> WakeLeaseHealth
    func release() async -> WakeReleaseOutcome
    func releaseFallback()
}
public extension WakeLeaseControlling { func releaseFallback() {} }

/// Small boundary for deterministic lifecycle tests. Its real implementation touches only owned assertions/helpers.
@MainActor protocol WakeLeaseBackend: AnyObject {
    func onACPower() -> Bool?
    func createIdle(name: String, timeout: TimeInterval) -> UInt32?
    func idleActive(_ assertion: UInt32) -> Bool?
    func releaseIdle(_ assertion: UInt32) -> Bool
    func startExperimental(ownerPID: Int32, timeout: Int) throws
    var helperPID: Int32? { get }
    var helperRunning: Bool { get }
    func helperAssertionActive() -> Bool?
    func terminateHelper()
}

@MainActor public final class SystemWakeLease: WakeLeaseControlling {
    private let mode: WakeMode
    private let runID: UUID
    private let deadline: Date
    private let backend: any WakeLeaseBackend
    private var idleID: UInt32?
    private var helperStarted = false
    private var acquired = false
    private var releaseResult: WakeReleaseOutcome?

    public convenience init(mode: WakeMode, runID: UUID, deadline: Date) {
        self.init(mode: mode, runID: runID, deadline: deadline, backend: NativeWakeLeaseBackend())
    }
    init(mode: WakeMode, runID: UUID, deadline: Date, backend: any WakeLeaseBackend) {
        self.mode = mode; self.runID = runID; self.deadline = deadline; self.backend = backend
    }

    public func acquire() async throws {
        guard !acquired, releaseResult == nil, deadline > Date(), mode != .off else { throw WakeLeaseError.unavailable }
        let remaining = deadline.timeIntervalSinceNow
        switch mode {
        case .off: throw WakeLeaseError.unavailable
        case .idle:
            guard let id = backend.createIdle(name: "Borrow \(runID.uuidString)", timeout: ceil(remaining)) else { throw WakeLeaseError.unavailable }
            idleID = id
            guard backend.idleActive(id) == true else { throw WakeLeaseError.unavailable }
        case .experimentalAC:
            guard backend.onACPower() == true else { throw WakeLeaseError.unavailable }
            do {
                try backend.startExperimental(ownerPID: ProcessInfo.processInfo.processIdentifier, timeout: max(1, Int(ceil(remaining))))
                helperStarted = true
            } catch { throw WakeLeaseError.unavailable }
            // A Process.run success is not assertion evidence. Allow powerd a short bounded registration interval.
            var confirmed = false
            for _ in 0..<20 {
                guard backend.onACPower() == true, backend.helperRunning, Date() < deadline else { break }
                if backend.helperAssertionActive() == true { confirmed = true; break }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard confirmed else { throw WakeLeaseError.unavailable }
        }
        acquired = true
    }

    public func health() -> WakeLeaseHealth {
        guard acquired, releaseResult == nil else { return .lost }
        if Date() >= deadline { return .expired }
        switch mode {
        case .off: return .lost
        case .idle:
            guard let idleID else { return .lost }
            // An unreadable assertion inventory is missing evidence, not a confirmed loss.
            switch backend.idleActive(idleID) {
            case true?: return .active
            case false?: return .lost
            case nil: return .unknown
            }
        case .experimentalAC:
            // Only a confirmed battery reading is an unplug; an unreadable power source stays unknown.
            switch backend.onACPower() {
            case nil: return .unknown
            case false?: return .powerDisconnected
            case true?: break
            }
            guard backend.helperRunning else { return .lost }
            switch backend.helperAssertionActive() {
            case true?: return .active
            case false?: return .lost
            case nil: return .unknown
            }
        }
    }

    public func release() async -> WakeReleaseOutcome {
        if let releaseResult { return releaseResult }
        let outcome: WakeReleaseOutcome
        if let idleID {
            // Covers provisional assertions too: one that was created but never confirmed is still Borrow's to clean.
            // The release call's return value is not evidence; only a readable inventory without the assertion is.
            _ = backend.releaseIdle(idleID)
            let absent = backend.idleActive(idleID) == false
            self.idleID = nil
            outcome = absent ? .released : .unconfirmed
        } else if helperStarted {
            backend.terminateHelper()
            var absent = false
            for _ in 0..<20 {
                if !backend.helperRunning, backend.helperAssertionActive() == false { absent = true; break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            outcome = absent ? .released : .unconfirmed
        } else {
            // No assertion or helper was ever created, so there is nothing to release and nothing to claim.
            outcome = .nothingHeld
        }
        releaseResult = outcome
        acquired = false
        return outcome
    }

    public func releaseFallback() {
        guard releaseResult == nil else { return }
        if let idleID { _ = backend.releaseIdle(idleID); self.idleID = nil }
        if helperStarted { backend.terminateHelper() }
        acquired = false
    }
}

@MainActor private final class NativeWakeLeaseBackend: WakeLeaseBackend {
    private var helper: Process?
    private var idleNames: [UInt32: String] = [:]
    func onACPower() -> Bool? { MachineProbe.onACPower() }
    func createIdle(name: String, timeout: TimeInterval) -> UInt32? {
        let properties: [String: Any] = [
            kIOPMAssertionTypeKey: kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionNameKey: name,
            kIOPMAssertionLevelKey: kIOPMAssertionLevelOn,
            kIOPMAssertionTimeoutKey: timeout,
            kIOPMAssertionTimeoutActionKey: kIOPMAssertionTimeoutActionRelease
        ]
        var id: IOPMAssertionID = 0
        guard IOPMAssertionCreateWithProperties(properties as CFDictionary, &id) == kIOReturnSuccess else { return nil }
        idleNames[id] = name
        return id
    }
    func idleActive(_ assertion: UInt32) -> Bool? {
        guard let name = idleNames[assertion] else { return false }
        guard let own = assertions(ownedBy: ProcessInfo.processInfo.processIdentifier) else { return nil }
        return own.contains {
            ($0[kIOPMAssertionNameKey] as? String) == name &&
            ($0[kIOPMAssertionTypeKey] as? String) == kIOPMAssertionTypePreventUserIdleSystemSleep &&
            ($0[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == Int(kIOPMAssertionLevelOn)
        }
    }
    func releaseIdle(_ assertion: UInt32) -> Bool {
        let result = IOPMAssertionRelease(assertion)
        // An OS timeout can release an assertion before normal cleanup reaches it.
        return result == kIOReturnSuccess || idleActive(assertion) == false
    }
    func startExperimental(ownerPID: Int32, timeout: Int) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-s", "-w", String(ownerPID), "-t", String(timeout)]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); helper = process
    }
    var helperPID: Int32? { helper?.processIdentifier }
    var helperRunning: Bool { helper?.isRunning == true }
    func helperAssertionActive() -> Bool? {
        guard let pid = helperPID else { return false }
        guard let own = assertions(ownedBy: pid) else { return nil }
        return own.contains {
            ($0[kIOPMAssertionTypeKey] as? String) == "PreventSystemSleep" &&
            ($0[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == Int(kIOPMAssertionLevelOn)
        }
    }
    private func assertions(ownedBy pid: Int32) -> [[String: Any]]? {
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let values = assertions?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return nil }
        return values[NSNumber(value: pid)] ?? []
    }
    func terminateHelper() { if let helper, helper.isRunning { helper.terminate() } }
}
