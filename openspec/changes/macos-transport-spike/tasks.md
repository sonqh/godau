# Native transport implementation tasks

## 1. Host and event ownership

- [x] 1.1 Add the session event tap, lifecycle notifications, pause state, and permission status without per-key I/O; verify capability loss, secure-input handling, three-retry timeout bounds, and fresh-state resume with focused lifecycle checks and document the status meanings.
- [x] 1.2 Add per-process event tagging, consumed key pairing, and bounded prototype composition; verify own-event bypass, ordinary key pairing, consumed key-up behavior, case, and autorepeat with ordered model traces.

## 2. Prepared transport and context

- [x] 2.1 Prepare all output before deletion and send the planner result for `as` and `aa` in serialized order; verify zero deletions on preparation failure or stale context, multi-character insertion, no blind rollback after partial send, and no event interleaving through a synthetic transport harness.
- [x] 2.2 Reset state on observed app, field, caret, source, navigation, selection, edit shortcuts, and lifecycle changes; verify same-app switches and external-edit notifications with focused tests, and document unobserved focus/selection limits.
- [ ] 2.3 Measure callback own-work in Release and keep collection and export outside the callback; save a report with sample count, workload, environment, and percentiles distinct from planner and native latency.

## 3. Native acceptance and handoff

- [ ] 3.1 Establish a stable local app identity and native evidence template; record OS, app versions, enabled capabilities, input source, and competing input apps with Son's authorization for the native session.
- [ ] 3.2 Verify VS Code editor, Find, and quick input with case, Backspace, shortcuts, selection, undo/redo, autocomplete, and same-app focus changes; record exact text and caret/selection results for each field.
- [ ] 3.3 Verify address/search, ordinary input, text area, and rich editing in Chrome, Edge, and Dia independently; record selected-suggestion and external-edit cases with actual autocomplete settings for every field.
- [ ] 3.4 Verify Apple Notes title and body, formatting, emoji adjacency, selection, and undo/redo; record text, caret, and formatting preservation for both fields.
- [ ] 3.5 Verify fast typing, autorepeat, app/field switching, permission loss, secure input, sleep/wake, and explicit resume; record clipboard preservation, no invisible characters, no underline, and fresh composition after each reset.
- [ ] 3.6 Save the complete native matrix and performance evidence, run `make check` and `make app`, and append ledger results; verify every required row passed before reporting M0 completion and enabling the follow-on MVP work.
