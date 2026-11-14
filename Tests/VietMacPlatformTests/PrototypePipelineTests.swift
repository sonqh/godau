import Testing
import VietMacCore
@testable import VietMacPlatform

private func activePipeline() -> PrototypePipeline {
    var model = PrototypePipeline(environment: InputEnvironment(permissions:
        PermissionSnapshot(accessibility: true, eventListening: true, eventPosting: true)))
    model.setEnabled(true)
    return model
}

struct PrototypePipelineTests {
    @Test func transformsExamplesWithActualBaseCaseAndOwnsRelease() {
        for (first, second, expected) in [(UInt8(97), UInt8(115), "á"), (65, 115, "Á"),
                                           (97, 83, "á"), (97, 97, "â"), (65, 97, "Â")] {
            var model = activePipeline()
            #expect(model.handle(.letter(first, keyCode: 0, isRepeat: false)) == .passThrough)
            #expect(model.handle(.keyUp(0)) == .passThrough)
            guard case .replace(let edit) = model.handle(.letter(second, keyCode: 1, isRepeat: false)) else {
                Issue.record("Expected M0 replacement")
                continue
            }
            #expect(model.word == String(UnicodeScalar(first))) // Candidate not yet accepted.
            #expect(edit.next == expected)
            #expect(model.accept(edit) == true)
            #expect(model.word == expected)
            #expect(model.handle(.keyUp(1)) == .consume)
            #expect(model.handle(.keyUp(1)) == .passThrough)
        }
    }

    /// Session 6 rollover: `s` triggered while the physical `a` was still down.
    @Test func rolloverReleasesTheHeldKeyAndOwnsOnlyTheTrigger() {
        var model = activePipeline()
        #expect(model.handle(.letter(97, keyCode: 0, isRepeat: false)) == .passThrough)
        guard case .replace(let edit) = model.handle(.letter(115, keyCode: 1, isRepeat: false)) else {
            Issue.record("Expected replacement while A is still down")
            return
        }
        #expect(edit.keyCode == 1) // The transport inserts with this key, not the held A.
        let accepted = model.accept(edit)
        #expect(accepted)
        #expect(model.handle(.keyUp(0)) == .passThrough) // The client saw A go down, so it must see A go up.
        #expect(model.handle(.keyUp(1)) == .consume)
        #expect(model.word == "á")
    }

    @Test func consumedRepeatAndReleaseSurviveContextLoss() {
        var model = activePipeline()
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        guard case .replace(let edit) = model.handle(.letter(115, keyCode: 1, isRepeat: false)) else {
            Issue.record("Expected replacement")
            return
        }
        #expect(model.accept(edit) == true)
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: true)) == .consume)
        model.setEnabled(false)
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: true)) == .consume)
        #expect(model.handle(.keyUp(1)) == .consume)
        #expect(model.word.isEmpty)
    }

    @Test func aNewPressClearsStaleOwnershipEvenWhilePaused() {
        var model = activePipeline()
        model.consumeAfterUncertainSend(1)
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: true)) == .consume)
        // A release may have occurred while the tap was unavailable. A new press
        // is not the old consumed gesture, so its down and up both pass through.
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: false)) == .passThrough)
        #expect(model.handle(.keyUp(1)) == .passThrough)
        model.consumeAfterUncertainSend(0)
        #expect(model.beginPhysicalPress(0, isRepeat: false) == false)
        _ = model.handle(.invalidate) // A new Command-A chord, not a text letter.
        #expect(model.handle(.keyUp(0)) == .passThrough)
    }

    @Test func ordinaryRepeatPassesOnceAndDoesNotApplyDoubleARule() {
        var model = activePipeline()
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        #expect(model.handle(.letter(97, keyCode: 0, isRepeat: true)) == .passThrough)
        #expect(model.word == "aa")
        #expect(model.handle(.keyUp(0)) == .passThrough)
    }

    @Test func staleCandidateCannotCommitOrEditAnOldField() {
        var model = activePipeline()
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        guard case .replace(let edit) = model.handle(.letter(115, keyCode: 1, isRepeat: false)) else {
            Issue.record("Expected replacement")
            return
        }
        model.invalidate()
        #expect(!model.isCurrent(edit))
        #expect(model.accept(edit) == false)
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: false)) == .passThrough)
        #expect(model.word.isEmpty)
        _ = model.handle(.boundary)
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        if case .replace = model.handle(.letter(115, keyCode: 1, isRepeat: false)) {} else {
            Issue.record("Boundary must permit fresh composition")
        }
    }

    @Test func capabilityAndSecureInputChangesInvalidateComposition() {
        for reason in [PauseReason.accessibility, .listening, .posting, .secureInput, .unsupportedApp,
                       .unsupportedSource, .uncertainContext] {
            var model = activePipeline()
            _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
            var environment = model.environment
            switch reason {
            case .accessibility: environment.permissions = .init(accessibility: false, eventListening: true, eventPosting: true)
            case .listening: environment.permissions = .init(accessibility: true, eventListening: false, eventPosting: true)
            case .posting: environment.permissions = .init(accessibility: true, eventListening: true, eventPosting: false)
            case .secureInput: environment.secureInput = true
            case .unsupportedApp: environment.supportedApp = false
            case .unsupportedSource: environment.supportedSource = false
            case .uncertainContext: environment.certainContext = false
            default: break
            }
            model.updateEnvironment(environment)
            #expect(model.state == .paused(reason))
            #expect(model.word.isEmpty)
            #expect(model.handle(.letter(115, keyCode: 1, isRepeat: false)) == .passThrough)
        }
    }

    @Test func timeoutRecoveryIsBoundedAndExplicitResumeStartsFresh() {
        var model = activePipeline()
        for time in UInt64(1)...3 { #expect(model.timeout(at: time) == true) }
        #expect(model.timeout(at: 4) == false)
        #expect(model.state == .paused(.recoveryLimit))
        #expect(model.timeout(at: 70_000_000_000) == false) // Override requires explicit resume.
        model.setEnabled(true)
        #expect(model.state == .active)
        #expect(model.word.isEmpty)
        #expect(model.timeout(at: 70_000_000_000) == true)
        #expect(model.timeout(at: 131_000_000_000) == true) // Earlier recovery expired.
    }

    @Test func disabledUserTapDoesNotAutomaticallyRecover() {
        var model = activePipeline()
        model.pauseFor(.userDisabledTap)
        #expect(model.timeout(at: 1) == false)
        #expect(model.state == .paused(.userDisabledTap))
        model.setEnabled(true)
        #expect(model.state == .active)
    }

    @Test func overflowAndUnownedBackspaceStayLiteralUntilBoundary() {
        var model = activePipeline()
        for _ in 0..<64 { _ = model.handle(.letter(98, keyCode: 11, isRepeat: false)) }
        #expect(model.word.count == 64)
        #expect(model.handle(.letter(97, keyCode: 0, isRepeat: false)) == .passThrough)
        #expect(model.literalUntilBoundary)
        #expect(model.word.isEmpty)
        _ = model.handle(.backspace)
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        #expect(model.handle(.letter(115, keyCode: 1, isRepeat: false)) == .passThrough)
        #expect(model.word.isEmpty)
        _ = model.handle(.boundary)
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        #expect(model.word == "a")
    }

    @Test func backspaceDeletesVisibleLetterAndNotEarlierHistory() {
        var model = activePipeline()
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        guard case .replace(let edit) = model.handle(.letter(115, keyCode: 1, isRepeat: false)) else {
            Issue.record("Expected replacement")
            return
        }
        _ = model.accept(edit)
        _ = model.handle(.backspace)
        #expect(model.word.isEmpty)
        _ = model.handle(.letter(98, keyCode: 11, isRepeat: false))
        #expect(model.word == "b")
        _ = model.handle(.boundary)
        _ = model.handle(.backspace)
        _ = model.handle(.letter(97, keyCode: 0, isRepeat: false))
        #expect(model.word.isEmpty)
    }

    @Test func malformedInputAndIndependentInstancesAreSafe() {
        var first = activePipeline()
        var second = activePipeline()
        _ = first.handle(.letter(97, keyCode: 0, isRepeat: false))
        #expect(second.handle(.letter(115, keyCode: 1, isRepeat: false)) == .passThrough)
        #expect(first.word == "a")
        #expect(second.word == "s")
        #expect(first.handle(.letter(255, keyCode: 65535, isRepeat: false)) == .passThrough)
        #expect(first.word.isEmpty)
        #expect(first.handle(.keyUp(65535)) == .passThrough)
    }
}

struct TelexPipelineTests {
    private func active() -> PrototypePipeline {
        var model = PrototypePipeline(environment: InputEnvironment(permissions: PermissionSnapshot(
            accessibility: true, eventListening: true, eventPosting: true)))
        model.setEnabled(true)
        return model
    }

    /// Types keys, accepting every replacement, and returns the tracked word.
    private func type(_ keys: String, into model: inout PrototypePipeline) -> [PrototypeAction] {
        var actions: [PrototypeAction] = []
        for (index, scalar) in keys.unicodeScalars.enumerated() {
            let code = UInt16(index % 100)
            let action = scalar == " " ? model.handle(.boundary)
                : scalar == "<" ? model.handle(.backspace)
                : model.handle(.letter(UInt8(scalar.value), keyCode: code, isRepeat: false))
            if case .replace(let edit) = action {
                let accepted = model.accept(edit)
                #expect(accepted)
            }
            if scalar != " " && scalar != "<" { _ = model.handle(.keyUp(code)) }
            actions.append(action)
        }
        return actions
    }

    @Test func composesTiengVietThroughReplacements() {
        var model = active()
        let actions = type("tieengs", into: &model)
        #expect(model.word == "tiếng")
        #expect(actions.filter { if case .replace = $0 { true } else { false } }.count == 2)
        _ = type(" Vieetj", into: &model)
        #expect(model.word == "Việt")
    }

    @Test func replacementCarriesWholeWordForPlanner() {
        var model = active()
        _ = type("hoaf", into: &model)
        guard case .replace(let edit) = model.handle(.letter(110, keyCode: 90, isRepeat: false)) else {
            // `n` is a plain append for the field, but the tone moves, so it must be a replacement.
            Issue.record("expected a replacement for the moving tone")
            return
        }
        #expect(edit.previous == "hòa" && edit.next == "hoàn")
    }

    @Test func backspaceEditsVisibleLetters() {
        var model = active()
        _ = type("tieengs<", into: &model)
        #expect(model.word == "tiến")
        _ = type("f", into: &model)
        #expect(model.word == "tiền")
    }

    /// `hoàn` + Backspace: the field shows `hoà`; the tone cannot move without a Backspace-triggered
    /// replacement (U-5), so the word stops being tracked until a boundary.
    @Test func backspaceThatWouldMoveTheToneEndsOwnership() {
        var model = active()
        _ = type("hoafn<", into: &model)
        #expect(model.word.isEmpty)
        #expect(model.literalUntilBoundary)
    }

    @Test func staleReplacementDoesNotCommitComposerState() {
        var model = active()
        _ = type("a", into: &model)
        guard case .replace(let edit) = model.handle(.letter(115, keyCode: 1, isRepeat: false)) else {
            Issue.record("expected a replacement")
            return
        }
        model.invalidate()
        let accepted = model.accept(edit)
        #expect(!accepted)
        #expect(model.word.isEmpty)
    }
}

/// Deterministic randomized ownership checks (telex-input-mvp task 2.6). An independent buffer applies
/// exactly what the field would receive: passed-through keys and replacement plans. The buffer must
/// always end with the tracked word, stay NFC, and stay bounded.
struct RandomizedOwnershipTests {
    /// SplitMix64, so a failing seed reproduces.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private static let keys: [UInt8] = Array("aeiouydwsfrxjzqgthnmcbAEOWDS".utf8)

    @Test(arguments: Array(UInt64(1)...20) + [42, 1_234, 99_991, 31_337, 2_026_111_4])
    func bufferAlwaysEndsWithTheTrackedWord(seed: UInt64) throws {
        var random = Generator(state: seed)
        var model = PrototypePipeline(environment: InputEnvironment(permissions: PermissionSnapshot(
            accessibility: true, eventListening: true, eventPosting: true)))
        model.setEnabled(true)
        var buffer: [Character] = []
        var history: [String] = []
        var reported = false
        for step in 0..<4_000 {
            let roll = Int.random(in: 0..<100, using: &random)
            let code = UInt16(step % 120)
            if roll < 8 {
                _ = model.handle(.boundary)
                history.append("␣")
                buffer.append(" ")
            } else if roll < 14 {
                _ = model.handle(.backspace)
                history.append("⌫")
                if !buffer.isEmpty { buffer.removeLast() }
            } else if roll < 15 {
                _ = model.handle(.invalidate)
            } else {
                let byte = Self.keys.randomElement(using: &random)!
                history.append(String(UnicodeScalar(byte)))
                switch model.handle(.letter(byte, keyCode: code, isRepeat: false)) {
                case .passThrough:
                    buffer.append(Character(UnicodeScalar(byte)))
                case .consume:
                    break
                case .replace(let edit):
                    let plan = try ReplacementPlan.compute(previous: edit.previous, next: edit.next)
                    let accepted = model.accept(edit)
                    #expect(accepted, "seed \(seed) step \(step)")
                    #expect(buffer.count >= plan.deleteCount, "seed \(seed) step \(step)")
                    buffer.removeLast(plan.deleteCount)
                    buffer.append(contentsOf: plan.insertion)
                }
                _ = model.handle(.keyUp(code))
            }
            let word = model.word
            let text = String(buffer)
            if !text.hasSuffix(word) && !reported {
                reported = true
                Issue.record("seed \(seed) step \(step): keys \(history.suffix(14).joined()) buffer …\(String(text.suffix(12))) word \(word)")
            }
            #expect(word.count <= 64)
            #expect(word.unicodeScalars.elementsEqual(word.precomposedStringWithCanonicalMapping.unicodeScalars))
            if buffer.count > 400 { buffer.removeFirst(buffer.count - 200) }
        }
    }
}
