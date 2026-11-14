# Telex input MVP tasks

All tasks are pending. Planning completion is not implementation or native acceptance.
M1 core runs in parallel with the M0 native gate (FG-2, accepted 2026-11-12). M2 integration and M3 acceptance wait for the gate.

## 1. Establish the native prerequisite

- [ ] 1.1 Before starting task group 3, verify `macos-transport-spike` has passed every required native field and preservation check; link its matrix and callback evidence in the MVP handoff, and stop integration if a required row remains failed or not-run. Task group 2 does not wait for this task.
- [ ] 1.2 Run U-4 (native multi-character insertion at 2, 8, 20, and 21 UTF-16 units in the three browsers and Notes) and U-5 (insertion keycode when the trigger is Backspace, with rollover) early in M1; record the results and amend the Core contract or transport limit before task 2.4 if either fails.

## 2. M1 — Semantic composition and replay

- [x] 2.1 Add instance-local typed letter/shape/tone state and transition handling in `VietMacCore`; verify ASCII validation, base/modifier case separation, independent instances, boundary resets, and stale-context rejection with focused core tests.
- [x] 2.2 Implement the shared NFC renderer and shape/tone/escape operations; verify all twelve vowel forms with five tones plus no tone, `aa/aw/ee/oo/ow/uw/dd`, tone replacement/removal, and `aasa` tone preservation in lower/upper/mixed case.
- [x] 2.3 Implement tone-target and paired-vowel rules using normalized base letters; verify `qu`, `gi`, `iê`, `yê`, `uô`, `ươ`, the selected `hòa/khỏe/thúy` convention, coda-driven movement, and all `thuở` case variants against explicit fixture expectations.
- [x] 2.4 Implement visible-character Backspace, literal escape/ineligible-modifier handling, literal brackets/leading `w`, and the 64-character limit; verify Backspace-then-tone, boundary deletion without history restoration, exactly-64/overflow, and no disconnected-suffix replacement.
- [ ] 2.5 Extend `vietmac-replay` with semantic-event fixtures recording mode, context, action, and text after every event; verify all `telex-composition` scenarios and selected OpenKey regression families while keeping existing planner replay working.
- [ ] 2.6 Add deterministic randomized ownership/NFC/bounds checks against an independent simulated text buffer; verify repeatable seeds and failure capture, then run focused address-sanitizer checks for the new indexing and buffer ownership.
- [ ] 2.7 Add a complete-reducer Release scope and `make bench-engine` entry point while retaining `make bench` as planner-only; verify Debug refusal, consumed outputs, 1,000 warmup/10,000 measured events, required workload categories, and schema/environment fields in saved JSON.
- [ ] 2.8 Document core state/escape/Backspace policies, semantic fixture format, replay, and benchmark scope; verify documented commands locally and run `make check`, recording model and performance evidence separately from native behavior.

## 3. M2 — Platform integration and user controls

Note (2026-11-14): at Son's request for a testable MVP, the composer replaced the M0 language rules inside `PrototypePipeline` before task 1.1 passed. Chained replacements are admitted when only earlier replacement events are unsettled. Native automation evidence is in the ledger. Task 3.1 stays open until its synthetic-trace verification and the native gate are complete.

- [ ] 3.1 Replace M0's prototype language rules with the core transition contract and existing planner/transport; verify ordered events, generated-event bypass, candidate-state acceptance, stale/preparation-failure pass-through, and partial-send pause without rollback using synthetic platform traces.
- [ ] 3.2 Add actual-text case normalization, the compiled `FieldProfile` table and resolver replacing `trialApps` (design 8), source policy, exclusions, and uncertain-context reset; verify resolution reads no value, title, or URL and runs once per focus change, the test-session launch argument, and that the profile table marks only evidenced profiles accepted; verify Shift/Caps Lock combinations, renderer/helper identity relationships, same-app switches, non-ASCII/paste, unsupported terminal/password contexts, and no per-key I/O or async task creation.
- [ ] 3.3 Produce `RuntimeStatus` with Active, Standby, and Blocked classes, gate order, run-loop observer publication, platform-owned mode, `shortcutArmed`, no AX observation in English mode, and tap removal on capability loss and on the trust-change notification (design 9 and 10), replacing `M0StatusAdapter` from `ux-shell`; verify the gate-combination test, one publication per pass, and that selections no longer pause; then add the optional configurable key-down shortcut; verify default-unset behavior, one toggle per held press, key pairing, unrelated shortcuts, fresh-state mode changes, and literal identifiers in focused controller/platform tests.
- [ ] 3.4 Add isolated preference persistence, first-launch English defaults, the `flock` instance lock with reopen notification, and `SMAppService.mainApp` login registration with the system state as truth (design 11); verify configuration round trips without typed content, mocked startup success/failure states, and second-instance refusal without creating a second pipeline.
- [ ] 3.5 Update app/control/context documentation and prepare the full-engine native matrix with all 17 field groups; run focused platform checks, `make check`, and `make app`, and verify the build/result report still marks unperformed native checks as pending.

- [ ] 3.6 Build the dogfood bundle (FG-4): enable only profiles whose full-engine rows passed by automation and a physical spot check, ship the `ux-shell` UI, and confirm U-3 has a recorded safe result first; record the enabled profiles and their evidence in the ledger. If U-3 is not safe, stop and report to Son.
- [ ] 3.7 Add the offset-0 word start (design 12) per profile only after U-14 passes for that profile; verify with an empty-field scenario and a field whose content a script replaces at the same moment.

## 4. M3 — Native field and personal lifecycle acceptance

- [ ] 4.1 Verify VS Code editor, Find, and quick input using the complete engine; record exact text/caret/selection, case, Backspace, escapes, shortcuts, autocomplete, undo/redo grouping, same-app/programmatic focus cases, and ordinary input in the excluded integrated terminal.
- [ ] 4.2 Verify Chrome address/search, ordinary input, text area, and rich editing independently; record full-engine cases, selected suggestions, external edits, focus changes, undo/redo, preservation, and actual autocomplete settings for each field.
- [ ] 4.3 Verify Safari address/search, ordinary input, text area, and rich editing independently with the same acceptance families; record its actual app version/settings and do not inherit a Chromium browser's result.
- [ ] 4.4 Verify Dia address/search, ordinary input, text area, and rich editing independently with the same acceptance families; keep every unavailable or failing field pending rather than reducing the matrix.
- [ ] 4.5 Verify Apple Notes title and body with the complete engine; record exact text/caret/selection, existing formatting, emoji adjacency, case, Backspace, escapes, focus changes, and undo/redo round-trip behavior for both fields.
- [ ] 4.6 Verify fast typing, held keys, configured toggle, mode changes, app/field switching, capability loss, secure input, bounded timeout recovery, sleep/wake, and relaunch; save synthetic native results showing ordinary-input preservation, correct status, and fresh composition after resets.
- [ ] 4.7 Verify the stable personal bundle's single-instance and opt-in login-startup behavior in an authorized native session; record actual registration/relaunch states without automatically granting permissions, installing apps, or changing global developer settings.

- [ ] 4.8 Verify the daily-use failure families in Chrome, Dia, and Safari with native automation and physical spot checks: rollover without lost text, a dropped or misdirected deletion detected and paused, and tone placement/NFC for Son's reported examples.

## 5. Integrated MVP acceptance and handoff

- [ ] 5.1 Save Release reducer and callback-own-work measurements on the native acceptance machine; verify reducer p99 < 1 ms and callback p99 < 2 ms, required report metadata, no sanitizers/profilers, and a separate native visible-latency method/limitation record.
- [ ] 5.2 Review the complete model/native/lifecycle/performance evidence, verify clipboard/no-underline/no-sentinel checks and all 17 field groups passed, run `make check` and `make app`, update README to the actual delivered behavior, and append one ledger handoff identifying environment, exclusions, and remaining unknowns.

## Workflow follow-up

- Review and merge stages in dependency order only with Son's authorization; separate PRs are optional and should group related outcomes.
- Sync/archive through the corresponding OpenSpec workflow only after completion criteria pass; do not check off a native task from a build or model test.
