import AppKit
import VietMacPlatform
import VietMacShell

/// Settings with the General, Apps, and Status toolbar tabs (settings-window spec).
/// Closing it changes nothing; it remembers the last tab.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let status: () -> RuntimeStatus
    private let counters: () -> [(String, String)]
    private let preferences: ShellPreferences
    /// Called after the shortcut or the exclusions change, so the host applies the new configuration.
    var onConfigurationChange: () -> Void = {}
    weak var router: ShellRouter?
    var strings = Strings()
    var features = SetupFeatures.current
    var catalog = ProfileCatalog.stub

    private let tabs = SettingsTabs()
    private var notArmedLabel: NSTextField?
    private var login: LoginControl?
    private var detailsOpen = false
    private var lastStatus: RuntimeStatus?

    init(status: @escaping () -> RuntimeStatus, counters: @escaping () -> [(String, String)],
         preferences: ShellPreferences) {
        self.status = status
        self.counters = counters
        self.preferences = preferences
        let window = SettingsWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.onCancel = { [weak self] in self?.close() }
        tabs.tabStyle = .toolbar
        tabs.onSelect = { [weak self] tab in
            self?.preferences.lastSettingsTab = tab
            self?.resize()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var isVisible: Bool { window?.isVisible ?? false }

    func show(_ tab: SettingsTab? = nil) {
        rebuild()
        let selected = tab ?? preferences.lastSettingsTab
        tabs.selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: selected) ?? 0
        preferences.lastSettingsTab = selected
        window?.title = strings("settings.windowTitle")
        resize()
        if !(window?.isVisible ?? false) { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        login?.refresh()
    }

    func statusChanged(_ current: RuntimeStatus) {
        guard isVisible, current != lastStatus else { return }
        lastStatus = current
        updateNotArmed(current)
        replace(.status, with: statusView(current))
    }

    #if DEBUG
    /// Builds every tab without showing the window, for Debug snapshots.
    func snapshots() -> [(SettingsTab, NSView)] {
        let current = status()
        detailsOpen = true
        defer { detailsOpen = false }
        return [(.general, generalView(current)), (.apps, appsView()), (.status, statusView(current))]
    }
    #endif

    // MARK: Building

    private func rebuild() {
        let current = status()
        lastStatus = current
        let items: [(SettingsTab, String, NSView)] = [
            (.general, "gearshape", generalView(current)),
            (.apps, "square.grid.2x2", appsView()),
            (.status, "checkmark.shield", statusView(current)),
        ]
        let selected = tabs.selectedTabViewItemIndex
        tabs.suppressSelection = true
        while !tabs.tabViewItems.isEmpty { tabs.removeTabViewItem(tabs.tabViewItems[0]) }
        for (tab, symbol, view) in items {
            let controller = NSViewController()
            controller.view = view
            controller.preferredContentSize = view.fittingSize
            let item = NSTabViewItem(viewController: controller)
            item.label = strings("settings.tab.\(tab.rawValue)")
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            tabs.addTabViewItem(item)
        }
        if selected >= 0 && selected < items.count { tabs.selectedTabViewItemIndex = selected }
        tabs.suppressSelection = false
    }

    private func replace(_ tab: SettingsTab, with view: NSView) {
        guard let index = SettingsTab.allCases.firstIndex(of: tab), index < tabs.tabViewItems.count,
              let controller = tabs.tabViewItems[index].viewController else { return }
        controller.view = view
        controller.preferredContentSize = view.fittingSize
        if tabs.selectedTabViewItemIndex == index { resize() }
    }

    private func resize() {
        guard let window, tabs.selectedTabViewItemIndex >= 0,
              let view = tabs.tabViewItems[tabs.selectedTabViewItemIndex].viewController?.view else { return }
        let size = view.fittingSize
        let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        var origin = window.frame.origin
        origin.y += window.frame.height - frame.height
        window.setFrame(NSRect(origin: origin, size: frame.size), display: true)
    }

    private func page(_ views: [NSView], width: CGFloat) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        for case let box as NSBox in views {
            box.widthAnchor.constraint(equalToConstant: width - 48).isActive = true
        }
        return stack
    }

    private func generalView(_ current: RuntimeStatus) -> NSView {
        let shortcutTitle = makeLabel(strings("settings.general.shortcut"), weight: .semibold, width: 472)
        let recorder = ShortcutRecorderControl(strings: strings, chord: preferences.shortcut) { [weak self] chord in
            guard let self else { return }
            self.preferences.shortcut = chord
            self.onConfigurationChange()
            self.updateNotArmed(self.status())
        }
        let notArmed = makeLabel("", size: NSFont.smallSystemFontSize, color: .secondaryLabelColor, width: 472)
        notArmedLabel = notArmed
        updateNotArmed(current)
        let login = LoginControl(strings: strings, preferences: preferences, title: strings("settings.general.login"))
        self.login = login
        let telex = ClosureButton(title: strings("settings.general.telex")) { [weak self] _ in
            self?.router?.perform(.openHelp(.telex))
        }
        telex.isBordered = false
        telex.contentTintColor = .linkColor
        telex.attributedTitle = NSAttributedString(string: strings("settings.general.telex"),
                                                   attributes: [.foregroundColor: NSColor.linkColor])
        return page([shortcutTitle, recorder, notArmed, NSBox.separator(), login, NSBox.separator(), telex], width: 520)
    }

    private func updateNotArmed(_ current: RuntimeStatus) {
        guard let label = notArmedLabel else { return }
        let reason = ShortcutNotice.notArmedReason(status: current, configured: preferences.shortcut != nil,
                                                   features: features)
        label.stringValue = reason.map { strings("shortcut.notArmed", strings($0)) } ?? ""
        label.isHidden = reason == nil
    }

    private func appsView() -> NSView {
        let model = AppsTab(catalog: catalog, excluded: preferences.excluded, names: SystemNames.resolver())
        let header = [strings("settings.apps.column.app"), strings("settings.apps.column.fields"),
                      strings("settings.apps.column.type")]
            .map { makeLabel($0, size: NSFont.smallSystemFontSize, weight: .semibold, color: .secondaryLabelColor,
                             width: 200) }
        let grid = NSGridView(views: [header])
        grid.rowSpacing = 10
        grid.columnSpacing = 16
        for row in model.rows {
            let name = makeLabel(strings(row.name), weight: .semibold, width: 110)
            let fields = NSStackView(views: row.fields.map { field in
                let kind = makeLabel(strings(field.name), size: 12, width: 220)
                kind.setContentHuggingPriority(.defaultLow, for: .horizontal)
                let state = makeLabel(strings(field.state), size: 12, weight: field.supported ? .semibold : .regular,
                                      color: field.supported ? .systemGreen : .secondaryLabelColor, width: 120)
                let line = NSStackView(views: [kind, state])
                line.spacing = 8
                line.widthAnchor.constraint(equalToConstant: 330).isActive = true
                return line
            })
            fields.orientation = .vertical
            fields.alignment = .leading
            fields.spacing = 3
            let bundleID = row.bundleID
            let checkbox = ClosureButton(title: "") { [weak self] sender in
                self?.setExcluded(bundleID, sender.state == .off)
            }
            checkbox.setButtonType(.switch)
            checkbox.state = row.typesVietnamese ? .on : .off
            checkbox.setAccessibilityLabel("\(strings("settings.apps.column.type")): \(strings(row.name))")
            grid.addRow(with: [name, fields, checkbox])
        }
        grid.column(at: 2).xPlacement = .center
        for index in 1..<grid.numberOfRows { grid.row(at: index).yPlacement = .top }
        let footer = makeLabel(strings("settings.apps.footer"), size: 12, color: .secondaryLabelColor, width: 592)
        return page([grid, footer], width: 640)
    }

    private func setExcluded(_ bundleID: String, _ excluded: Bool) {
        var set = preferences.excluded
        if excluded { set.insert(bundleID) } else { set.remove(bundleID) }
        preferences.excluded = set
        onConfigurationChange()
    }

    /// Called when the exclusions change elsewhere, for example from the menu.
    func exclusionsChanged() {
        guard isVisible else { return }
        replace(.apps, with: appsView())
    }

    private func statusView(_ current: RuntimeStatus) -> NSView {
        let model = StatusTab(status: current, features: features, names: SystemNames.resolver())
        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.rowSpacing = 10
        grid.columnSpacing = 14
        for row in model.rows {
            let symbol = NSImage(systemSymbolName: row.ok ? "checkmark.circle.fill" : "xmark.circle",
                                 accessibilityDescription: nil)
            let icon = NSImageView(image: symbol ?? NSImage())
            icon.contentTintColor = row.ok ? .systemGreen : .secondaryLabelColor
            let value = NSStackView(views: [icon, makeLabel(strings(row.value), weight: .semibold, width: 200)])
            value.spacing = 6
            var action: NSView = NSView()
            if let rowAction = row.action {
                let button = ClosureButton(title: strings("settings.openEllipsis")) { _ in
                    switch rowAction {
                    case .requestPermission(let step): PermissionRequester.request(step)
                    case .openKeyboardSettings: SystemPanes.open(.keyboard)
                    }
                }
                button.bezelStyle = .push
                button.setAccessibilityLabel("\(strings("settings.openEllipsis")) \(strings(row.label))")
                action = button
            }
            grid.addRow(with: [makeLabel(strings(row.label), width: 160), value, action])
        }
        var version = BuildInfo.version
        if BuildInfo.isAdHoc { version += "\n" + strings("settings.status.adHoc") }
        grid.addRow(with: [makeLabel(strings("settings.status.version"), width: 160),
                           makeLabel(version, width: 300), NSView()])
        grid.column(at: 0).xPlacement = .leading

        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 3
        let lines = StatusTab.technicalDetails(status: current).map { "\($0.0): \($0.1)" }
            + ["", strings("settings.status.countersSince")] + counters().map { "\($0.0): \($0.1)" }
        for line in lines {
            let label = makeLabel(line, size: 11, color: .secondaryLabelColor, width: 472)
            label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            details.addArrangedSubview(label)
        }
        let save = ClosureButton(title: strings("menu.saveReport")) { [weak self] _ in self?.router?.perform(.saveReport) }
        save.bezelStyle = .push
        details.addArrangedSubview(save)
        let toggle = DisclosureControl(title: strings("settings.status.details"), content: details, open: detailsOpen)
        toggle.onToggle = { [weak self] open in
            self?.detailsOpen = open
            self?.resize()
        }
        return page([grid, NSBox.separator(), toggle], width: 520)
    }
}

/// Tab controller that reports user tab changes.
@MainActor
final class SettingsTabs: NSTabViewController {
    var onSelect: (SettingsTab) -> Void = { _ in }
    var suppressSelection = false

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard !suppressSelection, let tabViewItem, let index = tabViewItems.firstIndex(of: tabViewItem),
              SettingsTab.allCases.indices.contains(index) else { return }
        onSelect(SettingsTab.allCases[index])
    }
}

/// Esc closes Settings.
final class SettingsWindow: NSWindow {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
