import ApplicationServices
import CoreGraphics
import VietMacCore

public struct PermissionSnapshot: Equatable, Sendable {
    public let accessibility: Bool
    public let eventListening: Bool
    public let eventPosting: Bool

    public init(accessibility: Bool, eventListening: Bool, eventPosting: Bool) {
        self.accessibility = accessibility
        self.eventListening = eventListening
        self.eventPosting = eventPosting
    }

    /// Read-only capability checks. This function never requests permission.
    public static func current() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibility: AXIsProcessTrusted(),
            eventListening: CGPreflightListenEventAccess(),
            eventPosting: CGPreflightPostEventAccess()
        )
    }
}

public enum PauseReason: String, Equatable, Sendable {
    case accessibility = "Accessibility access is unavailable"
    case listening = "Input monitoring is unavailable"
    case posting = "Event posting is unavailable"
    case secureInput = "Secure input is active"
    case unsupportedApp = "Application is outside the M0 trial"
    case unsupportedSource = "Use ABC or U.S. input source"
    case uncertainContext = "Focus or selection is uncertain"
    case tapUnavailable = "The event tap could not start"
    case recoveryLimit = "Timeout recovery limit reached; resume explicitly"
    case userDisabledTap = "The event tap was disabled by the user"
    case sleeping = "The user session is sleeping"
    case transportUncertain = "Replacement delivery became uncertain"
}

public enum InputRuntimeState: Equatable, Sendable {
    case disabled
    case active
    case paused(PauseReason)
}

public struct InputEnvironment: Equatable, Sendable {
    public var permissions: PermissionSnapshot
    public var secureInput: Bool
    public var supportedApp: Bool
    public var supportedSource: Bool
    public var certainContext: Bool

    public init(permissions: PermissionSnapshot, secureInput: Bool = false,
                supportedApp: Bool = true, supportedSource: Bool = true,
                certainContext: Bool = true) {
        self.permissions = permissions
        self.secureInput = secureInput
        self.supportedApp = supportedApp
        self.supportedSource = supportedSource
        self.certainContext = certainContext
    }

    var pauseReason: PauseReason? {
        if !permissions.accessibility { return .accessibility }
        if !permissions.eventListening { return .listening }
        if !permissions.eventPosting { return .posting }
        if secureInput { return .secureInput }
        if !supportedApp { return .unsupportedApp }
        if !supportedSource { return .unsupportedSource }
        if !certainContext { return .uncertainContext }
        return nil
    }
}

/// Bounded counters for native reproductions. They contain no text or keystroke payloads.
public struct ContextCounters: Encodable, Equatable, Sendable {
    public var focusChanges: UInt64 = 0
    public var selectionsObserved: UInt64 = 0
    public var fieldUnavailable: UInt64 = 0
    public var laggingObservations: UInt64 = 0
    public var unexplainedFieldChanges: UInt64 = 0
    public var unpredictableKeys: UInt64 = 0
    public var unsettledTriggers: UInt64 = 0
    public var staleBeforeSend: UInt64 = 0
    public var uncertainAfterSend: UInt64 = 0
    public var replacementsPosted: UInt64 = 0
    /// Replacements whose predicted field effect never settled; the host paused after each.
    public var replacementsUnconfirmed: UInt64 = 0
    /// Focus changes where the new field held exactly the tracked word, which was kept (⌘Tab race).
    public var wordsKeptAcrossFocus: UInt64 = 0

    public init() {}
}
