# Proposal

## Why

VietMac transforms text only in five hard-coded applications (`trialApps`), and each new application needs manual native testing before it is added. Son finds that per-app testing costs too much time. A review on 2026-11-17 of OpenKey, GoNhanh, PHTV, XKey, goxkey, VKey, vnkey, and ibus-bamboo found that none of them uses an allowlist: every application gets a default path, and exceptions are added per problem class. VietMac can do the same with less risk, because it can measure what the focused field reports instead of guessing from a bundle ID.

## What Changes

- **BREAKING** Remove the application allowlist. Vietnamese transformation is available in every application the user has not excluded.
- Select the assurance level per focused field from what the field reports at run time:
  - `observed` when the field reports a collapsed caret and a character count. This is the current verified path.
  - `eventOnly` when the field has a text-entry role but does not support those attributes.
  - Literal input when the focus is not a text-entry element, or no focused element can be read.
- A failed or timed-out Accessibility read never selects `eventOnly`.
- The existing `addressBar` and `vscodeEditor` profiles keep their behavior and take precedence over the capability rule.
- The user can exclude any application, not only the five listed ones. The `unsupportedApp` status is no longer produced.
- Terminal applications are no longer excluded as a class. They follow the same capability rule and are untested.
- Field-profile acceptance stops being a gate for transformation. It becomes an evidence label: "tested" for field families with native evidence, "untested" for the rest.

Usable outcome: Son can type Vietnamese in an application outside the five without a code change.

Completion gate: model checks pass, and native evidence exists for one `observed` field and one `eventOnly` field in applications outside the five, plus a non-text focus that stays literal.

Exclusions:

- No per-application behavior tables copied from other projects. A new exception profile is added only for a reported failure.
- No invisible sentinel characters, clipboard use, marked text, or delays in the key callback.
- No user-facing switch to force a mode per application.
- No fix for fields that report a caret and count that do not follow the text (for example some custom web editors). They stay literal under `observed`.

Required application surfaces do not change: VS Code, Chrome, Dia, Safari, and Apple Notes stay the acceptance set for the MVP. Other applications are best effort and carry no acceptance claim.

## Capabilities

### New Capabilities

- `field-coverage`: Which focused fields receive Vietnamese transformation, which assurance level each one gets, and how exclusions and evidence labels apply.

### Modified Capabilities

None in `openspec/specs`. This change conflicts with requirements that exist only in active changes. The tasks reconcile them:

- `telex-input-mvp` / `input-mode-control`: "Tested-context gating and exclusions" (transformation only in an accepted compiled profile; terminals and unsupported apps stay literal).
- `telex-input-mvp` / `telex-mvp-acceptance`: "Dogfood build with accepted profiles only".
- `ux-shell` / `settings-window`: "Apps tab from the profile table".
- `ux-shell` / `status-menu`: the `unsupportedApp` flicker scenario and the exclusion item's scope.

## Impact

- `Sources/VietMacPlatform`: `InputHost` (allowlist, focus observation, event-only selection), `FocusMonitor` (capability and error classification), `RuntimeStatus` and `StatusInterface` (pause and standby reasons, counters), `M0StatusAdapter` (assurance and exclusion mapping).
- `Sources/VietMacShell` and `Apps/VietMac`: menu exclusion item, Apps tab rows and labels, status text, string catalog.
- `Tests/VietMacPlatformTests`, `Tests/VietMacShellTests`: gating, mapping, and presentation tests.
- Documents: `docs/architecture-spec.md` sections 6.1 and 6.4 and AD-10, `docs/ux-spec.md`, `docs/verification/ux-shell-manual-test.md`, `README.md`.
- `VietMacCore` does not change. No new dependency. No new per-key work in the callback.
