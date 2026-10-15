# Tasks

## 1. Driver step scripts and guards

- [x] 1.1 Add `--script <path>` JSON steps (`text`, `key`, `hold`, `capsLock`, `pause`, `click`, `checkpoint`) with the full key vocabulary, modifier chords, autorepeat, and seeded jitter, keeping `--keys` as shorthand; verify with a script-validation test target (no events posted) and a Chrome fixture run whose page log shows the chord, autorepeat, and rollover order.
- [x] 1.2 Reject unsupported steps and Return/Enter for `protected` targets before posting any event; release held keys and modifiers and restore CapsLock and the input source on every exit path; verify with validation tests and an aborted run that leaves `CGEventSource` flag state clear.
- [ ] 1.3 Add the listen-only interference tap with a private event marker and `userInterference` abort; verify by moving the mouse during a run (Son, after granting Input Monitoring) and confirming no further events are posted.

## 2. Field oracles and preservation checks

- [x] 2.1 Add the driver `--read-focused` oracle (AX value, selected range, marked range when exposed) with the designation check and `untrustedTarget` failure, plus the clipboard change-count read; verify against the fixture page fields and a non-test field that returns no content.
- [x] 2.2 Add the address-bar oracle for Chrome, Dia, and Safari with localhost history seeding and recorded autocomplete/search-suggestion settings; verify an inline completion is observed as a selection in each browser.
- [x] 2.3 Add the VS Code oracles: Command-S file read for the editor test file and AX reads for Find and quick input; verify each with a literal typing scenario in a dedicated test workspace.
- [ ] 2.4 Add the Apple Notes oracle for title and body of the `VietMac Test` note in folder `VietMac Tests` (created once by Son); verify both fields with a literal typing scenario.
- [x] 2.5 Add runner preservation checks (invisible characters, NFC, composition events, clipboard count) to every run; verify with a fixture that deliberately inserts U+202F and a decomposed mark and must fail.

## 3. Scenario catalog and matrix runner

- [x] 3.1 Define the catalog schema and move the seven existing scenarios into `Fixtures/native-scenarios/`; verify the converted scenarios reproduce their previous Chrome results.
- [ ] 3.2 Add `m0` scenarios for the `context`, `editing`, `case`, `held-keys`, `preservation`, `autocomplete`, and `daily-use` families with explicit expected text and checkpoints; verify the catalog validates and every scenario lists its rule set and targets.
- [ ] 3.3 Turn `native_run.py` into the matrix runner (`--suite`, `--apps`, `--repeat`), with per-app VietMac relaunch, per-scenario counter deltas, `not-applicable` and `not-run` outcomes, `result.json`, and `summary.md`; verify with a two-app, two-scenario matrix whose summary matches its JSON.
- [ ] 3.4 Add the converter from `telex-input-mvp` composition fixtures to `telex-mvp` native scenarios, never calling the reducer; verify on sample fixtures that expected text equals the fixture text and that the current build reports them `not-applicable`.

## 4. Native acceptance of the harness

- [ ] 4.1 Run the full `m0` matrix in Chrome, Dia, Safari, VS Code, and Apple Notes; record per-cell results in `docs/verification/` and the ledger as `native-automation`, with every unreachable cell `not-run` and its reason.
- [ ] 4.2 Repeat the `transport` and `context` families five times per browser and record pass counts; investigate any flaky cell before closing this change.
- [ ] 4.3 Document harness usage, permissions, safety rules, and evidence labeling in `docs/development.md`; run `make check` and `./scripts/openspec.sh validate --all --strict`.

## Workflow follow-up

- After this change, `macos-transport-spike` tasks 3.2–3.5 and `telex-input-mvp` acceptance tasks can cite matrix runs, still paired with physical spot checks.
- Archive after task 4 evidence is recorded and limitations are listed.
