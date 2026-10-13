# Native transport implementation tasks

## 1. Host and event ownership

- [ ] 1.1 Add the session event tap, lifecycle notifications, pause state, and permission status without per-key I/O.
- [ ] 1.2 Add per-process event tagging, consumed key pairing, and bounded prototype composition with model checks.

## 2. Prepared transport and context

- [ ] 2.1 Prepare all output before deletion and send the planner result for `as` and `aa` in serialized order.
- [ ] 2.2 Reset state on observed app, source, navigation, selection, edit shortcuts, and lifecycle changes with focused tests.
- [ ] 2.3 Measure callback own-work in Release and keep collection and export outside the callback.

## 3. Native acceptance and handoff

- [ ] 3.1 Establish a stable local app identity and record the enabled capabilities for native testing with Son's authorization.
- [ ] 3.2 Verify VS Code editor, Find, and quick input with case, Backspace, shortcuts, selection, undo, and autocomplete.
- [ ] 3.3 Verify address/search, ordinary input, text area, and rich editing in Chrome, Edge, and Dia independently.
- [ ] 3.4 Verify Apple Notes title and body, formatting, emoji adjacency, selection, and undo.
- [ ] 3.5 Verify fast typing, autorepeat, app/field switching, clipboard preservation, no invisible characters, and no composition underline.
- [ ] 3.6 Save native matrix and performance evidence, append ledger results, and report remaining limitations before archive.
