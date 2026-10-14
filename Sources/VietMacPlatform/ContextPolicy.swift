import VietMacCore

/// Context decisions shared by the host and focused tests. The host owns every
/// argument on its run loop; this type adds no state and performs no AX or I/O.
enum ContextPolicy {
    /// Applies one field observation. Returns whether a collapsed caret is known and the comparison result.
    @discardableResult
    static func observe(focusChanged: Bool, reading: FieldReading, field: inout FieldContextTracker,
                        pipeline: inout PrototypePipeline,
                        counters: inout ContextCounters) -> (certain: Bool, result: FieldObservation) {
        if focusChanged {
            // An unchanged application identity is not proof of field ownership.
            counters.focusChanges &+= 1
            invalidate(field: &field, pipeline: &pipeline)
        }
        switch reading {
        case .caret(let snapshot):
            let result = field.observe(snapshot)
            switch result {
            case .consistent, .unavailable: break
            case .lagging: counters.laggingObservations &+= 1
            case .mismatch:
                counters.unexplainedFieldChanges &+= 1
                pipeline.invalidate()
            }
            return (true, result)
        case .selection:
            counters.selectionsObserved &+= 1
            invalidate(field: &field, pipeline: &pipeline)
            return (false, .unavailable)
        case .unavailable:
            counters.fieldUnavailable &+= 1
            invalidate(field: &field, pipeline: &pipeline)
            return (false, .unavailable)
        }
    }

    static func invalidate(field: inout FieldContextTracker, pipeline: inout PrototypePipeline) {
        pipeline.invalidate()
        field.reset()
    }

    /// Replacement needs an observation after every tracked key; otherwise the trigger stays literal.
    static func admitsReplacement(field: FieldContextTracker, pipeline: inout PrototypePipeline,
                                  counters: inout ContextCounters) -> Bool {
        guard field.isSettled else {
            counters.unsettledTriggers &+= 1
            pipeline.invalidate()
            return false
        }
        return true
    }

    /// Predicts the field effect of a physical key that reaches the application.
    static func expectPassThrough(_ input: PrototypeInput, keyCode: Int64, previous: String,
                                  field: inout FieldContextTracker, pipeline: inout PrototypePipeline,
                                  counters: inout ContextCounters) {
        guard pipeline.state == .active else {
            field.reset()
            return
        }
        switch input {
        case .letter:
            expect(deleting: 0, inserting: 1, field: &field, pipeline: &pipeline, counters: &counters)
        case .backspace:
            // Only a tracked character has a known UTF-16 width.
            if let deleted = previous.last {
                expect(deleting: deleted.utf16.count, inserting: 0, field: &field, pipeline: &pipeline,
                       counters: &counters)
            } else {
                field.reset()
            }
        case .boundary:
            // Return, Tab, and Enter can submit, move focus, or insert; printable boundaries insert one unit.
            if [36, 48, 76].contains(keyCode) { field.reset() }
            else { expect(deleting: 0, inserting: 1, field: &field, pipeline: &pipeline, counters: &counters) }
        case .invalidate:
            field.reset()
        case .keyUp:
            break
        }
    }

    /// Predicts each generated Backspace, then the Unicode insertion, in posting order.
    static func expectReplacement(previous: String, plan: ReplacementPlan, field: inout FieldContextTracker,
                                  pipeline: inout PrototypePipeline, counters: inout ContextCounters) {
        counters.replacementsPosted &+= 1
        for character in previous.suffix(plan.deleteCount).reversed() {
            expect(deleting: character.utf16.count, inserting: 0, field: &field, pipeline: &pipeline,
                   counters: &counters)
        }
        expect(deleting: 0, inserting: plan.insertion.utf16.count, field: &field, pipeline: &pipeline,
               counters: &counters)
    }

    private static func expect(deleting: Int, inserting: Int, field: inout FieldContextTracker,
                               pipeline: inout PrototypePipeline, counters: inout ContextCounters) {
        guard field.baseline != nil else { return }
        if !field.expect(deleting: deleting, inserting: inserting) {
            counters.unpredictableKeys &+= 1
            pipeline.invalidate()
        }
    }
}
