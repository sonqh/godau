# Spec Delta

## Purpose

Defines which focused fields receive Vietnamese transformation, the assurance level each field gets from what it reports at run time, and how exclusions and evidence labels apply.

## ADDED Requirements

### Requirement: Coverage without an application list
Transformation SHALL be available in every application that the user has not excluded. No compiled list of applications SHALL gate transformation. The other gates (capabilities, secure input, input source, mode) SHALL keep their behavior.

#### Scenario: Application outside the required five
- **WHEN** Vietnamese mode is selected and the user focuses a text field in an application that is not VS Code, Chrome, Dia, Safari, or Apple Notes
- **THEN** transformation can become active without a code or configuration change

#### Scenario: Excluded application
- **WHEN** the frontmost application is in the user's exclusions
- **THEN** every key passes through, no generated event is posted, and the status is Standby `excludedApp`
- **AND** no tracked word carries into or out of that application

### Requirement: Assurance from field capability
The platform SHALL choose the assurance level for each focused element from what the element reports. A text-entry element that reports a collapsed caret and a character count SHALL use `observed`. A text-entry element that does not support the selected-range or character-count attribute SHALL use `eventOnly`. The choice SHALL be made outside the key callback and SHALL NOT read a field value, selected text, title, or URL.

#### Scenario: Field reports caret and count
- **WHEN** the focused text field reports a collapsed caret and a character count
- **THEN** the status is `active(observed)`
- **AND** a replacement requires a settled observation, as in the five required applications

#### Scenario: Field has a text role but no readable range
- **WHEN** the focused element has a text-entry role and does not support the selected-range attribute
- **THEN** the status is `active(eventOnly)`
- **AND** a replacement is sent from key events alone

#### Scenario: Field reports a selection
- **WHEN** an `observed` field reports a non-collapsed selection
- **THEN** the tracked word is invalidated and no replacement is sent until a collapsed caret is read

### Requirement: Non-text focus stays literal
When the focused element is not a text-entry element, or no focused element can be read, every key SHALL pass through and the platform SHALL post no generated event. The status SHALL be Standby `noTextField`.

#### Scenario: Focus is a list
- **WHEN** Vietnamese mode is selected and the focus is a message list, a file list, or a button
- **THEN** typing `as` delivers `a` and `s` unchanged and posts no Backspace

#### Scenario: Application reports no focused element
- **WHEN** the frontmost application does not report a focused element
- **THEN** keys pass through and the status is Standby `noTextField`

### Requirement: Secure fields are never transformed
A field with the secure text subrole, and any context with secure input active, SHALL receive literal input under every assurance level.

#### Scenario: Password field in an unknown application
- **WHEN** the focused element has the secure text subrole in an application outside the required five
- **THEN** keys pass through and no tracked word exists

### Requirement: A failed read does not select eventOnly
A failed or timed-out Accessibility read SHALL NOT select `eventOnly`. The context SHALL stay uncertain and literal until a read succeeds. An element that has reported a caret since it gained focus SHALL stay `observed` until focus changes.

#### Scenario: Read times out on focus
- **WHEN** the first read of a newly focused text field times out
- **THEN** keys pass through and the status is Standby `fieldUnreadable`
- **AND** the next successful read selects the assurance level

#### Scenario: Observed field stops answering
- **WHEN** a field that reported a caret later fails a read
- **THEN** the tracked word is invalidated and the field does not change to `eventOnly`

### Requirement: Event-only safety
Under `eventOnly` the platform SHALL end the tracked word on a focus change, an application change, a mouse button press, a navigation key, a modifier chord, an input source change, and sleep. It SHALL delete only characters typed since the last such reset. It SHALL NOT insert invisible characters, use the clipboard, or create marked text.

#### Scenario: Click inside an event-only field
- **WHEN** the user types `a`, clicks elsewhere in the same field, and types `s`
- **THEN** `s` is delivered unchanged and no Backspace is posted

#### Scenario: Replacement in an event-only field
- **WHEN** the user types `a` then `s` without a reset in between
- **THEN** one Backspace and `á` are posted

### Requirement: Identified field profiles take precedence
A field identified as a browser address bar or as the VS Code default-mode editor SHALL keep the behavior of its profile, whatever the field reports. Capability selection SHALL apply only to fields that match no identified profile.

#### Scenario: Chrome address bar
- **WHEN** the focused element is identified as the Chrome address bar
- **THEN** the `addressBar` profile applies, including its completion-clearing key

### Requirement: Status reports the assurance level
The published status SHALL report `active(observed)` or `active(eventOnly)` for the focused field. The platform SHALL NOT publish `unsupportedApp`. Diagnostics SHALL count event-only replacements and SHALL contain no typed text.

#### Scenario: Move between two fields
- **WHEN** focus moves from an `observed` field to an `eventOnly` field
- **THEN** the published availability changes from `active(observed)` to `active(eventOnly)`

### Requirement: Exclusion for any application
The menu SHALL offer `Tắt tiếng Việt trong <App>` for every frontmost application that has a bundle ID. The Apps tab SHALL list the required applications and every excluded application, and SHALL NOT scan installed applications.

#### Scenario: Exclude an application outside the required five
- **WHEN** an application outside the required five is frontmost and the user chooses `Tắt tiếng Việt trong <App>`
- **THEN** its bundle ID is stored in the exclusions and the configuration is applied
- **AND** the Apps tab shows a row for it with `Gõ tiếng Việt` unchecked

### Requirement: Evidence labels are separate from availability
The product SHALL label a field family as tested only when native evidence exists for it. Every other application and field SHALL be labeled untested. A missing label SHALL NOT disable transformation. Model checks SHALL NOT change a label.

#### Scenario: Untested application works
- **WHEN** transformation is active in an application with no native evidence
- **THEN** the Apps tab and documents make no tested claim for that application

### Requirement: Native acceptance outside the required five
The change SHALL be complete only when native evidence shows a replacement in one `observed` field and one `eventOnly` field in applications outside the required five, and literal input in one non-text focus. The evidence SHALL name the application, its version, and the macOS version, and SHALL contain no typed content beyond the scripted test words.

#### Scenario: Native evidence is missing
- **WHEN** model tests pass and no native run exists for an application outside the required five
- **THEN** the native tasks stay pending and the change is not archived
