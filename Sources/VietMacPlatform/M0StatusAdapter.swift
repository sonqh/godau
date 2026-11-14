import CoreFoundation

/// Keeps the last published status and passes on only a different one.
public struct StatusPublisher: Sendable {
    public private(set) var last: RuntimeStatus?

    public init() {}

    /// Returns the status when it differs from the last published value, else nil.
    public mutating func offer(_ status: RuntimeStatus) -> RuntimeStatus? {
        guard status != last else { return nil }
        last = status
        return status
    }
}

/// Temporary producer of `RuntimeStatus` from the M0 host (ux-shell design D2).
/// M2 replaces it with `InputHost.status` and `onStatusChange`; the shell does not change.
/// Reads only cached host values. It never reads the system and adds no work to the key callback.
@MainActor
public final class M0StatusAdapter {
    private let host: InputHost
    private var publisher = StatusPublisher()
    private var observer: CFRunLoopObserver?
    /// What set the current mode. M0 has no shortcut, so this is `launch` or `menu`.
    public private(set) var modeSource: ModeSource = .launch
    public var onStatusChange: ((RuntimeStatus) -> Void)?
    /// A mode shortcut is configured. M0 matches it outside the key callback, as a system hot key
    /// registered by the shell only while `shortcutArmed` is true; M2 moves matching into the callback.
    public var shortcutConfigured = false

    public init(host: InputHost) {
        self.host = host
    }

    /// Synchronous read for a menu that is about to open.
    public var status: RuntimeStatus {
        Self.status(enabled: host.enabled, state: host.state, permissions: host.permissions,
                    inputSource: host.inputSource, frontmostBundleID: host.frontmostBundleID, modeSource: modeSource,
                    excluded: host.excludedBundleIDs, secureInput: host.secureInput,
                    shortcutConfigured: shortcutConfigured)
    }

    /// Publishes from one main run-loop observer, before the loop waits, at most once per pass.
    public func start() {
        guard observer == nil else { return }
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) {
            [weak self] _, _ in
            MainActor.assumeIsolated { _ = self?.publishIfChanged() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
        _ = publishIfChanged()
    }

    public func stop() {
        if let observer { CFRunLoopObserverInvalidate(observer) }
        observer = nil
    }

    /// Builds the status and calls `onStatusChange` only when it differs from the last published value.
    @discardableResult
    public func publishIfChanged() -> Bool {
        guard let changed = publisher.offer(status) else { return false }
        onStatusChange?(changed)
        return true
    }

    public func setMode(_ mode: InputMode, source: ModeSource) {
        modeSource = source
        host.setEnabled(mode == .vietnamese)
    }

    /// Exclusions apply between events and clear the tracked word.
    public func apply(excluded: Set<String>, shortcutConfigured: Bool) {
        self.shortcutConfigured = shortcutConfigured
        host.excludedBundleIDs = excluded
    }

    /// Clears a sticky pause. M0 resumes by enabling again, which starts with no tracked word.
    public func resume() {
        host.setEnabled(true)
    }

    // MARK: Pure mapping

    nonisolated public static func status(enabled: Bool, state: InputRuntimeState, permissions: PermissionSnapshot,
                              inputSource: String, frontmostBundleID: String?, modeSource: ModeSource,
                              excluded: Set<String> = [], secureInput: Bool = false,
                              shortcutConfigured: Bool = false) -> RuntimeStatus {
        var availability = enabled ? availability(for: state) : .off
        // M0 treats an excluded app as unsupported; the status names the real reason.
        if availability == .standby(.unsupportedApp), let app = frontmostBundleID, excluded.contains(app) {
            availability = .standby(.excludedApp)
        }
        let capabilities = Capabilities(permissions)
        return RuntimeStatus(mode: enabled ? .vietnamese : .english, modeSource: modeSource,
                             availability: availability, capabilities: capabilities, inputSourceID: inputSource,
                             frontmostBundleID: frontmostBundleID, profileID: nil, fieldKind: nil,
                             conflictingBundleID: nil,
                             shortcutArmed: shortcutArmed(configured: shortcutConfigured, capabilities: capabilities,
                                                          availability: availability, secureInput: secureInput))
    }

    /// The shortcut works only when it is configured, every capability is granted, no sticky pause is
    /// pending, secure input is off, and the session is awake (architecture-spec 7.2). Mode, source,
    /// app, and field do not matter.
    nonisolated public static func shortcutArmed(configured: Bool, capabilities: Capabilities,
                                                 availability: Availability, secureInput: Bool) -> Bool {
        guard configured, capabilities.accessibility, capabilities.eventListening, capabilities.eventPosting,
              !secureInput else { return false }
        switch availability {
        case .blocked(let reason) where reason.needsResume: return false
        case .standby(.sleeping), .standby(.secureInput): return false
        default: return true
        }
    }

    /// The M0 reason mapping table in ux-shell design D2.
    nonisolated public static func availability(for state: InputRuntimeState) -> Availability {
        switch state {
        case .disabled: .off
        case .active: .active(.observed)
        case .paused(let reason):
            switch reason {
            case .accessibility: .blocked(.accessibility)
            case .listening: .blocked(.listening)
            case .posting: .blocked(.posting)
            case .unsupportedSource: .blocked(.unsupportedSource)
            case .tapUnavailable: .blocked(.tapUnavailable)
            case .recoveryLimit: .blocked(.recoveryLimit)
            case .userDisabledTap: .blocked(.userDisabledTap)
            case .transportUncertain: .blocked(.transportUncertain)
            case .secureInput: .standby(.secureInput)
            case .unsupportedApp: .standby(.unsupportedApp)
            case .uncertainContext: .standby(.fieldUnreadable)
            case .sleeping: .standby(.sleeping)
            }
        }
    }
}
