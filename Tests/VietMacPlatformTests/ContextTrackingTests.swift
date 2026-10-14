import Testing
import VietMacCore
@testable import VietMacPlatform

private func activePipeline() -> PrototypePipeline {
    var model = PrototypePipeline(environment: InputEnvironment(permissions:
        PermissionSnapshot(accessibility: true, eventListening: true, eventPosting: true)))
    model.setEnabled(true)
    return model
}

private let a = PrototypeInput.letter(97, keyCode: 0, isRepeat: false)
private let s = PrototypeInput.letter(115, keyCode: 1, isRepeat: false)

/// Drives the host's context decisions with synthetic field metadata.
private struct Session {
    var pipeline = activePipeline()
    var field = FieldContextTracker()
    var counters = ContextCounters()

    mutating func observe(caret: Int, length: Int, focusChanged: Bool = false) {
        observe(.caret(FieldSnapshot(caret: caret, length: length)), focusChanged: focusChanged)
    }

    mutating func observe(_ reading: FieldReading, focusChanged: Bool = false) {
        _ = ContextPolicy.observe(focusChanged: focusChanged, reading: reading, field: &field,
                                  pipeline: &pipeline, counters: &counters)
    }

    /// Returns the replacement the host would send, or nil when the key stays literal.
    mutating func key(_ input: PrototypeInput, keyCode: Int64 = 0) -> String? {
        let before = pipeline.word
        switch pipeline.handle(input) {
        case .passThrough, .consume:
            ContextPolicy.expectPassThrough(input, keyCode: keyCode, previous: before, field: &field,
                                            pipeline: &pipeline, counters: &counters)
            return nil
        case .replace(let edit):
            guard ContextPolicy.admitsReplacement(field: field, pipeline: &pipeline, counters: &counters) else {
                ContextPolicy.expectPassThrough(input, keyCode: keyCode, previous: before, field: &field,
                                                pipeline: &pipeline, counters: &counters)
                return nil
            }
            guard let plan = try? ReplacementPlan.compute(previous: before, next: edit.next),
                  pipeline.accept(edit) else { return nil }
            ContextPolicy.expectReplacement(previous: before, plan: plan, field: &field,
                                            pipeline: &pipeline, counters: &counters)
            return edit.next
        }
    }
}

struct FieldContextTrackerTests {
    @Test func laggingObservationsSettleOnlyAfterEveryPredictedEffect() {
        var field = FieldContextTracker()
        #expect(field.observe(FieldSnapshot(caret: 5, length: 11)) == .consistent)
        #expect(field.isSettled)
        let predicted = [field.expect(deleting: 0, inserting: 1), // a
                         field.expect(deleting: 1, inserting: 0), // generated Backspace
                         field.expect(deleting: 0, inserting: 1)] // generated á
        #expect(predicted == [true, true, true])
        #expect(!field.isSettled)
        #expect(field.observe(FieldSnapshot(caret: 5, length: 11)) == .lagging) // Nothing applied yet.
        #expect(field.observe(FieldSnapshot(caret: 6, length: 12)) == .lagging) // Earliest match: a only.
        #expect(field.pendingCount == 2)
        #expect(field.observe(FieldSnapshot(caret: 5, length: 11)) == .lagging) // Generated Backspace.
        #expect(!field.isSettled)
        #expect(field.observe(FieldSnapshot(caret: 6, length: 12)) == .consistent)
        #expect(field.isSettled)
    }

    @Test func revisitedFinalStateStaysUnsettledUntilAnUnambiguousObservation() {
        var field = FieldContextTracker()
        _ = field.observe(FieldSnapshot(caret: 6, length: 12))
        field.expect(deleting: 1, inserting: 0)
        field.expect(deleting: 0, inserting: 1) // Net-zero a -> á.
        #expect(field.observe(FieldSnapshot(caret: 6, length: 12)) == .lagging)
        #expect(field.observe(FieldSnapshot(caret: 6, length: 12)) == .lagging) // Repetition proves nothing.
        #expect(!field.isSettled)
        field.expect(deleting: 0, inserting: 1) // The next key creates a unique state.
        #expect(field.observe(FieldSnapshot(caret: 7, length: 13)) == .consistent)
        #expect(field.isSettled)
    }

    @Test func sameCaretLengthChangeAndSameLengthCaretMoveAreMismatches() {
        var field = FieldContextTracker()
        _ = field.observe(FieldSnapshot(caret: 5, length: 11))
        field.expect(deleting: 0, inserting: 1)
        // A script inserts after the caret: the caret matches the prediction, the length does not.
        #expect(field.observe(FieldSnapshot(caret: 6, length: 17)) == .mismatch)
        #expect(field.baseline == FieldSnapshot(caret: 6, length: 17))
        #expect(field.isSettled) // Future keys start from the observed state; the caller drops the word.
        // A programmatic caret move keeps the length.
        #expect(field.observe(FieldSnapshot(caret: 2, length: 17)) == .mismatch)
    }

    @Test func sameCaretSameLengthEditRemainsUndetectable() {
        // Documented limit: metadata cannot distinguish replaced characters of equal width.
        var field = FieldContextTracker()
        _ = field.observe(FieldSnapshot(caret: 5, length: 11))
        field.expect(deleting: 0, inserting: 1)
        #expect(field.observe(FieldSnapshot(caret: 6, length: 12)) == .consistent)
    }

    @Test func unavailableMetadataAndBoundsClearTheBaseline() {
        var field = FieldContextTracker()
        #expect(field.expect(deleting: 0, inserting: 1) == false) // No baseline to predict from.
        _ = field.observe(FieldSnapshot(caret: 0, length: 0))
        #expect(field.expect(deleting: 1, inserting: 0) == false) // Backspace before position 0.
        #expect(field.baseline == nil)
        _ = field.observe(FieldSnapshot(caret: 0, length: 0))
        for _ in 0..<FieldContextTracker.capacity {
            let accepted = field.expect(deleting: 0, inserting: 1)
            #expect(accepted)
        }
        #expect(field.expect(deleting: 0, inserting: 1) == false)
        #expect(!field.isSettled)
        _ = field.observe(FieldSnapshot(caret: 3, length: 3))
        #expect(field.observe(nil) == .unavailable)
        #expect(field.baseline == nil)
    }
}

struct ContextPolicyTests {
    @Test func observedTypingAllowsReplacement() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        #expect(session.key(a) == nil)
        session.observe(caret: 6, length: 12)
        #expect(session.key(s) == "á")
        #expect(session.counters.replacementsPosted == 1)
        session.observe(caret: 5, length: 11) // Generated Backspace observed.
        session.observe(caret: 6, length: 12) // Generated á observed.
        #expect(session.counters.unexplainedFieldChanges == 0)
        #expect(session.field.isSettled)
    }

    @Test func unobservedTrackedKeyKeepsTheTriggerLiteral() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(a)
        // No observation after a: its arrival in the field is unproven.
        #expect(session.key(s) == nil)
        #expect(session.counters.unsettledTriggers == 1)
        #expect(session.pipeline.word.isEmpty)
        session.observe(caret: 7, length: 13) // a and literal s both arrive.
        #expect(session.counters.unexplainedFieldChanges == 0)
        _ = session.key(a)
        session.observe(caret: 8, length: 14)
        #expect(session.key(s) == nil) // Stays literal until a word boundary.
    }

    @Test func sameCaretExternalEditInvalidatesTheTrackedWord() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(a)
        session.observe(caret: 6, length: 12)
        // The synthetic page replaces its content and restores the same caret.
        session.observe(caret: 6, length: 16)
        #expect(session.counters.unexplainedFieldChanges == 1)
        #expect(session.key(s) == nil)
        #expect(session.pipeline.word.isEmpty)
    }

    @Test func externalEditDuringLagIsDetected() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(a)
        session.observe(caret: 5, length: 20) // Script edit observed before a.
        #expect(session.counters.unexplainedFieldChanges == 1)
        #expect(session.key(s) == nil)
    }

    @Test func sameAppFieldSwitchInvalidatesEvenAtAMatchingCaret() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(a)
        // Focus moves to another field whose metadata happens to match the prediction.
        session.observe(caret: 6, length: 12, focusChanged: true)
        #expect(session.counters.focusChanges == 1)
        #expect(session.key(s) == nil)
        #expect(session.pipeline.word.isEmpty)
    }

    @Test func selectionOrSuggestionPreventsSuffixDeletion() {
        var session = Session()
        session.observe(caret: 0, length: 0)
        _ = session.key(a)
        // Inline autocomplete selects a suggested completion after a.
        session.observe(.selection)
        #expect(session.counters.selectionsObserved == 1)
        #expect(!session.field.isSettled)
        #expect(session.key(s) == nil)
        session.observe(.unavailable(.noCharacterCount))
        #expect(session.counters.fieldUnavailable == 1)
    }

    @Test func returnTabAndNavigationRequireAFreshObservation() {
        for (input, code) in [(PrototypeInput.boundary, Int64(36)), (.boundary, 48), (.invalidate, 123)] {
            var session = Session()
            session.observe(caret: 5, length: 11)
            _ = session.key(input, keyCode: code)
            #expect(session.field.baseline == nil)
            _ = session.key(a)
            #expect(session.key(s) == nil)
        }
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(.boundary, keyCode: 49) // Space inserts one unit.
        _ = session.key(a)
        session.observe(caret: 7, length: 13)
        #expect(session.key(s) == "á")
    }

    @Test func backspaceUsesTrackedWidthAndUnknownDeletionResets() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        _ = session.key(a)
        _ = session.key(.backspace)
        session.observe(caret: 5, length: 11)
        #expect(!session.field.isSettled) // Returning to the baseline is ambiguous.
        #expect(session.field.pendingCount == 2)
        _ = session.key(.backspace) // Deletes an untracked character of unknown width.
        #expect(session.field.baseline == nil)
    }

    @Test func pausedStateDoesNotPredictFieldEffects() {
        var session = Session()
        session.observe(caret: 5, length: 11)
        session.pipeline.pauseFor(.secureInput)
        _ = session.key(a)
        #expect(session.field.baseline == nil)
    }

    /// Session 5 text area: space, `a`, settled, then `s` replaced `a`.
    private func replacedInTextArea() -> Session {
        var session = Session()
        session.observe(caret: 11, length: 11)
        _ = session.key(.boundary, keyCode: 49)
        _ = session.key(a)
        session.observe(caret: 13, length: 13)
        #expect(session.key(s) == "á")
        #expect(session.field.replacementUnconfirmed)
        return session
    }

    private func check(_ session: inout Session, caret: Int, length: Int, quietMilliseconds: UInt64) -> Bool {
        let snapshot = FieldSnapshot(caret: caret, length: length)
        let result = session.field.observe(snapshot)
        return ContextPolicy.checkReplacementDelivery(result: result, reading: .caret(snapshot),
                                                      quietNanoseconds: quietMilliseconds * 1_000_000,
                                                      field: &session.field, pipeline: &session.pipeline,
                                                      counters: &session.counters)
    }

    @Test func deliveredReplacementIsConfirmedOnlyOnceInputIsQuiet() {
        var session = replacedInTextArea()
        // `a` -> `á` keeps the length, so the delivered state equals the pre-replacement state.
        #expect(!check(&session, caret: 13, length: 13, quietMilliseconds: 100))
        #expect(session.field.replacementUnconfirmed)
        #expect(!session.field.isSettled)
        #expect(!check(&session, caret: 13, length: 13, quietMilliseconds: 600))
        #expect(session.field.isSettled)
        #expect(!session.field.replacementUnconfirmed)
        #expect(session.pipeline.state == .active)
        #expect(session.counters.replacementsUnconfirmed == 0)
    }

    @Test func droppedInsertionPausesAfterInputGoesQuiet() {
        var session = replacedInTextArea()
        // Deletion landed, insertion did not: the field stays one unit short.
        #expect(!check(&session, caret: 12, length: 12, quietMilliseconds: 100))
        #expect(session.pipeline.state == .active)
        #expect(check(&session, caret: 12, length: 12, quietMilliseconds: 600))
        #expect(session.pipeline.state == .paused(.transportUncertain))
        #expect(session.counters.replacementsUnconfirmed == 1)
        #expect(session.field.baseline == nil)
    }

    @Test func droppedInsertionHiddenByLaterKeyStillPauses() {
        var session = replacedInTextArea()
        _ = session.key(.boundary, keyCode: 49) // The next space can match the missing insertion's length.
        #expect(session.field.observe(FieldSnapshot(caret: 13, length: 13)) == .lagging)
        #expect(check(&session, caret: 13, length: 13, quietMilliseconds: 600))
        #expect(session.pipeline.state == .paused(.transportUncertain))
    }
}

struct ObservationTraceTests {
    @Test func ringKeepsTheNewestRecordsInOrderWithoutText() {
        var trace = ObservationTrace()
        let field = FieldContextTracker()
        for index in 0..<(ObservationTrace.capacity + 3) {
            let inspection = FocusInspection(changed: index == 0,
                field: .caret(FieldSnapshot(caret: index, length: index)), role: "AXTextField", elementHash: 7)
            trace.append(source: "poll", inspection: inspection, result: .consistent, keysSincePrevious: 1, field: field)
        }
        let records = trace.ordered
        #expect(records.count == ObservationTrace.capacity)
        #expect(records.first?.sequence == 4)
        #expect(records.last?.sequence == UInt64(ObservationTrace.capacity + 3))
        #expect(records.last?.caret == ObservationTrace.capacity + 2)
        trace.append(source: "notification", inspection: FocusInspection(changed: false,
            field: .unavailable(.noCharacterCount)), result: .unavailable, keysSincePrevious: 0, field: field)
        #expect(trace.ordered.last?.reading == "unavailable:noCharacterCount")
    }
}
