import Foundation
import VietMacShell

/// The shell's own preferences, in the app's defaults domain (ux-shell design D7).
/// It never stores status, counters, or text.
@MainActor
final class ShellPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults === UserDefaults.standard { Self.migrateLegacyPreferences(into: defaults) }
    }

    /// The bundle ID before the first public release (2026-11-17). macOS keys preferences by bundle ID.
    static let legacyBundleID = "local.sonquach.vietmac"

    /// Copies the preferences stored under the old bundle ID, once, and only into the Release app.
    /// A key that already has a value keeps it. Permissions do not move: the user grants them again.
    static func migrateLegacyPreferences(into defaults: UserDefaults) {
        let marker = "migratedLegacyPreferences"
        guard Bundle.main.bundleIdentifier == "io.github.sonqh.godau", !defaults.bool(forKey: marker) else { return }
        defaults.set(true, forKey: marker)
        guard let legacy = defaults.persistentDomain(forName: legacyBundleID) else { return }
        for (key, value) in legacy where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
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
