## Purpose

Establish safe ordinary-event replacement and context invalidation in the required macOS application fields before implementing the complete Telex engine.

## ADDED Requirements

### Requirement: Ordinary event replacement
The host SHALL apply the synthetic Telex example replacements through ordinary generated events without marked text or clipboard mutation.

#### Scenario: Apply acute accent
- **WHEN** the enabled prototype receives `s` after its tracked `a` in a supported field
- **THEN** the field displays `á` without an extra `s` or composition underline
- **AND** surrounding text remains unchanged

#### Scenario: Apply circumflex
- **WHEN** the enabled prototype receives a second `a` after its tracked `a`
- **THEN** the field displays `â` without a second literal `a` or composition underline

#### Scenario: Replace a multi-character suffix
- **WHEN** the native synthetic transport harness requests `tieng` to become `tiêng` in a controlled tracked context
- **THEN** the field contains `tiêng` with its surrounding text preserved
- **AND** the caret ends immediately after the replaced word

### Requirement: Prepared and serialized transport
The host MUST prepare all output events before posting deletions and MUST preserve replacement order.

#### Scenario: Event preparation fails
- **WHEN** the host cannot prepare the complete edit
- **THEN** it preserves the original physical event and invalidates tracked composition before posting any deletion

#### Scenario: Generated events return to the tap
- **WHEN** an event carries the host's per-process marker
- **THEN** the host passes it through without applying composition again

#### Scenario: Context becomes stale before replacement
- **WHEN** the tracked context is invalidated after planning but before the first generated deletion
- **THEN** the host posts no replacement events and preserves the original physical event
- **AND** it starts no new composition from the stale tracked word

#### Scenario: A send becomes uncertain after deletion starts
- **WHEN** a partial send or context change is detected after replacement begins
- **THEN** the host clears tracked composition and pauses transformation
- **AND** it does not send a guessed rollback into the document

### Requirement: Physical event pairing and repeat
The host SHALL preserve the defined down/up policy for ordinary, consumed, repeated, and generated events without duplicate insertion or recursive transformation.

#### Scenario: Modifier key is consumed
- **WHEN** the physical `s` key-down transforms tracked `a` into `á`
- **THEN** its matching key-up is handled without leaking an extra text-producing event
- **AND** following physical keys remain in their original order

#### Scenario: Ordinary key repeats
- **WHEN** an ordinary pass-through letter produces autorepeat key-down events
- **THEN** each repeat appears once and its eventual key-up does not remove or duplicate text

### Requirement: Context invalidation and lifecycle
Observed context changes SHALL invalidate tracked state independently of per-app language preferences.
Tap loss and capability loss SHALL pause or reset transformation while preserving ordinary input where the OS permits it.

#### Scenario: Navigation leaves the tracked word
- **WHEN** navigation or a selection/edit shortcut changes the expected caret context
- **THEN** subsequent modifiers do not replace text from the invalidated word

#### Scenario: Timeout notification arrives
- **WHEN** the tap receives a disabled-by-timeout notification
- **THEN** the host handles it before keyboard-field access and clears composition before controlled recovery

#### Scenario: Same-app field changes
- **WHEN** focus, selection, or caret changes are observed inside the same application
- **THEN** the host invalidates the old tracked word before applying another transformation
- **AND** it does not treat an unchanged application identity as proof of text ownership

#### Scenario: Selection ownership is uncertain
- **WHEN** the host detects an external edit or cannot establish a safe tracked suffix after a selected suggestion
- **THEN** it preserves ordinary input and performs no guessed suffix deletion
- **AND** the field remains unaccepted until native evidence establishes safe transformation there

### Requirement: Capability and recovery status
The prototype SHALL expose active, disabled, and paused status with the reason for a pause. Missing capabilities, secure input, and repeated tap loss SHALL prevent transformation and clear composition.

#### Scenario: Permission or secure-input condition prevents transformation
- **WHEN** an input capability is lost or secure input is detected
- **THEN** transformation pauses and ordinary input remains available where the OS permits it
- **AND** the menu identifies the condition without prompting from the key callback

#### Scenario: Timeout recovery is bounded
- **WHEN** three automatic timeout recoveries have occurred within 60 seconds and another timeout arrives
- **THEN** the host remains paused until explicit user resume
- **AND** any successful resume begins with an empty tracked word

#### Scenario: Sleep or wake interrupts composition
- **WHEN** the user session sleeps or wakes during an active word
- **THEN** the old word is invalidated before transformation resumes

### Requirement: Explicit native acceptance evidence
The prototype SHALL establish real field behavior in VS Code, Chrome, Dia, Safari, and Apple Notes before native completion.

#### Scenario: Required browser field includes selected suggestions
- **WHEN** native acceptance checks address/search bars in each browser
- **THEN** evidence includes selected autocomplete suggestions and expected versus actual text and caret behavior

#### Scenario: Required field matrix is evaluated
- **WHEN** the prototype is evaluated for native completion
- **THEN** evidence covers VS Code editor, Find, and quick input; address/search, ordinary input, text area, and rich editing in each of Chrome, Dia, and Safari; and Apple Notes title and body
- **AND** each field includes exact text, caret/selection, case, Backspace, shortcuts, undo/redo, and surrounding-text preservation results
- **AND** records identify OS, app version, input source, profile, and relevant autocomplete settings using synthetic text

#### Scenario: Preservation requirements are checked
- **WHEN** native replacement runs next to existing text or formatting
- **THEN** the clipboard, surrounding content, and existing formatting remain unchanged
- **AND** no marked text, composition underline, or invisible sentinel is introduced

#### Scenario: A required field has no result
- **WHEN** any required app or field family lacks native evidence
- **THEN** its acceptance task remains pending and the change is not archived as complete

### Requirement: Callback measurement isolation
The callback SHALL collect only bounded timing data and SHALL export evidence outside the key path.

#### Scenario: Export timing evidence
- **WHEN** the developer captures a callback measurement
- **THEN** the report identifies callback own-work separately from planner and visible native latency
- **AND** ledger and disk writes occur outside the callback
