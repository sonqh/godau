// Public status value types from architecture-spec section 7.2.
// Data only: nothing here reads the system, and the key callback does not use these types.

public enum InputMode: String, Equatable, Hashable, Sendable, CaseIterable {
    case english, vietnamese
}

/// What set the current mode. The shell shows the mode HUD only for `shortcut`.
public enum ModeSource: String, Equatable, Hashable, Sendable, CaseIterable {
    case launch, menu, shortcut
}

/// Capability reads. They never request a permission.
public struct Capabilities: Equatable, Hashable, Sendable {
    public let accessibility: Bool
    public let eventListening: Bool
    public let eventPosting: Bool

    public init(accessibility: Bool, eventListening: Bool, eventPosting: Bool) {
        self.accessibility = accessibility
        self.eventListening = eventListening
        self.eventPosting = eventPosting
    }

    public init(_ snapshot: PermissionSnapshot) {
        self.init(accessibility: snapshot.accessibility, eventListening: snapshot.eventListening,
                  eventPosting: snapshot.eventPosting)
    }

    public static let all = Capabilities(accessibility: true, eventListening: true, eventPosting: true)
    public static let none = Capabilities(accessibility: false, eventListening: false, eventPosting: false)
}

/// The user must act.
public enum BlockReason: String, Equatable, Hashable, Sendable, CaseIterable {
    case accessibility, listening, posting
    case unsupportedSource, conflictingTool
    case tapUnavailable, userDisabledTap, recoveryLimit, transportUncertain

    /// Sticky reasons clear only on an explicit `resume()`.
    public var needsResume: Bool {
        switch self {
        case .tapUnavailable, .userDisabledTap, .recoveryLimit, .transportUncertain: true
        default: false
        }
    }
}

/// Nothing to do here. Clears by itself when the context changes.
public enum StandbyReason: String, Equatable, Hashable, Sendable, CaseIterable {
    case secureInput, passwordField, sleeping
    case excludedApp, unsupportedField, noTextField, fieldUnreadable
}

/// Evidence required before deleting text (architecture-spec 6.3).
public enum Assurance: String, Equatable, Hashable, Sendable, CaseIterable {
    case observed, eventOnly
}

/// Field kinds the runtime can tell apart (architecture-spec 6.4).
public enum FieldKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case editor, find, quickInput, addressBar, webText, noteText, textField
}

public enum Availability: Equatable, Hashable, Sendable {
    /// English mode.
    case off
    case active(Assurance)
    case standby(StandbyReason)
    case blocked(BlockReason)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

public struct RuntimeStatus: Equatable, Hashable, Sendable {
    public let mode: InputMode
    public let modeSource: ModeSource
    public let availability: Availability
    /// Reported in every mode.
    public let capabilities: Capabilities
    public let inputSourceID: String
    public let frontmostBundleID: String?
    public let profileID: String?
    public let fieldKind: FieldKind?
    public let conflictingBundleID: String?
    /// The gate the callback uses before it matches the shortcut chord.
    public let shortcutArmed: Bool

    public init(mode: InputMode, modeSource: ModeSource, availability: Availability,
                capabilities: Capabilities, inputSourceID: String, frontmostBundleID: String?,
                profileID: String?, fieldKind: FieldKind?, conflictingBundleID: String?,
                shortcutArmed: Bool) {
        self.mode = mode
        self.modeSource = modeSource
        self.availability = availability
        self.capabilities = capabilities
        self.inputSourceID = inputSourceID
        self.frontmostBundleID = frontmostBundleID
        self.profileID = profileID
        self.fieldKind = fieldKind
        self.conflictingBundleID = conflictingBundleID
        self.shortcutArmed = shortcutArmed
    }

    /// Input sources the MVP accepts.
    public static let supportedInputSources: Set<String> = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]

    public var inputSourceSupported: Bool { Self.supportedInputSources.contains(inputSourceID) }
}
