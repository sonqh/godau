# UX shell (Track U)

## Why

The app shows an M0 developer menu: a constant `VM` title, raw pause strings, and a ✓/✗ access row. A new user cannot set it up without help, and Son cannot tell from the menu why a word did not change.
[ux-spec.md](../../../docs/ux-spec.md) defines the setup flow, menu bar states, reasons, Settings, and Help. Son accepted FG-2 on 2026-11-12, so this shell can be built now on simulated states, beside the Telex core, before integration.

## What Changes

- Replace the M0 developer menu with a status menu: `VI` / `EN` title, template badges for Standby and Blocked, one status line, one detail line, and at most one next-step item per reason.
- Add a guided Setup window whose step list is derived from capabilities, input source, and a conflicting tool, plus a Help mode with short pages.
- Add a Settings window with General, Apps, and Status tabs. The Apps tab reads the compiled field-profile table.
- Add a mode HUD for mode changes made with the shortcut.
- Ship Vietnamese and English string tables that follow the copy rules in ux-spec section 9.
- Call the system permission-request functions only from a click on a setup or settings button (FG-3, accepted 2026-11-12).
- Add a Debug-only status simulator that renders any `RuntimeStatus` value without `InputHost`.
- Until `telex-input-mvp` M2 delivers the real status, an adapter maps the M0 host's capabilities, input source, and pause into the new status, so grant changes are real during setup.

Exclusions: no change to input behavior in `VietMacPlatform`; no field profiles, shortcut matching, login registration, or single-instance lock (those stay in `telex-input-mvp` task group 3); no VS Code screen-reader hint or reduced-checking copy until Son decides FG-1; no in-window try-it field until U-6 passes (FG-5); no notifications, sounds, Dock icon, popover, or UI-language picker.
The required application surfaces do not change.

## Capabilities

### New Capabilities

- `status-menu`: Menu bar item states, the status menu, reason copy and next steps, exclusions from the menu, and the mode HUD.
- `guided-setup`: The derived setup step list, user-initiated permission requests, the try-it step, launch rules for opening setup, and Help pages.
- `settings-window`: The General, Apps, and Status tabs, including shortcut recording, login-startup state, and the diagnostics disclosure.
- `shell-presentation`: Localization, copy rules, macOS 27 appearance, accessibility, and the rule that every visible state comes from `RuntimeStatus` and preferences only.

### Modified Capabilities

None. `input-mode-control` in `telex-input-mvp` owns runtime status semantics. This change renders that status.

## Impact

- `Apps/VietMac`: the shell is split into a testable `VietMacShell` library target (status-to-copy mapping, step derivation, string tables) and the app executable (AppKit windows and menu).
- `VietMacPlatform`: adds the public `RuntimeStatus` value types from architecture-spec section 7.2 as data only, and a temporary M0 adapter. No callback, transport, or context-policy change.
- New tests for status mapping, step derivation, copy rules, and the simulator. No new dependency or network code.

## Completion gate

Exit evidence: UX-1 to UX-5, UX-8, UX-12, UX-13, UX-17, UX-18, UX-20, UX-22, and UX-25 pass against the simulator and real grant changes on this Mac. Screenshots of every state in light and dark appearance are saved as evidence. `make check` and `make app` pass.
UX criteria that need the full engine or M2 (UX-6, UX-7, UX-9 to UX-11, UX-14 to UX-16, UX-19, UX-21, UX-23, UX-24) stay with `telex-input-mvp`. A simulator render is not evidence for native behavior.
