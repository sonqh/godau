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

/// M0 examples only. This is not the production Telex reducer.
/// The host confines this value and its transport to one owning run loop.
public struct PrototypePipeline {
    public private(set) var word = ""
    public private(set) var generation: UInt64 = 0
    public private(set) var enabled = false
    public private(set) var literalUntilBoundary = false
    public private(set) var environment: InputEnvironment
    private var pause: PauseReason?
    private var consumed = Array(repeating: false, count: 128)
    private var timeoutRecoveries: [UInt64] = []

    public init(environment: InputEnvironment) {
        self.environment = environment
        timeoutRecoveries.reserveCapacity(3)
    }

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
        environment = value
        invalidate()
    }

    public mutating func invalidate(holdUntilBoundary: Bool = true) {
        generation &+= 1
        word.removeAll(keepingCapacity: true)
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
        guard state == .active else { return .passThrough }
        switch input {
        case .letter(let byte, let code, let repeated):
            guard code < consumed.count,
                  (65...90).contains(byte) || (97...122).contains(byte) else {
                invalidate()
                return .passThrough
            }
            guard !literalUntilBoundary else { return .passThrough }
            if !repeated, word == "a" || word == "A" {
                let upper = word == "A"
                let base = byte | 0x20
                let next = base == 115 ? (upper ? "Á" : "á") :
                           base == 97 ? (upper ? "Â" : "â") : nil
                if let next {
                    return .replace(PendingReplacement(previous: word, next: next,
                                                      generation: generation, keyCode: code))
                }
            }
            guard word.count < 64 else {
                invalidate()
                return .passThrough
            }
            word.append(Character(UnicodeScalar(byte)))
            return .passThrough
        case .backspace:
            if !word.isEmpty { word.removeLast() }
            else { invalidate() }
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

    public func isCurrent(_ edit: PendingReplacement) -> Bool {
        state == .active && generation == edit.generation && word == edit.previous
    }

    @discardableResult
    public mutating func accept(_ edit: PendingReplacement) -> Bool {
        guard isCurrent(edit), edit.keyCode < consumed.count else { return false }
        word = edit.next
        consumed[Int(edit.keyCode)] = true
        return true
    }

    public mutating func consumeAfterUncertainSend(_ code: UInt16) {
        if code < consumed.count { consumed[Int(code)] = true }
        pauseFor(.transportUncertain)
    }
}
