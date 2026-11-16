import CoreGraphics
import VietMacCore

public enum TransportError: Error, Equatable {
    case preparationFailed
    case invalidPlan
}

public enum SendResult: Equatable {
    case posted
    case staleBeforeSend
    case uncertainAfterSend
}

public struct PreparedReplacement {
    let events: [CGEvent]
}

/// Event creation is separate from sending so failure cannot follow deletion.
public final class PreparedTransport {
    public typealias Factory = (CGKeyCode, Bool) -> CGEvent?
    public let marker: Int64
    private let factory: Factory

    public init(marker: Int64, factory: Factory? = nil) {
        self.marker = marker
        let source = CGEventSource(stateID: .privateState)
        self.factory = factory ?? { CGEvent(keyboardEventSource: source, virtualKey: $0, keyDown: $1) }
    }

    /// `insertionKeyCode` must be a key the client cannot see as held. The host passes the consumed
    /// trigger key: reusing another physical key (for example `kVK_ANSI_A` while A is down) lets the
    /// client drop the insertion after the deletion has already landed.
    /// `leadingKey` prepends one key that removes an address bar's inline completion: forward Delete (117),
    /// which does nothing when no completion is shown, or Backspace (51) where the field ignores forward Delete.
    public func prepare(_ plan: ReplacementPlan, insertionKeyCode: CGKeyCode,
                        leadingKey: CGKeyCode? = nil) throws -> PreparedReplacement {
        let units = Array(plan.insertion.utf16)
        guard (0...64).contains(plan.deleteCount), units.count <= 128 else {
            throw TransportError.invalidPlan
        }
        var events: [CGEvent] = []
        events.reserveCapacity(plan.deleteCount * 2 + (units.isEmpty ? 0 : 2) + (leadingKey == nil ? 0 : 2))
        func make(_ code: CGKeyCode, down: Bool) throws -> CGEvent {
            guard let event = factory(code, down) else { throw TransportError.preparationFailed }
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            return event
        }
        if let leadingKey {
            guard leadingKey == 117 || leadingKey == 51 else { throw TransportError.invalidPlan }
            events.append(try make(leadingKey, down: true))
            events.append(try make(leadingKey, down: false))
        }
        for _ in 0..<plan.deleteCount {
            events.append(try make(51, down: true))
            events.append(try make(51, down: false))
        }
        if !units.isEmpty {
            for down in [true, false] {
                let event = try make(insertionKeyCode, down: down)
                units.withUnsafeBufferPointer {
                    event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress!)
                }
                events.append(event)
            }
        }
        return PreparedReplacement(events: events)
    }

    /// `posted` means all calls ran, not that the client acknowledged insertion.
    public func send(_ prepared: PreparedReplacement, isCurrent: () -> Bool,
                     post: (CGEvent) -> Bool) -> SendResult {
        var started = false
        for event in prepared.events {
            guard isCurrent() else { return started ? .uncertainAfterSend : .staleBeforeSend }
            started = true
            guard post(event) else { return .uncertainAfterSend }
        }
        return isCurrent() ? .posted : (started ? .uncertainAfterSend : .staleBeforeSend)
    }
}
