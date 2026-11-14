import Testing
@testable import VietMacCore

/// Feeds keys and returns the text after each key. A space ends the word (boundary).
private func type(_ keys: String) -> [String] {
    var composer = TelexComposer()
    var committed = ""
    var steps: [String] = []
    for scalar in keys.unicodeScalars {
        if scalar == " " {
            committed += composer.text + " "
            composer.reset()
        } else if scalar == "<" {
            composer.backspace()
        } else if case .text = composer.input(UInt8(scalar.value)) {
        }
        steps.append(committed + composer.text)
    }
    return steps
}

private func final(_ keys: String) -> String { type(keys).last ?? "" }

struct TelexComposerTests {
    @Test func standardShapes() {
        #expect(["aa", "aw", "ee", "oo", "ow", "uw", "dd"].map(final) == ["â", "ă", "ê", "ô", "ơ", "ư", "đ"])
    }

    @Test func shapeAfterConsonantSuffixAndTone() {
        #expect(final("tienge") == "tiêng")
        #expect(final("tienges") == "tiếng")
        #expect(type("asa") == ["a", "á", "ấ"])
    }

    @Test func pairedVowels() {
        #expect(["dduowngf", "nguowif", "yeeus"].map(final) == ["đường", "người", "yếu"])
    }

    @Test func fiveTones() {
        #expect(["as", "af", "ar", "ax", "aj"].map(final) == ["á", "à", "ả", "ã", "ạ"])
        let vowels = ["a", "aw", "aa", "e", "ee", "i", "o", "oo", "ow", "u", "uw", "y"]
        let expected = ["á", "ắ", "ấ", "é", "ế", "í", "ó", "ố", "ớ", "ú", "ứ", "ý"]
        #expect(vowels.map { final($0 + "s") } == expected)
        #expect(vowels.map { final($0.uppercased() + "s") } == expected.map { $0.uppercased() })
    }

    @Test func allVowelFormsWithEveryTone() {
        let vowels = ["a", "aw", "aa", "e", "ee", "i", "o", "oo", "ow", "u", "uw", "y"]
        let rows = ["aáàảãạ", "ăắằẳẵặ", "âấầẩẫậ", "eéèẻẽẹ", "êếềểễệ", "iíìỉĩị",
                    "oóòỏõọ", "ôốồổỗộ", "ơớờởỡợ", "uúùủũụ", "ưứừửữự", "yýỳỷỹỵ"]
        for (keys, row) in zip(vowels, rows) {
            let forms = Array(row).map(String.init)
            for (tone, form) in zip(["", "s", "f", "r", "x", "j"], forms) {
                #expect(final(keys + tone) == form, "\(keys)\(tone)")
                #expect(final(keys.uppercased() + tone) == form.uppercased(), "\(keys)\(tone) upper")
            }
        }
    }

    @Test func replaceAndRemoveTone() {
        #expect(type("aasfz") == ["a", "â", "ấ", "ầ", "â"])
    }

    @Test func openSyllableConvention() {
        #expect(["hoaf", "khoer", "thuys"].map(final) == ["hòa", "khỏe", "thúy"])
        let steps = type("hoafn")
        #expect(steps[3] == "hòa" && steps[4] == "hoàn")
    }

    @Test func quAndGiPrefixes() {
        #expect(["quas", "quys", "gias", "gif"].map(final) == ["quá", "quý", "giá", "gì"])
    }

    @Test func shapedAndThreeVowelNuclei() {
        #expect(["tieengs", "tuoongs", "ngoais", "khuyur"].map(final) == ["tiếng", "tuống", "ngoái", "khuỷu"])
        #expect(final("hoawcj") == "hoặc")
    }

    @Test func thuoRuleAcrossCase() {
        #expect(["thuowr", "THUOWR", "Thuowr"].map(final) == ["thuở", "THUỞ", "Thuở"])
    }

    @Test func baseCasePreserved() {
        #expect(["As", "aS", "DD", "Dd"].map(final) == ["Á", "á", "Đ", "Đ"])
        #expect(final("Tieengs Vieetj") == "Tiếng Việt")
        #expect(final("tieengs Vieetj") == "tiếng Việt")
    }

    @Test func repeatedModifierEscapes() {
        #expect(["ass", "aaa", "aww", "eee", "ooo", "oww", "uww", "ddd"].map(final)
                == ["as", "aa", "aw", "ee", "oo", "ow", "uw", "dd"])
        #expect(type("aasa") == ["a", "â", "ấ", "áa"])
        #expect(final("AaSa") == "Áa")
        #expect(final("asss") == "ass")
        #expect(final("asss as") == "ass á")
    }

    @Test func visibleCharacterBackspace() {
        #expect(final("tieengs<") == "tiến")
        #expect(final("tieengs<f") == "tiền")
        #expect(final("hoafn<") == "hòa")
        #expect(final("as<o") == "o")
    }

    /// Found by the randomized ownership test: an invalid tail must not move or drop the tone.
    @Test func invalidSyllableKeepsTheToneInPlace() {
        #expect(type("hufte") == ["h", "hu", "hù", "hùt", "hùte"])
        #expect(final("hufte<") == "hùt")
        #expect(final("cnyyfq") == "cnỳyq")
        #expect(final("cnyyfq<") == "cnỳy")
        #expect(final("eesxby<") == "ễb")
    }

    @Test func literalPreservation() {
        #expect(final("w") == "w")
        #expect(final("windows") == "windows")
        #expect(final("bws") == "bws")
        #expect(type("sas") == ["s", "sa", "sá"])
    }

    @Test func outputIsNFC() {
        for word in ["tieengs", "dduowngf", "nguowif", "khuyur", "thuowr", "aasa", "hoawcj"] {
            let text = final(word)
            #expect(text.unicodeScalars.elementsEqual(text.precomposedStringWithCanonicalMapping.unicodeScalars))
        }
    }

    @Test func overflowIsUntracked() {
        var composer = TelexComposer()
        for _ in 0..<64 { _ = composer.input(98) }
        #expect(composer.input(98) == .untracked)
        #expect(composer.letters.count == 64)
    }

    @Test func instancesAreIndependent() {
        var first = TelexComposer()
        var second = TelexComposer()
        _ = first.input(97)
        _ = second.input(115)
        #expect(first.text == "a" && second.text == "s")
    }

    @Test func rejectsNonLetters() {
        var composer = TelexComposer()
        #expect(composer.input(49) == .untracked)
        #expect(composer.isEmpty)
    }
}

/// Replacement and Backspace counts for the native Telex scenarios in Fixtures/native-scenarios/telex.json.
struct TelexScenarioCountTests {
    private func counts(_ keys: String) throws -> (replacements: Int, backspaces: Int) {
        var composer = TelexComposer()
        var replacements = 0, backspaces = 0
        for scalar in keys.unicodeScalars {
            if scalar == " " { composer.reset(); continue }
            let before = composer.text
            guard case .text(let after) = composer.input(UInt8(scalar.value)) else { continue }
            if after != before + String(scalar) {
                replacements += 1
                backspaces += try ReplacementPlan.compute(previous: before, next: after).deleteCount
            }
        }
        return (replacements, backspaces)
    }

    static let workloadPhrase = " tieengs Vieetj laf ngoon nguwx cuar nguowif Vieetj Nam"
    static var workload: String { String(repeating: workloadPhrase, count: 12) }

    @Test func workloadExpectation() throws {
        #expect(final(Self.workloadPhrase) == " tiếng Việt là ngôn ngữ của người Việt Nam")
        #expect(try counts(Self.workload) == (168, 252))
    }

    @Test func scenarioExpectationsMatchTheComposer() throws {
        #expect(try counts(" tieengs Vieetj") == (4, 7))
        #expect(try counts(" dduowngf nguowif hoafn khuyur thuowr quys gif") == (14, 22))
        #expect(try counts(" ass aasa windows") == (5, 5))
    }
}
