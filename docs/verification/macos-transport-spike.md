# M0 implementation and pending native acceptance

## Status on 2026-10-13

The M0 host and prepared transport compile, and the synthetic core/platform tests pass.
The app starts disabled and implements only `as` → `á` and `aa` → `â`, preserving the first letter's actual case.
It is not the complete Telex engine. No required application field has native typing evidence yet.

The specification commit was pushed as `215e810` before this implementation work.
The implemented source milestone follows that commit; Git history identifies the final implementation commit.

## Local verification

| Command | Result | Scope |
| --- | --- | --- |
| `make check` | Pass | Five strict OpenSpec items, five ledger tests, 25 Swift model tests, and six synthetic replay fixtures |
| `make test` | Pass | 21 new platform tests and 4 existing core tests |
| `make test-sanitize` | Pass | The same 25 tests with AddressSanitizer; no reported address errors |
| `make app` | Pass | Release app/bundle build; local signature verification is reported by the build script |
| `.artifacts/VietMac.app/Contents/MacOS/VietMac --diagnostics` | Pass | Read-only capability/environment snapshot; no event tap or native typing |
| `open .artifacts/VietMac.app` | Pass | Launch returned successfully and the app process was detected; menu/UI behavior was not inspected |

The synthetic transport checks create CGEvents and inspect their ordering, markers, key pairing, and Unicode payloads. They do not post into a real application.
Preparation failure at every stage of an `a` → `á` edit posts nothing.
Stale context posts nothing; injected partial-send uncertainty stops without a guessed rollback.
The model tests cover case, ordinary/consumed autorepeat, capability loss, secure input, bounded timeout recovery, 64-character overflow, and ownership resets.
Initial compile checks exposed Swift concurrency/Boolean bridging and test-macro issues; these were corrected before the passing checks above.
Existing CLT linker-search-path and Swift Testing deployment-floor warnings remain. The checks ran on the current host; older macOS and Intel remain unverified.

## Native blockers and environment

The read-only snapshot reported macOS 27.0.1 (26A434), ABC input source, secure input off, and `local.sonquach.vietmac` as the bundle identity.
Accessibility, event listening, and event posting were all unavailable to the invoked process.
This result describes the diagnostics invocation; a Launch Services/native session must record its own enabled capabilities.

| Required app | Detected version | Native status |
| --- | --- | --- |
| VS Code | 1.141.0 | Not run; input capabilities unavailable |
| Chrome | 155.0.8059.40 | Not run; input capabilities unavailable |
| Edge | Not registered with the queried bundle identity | Not run; app unavailable in the inspected inventory |
| Dia | 1.52.0 | Not run; input capabilities unavailable |
| Apple Notes | 4.13 | Not run; input capabilities unavailable |

No permission was requested or granted, no input source was changed, and no application was installed.
The app was opened for a startup smoke check. Computer Use then refused access with `Computer Use was not approved to use VietMac`; UI inspection and native automation were not performed.
Son requested instructions for granting permissions, then requested this commit and an agent handoff. No subsequent capability or Computer Use approval is assumed.
Ad hoc local signing does not establish TCC permission continuity across rebuilds.
Native task 3.1 stays pending until a stable test build/session and enabled capabilities are recorded.

## Context implementation and limits

All input/composition/transport state has one owning main run loop. Generated events use an instance marker and bypass reduction.
Consumed repeats and releases remain owned after composition invalidation or pause; a new physical press clears stale ownership even when transformation is paused.
Ordinary held-letter repeats pass through without applying the double-`a` rule.
The callback handles tap-loss notifications before reading keyboard fields and collects only bounded timing samples.
Menus, settings, capability checks, app/source lookup, AX inspection, and timing serialization occur outside the key callback.

The host observes app/source changes, navigation, edit chords, click/drag, lifecycle loss, AX focus/selection notifications, and polled focus/selected-range metadata.
It reads no document text and writes no typed-content records.
Cached focus/caret metadata cannot prove that the field still contains the predicted suffix. In particular, same-caret programmatic edits and notifications that arrive after the next key remain unresolved.
Task 2.2 is partially implemented and stays pending for external-edit handling and its focused/native reproductions.
A successful void event-post call is not a client acknowledgement; delivery and undo/formatting behavior remain native questions.

No real callback timing was captured. Task 2.3 stays pending; bounded-ring tests and model durations are not Release callback performance evidence.
The timing export retains at most 1,024 durations and separately reports total observed sample count. A zero-sample report is not a measurement.

## Native field matrix

Every row below is `not-run`. M0 completion requires exact text, caret/selection, surrounding-content preservation, case, Backspace, shortcuts, undo/redo, and context/autocomplete results in the actual field.

| App | Field | Status |
| --- | --- | --- |
| VS Code | Editor | not-run |
| VS Code | Find | not-run |
| VS Code | Quick input | not-run |
| Chrome | Address/search | not-run |
| Chrome | Ordinary input | not-run |
| Chrome | Text area | not-run |
| Chrome | Rich editing | not-run |
| Edge | Address/search | not-run |
| Edge | Ordinary input | not-run |
| Edge | Text area | not-run |
| Edge | Rich editing | not-run |
| Dia | Address/search | not-run |
| Dia | Ordinary input | not-run |
| Dia | Text area | not-run |
| Dia | Rich editing | not-run |
| Apple Notes | Title | not-run |
| Apple Notes | Body | not-run |

For each case, record OS/architecture, app version, input source, mode, transport profile, autocomplete settings, synthetic sequence, expected/actual text, caret/selection, and pass/fail/not-run.
Keep clipboard preservation, no underline, no invisible sentinel, formatting, and undo/redo grouping explicit.
Use [the local synthetic browser fields](../../Fixtures/native-fields.html) for page input, rich editing, programmatic focus, and external-edit reproductions.
Browser address bars and real selected autocomplete suggestions need independent tests; the page fixture does not substitute for them.
The prototype's two rules are not full-engine acceptance evidence.

## Next native session

1. Give Son manual permission instructions for the locally signed `.artifacts/VietMac.app` at a stable path. Son enables Accessibility/Input Monitoring; confirm actual posting capability as well. Computer Use access is a separate prerequisite for automated UI checks.
2. Use ABC or U.S. and one Vietnamese event-transforming app. Open synthetic documents/fields and enable the M0 prototype from its menu.
3. Exercise `as`, `aa`, case, Backspace, held keys, focus/selection, and surrounding text. Record failures before adding a transport/context override.
4. Resolve task 2.2 from concrete external-edit/selection reproductions and collect Release callback timing outside the callback.
5. Complete the remaining required apps, lifecycle checks, and matrix before declaring M0 complete or implementing `telex-input-mvp`.

The agent must not grant permissions, install Edge, change system input sources, or accept developer licenses on Son's behalf.

## Handoff completion boundary

The active change is `macos-transport-spike`, with tasks 1.1, 1.2, and 2.1 complete (3/11).
Continue task 2.2 with focused external-edit/context reproductions, then collect actual Release callback evidence for task 2.3 and complete the native acceptance matrix.
Record failed and not-run cases as well as passes. If access remains blocked, complete independent source/model work and report the exact missing capability or app.
The follow-on `telex-input-mvp` remains at 0/23 tasks. Do not begin its full reducer until the M0 native gate passes, and do not archive M0 while required native evidence is missing.
