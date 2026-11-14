import VietMacPlatform

/// Settled unknowns that change the setup flow. A flag changes only after the unknown has
/// a recorded native result and a ledger entry (ux-shell design D4).
public struct SetupFeatures: Equatable, Sendable {
    /// U-2: the active tap needs Input Monitoring.
    public var inputMonitoringRequired: Bool
    /// U-9: a known input tool with an active keyboard tap can be detected.
    public var conflictDetection: Bool
    /// FG-5 and U-6: the try-it step has its own text field.
    public var inAppTryIt: Bool
    /// U-15: a login-item launch can be told apart from a manual launch.
    public var distinguishesLoginLaunch: Bool

    public init(inputMonitoringRequired: Bool = true, conflictDetection: Bool = false,
                inAppTryIt: Bool = false, distinguishesLoginLaunch: Bool = false) {
        self.inputMonitoringRequired = inputMonitoringRequired
        self.conflictDetection = conflictDetection
        self.inAppTryIt = inAppTryIt
        self.distinguishesLoginLaunch = distinguishesLoginLaunch
    }

    /// The flags of this build.
    public static let current = SetupFeatures()
}

public enum SetupStep: String, Equatable, Hashable, Sendable, CaseIterable {
    case welcome, inputMonitoring, accessibility, keyboard, otherTool, tryIt, ready
}

/// The setup step list, derived at runtime from the status and the settled unknowns (ux-spec 4.3).
public struct SetupPlan: Equatable, Sendable {
    public let features: SetupFeatures
    public let steps: [SetupStep]

    public init(status: RuntimeStatus, features: SetupFeatures = .current) {
        self.features = features
        var steps: [SetupStep] = [.welcome]
        if features.inputMonitoringRequired { steps.append(.inputMonitoring) }
        steps += [.accessibility, .keyboard]
        if features.conflictDetection, status.conflictingBundleID != nil { steps.append(.otherTool) }
        steps += [.tryIt, .ready]
        self.steps = steps
    }

    /// The Welcome step asks the user to quit other input tools while the Other input tool step cannot appear.
    public var showsOtherToolLine: Bool { !features.conflictDetection }

    /// Step indicator values: 1-based position and the count of steps in this list.
    public func indicator(for step: SetupStep) -> (position: Int, count: Int)? {
        guard let index = steps.firstIndex(of: step) else { return nil }
        return (index + 1, steps.count)
    }

    /// True when the condition of a grant, keyboard, or conflict step holds. Welcome, Try it,
    /// and Ready depend on the user and are never satisfied by the status.
    public func isSatisfied(_ step: SetupStep, status: RuntimeStatus) -> Bool {
        switch step {
        case .inputMonitoring: status.capabilities.eventListening
        case .accessibility: status.capabilities.accessibility && status.capabilities.eventPosting
        case .keyboard: status.inputSourceSupported
        case .otherTool: status.conflictingBundleID == nil
        case .welcome, .tryIt, .ready: false
        }
    }

    /// The first item that is still missing, in gate order: capabilities, input source, conflicting tool.
    /// Reads status fields only, never `availability`, because first launch is English mode.
    public func firstMissing(status: RuntimeStatus) -> SetupStep? {
        let gated: [SetupStep] = steps.filter { [.inputMonitoring, .accessibility, .keyboard, .otherTool].contains($0) }
        return gated.first(where: { !isSatisfied($0, status: status) })
    }

    /// Setup is complete when every required capability is true, the input source is ABC or U.S.,
    /// and no conflicting tool is reported.
    public func isComplete(status: RuntimeStatus) -> Bool {
        let caps = status.capabilities
        let capabilitiesReady = caps.accessibility && caps.eventPosting
            && (caps.eventListening || !features.inputMonitoringRequired)
        return capabilitiesReady && status.inputSourceSupported && status.conflictingBundleID == nil
    }

    /// Where setup opens. A first opening starts at Welcome. A reopen starts at the first missing
    /// item in gate order; with nothing missing it returns to the last step the user saw.
    public func startStep(status: RuntimeStatus, lastSeen: SetupStep?) -> SetupStep {
        guard let lastSeen else { return .welcome }
        if let missing = firstMissing(status: status) { return missing }
        return lastSeen == .ready ? .ready : .tryIt
    }

    public func next(after step: SetupStep) -> SetupStep? {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    public func previous(before step: SetupStep) -> SetupStep? {
        guard let index = steps.firstIndex(of: step), index > 0 else { return nil }
        return steps[index - 1]
    }
}
