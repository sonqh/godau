# Replacement Planning

## Purpose

Provide reusable, bounded edits between the previous and desired tracked word.
This capability plans text changes. It does not establish native document ownership or implement Telex.

## Requirements

### Requirement: Minimal tracked suffix replacement
The planner SHALL retain the common grapheme prefix and return the deletion count and insertion text for the remaining suffix.

#### Scenario: Add a tone to a composed vowel
- **WHEN** the previous word is `tiêng` and the desired word is `tiếng`
- **THEN** the plan deletes three logical characters and inserts `ếng`
- **AND** applying that plan to the simulated previous text produces `tiếng`

#### Scenario: Keep unchanged text
- **WHEN** the previous and desired words are identical
- **THEN** the plan has zero deletions and an empty insertion

### Requirement: Canonical and bounded input
The planner SHALL reject non-NFC input and tracked words above the configured limit.
The configured limit MUST be between one and 64 logical characters.
Encoded input MUST remain within the bounded UTF-16 allowance before normalization.

#### Scenario: Reject canonically equivalent decomposed text
- **WHEN** the previous input contains `a` followed by combining acute accent
- **THEN** the planner rejects the input as noncanonical rather than accepting Swift's canonical string equality

#### Scenario: Reject overflow without truncation
- **WHEN** a tracked word exceeds 64 logical characters
- **THEN** the planner reports a word-limit error instead of silently removing earlier characters

### Requirement: Logical deletion count
The planner SHALL count deleted graphemes independently of encoded UTF-16 length.

#### Scenario: Delete a multi-unit grapheme
- **WHEN** the previous test string is `a👩🏽‍💻` and the desired test string is `a`
- **THEN** the planner deletes one grapheme
- **AND** the test does not imply that the future Telex engine tracks emoji
