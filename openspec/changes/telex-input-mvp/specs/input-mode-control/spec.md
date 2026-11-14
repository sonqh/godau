# Input mode control

## Purpose

Let Son explicitly choose Vietnamese transformation or literal English input and understand when transformation is paused. Keep settings and lifecycle behavior safe for personal macOS use.

## ADDED Requirements

### Requirement: Explicit Vietnamese and English modes
The app SHALL provide a menu control for Vietnamese and English mode. English mode SHALL preserve ordinary text and shortcuts without Telex transformation. Mode changes SHALL invalidate the tracked word without rewriting already displayed text.

#### Scenario: Type an identifier in English mode
- **WHEN** English mode receives `class`, `windows`, or `https://example.com/as`
- **THEN** the field contains the exact literal sequence
- **AND** no Telex replacement events are generated

#### Scenario: Toggle while a word is active
- **WHEN** `as` has produced `á` and the user selects English mode
- **THEN** the existing `á` remains unchanged and tracked composition is cleared
- **AND** subsequent `s` is literal

#### Scenario: Enable does not adopt an old prefix
- **WHEN** an existing `a` was typed in English mode and the user enables Vietnamese mode
- **THEN** a following `s` does not replace that old `a`
- **AND** a confirmed new-word boundary permits fresh Telex composition

### Requirement: Configurable key-down shortcut
The app SHALL offer an optional shortcut containing a non-modifier key and at least one Command, Control, or Option modifier. The shortcut SHALL be unset by default. It SHALL toggle once per physical press, consume its matching key pair, and never insert its key as text.

#### Scenario: Default shortcut does not reserve an app command
- **WHEN** the app starts without a configured shortcut
- **THEN** the menu toggle remains available and no shortcut chord is intercepted

#### Scenario: Toggle with the configured chord
- **WHEN** the configured chord receives key-down, autorepeat, and key-up
- **THEN** mode changes exactly once and no shortcut text reaches the field
- **AND** the old composition is invalidated

#### Scenario: Shortcut not armed
- **WHEN** a shortcut is configured and a capability is missing, secure input is on, or a sticky pause is active
- **THEN** `shortcutArmed` is false and the chord reaches the app as an ordinary key press
- **AND** the menu mode control still works

#### Scenario: Keep unrelated shortcuts unchanged
- **WHEN** a Command, Control, or Option chord does not match the configured toggle
- **THEN** its original events pass through and composition is invalidated
- **AND** modifier-release sequences alone do not toggle mode

### Requirement: Tested-context gating and exclusions
Transformation SHALL be enabled only in a field that resolves to an accepted compiled field profile, with ABC or U.S. input sources. Resolution SHALL run once per focused-element change outside the key callback and SHALL NOT read a field value, selected text, title, or URL. A user exclusion SHALL override support. Unsupported or unidentifiable contexts, password fields, and terminal surfaces SHALL preserve ordinary input and invalidate composition.

#### Scenario: Profile is not accepted
- **WHEN** the focused field resolves to `notes.text` and that profile is not accepted
- **THEN** ordinary input passes through and the status is Standby `unsupportedField`
- **AND** only a native test launch argument can enable it, and diagnostics then report `testSession`

#### Scenario: A required supported field is active
- **WHEN** Vietnamese mode is selected and an accepted field in VS Code, Chrome, Dia, Safari, or Apple Notes has the required capabilities
- **THEN** transformation can become active using that field's accepted transport profile

#### Scenario: Renderer or helper receives the key event
- **WHEN** a supported application uses a renderer or helper process for an accepted field
- **THEN** gating uses the tested application relationship rather than assuming the event PID equals the frontmost PID
- **AND** an unknown relationship preserves ordinary input

#### Scenario: Exclude an otherwise supported app
- **WHEN** the user excludes a tested application
- **THEN** its fields receive ordinary literal input and no tracked word carries into or out of that app

#### Scenario: Use an unsupported surface or input source
- **WHEN** a terminal, password field, unknown field, unsupported app, or input source other than ABC or U.S. is active
- **THEN** Telex transformation is paused and ordinary input is preserved where the OS permits it
- **AND** VietMac does not switch the system input source automatically

### Requirement: Visible runtime status
The platform SHALL publish one `RuntimeStatus` with availability `off`, `active`, `standby(reason)`, or `blocked(reason)`, reporting only the first failing gate in the order of architecture-spec section 6.1. `active` SHALL equal the gate the key callback uses. Word-level literal holds SHALL NOT change the status. The status SHALL be published from a run-loop observer at most once per pass, never from the callback.

#### Scenario: Selection is a word-level hold
- **WHEN** the user selects text in an accepted field in Vietnamese mode
- **THEN** the tracked word is invalidated
- **AND** the published availability stays `active`

#### Scenario: Gate combinations
- **WHEN** a unit test enumerates every combination of gate inputs
- **THEN** `availability == .active` is true exactly when the callback gate would transform

#### Scenario: User intent differs from runtime availability
- **WHEN** Vietnamese mode is selected but event posting is unavailable
- **THEN** the menu shows paused status and the missing capability
- **AND** selecting Vietnamese mode again does not falsely report active transformation

#### Scenario: A blocking condition clears
- **WHEN** the missing capability or secure-input condition clears and the selected mode permits transformation
- **THEN** the app reevaluates supported context before becoming active
- **AND** old composition is not restored

### Requirement: No observation in English mode and safe tap lifetime
English mode SHALL perform no Accessibility field observation and SHALL install no event tap unless a shortcut is configured. A capability loss SHALL remove the tap at once. On an Accessibility trust-change notification the host SHALL remove the tap before re-reading capabilities, and SHALL recreate it only when every required read is true.

#### Scenario: English mode without a shortcut
- **WHEN** the mode is English and no shortcut is configured
- **THEN** no event tap exists and no focused element is inspected
- **AND** capabilities, input source, and secure input are still refreshed for the status

#### Scenario: Accessibility revoked while typing
- **WHEN** the Accessibility read turns false or the trust-change notification arrives
- **THEN** the tap is removed before the next refresh and the status is Blocked `accessibility`

### Requirement: Persistent preferences with fresh composition
The app SHALL persist selected mode, shortcut, exclusions, and login-startup preference in its own settings domain. First launch SHALL use English mode with no shortcut and login startup off. Relaunch SHALL restore preferences while starting with no tracked word or document content.

#### Scenario: Relaunch after Vietnamese use
- **WHEN** the user quits after selecting Vietnamese mode and then relaunches
- **THEN** the desired mode is restored but transformation becomes active only if current gates pass
- **AND** no prior word, tone, caret, selection, or typed content is restored from storage

### Requirement: Opt-in login startup
The app SHALL offer login startup only as an explicit user preference, disabled by default. Changing this setting SHALL report its actual registration state and SHALL not grant input permissions or start an additional event-transforming instance.

#### Scenario: User enables startup explicitly
- **WHEN** the user enables login startup in settings
- **THEN** the app requests the startup registration through `SMAppService.mainApp` and shows the state the system reports, including `requiresApproval`
- **AND** input capability requirements remain unchanged

#### Scenario: User disables startup
- **WHEN** the user disables login startup
- **THEN** the app removes its startup registration or shows a concrete failure
- **AND** the current input mode is not silently changed

### Requirement: One transforming instance per user session
The app SHALL allow at most one VietMac event-transforming instance in a logged-in user session. A second launch SHALL reuse or identify the existing instance without installing a second active input pipeline.

#### Scenario: Launch a second copy
- **WHEN** VietMac is running and the same user launches another copy
- **THEN** a physical `as` sequence is transformed once rather than by two VietMac pipelines
- **AND** the second launch does not establish another transforming tap

#### Scenario: Second process fails to take the lock
- **WHEN** a second process cannot take the per-user instance lock
- **THEN** it posts the reopen notification and exits without creating `InputHost`
- **AND** the running instance opens its Settings window

### Requirement: Local operation without typed-content records
The app SHALL work offline and SHALL not persist or transmit typed words, raw keystroke history, clipboard contents, or document text. Development evidence and performance captures SHALL use synthetic input or content-free measurements outside the key callback.

#### Scenario: Capture diagnostics during normal typing
- **WHEN** the user types while status counters or callback timings are collected
- **THEN** the stored/exported data contains timing and status metadata without the typed content
- **AND** no runtime ledger write, network request, or document capture is required for composition
