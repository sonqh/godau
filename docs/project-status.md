# Project status

This page is for people who work on Gõ Dấu. It records delivery state, design documents, and the active OpenSpec changes.
For what the app does and how to install it, read the [README](../README.md).

## Current status

The M0 event-tap host now runs the complete Telex composer (`VietMacCore/TelexComposer`) with prepared Unicode replacement.
The `ux-shell` UI runs on top of it: the menu, Setup, Help, Settings, and the mode HUD.
The app starts in English mode.

- Verified: native automation passed the Telex scenarios in Chrome, Dia, and Safari on 2026-11-14.
- Not yet accepted: physical typing, Notes, VS Code, and callback performance.
- Not yet verified natively: typing in applications outside the five. Each field gets `observed` checking when it reports a caret and a character count, and `eventOnly` when it is a text field without them. Other focus stays as typed.

To test the app yourself, follow [the manual test guide](verification/ux-shell-manual-test.md).

## Design documents

Start with [architecture](architecture.md), [development workflow](development.md), and [performance policy](performance.md).

Three proposed documents describe the target app and the delivery order:
the [architecture specification](architecture-spec.md), the [UX specification](ux-spec.md), and the [product roadmap](product-roadmap.md).
They do not describe delivered behavior.
Son decided FG-1 on 2026-11-14 (option C: the VS Code editor and Quick Open stay literal in v0.1). FG-2 to FG-5 still await Son.

The [bootstrap evidence](verification/bootstrap.md) separates tested scaffolding from pending native behavior.

## OpenSpec changes

Five changes are active. The next work is in `ux-shell`, then `telex-input-mvp`.

| Change | Purpose | Tasks done (2026-11-14) |
| --- | --- | --- |
| [ux-shell](../openspec/changes/ux-shell/proposal.md) | Status menu, guided Setup, Settings, Help, and mode HUD | 12 of 16 |
| [telex-input-mvp](../openspec/changes/telex-input-mvp/proposal.md) | Complete Telex reducer, English/Vietnamese controls, full-engine native acceptance | 8 of 27 |
| [macos-transport-spike](../openspec/changes/macos-transport-spike/proposal.md) | M0 proof of ordered replacement and context resets (`as` → `á`, `aa` → `â`) | 5 of 12 |
| [native-test-automation](../openspec/changes/native-test-automation/proposal.md) | Scripted synthetic key events for repeatable native tests | 7 of 15 |
| [open-app-coverage](../openspec/changes/open-app-coverage/proposal.md) | Vietnamese in every application, with the checking level chosen from what each field reports | 15 of 18 (2026-11-17) |

- `ux-shell` waits for Son's results from [the manual test guide](verification/ux-shell-manual-test.md). These results close tasks 3.2, 3.3, 3.4, and 5.1.
- `telex-input-mvp` continues with milestone M2. Its [specifications](../openspec/changes/telex-input-mvp/specs/telex-composition/spec.md) use Son's selected `hòa`, `khỏe`, and `thúy` convention. The reducer and the callback have separate performance gates.
- `macos-transport-spike` closes after the native unknowns U-1, U-3, U-4, and U-14 run. Native verification must cover the required fields and autocomplete behavior in all five apps.

The plan put the native spike before the full engine.
On 2026-11-14, Son made an FG-2 exception: the composer runs before the M0 native gate closes, so that the MVP can be tested.
The MVP artifacts still describe planned behavior. Typing support counts as delivered only after native acceptance.

```sh
./scripts/openspec.sh list
./scripts/openspec.sh status --change ux-shell
python3 scripts/ledger.py recent --limit 5
```

Both assistants use the same workflow. Replace `<change>` with a change name from the table:

- Claude: `/opsx:apply <change>` in the project chat.
- Codex: `$openspec-apply-change <change>` or select the generated skill in the app.

You type these in the assistant, not in a terminal.
The generated integrations follow the [official OpenSpec tool paths](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md).
