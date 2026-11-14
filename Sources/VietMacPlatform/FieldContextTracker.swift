/// Field metadata in UTF-16 units. It never contains document text.
public struct FieldSnapshot: Equatable, Sendable {
    public let caret: Int
    public let length: Int

    public init(caret: Int, length: Int) {
        self.caret = caret
        self.length = length
    }
}

public enum FieldObservation: Equatable, Sendable {
    /// The observation matches every predicted key effect.
    case consistent
    /// The observation matches an earlier prediction; later keys are still in flight.
    case lagging
    /// The field changed in a way the tracked keys do not explain, confirmed by a second observation.
    case mismatch
    /// One observation disagrees with every prediction. WebKit can report a stale caret for one
    /// notification (for example caret 42 with length 44, then 44/44). Nothing is deleted until the
    /// next observation confirms or clears it.
    case suspect
    /// No caret/length is available, or a selection is active.
    case unavailable
}

/// Predicts caret and length from tracked keys and checks them against observations.
/// An observation proves only metadata consistency at its own time. A same-length,
/// same-caret external edit, or a change after the last observation, stays undetected.
public struct FieldContextTracker {
    public static let capacity = 80
    public private(set) var baseline: FieldSnapshot?
    /// A posted replacement whose insertion no observation has settled yet.
    public private(set) var replacementUnconfirmed = false
    /// Every unsettled prediction comes from posted replacements, with no physical key after them.
    /// Generated events are posted into the event stream right after their trigger, so the client
    /// applies them before any later physical key.
    public private(set) var unsettledByReplacementOnly = false
    private var pending: [FieldSnapshot] = []
    /// An unexplained observation waiting for confirmation.
    public private(set) var suspect: FieldSnapshot?

    public init() {
        pending.reserveCapacity(Self.capacity)
    }

    /// True only when an observation after every tracked key matched its prediction.
    public var isSettled: Bool { baseline != nil && pending.isEmpty && suspect == nil }
    public var pendingCount: Int { pending.count }
    var predicted: FieldSnapshot? { pending.last ?? baseline }

    public mutating func reset() {
        baseline = nil
        suspect = nil
        replacementUnconfirmed = false
        unsettledByReplacementOnly = false
        pending.removeAll(keepingCapacity: true)
    }

    /// Resolves the revisited-state ambiguity once input is quiet: generated events land within
    /// milliseconds, so a quiet field at the final prediction means every effect arrived.
    @discardableResult
    public mutating func settleIfFinal(_ snapshot: FieldSnapshot) -> Bool {
        guard !pending.isEmpty, snapshot == pending.last else { return false }
        baseline = snapshot
        pending.removeAll(keepingCapacity: true)
        replacementUnconfirmed = false
        unsettledByReplacementOnly = false
        return true
    }

    /// Call after predicting a posted replacement. A settled observation confirms it.
    public mutating func markReplacement() {
        replacementUnconfirmed = baseline != nil
        unsettledByReplacementOnly = baseline != nil
    }

    public mutating func observe(_ snapshot: FieldSnapshot?) -> FieldObservation {
        guard let snapshot else {
            reset()
            return .unavailable
        }
        guard predicted != nil else {
            baseline = snapshot
            return .consistent
        }
        let wasSuspect = suspect != nil
        suspect = nil
        // A revisited state (for example `a` -> `á`, or a letter and Backspace) is ambiguous.
        // Assume the earliest matching state; settle only on an unambiguous final match.
        if snapshot == baseline { return pending.isEmpty ? .consistent : .lagging }
        if let index = pending.firstIndex(of: snapshot) {
            baseline = snapshot
            pending.removeFirst(index + 1)
            if pending.isEmpty {
                replacementUnconfirmed = false
                unsettledByReplacementOnly = false
            }
            return pending.isEmpty ? .consistent : .lagging
        }
        // A first unexplained observation is held; a second one confirms the change.
        guard wasSuspect else {
            suspect = snapshot
            return .suspect
        }
        // The new state becomes the baseline; the caller invalidates the tracked word.
        reset()
        baseline = snapshot
        return .mismatch
    }

    /// Records the expected effect of one key or generated event. Returns false and
    /// clears the baseline when the effect cannot be predicted within bounds.
    @discardableResult
    public mutating func expect(deleting: Int, inserting: Int) -> Bool {
        guard let current = predicted, pending.count < Self.capacity,
              deleting >= 0, inserting >= 0, current.caret >= deleting, current.length >= deleting,
              current.length - deleting <= Int.max - inserting else {
            reset()
            return false
        }
        pending.append(FieldSnapshot(caret: current.caret - deleting + inserting,
                                     length: current.length - deleting + inserting))
        // A physical key ends the replacement-only window; `markReplacement` reopens it after a replacement.
        unsettledByReplacementOnly = false
        return true
    }
}
