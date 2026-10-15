# Native test automation harness

## Why

Native acceptance currently depends on Son typing each case by hand, which is slow, hard to repeat, and impractical for long workloads.
The M0 spike showed that HID-level synthetic key events reach VietMac's event tap and reproduce real failures such as key rollover.
A complete harness lets the Telex engine (`telex-input-mvp`) be verified natively and repeatably in every required field before and after each change.

## What Changes

- Extend the test-only `VietMacDriver` from a character string to a scripted step format: letters, digits, punctuation, modifiers, special keys, chords, held keys with autorepeat, CapsLock, pauses, clicks, and seeded timing jitter.
- Add a user-interference guard: the driver aborts when physical input arrives during a run, in addition to the existing frontmost-app, input-source, and time-limit guards.
- Add a versioned scenario catalog in `Fixtures/` that states key steps, the target app and field, expected visible text after selected checkpoints, and required VietMac counter outcomes. Expected text comes from explicit fixtures, never from the production reducer.
- Add field oracles per surface: the browser fixture page report (existing), Accessibility value/selection reads for address bars and Apple Notes, and a saved test file for the VS Code editor. Each oracle reads only a designated test document or field.
- Add global preservation checks for every run: clipboard change count unchanged, no marked text, no invisible or decomposed characters in the result.
- Replace the single-scenario runner with a matrix runner that executes scenario × app × field, repeats runs for flake rates, and writes one machine-readable result plus a Markdown summary for the verification notes and ledger.
- Record harness evidence as native automation, separate from physical typing and from model checks.

Required application surfaces are unchanged: VS Code (editor, Find, quick input), Chrome, Dia, and Safari (address/search, ordinary input, text area, rich editing), and Apple Notes (title and body).

Excluded: hosted CI, permission loss, sleep/wake, and secure-input automation (these stay manual checks); Microsoft Teams and other non-required apps; sending Return or submitting in any app that could publish content; reading any non-test document; replacing physical typing spot checks.

Completion gate: every required field has an oracle that reports exact text, caret, and selection; the catalog covers the transport and context families already verified in M0 plus the daily-use failure families; and one matrix run passes in all required fields with the M0 prototype rules.

## Capabilities

### New Capabilities

- `native-test-harness`: Scripted HID-level input, interference and safety guards, per-surface field oracles, a fixture-driven scenario catalog, and a matrix runner that produces native automation evidence.

### Modified Capabilities

None. The development workflow already separates model, native, and performance evidence; native automation is recorded within the native scope and labeled as automation.

## Impact

- `Apps/VietMacDriver` (test-only app): step parser, key vocabulary, guards, interference monitoring.
- `scripts/native_run.py` becomes a matrix runner with oracle adapters; `Fixtures/` gains the scenario catalog and test documents.
- `Fixtures/native-fields.html` keeps its automation mode; Notes and VS Code use dedicated test documents.
- Permissions: the driver keeps Accessibility; interference detection adds Input Monitoring for the driver. Son grants both.
- No change to `VietMacCore`, `VietMacPlatform`, or the app's runtime behavior. The `--enable-prototype` launch flag remains a test entry point.
- `telex-input-mvp` acceptance tasks can cite harness runs alongside physical spot checks.
