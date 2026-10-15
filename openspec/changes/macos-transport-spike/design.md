# Native transport prototype design

## Context

The app currently contains a menu bar shell and capability inspection.
The core provides a checked suffix planner and semantic contracts, with no complete Telex reducer.
Native text replacement, focus tracking, and callback timing have no current implementation evidence.

## Goals / Non-Goals

**Goals:** prove ordered plain-text replacement, recursion protection, context resets, and user-visible lifecycle status.
Use the required field matrix as the completion gate.

**Non-Goals:** a complete language engine, InputMethodKit, macro expansion, previous-word restoration, an updater, or installation automation.

## Decisions

Use one owning run loop for the tap, prototype state, and prepared transport.
Keep OS objects in `VietMacPlatform`, presentation in the app, and the planner independent of OS event frameworks.
The prototype must not grow into a second production engine.

Tag generated events with a per-process marker and preserve physical key-down/key-up policy.
Create every generated event before posting a deletion.
Use ordinary Backspace and Unicode payload events initially, without marked text or clipboard mutation.

Invalidate state on observed navigation, selection, shortcuts, app changes, input-source changes, and lifecycle loss.
Treat programmatic focus and autocomplete edits as native compatibility uncertainties.
Investigate Accessibility notifications only when an actual field reproduction requires them.

Track predicted text and context generation separately from physical keycodes and UTF-16 payload lengths.
Immediately before sending, reject a stale generation or known selection/focus uncertainty without deleting text.
After a partial send or detected external edit, invalidate composition and pause transformation; do not send a guessed repair.
An unchanged PID or generation alone is not proof that a field still owns the tracked suffix.

Use an explicit consumed-key policy for autorepeat and matching key-up events.
Check lifecycle notification types before accessing keyboard fields.
Allow at most three automatic timeout recoveries in a rolling 60-second interval; further losses require explicit user resume.
Do not automatically recover from a user-disabled tap, missing capability, or secure-input condition until that condition clears.
Resume always starts with an empty tracked word.

Instrument callback own-work with bounded counters and timing samples.
Publish snapshots outside the callback. No disk or ledger writes belong in that path.
Compare this scope with the planner baseline without combining their numbers.

### Native automation

`VietMacDriver.app` is a test-only app that posts scripted key events at the HID tap, so the session tap handles them like keyboard input.
`scripts/native_run.py` drives a browser fixture in automation mode, runs the driver, and compares field values, the page event log, and VietMac counters.
The driver types only while the expected app is frontmost with an ABC or U.S. source, and it releases held keys on every exit.
Record this evidence as native automation, separate from physical typing. It reproduces rollover, context changes, and long workloads repeatably.
Acceptance tasks 3.2–3.5 still require physical typing spot checks for each required app, recorded beside the automated rows.

## Risks / Trade-offs

- An event post has no document acknowledgement. A successful call is not insertion evidence.
- A selected browser suggestion can change what Backspace deletes.
- Cached focus and app identity may lag or differ from renderer/helper process identities.
- Secure input or revoked capabilities can suspend event handling.
- Undo grouping and rich-text formatting can differ even when the visible word is correct.

Record each failure with synthetic input, app/OS versions, input source, field, profile, and expected versus actual text.
Add a targeted transport override only after the reproduction establishes its need.
Do not claim native completion with a missing field result.

## Completion gate

All tasks, including real typing and caret/selection checks, must pass before archive.
If a required field remains unreliable, retain the active change and report the limitation to Son.
Test same-app field switches, observed programmatic focus/selection changes, selected browser suggestions, and edits not produced by the prototype.
Check a multi-character insertion through a synthetic transport harness in addition to the two prototype rules.
Record exact text, caret, selection, formatting, clipboard preservation, and undo/redo round-trip behavior.
Native records must use synthetic text and identify OS, app version, field, input source, profile, autocomplete settings, and result.
Missing results stay `not-run`; an unavailable required app does not reduce the required matrix.
The resulting implementation can then support `telex-input-mvp` (M1 through personal MVP acceptance).
