import Foundation

public enum ReplacementError: Error, Equatable {
    case invalidLimit
    case wordLimitExceeded
    case nonCanonicalText
}

/// An edit of the tracked suffix. Deletion counts graphemes, not UTF-16 units.
public struct ReplacementPlan: Equatable, Sendable {
    public let deleteCount: Int
    public let insertion: String

    public var isEmpty: Bool { deleteCount == 0 && insertion.isEmpty }

    public static func compute(
        previous: String,
        next: String,
        wordLimit: Int = 64
    ) throws -> ReplacementPlan {
        guard wordLimit > 0, wordLimit <= 64 else { throw ReplacementError.invalidLimit }
        // Check encoded lengths before normalization or creating character arrays.
        // Generated Vietnamese NFC text uses one scalar per letter. This also
        // bounds malformed long combining sequences submitted to this API.
        guard previous.utf16.prefix(wordLimit * 2 + 1).count <= wordLimit * 2,
              next.utf16.prefix(wordLimit * 2 + 1).count <= wordLimit * 2 else {
            throw ReplacementError.wordLimitExceeded
        }
        // String equality is canonically equivalent in Swift, so compare units.
        guard previous.utf16.elementsEqual(previous.precomposedStringWithCanonicalMapping.utf16),
              next.utf16.elementsEqual(next.precomposedStringWithCanonicalMapping.utf16) else {
            throw ReplacementError.nonCanonicalText
        }
        let old = Array(previous)
        let new = Array(next)
        guard old.count <= wordLimit, new.count <= wordLimit else {
            throw ReplacementError.wordLimitExceeded
        }
        var common = 0
        while common < old.count && common < new.count && old[common] == new[common] {
            common += 1
        }
        return ReplacementPlan(
            deleteCount: old.count - common,
            insertion: String(new.dropFirst(common))
        )
    }
}
