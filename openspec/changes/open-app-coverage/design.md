# Design

## Context

See `proposal.md` for the motivation. Current state, read from the code on 2026-11-17:

- `InputHost.trialApps` holds five bundle IDs. `supportedApp` is false for every other application, which gives `PauseReason.unsupportedApp` and stops Accessibility inspection (`FocusMonitor.inspect(allowed:)`).
- `FocusMonitor` reads role, subrole, selected range, and character count of the focused element. It returns `.caret`, `.selection`, or `.unavailable(reason)`. It does not record why a read failed.
- Two event-only profiles exist: `addressBar` (Chrome, Dia, Safari) and `vscodeEditor`. `InputHost.eventOnlyField` lets a replacement skip `ContextPolicy.admitsReplacement`.
- Every other field uses the observed path: `ContextPolicy` compares each reading with the predicted effect of each key.
- `ProfileCatalog.stub` lists ten profiles, all `accepted: false`. The shell uses it for the Apps tab and to decide whether the menu shows the exclusion item. The runtime does not consult it.

Constraints from `AGENTS.md`: no AX read, I/O, or task in the key callback; one owning run loop; invalidate uncertain context instead of a blind rollback; no marked text, clipboard, or invisible sentinel.

## Goals / Non-Goals

**Goals:**

- One rule that covers unknown applications, with no per-application data.
- No new work in the key callback. The callback keeps reading one cached flag.
- A wrong guess fails toward literal input.

**Non-Goals:**

- Matching the per-application tables of GoNhanh, PHTV, or XKey.
- Handling fields whose reported caret and count do not follow the text.
- Transforming in elements that expose no text-entry role.
- A new `FieldProfile` resolver type. The two existing identity checks stay where they are.

## Decisions

### D1. Remove the allowlist and keep the list as evidence metadata

`trialApps` is renamed `requiredApps` and is used only by the diagnostic report. `InputEnvironment.supportedApp` becomes `appExcluded`, and `PauseReason.unsupportedApp` becomes `excludedApp`. `StandbyReason.unsupportedApp` and its strings are removed. Accessibility inspection is allowed for every non-excluded application.

Alternative: keep the list and add an "all apps" setting. Rejected: two code paths to test, and Son decided to remove the list.

### D2. Capability decides the assurance, per focused element

`FocusInspection` gains a capability value that `FocusMonitor` sets:

| Reading of the focused element | Result |
| --- | --- |
| Identified as address bar or VS Code editor | Existing profile (unchanged) |
| Secure text subrole | Literal |
| Text role, selected range and character count read | `observed` |
| Text role, range or count attribute returns "unsupported" or "no value" | `eventOnly` |
| Text role, a read fails for another reason (timeout, cannot complete) | Uncertain, literal |
| Other role, or no focused element | Literal, `noTextField` |

Text roles stay `AXTextField`, `AXTextArea`, and `AXComboBox`. `InputHost.eventOnlyField` becomes true for the `eventOnly` row as well as for the two profiles, so the callback path does not change.

Benefit: an unknown application needs no entry anywhere. Trade-off: the rule trusts the role an application reports.

Alternative: event-only for every focus that is not readable, as OpenKey does. Rejected: a posted Backspace in a non-text focus can act as a command. For example, Backspace deletes the selected message in a mail list.

Alternative: choose by bundle ID as the other projects do. Rejected: it brings back the per-application work this change removes.

### D3. Classify read failures by AX error code

`eventOnly` needs evidence that the attribute does not exist. `FocusMonitor` treats `attributeUnsupported` and `noValue` as "not supported", and every other error as a failed read. The 0.05 s messaging timeout stays.

An element becomes sticky `observed` after its first caret reading. Later failures keep today's behavior: invalidate and wait. An element first classified `eventOnly` moves to `observed` if a later reading returns a caret and count. The host treats that move as a new field: the word survives only when the field holds exactly that word (the existing focus-change rule), otherwise the tracker and the word reset. This keeps the first letter in a field that reports "no value" only while it is empty.

Which error code each application returns is **inferred** from the API contract. The probe of task 1.1 could not run from the development shell on 2026-11-17, because that process has no Accessibility permission. The rule is implemented as inferred. The observation trace records `rangeUnsupported` and `countUnsupported`, so the native runs of group 5 supply the measurement.

VietMac's own windows are not inspected (the frontmost PID equals its own). They report `noTextField` and stay literal, which avoids an Accessibility call into the calling process on its own run loop.

### D4. Event-only rules are the existing ones

The generic event-only field uses the same handling as `vscodeEditor`: context is certain, the field tracker is reset on each observation, and a focus change invalidates the word. It sends no completion-clearing key. Resets come from sources that already exist: `EventNormalizer` (mouse, navigation keys, chords), the AX focus notifications, application activation, input source change, and sleep.

A counter `eventOnlyReplacements` is added next to `addressBarReplacements` and `vscodeEditorReplacements`.

### D5. Status and shell

- `M0StatusAdapter` receives the assurance from `InputHost` and publishes `active(observed)` or `active(eventOnly)`. Today it always publishes `observed`.
- A non-text focus publishes `standby(noTextField)`. A failed read publishes `standby(fieldUnreadable)` as today. An excluded application publishes `standby(excludedApp)` directly, without the remapping in the adapter.
- `MenuModel` shows the exclusion item for any frontmost bundle ID. The `catalog.hasProfile` condition is removed.
- `AppsTab` rows are the catalog's bundle IDs followed by excluded bundle IDs that are not in the catalog. Field-kind lines show `Đã kiểm thử ✓` or `Chưa kiểm thử`. A row from outside the catalog shows no field kinds.
- `ProfileCatalog.Profile.accepted` is renamed `tested`. Its value comes from ledger evidence and gates nothing. Set to true for the three `webText` profiles (native automation, 2026-11-14) and for the three address bars, the VS Code editor, and Quick Open (Son's physical typing, 2026-11-16). `vscode.find` and `notes.text` stay false.
- `MenuModel` no longer takes the catalog.

State ownership: all of the above stays on the main run loop inside `InputHost`, `FocusMonitor`, and the adapter. Dependency direction does not change: `VietMacShell` reads `VietMacPlatform` status types, `VietMacPlatform` reads `VietMacCore`.

### D6. Performance scope

No measured path changes. The callback does the same work. Inspection runs for more applications, on the existing poll (0.25 s) and AX notifications, outside the callback, with the existing timeout. No performance claim is made. If callback timings are compared, the scope is `callback` only.

## Risks / Trade-offs

- [An application reports a text role for a non-text control] → A replacement posts Backspace there. Mitigation: per-application exclusion; add an identity check when a case is reported.
- [The caret moves in an event-only field without an event VietMac sees, for example an editor command or an undo from a menu] → The next replacement can delete a wrong character. Mitigation: the word resets on every chord and mouse press, and the tracked word is at most 64 characters. This is the same residual risk the `vscodeEditor` profile already accepts.
- [A field reports a caret and count that do not follow the text] → It stays literal under `observed`. This is safe and visible in `unexplainedFieldChanges`. It is not fixed here.
- [Terminals] → Not tested. A terminal that reports a text role without a range becomes `eventOnly`, where Backspace in a shell line behaves as typed Backspace. Full-screen terminal programs are a known risk. Mitigation: exclusion.
- [Applications that draw their own text and expose no text role] → Stay literal. A later change can add a profile for a reported application.
- [More AX calls across more applications] → A slow application costs at most the 0.05 s timeout per read, outside the callback. Watch the callback timing report for regressions.

## Migration Plan

1. Land the platform change with model tests. Stored exclusions keep their format (`excludedApps` in user defaults).
2. Land the shell change and reconcile the conflicting requirements in `telex-input-mvp` and `ux-shell`.
3. Run the native checks and record them in the ledger.

Rollback: revert the commits. For one failing application, the user excludes it from the menu.

## Open Questions

- Should `AXSearchField` subroles or other roles join the text-role set? Decide from the first reported application that needs it.
- Is a visible mark for `eventOnly` useful in the menu? The status already carries the value; the UI decision can wait for use.
