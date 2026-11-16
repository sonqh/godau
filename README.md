# Gõ Dấu

Vietnamese input for macOS. Private repository: [sonqh/vietmac](https://github.com/sonqh/vietmac).

Gõ Dấu is Son's personal Vietnamese input app for macOS. The app was renamed from VietMac on 2026-11-16.
The repository, Swift modules, scripts, and bundle ID (`local.sonquach.vietmac`) keep the VietMac name,
so macOS permissions survive the rename. The built bundle is `.artifacts/GoDau.app`.
You type Telex, and VietMac replaces the keys with precomposed Unicode through generated events.
It does not use marked text.
The app must work in five applications: VS Code, Chrome, Dia, Safari, and Apple Notes.

## Current status

The M0 event-tap host now runs the complete Telex composer (`VietMacCore/TelexComposer`) with prepared Unicode replacement.
The `ux-shell` UI runs on top of it: the menu, Setup, Help, Settings, and the mode HUD.
The app starts in English mode.

- Verified: native automation passed the Telex scenarios in Chrome, Dia, and Safari on 2026-11-14.
- Not yet accepted: physical typing, Notes, VS Code, and callback performance.

To test the app yourself, follow [the manual test guide](docs/verification/ux-shell-manual-test.md).

## Quick start

You need Swift 6 or later, a macOS SDK, Python 3.9 or later, and Node.js 20.19 or later.
OpenSpec is a pinned local development dependency. The runtime has no Node or Python dependency.

```sh
make setup
make check
make bench
make app
```

`make app` builds `.artifacts/GoDau.app` and signs it locally. It does not open or install the app.

### Open and inspect the app

- Signing is ad hoc by default. To sign with a local identity you chose, set `VIETMAC_SIGNING_IDENTITY`.
- For a read-only capability snapshot, run `.artifacts/GoDau.app/Contents/MacOS/VietMac --diagnostics`. This command creates no event tap.
- To record evidence, open the app with `open .artifacts/GoDau.app --args --evidence-dir <absolute path>`. The app records the session's capabilities, context counters, and callback timings. Send `SIGUSR1` to refresh the record.
- Before you enable the prototype, read [M0 verification and pending native checks](docs/verification/macos-transport-spike.md).

### Toolchain

- `scripts/swift.sh` uses the installed Command Line Tools when they are available. It does not change global developer settings.
- To use another toolchain, set `VIETMAC_SWIFT_BIN` to an explicit Swift executable.
- Swift Testing provides the core tests. The local test command disables XCTest.
- When the CLT layout requires it, the wrapper loads the bundled test macro explicitly.

## Project layout

```text
VietMac/
  AGENTS.md                        Shared instructions for Codex and Claude
  CLAUDE.md                        Claude entry point
  Package.swift                    Runtime modules and development executables
  Apps/VietMac/                    Menu bar application shell and bundle metadata
  Sources/
    VietMacCore/                   Reusable semantic contracts and replacement planner
    VietMacPlatform/               Event tap, context inspection, prototype, and prepared transport
    VietMacReplay/                 Synthetic fixture replay
    VietMacBench/                  Release benchmark with explicit measurement scope
  Tests/                          Core/Unicode and synthetic platform checks
  Fixtures/                        Synthetic expected behavior
  benchmarks/baselines/            Tracked measurements with scope and environment
  openspec/
    config.yaml                    Project context and artifact rules
    specs/                         Baseline requirements for delivered capabilities
    changes/                       Active changes: ux-shell, telex-input-mvp, macos-transport-spike, native-test-automation
  .agents/skills/                  Generated OpenSpec skills for Codex
  .claude/skills/                  Generated OpenSpec skills for Claude
  .claude/commands/opsx/           Generated Claude commands
  ledger/                          Append-only development evidence
  scripts/                         Build, spec, and ledger entry points
  docs/                            Architecture, workflow, provenance, and evidence
```

## Design documents

Start with [architecture](docs/architecture.md), [development workflow](docs/development.md), and [performance policy](docs/performance.md).

Three proposed documents describe the target app and the delivery order:
the [architecture specification](docs/architecture-spec.md), the [UX specification](docs/ux-spec.md), and the [product roadmap](docs/product-roadmap.md).
They do not describe delivered behavior.
Son decided FG-1 on 2026-11-14 (option C: the VS Code editor and Quick Open stay literal in v0.1). FG-2 to FG-5 still await Son.

The [bootstrap evidence](docs/verification/bootstrap.md) separates tested scaffolding from pending native behavior.

## OpenSpec changes

Four changes are active. The next work is in `ux-shell`, then `telex-input-mvp`.

| Change | Purpose | Tasks done (2026-11-14) |
| --- | --- | --- |
| [ux-shell](openspec/changes/ux-shell/proposal.md) | Status menu, guided Setup, Settings, Help, and mode HUD | 12 of 16 |
| [telex-input-mvp](openspec/changes/telex-input-mvp/proposal.md) | Complete Telex reducer, English/Vietnamese controls, full-engine native acceptance | 8 of 27 |
| [macos-transport-spike](openspec/changes/macos-transport-spike/proposal.md) | M0 proof of ordered replacement and context resets (`as` → `á`, `aa` → `â`) | 5 of 12 |
| [native-test-automation](openspec/changes/native-test-automation/proposal.md) | Scripted synthetic key events for repeatable native tests | 7 of 15 |

- `ux-shell` waits for Son's results from [the manual test guide](docs/verification/ux-shell-manual-test.md). These results close tasks 3.2, 3.3, 3.4, and 5.1.
- `telex-input-mvp` continues with milestone M2. Its [specifications](openspec/changes/telex-input-mvp/specs/telex-composition/spec.md) use Son's selected `hòa`, `khỏe`, and `thúy` convention. The reducer and the callback have separate performance gates.
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

## Later work

Later extensions include VNI, macros, more layouts, and per-app modes, when usage justifies them.
See [provenance](docs/provenance.md) for the OpenKey research baseline.
