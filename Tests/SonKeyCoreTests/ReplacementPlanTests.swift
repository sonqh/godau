import Testing
@testable import SonKeyCore

struct ReplacementPlanTests {
    @Test func reconstructsDesiredTextAndKeepsCommonPrefix() throws {
        for (previous, next, count, insertion) in [
            ("a", "á", 1, "á"),
            ("tiêng", "tiếng", 3, "ếng"),
            ("ấ", "áa", 1, "áa"),
            ("tiếng", "tiến", 1, ""),
            ("", "a", 0, "a"),
            ("á", "", 1, ""),
            ("á", "á", 0, ""),
        ] {
            let plan = try ReplacementPlan.compute(previous: previous, next: next)
            #expect(plan.deleteCount == count)
            #expect(plan.insertion == insertion)
            #expect(String(previous.dropLast(plan.deleteCount)) + plan.insertion == next)
        }
    }

    @Test func deletionCountsGraphemesRatherThanUTF16Units() throws {
        let plan = try ReplacementPlan.compute(previous: "a👩🏽‍💻", next: "a")
        #expect(plan.deleteCount == 1)
        #expect(plan.insertion.isEmpty)
    }

    @Test func rejectsNFDDespiteSwiftCanonicalEquality() {
        #expect(throws: ReplacementError.nonCanonicalText) {
            try ReplacementPlan.compute(previous: "a\u{0301}", next: "á")
        }
    }

    @Test func boundsTextAndRejectsInvalidLimits() throws {
        let boundary = String(repeating: "a", count: 64)
        #expect(try ReplacementPlan.compute(previous: boundary, next: boundary).isEmpty)
        #expect(throws: ReplacementError.wordLimitExceeded) {
            try ReplacementPlan.compute(previous: boundary + "a", next: "a")
        }
        for limit in [0, -1, Int.max] {
            #expect(throws: ReplacementError.invalidLimit) {
                try ReplacementPlan.compute(previous: "a", next: "á", wordLimit: limit)
            }
        }
        #expect(throws: ReplacementError.wordLimitExceeded) {
            try ReplacementPlan.compute(previous: String(repeating: "\u{0301}", count: 200), next: "")
        }
    }
}
