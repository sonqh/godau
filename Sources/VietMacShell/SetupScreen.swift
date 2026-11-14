import VietMacPlatform

/// What a setup button does. The window performs it; this model never calls the platform.
public enum SetupCommand: Equatable, Hashable, Sendable {
    case start
    /// Calls the matching system request function, then opens the pane (FG-3).
    case requestPermission(SetupStep)
    case next
    case back
    /// `Để sau` / `Bỏ qua`: closes setup and keeps the menu's `Tiếp tục thiết lập…`.
    case later
    case reopen
    case openKeyboardSettings
    case openNotes
    case textChanged
    case textNotChanged
    case done
    case shell(ShellAction)
}

public struct SetupButton: Equatable, Hashable, Sendable {
    public let title: LocalizedText
    public let command: SetupCommand

    public init(_ title: LocalizedText, _ command: SetupCommand) {
        self.title = title
        self.command = command
    }
}

public struct SetupStatusRow: Equatable, Hashable, Sendable {
    public let label: LocalizedText?
    public let value: LocalizedText
    public let satisfied: Bool
}

public struct SetupDisclosure: Equatable, Hashable, Sendable {
    public let title: LocalizedText
    public let body: LocalizedText
}

/// The answer on the Notes variant of the Try it step.
public enum TryItAnswer: Equatable, Hashable, Sendable {
    case changed, notChanged
}

/// Window-side facts that the status does not carry.
public struct SetupContext: Equatable, Sendable {
    /// Setup was opened by a launch after setup was completed once (ux-spec 4.6 update heading).
    public var updateHeading: Bool
    /// The capability is still missing 20 s after the user returned from System Settings.
    public var reopenOffered: Bool
    /// ABC or U.S. is among the enabled input sources.
    public var supportedSourceEnabled: Bool
    public var tryItAnswer: TryItAnswer?

    public init(updateHeading: Bool = false, reopenOffered: Bool = false, supportedSourceEnabled: Bool = true,
                tryItAnswer: TryItAnswer? = nil) {
        self.updateHeading = updateHeading
        self.reopenOffered = reopenOffered
        self.supportedSourceEnabled = supportedSourceEnabled
        self.tryItAnswer = tryItAnswer
    }

    /// Seconds after the return from System Settings before `Mở lại VietMac` is offered.
    public static let reopenDelay: Double = 20
}

/// Everything one setup step shows, as data (ux-spec 4.3). A pure function of the step, the plan,
/// the status, and the window context.
public struct SetupScreen: Equatable, Sendable {
    public let step: SetupStep
    public let indicator: LocalizedText
    public let position: Int
    public let count: Int
    public let heading: LocalizedText
    public let paragraphs: [LocalizedText]
    /// Numbered instructions.
    public let instructions: [LocalizedText]
    public let statusRow: SetupStatusRow?
    /// A line with its own button, for example the posting relaunch row.
    public let extraRow: (text: LocalizedText, button: SetupButton)?
    public let disclosure: SetupDisclosure?
    /// Secondary text below the content: tips, the Telex strip, the Try it result.
    public let notes: [LocalizedText]
    /// The Try it step shows a Vietnamese mode switch bound to the status mode.
    public let showsModeSwitch: Bool
    /// The Ready step shows the shortcut recorder and the login checkbox, both unset by default.
    public let showsReadyControls: Bool
    /// The Try it result after `Chữ chưa đổi`: the current status line and its next step.
    public let tryItProblem: (statusLine: LocalizedText, detail: LocalizedText?, step: NextStep?)?
    /// Extra buttons in the content area (Open Notes, the Try it answers).
    public let contentButtons: [SetupButton]
    public let primary: SetupButton
    public let secondary: SetupButton?
    public let back: SetupButton?
    public let link: SetupButton?

    public init(step: SetupStep, plan: SetupPlan, status: RuntimeStatus, context: SetupContext = SetupContext(),
                names: NameResolver = .fallback) {
        self.step = step
        let (position, count) = plan.indicator(for: step) ?? (1, plan.steps.count)
        self.position = position
        self.count = count
        indicator = LocalizedText("setup.stepIndicator", String(position), String(count))
        back = step == .welcome ? nil : SetupButton(LocalizedText("setup.back"), .back)
        let satisfied = plan.isSatisfied(step, status: status)
        let caps = status.capabilities
        var paragraphs: [LocalizedText] = []
        var instructions: [LocalizedText] = []
        var statusRow: SetupStatusRow?
        var extraRow: (LocalizedText, SetupButton)?
        var disclosure: SetupDisclosure?
        var notes: [LocalizedText] = []
        var contentButtons: [SetupButton] = []
        var secondary: SetupButton?
        var link: SetupButton? = SetupButton(LocalizedText("setup.later"), .later)
        var tryItProblem: (LocalizedText, LocalizedText?, NextStep?)?
        let primary: SetupButton
        let heading: LocalizedText

        switch step {
        case .welcome:
            heading = LocalizedText("setup.welcome.heading")
            paragraphs = [LocalizedText("setup.welcome.body"), LocalizedText("setup.welcome.privacy")]
            if plan.showsOtherToolLine { paragraphs.append(LocalizedText("setup.welcome.otherTool")) }
            primary = SetupButton(LocalizedText("setup.welcome.start"), .start)
            link = nil

        case .inputMonitoring, .accessibility:
            let listening = step == .inputMonitoring
            let prefix = listening ? "setup.listening" : "setup.accessibility"
            if context.updateHeading && !satisfied {
                heading = LocalizedText("setup.update.heading")
                paragraphs = [LocalizedText("setup.update.body")]
            } else {
                heading = LocalizedText("\(prefix).heading")
                paragraphs = [LocalizedText("\(prefix).body")]
            }
            instructions = [LocalizedText("setup.grant.step1"), LocalizedText("setup.grant.step2"),
                            LocalizedText("setup.grant.step3")]
            statusRow = SetupStatusRow(label: LocalizedText("\(prefix).row"),
                                       value: LocalizedText(satisfied ? "setup.statusOn" : "setup.statusOff"),
                                       satisfied: satisfied)
            // The stale-entry help applies only while the capability reads missing.
            if !satisfied {
                disclosure = SetupDisclosure(title: LocalizedText("setup.grant.helpTitle"),
                                             body: LocalizedText("setup.grant.helpBody"))
            }
            // Accessibility and Input Monitoring are on but posting is not: only a relaunch helps.
            let postingStuck = !listening && caps.accessibility && caps.eventListening && !caps.eventPosting
            if postingStuck {
                extraRow = (LocalizedText("setup.accessibility.reopenRow"),
                            SetupButton(LocalizedText("action.reopen"), .reopen))
            }
            if satisfied {
                primary = SetupButton(LocalizedText("setup.continue"), .next)
            } else {
                primary = SetupButton(LocalizedText("setup.openSystemSettings"), .requestPermission(step))
                if context.reopenOffered && !postingStuck {
                    secondary = SetupButton(LocalizedText("action.reopen"), .reopen)
                }
            }

        case .keyboard:
            heading = LocalizedText("setup.keyboard.heading")
            let name = names.inputSourceName(status.inputSourceID)
            paragraphs = [LocalizedText("setup.keyboard.body", name)]
            statusRow = SetupStatusRow(label: nil,
                                       value: LocalizedText(satisfied ? "setup.keyboard.ok" : "setup.keyboard.wrong", name),
                                       satisfied: satisfied)
            if satisfied {
                primary = SetupButton(LocalizedText("setup.continue"), .next)
            } else {
                instructions = [LocalizedText(context.supportedSourceEnabled
                                              ? "setup.keyboard.wrongSource" : "setup.keyboard.addABC")]
                primary = SetupButton(LocalizedText("setup.keyboard.open"), .openKeyboardSettings)
            }

        case .otherTool:
            let app = names.appName(status.conflictingBundleID ?? "")
            heading = LocalizedText("setup.conflict.heading")
            paragraphs = [LocalizedText("setup.conflict.body", app, app)]
            statusRow = SetupStatusRow(label: nil,
                                       value: LocalizedText(satisfied ? "setup.conflict.clear" : "setup.conflict.running", app),
                                       satisfied: satisfied)
            primary = SetupButton(LocalizedText("setup.continue"), .next)

        case .tryIt:
            heading = LocalizedText("setup.try.heading")
            instructions = [LocalizedText("setup.try.step1"), LocalizedText("setup.try.step2Notes"),
                            LocalizedText("setup.try.step3")]
            paragraphs = [LocalizedText("setup.try.expected")]
            contentButtons = [SetupButton(LocalizedText("setup.try.openNotes"), .openNotes),
                              SetupButton(LocalizedText("setup.try.changed"), .textChanged),
                              SetupButton(LocalizedText("setup.try.notChanged"), .textNotChanged)]
            switch context.tryItAnswer {
            case .changed:
                notes.append(LocalizedText("setup.try.success"))
            case .notChanged:
                let presentation = StatusPresentation(status: status, features: plan.features, names: names)
                tryItProblem = (presentation.statusLine, presentation.detailLine, presentation.nextStep)
            case nil:
                break
            }
            notes.append(LocalizedText("setup.try.telex"))
            primary = SetupButton(LocalizedText("setup.continue"), .next)
            link = SetupButton(LocalizedText("setup.skip"), .next)

        case .ready:
            heading = LocalizedText("setup.ready.heading")
            paragraphs = [LocalizedText("setup.ready.icon")]
            notes = [LocalizedText("setup.ready.tip"), LocalizedText("setup.ready.hiddenIcon")]
            primary = SetupButton(LocalizedText("setup.ready.done"), .done)
            link = nil
        }

        self.heading = heading
        self.paragraphs = paragraphs
        self.instructions = instructions
        self.statusRow = statusRow
        self.extraRow = extraRow
        self.disclosure = disclosure
        self.notes = notes
        self.showsModeSwitch = step == .tryIt
        self.showsReadyControls = step == .ready
        self.tryItProblem = tryItProblem
        self.contentButtons = contentButtons
        self.primary = primary
        self.secondary = secondary
        self.link = link
    }

    public static func == (lhs: SetupScreen, rhs: SetupScreen) -> Bool {
        lhs.step == rhs.step && lhs.position == rhs.position && lhs.count == rhs.count && lhs.heading == rhs.heading
            && lhs.paragraphs == rhs.paragraphs && lhs.instructions == rhs.instructions
            && lhs.statusRow == rhs.statusRow && lhs.extraRow?.text == rhs.extraRow?.text
            && lhs.extraRow?.button == rhs.extraRow?.button && lhs.disclosure == rhs.disclosure
            && lhs.notes == rhs.notes && lhs.showsModeSwitch == rhs.showsModeSwitch
            && lhs.showsReadyControls == rhs.showsReadyControls
            && lhs.tryItProblem?.statusLine == rhs.tryItProblem?.statusLine
            && lhs.tryItProblem?.detail == rhs.tryItProblem?.detail && lhs.tryItProblem?.step == rhs.tryItProblem?.step
            && lhs.contentButtons == rhs.contentButtons && lhs.primary == rhs.primary
            && lhs.secondary == rhs.secondary && lhs.back == rhs.back && lhs.link == rhs.link
    }
}

/// Whether setup opens by itself at launch (ux-spec 4.6, guided-setup spec).
public struct LaunchDecision: Equatable, Sendable {
    /// The step to open at, or nil for no window.
    public let step: SetupStep?
    /// False shows the window without activating VietMac, so the frontmost app keeps keyboard focus.
    public let activates: Bool
    public let updateHeading: Bool

    public static let none = LaunchDecision(step: nil, activates: false, updateHeading: false)

    public init(step: SetupStep?, activates: Bool, updateHeading: Bool) {
        self.step = step
        self.activates = activates
        self.updateHeading = updateHeading
    }

    /// - Parameters:
    ///   - completedOnce: the user finished setup with `Xong` at least once.
    ///   - lastSeen: the last step the user saw, or nil before the first opening.
    ///   - loginLaunch: the launch was a login-item launch; trusted only when U-15 passed.
    public static func decide(status: RuntimeStatus, plan: SetupPlan, completedOnce: Bool, lastSeen: SetupStep?,
                              loginLaunch: Bool) -> LaunchDecision {
        if !completedOnce && lastSeen == nil {
            return LaunchDecision(step: .welcome, activates: true, updateHeading: false)
        }
        guard !plan.isComplete(status: status) else { return .none }
        if !completedOnce {
            // Relaunch during setup: reopen at the first missing item (UX-4).
            return LaunchDecision(step: plan.startStep(status: status, lastSeen: lastSeen), activates: true,
                                  updateHeading: false)
        }
        if plan.features.distinguishesLoginLaunch {
            // PD-3: no window at a login-item launch.
            if loginLaunch { return .none }
            return LaunchDecision(step: plan.firstMissing(status: status), activates: true, updateHeading: true)
        }
        // Fallback until U-15: show the window at every such launch without taking keyboard focus.
        return LaunchDecision(step: plan.firstMissing(status: status), activates: false, updateHeading: true)
    }
}
