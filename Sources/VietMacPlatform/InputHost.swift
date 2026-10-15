import AppKit
import Carbon
import CoreGraphics
import Dispatch
import VietMacCore

/// Main-run-loop owner. No task, actor hop, UI, AX read, or I/O per key.
@MainActor
public final class InputHost {
    public private(set) var permissions = PermissionSnapshot.current()
    public private(set) var inputSource = "unknown"
    public private(set) var frontmostBundleID: String?
    public var state: InputRuntimeState { pipeline.state }
    public var enabled: Bool { pipeline.enabled }

    private var pipeline: PrototypePipeline
    private let transport = PreparedTransport(marker: Int64.random(in: 1...Int64.max))
    private var timings = CallbackTimings()
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sourceObserver: NSObjectProtocol?
    private let focus = FocusMonitor()
    private var field = FieldContextTracker()
    public private(set) var counters = ContextCounters()
    private var trace = ObservationTrace()
    private var keysSinceObservation: UInt32 = 0
    private var lastTrackedKeyNanos: UInt64 = 0
    private var pid: pid_t = 0
    private var sleeping = false
    private var uncertainSend = false
    private let trialApps: Set<String> = ["com.microsoft.VSCode", "com.google.Chrome", "com.apple.Safari",
                                         "company.thebrowser.dia", "com.apple.Notes"]

    public init() {
        pipeline = PrototypePipeline(environment: InputEnvironment(permissions: .current(), certainContext: false))
    }

    public func start() {
        guard timer == nil else { return }
        focus.onNotification = { [weak self] in self?.observeField() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.didWakeNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let isSleeping = note.name == NSWorkspace.willSleepNotification
                let isWaking = note.name == NSWorkspace.didWakeNotification
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.invalidateContext()
                    if isSleeping {
                        self.sleeping = true
                        self.removeTap()
                    } else if isWaking {
                        self.sleeping = false
                    }
                    self.refresh()
                }
            })
        }
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.invalidateContext()
                    self?.refresh()
                }
            }
        let poll = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(source: "poll") }
        }
        timer = poll
        RunLoop.main.add(poll, forMode: .common)
        refresh()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        if let sourceObserver { DistributedNotificationCenter.default().removeObserver(sourceObserver) }
        sourceObserver = nil
        focus.stop()
        removeTap()
        pipeline.setEnabled(false)
    }

    public func setEnabled(_ value: Bool) {
        uncertainSend = false
        pipeline.setEnabled(value)
        field.reset()
        refresh()
        // Explicit enable/resume starts fresh in the inspected context.
        pipeline.invalidate(holdUntilBoundary: false)
        if !value && !pipeline.hasConsumedKeys { removeTap() }
        if value, pipeline.state == .active, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    public func refresh() { refresh(source: "refresh") }

    private func refresh(source: String) {
        permissions = .current()
        let active = NSWorkspace.shared.frontmostApplication
        let nextPID = active?.processIdentifier ?? 0
        let nextBundle = active?.bundleIdentifier
        let nextSource = Self.currentInputSource()
        if pid != nextPID || inputSource != nextSource { invalidateContext() }
        pid = nextPID
        frontmostBundleID = nextBundle
        inputSource = nextSource
        let certain = observeFocus(source: source)
        let environment = InputEnvironment(permissions: permissions,
            secureInput: IsSecureEventInputEnabled(),
            supportedApp: supportedApp,
            supportedSource: ["com.apple.keylayout.ABC", "com.apple.keylayout.US"].contains(inputSource),
            certainContext: !sleeping && !uncertainSend && certain)
        pipeline.updateEnvironment(environment)
        if !pipeline.enabled && !pipeline.hasConsumedKeys { removeTap() }
        if pipeline.enabled && !sleeping && environment.pauseReason == nil && tap == nil && pipeline.state == .active {
            createTap()
        }
    }

    private var supportedApp: Bool { frontmostBundleID.map { trialApps.contains($0) } ?? false }

    /// AX notification path: field metadata only, without capability or app lookups.
    private func observeField() {
        let certain = observeFocus(source: "notification")
        var environment = pipeline.environment
        environment.certainContext = !sleeping && !uncertainSend && certain
        pipeline.updateEnvironment(environment)
    }

    /// Compares observed caret/length with predicted key effects. Returns whether a caret is known.
    private func observeFocus(source: String) -> Bool {
        let inspected = focus.inspect(pid: pid, allowed: permissions.accessibility && supportedApp && !sleeping)
        let observed = ContextPolicy.observe(focusChanged: inspected.changed, reading: inspected.field,
                                             field: &field, pipeline: &pipeline, counters: &counters)
        trace.append(source: source, inspection: inspected, result: observed.result,
                     keysSincePrevious: keysSinceObservation, field: field)
        keysSinceObservation = 0
        let quiet = DispatchTime.now().uptimeNanoseconds &- lastTrackedKeyNanos
        if ContextPolicy.checkReplacementDelivery(result: observed.result, reading: inspected.field,
                                                  quietNanoseconds: quiet,
                                                  field: &field, pipeline: &pipeline, counters: &counters) {
            return false
        }
        return observed.certain
    }

    private func invalidateContext() {
        ContextPolicy.invalidate(field: &field, pipeline: &pipeline)
    }

    /// Call from UI/export only; contains no text or keystroke payloads.
    public func timingJSON() throws -> Data {
        struct Report: Encodable {
            let build: String
            let os: String
            let architecture: String
            let inputSource: String
            let profile: String
            let timings: CallbackTimingReport
        }
        #if DEBUG
        let build = "debug-not-performance-evidence"
        #else
        let build = "release"
        #endif
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Report(build: build, os: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture, inputSource: inputSource, profile: "M0 ordinary-event trial",
            timings: timings.snapshot()))
    }

    /// `scope` distinguishes a direct invocation from the running app session.
    public func diagnosticJSON(scope: String = "read-only-process-capability-snapshot") throws -> Data {
        struct AppInfo: Encodable {
            let bundleID: String
            let installed: Bool
            let version: String?
        }
        struct Report: Encodable {
            let scope: String
            let nativeTypingVerified = false
            let pid: Int32
            let bundleID: String?
            let executable: String?
            let os: String
            let accessibility: Bool
            let eventListening: Bool
            let eventPosting: Bool
            let secureInput: Bool
            let inputSource: String
            let prototypeEnabled: Bool
            let state: String
            let tapInstalled: Bool
            let frontmostBundleID: String?
            let contextCounters: ContextCounters
            let observationTrace: [ObservationRecord]
            let requiredApps: [AppInfo]
        }
        let stateText: String
        switch state {
        case .disabled: stateText = "disabled"
        case .active: stateText = "active"
        case .paused(let reason): stateText = "paused: \(reason.rawValue)"
        }
        let apps = trialApps.sorted().map { id in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let bundle = url.flatMap { Bundle(url: $0) }
            return AppInfo(bundleID: id, installed: url != nil,
                           version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Report(scope: scope, pid: ProcessInfo.processInfo.processIdentifier,
            bundleID: Bundle.main.bundleIdentifier,
            executable: Bundle.main.executableURL?.path,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            accessibility: permissions.accessibility, eventListening: permissions.eventListening,
            eventPosting: permissions.eventPosting, secureInput: pipeline.environment.secureInput,
            inputSource: inputSource, prototypeEnabled: enabled, state: stateText, tapInstalled: tap != nil,
            frontmostBundleID: frontmostBundleID, contextCounters: counters, observationTrace: trace.ordered, requiredApps: apps))
    }

    private func createTap() {
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown,
                                   .otherMouseDown, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { proxy, type, event, pointer in
                guard let pointer else { return Unmanaged.passUnretained(event) }
                let pass = MainActor.assumeIsolated {
                    Unmanaged<InputHost>.fromOpaque(pointer).takeUnretainedValue().handle(proxy, type, event)
                }
                return pass ? Unmanaged.passUnretained(event) : nil
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let created, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            pipeline.pauseFor(.tapUnavailable)
            return
        }
        tap = created
        tapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }

    private func removeTap() {
        if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        tap = nil
        tapSource = nil
    }

    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        defer { timings.record(DispatchTime.now().uptimeNanoseconds - start) }
        let original = true
        switch EventNormalizer.normalize(type: type, event: event, marker: transport.marker) {
        case .generated, .unhandled:
            return original
        case .timeout:
            if pipeline.timeout(at: start), let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            field.reset()
            return original
        case .userDisabled:
            pipeline.pauseFor(.userDisabledTap)
            field.reset()
            return original
        case .input(let input):
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if type == .keyDown {
                if (0..<128).contains(code), pipeline.beginPhysicalPress(UInt16(code),
                    isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) {
                    return false
                }
            }
            let before = pipeline.word
            switch pipeline.handle(input) {
            case .passThrough:
                expectPassThrough(input, keyCode: code, previous: before)
                return original
            case .consume:
                return false
            case .replace(let edit):
                // Require an observation after every tracked key before deleting anything.
                guard ContextPolicy.admitsReplacement(field: field, pipeline: &pipeline, counters: &counters) else {
                    expectPassThrough(input, keyCode: code, previous: before)
                    return original
                }
                do {
                    let plan = try ReplacementPlan.compute(previous: before, next: edit.next)
                    let prepared = try transport.prepare(plan, insertionKeyCode: CGKeyCode(edit.keyCode))
                    let result = transport.send(prepared, isCurrent: { pipeline.isCurrent(edit) }, post: {
                        $0.tapPostEvent(proxy)
                        return true // A void OS post is not client acknowledgement.
                    })
                    switch result {
                    case .posted:
                        guard pipeline.accept(edit) else {
                            markUncertainSend(edit)
                            return false
                        }
                        ContextPolicy.expectReplacement(previous: before, plan: plan, field: &field,
                                                        pipeline: &pipeline, counters: &counters)
                        lastTrackedKeyNanos = start
                        return false
                    case .staleBeforeSend:
                        counters.staleBeforeSend &+= 1
                        pipeline.invalidate()
                        expectPassThrough(input, keyCode: code, previous: before)
                        return original
                    case .uncertainAfterSend:
                        markUncertainSend(edit)
                        return false
                    }
                } catch {
                    pipeline.invalidate()
                    expectPassThrough(input, keyCode: code, previous: before)
                    return original
                }
            }
        }
    }

    private func markUncertainSend(_ edit: PendingReplacement) {
        counters.uncertainAfterSend &+= 1
        uncertainSend = true
        field.reset()
        pipeline.consumeAfterUncertainSend(edit.keyCode)
    }

    private func expectPassThrough(_ input: PrototypeInput, keyCode: Int64, previous: String) {
        if case .keyUp = input {} else {
            keysSinceObservation &+= 1
            lastTrackedKeyNanos = DispatchTime.now().uptimeNanoseconds
        }
        ContextPolicy.expectPassThrough(input, keyCode: keyCode, previous: previous, field: &field,
                                        pipeline: &pipeline, counters: &counters)
    }

    private static func currentInputSource() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "unknown" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
