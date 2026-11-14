# Telex composer

`VietMacCore/TelexComposer` turns ASCII letter keys into one NFC Vietnamese word. It has no macOS or I/O dependency.
`PrototypePipeline` owns one instance per host and decides what reaches the field. Behavior is specified in
[telex-composition](../openspec/changes/telex-input-mvp/specs/telex-composition/spec.md).

## State

- `letters`: at most 64 entries. Each holds a lowercase ASCII base, its own case, and a shape (`circumflex`, `breve`, `horn`, `stroke`).
- `tone`: one word-level tone. Its target is computed at every render from the syllable: a shaped vowel first (the last one), else the only vowel, else the last vowel before a final consonant, else the first of two open vowels (`hòa`, `khỏe`, `thúy`), else the middle of three.
- `literal`: set by an escape, an ineligible `w` or `z`, or a letter that leaves no valid syllable. Every later key is appended as typed until a boundary, and the tone stays on the letter it was on.
- `qu` and `gi` (before another vowel) are initials. `ươ` renders as `uơ` when nothing follows (`thuở`).

## Keys

| Key | Effect |
| --- | --- |
| `s f r x j` | Set the tone. The same tone again removes it, appends the key, and turns the word literal. Without a vowel, or after a tail that cannot end a syllable, the key is an ordinary letter |
| `z` | Remove the tone. Without a tone, the key is appended and the word turns literal |
| `a e o` | Circumflex on the last matching vowel of the nucleus when only a valid final follows. Applied again, it escapes |
| `w` | Horn on `uo` (both), else breve on `a`, horn on `o`, horn on `u`. No target: literal |
| `d` | `dd` at the start of the word gives `đ`; a third `d` escapes |

## Backspace

The composer removes the last visible letter and recomputes the tone. The pipeline accepts that only when the result equals the field after a physical Backspace (the old text without its last character).
When the tone would move (`hoàn` then Backspace gives `hòa` in the composer but `hoà` in the field), the pipeline stops tracking the word until a boundary. Moving the tone needs a Backspace-triggered replacement, which waits for U-5. This differs from the spec scenario "Recompute tone placement after deletion".

## Replacement

For each key the pipeline compares the composer's text with the old text plus the typed letter. Equal means the key passes through. Otherwise the pipeline asks the host for a replacement from the old text to the new text; `ReplacementPlan` computes the deletion count and insertion, and the composer state commits only when the host accepts the replacement.
A held modifier key (autorepeat) never transforms; it is tracked as typed and the word turns literal.

## Verification

| Command | Scope |
| --- | --- |
| `make test` | Spec scenarios, the 12 vowels × 6 tones matrix, pipeline integration, and 25 seeded random runs of 4,000 events against an independent text buffer |
| `make replay` | Planner fixtures and `Fixtures/telex-composition.json` semantic fixtures (events: letters, ` ` boundary, `<` Backspace, `!` invalidation) |
| `make bench-engine` | Release per-event cost of the composer plus the replacement plan; baseline [2026-11-14](../benchmarks/baselines/2026-11-14-reducer-arm64.json) p99 3.6 µs |
| `make test-sanitize` | Address sanitizer over all tests |
| `python3 scripts/native_run.py telex-* --browser <app>` | Native automation in Chrome, Dia, and Safari (`Fixtures/native-scenarios/telex.json`) |
