import AppKit
import VietMacPlatform

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem?
    private let host = InputHost()
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Enable M0 prototype", action: nil, keyEquivalent: "")
    private let resumeItem = NSMenuItem(title: "Resume after pause", action: nil, keyEquivalent: "")
    private let capabilitiesItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var evidenceSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "VM"
        status.button?.toolTip = "VietMac M0 prototype — native acceptance pending"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        stateItem.isEnabled = false
        capabilitiesItem.isEnabled = false
        toggleItem.action = #selector(toggle)
        toggleItem.target = self
        resumeItem.action = #selector(resume)
        resumeItem.target = self
        menu.addItem(stateItem)
        menu.addItem(toggleItem)
        menu.addItem(resumeItem)
        menu.addItem(capabilitiesItem)
        let notice = NSMenuItem(title: "M0 examples only: as → á, aa → â", action: nil, keyEquivalent: "")
        notice.isEnabled = false
        menu.addItem(notice)
        menu.addItem(.separator())
        add("Open Accessibility settings…", action: #selector(openAccessibility), to: menu)
        add("Open Input Monitoring settings…", action: #selector(openMonitoring), to: menu)
        add("Save callback timing report…", action: #selector(exportTiming), to: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit VietMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        item = status
        host.start()
        updateMenu()
        startEvidenceExport()
    }

    /// `--evidence-dir <absolute path>` writes session snapshots at launch and on SIGUSR1.
    /// Writes run on the main queue outside the key callback and contain no typed text.
    private func startEvidenceExport() {
        signal(SIGUSR1, SIG_IGN) // A stray export request must not terminate a session without evidence export.
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--evidence-dir"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        guard directory.path.hasPrefix("/") else { return }
        writeEvidence(to: directory)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.writeEvidence(to: directory) }
        }
        source.resume()
        evidenceSignal = source
    }

    private func writeEvidence(to directory: URL) {
        do {
            host.refresh()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try host.diagnosticJSON(scope: "launch-services-session-snapshot")
                .write(to: directory.appendingPathComponent("session-diagnostics.json"), options: .atomic)
            try host.timingJSON().write(to: directory.appendingPathComponent("callback-timings.json"), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Evidence export failed: \(error)\n".utf8))
        }
    }

    func applicationWillTerminate(_ notification: Notification) { host.stop() }
    func menuNeedsUpdate(_ menu: NSMenu) { updateMenu() }

    private func add(_ title: String, action: Selector, to menu: NSMenu) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        menu.addItem(entry)
    }

    private func updateMenu() {
        switch host.state {
        case .disabled: stateItem.title = "Prototype disabled — ordinary input"
        case .active: stateItem.title = "M0 prototype active — acceptance pending"
        case .paused(let reason): stateItem.title = "Paused: \(reason.rawValue)"
        }
        toggleItem.title = host.enabled ? "Disable M0 prototype" : "Enable M0 prototype"
        if case .paused = host.state { resumeItem.isEnabled = host.enabled }
        else { resumeItem.isEnabled = false }
        let p = host.permissions
        capabilitiesItem.title = "Access: AX \(p.accessibility ? "✓" : "✗") · Listen \(p.eventListening ? "✓" : "✗") · Post \(p.eventPosting ? "✓" : "✗")"
        item?.button?.toolTip = stateItem.title
    }

    @objc private func toggle() { host.setEnabled(!host.enabled); updateMenu() }
    @objc private func resume() { host.setEnabled(true); updateMenu() }
    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func openMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func exportTiming() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vietmac-callback-timings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try host.timingJSON().write(to: url, options: .atomic) }
        catch {
            let alert = NSAlert()
            alert.messageText = "Timing report could not be saved"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

@main
private struct VietMacApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--diagnostics") {
            let host = InputHost()
            host.refresh()
            do {
                let data = try host.diagnosticJSON()
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("Diagnostics failed: \(error)\n".utf8))
                exit(1)
            }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
