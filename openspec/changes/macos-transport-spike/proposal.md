# Native macOS transport prototype

## Why

The reusable planner cannot prove that macOS applications apply generated events correctly.
Prove the no-underline replacement path in Son's required apps before implementing the complete Telex engine.

## What Changes

- Add a user-session event tap, generated-event tagging, and explicit key pairing.
- Add ordered replacement for synthetic `as` → `á` and `aa` → `â` examples.
- Add context invalidation, permission status, pause, and bounded lifecycle recovery.
- Prevent replacement when field ownership or the tracked suffix is uncertain; do not attempt blind rollback after a partial send.
- Check native behavior in VS Code, Chrome, Edge, Dia, and Apple Notes, including browser suggestions.
- Record callback own-work timing separately from planner timings.

The prototype keeps composition bounded to its small example rules.
Full Telex, VNI, macros, invalid-word restoration, legacy encodings, and automatic installation are outside this change.

## Capabilities

### New Capabilities

- `native-text-transport`: Ordered ordinary-event replacement with context resets, lifecycle handling, and native acceptance evidence.

### Modified Capabilities

None. Existing planner and development evidence contracts remain in force.

## Impact

Implementation primarily affects `Sources/VietMacPlatform` and `Apps/VietMac`.
It adds native test evidence and measured callback instrumentation.
It requires a usable app identity and user-enabled capabilities for interactive acceptance.
The app must not create marked text or composition underline.
No compatibility claim is complete until each required field family has native evidence.

## Completion and follow-on

The gate requires every field in the native matrix to pass, with exact text, caret, selection, and preservation checks.
Model checks and a successful build do not satisfy this gate.
The follow-on `telex-input-mvp` change adds the language engine and daily-use acceptance after M0 passes.
Both changes describe planned behavior; this proposal does not establish runtime compatibility.
