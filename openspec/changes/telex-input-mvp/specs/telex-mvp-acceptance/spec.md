# Telex MVP acceptance

## Purpose

Define the evidence required to accept VietMac as Son's personal Vietnamese input app. Keep language-model correctness, native document behavior, lifecycle, and performance claims separate.

## ADDED Requirements

### Requirement: Native transport prerequisite
The full-engine implementation SHALL follow the successful native gate of `macos-transport-spike`. Planning can exist before that gate, but unresolved or missing M0 field evidence SHALL prevent proceeding as if transport were established.

#### Scenario: M0 has an untested required browser
- **WHEN** M0 lacks a Dia field result or has an unresolved selected-suggestion failure
- **THEN** full-engine implementation does not bypass the gate
- **AND** the missing or failed native task stays pending

### Requirement: Expected behavior after every semantic event
Composition fixtures SHALL state expected visible text and action after each event, including mode, context boundaries, and invalidation. Expected text SHALL come from explicit behavior fixtures rather than using the production reducer as its own oracle.

#### Scenario: A temporary wrong output would be hidden by the final word
- **WHEN** a fixture replays `aasa`
- **THEN** it checks `a`, `â`, `ấ`, and `áa` after the respective keys
- **AND** an intermediate wrong word fails the fixture even if final text matches

#### Scenario: Coverage spans tone, shape, and case
- **WHEN** the model acceptance report is generated
- **THEN** it includes all twelve vowel forms, all five tones plus no tone, base/modifier case variants, `qu`, `gi`, `iê`, `yê`, `uô`, `ươ`, `oa`, `oe`, and `uy`
- **AND** it includes repeated modifiers, tone removal, Backspace, punctuation, boundaries, invalidation, and exact-limit/overflow cases

### Requirement: Selected legacy regression coverage
The model suite SHALL cover applicable failure families from the reviewed OpenKey baseline using VietMac's selected policies. VNI, Windows transport, and committed-word restoration checks SHALL remain excluded rather than implying those features exist.

#### Scenario: Standalone and case-dependent legacy failures are covered
- **WHEN** the regression suite runs
- **THEN** standalone brackets and leading `w` remain literal without invalid access
- **AND** `thuowr`, `THUOWR`, and `Thuowr` use the same vowel rule

#### Scenario: Restore a vowel shape without losing its tone
- **WHEN** the regression suite runs `aasa` and its case/tone variants
- **THEN** the repeated shape key is visible and the restored vowel retains its tone

#### Scenario: Backspace cannot recover unmatched raw history
- **WHEN** a fixture crosses a boundary, deletes backward, and then applies a modifier
- **THEN** no replacement uses a committed word or raw history that the current context does not own

### Requirement: Daily-use failure families
The MVP SHALL prevent or detect the three failures Son reports with OpenKey in every required browser field: lost text, duplicated text, and tone marks outside the selected form. See `docs/research/openkey-comparison.md`.

#### Scenario: Key rollover does not lose text
- **WHEN** a trigger key is pressed while the previous letter key is still down
- **THEN** the replacement deletes and inserts exactly the planned text, and no trigger loses its insertion

#### Scenario: A misdirected deletion is not followed silently
- **WHEN** a field observation after a replacement shows the previous text was not removed as predicted
- **THEN** the replacement counts as unconfirmed, the input path pauses with a delivery reason, and no repair deletion is sent

#### Scenario: Tone placement follows the selected convention
- **WHEN** Son's reported examples and the `hoaf`, `khoer`, `thuys`, and `hoafn` sequences are typed natively
- **THEN** each field contains the selected NFC form with no decomposed marks

### Requirement: Randomized model and safety checks
The suite SHALL exercise deterministic randomized semantic sequences against an independent simulated text buffer. It SHALL verify NFC output, bounded state, no replacement outside owned text, consistent pass-through, and reset isolation; such checks SHALL not be labeled native verification.

#### Scenario: A randomized sequence fails
- **WHEN** a generated sequence violates a model invariant
- **THEN** the report preserves the seed and a synthetic reproduction suitable for a focused fixture
- **AND** the failure is not hidden by changing the expected output to match the reducer

#### Scenario: Index or ownership code changes
- **WHEN** implementation changes indexes, bounds, or buffer ownership
- **THEN** focused sanitizer checks pass before that work is accepted
- **AND** sanitizer success is reported as model/address-safety evidence only

### Requirement: Full-engine native field matrix
The complete engine SHALL pass independently in all required fields: VS Code editor, Find, quick input; four field families in each of Chrome, Dia, and Safari; Apple Notes title and body. M0 prototype evidence SHALL not count as full-engine acceptance.

#### Scenario: Required field families are enumerated
- **WHEN** native MVP acceptance is recorded
- **THEN** the matrix contains all 17 field groups: three VS Code groups, address/search plus ordinary input plus text area plus rich editing in each browser, and two Notes groups
- **AND** the browser results are independent rather than inherited from a shared browser engine

#### Scenario: Compose a phrase in each required field
- **WHEN** `tieengs Vieetj` is typed between pre-existing synthetic prefix and suffix text in an accepted field
- **THEN** the inserted text is exactly `tiếng Việt` with the caret immediately after it
- **AND** the prefix, suffix, and selection outside the edit are preserved
- **AND** the same field passes tone replacement, case, repeated modifiers, and Backspace scenarios

### Requirement: Native context and editing preservation
Each required field SHALL pass context-switching, selection, autocomplete, shortcut, undo/redo, and surrounding-text checks. Native evidence SHALL report observable undo grouping; it SHALL not infer document correctness from successful event posting.

#### Scenario: Browser selects a suggested completion
- **WHEN** Telex input is exercised with selected autocomplete suggestions in each browser address/search field
- **THEN** the expected typed prefix, completion selection, final text, and caret agree with the recorded scenario
- **AND** the field fails acceptance if a replacement silently deletes unrelated suggestion or user text

#### Scenario: Move between fields inside one app
- **WHEN** the user or application changes focus/selection after typing tracked `a`, then `s` arrives in the new context
- **THEN** no character from the prior tracked word is replaced
- **AND** evidence includes observed programmatic focus changes and document edits in addition to mouse/navigation changes

#### Scenario: Undo and redo composed input
- **WHEN** the test undoes and redoes a controlled composition sequence
- **THEN** the before/after synthetic text and surrounding content are restored as expected
- **AND** the record states the number and grouping of undo steps instead of promising one step per physical key

#### Scenario: Preserve rich text and Unicode neighbors
- **WHEN** composition runs next to an emoji or an existing formatted span in Notes or a rich editor
- **THEN** the emoji and existing formatting remain unchanged outside the inserted text
- **AND** Backspace never deletes an unowned UTF-16 unit or neighboring grapheme

### Requirement: Native lifecycle and mode acceptance
The personal app SHALL pass native tests for English mode, configured toggle, fast typing, held keys, single-instance launch, capability loss, secure input, sleep/wake, relaunch, and opt-in startup. Recovery SHALL start fresh and preserve ordinary input while transformation is unavailable.

#### Scenario: Exercise mode and speed transitions
- **WHEN** synthetic Vietnamese and English sequences are typed rapidly, repeated keys are held, and the configured toggle is pressed
- **THEN** there are no missing or duplicate physical characters beyond the specified Telex transformations
- **AND** English identifiers and unrelated shortcuts remain literal

#### Scenario: Recover after availability changes
- **WHEN** the native session exercises permission loss, secure input, timeout pause, sleep/wake, and relaunch
- **THEN** the menu reports the actual availability and any resumed composition starts without the prior word
- **AND** the result includes ordinary-input preservation and bounded recovery behavior

### Requirement: Plain text and privacy preservation
Native typing SHALL leave the clipboard unchanged and SHALL introduce no marked text, composition underline, or invisible sentinel. Acceptance evidence SHALL use synthetic text and SHALL record no user documents or real typing history.

#### Scenario: Inspect an accepted insertion
- **WHEN** a required field completes a controlled Telex sequence
- **THEN** inspection shows only the intended NFC text and literal boundaries
- **AND** clipboard contents remain the same as before the sequence
- **AND** the visual result has no composition underline

### Requirement: Explicit evidence and completion status
Each native row SHALL identify OS, hardware architecture, app version, field, input source, mode, transport profile, autocomplete settings, sequence, expected/actual text, caret/selection, and pass/fail/not-run status. Missing or failed required evidence SHALL block MVP completion.

#### Scenario: A required app is unavailable
- **WHEN** an app or field cannot be tested locally
- **THEN** its rows remain `not-run` and its tasks remain pending
- **AND** the supported matrix is not silently reduced

#### Scenario: Only model checks and the app build passed
- **WHEN** source checks, replay, or `make app` pass without the complete native matrix
- **THEN** the report states those scopes as verified and native MVP acceptance as unknown
- **AND** the change is not archived as complete

#### Scenario: Declare personal MVP completion
- **WHEN** all model, native, lifecycle/control, and declared Release performance gates have passed
- **THEN** the report links their evidence and names the tested OS/app environment and remaining excluded features
- **AND** neither older macOS/Intel support nor public distribution is claimed from the local result
