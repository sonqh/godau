import CoreGraphics

enum NormalizedEvent: Equatable {
    case generated
    case timeout
    case userDisabled
    case input(PrototypeInput)
    case unhandled
}

enum EventNormalizer {
    static func normalize(type: CGEventType, event: CGEvent, marker: Int64) -> NormalizedEvent {
        // Lifecycle pseudo-events have no valid keyboard fields.
        if type == .tapDisabledByTimeout { return .timeout }
        if type == .tapDisabledByUserInput { return .userDisabled }
        if event.getIntegerValueField(.eventSourceUserData) == marker { return .generated }
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown ||
           type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged {
            return .input(.invalidate)
        }
        if type == .flagsChanged {
            return event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty
                ? .unhandled : .input(.invalidate)
        }
        guard type == .keyDown || type == .keyUp else { return .unhandled }
        let rawCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard (0..<128).contains(rawCode) else { return .input(.invalidate) }
        let code = UInt16(rawCode)
        if type == .keyUp { return .input(.keyUp(code)) }
        if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty {
            return .input(.invalidate)
        }
        if code == 51 { return .input(.backspace) }
        if [53, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(code) {
            return .input(.invalidate)
        }
        if [36, 48, 76].contains(code) { return .input(.boundary) }
        var units = [UniChar](repeating: 0, count: 2)
        var length = 0
        units.withUnsafeMutableBufferPointer {
            event.keyboardGetUnicodeString(maxStringLength: $0.count, actualStringLength: &length,
                                           unicodeString: $0.baseAddress!)
        }
        guard length == 1, units[0] < 128 else { return .input(.invalidate) }
        let byte = UInt8(units[0])
        if (65...90).contains(byte) || (97...122).contains(byte) {
            return .input(.letter(byte, keyCode: code,
                                  isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0))
        }
        return .input(.boundary)
    }
}
