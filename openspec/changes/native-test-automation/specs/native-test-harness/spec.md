# Spec Delta

## Purpose

Verify VietMac's visible behavior in Son's required macOS fields with scripted, repeatable native input instead of manual typing, while keeping that evidence separate from physical typing and model checks.

## ADDED Requirements

### Requirement: Scripted native key input
The test driver SHALL post HID-level keyboard and mouse events from a declared step script, so session event taps receive them as keyboard input. Steps SHALL support letters, digits, punctuation, Space, Return, Tab, Backspace, Delete, Escape, arrow keys, modifier chords, held keys with autorepeat, CapsLock, pauses, clicks, and per-step press/hold timing with optional seeded jitter.

#### Scenario: Rollover timing is reproduced
- **WHEN** a script presses the next key before releasing the previous one
- **THEN** the target application observes the second keydown while the first key is still down

#### Scenario: Held key produces autorepeat
- **WHEN** a script holds a letter for a declared repeat count
- **THEN** the driver posts one initial keydown followed by that many keydowns marked as autorepeat and a single keyup

#### Scenario: Seeded jitter is reproducible
- **WHEN** the same script runs twice with the same jitter seed
- **THEN** the driver posts the same event order with the same relative timings

#### Scenario: Unsupported step is rejected
- **WHEN** a script contains a key name or character outside the driver vocabulary
- **THEN** the driver posts no events and reports the unsupported step

### Requirement: Safe driver execution
The driver MUST type only into the declared application with an ABC or U.S. input source, MUST stop on interference, and MUST leave no key or modifier held.

#### Scenario: Wrong application is frontmost
- **WHEN** the frontmost application differs from the declared bundle identifier before or during a run
- **THEN** the driver posts no further events, releases held keys, and reports `frontmostChanged`

#### Scenario: Physical input interrupts a run
- **WHEN** a keyboard or mouse event that the driver did not post arrives during a run
- **THEN** the driver stops, releases held keys and modifiers, and reports `userInterference`

#### Scenario: Input source is restored
- **WHEN** a run selected ABC because another source was active
- **THEN** the previous input source is selected again on every exit path

#### Scenario: Submission keys are refused for protected targets
- **WHEN** a scenario sends Return or Command-Return to a target declared as protected
- **THEN** the driver rejects the script before posting any event

### Requirement: Field oracles for required surfaces
The harness SHALL read the exact text, caret, and selection of the target field after a run for VS Code editor, Find, and quick input; Chrome, Dia, and Safari address/search, ordinary input, text area, and rich editing; and Apple Notes title and body. An oracle MUST read only a designated test document or field.

#### Scenario: Browser page field is read
- **WHEN** a run targets a fixture page field
- **THEN** the oracle reports that field's value, caret, selection, and the page's key and input event log

#### Scenario: Native field is read
- **WHEN** a run targets an address bar, a VS Code test document, or the Apple Notes test note
- **THEN** the oracle reports the field text and selected range of that designated target

#### Scenario: Target is not a test document
- **WHEN** the focused element is not the designated test document or field
- **THEN** the oracle reads no content and the run fails with `untrustedTarget`

### Requirement: Fixture-driven scenario catalog
Scenarios SHALL be versioned fixtures that declare steps, target app and field, initial field content, expected text and caret at checkpoints, required VietMac counter outcomes, and the prototype or engine rule set they assume. Expected text SHALL come from explicit fixtures, not from the production reducer.

#### Scenario: Intermediate checkpoint fails
- **WHEN** the final text matches but a declared checkpoint shows a different intermediate text
- **THEN** the scenario fails and reports the checkpoint

#### Scenario: Scenario assumes rules the build lacks
- **WHEN** a scenario requires engine rules that the running build does not provide
- **THEN** the runner reports it as `not-applicable` rather than pass or fail

### Requirement: Preservation checks on every run
Each run SHALL fail when the clipboard changed, marked text appeared, or the resulting text contains invisible format characters or decomposed Vietnamese marks.

#### Scenario: Clipboard is preserved
- **WHEN** a run completes
- **THEN** the pasteboard change count equals its value before the run, without reading clipboard contents

#### Scenario: Composition or invisible text appears
- **WHEN** the field reports marked text or the result contains U+200B–U+200F, U+202F, U+FEFF, or a non-NFC sequence
- **THEN** the run fails with the offending code points

### Requirement: Matrix execution and evidence
The runner SHALL execute selected scenarios across apps and fields, optionally repeating each run, and SHALL write a machine-readable result and a Markdown summary that identify OS, app versions, input source, VietMac build, scenario version, and evidence class `native-automation`.

#### Scenario: Repeated runs report a flake rate
- **WHEN** a scenario runs N times in one field
- **THEN** the result lists each run's outcome and the pass count out of N without retrying failures silently

#### Scenario: Automation is not counted as physical typing
- **WHEN** acceptance evidence is summarized
- **THEN** automated rows are labeled `native-automation` and do not satisfy physical spot-check requirements

#### Scenario: A field cannot be driven
- **WHEN** an app is missing or its oracle is unavailable
- **THEN** that matrix cell is `not-run` with the reason, and the summary does not report the field as passed
