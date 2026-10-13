import Testing
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
