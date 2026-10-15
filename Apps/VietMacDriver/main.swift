import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

// Test-only native key driver. It posts scripted key events at the HID tap, so session event
// taps such as VietMac's see them like keyboard input. It is not linked into VietMac.
// It refuses to type unless the expected app is frontmost with an ABC or U.S. input source,
// and it releases every key it pressed before exiting.

struct Options {
    var keys = ""
    var intervalMilliseconds = 80.0
    var holdMilliseconds = 50.0
    var pauseMilliseconds = 1000.0
    var startDelayMilliseconds = 300.0
    var maximumSeconds = 120.0
    var expectedBundleID = ""
    var output = ""
    var selectABC = false
    var click: CGPoint?
}

struct Result: Encodable {
    var status = "pass"
    var reason: String?
    var keyEventsPosted = 0
    var characters = 0
    var durationMilliseconds = 0.0
    var frontmostBundleID: String?
    var inputSource: String?
    var intervalMilliseconds = 0.0
    var holdMilliseconds = 0.0
    var restoredInputSource: String?
}

private let keyCodes: [Character: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
    "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, " ": 49,
]
private let allowedSources: Set<String> = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]

private func parse(_ arguments: [String]) -> Options? {
    var options = Options()
    var index = 1
    while index < arguments.count {
        if arguments[index] == "--select-abc" {
            options.selectABC = true
            index += 1
            continue
        }
        guard index + 1 < arguments.count else { return nil }
        let value = arguments[index + 1]
        switch arguments[index] {
        case "--keys": options.keys = value
        case "--interval-ms": options.intervalMilliseconds = Double(value) ?? -1
        case "--hold-ms": options.holdMilliseconds = Double(value) ?? -1
        case "--pause-ms": options.pauseMilliseconds = Double(value) ?? -1
        case "--start-delay-ms": options.startDelayMilliseconds = Double(value) ?? -1
        case "--max-seconds": options.maximumSeconds = Double(value) ?? -1
        case "--expect-bundle": options.expectedBundleID = value
        case "--out": options.output = value
        case "--click":
            let parts = value.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            options.click = CGPoint(x: parts[0], y: parts[1])
        default: return nil
        }
        index += 2
    }
    guard index == arguments.count, !options.keys.isEmpty, !options.expectedBundleID.isEmpty,
          options.output.hasPrefix("/"), options.intervalMilliseconds > 0, options.holdMilliseconds > 0, options.pauseMilliseconds >= 0,
          options.startDelayMilliseconds >= 0, options.maximumSeconds > 0 else { return nil }
    return options
}

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

/// Waits on the main run loop so NSWorkspace keeps the frontmost application current.
private func wait(until deadline: Date) {
    while Date() < deadline { RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.005))) }
}

private func write(_ result: Result, to path: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(result) {
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

private struct Step {
    let offset: Double
    let character: Character
    let code: CGKeyCode
    let down: Bool
}

private func run() -> Int32 {
    guard let options = parse(CommandLine.arguments) else {
        FileHandle.standardError.write(Data("""
            usage: VietMacDriver --keys <a-z, A-Z, space, | = pause> --expect-bundle <id> --out <absolute path>
                   [--interval-ms 80] [--hold-ms 50] [--start-delay-ms 300] [--max-seconds 120] [--pause-ms 1000] [--select-abc] [--click x,y]
            hold > interval produces key rollover. --select-abc selects ABC for the run and restores
            the previous input source on exit. --click focuses the field with one left click in global
            display points before typing.\n
            """.utf8))
        return 64
    }
    var result = Result(intervalMilliseconds: options.intervalMilliseconds, holdMilliseconds: options.holdMilliseconds)
    var previousSource: TISInputSource?
    func finish(_ reason: String?) -> Int32 {
        if let previousSource {
            TISSelectInputSource(previousSource)
            result.restoredInputSource = currentInputSource()
        }
        if let reason { result.status = "aborted"; result.reason = reason }
        write(result, to: options.output)
        return reason == nil ? 0 : 1
    }
    guard CGPreflightPostEventAccess() else {
        _ = CGRequestPostEventAccess()
        return finish("postEventAccessDenied")
    }
    // Schedule every press and release; overlapping times reproduce rollover.
    var steps: [Step] = []
    var start = 0.0
    for character in options.keys {
        if character == "|" {
            start += options.pauseMilliseconds // Lets the page change context between keys.
            continue
        }
        guard let code = keyCodes[Character(character.lowercased())] else {
            return finish("unsupportedCharacter")
        }
        defer { start += options.intervalMilliseconds }
        result.characters += 1
        steps.append(Step(offset: start, character: character, code: code, down: true))
        steps.append(Step(offset: start + options.holdMilliseconds, character: character, code: code, down: false))
    }
    steps.sort { $0.offset == $1.offset ? $0.down && !$1.down : $0.offset < $1.offset }

    wait(until: Date().addingTimeInterval(options.startDelayMilliseconds / 1000))
    if options.selectABC, let current = currentInputSource(), !allowedSources.contains(current) {
        guard let abc = inputSource(withID: "com.apple.keylayout.ABC") ?? inputSource(withID: "com.apple.keylayout.US"),
              let previous = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return finish("inputSourceSelectionFailed")
        }
        previousSource = previous
        TISSelectInputSource(abc)
        // Give observers (VietMac polls every 250 ms) time to see the new source.
        wait(until: Date().addingTimeInterval(0.8))
    }
    result.inputSource = currentInputSource()
    result.frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    guard let inputSource = result.inputSource, allowedSources.contains(inputSource) else {
        return finish("unsupportedInputSource")
    }
    let source = CGEventSource(stateID: .hidSystemState)
    if let point = options.click {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == options.expectedBundleID else {
            return finish("frontmostChanged")
        }
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
            wait(until: Date().addingTimeInterval(0.05))
        }
        wait(until: Date().addingTimeInterval(0.6)) // The app moves focus; VietMac observes the field.
    }
    var pressed: Set<CGKeyCode> = []
    var characterForCode: [CGKeyCode: Character] = [:]
    func post(_ code: CGKeyCode, _ character: Character, down: Bool) -> Bool {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return false }
        event.flags = character.isUppercase ? .maskShift : []
        var units = Array(String(character).utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        event.post(tap: .cghidEventTap)
        result.keyEventsPosted += 1
        return true
    }
    func releaseAll() {
        for code in pressed { _ = post(code, characterForCode[code] ?? " ", down: false) }
        pressed.removeAll()
    }

    let started = Date()
    for step in steps {
        wait(until: started.addingTimeInterval(step.offset / 1000))
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let source = currentInputSource()
        let abort: String? =
            Date().timeIntervalSince(started) > options.maximumSeconds ? "timeLimit" :
            frontmost != options.expectedBundleID ? "frontmostChanged" :
            !(source.map(allowedSources.contains) ?? false) ? "inputSourceChanged" : nil
        if let abort {
            result.frontmostBundleID = frontmost
            result.inputSource = source
            releaseAll()
            return finish(abort)
        }
        guard post(step.code, step.character, down: step.down) else {
            releaseAll()
            return finish("eventCreationFailed")
        }
        if step.down { pressed.insert(step.code); characterForCode[step.code] = step.character }
        else { pressed.remove(step.code) }
    }
    result.durationMilliseconds = Date().timeIntervalSince(started) * 1000
    return finish(nil)
}

exit(run())
