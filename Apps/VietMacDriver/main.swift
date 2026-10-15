import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import VietMacDriverKit

// Test-only native key driver. It posts scripted HID-level events, so session event taps such
// as VietMac's see them like keyboard input. It is not linked into VietMac.
// Safety: it types only while the expected app is frontmost with an ABC or U.S. source, stops on
// physical input, refuses submission keys for protected targets, reads only designated fields,
// and releases every key, modifier, and CapsLock state it set on every exit path.

private let driverMarker: Int64 = 0x5644_524B // "VDRK"; tags every event this driver posts.
private let allowedSources: Set<String> = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]

struct Options {
    var keys: String?
    var scriptPath: String?
    /// Inline script; avoids file reads that need Files & Folders consent under ~/Documents.
    var scriptJSON: String?
    var interval = 80.0
    var hold = 50.0
    var pause = 1000.0
    var startDelay = 300.0
    var maximumSeconds = 120.0
    var expectedBundleID = ""
    var output = ""
    var selectABC = false
    var click: (Double, Double)?
    var validateOnly = false
    var protected = false
    var allowUnguarded = false
    var readFocused = false
    var describeFocused = false
    /// Check the designation before every key press, not only at checkpoints.
    var requireTarget = false
    /// Find the designated field in the focused window instead of using the focused element
    /// (VS Code quick input keeps AX focus on the active list row).
    var findInWindow = false
    var listWindowFields = false
    var designation = Designation()
}

/// Identifies the only field an oracle may read. Every set property must match.
struct Designation: Codable {
    var role: String?
    var descriptionContains: String?
    var windowTitleContains: String?
    var valuePrefix: String?
    var identifier: String?

    var isEmpty: Bool {
        role == nil && descriptionContains == nil && windowTitleContains == nil && valuePrefix == nil && identifier == nil
    }
}

/// Attributes that identify a field without any of its text.
struct FieldDescription: Codable {
    var role: String?
    var subrole: String?
    var description: String?
    var title: String?
    var placeholder: String?
    var identifier: String?
    var windowTitle: String?
}

struct FieldReading: Codable {
    var role: String?
    var value: String?
    var selection: [Int]?
    var markedRange: [Int]?
    var length: Int?
}

struct Checkpoint: Codable {
    var name: String
    var offsetMilliseconds: Double
    var field: FieldReading?
    var reason: String?
}

struct Result: Codable {
    var status = "pass"
    var reason: String?
    var detail: String?
    var keyEventsPosted = 0
    var eventsPosted = 0
    var durationMilliseconds = 0.0
    var frontmostBundleID: String?
    var inputSource: String?
    var restoredInputSource: String?
    var interferenceGuard = false
    var interferenceSourcePID: Int?
    var clipboardChangeCountBefore: Int?
    var clipboardChangeCountAfter: Int?
    var heldFlagsAfter: UInt64?
    var checkpoints: [Checkpoint] = []
    var field: FieldReading?
    var focused: FieldDescription?
    var windowFields: [FieldDescription]?
}

// MARK: - Arguments

private func parse(_ arguments: [String]) -> Options? {
    var options = Options()
    var index = 1
    func next() -> String? {
        index += 1
        return index < arguments.count ? arguments[index] : nil
    }
    while index < arguments.count {
        let name = arguments[index]
        switch name {
        case "--select-abc": options.selectABC = true
        case "--validate-only": options.validateOnly = true
        case "--protected": options.protected = true
        case "--allow-unguarded": options.allowUnguarded = true
        case "--read-focused": options.readFocused = true
        case "--describe-focused": options.describeFocused = true
        case "--require-target": options.requireTarget = true
        case "--find-in-window": options.findInWindow = true
        case "--list-window-fields": options.listWindowFields = true
        default:
            guard let value = next() else { return nil }
            switch name {
            case "--keys": options.keys = value
            case "--script": options.scriptPath = value
            case "--script-json": options.scriptJSON = value
            case "--interval-ms": options.interval = Double(value) ?? -1
            case "--hold-ms": options.hold = Double(value) ?? -1
            case "--pause-ms": options.pause = Double(value) ?? -1
            case "--start-delay-ms": options.startDelay = Double(value) ?? -1
            case "--max-seconds": options.maximumSeconds = Double(value) ?? -1
            case "--expect-bundle": options.expectedBundleID = value
            case "--out": options.output = value
            case "--target-role": options.designation.role = value
            case "--target-description": options.designation.descriptionContains = value
            case "--target-window": options.designation.windowTitleContains = value
            case "--target-value-prefix": options.designation.valuePrefix = value
            case "--target-identifier": options.designation.identifier = value
            case "--click":
                let parts = value.split(separator: ",").compactMap { Double($0) }
                guard parts.count == 2 else { return nil }
                options.click = (parts[0], parts[1])
            default: return nil
            }
        }
        index += 1
    }
    let hasInput = [options.keys, options.scriptPath, options.scriptJSON].compactMap { $0 }.count == 1
    if options.requireTarget && options.designation.isEmpty { return nil }
    guard options.output.hasPrefix("/"), options.startDelay >= 0, options.maximumSeconds > 0,
          // Reading content always needs a designation; describing never returns content.
          options.readFocused ? !options.expectedBundleID.isEmpty && !options.designation.isEmpty
                              : options.describeFocused || options.listWindowFields
                                  ? !options.expectedBundleID.isEmpty : hasInput && (options.validateOnly || !options.expectedBundleID.isEmpty)
    else { return nil }
    return options
}

// MARK: - System helpers

private func currentInputSource() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

private func inputSource(withID id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return nil }
    return list.first
}

private func frontmostBundleID() -> String? { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }

/// Waits on the main run loop so NSWorkspace stays current and the interference tap runs.
private func wait(until deadline: Date) {
    while Date() < deadline { RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.005))) }
}

private func write(_ result: Result, to path: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(result) { try? data.write(to: URL(fileURLWithPath: path), options: .atomic) }
}

// MARK: - Accessibility oracle

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

private func range(_ element: AXUIElement, _ name: String) -> [Int]? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
    return [range.location, range.location + range.length]
}

private let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

private func describe(_ element: AXUIElement, windowTitle: String?) -> FieldDescription {
    FieldDescription(role: attribute(element, kAXRoleAttribute) as? String,
                     subrole: attribute(element, kAXSubroleAttribute) as? String,
                     description: attribute(element, kAXDescriptionAttribute) as? String,
                     title: attribute(element, kAXTitleAttribute) as? String,
                     placeholder: attribute(element, "AXPlaceholderValue") as? String,
                     identifier: attribute(element, kAXIdentifierAttribute) as? String,
                     windowTitle: windowTitle)
}

/// Text fields in the focused window, breadth-first and bounded. Values are never read here.
private func windowTextFields(bundleID: String) -> ([(AXUIElement, FieldDescription)], String?) {
    guard frontmostBundleID() == bundleID, let app = NSWorkspace.shared.frontmostApplication else {
        return ([], "frontmostChanged")
    }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    guard let windowRef = attribute(appElement, kAXFocusedWindowAttribute) else { return ([], "noFocusedWindow") }
    let window = windowRef as! AXUIElement
    let title = attribute(window, kAXTitleAttribute) as? String
    var queue = [window], fields: [(AXUIElement, FieldDescription)] = [], visited = 0
    while !queue.isEmpty, visited < 4000 {
        let element = queue.removeFirst()
        visited += 1
        if let role = attribute(element, kAXRoleAttribute) as? String, textRoles.contains(role) {
            fields.append((element, describe(element, windowTitle: title)))
        }
        if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] { queue += children }
    }
    return (fields, nil)
}

private func describeFocusedField(bundleID: String) -> (FieldDescription?, String?) {
    guard frontmostBundleID() == bundleID, let app = NSWorkspace.shared.frontmostApplication else {
        return (nil, "frontmostChanged")
    }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    guard let focusedRef = attribute(appElement, kAXFocusedUIElementAttribute) else { return (nil, "noFocusedElement") }
    let focused = focusedRef as! AXUIElement
    let window = attribute(focused, kAXWindowAttribute).map { $0 as! AXUIElement }
    return (FieldDescription(role: attribute(focused, kAXRoleAttribute) as? String,
                             subrole: attribute(focused, kAXSubroleAttribute) as? String,
                             description: attribute(focused, kAXDescriptionAttribute) as? String,
                             title: attribute(focused, kAXTitleAttribute) as? String,
                             placeholder: attribute(focused, "AXPlaceholderValue") as? String,
                             identifier: attribute(focused, kAXIdentifierAttribute) as? String,
                             windowTitle: window.flatMap { attribute($0, kAXTitleAttribute) as? String }), nil)
}

nonisolated(unsafe) private var findInWindowMode = false

/// Reads the focused element of the expected app only when it matches the designation.
/// With `--find-in-window`, reads the first window text field that matches instead.
/// Returns a reason instead of content for any other element.
private func readFocusedField(bundleID: String, designation: Designation) -> (FieldReading?, String?) {
    if findInWindowMode {
        let (fields, reason) = windowTextFields(bundleID: bundleID)
        if let reason { return (nil, reason) }
        for (element, _) in fields {
            let (reading, failure) = readField(element, designation: designation)
            if failure == nil { return (reading, nil) }
        }
        return (nil, "untrustedTarget")
    }
    guard frontmostBundleID() == bundleID, let app = NSWorkspace.shared.frontmostApplication else {
        return (nil, "frontmostChanged")
    }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    guard let focusedRef = attribute(appElement, kAXFocusedUIElementAttribute) else { return (nil, "noFocusedElement") }
    return readField(focusedRef as! AXUIElement, designation: designation)
}

private func readField(_ focused: AXUIElement, designation: Designation) -> (FieldReading?, String?) {
    let role = attribute(focused, kAXRoleAttribute) as? String
    if let expected = designation.role, role != expected { return (nil, "untrustedTarget") }
    if let expected = designation.identifier, attribute(focused, kAXIdentifierAttribute) as? String != expected {
        return (nil, "untrustedTarget")
    }
    if let needle = designation.descriptionContains {
        let description = (attribute(focused, kAXDescriptionAttribute) as? String ?? "") + " " +
            (attribute(focused, kAXTitleAttribute) as? String ?? "") + " " +
            (attribute(focused, "AXPlaceholderValue") as? String ?? "")
        guard description.localizedCaseInsensitiveContains(needle) else { return (nil, "untrustedTarget") }
    }
    if let needle = designation.windowTitleContains {
        let window = attribute(focused, kAXWindowAttribute).map { $0 as! AXUIElement }
        let title = window.flatMap { attribute($0, kAXTitleAttribute) as? String } ?? ""
        guard title.contains(needle) else { return (nil, "untrustedTarget") }
    }
    let value = attribute(focused, kAXValueAttribute) as? String
    // The marker check needs the value; a non-matching value is discarded, never reported.
    if let prefix = designation.valuePrefix, !(value ?? "").hasPrefix(prefix) { return (nil, "untrustedTarget") }
    let length = (attribute(focused, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue
    return (FieldReading(role: role, value: value, selection: range(focused, kAXSelectedTextRangeAttribute),
                         markedRange: range(focused, "AXMarkedTextRange"), length: length), nil)
}

// MARK: - Interference guard

nonisolated(unsafe) private var interferencePID: Int?

private func installInterferenceGuard() -> Bool {
    // A listen-only tap can be created without Input Monitoring but then receives no keyboard events.
    guard CGPreflightListenEventAccess() else { return false }
    let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown,
                                .otherMouseDown, .mouseMoved, .leftMouseDragged, .scrollWheel]
    let mask = types.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                      eventsOfInterest: mask, callback: { _, _, event, _ in
        // Physical input carries no driver marker and comes from no posting process (PID 0).
        // Events generated by VietMac or other posting apps carry their own PID and are ignored.
        if event.getIntegerValueField(.eventSourceUserData) != driverMarker,
           event.getIntegerValueField(.eventSourceUnixProcessID) == 0, interferencePID == nil {
            interferencePID = 0
        }
        return Unmanaged.passUnretained(event)
    }, userInfo: nil) else { return false }
    let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
}

// MARK: - Run

private func run() -> Int32 {
    guard let options = parse(CommandLine.arguments) else {
        FileHandle.standardError.write(Data("""
            usage: VietMacDriver (--keys <text, | = pause> | --script <file> | --script-json <json>) --expect-bundle <id> --out <absolute path>
                   [--interval-ms 80] [--hold-ms 50] [--pause-ms 1000] [--start-delay-ms 300] [--max-seconds 120]
                   [--select-abc] [--click x,y] [--protected] [--validate-only] [--allow-unguarded]
                   [--target-role R] [--target-description D] [--target-window W] [--target-value-prefix P] [--target-identifier I]
                   [--require-target]  (check the designation before every key press)
                   [--find-in-window]  (match the designation among the focused window's text fields)
                   VietMacDriver --list-window-fields --expect-bundle <id> --out <absolute path>  (no field text)
                   VietMacDriver --read-focused --expect-bundle <id> --out <absolute path> --target-… (at least one)
                   VietMacDriver --describe-focused --expect-bundle <id> --out <absolute path>  (no field text)
            hold > interval produces key rollover. Checkpoints read the field only with a --target-… designation.\n
            """.utf8))
        return 64
    }
    var result = Result()
    func finish(_ reason: String?, _ detail: String? = nil) -> Int32 {
        if let reason { result.status = "aborted"; result.reason = reason; result.detail = detail }
        write(result, to: options.output)
        return reason == nil ? 0 : 1
    }

    findInWindowMode = options.findInWindow
    if options.listWindowFields {
        guard AXIsProcessTrusted() else { return finish("accessibilityDenied") }
        let (fields, reason) = windowTextFields(bundleID: options.expectedBundleID)
        result.windowFields = fields.map(\.1)
        result.frontmostBundleID = frontmostBundleID()
        return finish(reason)
    }

    if options.describeFocused {
        guard AXIsProcessTrusted() else { return finish("accessibilityDenied") }
        let (focused, reason) = describeFocusedField(bundleID: options.expectedBundleID)
        result.focused = focused
        result.frontmostBundleID = frontmostBundleID()
        return finish(reason)
    }

    if options.readFocused {
        guard AXIsProcessTrusted() else { return finish("accessibilityDenied") }
        let (field, reason) = readFocusedField(bundleID: options.expectedBundleID, designation: options.designation)
        result.field = field
        result.frontmostBundleID = frontmostBundleID()
        result.clipboardChangeCountAfter = NSPasteboard.general.changeCount
        return finish(reason)
    }

    var script: DriverScript
    do {
        if let json = options.scriptJSON {
            script = try DriverScript.parse(json: Data(json.utf8))
        } else if let path = options.scriptPath {
            script = try DriverScript.parse(json: Data(contentsOf: URL(fileURLWithPath: path)))
        } else {
            script = try DriverScript.shorthand(options.keys ?? "", interval: options.interval, hold: options.hold,
                                                pause: options.pause)
        }
        if options.protected { script.protected = true; try script.validate() }
        if let (x, y) = options.click { script.steps.insert(.click(x: x, y: y), at: 0) }
    } catch let error as ScriptError {
        return finish("invalidScript", error.description)
    } catch {
        return finish("invalidScript", "\(error)")
    }
    let timeline = script.timeline()
    if options.validateOnly {
        result.status = "valid"
        result.detail = "\(timeline.count) events, \(Int(timeline.last?.offset ?? 0)) ms"
        return finish(nil)
    }
    guard CGPreflightPostEventAccess() else {
        _ = CGRequestPostEventAccess()
        return finish("postEventAccessDenied")
    }
    result.interferenceGuard = installInterferenceGuard()
    guard result.interferenceGuard || options.allowUnguarded else {
        _ = CGRequestListenEventAccess()
        return finish("interferenceGuardUnavailable", "grant Input Monitoring to VietMacDriver")
    }
    result.clipboardChangeCountBefore = NSPasteboard.general.changeCount

    // State this run changes and must undo on every exit path.
    let source = CGEventSource(stateID: .hidSystemState)
    var pressed: [UInt16: (Set<Modifier>, String?)] = [:]
    var heldModifiers: Set<Modifier> = []
    var capsLockOn = false
    var previousSource: TISInputSource?

    func post(_ event: CGEvent?) {
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: driverMarker)
        event.post(tap: .cghidEventTap)
        result.eventsPosted += 1
    }
    func flags(_ modifiers: Set<Modifier>, capsLock: Bool) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if capsLock { flags.insert(.maskAlphaShift) }
        return flags
    }
    func postKey(_ code: UInt16, down: Bool, modifiers: Set<Modifier>, text: String?, autorepeat: Bool, capsLock: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
        event?.flags = flags(modifiers, capsLock: capsLock)
        if let text {
            var units = Array(text.utf16)
            event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        }
        if autorepeat { event?.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        post(event)
        result.keyEventsPosted += 1
    }
    func postFlags(_ code: UInt16, _ flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        event?.type = .flagsChanged
        event?.flags = flags
        post(event)
    }
    func cleanUp() {
        for (code, (modifiers, text)) in pressed {
            postKey(code, down: false, modifiers: modifiers, text: text, autorepeat: false, capsLock: capsLockOn)
        }
        pressed.removeAll()
        for modifier in heldModifiers {
            heldModifiers.remove(modifier)
            postFlags(modifier.keyCode, flags(heldModifiers, capsLock: capsLockOn))
        }
        if capsLockOn { capsLockOn = false; postFlags(57, []) }
        if let previousSource {
            TISSelectInputSource(previousSource)
            result.restoredInputSource = currentInputSource()
        }
        wait(until: Date().addingTimeInterval(0.05))
        result.heldFlagsAfter = CGEventSource.flagsState(.hidSystemState).rawValue &
            (CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue |
             CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue)
        result.clipboardChangeCountAfter = NSPasteboard.general.changeCount
    }
    func abort(_ reason: String) -> Int32 {
        cleanUp()
        return finish(reason)
    }

    wait(until: Date().addingTimeInterval(options.startDelay / 1000))
    if options.selectABC, let current = currentInputSource(), !allowedSources.contains(current) {
        guard let abc = inputSource(withID: "com.apple.keylayout.ABC") ?? inputSource(withID: "com.apple.keylayout.US"),
              let previous = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return finish("inputSourceSelectionFailed")
        }
        previousSource = previous
        TISSelectInputSource(abc)
        wait(until: Date().addingTimeInterval(0.8)) // VietMac polls every 250 ms.
    }
    result.inputSource = currentInputSource()
    result.frontmostBundleID = frontmostBundleID()
    guard let inputSource = result.inputSource, allowedSources.contains(inputSource) else {
        return abort("unsupportedInputSource")
    }
    interferencePID = nil

    let started = Date()
    for event in timeline {
        wait(until: started.addingTimeInterval(event.offset / 1000))
        let frontmost = frontmostBundleID()
        let currentSource = currentInputSource()
        if let pid = interferencePID {
            result.interferenceSourcePID = pid
            return abort("userInterference")
        }
        if Date().timeIntervalSince(started) > options.maximumSeconds { return abort("timeLimit") }
        if frontmost != options.expectedBundleID {
            result.frontmostBundleID = frontmost
            return abort("frontmostChanged")
        }
        if !(currentSource.map(allowedSources.contains) ?? false) {
            result.inputSource = currentSource
            return abort("inputSourceChanged")
        }
        // In apps the user also works in (VS Code, Notes), a key may only go to the designated test field.
        if options.requireTarget, case .key(_, true, _, _, _, _) = event.kind {
            let (_, reason) = readFocusedField(bundleID: options.expectedBundleID, designation: options.designation)
            if let reason { return abort(reason == "untrustedTarget" ? "targetChanged" : reason) }
        }
        switch event.kind {
        case .key(let code, let down, let modifiers, let text, let autorepeat, let capsLock):
            postKey(code, down: down, modifiers: modifiers, text: text, autorepeat: autorepeat, capsLock: capsLock)
            if down { pressed[code] = (modifiers, text) } else { pressed[code] = nil }
        case .modifier(let modifier, let down, let held):
            postFlags(modifier.keyCode, flags(held, capsLock: capsLockOn))
            if down { heldModifiers.insert(modifier) } else { heldModifiers.remove(modifier) }
        case .capsLock(let on):
            capsLockOn = on
            postFlags(57, on ? .maskAlphaShift : [])
        case .click(let x, let y, let down):
            let type: CGEventType = down ? .leftMouseDown : .leftMouseUp
            post(CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left))
        case .checkpoint(let name):
            var checkpoint = Checkpoint(name: name, offsetMilliseconds: Date().timeIntervalSince(started) * 1000)
            if !options.designation.isEmpty {
                let (field, reason) = readFocusedField(bundleID: options.expectedBundleID, designation: options.designation)
                checkpoint.field = field
                checkpoint.reason = reason
            }
            result.checkpoints.append(checkpoint)
        }
    }
    result.durationMilliseconds = Date().timeIntervalSince(started) * 1000
    cleanUp()
    return finish(nil)
}

exit(run())
