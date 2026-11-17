import VietMacPlatform

/// A recorded mode shortcut (ux-spec 6.2). Stored as a key code, modifiers, and the key's label.
public struct ShortcutChord: Equatable, Hashable, Codable, Sendable {
    public struct Modifiers: OptionSet, Equatable, Hashable, Codable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public let keyCode: UInt16
    public let modifiers: Modifiers
    /// The key as shown, for example `V` or `Space`.
    public let keyLabel: String

    public init(keyCode: UInt16, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// Key code of a modifier-only gesture. No physical key has it.
    public static let modifierOnlyKeyCode: UInt16 = 0xFFFF

    /// ⌃⇧ pressed and released with no other key, the only accepted modifier-only gesture (Son, 2026-11-15).
    public static let controlShift = ShortcutChord(keyCode: modifierOnlyKeyCode, modifiers: [.control, .shift],
                                                   keyLabel: "")

    public var isModifierOnly: Bool { keyCode == Self.modifierOnlyKeyCode }

    /// The candidate chord. Its conflicts in the five apps are unknown until the PD-1 native test.
    public static let suggested = ShortcutChord(keyCode: 9, modifiers: [.control, .option], keyLabel: "V")

    /// macOS order: ⌃ ⌥ ⇧ ⌘, then the key.
    public var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + keyLabel
    }

    public enum Rejection: Error, Equatable, Sendable {
        case needsModifier
        case systemShortcut

        public var message: LocalizedText {
            switch self {
            case .needsModifier: LocalizedText("shortcut.needsModifier")
            case .systemShortcut: LocalizedText("shortcut.systemTaken")
            }
        }
    }

    /// Recorder rules: a chord needs ⌘, ⌃, or ⌥ plus one other key, and must not be a system shortcut.
    /// A modifier-only gesture (`modifierOnly`) is accepted only as ⌃⇧; its key code and label are ignored.
    public static func validate(keyCode: UInt16, modifiers: Modifiers, keyLabel: String, modifierOnly: Bool,
                                systemShortcuts: Set<ShortcutChord.Key>) -> Result<ShortcutChord, Rejection> {
        if modifierOnly { return modifiers == controlShift.modifiers ? .success(controlShift) : .failure(.needsModifier) }
        guard !keyLabel.isEmpty,
              !modifiers.intersection([.command, .control, .option]).isEmpty else { return .failure(.needsModifier) }
        let chord = ShortcutChord(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
        if systemShortcuts.contains(chord.key) { return .failure(.systemShortcut) }
        return .success(chord)
    }

    /// Identity of a chord without its label.
    public struct Key: Equatable, Hashable, Sendable {
        public let keyCode: UInt16
        public let modifiers: Modifiers
        public init(keyCode: UInt16, modifiers: Modifiers) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }

    public var key: Key { Key(keyCode: keyCode, modifiers: modifiers) }
}

/// Detects a modifier-only gesture: every key of `target` held together, then all released, with no other
/// key or click in between and no modifier outside `target`. Pure state, fed by the app's event monitors.
public struct ModifierTapDetector: Sendable {
    public let target: ShortcutChord.Modifiers
    private var down: ShortcutChord.Modifiers = []
    private var matched = false
    private var spoiled = false

    public init(target: ShortcutChord.Modifiers) { self.target = target }

    /// Call on every modifier change with the modifiers now held. Returns true when the gesture completes.
    public mutating func modifiersChanged(_ held: ShortcutChord.Modifiers) -> Bool {
        down = held
        if held.isEmpty {
            let fired = matched && !spoiled
            matched = false
            spoiled = false
            return fired
        }
        if !target.isSuperset(of: held) { spoiled = true }
        if held == target { matched = true }
        return false
    }

    /// Call on a key press or a click. Any input while a modifier is held cancels the gesture.
    public mutating func otherInput() {
        if !down.isEmpty { spoiled = true }
    }
}

/// The line under the recorder while a shortcut is set but cannot fire (ux-spec 6.1).
public enum ShortcutNotice {
    /// The reason the shortcut does not work now, or nil when it is armed or unset.
    /// The app shows it as `shortcut.notArmed` with the rendered reason.
    public static func notArmedReason(status: RuntimeStatus, configured: Bool,
                                      features: SetupFeatures = .current) -> LocalizedText? {
        guard configured, !status.shortcutArmed else { return nil }
        let caps = status.capabilities
        if !caps.accessibility { return LocalizedText("detail.accessibility") }
        if !caps.eventListening { return LocalizedText("detail.listening") }
        if !caps.eventPosting { return LocalizedText("detail.posting") }
        switch status.availability {
        case .blocked(let reason) where reason.needsResume: return LocalizedText("detail.\(reason.rawValue)")
        case .standby(.sleeping): return LocalizedText("detail.sleeping")
        default: return LocalizedText("detail.secureInput")
        }
    }
}

/// When the mode HUD shows (ux-spec 6.3): a new mode set by the shortcut. Menu and setup changes never show it.
public enum ModeHUDRule {
    public static func shouldShow(previous: RuntimeStatus?, next: RuntimeStatus) -> Bool {
        guard let previous else { return false }
        return previous.mode != next.mode && next.modeSource == .shortcut
    }

    /// Fade time in seconds. With Reduce Motion on, the HUD appears and disappears without a fade.
    public static func fadeDuration(reduceMotion: Bool) -> Double { reduceMotion ? 0 : 0.15 }

    /// How long the HUD stays visible.
    public static let displaySeconds = 0.8

    public static func text(for mode: InputMode) -> LocalizedText {
        LocalizedText(mode == .vietnamese ? "hud.vietnamese" : "hud.english")
    }
}

/// Settings › Apps (ux-spec 7.2): one row per required app, then one per excluded app outside that list.
/// Never a scan of installed apps.
public struct AppsTab: Equatable, Sendable {
    public struct Field: Equatable, Hashable, Sendable {
        public let name: LocalizedText
        public let state: LocalizedText
        /// Native evidence exists. A label; it does not turn typing on or off.
        public let tested: Bool
    }

    public struct Row: Equatable, Hashable, Sendable {
        public let bundleID: String
        public let name: LocalizedText
        public let fields: [Field]
        /// `Gõ tiếng Việt`: on unless the app is excluded.
        public let typesVietnamese: Bool
    }

    public let rows: [Row]

    /// Field kinds in the order the mockup shows them.
    static let fieldOrder: [FieldKind] = [.webText, .addressBar, .editor, .find, .quickInput, .noteText, .textField]

    public init(catalog: ProfileCatalog, excluded: Set<String>, names: NameResolver = .fallback) {
        let listed = catalog.bundleIDs
        rows = (listed + excluded.subtracting(listed).sorted()).map { bundleID in
            let profiles = catalog.profiles(for: bundleID)
                .sorted { Self.fieldOrder.firstIndex(of: $0.field)! < Self.fieldOrder.firstIndex(of: $1.field)! }
            let fields = profiles.map { profile in
                let state = !profile.tested ? "settings.apps.untested"
                    : profile.assurance == .eventOnly ? "settings.apps.testedReduced" : "settings.apps.tested"
                return Field(name: LocalizedText("field.\(profile.field.rawValue)"), state: LocalizedText(state),
                             tested: profile.tested)
            }
            let name = bundleID == "com.apple.Notes"
                ? LocalizedText("app.notes") : LocalizedText("text.literal", names.appName(bundleID))
            return Row(bundleID: bundleID, name: name, fields: fields, typesVietnamese: !excluded.contains(bundleID))
        }
    }
}

/// Settings › Status (ux-spec 7.2). Posting appears only in the technical details, never as a row.
public struct StatusTab: Equatable, Sendable {
    public struct Row: Equatable, Hashable, Sendable {
        public let label: LocalizedText
        public let value: LocalizedText
        public let ok: Bool
        /// `Mở…` when an action exists.
        public let action: SettingsRowAction?
    }

    public enum SettingsRowAction: Equatable, Hashable, Sendable {
        case requestPermission(SetupStep)
        case openKeyboardSettings
    }

    public let rows: [Row]

    public init(status: RuntimeStatus, features: SetupFeatures = .current, names: NameResolver = .fallback) {
        let caps = status.capabilities
        var rows: [Row] = []
        func grant(_ label: String, _ on: Bool, _ step: SetupStep) -> Row {
            Row(label: LocalizedText(label), value: LocalizedText(on ? "setup.statusOn" : "setup.statusOff"), ok: on,
                action: on ? nil : .requestPermission(step))
        }
        if features.inputMonitoringRequired {
            rows.append(grant("settings.status.listening", caps.eventListening, .inputMonitoring))
        }
        rows.append(grant("settings.status.accessibility", caps.accessibility, .accessibility))
        let source = names.inputSourceName(status.inputSourceID)
        let sourceOK = status.inputSourceSupported
        rows.append(Row(label: LocalizedText("settings.status.keyboard"),
                        value: LocalizedText(sourceOK ? "setup.keyboard.ok" : "setup.keyboard.wrong", source), ok: sourceOK,
                        action: sourceOK ? nil : .openKeyboardSettings))
        if features.conflictDetection {
            let app = status.conflictingBundleID.map(names.appName)
            rows.append(Row(label: LocalizedText("settings.status.otherTool"),
                            value: app.map { LocalizedText("setup.conflict.running", $0) }
                                ?? LocalizedText("settings.status.otherToolNone"),
                            ok: app == nil, action: nil))
        }
        self.rows = rows
    }

    /// Technical details as label and value pairs. Values are enum names and booleans, never text.
    public static func technicalDetails(status: RuntimeStatus) -> [(String, String)] {
        let availability: String
        switch status.availability {
        case .off: availability = "off"
        case .active(let assurance): availability = "active(\(assurance.rawValue))"
        case .standby(let reason): availability = "standby(\(reason.rawValue))"
        case .blocked(let reason): availability = "blocked(\(reason.rawValue))"
        }
        let caps = status.capabilities
        return [
            ("mode", status.mode.rawValue),
            ("modeSource", status.modeSource.rawValue),
            ("availability", availability),
            ("profile", status.profileID ?? "none"),
            ("fieldKind", status.fieldKind?.rawValue ?? "none"),
            ("accessibility", String(caps.accessibility)),
            ("eventListening", String(caps.eventListening)),
            ("eventPosting", String(caps.eventPosting)),
            ("inputSource", status.inputSourceID),
            ("frontmostApp", status.frontmostBundleID ?? "none"),
            ("shortcutArmed", String(status.shortcutArmed)),
        ]
    }
}
