import AppKit
import VietMacPlatform
import VietMacShell

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, ShellRouter {
    private let host = InputHost()
    private lazy var adapter = M0StatusAdapter(host: host)
    private var controller: StatusItemController?
    private var setup: SetupWindowController?
    private var settings: SettingsWindowController?
    private let preferences = ShellPreferences()
    private let hotKeys = HotKeyCenter()
    private let hud = ModeHUD()
    private var previousStatus: RuntimeStatus?
    #if DEBUG
    private var simulatorMenu: SimulatorMenu?
    #endif
    private var evidenceSignal: DispatchSourceSignal?
    private var evidenceDirectory: URL?
    private var disableSnapshots = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        host.start()
        adapter.apply(excluded: preferences.excluded, shortcutConfigured: preferences.shortcut != nil)
        // Native automation starts with the prototype on; ordinary launches stay in English mode.
        if CommandLine.arguments.contains("--enable-prototype") { adapter.setMode(.vietnamese, source: .launch) }
        adapter.start()
        let controller = StatusItemController(source: adapter)
        controller.router = self
        controller.beforeModeChange = { [weak self] mode in
            // Snapshot before disabling so the trace still covers the trial just typed.
            guard let self, mode == .english, self.host.enabled, let directory = self.evidenceDirectory else { return }
            self.disableSnapshots += 1
            self.writeEvidence(to: directory, prefix: "disable-\(self.disableSnapshots)-")
        }
        #if DEBUG
        let simulator = SimulatorMenu(controller: controller, live: adapter)
        controller.extraItems = { simulator.items() }
        simulator.resetSetup = { [weak self] in
            self?.preferences.lastSetupStep = nil
            self?.preferences.setupCompletedOnce = false
        }
        simulator.simulateLaunch = { [weak self] in self?.openSetupAtLaunch(force: true) }
        simulatorMenu = simulator
        #endif
        let setup = SetupWindowController(status: { [weak controller] in
            controller?.source.status ?? self.adapter.status
        }, setMode: { [weak controller] mode in
            controller?.source.setMode(mode, source: .menu)
        }, preferences: preferences)
        setup.router = self
        setup.onConfigurationChange = { [weak self] in self?.applyConfiguration() }
        let settings = SettingsWindowController(status: { [weak controller] in
            controller?.source.status ?? self.adapter.status
        }, counters: { [weak self] in self?.counterRows() ?? [] }, preferences: preferences)
        settings.router = self
        settings.onConfigurationChange = { [weak self] in self?.applyConfiguration() }
        controller.onStatus = { [weak self] status in self?.statusPublished(status) }
        controller.onExclusion = { [weak self] bundleID, excluded in
            guard let self else { return }
            var set = self.preferences.excluded
            if excluded { set.insert(bundleID) } else { set.remove(bundleID) }
            self.preferences.excluded = set
            self.applyConfiguration()
            self.settings?.exclusionsChanged()
        }
        hotKeys.onPress = { [weak self] in
            guard let self, let source = self.controller?.source else { return }
            // The chord fires only while armed; the menu stays the complete control.
            guard source.status.shortcutArmed else { return }
            let next: InputMode = source.status.mode == .vietnamese ? .english : .vietnamese
            self.controller?.beforeModeChange?(next)
            source.setMode(next, source: .shortcut)
        }
        self.setup = setup
        self.settings = settings
        self.controller = controller
        applyConfiguration()
        startEvidenceExport()
        openSetupAtLaunch()
    }

    /// Opening VietMac again while it runs opens Settings (architecture-spec 7.7).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings?.show()
        return false
    }

    /// Applies the stored shortcut and exclusions to the host and the menu.
    private func applyConfiguration() {
        adapter.apply(excluded: preferences.excluded, shortcutConfigured: preferences.shortcut != nil)
        controller?.excluded = preferences.excluded
        controller?.shortcutDisplay = preferences.shortcut?.display
        _ = adapter.publishIfChanged()
        if let status = controller?.source.status { statusPublished(status) }
        controller?.refresh()
    }

    /// Every published status: hot key arming, the mode HUD, and open windows.
    private func statusPublished(_ status: RuntimeStatus) {
        hotKeys.update(chord: preferences.shortcut, armed: status.shortcutArmed)
        if ModeHUDRule.shouldShow(previous: previousStatus, next: status), let strings = controller?.strings {
            hud.show(mode: status.mode, strings: strings)
        }
        previousStatus = status
        setup?.statusChanged(status)
        settings?.statusChanged(status)
    }

    /// Context counters since this launch, for Settings › Status. Counts only, never text.
    private func counterRows() -> [(String, String)] {
        let counters = host.counters
        return [("focusChanges", counters.focusChanges), ("selectionsObserved", counters.selectionsObserved),
                ("fieldUnavailable", counters.fieldUnavailable), ("replacementsPosted", counters.replacementsPosted),
                ("replacementsUnconfirmed", counters.replacementsUnconfirmed),
                ("unsettledTriggers", counters.unsettledTriggers)].map { ($0.0, String($0.1)) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        adapter.stop()
        host.stop()
    }

    // MARK: ShellRouter

    var hasSetupWindow: Bool { true }
    var hasHelpWindow: Bool { true }
    var hasSettingsWindow: Bool { true }

    func canPerform(_ action: ShellAction) -> Bool { true }

    func perform(_ action: ShellAction) {
        switch action {
        case .openSetup(let step): setup?.showSetup(at: step)
        case .openHelp(let page): setup?.showHelp(page)
        case .openKeyboardSettings: SystemPanes.open(.keyboard)
        case .relaunch: relaunch()
        case .resume: controller?.source.resume()
        case .openSettings(let tab): settings?.show(tab)
        case .removeExclusion(let bundleID): controller?.onExclusion?(bundleID, false)
        }
    }

    func perform(_ command: MenuModel.Command) {
        switch command {
        case .quit: NSApp.terminate(nil)
        case .saveReport: saveDiagnosticReport()
        case .continueSetup: setup?.showSetupContinuing()
        case .help: setup?.showHelp()
        case .settings: settings?.show()
        }
    }

    /// Opens setup by itself only under the launch rules of ux-spec 4.6. Never requests a permission.
    private func openSetupAtLaunch(force: Bool = false) {
        // Native automation sessions must not get a window in front of the fields under test.
        guard force || !CommandLine.arguments.contains("--enable-prototype") else { return }
        let status = controller?.source.status ?? adapter.status
        let plan = SetupPlan(status: status)
        let decision = LaunchDecision.decide(status: status, plan: plan, completedOnce: preferences.setupCompletedOnce,
                                             lastSeen: preferences.lastSetupStep, loginLaunch: false)
        guard let step = decision.step else { return }
        setup?.showSetup(at: step, updateHeading: decision.updateHeading, activate: decision.activates)
    }

    /// Opens a new instance of this bundle, then quits once the launch succeeded (architecture-spec 7.7).
    private func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let bundleURL = Bundle.main.bundleURL
        adapter.stop()
        host.stop()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if app != nil {
                        NSApp.terminate(nil)
                    } else {
                        self.host.start()
                        self.adapter.start()
                    }
                }
            }
        }
    }

    /// Exports only the "may show" fields of architecture-spec 7.9 to a location the user chooses.
    private func saveDiagnosticReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vietmac-diagnostics.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            host.refresh()
            let diagnostics = try JSONSerialization.jsonObject(with: host.diagnosticJSON(scope: "user-diagnostic-report"))
            let timings = try JSONSerialization.jsonObject(with: host.timingJSON())
            let data = try JSONSerialization.data(withJSONObject: ["diagnostics": diagnostics, "callbackTimings": timings],
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.messageText = controller?.strings("menu.saveReport") ?? "Gõ Dấu"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: Native evidence (development)

    /// `--evidence-dir <absolute path>` writes session snapshots at launch and on SIGUSR1.
    /// Writes run on the main queue outside the key callback and contain no typed text.
    private func startEvidenceExport() {
        signal(SIGUSR1, SIG_IGN) // A stray export request must not terminate a session without evidence export.
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--evidence-dir"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        guard directory.path.hasPrefix("/") else { return }
        evidenceDirectory = directory
        writeEvidence(to: directory)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.writeEvidence(to: directory) }
        }
        source.resume()
        evidenceSignal = source
    }

    private func writeEvidence(to directory: URL, prefix: String = "") {
        do {
            host.refresh()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try host.diagnosticJSON(scope: "launch-services-session-snapshot")
                .write(to: directory.appendingPathComponent(prefix + "session-diagnostics.json"), options: .atomic)
            try host.timingJSON().write(to: directory.appendingPathComponent(prefix + "callback-timings.json"), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Evidence export failed: \(error)\n".utf8))
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
        #if DEBUG
        if Snapshots.runIfRequested() { return }
        #endif
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
