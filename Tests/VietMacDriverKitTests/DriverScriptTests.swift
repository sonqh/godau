import Foundation
import Testing
@testable import VietMacDriverKit

private func script(_ json: String) throws -> DriverScript {
    try DriverScript.parse(json: Data(json.utf8))
}

private func keys(_ timeline: [TimelineEvent]) -> [String] {
    timeline.compactMap {
        switch $0.kind {
        case .key(let code, let down, let modifiers, _, let autorepeat, _):
            "\(code)\(down ? "↓" : "↑")\(autorepeat ? "r" : "")\(modifiers.isEmpty ? "" : "+" + modifiers.map(\.rawValue).sorted().joined(separator: ","))"
        case .modifier(let modifier, let down, _): "\(modifier.rawValue)\(down ? "↓" : "↑")"
        case .capsLock(let on): "caps\(on ? "On" : "Off")"
        case .click(_, _, let down): "click\(down ? "↓" : "↑")"
        case .checkpoint(let name): "#\(name)"
        }
    }
}

struct DriverScriptTests {
    @Test func rolloverPressesTheNextKeyBeforeReleasingThePrevious() throws {
        let timeline = try script(#"{"steps":[{"text":"as","interval":70,"hold":110}]}"#).timeline()
        #expect(keys(timeline) == ["0↓", "1↓", "0↑", "1↑"])
    }

    @Test func chordWrapsTheKeyInItsModifiers() throws {
        let timeline = try script(#"{"steps":[{"key":"z","modifiers":["command","shift"]}]}"#).timeline()
        #expect(keys(timeline) == ["command↓", "shift↓", "6↓+command,shift", "6↑+command,shift", "shift↑", "command↑"])
        // Chrome treated Command-A as typed `a` while a Unicode string was attached.
        let chordText = timeline.compactMap { event -> String?? in
            if case .key(_, _, _, let text, _, _) = event.kind { return .some(text) }
            return nil
        }
        #expect(chordText.allSatisfy { $0 == nil })
    }

    @Test func heldKeyRepeatsWithAutorepeatAndOneRelease() throws {
        let timeline = try script(#"{"steps":[{"hold":"a","repeat":3}]}"#).timeline()
        #expect(keys(timeline) == ["0↓", "0↓r", "0↓r", "0↓r", "0↑"])
    }

    @Test func shiftedCharactersAndNamedKeysMap() throws {
        let timeline = try script(#"{"steps":[{"text":"A!"},{"key":"backspace"},{"key":"left"}]}"#).timeline()
        #expect(keys(timeline) == ["0↓+shift", "0↑+shift", "18↓+shift", "18↑+shift", "51↓", "51↑", "123↓", "123↑"])
    }

    @Test func capsLockUppercasesTypedLetters() throws {
        let timeline = try script(#"{"steps":[{"capsLock":true},{"text":"a"},{"capsLock":false}]}"#).timeline()
        let typed = timeline.compactMap { event -> String? in
            if case .key(_, true, _, let text, _, let caps) = event.kind { return "\(text ?? "")\(caps)" }
            return nil
        }
        #expect(typed == ["Atrue"])
        #expect(keys(timeline).first == "capsOn" && keys(timeline).last == "capsOff")
    }

    @Test func seededJitterIsReproducibleAndSeedSensitive() throws {
        let json = #"{"seed":%d,"steps":[{"text":"as as as","jitter":20}]}"#
        let first = try script(String(format: json, 7)).timeline().map(\.offset)
        let again = try script(String(format: json, 7)).timeline().map(\.offset)
        let other = try script(String(format: json, 8)).timeline().map(\.offset)
        #expect(first == again)
        #expect(first != other)
    }

    @Test func shorthandPausesAtBars() throws {
        let timeline = try DriverScript.shorthand(" a|s", interval: 120, hold: 60, pause: 1200).timeline()
        #expect(keys(timeline) == ["49↓", "49↑", "0↓", "0↑", "1↓", "1↑"])
        let sDown = timeline[4].offset, aUp = timeline[3].offset
        #expect(sDown - aUp >= 1200)
    }

    @Test func checkpointsFollowTheirSettleTime() throws {
        let timeline = try script(#"{"steps":[{"text":"a"},{"checkpoint":"after-a","settle":300}]}"#).timeline()
        #expect(keys(timeline) == ["0↓", "0↑", "#after-a"])
        #expect(timeline[2].offset >= timeline[1].offset + 300)
    }

    @Test func unsupportedInputIsRejectedBeforeAnyEvent() {
        #expect(throws: ScriptError.unsupportedCharacter("á")) { try script(#"{"steps":[{"text":"á"}]}"#) }
        #expect(throws: ScriptError.unsupportedKey("f13")) { try script(#"{"steps":[{"key":"f13"}]}"#) }
        #expect(throws: ScriptError.unsupportedStep(index: 0, detail: "bogus")) { try script(#"{"steps":[{"bogus":1}]}"#) }
        #expect(throws: ScriptError.self) { try script(#"{"steps":[{"key":"a","modifiers":["hyper"]}]}"#) }
        #expect(throws: ScriptError.self) { try script(#"{"steps":[]}"#) }
    }

    @Test func protectedTargetsRefuseSubmissionKeys() throws {
        #expect(throws: ScriptError.protectedSubmission("return")) {
            try script(#"{"protected":true,"steps":[{"key":"return"}]}"#)
        }
        #expect(throws: ScriptError.protectedSubmission("Enter")) {
            try script(#"{"protected":true,"steps":[{"key":"Enter","modifiers":["command"]}]}"#)
        }
        #expect(throws: ScriptError.protectedSubmission("newline")) {
            try script(#"{"protected":true,"steps":[{"text":"a\nb"}]}"#)
        }
        _ = try script(#"{"protected":false,"steps":[{"key":"return"}]}"#)
    }
}
