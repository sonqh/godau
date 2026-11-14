import AppKit
import VietMacPlatform
import VietMacShell

/// The Setup and Help window (guided-setup spec). Every screen is built from `SetupScreen`,
/// which is a pure function of the status, the plan, and this window's context.
@MainActor
final class SetupWindowController: NSWindowController, NSWindowDelegate {
    enum Mode: Equatable {
        case setup(SetupStep)
        case help(HelpPage)
    }

    private let status: () -> RuntimeStatus
    private let setMode: (InputMode) -> Void
    private let preferences: ShellPreferences
    weak var router: ShellRouter?
    var strings = Strings()
    var features = SetupFeatures.current
    /// Called after the shortcut changes on the Ready step.
    var onConfigurationChange: () -> Void = {}

    private(set) var mode: Mode = .setup(.welcome)
    private var context = SetupContext()
    private var lastScreen: SetupScreen?
    private var lastRenderedMode: InputMode?
    private var lastFrontmost: String?
    private var reopenTimer: Timer?
    private var primaryButton: NSButton?
    private var announcement: String?

    init(status: @escaping () -> RuntimeStatus, setMode: @escaping (InputMode) -> Void, preferences: ShellPreferences) {
        self.status = status
        self.setMode = setMode
        self.preferences = preferences
        let window = SetupWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.onCancel = { [weak self] in self?.cancel() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var isVisible: Bool { window?.isVisible ?? false }

    // MARK: Opening

    /// Opens setup at a step. `activate` false shows the window without taking keyboard focus
    /// (the launch fallback until U-15).
    func showSetup(at step: SetupStep, updateHeading: Bool = false, activate: Bool = true) {
        context = SetupContext(updateHeading: updateHeading)
        mode = .setup(step)
        render()
        present(activate: activate)
    }

    /// Opens setup where the user should continue: the first missing item, else the last step seen.
    func showSetupContinuing() {
        let current = status()
        let plan = SetupPlan(status: current, features: features)
        showSetup(at: plan.startStep(status: current, lastSeen: preferences.lastSetupStep))
    }

    func showHelp(_ page: HelpPage = .telex) {
        mode = .help(page)
        render()
        present(activate: true)
    }

    private func present(activate: Bool) {
        guard let window else { return }
        if !window.isVisible { window.center() }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    #if DEBUG
    /// Renders one screen without showing the window, for Debug snapshots.
    func snapshot(_ mode: Mode, context: SetupContext = SetupContext()) -> NSView? {
        self.mode = mode
        self.context = context
        lastScreen = nil
        render(keepContext: true)
        return window?.contentView
    }
    #endif

    // MARK: Status changes

    func statusChanged(_ current: RuntimeStatus) {
        defer { lastFrontmost = current.frontmostBundleID }
        guard isVisible, case .setup(let step) = mode else { return }
        let plan = SetupPlan(status: current, features: features)
        let wasSatisfied = lastScreen?.statusRow?.satisfied ?? false
        let nowSatisfied = plan.isSatisfied(step, status: current)
        watchReturnFromSystemSettings(current, step: step, satisfied: nowSatisfied)
        render()
        guard nowSatisfied, !wasSatisfied, [.inputMonitoring, .accessibility, .keyboard, .otherTool].contains(step)
        else { return }
        // Grant change feedback: focus on Continue and announce. Raise only while System Settings is frontmost.
        if current.frontmostBundleID == SystemPanes.systemSettingsBundleID {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        if let primaryButton { window?.makeFirstResponder(primaryButton) }
        if let row = lastScreen?.statusRow, let window {
            NSAccessibility.post(element: window, notification: .announcementRequested,
                                 userInfo: [.announcement: strings(row.value),
                                            .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    /// Offers `Mở lại VietMac` when a grant is still missing 20 s after the user left System Settings.
    private func watchReturnFromSystemSettings(_ current: RuntimeStatus, step: SetupStep, satisfied: Bool) {
        guard step == .inputMonitoring || step == .accessibility, !satisfied else {
            reopenTimer?.invalidate()
            reopenTimer = nil
            return
        }
        let settings = SystemPanes.systemSettingsBundleID
        guard lastFrontmost == settings, current.frontmostBundleID != settings, reopenTimer == nil,
              !context.reopenOffered else { return }
        let timer = Timer(timeInterval: SetupContext.reopenDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, case .setup(let step) = self.mode else { return }
                self.reopenTimer = nil
                let current = self.status()
                if !SetupPlan(status: current, features: self.features).isSatisfied(step, status: current) {
                    self.context.reopenOffered = true
                    self.render()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reopenTimer = timer
    }

    // MARK: Commands

    private func perform(_ command: SetupCommand) {
        guard case .setup(let step) = mode else { return }
        let current = status()
        let plan = SetupPlan(status: current, features: features)
        switch command {
        case .start, .next:
            if let next = plan.next(after: step) { go(to: next) }
        case .back:
            if let previous = plan.previous(before: step) { go(to: previous) }
        case .later:
            close()
        case .requestPermission(let grant):
            PermissionRequester.request(grant)
        case .reopen:
            router?.perform(.relaunch)
        case .openKeyboardSettings:
            SystemPanes.open(.keyboard)
        case .openNotes:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .textChanged:
            context.tryItAnswer = .changed
            render()
        case .textNotChanged:
            context.tryItAnswer = .notChanged
            render()
        case .done:
            preferences.setupCompletedOnce = true
            close()
        case .shell(let action):
            router?.perform(action)
        }
    }

    private func go(to step: SetupStep) {
        mode = .setup(step)
        context.reopenOffered = false
        context.tryItAnswer = nil
        reopenTimer?.invalidate()
        reopenTimer = nil
        render()
        if let primaryButton { window?.makeFirstResponder(primaryButton) }
    }

    /// Esc acts as `Để sau` in setup and closes Help.
    private func cancel() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        reopenTimer?.invalidate()
        reopenTimer = nil
    }

    // MARK: Rendering

    private func render(keepContext: Bool = false) {
        guard let window else { return }
        switch mode {
        case .setup(let step):
            let current = status()
            let plan = SetupPlan(status: current, features: features)
            if !keepContext { context.supportedSourceEnabled = SystemNames.supportedSourceEnabled() }
            let screen = SetupScreen(step: step, plan: plan, status: current, context: context,
                                     names: SystemNames.resolver())
            preferences.lastSetupStep = step
            window.title = strings("setup.windowTitle")
            if screen != lastScreen || current.mode != lastRenderedMode || window.contentView?.subviews.isEmpty != false {
                window.contentView = setupView(screen, mode: current.mode)
                lastScreen = screen
                lastRenderedMode = current.mode
            }
        case .help(let page):
            lastScreen = nil
            window.title = strings("help.windowTitle")
            window.contentView = helpView(page)
        }
        let size = window.contentView?.fittingSize ?? .zero
        window.setContentSize(NSSize(width: 560, height: max(460, size.height)))
    }

    private func setupView(_ screen: SetupScreen, mode: InputMode) -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        content.setAccessibilityLabel(strings(screen.heading))

        let progress = NSProgressIndicator()
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = Double(screen.count)
        progress.doubleValue = Double(screen.position)
        progress.style = .bar
        progress.setAccessibilityLabel(strings(screen.indicator))
        let indicator = label(strings(screen.indicator), size: NSFont.smallSystemFontSize, weight: .semibold,
                              color: .secondaryLabelColor)
        let indicatorRow = NSStackView(views: [indicator, progress])
        indicatorRow.spacing = 10
        content.addArrangedSubview(indicatorRow)
        indicatorRow.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        let heading = label(strings(screen.heading), size: 20, weight: .bold)
        heading.setAccessibilityRole(.staticText)
        content.addArrangedSubview(heading)
        for paragraph in screen.paragraphs { content.addArrangedSubview(markdownLabel(strings(paragraph))) }
        if screen.showsModeSwitch { content.addArrangedSubview(modeSwitch(mode)) }
        for (index, instruction) in screen.instructions.enumerated() {
            let prefix = screen.instructions.count > 1 ? "\(index + 1). " : ""
            content.addArrangedSubview(markdownLabel(prefix + strings(instruction)))
        }
        if let row = screen.statusRow { content.addArrangedSubview(statusRow(row)) }
        if let extra = screen.extraRow {
            let row = NSStackView(views: [markdownLabel(strings(extra.text)), button(extra.button, prominent: false)])
            row.spacing = 10
            content.addArrangedSubview(row)
        }
        if !screen.contentButtons.isEmpty {
            let row = NSStackView(views: screen.contentButtons.map { button($0, prominent: false) })
            row.spacing = 8
            content.addArrangedSubview(row)
        }
        if let problem = screen.tryItProblem {
            content.addArrangedSubview(label(strings(problem.statusLine), size: 13, weight: .semibold))
            if let detail = problem.detail { content.addArrangedSubview(markdownLabel(strings(detail))) }
            if let step = problem.step {
                content.addArrangedSubview(button(SetupButton(step.title, .shell(step.action)), prominent: false))
            }
        }
        if screen.showsReadyControls {
            content.addArrangedSubview(label(strings("setup.ready.shortcutLabel"), size: 13, weight: .semibold))
            content.addArrangedSubview(ShortcutRecorderControl(strings: strings, chord: preferences.shortcut) {
                [weak self] chord in
                self?.preferences.shortcut = chord
                self?.onConfigurationChange()
            })
            content.addArrangedSubview(LoginControl(strings: strings, preferences: preferences,
                                                    title: strings("setup.ready.login")))
        }
        for note in screen.notes {
            content.addArrangedSubview(markdownLabel(strings(note), size: NSFont.smallSystemFontSize,
                                                     color: .secondaryLabelColor))
        }
        if let disclosure = screen.disclosure { content.addArrangedSubview(disclosureView(disclosure)) }

        // Focus order: content, link, back, secondary, primary.
        var bottom: [NSView] = []
        if let back = screen.back { bottom.append(button(back, prominent: false)) }
        if let link = screen.link { bottom.append(linkButton(link)) }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottom.append(spacer)
        if let secondary = screen.secondary { bottom.append(button(secondary, prominent: false)) }
        let primary = button(screen.primary, prominent: true)
        primaryButton = primary
        bottom.append(primary)
        let bar = NSStackView(views: bottom)
        bar.spacing = 12
        return frame(content: content, bottom: bar)
    }

    private func helpView(_ page: HelpPage) -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        let picker = NSPopUpButton()
        for item in HelpPage.allCases { picker.addItem(withTitle: strings("help.\(item.rawValue).title")) }
        picker.selectItem(at: HelpPage.allCases.firstIndex(of: page) ?? 0)
        picker.setAccessibilityLabel(strings("help.windowTitle"))
        picker.target = self
        picker.action = #selector(helpPageChosen(_:))
        content.addArrangedSubview(picker)
        content.addArrangedSubview(label(strings("help.\(page.rawValue).title"), size: 20, weight: .bold))
        content.addArrangedSubview(markdownLabel(strings("help.\(page.rawValue).body")))
        primaryButton = nil
        return frame(content: content, bottom: nil)
    }

    @objc private func helpPageChosen(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard HelpPage.allCases.indices.contains(index) else { return }
        mode = .help(HelpPage.allCases[index])
        render()
    }

    private func frame(content: NSStackView, bottom: NSStackView?) -> NSView {
        let root = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        var constraints = [
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 36),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -36),
            root.widthAnchor.constraint(equalToConstant: 560),
        ]
        if let bottom {
            bottom.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(bottom)
            constraints += [
                bottom.topAnchor.constraint(greaterThanOrEqualTo: content.bottomAnchor, constant: 16),
                bottom.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 36),
                bottom.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -36),
                bottom.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            ]
        } else {
            constraints.append(content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24))
        }
        NSLayoutConstraint.activate(constraints)
        return root
    }

    private func modeSwitch(_ mode: InputMode) -> NSView {
        let toggle = NSSwitch()
        toggle.state = mode == .vietnamese ? .on : .off
        toggle.target = self
        toggle.action = #selector(modeSwitched(_:))
        let title = strings("setup.try.switch")
        toggle.setAccessibilityLabel(title)
        let row = NSStackView(views: [label(title, size: 13, weight: .semibold), toggle])
        row.spacing = 10
        return row
    }

    @objc private func modeSwitched(_ sender: NSSwitch) {
        setMode(sender.state == .on ? .vietnamese : .english)
        render()
    }

    private func statusRow(_ row: SetupStatusRow) -> NSView {
        let symbol = NSImage(systemSymbolName: row.satisfied ? "checkmark.circle.fill" : "xmark.circle",
                             accessibilityDescription: nil)
        let icon = NSImageView(image: symbol ?? NSImage())
        icon.contentTintColor = row.satisfied ? .systemGreen : .secondaryLabelColor
        var views: [NSView] = [icon]
        if let name = row.label {
            let title = label(strings(name), size: 13)
            title.setContentHuggingPriority(.defaultLow, for: .horizontal)
            views.append(title)
        }
        views.append(label(strings(row.value), size: 13, weight: .semibold))
        let stack = NSStackView(views: views)
        stack.spacing = 8
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.staticText)
        stack.setAccessibilityLabel(views.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: ", "))
        return stack
    }

    private func disclosureView(_ disclosure: SetupDisclosure) -> NSView {
        let body = markdownLabel(strings(disclosure.body), size: NSFont.smallSystemFontSize, color: .secondaryLabelColor)
        body.isHidden = true
        return DisclosureControl(title: strings(disclosure.title), content: body)
    }

    private func button(_ spec: SetupButton, prominent: Bool) -> NSButton {
        let command = spec.command
        let button = ClosureButton(title: strings(spec.title)) { [weak self] _ in self?.perform(command) }
        button.bezelStyle = .push
        button.controlSize = .large
        if prominent {
            button.keyEquivalent = "\r"
            button.hasDestructiveAction = false
        }
        return button
    }

    private func linkButton(_ spec: SetupButton) -> NSButton {
        let command = spec.command
        let button = ClosureButton(title: strings(spec.title)) { [weak self] _ in self?.perform(command) }
        button.isBordered = false
        button.contentTintColor = .linkColor
        button.attributedTitle = NSAttributedString(string: strings(spec.title),
                                                    attributes: [.foregroundColor: NSColor.linkColor])
        return button
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.preferredMaxLayoutWidth = 488
        field.isSelectable = false
        return field
    }

    /// Body text with `**bold**` and `code` spans, rendered with system fonts and colors.
    private func markdownLabel(_ text: String, size: CGFloat = 13, color: NSColor = .labelColor) -> NSTextField {
        let field = label(text, size: size, color: color)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let parsed = try? AttributedString(markdown: text, options: options) else { return field }
        let result = NSMutableAttributedString()
        for run in parsed.runs {
            let piece = String(parsed[run.range].characters)
            var font = NSFont.systemFont(ofSize: size)
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) { font = .systemFont(ofSize: size, weight: .semibold) }
                if intent.contains(.code) { font = .monospacedSystemFont(ofSize: size - 1, weight: .regular) }
            }
            result.append(NSAttributedString(string: piece, attributes: [.font: font, .foregroundColor: color]))
        }
        field.attributedStringValue = result
        return field
    }
}

/// A borderless toggle with a chevron that shows or hides its content. Reachable with Tab and Space.
@MainActor
final class DisclosureControl: NSStackView {
    private let toggle: NSButton
    private let content: NSView
    var onToggle: (Bool) -> Void = { _ in }

    init(title: String, content: NSView, open: Bool = false) {
        self.content = content
        toggle = NSButton(title: title, target: nil, action: nil)
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        toggle.isBordered = false
        toggle.setButtonType(.pushOnPushOff)
        toggle.imagePosition = .imageLeading
        toggle.contentTintColor = .linkColor
        toggle.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.linkColor, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)])
        toggle.state = open ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggled)
        content.isHidden = !open
        updateImage()
        addArrangedSubview(toggle)
        addArrangedSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func updateImage() {
        let open = toggle.state == .on
        toggle.image = NSImage(systemSymbolName: open ? "chevron.down" : "chevron.right", accessibilityDescription: nil)
        toggle.setAccessibilityExpanded(open)
    }

    @objc private func toggled() {
        content.isHidden = toggle.state == .off
        updateImage()
        onToggle(toggle.state == .on)
    }
}

/// Routes Esc to the controller: `Để sau` in setup, close in Help.
final class SetupWindow: NSWindow {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// A button that runs a closure.
@MainActor
final class ClosureButton: NSButton {
    private var handler: (NSButton) -> Void = { _ in }

    convenience init(title: String, handler: @escaping (NSButton) -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.handler = handler
        target = self
        action = #selector(run)
    }

    @objc private func run() {
        handler(self)
    }
}
