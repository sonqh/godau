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

    public func prepare(_ plan: ReplacementPlan) throws -> PreparedReplacement {
        let units = Array(plan.insertion.utf16)
        guard (0...64).contains(plan.deleteCount), units.count <= 128 else {
            throw TransportError.invalidPlan
        }
        var events: [CGEvent] = []
        events.reserveCapacity(plan.deleteCount * 2 + (units.isEmpty ? 0 : 2))
        func make(_ code: CGKeyCode, down: Bool) throws -> CGEvent {
            guard let event = factory(code, down) else { throw TransportError.preparationFailed }
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            return event
        }
        for _ in 0..<plan.deleteCount {
            events.append(try make(51, down: true))
            events.append(try make(51, down: false))
        }
        if !units.isEmpty {
            for down in [true, false] {
                let event = try make(0, down: down)
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
