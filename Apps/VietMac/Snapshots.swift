#if DEBUG
import AppKit
import VietMacPlatform
import VietMacShell

/// `--snapshot-dir <absolute path>` (Debug only): renders every setup step, Help page, Settings tab,
/// and the status menu text for every reason, in both UI languages, then exits.
/// The rendering uses simulated statuses and never calls `InputHost`.
@MainActor
enum Snapshots {
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot-dir"), index + 1 < arguments.count else { return false }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSAppearance(named: appearance).map { NSApp.appearance = $0 }
            let suffix = appearance == .aqua ? "light" : "dark"
            for language in UILanguage.allCases {
                render(language: language, into: directory, suffix: "\(language.rawValue)-\(suffix)")
            }
        }
        for language in UILanguage.allCases {
            writeMenuText(language: language, to: directory.appendingPathComponent("menu-\(language.rawValue).txt"))
            writeRealMenus(language: language, to: directory.appendingPathComponent("nsmenu-\(language.rawValue).txt"))
        }
        return true
    }

    private static func status(_ availability: Availability = .off, caps: Capabilities = .none,
                               source: String = "com.apple.keylayout.ABC") -> RuntimeStatus {
        RuntimeStatus(mode: availability == .off ? .english : .vietnamese, modeSource: .menu,
                      availability: availability, capabilities: caps, inputSourceID: source,
                      frontmostBundleID: "com.apple.Safari", profileID: nil, fieldKind: .addressBar,
                      conflictingBundleID: nil, shortcutArmed: false)
    }

    private static func render(language: UILanguage, into directory: URL, suffix: String) {
        let strings = Strings(language: language)
        let preferences = ShellPreferences(defaults: UserDefaults(suiteName: "vietmac.snapshots") ?? .standard)
        var current = status()
        let setup = SetupWindowController(status: { current }, setMode: { _ in }, preferences: preferences)
        setup.strings = strings
        let cases: [(String, SetupStep, RuntimeStatus, SetupContext)] = [
            ("1-welcome", .welcome, status(), SetupContext()),
            ("2-input-monitoring-off", .inputMonitoring, status(), SetupContext()),
            ("2-input-monitoring-on", .inputMonitoring,
             status(caps: Capabilities(accessibility: false, eventListening: true, eventPosting: false)), SetupContext()),
            ("3-accessibility-reopen", .accessibility, status(), SetupContext(reopenOffered: true)),
            ("3-accessibility-update", .accessibility, status(), SetupContext(updateHeading: true)),
            ("3-accessibility-posting", .accessibility,
             status(caps: Capabilities(accessibility: true, eventListening: true, eventPosting: false)), SetupContext()),
            ("4-keyboard-wrong", .keyboard,
             status(caps: .all, source: "com.apple.inputmethod.VietnameseIM.VietnameseTelex"), SetupContext()),
            ("4-keyboard-ok", .keyboard, status(caps: .all), SetupContext()),
            ("5-try-it", .tryIt, status(caps: .all), SetupContext()),
            ("5-try-it-not-changed", .tryIt,
             status(.blocked(.unsupportedSource), caps: .all, source: "com.apple.inputmethod.VietnameseIM.VietnameseTelex"),
             SetupContext(tryItAnswer: .notChanged)),
            ("6-ready", .ready, status(caps: .all), SetupContext()),
        ]
        for (name, step, value, context) in cases {
            current = value
            if let view = setup.snapshot(.setup(step), context: context) {
                write(view, to: directory.appendingPathComponent("setup-\(name)-\(suffix).png"))
            }
        }
        for page in HelpPage.allCases {
            if let view = setup.snapshot(.help(page)) {
                write(view, to: directory.appendingPathComponent("help-\(page.rawValue)-\(suffix).png"))
            }
        }
        current = status(.standby(.secureInput), caps: Capabilities(accessibility: true, eventListening: true,
                                                                     eventPosting: false))
        let settings = SettingsWindowController(status: { current }, counters: { [("replacementsPosted", "0")] },
                                                preferences: preferences)
        settings.strings = strings
        settings.isAdHoc = { true } // Stub diagnostics value: signature == adHoc.
        preferences.shortcut = .suggested
        preferences.excluded = ["com.apple.Safari"]
        for (tab, view) in settings.snapshots() {
            write(view, to: directory.appendingPathComponent("settings-\(tab.rawValue)-\(suffix).png"))
        }
        preferences.shortcut = nil
        preferences.excluded = []
        for mode in [InputMode.vietnamese, .english] {
            let hud = ModeHUD() // The snapshot takes the panel's content view, so each mode needs its own HUD.
            hud.show(mode: mode, strings: strings, reduceMotion: true)
            if let view = hud.contentView {
                write(view, to: directory.appendingPathComponent("hud-\(mode.rawValue)-\(suffix).png"))
            }
        }
    }

    private static func write(_ view: NSView, to url: URL) {
        // Fixed-frame views (the HUD panel content) have no fitting size.
        let size = view.fittingSize.width > 0 && view.fittingSize.height > 0 ? view.fittingSize : view.frame.size
        if view.fittingSize.width == 0 {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: size.width).isActive = true
            view.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        }
        // A filled window background, so light and dark snapshots both show their real contrast.
        let background = NSBox()
        background.boxType = .custom
        background.borderWidth = 0
        background.fillColor = .windowBackgroundColor
        background.contentViewMargins = .zero
        background.contentView = view
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: view.fittingSize), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = background
        background.layoutSubtreeIfNeeded()
        window.setContentSize(view.fittingSize)
        background.layoutSubtreeIfNeeded()
        guard let rep = background.bitmapImageRepForCachingDisplay(in: background.bounds) else { return }
        background.cacheDisplay(in: background.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// The real `NSMenu` built by `StatusItemController` for every availability, through the simulator.
    private static func writeRealMenus(language: UILanguage, to url: URL) {
        var statuses: [RuntimeStatus] = [status(caps: .all), status(), status(.active(.observed), caps: .all),
                                          status(.active(.eventOnly), caps: .all)]
        statuses += BlockReason.allCases.map { status(.blocked($0), caps: .all,
                                                      source: "com.apple.inputmethod.VietnameseIM.VietnameseTelex") }
        statuses += StandbyReason.allCases.map { status(.standby($0), caps: .all) }
        let simulator = StatusSimulator(from: statuses[0])
        let controller = StatusItemController(source: simulator)
        controller.strings = Strings(language: language)
        var text = ""
        for value in statuses {
            simulator.update(mode: value.mode, availability: value.availability, capabilities: value.capabilities,
                             inputSourceID: value.inputSourceID)
            controller.refresh()
            // A Standby badge applies after its 500 ms debounce; let the timer fire before reading the title.
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            text += "== \(value.availability)\n" + controller.snapshotText() + "\n"
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The status menu for every reason as text: title, badge, accessibility label, and menu lines.
    private static func writeMenuText(language: UILanguage, to url: URL) {
        let strings = Strings(language: language)
        var statuses: [RuntimeStatus] = [status(caps: .all), status(), status(.active(.observed), caps: .all)]
        statuses += BlockReason.allCases.map { status(.blocked($0), caps: .all,
                                                      source: "com.apple.inputmethod.VietnameseIM.VietnameseTelex") }
        statuses += StandbyReason.allCases.map { status(.standby($0), caps: .all) }
        var text = ""
        for value in statuses {
            let p = StatusPresentation(status: value)
            let model = MenuModel(status: value, presentation: p, setupComplete: true, shortcutDisplay: nil,
                                  excluded: [], exclusionsSupported: true)
            text += "== \(value.availability) | title \(p.title) badge \(p.badge.rawValue) | \(strings(p.accessibilityLabel))\n"
            for item in model.items {
                switch item {
                case .info(let line, let secondary): text += (secondary ? "   " : " ") + strings(line) + "\n"
                case .nextStep(let step): text += " > " + strings(step.title) + "\n"
                case .separator: text += " ---\n"
                case .mode(let mode, let checked, _):
                    text += (checked ? " ✓ " : "   ") + strings(mode == .vietnamese ? "menu.vietnamese" : "menu.english") + "\n"
                case .exclusion(_, let title, _): text += "   " + strings(title) + "\n"
                case .command(let command, let alternate):
                    text += (alternate ? "   [⌥] " : "   ") + strings(MenuModel.title(for: command)) + "\n"
                }
            }
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
