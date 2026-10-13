import CoreGraphics
import Testing
@testable import VietMacPlatform

private func key(_ text: String, code: CGKeyCode = 0, flags: CGEventFlags = []) throws -> CGEvent {
    let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
    let units = Array(text.utf16)
    units.withUnsafeBufferPointer {
        event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress!)
    }
    event.flags = flags
    return event
}

struct EventNormalizerTests {
    @Test func usesTextCaseRatherThanShiftOrCapsLock() throws {
        for flags in [CGEventFlags.maskShift, .maskAlphaShift, [.maskShift, .maskAlphaShift]] {
            let lower = try key("a", flags: flags)
            #expect(EventNormalizer.normalize(type: .keyDown, event: lower, marker: 999) ==
                    .input(.letter(97, keyCode: 0, isRepeat: false)))
        }
        #expect(EventNormalizer.normalize(type: .keyDown, event: try key("A"), marker: 999) ==
                .input(.letter(65, keyCode: 0, isRepeat: false)))
    }

    @Test func lifecycleAndGeneratedEventsBypassKeyboardReduction() throws {
        let event = try key("as")
        #expect(EventNormalizer.normalize(type: .tapDisabledByTimeout, event: event, marker: 12) == .timeout)
        #expect(EventNormalizer.normalize(type: .tapDisabledByUserInput, event: event, marker: 12) == .userDisabled)
        event.setIntegerValueField(.eventSourceUserData, value: 12)
        #expect(EventNormalizer.normalize(type: .keyDown, event: event, marker: 12) == .generated)
        #expect(EventNormalizer.normalize(type: .keyDown, event: event, marker: 13) == .input(.invalidate))
    }

    @Test func navigationEditChordsAndUnsupportedTextInvalidate() throws {
        for flags in [CGEventFlags.maskCommand, .maskControl, .maskAlternate] {
            #expect(EventNormalizer.normalize(type: .keyDown, event: try key("a", flags: flags), marker: 9) == .input(.invalidate))
        }
        for code: CGKeyCode in [53, 117, 123, 124, 125, 126] {
            #expect(EventNormalizer.normalize(type: .keyDown, event: try key("a", code: code), marker: 9) == .input(.invalidate))
        }
        for text in ["á", "👩🏽‍💻", "a\u{0301}", "ab"] {
            #expect(EventNormalizer.normalize(type: .keyDown, event: try key(text), marker: 9) == .input(.invalidate))
        }
        for text in ["[", "]", " ", ".", "1"] {
            #expect(EventNormalizer.normalize(type: .keyDown, event: try key(text), marker: 9) == .input(.boundary))
        }
    }

    @Test func keyUpMouseAndBackspaceAreExplicit() throws {
        let event = try key("a", code: 51)
        #expect(EventNormalizer.normalize(type: .keyDown, event: event, marker: 9) == .input(.backspace))
        #expect(EventNormalizer.normalize(type: .keyUp, event: event, marker: 9) == .input(.keyUp(51)))
        #expect(EventNormalizer.normalize(type: .leftMouseDown, event: event, marker: 9) == .input(.invalidate))
    }
}

struct CallbackTimingsTests {
    @Test func ringIsBoundedAndEmptyIsNotTimingEvidence() {
        var timings = CallbackTimings()
        #expect(timings.snapshot().p99Nanoseconds == nil)
        for sample in UInt64(1)...2000 { timings.record(sample) }
        let report = timings.snapshot()
        #expect(report.totalSamples == 2000)
        #expect(report.retainedSamples == 1024)
        #expect(report.maximumNanoseconds == 2000)
        #expect(report.medianNanoseconds! >= 977)
        #expect(report.scope == "event-tap-callback-own-work")
    }
}
