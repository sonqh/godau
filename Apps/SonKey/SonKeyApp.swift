import AppKit
import SonKeyMac

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "SK"
        status.button?.toolTip = "SonKey development scaffold"
        let menu = NSMenu()
        let state = NSMenuItem(title: "Transport not implemented — M0 pending", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SonKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        item = status
    }
}

@main
private struct SonKeyApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
