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

### Requirement: Prepared and serialized transport
The host MUST prepare all output events before posting deletions and MUST preserve replacement order.

#### Scenario: Event preparation fails
- **WHEN** the host cannot prepare the complete edit
- **THEN** it preserves the original physical event and invalidates tracked composition before posting any deletion

#### Scenario: Generated events return to the tap
- **WHEN** an event carries the host's per-process marker
- **THEN** the host passes it through without applying composition again

### Requirement: Context invalidation and lifecycle
Observed context changes SHALL invalidate tracked state independently of per-app language preferences.
Tap loss and capability loss SHALL pause or reset transformation while preserving ordinary input where the OS permits it.

#### Scenario: Navigation leaves the tracked word
- **WHEN** navigation or a selection/edit shortcut changes the expected caret context
- **THEN** subsequent modifiers do not replace text from the invalidated word

#### Scenario: Timeout notification arrives
- **WHEN** the tap receives a disabled-by-timeout notification
- **THEN** the host handles it before keyboard-field access and clears composition before controlled recovery

### Requirement: Explicit native acceptance evidence
The prototype SHALL establish real field behavior in VS Code, Chrome, Edge, Dia, and Apple Notes before native completion.

#### Scenario: Required browser field includes selected suggestions
- **WHEN** native acceptance checks address/search bars in each browser
- **THEN** evidence includes selected autocomplete suggestions and expected versus actual text and caret behavior

#### Scenario: A required field has no result
- **WHEN** any required app or field family lacks native evidence
- **THEN** its acceptance task remains pending and the change is not archived as complete

### Requirement: Callback measurement isolation
The callback SHALL collect only bounded timing data and SHALL export evidence outside the key path.

#### Scenario: Export timing evidence
- **WHEN** the developer captures a callback measurement
- **THEN** the report identifies callback own-work separately from planner and visible native latency
- **AND** ledger and disk writes occur outside the callback
