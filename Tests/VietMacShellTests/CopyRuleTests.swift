import Foundation
import Testing
@testable import VietMacShell

/// Copy rules from ux-spec section 9, checked on the bundled string catalog.
struct CopyRuleTests {
    let table = StringTable.bundled

    @Test func catalogLoads() {
        #expect(table.entries.count > 100)
    }

    @Test func bothLanguagesHaveEveryKey() {
        for (key, values) in table.entries {
            for language in UILanguage.allCases {
                #expect(!(values[language] ?? "").isEmpty, "\(key) has no \(language.rawValue) value")
            }
        }
    }

    @Test func placeholderCountsMatch() {
        for (key, values) in table.entries {
            let counts = UILanguage.allCases.map { (values[$0] ?? "").components(separatedBy: "%@").count }
            #expect(Set(counts).count == 1, "\(key) placeholder count differs")
        }
    }

    @Test func vietnameseIsPrecomposedNFC() {
        for (key, values) in table.entries {
            let value = values[.vi] ?? ""
            #expect(value.unicodeScalars.elementsEqual(value.precomposedStringWithCanonicalMapping.unicodeScalars),
                    "\(key) is not NFC")
        }
    }

    @Test func englishFollowsCopyRules() {
        let contractions = ["n't", "'re", "'ve", "'ll", "'m ", "'d ", "it's", "that's", "there's", "what's", "let's"]
        for (key, values) in table.entries {
            let value = values[.en] ?? ""
            let lower = value.lowercased().replacingOccurrences(of: "’", with: "'")
            #expect(!value.contains("—") && !value.contains("–"), "\(key) has a dash")
            #expect(!value.contains(";"), "\(key) has a semicolon")
            #expect(!contractions.contains { lower.contains($0) }, "\(key) has a contraction")
            #expect(!lower.contains("error") && !lower.contains("failed"), "\(key) names a fault")
        }
    }

    @Test func vietnameseFollowsCopyRules() {
        for (key, values) in table.entries {
            let value = values[.vi] ?? ""
            let lower = value.lowercased()
            #expect(!value.contains("—") && !value.contains("–"), "\(key) has a dash")
            #expect(!value.contains(";"), "\(key) has a semicolon")
            #expect(!lower.contains("lỗi") && !lower.contains("thất bại"), "\(key) names a fault")
            #expect(!value.contains("!"), "\(key) has an exclamation mark")
        }
    }

    /// A description has at most 25 words per sentence (ux-spec 9). Checked in English, because a
    /// Vietnamese word count is a syllable count. Reference strips separated by `·` are not sentences.
    @Test func sentencesStayShort() {
        for (key, values) in table.entries {
            for language in [UILanguage.en] where !(values[language] ?? "").contains("·") {
                let value = (values[language] ?? "").replacingOccurrences(of: "\n", with: ". ")
                for sentence in value.components(separatedBy: ". ") {
                    let words = sentence.split(whereSeparator: { $0.isWhitespace }).count
                    #expect(words <= 25, "\(key) \(language.rawValue): \(words) words")
                }
            }
        }
    }

    @Test func helpPagesStayUnder120Words() {
        for page in HelpPage.allCases {
            for language in UILanguage.allCases {
                let body = Strings(language: language).text("help.\(page.rawValue).body")
                let words = body.split(whereSeparator: { $0.isWhitespace }).filter { $0 != "•" }.count
                #expect(words < 120, "help.\(page.rawValue).body \(language.rawValue) has \(words) words")
                #expect(!body.contains("http"), "help page has an external link")
            }
        }
    }

    @Test func substitutesArgumentsInOrder() {
        #expect(Strings.substitute("%@ cũng %@", ["A", "B"]) == "A cũng B")
        #expect(Strings(language: .vi)("setup.stepIndicator", "3", "6") == "Bước 3 / 6")
        #expect(Strings(language: .en)("setup.stepIndicator", "3", "6") == "Step 3 of 6")
    }

    @Test func missingKeyIsVisible() {
        #expect(Strings(language: .en)("no.such.key") == "no.such.key")
    }

    @Test func preferredLanguageFollowsSystemOrder() {
        #expect(UILanguage.preferred(["vi-VN", "en-US"]) == .vi)
        #expect(UILanguage.preferred(["fr-FR", "en-GB", "vi"]) == .en)
        #expect(UILanguage.preferred(["ja-JP"]) == .en)
    }
}
