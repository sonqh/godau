# Telex input MVP tasks

All tasks are pending. Planning completion is not implementation or native acceptance.
Implement in order: M0 gate → M1 core → M2 integration → M3 native/personal acceptance.

## 1. Establish the native prerequisite

- [ ] 1.1 Verify `macos-transport-spike` has passed every required native field and preservation check; link its matrix and callback evidence in the MVP handoff, and stop engine implementation if a required row remains failed or not-run.

## 2. M1 — Semantic composition and replay

- [ ] 2.1 Add instance-local typed letter/shape/tone state and transition handling in `VietMacCore`; verify ASCII validation, base/modifier case separation, independent instances, boundary resets, and stale-context rejection with focused core tests.
- [ ] 2.2 Implement the shared NFC renderer and shape/tone/escape operations; verify all twelve vowel forms with five tones plus no tone, `aa/aw/ee/oo/ow/uw/dd`, tone replacement/removal, and `aasa` tone preservation in lower/upper/mixed case.
- [ ] 2.3 Implement tone-target and paired-vowel rules using normalized base letters; verify `qu`, `gi`, `iê`, `yê`, `uô`, `ươ`, the selected `hòa/khỏe/thúy` convention, coda-driven movement, and all `thuở` case variants against explicit fixture expectations.
- [ ] 2.4 Implement visible-character Backspace, literal escape/ineligible-modifier handling, literal brackets/leading `w`, and the 64-character limit; verify Backspace-then-tone, boundary deletion without history restoration, exactly-64/overflow, and no disconnected-suffix replacement.
- [ ] 2.5 Extend `vietmac-replay` with semantic-event fixtures recording mode, context, action, and text after every event; verify all `telex-composition` scenarios and selected OpenKey regression families while keeping existing planner replay working.
- [ ] 2.6 Add deterministic randomized ownership/NFC/bounds checks against an independent simulated text buffer; verify repeatable seeds and failure capture, then run focused address-sanitizer checks for the new indexing and buffer ownership.
- [ ] 2.7 Add a complete-reducer Release scope and `make bench-engine` entry point while retaining `make bench` as planner-only; verify Debug refusal, consumed outputs, 1,000 warmup/10,000 measured events, required workload categories, and schema/environment fields in saved JSON.
- [ ] 2.8 Document core state/escape/Backspace policies, semantic fixture format, replay, and benchmark scope; verify documented commands locally and run `make check`, recording model and performance evidence separately from native behavior.

## 3. M2 — Platform integration and user controls

- [ ] 3.1 Replace M0's prototype language rules with the core transition contract and existing planner/transport; verify ordered events, generated-event bypass, candidate-state acceptance, stale/preparation-failure pass-through, and partial-send pause without rollback using synthetic platform traces.
- [ ] 3.2 Add actual-text case normalization and accepted app/field/source policy with exclusions and uncertain-context reset; verify Shift/Caps Lock combinations, renderer/helper identity relationships, same-app switches, non-ASCII/paste, unsupported terminal/password contexts, and no per-key I/O or async task creation.
- [ ] 3.3 Add menu Vietnamese/English mode, distinct pause reasons, and optional configurable key-down shortcut; verify default-unset behavior, one toggle per held press, key pairing, unrelated shortcuts, fresh-state mode changes, and literal identifiers in focused controller/platform tests.
- [ ] 3.4 Add isolated preference persistence, first-launch English defaults, single transforming-instance handling, and user-driven login registration; verify configuration round trips without typed content, mocked startup success/failure states, and second-instance refusal without creating a second pipeline.
- [ ] 3.5 Update app/control/context documentation and prepare the full-engine native matrix with all 17 field groups; run focused platform checks, `make check`, and `make app`, and verify the build/result report still marks unperformed native checks as pending.

## 4. M3 — Native field and personal lifecycle acceptance

- [ ] 4.1 Verify VS Code editor, Find, and quick input using the complete engine; record exact text/caret/selection, case, Backspace, escapes, shortcuts, autocomplete, undo/redo grouping, same-app/programmatic focus cases, and ordinary input in the excluded integrated terminal.
- [ ] 4.2 Verify Chrome address/search, ordinary input, text area, and rich editing independently; record full-engine cases, selected suggestions, external edits, focus changes, undo/redo, preservation, and actual autocomplete settings for each field.
- [ ] 4.3 Verify Safari address/search, ordinary input, text area, and rich editing independently with the same acceptance families; record its actual app version/settings and do not inherit a Chromium browser's result.
- [ ] 4.4 Verify Dia address/search, ordinary input, text area, and rich editing independently with the same acceptance families; keep every unavailable or failing field pending rather than reducing the matrix.
- [ ] 4.5 Verify Apple Notes title and body with the complete engine; record exact text/caret/selection, existing formatting, emoji adjacency, case, Backspace, escapes, focus changes, and undo/redo round-trip behavior for both fields.
- [ ] 4.6 Verify fast typing, held keys, configured toggle, mode changes, app/field switching, capability loss, secure input, bounded timeout recovery, sleep/wake, and relaunch; save synthetic native results showing ordinary-input preservation, correct status, and fresh composition after resets.
- [ ] 4.7 Verify the stable personal bundle's single-instance and opt-in login-startup behavior in an authorized native session; record actual registration/relaunch states without automatically granting permissions, installing apps, or changing global developer settings.

## 5. Integrated MVP acceptance and handoff

- [ ] 5.1 Save Release reducer and callback-own-work measurements on the native acceptance machine; verify reducer p99 < 1 ms and callback p99 < 2 ms, required report metadata, no sanitizers/profilers, and a separate native visible-latency method/limitation record.
- [ ] 5.2 Review the complete model/native/lifecycle/performance evidence, verify clipboard/no-underline/no-sentinel checks and all 17 field groups passed, run `make check` and `make app`, update README to the actual delivered behavior, and append one ledger handoff identifying environment, exclusions, and remaining unknowns.

## Workflow follow-up

- Review and merge stages in dependency order only with Son's authorization; separate PRs are optional and should group related outcomes.
- Sync/archive through the corresponding OpenSpec workflow only after completion criteria pass; do not check off a native task from a build or model test.
