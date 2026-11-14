#if DEBUG
import AppKit
import VietMacPlatform
import VietMacShell

/// Debug-only status source. It builds `RuntimeStatus` values with the public initializer and
/// never calls `InputHost` (shell-presentation spec). Release builds do not compile this file's body.
@MainActor
final class StatusSimulator: StatusSource {
    var onStatusChange: ((RuntimeStatus) -> Void)?
    private(set) var status: RuntimeStatus {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    init(from start: RuntimeStatus) {
        status = start
    }

    func setMode(_ mode: InputMode, source: ModeSource) {
        update(mode: mode, modeSource: source,
               availability: mode == .english ? .off : (status.availability == .off ? .active(.observed) : nil))
    }

    func resume() {
        if case .blocked(let reason) = status.availability, reason.needsResume {
            update(availability: reason == .tapUnavailable ? .blocked(.tapUnavailable) : .active(.observed))
        }
    }

    func update(mode: InputMode? = nil, modeSource: ModeSource? = nil, availability: Availability? = nil,
                capabilities: Capabilities? = nil, inputSourceID: String? = nil, frontmost: String?? = nil,
                fieldKind: FieldKind?? = nil, conflicting: String?? = nil, shortcutArmed: Bool? = nil) {
        status = RuntimeStatus(mode: mode ?? status.mode, modeSource: modeSource ?? status.modeSource,
                               availability: availability ?? status.availability,
                               capabilities: capabilities ?? status.capabilities,
                               inputSourceID: inputSourceID ?? status.inputSourceID,
                               frontmostBundleID: frontmost ?? status.frontmostBundleID, profileID: nil,
                               fieldKind: fieldKind ?? status.fieldKind,
                               conflictingBundleID: conflicting ?? status.conflictingBundleID,
                               shortcutArmed: shortcutArmed ?? status.shortcutArmed)
    }
}

/// The `Simulator` submenu appended to the status menu in Debug builds.
@MainActor
final class SimulatorMenu {
    private let controller: StatusItemController
    private let live: StatusSource
    private var simulator: StatusSimulator?
    /// Clears the stored setup progress, so the next launch rule acts as a first launch.
    var resetSetup: () -> Void = {}
    /// Applies the launch rules of ux-spec 4.6 to the current status.
    var simulateLaunch: () -> Void = {}

    init(controller: StatusItemController, live: StatusSource) {
        self.controller = controller
        self.live = live
    }

    func items() -> [NSMenuItem] {
        let root = NSMenuItem(title: "Simulator (Debug)", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.autoenablesItems = false
        root.submenu = menu
        let active = simulator != nil
        menu.addItem(item(active ? "Use Live M0 Status" : "Start Simulator", checked: false) { [self] in
            if active {
                simulator = nil
                controller.attach(live)
            } else {
                let sim = StatusSimulator(from: live.status)
                simulator = sim
                controller.attach(sim)
            }
        })
        menu.addItem(.separator())
        menu.addItem(submenu("UI Language", UILanguage.allCases.map { language in
            item(language == .vi ? "Tiếng Việt" : "English", checked: controller.strings.language == language) { [self] in
                controller.strings = Strings(language: language)
                controller.refresh()
            }
        }))
        menu.addItem(item("Reset Setup Progress", checked: false) { [self] in resetSetup() })
        menu.addItem(item("Apply Launch Rules Now", checked: false) { [self] in simulateLaunch() })
        guard let sim = simulator else { return [.separator(), root] }
        let status = sim.status
        var availability: [NSMenuItem] = [
            item("off (English)", checked: status.availability == .off) { sim.update(mode: .english, availability: .off) },
            item("active(observed)", checked: status.availability == .active(.observed)) {
                sim.update(mode: .vietnamese, availability: .active(.observed))
            },
            item("active(eventOnly)", checked: status.availability == .active(.eventOnly)) {
                sim.update(mode: .vietnamese, availability: .active(.eventOnly))
            },
            .separator(),
        ]
        availability += BlockReason.allCases.map { reason in
            item("blocked(\(reason.rawValue))", checked: status.availability == .blocked(reason)) {
                sim.update(mode: .vietnamese, availability: .blocked(reason))
            }
        }
        availability.append(.separator())
        availability += StandbyReason.allCases.map { reason in
            item("standby(\(reason.rawValue))", checked: status.availability == .standby(reason)) {
                sim.update(mode: .vietnamese, availability: .standby(reason))
            }
        }
        menu.addItem(submenu("Availability", availability))
        let caps = status.capabilities
        menu.addItem(submenu("Capabilities", [
            item("Accessibility", checked: caps.accessibility) {
                sim.update(capabilities: Capabilities(accessibility: !caps.accessibility,
                                                      eventListening: caps.eventListening, eventPosting: caps.eventPosting))
            },
            item("Input Monitoring", checked: caps.eventListening) {
                sim.update(capabilities: Capabilities(accessibility: caps.accessibility,
                                                      eventListening: !caps.eventListening, eventPosting: caps.eventPosting))
            },
            item("Event Posting", checked: caps.eventPosting) {
                sim.update(capabilities: Capabilities(accessibility: caps.accessibility,
                                                      eventListening: caps.eventListening, eventPosting: !caps.eventPosting))
            },
        ]))
        let sources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US",
                       "com.apple.inputmethod.VietnameseIM.VietnameseTelex"]
        menu.addItem(submenu("Input Source", sources.map { id in
            item(id, checked: status.inputSourceID == id) { sim.update(inputSourceID: id) }
        }))
        let apps: [String?] = ["com.google.Chrome", "com.apple.Safari", "company.thebrowser.dia",
                               "com.microsoft.VSCode", "com.apple.Notes", "com.tinyspeck.slackmacgap", nil]
        menu.addItem(submenu("Frontmost App", apps.map { id in
            item(id ?? "none", checked: status.frontmostBundleID == id) { sim.update(frontmost: .some(id)) }
        }))
        menu.addItem(submenu("Field Kind", ([nil] + FieldKind.allCases.map(Optional.some)).map { kind in
            item(kind?.rawValue ?? "none", checked: status.fieldKind == kind) { sim.update(fieldKind: .some(kind)) }
        }))
        menu.addItem(submenu("Conflicting Tool", ["com.tuyenmai.openkey", nil].map { id in
            item(id ?? "none", checked: status.conflictingBundleID == id) { sim.update(conflicting: .some(id)) }
        }))
        menu.addItem(item("Shortcut Armed", checked: status.shortcutArmed) {
            sim.update(shortcutArmed: !status.shortcutArmed)
        })
        menu.addItem(item("Toggle Mode with Shortcut", checked: false) {
            let next: InputMode = status.mode == .vietnamese ? .english : .vietnamese
            sim.update(mode: next, modeSource: .shortcut,
                       availability: next == .english ? .off : .active(.observed))
        })
        return [.separator(), root]
    }

    private func item(_ title: String, checked: Bool, _ handler: @escaping @MainActor () -> Void) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title) { [weak controller] in
            handler()
            controller?.refresh()
        }
        entry.state = checked ? .on : .off
        return entry
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        root.submenu = menu
        return root
    }
}
#endif
