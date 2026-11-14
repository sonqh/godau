import AppKit
import VietMacShell

/// Wrapping label with system font and color.
@MainActor
func makeLabel(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
               color: NSColor = .labelColor, width: CGFloat = 488) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.preferredMaxLayoutWidth = width
    field.isSelectable = false
    return field
}

/// Shortcut recorder with `Xoá` and `Dùng gợi ý` (ux-spec 6.2). It keeps the old value when a chord is rejected.
@MainActor
final class ShortcutRecorderControl: NSStackView {
    private let strings: Strings
    private var chord: ShortcutChord?
    private let onChange: (ShortcutChord?) -> Void
    private let recordButton = NSButton()
    private let message = NSTextField(labelWithString: "")
    private var monitor: Any?

    init(strings: Strings, chord: ShortcutChord?, onChange: @escaping (ShortcutChord?) -> Void) {
        self.strings = strings
        self.chord = chord
        self.onChange = onChange
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        recordButton.bezelStyle = .push
        recordButton.target = self
        recordButton.action = #selector(startRecording)
        recordButton.setAccessibilityLabel(strings("settings.general.shortcut"))
        let clear = ClosureButton(title: strings("shortcut.clear")) { [weak self] _ in self?.set(nil) }
        clear.bezelStyle = .push
        let suggestion = ClosureButton(title: strings("shortcut.useSuggestion", ShortcutChord.suggested.display)) {
            [weak self] _ in self?.set(.suggested)
        }
        suggestion.bezelStyle = .push
        let row = NSStackView(views: [recordButton, clear, suggestion])
        row.spacing = 8
        message.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        message.isHidden = true
        addArrangedSubview(row)
        addArrangedSubview(message)
        updateTitle(recording: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func set(_ value: ShortcutChord?) {
        stopRecording()
        chord = value
        message.isHidden = true
        updateTitle(recording: false)
        onChange(value)
    }

    private func updateTitle(recording: Bool) {
        recordButton.title = recording ? strings("shortcut.recordPrompt") : (chord?.display ?? strings("shortcut.empty"))
    }

    @objc private func startRecording() {
        guard monitor == nil else { return }
        updateTitle(recording: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.record(event)
            }
            return nil
        }
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 && flags.isEmpty { stopRecording(); return } // Esc cancels.
        var modifiers: ShortcutChord.Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        let result = ShortcutChord.validate(keyCode: event.keyCode, modifiers: modifiers,
                                            keyLabel: Self.label(for: event), modifierOnly: false,
                                            systemShortcuts: HotKeyCenter.systemShortcuts())
        switch result {
        case .success(let recorded):
            set(recorded)
        case .failure(let rejection):
            stopRecording()
            message.stringValue = strings(rejection.message)
            message.isHidden = false
            NSAccessibility.post(element: message, notification: .announcementRequested,
                                 userInfo: [.announcement: message.stringValue])
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        updateTitle(recording: false)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stopRecording() }
    }

    static func label(for event: NSEvent) -> String {
        let named: [UInt16: String] = [49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 123: "←", 124: "→",
                                       125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
                                       97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        if let name = named[event.keyCode] { return name }
        return (event.charactersIgnoringModifiers ?? "").uppercased()
    }
}

/// `Mở VietMac khi đăng nhập` with the system registration state below it (architecture-spec 7.8).
@MainActor
final class LoginControl: NSStackView {
    private let strings: Strings
    private let preferences: ShellPreferences
    private let checkbox: NSButton
    private let state = NSTextField(labelWithString: "")
    private let approve: NSButton

    init(strings: Strings, preferences: ShellPreferences, title: String) {
        self.strings = strings
        self.preferences = preferences
        checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        approve = ClosureButton(title: strings("settings.open")) { _ in LoginItem.openApprovalSettings() }
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 4
        checkbox.state = preferences.loginRequested ? .on : .off
        checkbox.target = self
        checkbox.action = #selector(toggled)
        state.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        state.textColor = .secondaryLabelColor
        approve.bezelStyle = .push
        approve.controlSize = .small
        let stateRow = NSStackView(views: [state, approve])
        stateRow.spacing = 8
        addArrangedSubview(checkbox)
        addArrangedSubview(stateRow)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Reads the system state. Called when the window opens or becomes key, and after each change.
    func refresh() {
        state.stringValue = strings(LoginItem.stateText)
        approve.isHidden = !LoginItem.requiresApproval
    }

    @objc private func toggled() {
        let on = checkbox.state == .on
        preferences.loginRequested = on
        LoginItem.set(on)
        refresh()
    }
}
