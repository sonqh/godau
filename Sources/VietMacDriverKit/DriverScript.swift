import Foundation

// Test-only script model for VietMacDriver. It parses steps and builds an ordered event
// timeline without posting anything, so validation and timing are testable. It must not
// depend on VietMac modules.

public enum Modifier: String, CaseIterable, Codable, Sendable {
    case shift, control, option, command

    public var keyCode: UInt16 {
        switch self {
        case .shift: 56
        case .control: 59
        case .option: 58
        case .command: 55
        }
    }
}

/// One posted event, in posting order. `offset` is milliseconds from the run start.
public struct TimelineEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// `text` is the Unicode string to attach; nil for named keys.
        case key(code: UInt16, down: Bool, modifiers: Set<Modifier>, text: String?, autorepeat: Bool, capsLock: Bool)
        case modifier(Modifier, down: Bool, held: Set<Modifier>)
        case capsLock(on: Bool)
        case click(x: Double, y: Double, down: Bool)
        case checkpoint(name: String)
    }

    public let offset: Double
    public let kind: Kind
}

public struct DriverScript: Sendable {
    public var steps: [Step]
    public var seed: UInt64
    public var protected: Bool
    public var interval: Double
    public var hold: Double
    public var pause: Double

    public enum Step: Equatable, Sendable {
        case text(String, interval: Double?, hold: Double?, jitter: Double)
        case key(String, modifiers: [Modifier])
        case hold(String, repeats: Int, repeatInterval: Double)
        case capsLock(Bool)
        case pause(Double)
        case click(x: Double, y: Double)
        case checkpoint(String, settle: Double)
    }

    public init(steps: [Step], seed: UInt64 = 1, protected: Bool = false,
                interval: Double = 80, hold: Double = 50, pause: Double = 1000) {
        self.steps = steps
        self.seed = seed
        self.protected = protected
        self.interval = interval
        self.hold = hold
        self.pause = pause
    }
}

public enum ScriptError: Error, Equatable, CustomStringConvertible {
    case invalidJSON(String)
    case unsupportedStep(index: Int, detail: String)
    case unsupportedCharacter(Character)
    case unsupportedKey(String)
    case protectedSubmission(String)
    case invalidTiming(String)

    public var description: String {
        switch self {
        case .invalidJSON(let detail): "invalidJSON: \(detail)"
        case .unsupportedStep(let index, let detail): "unsupportedStep[\(index)]: \(detail)"
        case .unsupportedCharacter(let character): "unsupportedCharacter: \(String(character).unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))"
        case .unsupportedKey(let name): "unsupportedKey: \(name)"
        case .protectedSubmission(let name): "protectedSubmission: \(name)"
        case .invalidTiming(let detail): "invalidTiming: \(detail)"
        }
    }
}

/// ANSI virtual key codes. Characters map to a key plus whether Shift is needed.
public enum KeyVocabulary {
    static let unshifted: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "=": 24, "-": 27, "]": 30, "[": 33, "'": 39, ";": 41, "\\": 42, ",": 43, "/": 44,
        ".": 47, "`": 50, " ": 49,
    ]
    static let shifted: [Character: Character] = [
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
        "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",", ">": ".",
        "?": "/", "~": "`",
    ]
    public static let named: [String: UInt16] = [
        "return": 36, "tab": 48, "space": 49, "backspace": 51, "escape": 53, "delete": 117,
        "left": 123, "right": 124, "down": 125, "up": 126, "home": 115, "end": 119,
        "pageup": 116, "pagedown": 121, "enter": 76,
    ]
    /// Keys that can submit or send content in a protected target.
    public static let submission: Set<String> = ["return", "enter"]

    /// Returns the key code and whether Shift is pressed for one typed character.
    public static func key(for character: Character) -> (code: UInt16, shift: Bool)? {
        if let code = unshifted[character] { return (code, false) }
        if character.isUppercase, let lower = character.lowercased().first, character.isASCII,
           let code = unshifted[lower] { return (code, true) }
        if let base = shifted[character], let code = unshifted[base] { return (code, true) }
        return nil
    }

    public static func key(named name: String) -> UInt16? {
        if let code = named[name.lowercased()] { return code }
        guard name.count == 1, let character = name.first, let (code, _) = key(for: character) else { return nil }
        return code
    }
}

/// SplitMix64: small, deterministic, and good enough for timing jitter.
struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [-range, range].
    mutating func offset(_ range: Double) -> Double {
        guard range > 0 else { return 0 }
        return (Double(next() >> 11) / Double(1 << 53) * 2 - 1) * range
    }
}

extension DriverScript {
    /// Parses `{"seed":1,"protected":false,"interval":80,"hold":50,"steps":[...]}`.
    public static func parse(json data: Data) throws -> DriverScript {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ScriptError.invalidJSON("expected an object")
        }
        guard let rawSteps = root["steps"] as? [[String: Any]], !rawSteps.isEmpty else {
            throw ScriptError.invalidJSON("steps must be a non-empty array of objects")
        }
        var script = DriverScript(steps: [])
        if let seed = root["seed"] as? Int, seed >= 0 { script.seed = UInt64(seed) }
        script.protected = root["protected"] as? Bool ?? false
        script.interval = root["interval"] as? Double ?? script.interval
        script.hold = root["hold"] as? Double ?? script.hold
        script.pause = root["pause"] as? Double ?? script.pause
        for (index, raw) in rawSteps.enumerated() {
            script.steps.append(try parseStep(raw, index: index))
        }
        try script.validate()
        return script
    }

    static func parseStep(_ raw: [String: Any], index: Int) throws -> Step {
        func number(_ key: String) -> Double? { (raw[key] as? NSNumber)?.doubleValue }
        if let text = raw["text"] as? String {
            return .text(text, interval: number("interval"), hold: number("hold"), jitter: number("jitter") ?? 0)
        }
        if let name = raw["key"] as? String {
            var modifiers: [Modifier] = []
            for value in raw["modifiers"] as? [String] ?? [] {
                guard let modifier = Modifier(rawValue: value) else {
                    throw ScriptError.unsupportedStep(index: index, detail: "modifier \(value)")
                }
                modifiers.append(modifier)
            }
            return .key(name, modifiers: modifiers)
        }
        if let name = raw["hold"] as? String {
            return .hold(name, repeats: raw["repeat"] as? Int ?? 0, repeatInterval: number("repeatInterval") ?? 35)
        }
        if let on = raw["capsLock"] as? Bool { return .capsLock(on) }
        if let duration = number("pause") { return .pause(duration) }
        if let point = raw["click"] as? [NSNumber], point.count == 2 {
            return .click(x: point[0].doubleValue, y: point[1].doubleValue)
        }
        if let name = raw["checkpoint"] as? String {
            return .checkpoint(name, settle: number("settle") ?? 300)
        }
        throw ScriptError.unsupportedStep(index: index, detail: raw.keys.sorted().joined(separator: ","))
    }

    /// Builds a script from the `--keys` shorthand, where `|` pauses for `pause` milliseconds.
    public static func shorthand(_ keys: String, interval: Double, hold: Double, pause: Double) throws -> DriverScript {
        var steps: [Step] = []
        for (position, part) in keys.split(separator: "|", omittingEmptySubsequences: false).enumerated() {
            if position > 0 { steps.append(.pause(pause)) }
            if !part.isEmpty { steps.append(.text(String(part), interval: nil, hold: nil, jitter: 0)) }
        }
        let script = DriverScript(steps: steps, interval: interval, hold: hold, pause: pause)
        try script.validate()
        return script
    }

    /// Rejects unsupported keys, invalid timing, and submission keys for protected targets.
    public func validate() throws {
        guard interval > 0, hold > 0, pause >= 0 else { throw ScriptError.invalidTiming("defaults") }
        for step in steps {
            switch step {
            case .text(let text, let stepInterval, let stepHold, let jitter):
                guard (stepInterval ?? interval) > 0, (stepHold ?? hold) > 0, jitter >= 0 else {
                    throw ScriptError.invalidTiming("text")
                }
                for character in text {
                    if protected, character == "\n" || character == "\r" {
                        throw ScriptError.protectedSubmission("newline")
                    }
                    guard KeyVocabulary.key(for: character) != nil else { throw ScriptError.unsupportedCharacter(character) }
                }
            case .key(let name, _), .hold(let name, _, _):
                if protected, KeyVocabulary.submission.contains(name.lowercased()) {
                    throw ScriptError.protectedSubmission(name)
                }
                guard KeyVocabulary.key(named: name) != nil else { throw ScriptError.unsupportedKey(name) }
                if case .hold(_, let repeats, let repeatInterval) = step, repeats < 0 || repeatInterval <= 0 {
                    throw ScriptError.invalidTiming("hold")
                }
            case .pause(let duration), .checkpoint(_, let duration):
                guard duration >= 0 else { throw ScriptError.invalidTiming("pause") }
            case .capsLock, .click:
                break
            }
        }
    }

    /// Orders every press and release. Overlapping text timing reproduces rollover.
    public func timeline() -> [TimelineEvent] {
        var events: [(TimelineEvent, Int)] = []
        var generator = SeededGenerator(seed: seed)
        var now = 0.0
        var capsLock = false
        func add(_ offset: Double, _ kind: TimelineEvent.Kind) {
            events.append((TimelineEvent(offset: offset, kind: kind), events.count))
        }
        for step in steps {
            switch step {
            case .text(let text, let stepInterval, let stepHold, let jitter):
                var lastRelease = now
                for character in text {
                    let (code, shift) = KeyVocabulary.key(for: character)!
                    let held = max(1, (stepHold ?? hold) + generator.offset(jitter))
                    let visible = capsLock && character.isLetter && character.isASCII
                        ? String(character).uppercased() : String(character)
                    let modifiers: Set<Modifier> = shift ? [.shift] : []
                    add(now, .key(code: code, down: true, modifiers: modifiers, text: visible, autorepeat: false, capsLock: capsLock))
                    add(now + held, .key(code: code, down: false, modifiers: modifiers, text: visible, autorepeat: false, capsLock: capsLock))
                    lastRelease = max(lastRelease, now + held)
                    now += max(1, (stepInterval ?? interval) + generator.offset(jitter))
                }
                // The next step starts after every key of this text is released.
                now = max(now, lastRelease + 1)
            case .key(let name, let modifiers):
                let code = KeyVocabulary.key(named: name)!
                var held: Set<Modifier> = []
                for modifier in modifiers {
                    held.insert(modifier)
                    add(now, .modifier(modifier, down: true, held: held)); now += 10
                }
                // A chord is a shortcut, not typed text; an attached string hides the modifiers.
                let text = name.count == 1 && modifiers.isEmpty ? name : nil
                add(now, .key(code: code, down: true, modifiers: held, text: text, autorepeat: false, capsLock: capsLock))
                now += hold
                add(now, .key(code: code, down: false, modifiers: held, text: text, autorepeat: false, capsLock: capsLock))
                for modifier in modifiers.reversed() {
                    now += 10
                    held.remove(modifier)
                    add(now, .modifier(modifier, down: false, held: held))
                }
                now += interval
            case .hold(let name, let repeats, let repeatInterval):
                let code = KeyVocabulary.key(named: name)!
                let text = name.count == 1 ? name : nil
                add(now, .key(code: code, down: true, modifiers: [], text: text, autorepeat: false, capsLock: capsLock))
                for _ in 0..<repeats {
                    now += repeatInterval
                    add(now, .key(code: code, down: true, modifiers: [], text: text, autorepeat: true, capsLock: capsLock))
                }
                now += hold
                add(now, .key(code: code, down: false, modifiers: [], text: text, autorepeat: false, capsLock: capsLock))
                now += interval
            case .capsLock(let on):
                capsLock = on
                add(now, .capsLock(on: on))
                now += interval
            case .pause(let duration):
                now += duration
            case .click(let x, let y):
                add(now, .click(x: x, y: y, down: true)); now += 50
                add(now, .click(x: x, y: y, down: false)); now += 600
            case .checkpoint(let name, let settle):
                now += settle
                add(now, .checkpoint(name: name))
            }
        }
        // Stable by offset: equal offsets keep script order.
        return events.sorted { $0.0.offset == $1.0.offset ? $0.1 < $1.1 : $0.0.offset < $1.0.offset }.map(\.0)
    }
}
