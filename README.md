# VietMac

Vietnamese input for macOS. Private repository: [sonqh/vietmac](https://github.com/sonqh/vietmac).

VietMac is the foundation for Son's personal macOS Vietnamese input app.
The product uses Telex, precomposed Unicode, and event-based replacement without marked text.
Required applications are VS Code, Chrome, Dia, Safari, and Apple Notes.

**Current status:** the M0 event-tap host with prepared Unicode replacement now runs the complete Telex composer
(`VietMacCore/TelexComposer`), behind the `ux-shell` menu, Setup, Help, Settings, and mode HUD. It starts in English mode.
Native automation passed Telex scenarios in Chrome, Dia, and Safari on 2026-11-14; physical typing, Notes, VS Code, and callback performance are not yet accepted.
See [the manual test guide](docs/verification/ux-shell-manual-test.md).

## Quick start

Requirements: Swift 6 or later, a macOS SDK, Python 3.9 or later, and Node.js 20.19 or later.
OpenSpec is a pinned local development dependency. The runtime has no Node or Python dependency.

```sh
make setup
make check
make bench
make app
```

`make app` builds and locally signs `.artifacts/VietMac.app` without launching or installing it.
Signing defaults to ad hoc; set `VIETMAC_SIGNING_IDENTITY` explicitly to use a chosen local identity.
Run `.artifacts/VietMac.app/Contents/MacOS/VietMac --diagnostics` for a read-only capability snapshot without creating an event tap.
Launch with `open .artifacts/VietMac.app --args --evidence-dir <absolute path>` to record the running session's capabilities, context counters, and callback timings (refreshed on `SIGUSR1`).
See [M0 verification and pending native checks](docs/verification/macos-transport-spike.md) before enabling the prototype.
`scripts/swift.sh` uses the installed Command Line Tools when available without changing global developer settings.
Set `VIETMAC_SWIFT_BIN` to an explicit Swift executable to use another toolchain.
Swift Testing provides the core tests. XCTest is disabled for the local test command.
The wrapper loads the bundled test macro explicitly when the CLT layout requires it.

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
    changes/macos-transport-spike/ First planned native change
  .agents/skills/                  Generated OpenSpec skills for Codex
  .claude/skills/                  Generated OpenSpec skills for Claude
  .claude/commands/opsx/           Generated Claude commands
  ledger/                          Append-only development evidence
  scripts/                         Build, spec, and ledger entry points
  docs/                            Architecture, workflow, provenance, and evidence
```

## Design and next work

Start with [architecture](docs/architecture.md), [development workflow](docs/development.md), and [performance policy](docs/performance.md).
The proposed [architecture specification](docs/architecture-spec.md), [UX specification](docs/ux-spec.md), and [product roadmap](docs/product-roadmap.md) describe the target app and delivery order.
They are not delivered behavior; final-gate decisions FG-1 to FG-5 await Son.
The [bootstrap evidence](docs/verification/bootstrap.md) distinguishes tested scaffolding from pending native behavior.

The active OpenSpec change is [macos-transport-spike](openspec/changes/macos-transport-spike/proposal.md).
It proves ordered replacement and context resets with `as` → `á` and `aa` → `â` before a full Telex engine.
Native verification must cover the required fields and autocomplete behavior in all five apps.

The follow-on [Telex input MVP plan](openspec/changes/telex-input-mvp/proposal.md) covers the complete reducer,
English/Vietnamese controls, full-engine native acceptance, and separate reducer/callback performance gates.
Its [specifications](openspec/changes/telex-input-mvp/specs/telex-composition/spec.md) use Son's selected `hòa`, `khỏe`, and `thúy` convention.
Implement it only after the native spike passes; these artifacts describe planned behavior, not delivered typing support.

```sh
./scripts/openspec.sh status --change macos-transport-spike
python3 scripts/ledger.py recent --limit 5
```

Use the shared workflow with either engine:

- Claude: `/opsx:apply macos-transport-spike` in the project chat.
- Codex: `$openspec-apply-change macos-transport-spike` or select the generated skill in the app.

These are assistant invocations, not terminal commands.
The generated integrations follow the [official OpenSpec tool paths](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md).

The first native gate precedes a complete composition engine.
Later extensions include VNI, macros, additional layouts, and per-app modes when usage justifies them.
See [provenance](docs/provenance.md) for the OpenKey research baseline.
