import AppKit
import ApplicationServices
import CoreGraphics
import VietMacShell

/// Calls the system permission-request functions (FG-3). Only button actions in the setup and settings
/// windows may call it; the launch path, the status observer, and the menu never do
/// (checked by `scripts/tests/test_permission_requests.py`).
@MainActor
enum PermissionRequester {
    /// Requests the capability of a grant step, then opens its System Settings pane.
    static func request(_ step: SetupStep) {
        switch step {
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
            SystemPanes.open(.inputMonitoring)
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary // kAXTrustedCheckOptionPrompt
            _ = AXIsProcessTrustedWithOptions(options)
            SystemPanes.open(.accessibility)
        default:
            break
        }
    }
}

/// System Settings panes the shell opens. Opening a pane grants nothing.
enum SystemPanes {
    case accessibility, inputMonitoring, keyboard

    static let systemSettingsBundleID = "com.apple.systempreferences"

    static func open(_ pane: SystemPanes) {
        let address: String
        switch pane {
        case .accessibility: address = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring: address = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .keyboard: address = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
        }
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }
}
