import AppKit
import Carbon
import Security
import ServiceManagement
import VietMacPlatform
import VietMacShell

/// The mode shortcut as a system hot key. M0 has no shortcut matching in the key callback, so the shell
/// registers the chord only while `shortcutArmed` is true and unregisters it otherwise; an unregistered
/// chord reaches the frontmost app as an ordinary key press. M2 replaces this with callback matching.
@MainActor
final class HotKeyCenter {
    private static var current: HotKeyCenter?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private(set) var registered: ShortcutChord?
    var onPress: (() -> Void)?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // One event per press; a held chord does not repeat.
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKeyCenter.current?.onPress?() } }
            return noErr
        }, 1, &spec, nil, &handler)
        HotKeyCenter.current = self
    }

    func update(chord: ShortcutChord?, armed: Bool) {
        let wanted = armed ? chord : nil
        guard wanted != registered else { return }
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        registered = nil
        guard let wanted else { return }
        var modifiers: UInt32 = 0
        if wanted.modifiers.contains(.control) { modifiers |= UInt32(controlKey) }
        if wanted.modifiers.contains(.option) { modifiers |= UInt32(optionKey) }
        if wanted.modifiers.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if wanted.modifiers.contains(.command) { modifiers |= UInt32(cmdKey) }
        var created: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x564D_4143), id: 1) // 'VMAC'
        if RegisterEventHotKey(UInt32(wanted.keyCode), modifiers, id, GetApplicationEventTarget(), 0, &created) == noErr {
            reference = created
            registered = wanted
        }
    }

    /// Enabled system shortcuts from System Settings › Keyboard Shortcuts.
    static func systemShortcuts() -> Set<ShortcutChord.Key> {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr, let list = array?.takeRetainedValue() as? [[String: Any]] else {
            return []
        }
        var keys = Set<ShortcutChord.Key>()
        for entry in list {
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let carbon = entry[kHISymbolicHotKeyModifiers as String] as? Int else { continue }
            var modifiers: ShortcutChord.Modifiers = []
            if carbon & controlKey != 0 { modifiers.insert(.control) }
            if carbon & optionKey != 0 { modifiers.insert(.option) }
            if carbon & shiftKey != 0 { modifiers.insert(.shift) }
            if carbon & cmdKey != 0 { modifiers.insert(.command) }
            keys.insert(ShortcutChord.Key(keyCode: UInt16(truncatingIfNeeded: code), modifiers: modifiers))
        }
        return keys
    }
}

/// Login startup through `SMAppService.mainApp`. The system registration is the truth (architecture-spec 7.8).
@MainActor
enum LoginItem {
    static var stateText: LocalizedText {
        switch SMAppService.mainApp.status {
        case .enabled: LocalizedText("login.enabled")
        case .requiresApproval: LocalizedText("login.requiresApproval")
        case .notFound: LocalizedText("login.notFound")
        default: LocalizedText("login.notRegistered")
        }
    }

    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            // The state line below the checkbox shows what the system reports.
        }
    }

    static func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Version and signature for the Status tab.
enum BuildInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        #if DEBUG
        return "\(short) (\(build), Debug)"
        #else
        return "\(short) (\(build))"
        #endif
    }

    /// Ad hoc signed builds lose their permissions after each rebuild.
    static var isAdHoc: Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else {
            return true
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return true }
        let flags = (dictionary[kSecCodeInfoFlags as String] as? UInt32) ?? 0
        return flags & UInt32(SecCodeSignatureFlags.adhoc.rawValue) != 0 || dictionary[kSecCodeInfoIdentifier as String] == nil
    }
}

/// The non-activating mode HUD (ux-spec 6.3). It never becomes key and ignores the mouse.
@MainActor
final class ModeHUD {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let panel: Panel
    private let glyph = NSTextField(labelWithString: "")
    private let label = NSTextField(labelWithString: "")
    private var hideTimer: Timer?

    init() {
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 168, height: 64),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        let material = NSVisualEffectView()
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 18
        material.layer?.masksToBounds = true
        glyph.font = .systemFont(ofSize: 13, weight: .bold)
        glyph.wantsLayer = true
        glyph.layer?.borderWidth = 1.5
        glyph.layer?.borderColor = NSColor.labelColor.cgColor
        glyph.layer?.cornerRadius = 5
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        let row = NSStackView(views: [glyph, label])
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(row)
        NSLayoutConstraint.activate([row.centerXAnchor.constraint(equalTo: material.centerXAnchor),
                                     row.centerYAnchor.constraint(equalTo: material.centerYAnchor)])
        panel.contentView = material
        panel.setAccessibilityElement(false)
    }

    func show(mode: InputMode, strings: Strings) {
        glyph.stringValue = mode == .vietnamese ? " VI " : " EN "
        label.stringValue = strings(ModeHUDRule.text(for: mode))
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                         y: frame.minY + frame.height / 3 - panel.frame.height / 2))
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: label.stringValue,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 0.8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide(reduceMotion: reduceMotion) }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    private func hide(reduceMotion: Bool) {
        guard !reduceMotion else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; panel.animator().alphaValue = 0 },
                                             completionHandler: { [panel] in
                                                 MainActor.assumeIsolated { panel.orderOut(nil) }
                                             })
    }
}
