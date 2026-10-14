# M0 implementation and pending native acceptance

## Status on 2026-10-13

The M0 host and prepared transport compile, and the synthetic core/platform tests pass.
The app starts disabled and implements only `as` → `á` and `aa` → `â`, preserving the first letter's actual case.
It is not the complete Telex engine. No required application field has native typing evidence yet.

The specification commit was pushed as `215e810` before this implementation work.
The implemented source milestone follows that commit; Git history identifies the final implementation commit.

## Session 2 update on 2026-10-14

Task 2.2 context handling is implemented at model level and still awaits native reproduction.

| Command | Result | Scope |
| --- | --- | --- |
| `make check` | Pass | Five strict OpenSpec items, five ledger tests, 35 platform/4 core Swift model tests, six replay fixtures |
| `make test-sanitize` | Pass | The same 39 tests with AddressSanitizer |
| `make app` | Pass | Release bundle, ad hoc signature, CDHash `39f8ee86b43a5d0ed9cfaabae5ce4da2b70c723c` |
| `open .artifacts/VietMac.app --args --evidence-dir <abs>/.artifacts/native/session-1` | Pass | Launch Services session pid 97627 wrote `session-diagnostics.json` |

The session snapshot reported `accessibility`, `eventListening`, and `eventPosting` all false, state `disabled`, no tap, ABC input source, and secure input off.
This is the actual app session, not the terminal-invoked diagnostics process. Native typing remains blocked on Son granting Accessibility and Input Monitoring to this exact build.
Ad hoc signing ties the grant to this CDHash. Any rebuild requires re-granting, so the build was frozen after this snapshot.

### Native attempts in session 2

| Step | Result | Evidence |
| --- | --- | --- |
| Son granted Input Monitoring, then Accessibility, to the ad hoc build | Pass | Session pid 98941: `accessibility`, `eventListening`, `eventPosting` all true; tap installed; prototype enabled from the menu |
| Chrome 155 ordinary input, `LEFT ` + space + `as` (cases 1 and 1b) | **Fail (safe)** | Field showed `LEFT as RIGHT`, caret after `as`; no deletion; `replacementsPosted` 0 |
| Counter delta for case 1b | Diagnostic | `focusChanges` +22, `unexplainedFieldChanges` +6, `laggingObservations` +5, `unsettledTriggers` 0 |
| Rebuild signed with a self-signed `VietMac Local Signing` certificate (not trusted) | Built | Designated requirement: identifier plus certificate leaf `d53f4c1f…` |
| Grant to the certificate-signed build after removing and re-adding entries | **Fail** | Sessions pid 1684 and 1841 reported all three capabilities false |

Inferred cause of the Chrome failure: nearly every 250 ms poll reported a focused-element change, so the tracked word was invalidated before `s`. The ad hoc build lacked the metadata to confirm this.
Inferred cause of the signing failure: TCC on this macOS build did not honor the untrusted self-signed certificate. `tccd` log details are redacted.
Son stopped the session at this point. OpenKey's helper (`com.tuyenmai.OpenKeyHelper`) was running and must be quit before the next native session.

The current build adds a bounded 64-entry observation trace to `session-diagnostics.json`: source (poll, notification, refresh), role, element hash, focus-change flag, reading or unavailable reason, caret, length, comparison result, keys since the previous observation, and pending/settled state. It contains no text or key identity.
The app now ignores `SIGUSR1` when started without `--evidence-dir`; the earlier build terminated on a stray signal once in this session.

### Native attempts in sessions 3–5 (2026-10-14)

Son trusted `VietMac Local Signing` for code signing. Rebuilt binaries keep Accessibility, listening, and posting without a new grant.
OpenKey was quit. Its login-item helper stays alive under launchd but has no event tap (`CGGetEventTapList`).
Chrome tests used `Fixtures/native-fields.html` served from `127.0.0.1`, with a page event log of key and input events.

| Step | Result | Evidence |
| --- | --- | --- |
| Chrome ordinary input, space + `as`, `a` released before `s` (session 4) | Pass | Field `LEFT  á RIGHT` (U+00E1), caret 7; page log: Backspace, `keydown key="á" code=KeyA`, `insertText "á"` |
| Chrome `as`, two attempts (session 3) | **Fail (data loss)** | `as` removed, no `á`; `replacementsPosted` 2 |
| Chrome text area, space + `as` five times (sessions 4 and 5) | **Fail (data loss) once per run** | First trigger: `as` removed, no `á`; the other four stayed literal with `unsettledTriggers` +4 |

Session 5 page log for the failed trigger: `a` keydown, Backspace keydown/keyup, then one `a` keyup. Chrome received no keydown for the generated `á`.
The physical `a` was still down when `s` was pressed (key rollover). In the passing case, `a` was released before `s`.
Inferred cause: the generated insertion uses virtual key 0 (`kVK_ANSI_A`). While the physical `A` key is held, the system or Chrome drops that keydown, and the generated keyup releases `A`.
The transport therefore deletes and never inserts. The tracker kept the insertion pending (`lagging`) for every later observation, which blocked later triggers but did not pause or report the loss.
The app now writes `disable-<n>-session-diagnostics.json` when the prototype is disabled from the menu, so the trace covers the trial just typed.

Fix: the generated insertion now uses the consumed trigger key's virtual keycode (for `as`, `kVK_ANSI_S`). The client never saw that key go down.
After a replacement, the tracker settles a quiet field (500 ms after the last tracked key) at its final prediction. This resolves the `a` → `á` same-length ambiguity.
If the replacement is still unexplained after that quiet period, the host counts `replacementsUnconfirmed` and pauses with `transportUncertain`.

### Native attempts in session 6 (2026-10-14)

| Step | Result | Evidence |
| --- | --- | --- |
| Chrome text area with Apple Vietnamese Simple Telex active | Not a VietMac test | Text came from Apple's IME (`insertCompositionText`, `composing=true`); VietMac paused for the unsupported source with `replacementsPosted` 0 |
| Chrome text area, ABC, fast space + `as` five times | **Pass** | `LEFT  RIGHT á á á á á ` (U+00E1 each). `replacementsPosted` 5, `replacementsUnconfirmed` 0, `unsettledTriggers` 0, state still active |
| Rollover on the first trigger | Pass | `a` keydown, Backspace, `keydown key="á" code=KeyS`, `insertText "á"`, then the physical `a` keyup about 120 ms later |

This passes one Chrome text-area row only. It does not complete the Chrome, Edge, and Dia matrix in task 3.3.

## Local verification (session 1)

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

The host observes app/source changes, navigation, edit chords, click/drag, lifecycle loss, AX focus/window/selection/value notifications, and polled focus metadata.
It reads the selected range and `AXNumberOfCharacters` only. It reads no document text and writes no typed-content records.

`FieldContextTracker` predicts the field's UTF-16 caret and length after each pass-through key, generated Backspace, and generated insertion.
`ContextPolicy` applies observations on the owning run loop:

- A caret/length that no prediction explains (for example, a same-caret script edit that changes the length, or a caret move at the same length) invalidates the tracked word.
- A focused-element change invalidates even when the new field's metadata matches the prediction, so an unchanged PID is never treated as field ownership.
- A non-empty selection (including inline autocomplete) or missing caret/length pauses with `uncertainContext` and invalidates.
- A replacement requires a settled tracker: an unambiguous observation after every tracked key matched the prediction. Otherwise the trigger key passes through literally and the word stays literal until a boundary.
- An observation that matches several predictions (a revisited state such as net-zero `a` → `á`, or a letter and Backspace) assumes the earliest match and does not settle.
- Return, Tab, Enter, navigation, edit chords, and untracked Backspace clear the baseline; the next observation re-establishes it.

Remaining limits, documented rather than solved:

- A same-length, same-caret external edit is indistinguishable from the predicted state by metadata.
- A change after the last observation and before the trigger key cannot be detected without an AX read in the key path. The callback does no AX reads.
- A key processed after a reset but before the re-baselining observation can make that observation look settled. Event order still places generated events after it.
- Fields without `AXNumberOfCharacters` or a selected range stay paused. Electron and browser fields may lack timely notifications; the 250 ms poll is the fallback, so fast typing may leave triggers literal.
- Programmatic focus changes are detected only when the focused element or its notifications change.

Task 2.2 stays pending until the native reproductions below confirm the counters and text outcomes.
`contextCounters` in the session snapshot counts focus changes, selections, unavailable fields, lagging observations, unexplained changes, unsettled triggers, stale/uncertain sends, and posted replacements. It contains no text.
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

## Native session procedure

The app accepts `--evidence-dir <absolute path>`. It writes `session-diagnostics.json` and `callback-timings.json` at launch and whenever it receives `SIGUSR1`.
The write runs on the main queue outside the key callback. Send the signal between cases, not while typing.

```sh
open .artifacts/VietMac.app --args --evidence-dir "$PWD/.artifacts/native/session-1"
kill -USR1 "$(pgrep -f 'VietMac.app/Contents/MacOS/VietMac')"
```

Task 2.2 reproductions with [the synthetic fields](../../Fixtures/native-fields.html), one browser at a time:

| Case | Steps | Expected |
| --- | --- | --- |
| Baseline | Click after `LEFT `, type space, `as` | `á` replaces `a`; `replacementsPosted` +1 |
| Same-caret external edit | Click Change ordinary input, return caret, type `a`, wait for the edit, type `s` | Content stays `EXTERNAL CONTENT` plus literal `as`; `unexplainedFieldChanges` +1; no deletion |
| Same-app focus switch | Click Focus the second input, type `a` in the first field, wait, type `s` | Second field receives literal `s`; first field keeps `a`; `focusChanges` +1 |
| Synthetic selection | Click Select a synthetic completion, type `s` | Selection replaced by `s` as ordinary input; `selectionsObserved` +1; no extra deletion |
| Fast typing | Type `as` quickly ten times separated by spaces | Record each result; literal `as` with `unsettledTriggers` is a safe failure, not a pass |

Task 2.3 workload: enable the prototype, type the ordinary-input workload for at least 1,000 key events, then send `SIGUSR1`. Record sample count, environment, and percentiles as callback own-work only.

## Next native session

Decide the signing path first: trust the local certificate for code signing (Son's keychain decision) or rebuild ad hoc and re-grant after each rebuild.
Then repeat case 1b in Chrome and read `observationTrace` to confirm or reject the element-identity hypothesis before changing the focus comparison.


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
