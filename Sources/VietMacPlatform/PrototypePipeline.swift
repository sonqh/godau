import Foundation
import VietMacCore

public enum PrototypeInput: Equatable, Sendable {
    case letter(UInt8, keyCode: UInt16, isRepeat: Bool)
    case keyUp(UInt16)
    case backspace
    case boundary
    case invalidate
}

public struct PendingReplacement: Equatable, Sendable {
    public let previous: String
    public let next: String
    public let generation: UInt64
    public let keyCode: UInt16
}

public enum PrototypeAction: Equatable, Sendable {
    case passThrough
    case consume
    case replace(PendingReplacement)
}

/// Key ownership, pause, and context state around the Telex composer from `VietMacCore`.
/// The host confines this value and its transport to one owning run loop.
public struct PrototypePipeline {
    /// The visible text of the tracked word, as the field shows it.
    public private(set) var word = ""
    private var composer = TelexComposer()
    /// Composer state for a replacement that is not accepted yet.
    private var pendingComposer: TelexComposer?
    public private(set) var generation: UInt64 = 0
    public private(set) var enabled = false
    public private(set) var literalUntilBoundary = false
    public private(set) var environment: InputEnvironment
    private var pause: PauseReason?
    private var consumed = Array(repeating: false, count: 128)
    private var timeoutRecoveries: [UInt64] = []
    /// ASCII letters typed while the only pause was an uncertain context, in order. Never transformed;
    /// adopted only when an observation shows the field holds exactly these letters. Bounded to 64.
    private var unownedLetters: [UInt8] = []

    public init(environment: InputEnvironment) {
        self.environment = environment
        timeoutRecoveries.reserveCapacity(3)
        unownedLetters.reserveCapacity(Self.unownedCapacity)
    }

    static let unownedCapacity = 64
    public var unownedLetterCount: Int { unownedLetters.count }

    public var state: InputRuntimeState {
        if !enabled { return .disabled }
        if let reason = pause ?? environment.pauseReason { return .paused(reason) }
        return .active
    }

    var hasConsumedKeys: Bool { consumed.contains(true) }

    /// Physical ownership precedes semantic policy, including during a pause.
    mutating func beginPhysicalPress(_ code: UInt16, isRepeat: Bool) -> Bool {
        guard code < consumed.count else { return false }
        if isRepeat { return consumed[Int(code)] }
        consumed[Int(code)] = false
        return false
    }

    public mutating func setEnabled(_ value: Bool) {
        enabled = value
        pause = nil
        timeoutRecoveries.removeAll(keepingCapacity: true)
        invalidate(holdUntilBoundary: false)
    }

    public mutating func updateEnvironment(_ value: InputEnvironment) {
        guard value != environment else { return }
        // Context turning certain changes no ownership: the word is empty, or was adopted from this
        // observation. Every other change ends the word.
        var regained = environment
        regained.certainContext = true
        let onlyRegainedCertainty = !environment.certainContext && value.certainContext && regained == value
        environment = value
        if !onlyRegainedCertainty { invalidate() }
    }

    /// Makes the letters typed during an uncertain context the tracked word. The field shows them as typed;
    /// the composer state may already differ (for example `tuw` is `tư`), and the next key's replacement
    /// rewrites the visible letters. Returns false, and forgets them, if they cannot form a tracked word.
    @discardableResult
    public mutating func adoptUnownedLetters() -> Bool {
        defer { unownedLetters.removeAll(keepingCapacity: true) }
        guard word.isEmpty, !literalUntilBoundary, !unownedLetters.isEmpty else { return false }
        var next = TelexComposer()
        for byte in unownedLetters {
            if case .untracked = next.input(byte) { return false }
        }
        composer = next
        word = String(decoding: unownedLetters, as: UTF8.self)
        return true
    }

    /// Ends the tracked word. A context reset starts the next word at the next letter (Son, 2026-11-15:
    /// in Vietnamese mode, always type Vietnamese). Replacements still delete only letters VietMac saw typed
    /// since the reset, and only in a settled field. `holdUntilBoundary` is for overflow and the tone-move
    /// Backspace, where the visible word continues past what VietMac owns.
    public mutating func invalidate(holdUntilBoundary: Bool = false) {
        generation &+= 1
        word.removeAll(keepingCapacity: true)
        unownedLetters.removeAll(keepingCapacity: true)
        composer.reset()
        pendingComposer = nil
        literalUntilBoundary = holdUntilBoundary
        // Keep consumed key ownership until release, including after a pause.
    }

    public mutating func pauseFor(_ reason: PauseReason) {
        pause = reason
        invalidate()
    }

    /// Returns whether the host can attempt a timeout re-enable. Monotonic ns.
    public mutating func timeout(at now: UInt64) -> Bool {
        invalidate()
        guard enabled, pause == nil, environment.pauseReason == nil else { return false }
        timeoutRecoveries.removeAll { now >= $0 && now - $0 >= 60_000_000_000 }
        guard timeoutRecoveries.count < 3 else {
            pause = .recoveryLimit
            return false
        }
        timeoutRecoveries.append(now)
        return true
    }

    public mutating func handle(_ input: PrototypeInput) -> PrototypeAction {
        // Releases of consumed keys stay consumed even after disable/context loss.
        if case .keyUp(let code) = input {
            guard code < consumed.count, consumed[Int(code)] else { return .passThrough }
            consumed[Int(code)] = false
            return .consume
        }
        if case .letter(_, let code, let repeated) = input,
           beginPhysicalPress(code, isRepeat: repeated) { return .consume }
        guard state == .active else {
            recordUnowned(input)
            return .passThrough
        }
        switch input {
        case .letter(let byte, let code, let repeated):
            guard code < consumed.count,
                  (65...90).contains(byte) || (97...122).contains(byte) else {
                invalidate()
                return .passThrough
            }
            guard !literalUntilBoundary else { return .passThrough }
            var next = composer
            switch next.input(byte) {
            case .untracked:
                // Overflow: never transform a disconnected suffix of the same visible word.
                invalidate(holdUntilBoundary: true)
                return .passThrough
            case .text(let text):
                if text == word + String(UnicodeScalar(byte)) {
                    composer = next
                    word = text
                    return .passThrough
                }
                // A held modifier key never transforms; it is tracked as typed and the word turns literal.
                guard !repeated else {
                    if case .text(let literal) = composer.inputLiteral(byte) { word = literal } else { invalidate() }
                    return .passThrough
                }
                pendingComposer = next
                return .replace(PendingReplacement(previous: word, next: text, generation: generation, keyCode: code))
            }
        case .backspace:
            // The physical Backspace deletes only the last visible character. When the composer would also
            // move the tone (`hoàn` -> `hòa`), the field and the word would differ, so ownership ends instead.
            // Moving the tone needs a Backspace-triggered replacement, which waits for U-5.
            guard !word.isEmpty else {
                // An unowned Backspace keeps an overflow hold; otherwise the next letter starts a word.
                invalidate(holdUntilBoundary: literalUntilBoundary)
                return .passThrough
            }
            var next = composer
            next.backspace()
            let expected = String(word.dropLast())
            if next.text == expected {
                composer = next
                word = expected
            } else {
                invalidate(holdUntilBoundary: true)
            }
            return .passThrough
        case .boundary:
            invalidate(holdUntilBoundary: false)
            return .passThrough
        case .invalidate:
            invalidate()
            return .passThrough
        case .keyUp:
            return .passThrough
        }
    }

    /// While the only pause is an uncertain context, remember letters for a later adoption.
    private mutating func recordUnowned(_ input: PrototypeInput) {
        guard enabled, pause == nil, environment.pauseReason == .uncertainContext else {
            unownedLetters.removeAll(keepingCapacity: true)
            return
        }
        switch input {
        case .letter(let byte, _, let repeated):
            guard !repeated, (65...90).contains(byte) || (97...122).contains(byte),
                  unownedLetters.count < Self.unownedCapacity else {
                unownedLetters.removeAll(keepingCapacity: true)
                return
            }
            unownedLetters.append(byte)
        case .keyUp:
            break
        case .backspace, .boundary, .invalidate:
            unownedLetters.removeAll(keepingCapacity: true)
        }
    }

    public func isCurrent(_ edit: PendingReplacement) -> Bool {
        state == .active && generation == edit.generation && word == edit.previous
    }

    @discardableResult
    public mutating func accept(_ edit: PendingReplacement) -> Bool {
        guard isCurrent(edit), edit.keyCode < consumed.count, let next = pendingComposer else { return false }
        word = edit.next
        composer = next
        pendingComposer = nil
        consumed[Int(edit.keyCode)] = true
        return true
    }

    public mutating func consumeAfterUncertainSend(_ code: UInt16) {
        if code < consumed.count { consumed[Int(code)] = true }
        pauseFor(.transportUncertain)
    }
}
