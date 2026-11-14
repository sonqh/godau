# UX shell design

## Context

The app shell is one file, `Apps/VietMac/VietMacApp.swift` (161 lines). It builds an M0 developer menu from `InputHost.state`, `InputHost.enabled`, and `PermissionSnapshot`. It has no test target.
`VietMacPlatform/RuntimeStatus.swift` contains `PermissionSnapshot`, the twelve-case `PauseReason` with English developer strings, `InputRuntimeState`, and an unused `enum RuntimeStatus { static let transportImplemented }`.
The target UI is specified in [ux-spec.md](../../../docs/ux-spec.md). The status interface is in [architecture-spec.md](../../../docs/architecture-spec.md) section 7.2.
Son accepted FG-2, FG-3, and FG-4 on 2026-11-12. FG-1 and FG-5 wait for U-1 and U-6.

## Goals / Non-Goals

**Goals**

- Build every user-visible surface from one `RuntimeStatus` value and the shell preferences.
- Make status-to-UI mapping, setup step derivation, and copy testable without AppKit or a running tap.
- Let real grant changes drive setup before M2, without changing input behavior.

**Non-Goals**

- Field profiles, the profile resolver, shortcut matching, mode ownership in the pipeline, `InstanceLock`, and `LoginItem` registration logic. They belong to `telex-input-mvp` task group 3. This change renders their state through protocols with simulator stubs.
- VS Code A1 hint and `eventOnly` copy (FG-1 pending), the in-window try-it field (FG-5 and U-6 pending), and the Other input tool step (U-9 pending).

## Decisions

### D1. Status value types land in `VietMacPlatform` as data only

Add `InputMode`, `ModeSource`, `Capabilities`, `BlockReason`, `StandbyReason`, `Availability`, `Assurance`, `FieldKind`, and the `RuntimeStatus` struct with a public memberwise initializer, exactly as in architecture-spec section 7.2. Remove the unused `enum RuntimeStatus` namespace, which has no callers.
`PauseReason` and `InputRuntimeState` stay until M2 removes the prototype pipeline.
Benefit: the shell and the simulator compile against the final interface now, so M2 swaps the producer without touching the shell.
Trade-off: the types exist before the pipeline produces all of them. `active(.eventOnly)` and several Standby reasons are reachable only through the simulator until M2.

### D2. A temporary M0 adapter produces the status

`M0StatusAdapter` reads the M0 host's public state on the main run loop and builds a `RuntimeStatus`:

| M0 source | New field |
| --- | --- |
| `enabled` | `mode` (`vietnamese` when enabled) |
| `PermissionSnapshot` | `capabilities` |
| input source, frontmost bundle ID | `inputSourceID`, `frontmostBundleID` |
| `paused(accessibility/listening/posting/unsupportedSource/tapUnavailable/recoveryLimit/userDisabledTap/transportUncertain)` | `blocked` with the same reason |
| `paused(secureInput)` | `standby(secureInput)` |
| `paused(unsupportedApp)` | `standby(unsupportedApp)` |
| `paused(uncertainContext)` | `standby(fieldUnreadable)` |
| `paused(sleeping)` | `standby(sleeping)` |

`shortcutArmed` is false and `profileID`, `fieldKind`, `conflictingBundleID` are nil, because M0 has none of them.
The adapter needs read-only public accessors on `InputHost` for input source and frontmost bundle ID. These add no work to the callback and change no gate.
The adapter publishes from a run-loop observer that compares with the last value, as section 7.4 specifies, so the shell already uses the M2 publication contract.
Benefit: UX-2, UX-3, UX-12, and UX-13 can be verified against real grants now.
Trade-off: M0 evaluates gates in a different order (architecture-spec 6.1). Until M2, the first reason shown can differ from the target order. Tests for gate order belong to M2, not to this change.

### D3. A `VietMacShell` library target holds the logic

| Unit | Input | Output |
| --- | --- | --- |
| `StatusPresentation` | `RuntimeStatus`, preferences, profile table | UI class, title, badge, accessibility label, status line, detail line, action |
| `SetupPlan` | `RuntimeStatus`, settled-unknown flags, last step seen | Step list, current step, completion |
| `Strings` | Key, language | Localized text from `Localizable.xcstrings` |
| `ProfileCatalog` protocol | — | Rows for Settings › Apps; a stub until M2 supplies the compiled table |

The `VietMacApp` executable keeps only AppKit code: `StatusItemController`, `SetupWindow`, `SettingsWindow`, `ModeHUD`, and the Debug simulator.
A new `VietMacShellTests` target tests the pure units.
Benefit: UX-8 and the copy rules are checked by unit tests for every reason and both languages.
Trade-off: one more target and a resource bundle for string catalogs in the SwiftPM build. `make app` must copy the localized resources into the bundle.

### D4. Settled unknowns are compile-time flags

`SetupFeatures` holds `inputMonitoringRequired` (U-2, default true), `conflictDetection` (U-9, default false), `inAppTryIt` (FG-5 and U-6, default false), and `distinguishesLoginLaunch` (U-15, default false).
A flag changes only after the unknown has a recorded native result and a ledger entry.
Benefit: the step list and launch rules follow evidence, not guesses.
Trade-off: a settled unknown needs a rebuild. That is acceptable for a personal build.

### D5. Permission requests run from a button action only

`PermissionRequester` wraps `CGRequestListenEventAccess` and `AXIsProcessTrustedWithOptions` with the prompt option. Only button actions in `SetupWindow` and `SettingsWindow` call it. It then opens the System Settings pane by URL.
A unit test asserts that `StatusItemController`, the status observer, and the app delegate launch path hold no reference to the requester.
`CGRequestPostEventAccess` is not called from the UI. Posting follows the Accessibility grant (**inferred**, verified once in session 2).

### D6. Refresh cadence while windows are visible

While a setup or settings window is visible, the shell asks the host for the 250 ms refresh even in English mode, as architecture-spec section 7.5 requires. In M0 the refresh timer already runs in every mode (**verified**, `InputHost.swift:70-74`), so the adapter needs no change for this.

### D7. Preferences

`ShellPreferences` stores, in the app's own defaults domain: last setup step seen, setup-completed-once flag, last Settings tab, shortcut, exclusions, and the login-startup request. It never stores status, counters, or text. Mode persistence stays in `telex-input-mvp` task 3.4; until then the shell writes the M0 enabled flag only as it does today.

## Risks / Trade-offs

- Interim M0 support so the shell can be tested end to end (Son's request of 2026-11-14). Each item moves to `telex-input-mvp` M2 unchanged in the shell:
  - Exclusions: `InputHost.excludedBundleIDs` makes an excluded trial app unsupported, so keys pass through (the safe direction); `M0StatusAdapter` reports it as `standby(excludedApp)`.
  - Shortcut: the shell registers the chord as a Carbon system hot key only while `shortcutArmed` is true, outside the key callback. `M0StatusAdapter.shortcutArmed` applies the architecture-spec 7.2 rule from cached host values, including `InputHost.secureInput`. M2 replaces this with matching in the callback.
  - Login startup: `LoginItem` calls `SMAppService.mainApp` directly and shows the system state; U-7 (registration of a bundle under `.artifacts`) is still unknown.
- `make app-debug` builds `VietMac Debug.app` with its own bundle ID and the simulator; `--snapshot-dir` (Debug only) renders every setup step, Help page, Settings tab, and the menu text for each reason. Snapshots are model evidence, not UX-25 screenshots.
- `scripts/tests/test_permission_requests.py` checks that only `PermissionRequester` calls a request function and only window button commands call the requester.
- The string catalog is copied, not compiled: the Command Line Tools build has no string compiler. `StringTable` reads `Localizable.xcstrings` as JSON, and `make app` copies it to `Contents/Resources`.
- The M0 adapter shows `uncertainContext` as quiet `fieldUnreadable`. A selection in M0 then hides the reason that the word is held. This matches the M2 target, where selections are word-level holds and not status.
- Vietnamese pane names in System Settings on macOS 27 are **unknown** (UX-20). The copy uses the names in ux-spec and is checked on a Vietnamese system before closing.
- macOS 27 appearance facts are **inferred** from press coverage. UX-25 checks the built app on Son's Mac.
- A non-activating setup window at launch (D4 fallback) is **inferred** implementable. If it takes focus in the U-15 check, the fallback becomes no window plus the triangle badge.

## Migration Plan

1. Add the types and the adapter; the M0 menu keeps working.
2. Replace the menu with `StatusItemController`; move the M0 developer items behind the Debug simulator menu.
3. Add Setup, Settings, HUD, and Help.
4. M2 replaces `M0StatusAdapter` with `InputHost.status` and `onStatusChange`, and supplies the profile table, `LoginItem`, and `shortcutArmed`. The shell does not change.

Rollback: the app target can return to the M0 menu file; platform input behavior was never changed.

## Open Questions

- Suggested shortcut chord: `⌃⌥V` is the candidate. It ships in `Dùng gợi ý` only after a native conflict test in the five apps (PD-1).
- Whether the menu reads the status synchronously enough with the M0 adapter when the menu opens during a refresh. Measure with the simulator first, then natively.
