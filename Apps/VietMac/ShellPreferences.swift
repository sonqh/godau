import Foundation
import VietMacShell

/// The shell's own preferences, in the app's defaults domain (ux-shell design D7).
/// It never stores status, counters, or text.
@MainActor
final class ShellPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last setup step the user saw. Setup progress is otherwise derived from the status.
    var lastSetupStep: SetupStep? {
        get { defaults.string(forKey: "setup.lastStep").flatMap(SetupStep.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "setup.lastStep") }
    }

    /// The user finished setup with `Xong` at least once.
    var setupCompletedOnce: Bool {
        get { defaults.bool(forKey: "setup.completedOnce") }
        set { defaults.set(newValue, forKey: "setup.completedOnce") }
    }

    /// The mode shortcut. Unset by default (PD-1).
    var shortcut: ShortcutChord? {
        get { defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(ShortcutChord.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "shortcut") }
    }

    /// Bundle IDs where the user turned Vietnamese off. Per app, never per field.
    var excluded: Set<String> {
        get { Set(defaults.stringArray(forKey: "excludedApps") ?? []) }
        set { defaults.set(newValue.sorted(), forKey: "excludedApps") }
    }

    var lastSettingsTab: SettingsTab {
        get { defaults.string(forKey: "settings.lastTab").flatMap(SettingsTab.init(rawValue:)) ?? .general }
        set { defaults.set(newValue.rawValue, forKey: "settings.lastTab") }
    }

    /// The user's last login-startup request. The system registration state is the truth.
    var loginRequested: Bool {
        get { defaults.bool(forKey: "login.requested") }
        set { defaults.set(newValue, forKey: "login.requested") }
    }
}
