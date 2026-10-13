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
Keep OS objects in `SonKeyMac`, presentation in the app, and the planner independent of OS event frameworks.
The prototype must not grow into a second production engine.

Tag generated events with a per-process marker and preserve physical key-down/key-up policy.
Create every generated event before posting a deletion.
Use ordinary Backspace and Unicode payload events initially, without marked text or clipboard mutation.

Invalidate state on observed navigation, selection, shortcuts, app changes, input-source changes, and lifecycle loss.
Treat programmatic focus and autocomplete edits as native compatibility uncertainties.
Investigate Accessibility notifications only when an actual field reproduction requires them.

Instrument callback own-work with bounded counters and timing samples.
Publish snapshots outside the callback. No disk or ledger writes belong in that path.
Compare this scope with the planner baseline without combining their numbers.

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
The resulting implementation can then support the full engine change M1.
