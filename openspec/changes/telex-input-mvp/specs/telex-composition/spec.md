# Telex composition

## Purpose

Convert semantic ASCII key sequences into predictable NFC Vietnamese text while editing only the currently tracked word. Define language behavior independently of macOS transport and application compatibility.

## ADDED Requirements

### Requirement: Standard vowel and consonant shapes
The composer SHALL support `aa`, `aw`, `ee`, `oo`, `ow`, `uw`, and `dd` as `â`, `ă`, `ê`, `ô`, `ơ`, `ư`, and `đ`. Eligible shape modifiers SHALL work immediately after the base or after its tracked consonant suffix, without losing an existing tone.

#### Scenario: Shape a base letter
- **WHEN** a fresh word receives each of `aa`, `aw`, `ee`, `oo`, `ow`, `uw`, and `dd`
- **THEN** its text is respectively `â`, `ă`, `ê`, `ô`, `ơ`, `ư`, and `đ`

#### Scenario: Add a shape after the consonant suffix
- **WHEN** a fresh word receives `tienge`
- **THEN** its text is `tiêng`
- **AND** a following `s` produces `tiếng`

#### Scenario: Add a shape after a tone
- **WHEN** a fresh word receives `asa`
- **THEN** its text after each key is `a`, `á`, and `ấ`

#### Scenario: Compose common paired vowels
- **WHEN** fresh words receive `dduowngf`, `nguowif`, and `yeeus`
- **THEN** their text is respectively `đường`, `người`, and `yếu`

### Requirement: Tone selection and removal
The composer SHALL apply `s`, `f`, `r`, `x`, and `j` as acute, grave, hook, tilde, and dot-below tones. A different tone SHALL replace the current tone. `z` SHALL remove an existing tone without removing vowel shape or case.

#### Scenario: Apply the five tones
- **WHEN** fresh words receive `as`, `af`, `ar`, `ax`, and `aj`
- **THEN** their text is respectively `á`, `à`, `ả`, `ã`, and `ạ`
- **AND** the same tone mapping applies to all twelve Vietnamese vowel forms and their uppercase counterparts

#### Scenario: Replace a tone and retain shape
- **WHEN** a fresh word receives `aasfz`
- **THEN** its text after each key is `a`, `â`, `ấ`, `ầ`, and `â`
- **AND** no modifier key is appended literally during those accepted transformations

### Requirement: Deterministic tone placement
The composer SHALL retain one word-level tone and recompute its target as the tracked vowel nucleus changes. Open `oa`, `oe`, and `uy` SHALL use Son's selected `hòa`, `khỏe`, and `thúy` convention. Prefix handling for `qu` and `gi` SHALL depend on the remaining vowels rather than case.

#### Scenario: Use the selected open-syllable convention
- **WHEN** fresh words receive `hoaf`, `khoer`, and `thuys`
- **THEN** their text is respectively `hòa`, `khỏe`, and `thúy`

#### Scenario: Move the tone after a final consonant arrives
- **WHEN** a fresh word receives `hoafn`
- **THEN** its text after the fourth key is `hòa` and after the fifth is `hoàn`
- **AND** the word retains exactly one grave tone

#### Scenario: Handle qu and gi prefixes
- **WHEN** fresh words receive `quas`, `quys`, `gias`, and `gif`
- **THEN** their text is respectively `quá`, `quý`, `giá`, and `gì`
- **AND** the `i` in `gif` remains an eligible vowel

#### Scenario: Place tones on shaped and three-vowel nuclei
- **WHEN** fresh words receive `tieengs`, `tuoongs`, `ngoais`, and `khuyur`
- **THEN** their text is respectively `tiếng`, `tuống`, `ngoái`, and `khuỷu`

#### Scenario: Preserve the thuở rule across case
- **WHEN** fresh words receive `thuowr`, `THUOWR`, and `Thuowr`
- **THEN** their text is respectively `thuở`, `THUỞ`, and `Thuở`

### Requirement: Base-letter case preservation
Transformation rules SHALL match base letters without using case as a phonetic condition. Output SHALL preserve each base letter's actual input case; the case of a consumed modifier SHALL not change that base letter.

#### Scenario: Modifiers do not change base case
- **WHEN** fresh words receive `As`, `aS`, `DD`, and `Dd`
- **THEN** their text is respectively `Á`, `á`, `Đ`, and `Đ`

#### Scenario: Compose a mixed-case phrase
- **WHEN** a fresh input sequence receives `Tieengs Vieetj`
- **THEN** its text is `Tiếng Việt`
- **AND** the space remains one literal boundary

### Requirement: Repeated modifier escape
Repeating an already applied tone or shape modifier SHALL undo that modifier and append the repeated key literally with its actual case. Removing a shape SHALL retain any tone on the restored vowel. The escaped word SHALL remain literal until its next boundary.

#### Scenario: Escape an already applied modifier
- **WHEN** fresh words receive `ass`, `aaa`, `aww`, `eee`, `ooo`, `oww`, `uww`, and `ddd`
- **THEN** their text is respectively `as`, `aa`, `aw`, `ee`, `oo`, `ow`, `uw`, and `dd`

#### Scenario: Remove a shape while retaining the tone
- **WHEN** a fresh word receives `aasa`
- **THEN** its text after each key is `a`, `â`, `ấ`, and `áa`
- **AND** `AaSa` similarly produces `Áa`

#### Scenario: Stay literal after escape
- **WHEN** a fresh word receives `asss`
- **THEN** its text is `ass`
- **AND** a boundary followed by `as` starts a new word that produces `á`

### Requirement: Visible-character Backspace
Backspace inside the owned word SHALL remove its last visible logical character, not its last raw modifier key, and recompute tone placement. Removing the last eligible vowel SHALL clear its tone. Backspace outside that word SHALL pass through without recovering committed-word history.

#### Scenario: Delete the visible final consonant
- **WHEN** `tieengs` produces `tiếng` and one Backspace arrives
- **THEN** the text is `tiến`
- **AND** a following `f` produces `tiền`

#### Scenario: Recompute tone placement after deletion
- **WHEN** `hoafn` produces `hoàn` and one Backspace arrives
- **THEN** the text is `hòa`

#### Scenario: Delete the last vowel and start cleanly
- **WHEN** `as` produces `á`, Backspace removes it, and `o` arrives
- **THEN** the text is `o` without a carried tone

#### Scenario: Do not resume a committed word
- **WHEN** `as ` produces `á `, Backspace deletes the space, and `f` arrives
- **THEN** the text is `áf`
- **AND** the earlier `á` is not recomposed as `à`

### Requirement: Literal preservation and ineligible modifiers
Brackets SHALL remain literal boundaries and leading `w` SHALL remain literal. If `w` or `z` has no eligible operation, the composer SHALL preserve that key and remain literal until a boundary. Tone letters without a target SHALL remain visible ordinary letters; no key SHALL disappear merely because a rule was rejected.

#### Scenario: Preserve standalone developer characters
- **WHEN** fresh sequences receive `[`, `]`, `w`, and `windows`
- **THEN** their text remains exactly the supplied sequence
- **AND** no rule reads before the beginning of an empty word

#### Scenario: Keep an ineligible shape key and following input
- **WHEN** a fresh word receives `bws`
- **THEN** its text is `bws` without deletion or a hidden modifier

#### Scenario: Keep a consonant when no vowel exists
- **WHEN** a fresh word receives `s` followed by `a`
- **THEN** its text is `sa`
- **AND** a following `s` produces `sá`

### Requirement: Context-bound composition
The composer SHALL associate its state with one context generation and edit only newly owned text. Boundaries SHALL end the word and preserve the boundary event. Invalidation SHALL clear letters, tone, escape state, and ownership; it SHALL not adopt existing document text.

#### Scenario: Invalidate before the next modifier
- **WHEN** a tracked `a` is invalidated before `s` arrives
- **THEN** no intent replaces the old `a`
- **AND** a later confirmed boundary allows `as` to compose a fresh `á`

#### Scenario: Keep punctuation and whitespace
- **WHEN** `as`, a comma, and a space arrive in order
- **THEN** the text is `á, ` and the earlier word is no longer owned

#### Scenario: Start a word at the beginning of an empty field
- **WHEN** U-14 has passed for the active profile and, after a reset, a settled observation shows a collapsed caret at offset 0
- **THEN** the next letters start a new owned word without a boundary key
- **AND** without that observation the word stays literal until a boundary

#### Scenario: Keep independent instances independent
- **WHEN** one composer tracks `a` and another composer receives `s` in its own fresh context
- **THEN** the second composer cannot modify the first composer's state or text

### Requirement: Bounded canonical output
The composer SHALL keep each tracked word within 64 logical characters and emit NFC precomposed Vietnamese letters. Overflow SHALL preserve the physical key and enter literal mode until a boundary, without transforming a disconnected suffix. Unsupported non-ASCII input SHALL invalidate ownership and pass through.

#### Scenario: Overflow does not truncate or resume inside the word
- **WHEN** a word of 64 ordinary consonants receives a 65th letter and later modifier keys
- **THEN** all keys remain visible and no tracked replacement is produced before the next boundary
- **AND** the owned buffer remains bounded rather than shifting out an earlier character

#### Scenario: Keep pasted or non-ASCII text outside ownership
- **WHEN** an emoji, decomposed input, or paste is observed next to the tracked word
- **THEN** that input passes through unchanged and the old word is invalidated
- **AND** later modifiers do not delete any part of that input

#### Scenario: Output remains canonical after every transformation
- **WHEN** a tone, shape, escape, or Backspace changes a tracked Vietnamese word
- **THEN** its desired text is NFC and deletion counts remain independent of UTF-16 payload length
