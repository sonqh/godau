# Tasks

Native tasks stay pending until real application evidence exists. A passing model test or build is not native evidence.

## 1. Capability classification

- [ ] 1.1 (Blocked 2026-11-17: the development shell has no Accessibility permission; read `rangeUnsupported` / `countUnsupported` from the observation trace of the group 5 runs instead.) Probe the AX error codes for selected range and character count in three applications outside the required five (one native text field, one Electron application, one terminal) with a read-only script; record roles and error codes in the ledger with no field content
- [x] 1.2 Add the capability value to `FocusInspection` and classify reads in `FocusMonitor` per design D2 and D3 (unsupported or no-value gives `eventOnly`; other errors give a failed read; sticky `observed` after the first caret reading); verify with new `ContextTrackingTests` cases for each table row
- [x] 1.3 Update `docs/architecture-spec.md` section 6.4 and AD-10 to describe capability selection and to mark acceptance as an evidence label; verify the section no longer says `trialApps` or accepted profiles gate transformation

## 2. Remove the allowlist

- [x] 2.1 Rename `trialApps` to `requiredApps` for diagnostics only, replace `InputEnvironment.supportedApp` with `appExcluded`, rename `PauseReason.unsupportedApp` to `excludedApp`, and allow inspection for every non-excluded application; verify `PrototypePipelineTests` cover the excluded pause and that no source references `trialApps`
- [x] 2.2 Set `eventOnlyField` for the generic `eventOnly` capability with the `vscodeEditor` handling and no completion-clearing key, keep the two identified profiles ahead of it, and add the `eventOnlyReplacements` counter; verify by tests that an event-only field admits a replacement without a settled observation and that a focus change invalidates the word
- [x] 2.3 Keep a non-text focus and a missing focused element literal; verify by test that `as` in a non-text focus produces two pass-through keys and no prepared replacement
- [x] 2.4 Run `make check` and the sanitizer checks if any buffer or index code changed; record the commands and results in the ledger

## 3. Status and shell

- [x] 3.1 Publish `active(observed)` or `active(eventOnly)`, `standby(noTextField)`, and `standby(excludedApp)` from `M0StatusAdapter`, and remove `StandbyReason.unsupportedApp` with its strings; verify `M0StatusAdapterTests` and `StatusPresentationTests` cover each mapping and the string catalog has the same keys in both languages
- [x] 3.2 Show the exclusion menu item for any frontmost bundle ID; verify `MenuModelTests` with a bundle ID outside the catalog
- [x] 3.3 Build Apps tab rows from the catalog plus excluded bundle IDs, rename `accepted` to `tested`, and use the labels `Đã kiểm thử ✓` and `Chưa kiểm thử`; verify `SettingsModelTests` for an excluded application outside the catalog
- [x] 3.4 Update `docs/ux-spec.md` (status table, copy table, Apps tab) and `docs/verification/ux-shell-manual-test.md` row A3; verify no row names `unsupportedApp`

## 4. Reconcile active changes

- [x] 4.1 Update `telex-input-mvp` specs: rewrite "Tested-context gating and exclusions" in `input-mode-control` and "Dogfood build with accepted profiles only" in `telex-mvp-acceptance` to point to `field-coverage`; verify `./scripts/openspec.sh validate telex-input-mvp` passes
- [x] 4.2 Update `ux-shell` specs: "Apps tab from the profile table" in `settings-window`, and the `unsupportedApp` scenario and exclusion scope in `status-menu`; verify `./scripts/openspec.sh validate ux-shell` passes
- [x] 4.3 Update `README.md` current status and `openspec/config.yaml` context to say the five applications are the acceptance set and other applications are best effort; verify both name `open-app-coverage`

## 5. Native verification

- [x] 5.1 Type the scripted Telex words in one `observed` field outside the required five (for example TextEdit); record application version, macOS version, counters, and result in the ledger
- [ ] 5.2 Type the scripted Telex words in one `eventOnly` field outside the required five, chosen from the 1.1 probe; record `eventOnlyReplacements` and the result
- [x] 5.3 Type `as` with a non-text focus (for example a Finder file list) and confirm that no Backspace is posted and nothing is deleted; record the result
- [ ] 5.4 (2026-11-17: typing is correct in all five by Son's report, but `unexplainedFieldChanges` rose to 41 against 2 on 2026-11-16 and cannot be attributed without the bundle ID in the trace; repeat with the next build.) Repeat one Telex scenario in each of the five required applications and confirm the counters show no new `unexplainedFieldChanges` or `replacementsUnconfirmed` against the 2026-11-16 evidence

## Workflow follow-up

- Archive the change after the native tasks in group 5 have ledger evidence.
