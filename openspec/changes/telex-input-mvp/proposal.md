# Personal Telex input MVP

## Why

VietMac currently plans edits between known strings but cannot compose Vietnamese from keystrokes.
After the native transport gate passes, Son needs a predictable Telex engine, explicit English mode, and evidence that ordinary editing remains safe in the required apps.

## What Changes

- Add a bounded, instance-local Telex reducer with NFC output, vowel shapes, five tones, case preservation, repeated-modifier escape, and Backspace over visible characters.
- Use Son's selected default `hòa`, `khỏe`, and `thúy` for open `oa`, `oe`, and `uy` syllables.
- Preserve literal brackets and leading `w`; provide explicit English mode for identifiers, URLs, and commands.
- Add menu and configurable shortcut controls, tested-app gating, exclusions, status reasons, preference persistence, and opt-in login startup.
- Integrate the reducer with the M0 transport and its context invalidation policy; remove the prototype's separate language rules.
- Add per-event replay, selected legacy regressions, deterministic randomized model checks, and complete native acceptance for the full engine.
- Measure the complete reducer and callback separately from the existing planner benchmark and native visible latency.

Required application surfaces remain VS Code editor, Find, and quick input; address/search, ordinary input, text area, and rich editing in Chrome, Edge, and Dia independently; and Apple Notes title and body.

VNI, macros, dictionary-based correction, automatic language detection, invalid-word restoration, re-composition of committed words, alternate tone-placement settings, terminal transformation, additional layouts, legacy encodings, public distribution, and an updater are excluded.
English text that resembles Telex requires explicit English mode; this MVP does not promise automatic bilingual inference.

## Capabilities

### New Capabilities

- `telex-composition`: Deterministic semantic-key composition, rendering, editing, literal fallback, and bounded current-word ownership.
- `input-mode-control`: Explicit Vietnamese/English mode, supported-context gating, status, preferences, shortcut, and opt-in startup.
- `telex-mvp-acceptance`: Model regression coverage and native field evidence needed to accept the complete personal input app.

### Modified Capabilities

- `performance-measurement`: Add complete-reducer measurements and MVP latency budgets while retaining planner-only scope and baseline evidence.

## Impact

Implementation extends `VietMacCore`, `VietMacPlatform`, `Apps/VietMac`, core/platform tests, fixtures, replay, benchmarks, and evidence documentation in the existing Swift package.
It introduces no runtime service, network dependency, development-ledger dependency, or copied legacy engine.
Selected OpenKey findings inform regression scenarios; they do not establish defects or correctness in VietMac.

## Dependency and completion gate

Implement in order: `macos-transport-spike` native completion → M1 reducer and replay → M2 integration and controls → M3 personal app acceptance.
This change can be planned now, but its implementation must not bypass M0's required native gate.
M0 evidence does not replace full-engine acceptance.

Completion requires all semantic fixtures and bounded-state checks to pass, no unresolved text-loss or cross-context-edit failure in the required native matrix, verified lifecycle and controls, and Release performance evidence meeting the declared budgets.
An unavailable app, missing native result, or unresolved required-field failure leaves the relevant task pending.
Source completion, app build, specification validation, and the planner benchmark alone cannot establish a working MVP.
