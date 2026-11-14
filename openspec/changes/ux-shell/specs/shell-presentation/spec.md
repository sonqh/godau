# Shell presentation

## Purpose

Keep every surface honest, readable, and consistent: one source of state, two UI languages with one set of copy rules, the macOS 27 system look, and full keyboard and VoiceOver access.

## ADDED Requirements

### Requirement: One source of visible state
Every visible state SHALL be built from `RuntimeStatus` and the shell's own preferences only. The shell SHALL show Vietnamese as working only when availability is `active`. It SHALL NOT switch the input source, quit another app, change a setting in another app, or do blocking work on the main run loop.

#### Scenario: Mode is Vietnamese but posting is missing
- **WHEN** the mode is Vietnamese and availability is `blocked(posting)`
- **THEN** no surface shows `Tiếng Việt: đang bật`

#### Scenario: Status equality test
- **WHEN** the shell test renders a status built with the public initializer
- **THEN** the rendered title, status line, detail line, and action are a pure function of that status and the preferences

### Requirement: Debug status simulator
Debug builds SHALL include a simulator that builds any `RuntimeStatus` with the public initializer and renders it in the real menu, setup, settings, and HUD. The simulator SHALL never call `InputHost` and SHALL NOT be present in Release builds.

#### Scenario: Release build
- **WHEN** `make app` builds the Release bundle
- **THEN** the bundle contains no simulator menu or code path

### Requirement: Two UI languages with fixed terms
The shell SHALL ship complete Vietnamese and English string tables and follow the macOS preferred language order. Every surface SHALL use one language, except `VI`, `EN`, and app names. Strings SHALL follow ux-spec section 9: active voice, one instruction per sentence, numbered steps, at most 20 words per instruction and 25 per description, no dashes or semicolons, no English contractions, and one term per concept from the glossary. Vietnamese text SHALL be precomposed NFC.

#### Scenario: Missing translation
- **WHEN** the string-table test finds a key present in one language and absent in the other
- **THEN** the test fails

#### Scenario: Copy rule check
- **WHEN** the copy test scans the English table
- **THEN** it finds no em dash, en dash, semicolon, contraction, "error", or "failed"

### Requirement: macOS 27 system appearance
The shell SHALL use standard windows, controls, toolbar tabs, system colors, system fonts, and system materials only. The menu bar item SHALL be a template title and template badge with no color, background fill, or custom view. Menu items SHALL have no icons except the mode check mark. No state SHALL depend on color or translucency alone.

#### Scenario: Liquid Glass and transparency settings
- **WHEN** the Liquid Glass slider is at each end, Reduce Transparency is on or off, the appearance is light or dark, and the menu bar background is shown or hidden
- **THEN** every title, badge, menu line, and window text stays readable
- **AND** no surface uses a custom blur, a fixed window radius, or a colored menu bar item

### Requirement: Keyboard and VoiceOver access
Every control SHALL be reachable with Tab, Space, Return, and Esc and have an accessibility label in the current UI language. Esc SHALL close Settings and Help and act as `Để sau` in setup. VoiceOver SHALL announce a UI class change of the menu bar item and a status change in a setup step. Layouts SHALL fit the longer of the two languages and larger system text sizes without truncation.

#### Scenario: Keyboard-only setup
- **WHEN** the user completes setup with the keyboard only and VoiceOver on
- **THEN** every control is reached and named, and no focus trap occurs
