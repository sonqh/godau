import VietMacPlatform

/// UI classes map one-to-one onto availability (ux-spec 5.1).
public enum UIClass: String, Equatable, Hashable, Sendable {
    case active, english, blocked, standbyShown, standbyQuiet
}

/// Template badge drawn beside the menu bar title.
public enum Badge: String, Equatable, Hashable, Sendable {
    case none
    /// `pause.fill`
    case pause
    /// `exclamationmark.triangle.fill`
    case triangle
}

public enum HelpPage: String, Equatable, Hashable, Sendable, CaseIterable {
    case telex, unchanged, password, permissions, otherTool
}

public enum SettingsTab: String, Equatable, Hashable, Sendable, CaseIterable {
    case general, apps, status
}

/// What a next-step item does. The app layer performs it; the logic never calls the platform.
public enum ShellAction: Equatable, Hashable, Sendable {
    case openSetup(SetupStep)
    case relaunch
    case openKeyboardSettings
    case openHelp(HelpPage)
    case openSettings(SettingsTab)
    case resume
    case removeExclusion(bundleID: String)
}

public struct NextStep: Equatable, Hashable, Sendable {
    public let title: LocalizedText
    public let action: ShellAction

    public init(title: LocalizedText, action: ShellAction) {
        self.title = title
        self.action = action
    }
}

/// Turns bundle IDs and input source IDs into display names. The app layer supplies
/// localized names from the system; tests use the fallback.
public struct NameResolver: Sendable {
    public let appName: @Sendable (String) -> String
    public let inputSourceName: @Sendable (String) -> String

    public init(appName: @escaping @Sendable (String) -> String,
                inputSourceName: @escaping @Sendable (String) -> String) {
        self.appName = appName
        self.inputSourceName = inputSourceName
    }

    public static let knownApps: [String: String] = [
        "com.microsoft.VSCode": "VS Code",
        "com.google.Chrome": "Chrome",
        "com.apple.Safari": "Safari",
        "company.thebrowser.dia": "Dia",
        "com.apple.Notes": "Notes",
    ]

    /// Known names, else the last bundle ID component. Input sources: last ID component.
    public static let fallback = NameResolver(
        appName: { knownApps[$0] ?? String($0.split(separator: ".").last ?? Substring($0)) },
        inputSourceName: { String($0.split(separator: ".").last ?? Substring($0)) })
}

/// Shell state that changes presentation but is not part of `RuntimeStatus`.
public struct PresentationContext: Equatable, Sendable {
    /// `Thử lại` was chosen and the tap still could not start.
    public var tapRetryFailed: Bool

    public init(tapRetryFailed: Bool = false) {
        self.tapRetryFailed = tapRetryFailed
    }
}

/// Everything the menu bar item and the top of the menu show for one status.
/// A pure function of the status, the features, and the context (shell-presentation spec).
public struct StatusPresentation: Equatable, Sendable {
    public let uiClass: UIClass
    /// `VI` or `EN`, in both UI languages.
    public let title: String
    public let badge: Badge
    public let accessibilityLabel: LocalizedText
    public let statusLine: LocalizedText
    public let detailLine: LocalizedText?
    public let nextStep: NextStep?

    public init(status: RuntimeStatus, features: SetupFeatures = .current,
                context: PresentationContext = PresentationContext(), names: NameResolver = .fallback) {
        switch status.availability {
        case .off:
            let missing = Self.missingCapability(status.capabilities, features: features) != nil
            uiClass = .english
            title = "EN"
            badge = missing ? .triangle : .none
            accessibilityLabel = LocalizedText(missing ? "title.a11y.en.attention" : "title.a11y.en")
            statusLine = LocalizedText("status.off")
            // The menu's `Tiếp tục thiết lập…` item is the next step for a missing grant in English mode.
            detailLine = missing ? LocalizedText("detail.englishMissingPermission") : nil
            nextStep = nil
        case .active(let assurance):
            uiClass = .active
            title = "VI"
            badge = .none
            accessibilityLabel = LocalizedText("title.a11y.vi")
            statusLine = LocalizedText(assurance == .eventOnly ? "status.activeReduced" : "status.active")
            detailLine = nil
            nextStep = nil
        case .blocked(let reason):
            uiClass = .blocked
            title = "VI"
            badge = .triangle
            accessibilityLabel = LocalizedText("title.a11y.vi.attention")
            statusLine = LocalizedText("status.blocked")
            (detailLine, nextStep) = Self.blocked(reason, status: status, context: context, names: names)
        case .standby(let reason):
            let quiet = Self.quietReasons.contains(reason)
            uiClass = quiet ? .standbyQuiet : .standbyShown
            title = "VI"
            badge = quiet ? .none : .pause
            accessibilityLabel = LocalizedText(quiet ? "title.a11y.vi" : "title.a11y.vi.paused")
            statusLine = LocalizedText("status.standby")
            (detailLine, nextStep) = Self.standby(reason, status: status, names: names)
        }
    }

    /// Reasons that occur on every click outside a text field; they never badge the title.
    public static let quietReasons: Set<StandbyReason> = [.noTextField, .fieldUnreadable, .sleeping]

    /// The first missing required capability, in the runtime gate order.
    public static func missingCapability(_ caps: Capabilities, features: SetupFeatures) -> BlockReason? {
        if !caps.accessibility { return .accessibility }
        if features.inputMonitoringRequired && !caps.eventListening { return .listening }
        if !caps.eventPosting { return .posting }
        return nil
    }

    /// A Standby badge may lag by up to 500 ms; every other title change applies at once.
    public var badgeMayDebounce: Bool { uiClass == .standbyShown || uiClass == .standbyQuiet }

    private static func blocked(_ reason: BlockReason, status: RuntimeStatus, context: PresentationContext,
                                names: NameResolver) -> (LocalizedText, NextStep) {
        switch reason {
        case .accessibility:
            return (LocalizedText("detail.accessibility"),
                    NextStep(title: LocalizedText("action.turnOnAccessibility"), action: .openSetup(.accessibility)))
        case .listening:
            return (LocalizedText("detail.listening"),
                    NextStep(title: LocalizedText("action.turnOnListening"), action: .openSetup(.inputMonitoring)))
        case .posting:
            return (LocalizedText("detail.posting"), NextStep(title: LocalizedText("action.reopen"), action: .relaunch))
        case .unsupportedSource:
            return (LocalizedText("detail.unsupportedSource", names.inputSourceName(status.inputSourceID)),
                    NextStep(title: LocalizedText("action.openKeyboardSettings"), action: .openKeyboardSettings))
        case .conflictingTool:
            let app = names.appName(status.conflictingBundleID ?? "")
            return (LocalizedText("detail.conflictingTool", app),
                    NextStep(title: LocalizedText("action.howToQuit", app), action: .openHelp(.otherTool)))
        case .tapUnavailable:
            let step = context.tapRetryFailed
                ? NextStep(title: LocalizedText("action.reopen"), action: .relaunch)
                : NextStep(title: LocalizedText("action.tryAgain"), action: .resume)
            return (LocalizedText("detail.tapUnavailable"), step)
        case .userDisabledTap, .recoveryLimit, .transportUncertain:
            return (LocalizedText("detail.\(reason.rawValue)"),
                    NextStep(title: LocalizedText("action.resume"), action: .resume))
        }
    }

    private static func standby(_ reason: StandbyReason, status: RuntimeStatus,
                                names: NameResolver) -> (LocalizedText, NextStep?) {
        let app = names.appName(status.frontmostBundleID ?? "")
        switch reason {
        case .secureInput:
            return (LocalizedText("detail.secureInput"),
                    NextStep(title: LocalizedText("action.seeReason"), action: .openHelp(.password)))
        case .passwordField:
            return (LocalizedText("detail.passwordField"), nil)
        case .unsupportedApp:
            return (LocalizedText("detail.unsupportedApp", app),
                    NextStep(title: LocalizedText("action.seeSupportedApps"), action: .openSettings(.apps)))
        case .excludedApp:
            let step = status.frontmostBundleID.map {
                NextStep(title: LocalizedText("menu.turnOnInApp", app), action: .removeExclusion(bundleID: $0))
            }
            return (LocalizedText("detail.excludedApp", app), step)
        case .unsupportedField:
            let field = LocalizedText.reference("field.\((status.fieldKind ?? .textField).rawValue)")
            return (LocalizedText(key: "detail.unsupportedField", args: [field, app]),
                    NextStep(title: LocalizedText("action.seeSupportedApps"), action: .openSettings(.apps)))
        case .noTextField, .fieldUnreadable, .sleeping:
            return (LocalizedText("detail.\(reason.rawValue)"), nil)
        }
    }
}
