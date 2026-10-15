# Design

## Context

The M0 spike already provides the pieces below (see proposal.md for motivation):

- `VietMacDriver.app`: test-only, signed with the local certificate, Accessibility granted. It posts HID-level key and mouse events from a `--keys` string with `|` pauses. It guards the frontmost app, the ABC/U.S. source, and a time limit, can select ABC and restore the source, and releases keys on exit.
- `scripts/native_run.py`: Python stdlib only. It serves `Fixtures/` on 127.0.0.1, relaunches VietMac with `--enable-prototype --evidence-dir`, reads the fixture page report, and diffs VietMac counters through `SIGUSR1` snapshots. Seven Chrome/Dia/Safari scenarios are hard-coded in it.
- VietMac exposes no other test hook, and its runtime must not read document text.

Constraints that shape the design: no new runtime dependency for VietMac, no Node or Python in the app or core, synthetic text only, and Son grants every permission.

## Goals / Non-Goals

**Goals:**
- One script format and one runner that cover every required surface, including address bars with real inline autocomplete.
- Oracles that report exact text, caret, and selection, plus preservation checks, without reading non-test content.
- Scenario fixtures reusable by `telex-input-mvp`, with expected text authored independently of the reducer.

**Non-Goals:**
- Measuring visible input latency. The harness reports callback own-work only through VietMac's existing export; driver pacing is not latency.
- Automating permission loss, sleep/wake, or secure input.
- Running unattended or in hosted CI. Runs need Son's logged-in session and an idle Mac.

## Decisions

### Dependency direction and state ownership

`runner → driver`, `runner → VietMac (launch flags, SIGUSR1)`, `runner → fixture server`. VietMac and its modules never depend on the harness.
The driver owns pressed-key and modifier state, input-source restoration, and interference monitoring for one script.
The runner owns process lifecycle (VietMac, fixture server), field initialization, the matrix, and result files.
Ledger records stay a manual `scripts/ledger.py` step after reviewing a summary, so a failing run cannot write evidence automatically.

### Driver: JSON step scripts (`--script <path>`), keeping `--keys` as shorthand

A step list expresses chords, holds, clicks, checkpoints, and per-step timing; a character string cannot.
Alternative considered: extend the string DSL with escape tokens. It is compact, but it becomes hard to read and to validate for chords and holds.
Step types: `text` (characters with interval/hold/jitter), `key` (named key plus modifiers), `hold` (key plus repeat count; repeats set the autorepeat field), `capsLock`, `pause`, `click` (point or `fieldCenter` from the oracle), and `checkpoint` (settle, then read the oracle).
The vocabulary covers ANSI letters, digits, punctuation, Space, Return, Tab, Backspace, Delete, Escape, arrows, and Shift/Control/Option/Command. Unknown names reject the script before any event.
Jitter uses a seeded generator, so a failing seed replays the same timing.
The driver is the single native process. It also hosts the Accessibility oracle and clipboard change-count read, so the runner stays stdlib-only and no PyObjC dependency is added.

### Interference guard: listen-only event tap in the driver

Driver events carry a private `eventSourceUserData` marker. A listen-only session tap in the driver aborts the run on any keyboard or mouse event without that marker.
Alternative considered: HID idle time. It cannot tell posted events from physical ones.
Trade-off: the driver needs Input Monitoring in addition to Accessibility. Son grants it once; the signed bundle keeps the grant across rebuilds.

### Protected targets

Scenarios declare a target as `protected` when Return could submit or publish content (for example a chat app). The driver refuses Return, Command-Return, and Enter steps for protected targets.
No current required surface is protected, but the guard keeps future apps safe by default.

### Field oracles per surface

| Surface | Oracle | Designation check |
| --- | --- | --- |
| Fixture page fields (Chrome, Dia, Safari) | Existing page report: value, caret, selection, key/input/composition events | Run ID in the page URL |
| Address/search bars | Driver AX read of the focused `AXTextField`: `AXValue`, `AXSelectedTextRange` | Expected app, focused role, and the browser's address-field identifier or description |
| VS Code Find and quick input | Driver AX read of the focused text field | VS Code window title names the test workspace |
| VS Code editor | Command-S, then read `.artifacts/native/vscode/editor-test.txt` from disk; caret from AX when exposed | Window title names the test file |
| Apple Notes title and body | Driver AX read of the focused note text area; title is the first line | Note text starts with the marker line `VietMac Test` in folder `VietMac Tests` |

AX reads happen only after the designation check passes; otherwise the run fails with `untrustedTarget` and no content is read.
The VS Code editor uses a file oracle because the Monaco editor's AX value depends on VS Code's accessibility mode. A saved test file is deterministic.
Checkpoints use the same oracle at a declared step. Web checkpoints can also be reconstructed from the timestamped page log.

### Real address-bar autocomplete

Before address-bar scenarios, the runner opens fixture URLs such as `http://127.0.0.1:8765/aaron-test` so history-based inline completion has deterministic candidates.
Scenarios never press Return in an address bar. Each run records the browser's autocomplete and search-suggestion settings, because typed synthetic text may be sent to a search provider when suggestions are enabled.

### Preservation checks

- Clipboard: the driver records `NSPasteboard.general.changeCount` before and after; contents are never read.
- Marked text: page `compositionstart` events for web fields; for native fields, `AXMarkedTextRange` when exposed, otherwise `not-observable`, backed by the ABC-source guard.
- Text form: the runner rejects U+200B–U+200F, U+202F, U+FEFF, and any non-NFC result (`unicodedata.is_normalized`).

### Scenario catalog

`Fixtures/native-scenarios/<family>.json`, with schema version, scenario ID and version, `rules` (`m0` or `telex-mvp`), targets (`app`, `field`), initial text and caret, steps, checkpoints, expected final text and caret, and counter expectations (`exact` or `minimum`).
Families: `transport` (single, rollover, fast, workload), `context` (external edit, focus switch, selection, click), `editing` (Backspace, Delete, arrows, undo/redo, select-all and type), `case` (Shift, CapsLock), `held-keys`, `preservation` (emoji, formatting, surrounding text), `autocomplete` (address bars), and `daily-use` (Son's reported failures).
`telex-mvp` scenarios are generated by a converter from `telex-input-mvp` composition fixtures: key steps come from the fixture's semantic keys, and expected text comes from the fixture's explicit text. The reducer is never the oracle.
The runner marks a scenario `not-applicable` when the build lacks its rule set. The current build reports `rules: m0` through `--evidence-dir` diagnostics.

### Runner: matrix, repeats, results

`scripts/native_run.py --suite <file|family> --apps chrome,dia,safari,vscode,notes --repeat N` expands scenarios × targets.
VietMac is relaunched once per app group, with counter snapshots before and after each scenario. Fields are reset per scenario.
Output goes to `.artifacts/native/matrix/<run>/result.json` (per-cell outcomes, environment, versions, settings, evidence class `native-automation`) and `summary.md` (a matrix table ready for the verification notes).
There are no automatic retries. Repeats report pass counts out of N.
Existing hard-coded scenarios move into the catalog unchanged in meaning.

## Risks / Trade-offs

- [Synthetic events differ from physical input, for example keyboard type or device ID] → Keep physical spot checks per app; label automation evidence separately.
- [AX values lag or are missing in some fields] → Settle waits at checkpoints, repeat counts, a file oracle for the VS Code editor, and `not-run` instead of guessing.
- [Typing into the wrong place] → Frontmost, designation, and interference guards; protected targets; synthetic text; test documents only.
- [Autocomplete depends on browser history and settings] → Seed deterministic localhost history and record settings with each result.
- [Address-bar text may reach a search provider] → Synthetic text only; Son may disable search suggestions; recorded per run.
- [Long matrix runs occupy the Mac] → Suites are selectable by family and app; the workload is a separate family.
- [Extra Input Monitoring permission for the driver] → One-time grant to the signed test-only bundle; the driver never runs from VietMac.

## Migration Plan

Move the seven hard-coded scenarios into `Fixtures/native-scenarios/` first and keep `--keys` working, so existing commands and evidence stay reproducible.
Rollback: the catalog and runner are test tooling; reverting them does not affect VietMac.

## Open Questions

- Whether the `VietMac Test` note is later created by the runner through AppleScript (adds Automation permission). Tasks assume Son creates it once by hand; either satisfies the designation check.
