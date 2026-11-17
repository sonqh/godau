import AppKit
import VietMacPlatform
import VietMacShell

/// Actions that leave the menu. The app delegate performs them.
@MainActor
protocol ShellRouter: AnyObject {
    func perform(_ action: ShellAction)
    func perform(_ command: MenuModel.Command)
    /// False while the window or pane that an action opens does not exist yet.
    func canPerform(_ action: ShellAction) -> Bool
    var hasSetupWindow: Bool { get }
    var hasHelpWindow: Bool { get }
    var hasSettingsWindow: Bool { get }
}

/// The menu bar item and the status menu (status-menu spec). Every visible state comes from one
/// `RuntimeStatus` and the shell's preferences.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private(set) var source: StatusSource
    weak var router: ShellRouter?
    var strings = Strings()
    var features = SetupFeatures.current
    var context = PresentationContext()
    var exclusionsSupported = true
    var excluded: Set<String> = []
    /// Adds (true) or removes (false) an app exclusion; the owner stores and applies it.
    var onExclusion: ((String, Bool) -> Void)?
    var shortcutDisplay: String?
    /// Every published status, after the title handled it. Open windows follow the same source.
    var onStatus: ((RuntimeStatus) -> Void)?
    /// Runs before a mode change from the menu, for example to snapshot native evidence.
    var beforeModeChange: ((InputMode) -> Void)?
    /// Extra items appended at the end of the menu (the Debug simulator).
    var extraItems: () -> [NSMenuItem] = { [] }

    private var shown: StatusPresentation?
    private var latest: StatusPresentation?
    private var pendingTitle: Timer?

    init(source: StatusSource) {
        self.source = source
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        item.button?.imagePosition = .imageTrailing
        attach(source)
    }

    /// Switches the status source, for example between the M0 adapter and the simulator.
    func attach(_ next: StatusSource) {
        source.onStatusChange = nil
        source = next
        next.onStatusChange = { [weak self] status in self?.statusChanged(status) }
        statusChanged(next.status)
    }

    func refresh() { statusChanged(source.status) }

    private func presentation(for status: RuntimeStatus) -> StatusPresentation {
        StatusPresentation(status: status, features: features, context: context, names: SystemNames.resolver())
    }

    private func statusChanged(_ status: RuntimeStatus) {
        defer { onStatus?(status) }
        let next = presentation(for: status)
        latest = next
        switch TitleTiming.timing(from: shown, to: next) {
        case .immediate:
            pendingTitle?.invalidate()
            pendingTitle = nil
            applyTitle(next)
        case .delayed(let milliseconds):
            guard pendingTitle == nil else { return }
            let timer = Timer(timeInterval: Double(milliseconds) / 1000, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pendingTitle = nil
                    if let latest = self.latest { self.applyTitle(latest) }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            pendingTitle = timer
        }
    }

    private func applyTitle(_ p: StatusPresentation) {
        guard let button = item.button else { return }
        let classChanged = shown.map { $0.uiClass != p.uiClass || $0.title != p.title } ?? false
        shown = p
        button.title = p.title
        button.font = NSFont.menuBarFont(ofSize: 0)
        button.image = badgeImage(p.badge)
        item.length = titleWidth(badge: p.badge != .none)
        let label = strings(p.accessibilityLabel)
        button.setAccessibilityLabel(label)
        button.toolTip = strings(p.statusLine)
        if classChanged {
            NSAccessibility.post(element: button, notification: .announcementRequested,
                                 userInfo: [.announcement: label, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    private func badgeImage(_ badge: Badge) -> NSImage? {
        let name: String
        switch badge {
        case .none: return nil
        case .pause: name = "pause.fill"
        case .triangle: name = "exclamationmark.triangle.fill"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Fixed width for `VI` and `EN`, so the menu bar does not shift when the mode changes.
    private func titleWidth(badge: Bool) -> CGFloat {
        let font = NSFont.menuBarFont(ofSize: 0)
        let text = ["VI", "EN"].map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 20
        return ceil(text) + 14 + (badge ? 14 : 0)
    }

    #if DEBUG
    /// The real menu and title for the current status, as text, for Debug snapshots (UX-8).
    func snapshotText() -> String {
        menuNeedsUpdate(menu)
        var lines = ["title=\(item.button?.title ?? "") badge=\(item.button?.image == nil ? "none" : "symbol") a11y=\(item.button?.accessibilityLabel() ?? "")"]
        for entry in menu.items {
            if entry.isSeparatorItem { lines.append(" ---"); continue }
            var flags: [String] = []
            if entry.state == .on { flags.append("checked") }
            if !entry.isEnabled { flags.append("disabled") }
            if entry.isAlternate { flags.append("alternate") }
            if !entry.keyEquivalent.isEmpty { flags.append("key=\(entry.keyEquivalent)") }
            lines.append(" \(entry.title) [\(flags.joined(separator: ","))]")
        }
        return lines.joined(separator: "\n")
    }
    #endif

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        let status = source.status
        let p = presentation(for: status)
        let model = MenuModel(status: status, presentation: p,
                              setupComplete: SetupPlan(status: status, features: features).isComplete(status: status),
                              shortcutDisplay: shortcutDisplay, excluded: excluded,
                              exclusionsSupported: exclusionsSupported, names: SystemNames.resolver())
        menu.removeAllItems()
        var previous: NSMenuItem?
        for entry in model.items {
            let built = build(entry, previous: previous)
            menu.addItem(built)
            previous = built
        }
        for extra in extraItems() { menu.addItem(extra) }
    }

    private func build(_ entry: MenuModel.Item, previous: NSMenuItem?) -> NSMenuItem {
        switch entry {
        case .separator:
            return .separator()
        case .info(let text, let secondary):
            let entry = NSMenuItem(title: strings(text), action: nil, keyEquivalent: "")
            entry.isEnabled = false
            if secondary {
                entry.attributedTitle = NSAttributedString(string: strings(text), attributes: [
                    .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
            }
            return entry
        case .nextStep(let step):
            let entry = action(strings(step.title)) { [weak self] in self?.perform(step.action) }
            switch step.action {
            case .resume, .removeExclusion: break
            default: entry.isEnabled = router?.canPerform(step.action) ?? false
            }
            return entry
        case .mode(let mode, let checked, let chord):
            let title = strings(mode == .vietnamese ? "menu.vietnamese" : "menu.english")
            let entry = action(title) { [weak self] in
                self?.beforeModeChange?(mode)
                self?.source.setMode(mode, source: .menu)
            }
            entry.state = checked ? .on : .off
            if let chord { Self.applyChord(chord, to: entry) }
            return entry
        case .exclusion(let bundleID, let title, let excluded):
            return action(strings(title)) { [weak self] in
                self?.onExclusion?(bundleID, !excluded)
                self?.refresh()
            }
        case .command(let command, let alternate):
            let entry = action(strings(MenuModel.title(for: command))) { [weak self] in self?.router?.perform(command) }
            switch command {
            case .settings: entry.keyEquivalent = ","
            case .quit: entry.keyEquivalent = "q"
            default: break
            }
            if alternate {
                entry.isAlternate = true
                entry.keyEquivalentModifierMask = [.option]
            }
            entry.isEnabled = isAvailable(command)
            return entry
        }
    }

    private func isAvailable(_ command: MenuModel.Command) -> Bool {
        switch command {
        case .continueSetup: router?.hasSetupWindow ?? false
        case .help: router?.hasHelpWindow ?? false
        case .settings: router?.hasSettingsWindow ?? false
        case .quit, .saveReport: true
        }
    }

    private func perform(_ action: ShellAction) {
        switch action {
        case .resume:
            if case .blocked(.tapUnavailable) = source.status.availability {
                source.resume()
                // A second failure turns `Thử lại` into `Mở lại VietMac`.
                context.tapRetryFailed = source.status.availability == .blocked(.tapUnavailable)
            } else {
                source.resume()
            }
        case .removeExclusion(let bundleID):
            onExclusion?(bundleID, false)
        default:
            router?.perform(action)
        }
        refresh()
    }

    private func action(_ title: String, handler: @escaping @MainActor () -> Void) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title, handler: handler)
        return entry
    }

    /// `⌃⌥V` → key equivalent `v` with Control and Option.
    static func applyChord(_ chord: String, to entry: NSMenuItem) {
        var mask: NSEvent.ModifierFlags = []
        var key = ""
        for character in chord {
            switch character {
            case "⌃": mask.insert(.control)
            case "⌥": mask.insert(.option)
            case "⇧": mask.insert(.shift)
            case "⌘": mask.insert(.command)
            default: key = String(character).lowercased()
            }
        }
        entry.keyEquivalent = key
        entry.keyEquivalentModifierMask = mask
    }
}

/// A menu item that runs a closure, so the menu needs no selector per entry.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() {
        handler()
    }
}
