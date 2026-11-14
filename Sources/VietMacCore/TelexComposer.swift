/// Telex composition for one tracked word (telex-composition spec).
///
/// The state is structured: base letters with their case and shape, and one word-level tone whose
/// target is recomputed on every render. Instances are independent; there is no global state.
/// Output is precomposed NFC. The word is bounded to `limit` logical characters.
public struct TelexComposer: Equatable, Sendable {
    public enum Shape: UInt8, Equatable, Sendable {
        case none, circumflex, breve, horn, stroke
    }

    public enum Tone: Int, Equatable, Sendable {
        case none = 0, acute, grave, hook, tilde, dot
    }

    public struct Letter: Equatable, Sendable {
        /// Lowercase ASCII base letter.
        public var base: UInt8
        public var upper: Bool
        public var shape: Shape
    }

    /// Result of one key.
    public enum Outcome: Equatable, Sendable {
        /// The visible text after the key. It may equal the old text plus the typed letter.
        case text(String)
        /// The word cannot track this key (overflow); the caller stops tracking until a boundary.
        case untracked
    }

    public static let limit = 64

    public private(set) var letters: [Letter] = []
    public private(set) var tone: Tone = .none
    /// Escaped, ineligible `w`/`z`, or literal start: every key is appended as typed until a boundary.
    public private(set) var literal = false
    /// In literal mode the tone stays on the letter it was on when the word turned literal.
    private var frozenToneIndex: Int?

    public init() {
        letters.reserveCapacity(Self.limit)
    }

    public var text: String { render() }
    public var isEmpty: Bool { letters.isEmpty }

    public mutating func reset() {
        letters.removeAll(keepingCapacity: true)
        tone = .none
        literal = false
        frozenToneIndex = nil
    }

    /// Applies one ASCII letter key (`A`–`Z`, `a`–`z`). Other bytes are rejected as untracked.
    public mutating func input(_ byte: UInt8) -> Outcome {
        guard (65...90).contains(byte) || (97...122).contains(byte) else { return .untracked }
        let key = byte | 0x20
        let upper = byte < 97
        if literal { return append(key, upper: upper) }
        switch key {
        case 115, 102, 114, 120, 106: // s f r x j
            return applyTone(Self.tone(for: key), key: key, upper: upper)
        case 122: // z
            if tone != .none, nucleus() != nil {
                tone = .none
                return .text(render())
            }
            return enterLiteral(appending: key, upper: upper)
        case 119: // w
            return applyHornOrBreve(key: key, upper: upper)
        case 97, 101, 111: // a e o
            if let target = shapeTarget(for: key) {
                if letters[target].shape == .circumflex { return escapeShape(at: target, key: key, upper: upper) }
                letters[target].shape = .circumflex
                return .text(render())
            }
            return append(key, upper: upper)
        case 100: // d
            if letters.count == 1, letters[0].base == 100 {
                if letters[0].shape == .stroke { return escapeShape(at: 0, key: key, upper: upper) }
                letters[0].shape = .stroke
                return .text(render())
            }
            return append(key, upper: upper)
        default:
            return append(key, upper: upper)
        }
    }

    /// Appends a key as typed and keeps the word literal until a boundary, for example for an autorepeat
    /// of a modifier key, which never transforms.
    public mutating func inputLiteral(_ byte: UInt8) -> Outcome {
        guard (65...90).contains(byte) || (97...122).contains(byte) else { return .untracked }
        return enterLiteral(appending: byte | 0x20, upper: byte < 97)
    }

    /// Removes the last visible letter and recomputes tone placement. Returns false when the word is empty.
    @discardableResult
    public mutating func backspace() -> Bool {
        guard !letters.isEmpty else { return false }
        let removed = letters.count - 1
        if literal, let frozen = frozenToneIndex, frozen == removed {
            frozenToneIndex = nil
            tone = .none
        }
        letters.removeLast()
        if !literal && nucleus() == nil { tone = .none }
        if letters.isEmpty { reset() }
        return true
    }

    // MARK: Rules

    private mutating func append(_ key: UInt8, upper: Bool) -> Outcome {
        guard letters.count < Self.limit else { return .untracked }
        let toneBefore = literal || tone == .none ? nil : toneIndex()
        letters.append(Letter(base: key, upper: upper, shape: .none))
        // A letter that leaves no valid syllable (a vowel after the final, or a tail that cannot end a
        // syllable) must not move or drop the tone: the word turns literal with the tone where it was.
        if let toneBefore, !isValidSyllable {
            literal = true
            frozenToneIndex = toneBefore
        }
        return .text(render())
    }

    private var isValidSyllable: Bool {
        guard let range = nucleus() else { return false }
        return validFinal(after: range.upperBound)
    }

    private mutating func applyTone(_ next: Tone, key: UInt8, upper: Bool) -> Outcome {
        // Without a vowel, or after letters that cannot end a syllable, a tone key is an ordinary letter.
        guard let range = nucleus(), validFinal(after: range.upperBound) else { return append(key, upper: upper) }
        if tone == next {
            tone = .none
            return enterLiteral(appending: key, upper: upper)
        }
        tone = next
        return .text(render())
    }

    private mutating func applyHornOrBreve(key: UInt8, upper: Bool) -> Outcome {
        guard let range = nucleus(), validFinal(after: range.upperBound) else {
            return enterLiteral(appending: key, upper: upper)
        }
        let vowels = Array(range)
        // `uo` takes a horn on both letters (`ươ`); rendering keeps `u` plain when nothing follows (`thuở`).
        if let u = vowels.firstIndex(where: { letters[$0].base == 117 }), u + 1 < vowels.count,
           letters[vowels[u + 1]].base == 111 {
            let first = vowels[u], second = vowels[u + 1]
            if letters[first].shape == .horn && letters[second].shape == .horn {
                letters[first].shape = .none
                return escapeShape(at: second, key: key, upper: upper)
            }
            letters[first].shape = .horn
            letters[second].shape = .horn
            return .text(render())
        }
        for (base, shape) in [(UInt8(97), Shape.breve), (111, .horn), (117, .horn)] {
            if let index = vowels.last(where: { letters[$0].base == base }) {
                if letters[index].shape == shape { return escapeShape(at: index, key: key, upper: upper) }
                letters[index].shape = shape
                return .text(render())
            }
        }
        return enterLiteral(appending: key, upper: upper)
    }

    /// The vowel that `aa`, `ee`, or `oo` shapes: the last matching vowel of the nucleus, followed only by
    /// a valid final consonant.
    private func shapeTarget(for key: UInt8) -> Int? {
        guard let range = nucleus(), validFinal(after: range.upperBound) else { return nil }
        return range.last(where: { letters[$0].base == key })
    }

    /// Repeating an applied modifier undoes it, keeps the tone, appends the key, and turns the word literal.
    private mutating func escapeShape(at index: Int, key: UInt8, upper: Bool) -> Outcome {
        letters[index].shape = .none
        return enterLiteral(appending: key, upper: upper)
    }

    private mutating func enterLiteral(appending key: UInt8, upper: Bool) -> Outcome {
        frozenToneIndex = tone == .none ? nil : toneIndex()
        literal = true
        return append(key, upper: upper)
    }

    // MARK: Syllable structure

    private static func isVowel(_ base: UInt8) -> Bool {
        base == 97 || base == 101 || base == 105 || base == 111 || base == 117 || base == 121
    }

    /// The contiguous vowel group after the initial consonants, skipping the `qu` and `gi` prefixes.
    /// Nil when the word has no vowel or a vowel appears again after the final consonants.
    func nucleus() -> Range<Int>? {
        guard let first = letters.firstIndex(where: { Self.isVowel($0.base) }) else { return nil }
        var start = first
        if start == 1, letters[0].base == 113, letters[1].base == 117 { start = 2 } // qu
        if start == 1, letters[0].base == 103, letters[1].base == 105,
           letters.count > 2, Self.isVowel(letters[2].base) { start = 2 } // gi + vowel
        guard start < letters.count, Self.isVowel(letters[start].base) else {
            // `qu` or `gi` with no further vowel: the prefix vowel is the nucleus (`gì`).
            return first < letters.count ? first..<(first + 1) : nil
        }
        var end = start
        while end < letters.count, Self.isVowel(letters[end].base) { end += 1 }
        if letters[end...].contains(where: { Self.isVowel($0.base) }) { return nil }
        return start..<end
    }

    private static let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

    private func validFinal(after index: Int) -> Bool {
        let tail = String(decoding: letters[index...].map(\.base), as: UTF8.self)
        return Self.finals.contains(tail)
    }

    /// Tone target (telex-composition: deterministic tone placement, `hòa`, `khỏe`, `thúy`).
    private func toneIndex() -> Int? {
        if literal { return frozenToneIndex }
        guard let range = nucleus() else { return nil }
        let vowels = Array(range)
        let shaped = vowels.filter { letters[$0].shape != .none && renderedShape(at: $0) != .none }
        if let last = shaped.last { return last }
        if vowels.count == 1 { return vowels[0] }
        let hasFinal = range.upperBound < letters.count
        if hasFinal { return vowels[vowels.count - 1] }
        if vowels.count == 2 { return vowels[0] }
        return vowels[1]
    }

    /// `ươ` renders as `uơ` at the end of a word (`thuở`, `huơ`).
    private func renderedShape(at index: Int) -> Shape {
        let letter = letters[index]
        if letter.base == 117, letter.shape == .horn, index + 2 == letters.count,
           letters[index + 1].base == 111, letters[index + 1].shape == .horn {
            return .none
        }
        return letter.shape
    }

    // MARK: Rendering

    private static let vowelForms: [String: [Character]] = [
        "a": Array("aáàảãạ"), "ă": Array("ăắằẳẵặ"), "â": Array("âấầẩẫậ"),
        "e": Array("eéèẻẽẹ"), "ê": Array("êếềểễệ"), "i": Array("iíìỉĩị"),
        "o": Array("oóòỏõọ"), "ô": Array("ôốồổỗộ"), "ơ": Array("ơớờởỡợ"),
        "u": Array("uúùủũụ"), "ư": Array("ưứừửữự"), "y": Array("yýỳỷỹỵ"),
    ]

    private func render() -> String {
        let target = tone == .none ? nil : toneIndex()
        var output = ""
        output.reserveCapacity(letters.count * 2)
        for (index, letter) in letters.enumerated() {
            var base = String(UnicodeScalar(letter.base))
            switch (letter.base, renderedShape(at: index)) {
            case (97, .circumflex): base = "â"
            case (97, .breve): base = "ă"
            case (101, .circumflex): base = "ê"
            case (111, .circumflex): base = "ô"
            case (111, .horn): base = "ơ"
            case (117, .horn): base = "ư"
            case (100, .stroke): base = "đ"
            default: break
            }
            var character = Character(base)
            if index == target, let forms = Self.vowelForms[base] { character = forms[tone.rawValue] }
            output += letter.upper ? character.uppercased() : String(character)
        }
        return output
    }

    private static func tone(for key: UInt8) -> Tone {
        switch key {
        case 115: .acute
        case 102: .grave
        case 114: .hook
        case 120: .tilde
        default: .dot
        }
    }
}
