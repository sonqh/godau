# UX shell tasks

All tasks are pending. A simulator render is model evidence, not native evidence.
`telex-input-mvp` M2 owns field profiles, shortcut matching, login registration, and the single-instance lock. This change renders their state through stubs.

## 1. Status types and shell logic

- [x] 1.1 Add the architecture-spec 7.2 status value types to `VietMacPlatform` as data with a public memberwise initializer, and remove the unused `RuntimeStatus` namespace; verify `make test` passes and no callback or transport file changed.
- [x] 1.2 Add the `VietMacShell` library and `VietMacShellTests` targets with `StatusPresentation`; verify by tests that every `BlockReason` and `StandbyReason` maps to the title, badge, accessibility label, status line, detail line, and action in ux-spec sections 5.1 and 5.4, and that quiet reasons leave the title unbadged.
- [x] 1.3 Add `Localizable.xcstrings` with Vietnamese and English for every surface, and a copy-rule test; verify both languages have the same keys, Vietnamese strings are NFC, and English strings contain no dash, semicolon, contraction, "error", or "failed".
- [x] 1.4 Add `SetupPlan` and `SetupFeatures` flags; verify by tests the derived step list, the step count, completion from capabilities, input source, and conflicting tool only, and the first missing item in gate order on reopen.

## 2. Status source and menu

- [x] 2.1 Add `M0StatusAdapter` and read-only `InputHost` accessors for input source and frontmost bundle ID, publishing from a run-loop observer at most once per pass; verify by tests the M0 reason mapping table in design D2 and that equal statuses do not republish.
- [x] 2.2 Replace the M0 menu with `StatusItemController`: template `VI` / `EN` title, badges, 500 ms Standby debounce, menu order, one action, resume rules, exclusion item, Option-revealed report item; verify UX-8 for every reason in both languages with the simulator.
- [x] 2.3 Add the Debug status simulator menu that renders any status in the menu, setup, settings, and HUD without calling `InputHost`; verify the Release bundle from `make app` contains no simulator code path.

## 3. Setup and Help

- [ ] 3.1 Add `SetupWindow` with the derived step list, grant steps, stale-entry help, 20 s reopen offer, Keyboard step, Notes try-it variant, and Ready step with defaults; verify UX-1, UX-4, UX-5, and UX-7 (defaults only) with the simulator and the M0 adapter.
- [ ] 3.2 Add `PermissionRequester` called only from setup and settings button actions; verify by test that the launch path, status observer, and menu hold no reference to it, and verify UX-2 natively with Son's grant (pane opens, VietMac listed).
- [ ] 3.3 Add grant-change feedback: `Đã bật ✓` within one pass, focus on `Tiếp tục`, VoiceOver announcement, raise only when System Settings is frontmost; verify UX-3 and UX-12 natively by turning Accessibility on and off with Son, after U-3 has a recorded safe result.
- [ ] 3.4 Add launch rules: first launch opens step 1, manual launch with a missing item opens once with the update heading, and the non-activating fallback until U-15; verify UX-13 natively and that the frontmost app keeps focus in the fallback.
- [x] 3.5 Add Help mode with the five pages, each under 120 words; verify word counts by test and page links from the menu actions.

## 4. Settings and HUD

- [ ] 4.1 Add `SettingsWindow` with General, Apps, and Status tabs; shortcut recorder rules and not-armed line; login checkbox bound to a `LoginItem` protocol stub; Apps rows from a `ProfileCatalog` stub showing `Chưa hỗ trợ` for unaccepted profiles; Status rows and the technical disclosure; verify UX-22 with the simulator and the ad hoc warning with a stub diagnostics value.
- [ ] 4.2 Add the non-activating `ModeHUD` shown only for `modeSource == shortcut`; verify with the simulator that menu and setup mode changes show no HUD and that Reduce Motion removes the fade. The native focus check (U-8) stays with `telex-input-mvp`.

## 5. Acceptance and handoff

- [ ] 5.1 Verify UX-17, UX-18, UX-20, and UX-25 on Son's Mac with macOS 27: keyboard only, VoiceOver, light and dark, Increase Contrast, Reduce Motion, Reduce Transparency, both Liquid Glass slider ends, menu bar background on and off, and both UI languages on a Vietnamese system; save screenshots of every state as evidence.
- [ ] 5.2 Run `make check`, `make app`, and `./scripts/openspec.sh validate ux-shell --strict`; update `Apps/VietMac/README.md` to the delivered shell, list the UX criteria left for `telex-input-mvp`, and append one ledger handoff.
