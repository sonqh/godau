import VietMacPlatform

/// The required apps and their field kinds, with an evidence label for each. It gates nothing:
/// Vietnamese works in every app that is not excluded (open-app-coverage).
public struct ProfileCatalog: Equatable, Sendable {
    public struct Profile: Equatable, Hashable, Sendable {
        public let id: String
        public let bundleID: String
        public let field: FieldKind
        public let assurance: Assurance
        /// Native evidence exists for this field family. A label only.
        public let tested: Bool

        public init(id: String, bundleID: String, field: FieldKind, assurance: Assurance = .observed,
                    tested: Bool) {
            self.id = id
            self.bundleID = bundleID
            self.field = field
            self.assurance = assurance
            self.tested = tested
        }
    }

    public let profiles: [Profile]

    public init(profiles: [Profile]) {
        self.profiles = profiles
    }

    /// Bundle IDs in table order, each once.
    public var bundleIDs: [String] {
        var seen = Set<String>()
        return profiles.map(\.bundleID).filter { seen.insert($0).inserted }
    }

    public func profiles(for bundleID: String) -> [Profile] {
        profiles.filter { $0.bundleID == bundleID }
    }

    /// The ten profiles of architecture-spec 6.4. `tested` follows the ledger: browser page fields by
    /// native automation (2026-11-14), address bars, the VS Code editor, and Quick Open by Son's physical
    /// typing (2026-11-16). VS Code Find and Notes have no accepted evidence.
    public static let stub = ProfileCatalog(profiles: [
        Profile(id: "chrome.webText", bundleID: "com.google.Chrome", field: .webText, tested: true),
        Profile(id: "chrome.addressBar", bundleID: "com.google.Chrome", field: .addressBar, assurance: .eventOnly,
                tested: true),
        Profile(id: "safari.webText", bundleID: "com.apple.Safari", field: .webText, tested: true),
        Profile(id: "safari.addressBar", bundleID: "com.apple.Safari", field: .addressBar, assurance: .eventOnly,
                tested: true),
        Profile(id: "dia.webText", bundleID: "company.thebrowser.dia", field: .webText, tested: true),
        Profile(id: "dia.addressBar", bundleID: "company.thebrowser.dia", field: .addressBar, assurance: .eventOnly,
                tested: true),
        Profile(id: "vscode.editor", bundleID: "com.microsoft.VSCode", field: .editor, assurance: .eventOnly,
                tested: true),
        Profile(id: "vscode.find", bundleID: "com.microsoft.VSCode", field: .find, tested: false),
        Profile(id: "vscode.quickInput", bundleID: "com.microsoft.VSCode", field: .quickInput, tested: true),
        Profile(id: "notes.text", bundleID: "com.apple.Notes", field: .noteText, tested: false),
    ])
}

/// The status menu as data, in ux-spec 5.3 order. The app layer turns it into an `NSMenu`.
public struct MenuModel: Equatable, Sendable {
    public enum Command: String, Equatable, Hashable, Sendable {
        case continueSetup, help, settings, quit, saveReport
    }

    public enum Item: Equatable, Hashable, Sendable {
        /// Disabled text. `secondary` marks the detail line.
        case info(LocalizedText, secondary: Bool)
        case nextStep(NextStep)
        case separator
        /// Radio item. `chord` is shown only while the shortcut is armed.
        case mode(InputMode, checked: Bool, chord: String?)
        case exclusion(bundleID: String, title: LocalizedText, excluded: Bool)
        /// `alternate` items appear while Option is held.
        case command(Command, alternate: Bool)
    }

    public let items: [Item]

    /// - Parameters:
    ///   - shortcutDisplay: the configured chord as menu text, or nil when unset.
    ///   - exclusionsSupported: false while the host cannot apply exclusions (M0), so the item never
    ///     claims an exclusion that typing would ignore.
    public init(status: RuntimeStatus, presentation: StatusPresentation, setupComplete: Bool,
                shortcutDisplay: String?, excluded: Set<String>,
                exclusionsSupported: Bool, names: NameResolver = .fallback) {
        var items: [Item] = [.info(presentation.statusLine, secondary: false)]
        if let detail = presentation.detailLine { items.append(.info(detail, secondary: true)) }
        if let step = presentation.nextStep { items.append(.nextStep(step)) }
        items.append(.separator)
        let chord = status.shortcutArmed ? shortcutDisplay : nil
        items.append(.mode(.vietnamese, checked: status.mode == .vietnamese, chord: chord))
        items.append(.mode(.english, checked: status.mode == .english, chord: nil))
        if exclusionsSupported, let app = status.frontmostBundleID,
           presentation.nextStep?.action != .removeExclusion(bundleID: app) {
            let isExcluded = excluded.contains(app)
            let key = isExcluded ? "menu.turnOnInApp" : "menu.turnOffInApp"
            items.append(.separator)
            items.append(.exclusion(bundleID: app, title: LocalizedText(key, names.appName(app)), excluded: isExcluded))
        }
        items.append(.separator)
        if !setupComplete { items.append(.command(.continueSetup, alternate: false)) }
        items.append(.command(.help, alternate: false))
        items.append(.command(.saveReport, alternate: true))
        items.append(.command(.settings, alternate: false))
        items.append(.separator)
        items.append(.command(.quit, alternate: false))
        self.items = items
    }

    public static func title(for command: Command) -> LocalizedText {
        switch command {
        case .continueSetup: LocalizedText("menu.continueSetup")
        case .help: LocalizedText("menu.help")
        case .settings: LocalizedText("menu.settings")
        case .quit: LocalizedText("menu.quit")
        case .saveReport: LocalizedText("menu.saveReport")
        }
    }
}

/// When the menu bar title applies a new presentation (status-menu spec, publication timing).
public enum TitleTiming: Equatable, Sendable {
    case immediate
    /// A Standby badge may appear or disappear up to this many milliseconds late.
    case delayed(milliseconds: Int)

    public static let standbyDelay = 500

    /// Blocked, mode, and Active changes apply at once. A change into Standby waits, so a quick pass
    /// through an unsupported app or a click outside a field never flickers the badge.
    public static func timing(from shown: StatusPresentation?, to next: StatusPresentation) -> TitleTiming {
        guard let shown, shown.title == next.title else { return .immediate }
        switch next.uiClass {
        case .standbyShown, .standbyQuiet:
            return shown.badge == next.badge ? .immediate : .delayed(milliseconds: standbyDelay)
        case .active, .english, .blocked:
            return .immediate
        }
    }
}
