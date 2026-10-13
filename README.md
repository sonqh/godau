# VietMac

Vietnamese input for macOS. Private repository: [sonqh/vietmac](https://github.com/sonqh/vietmac).

VietMac is the foundation for Son's personal macOS Vietnamese input app.
The product uses Telex, precomposed Unicode, and event-based replacement without marked text.
Required applications are VS Code, Chrome, Edge, Dia, and Apple Notes.

**Current status:** project scaffold, a tested replacement planner, replay fixtures, and development tooling.
The menu bar shell builds, but Vietnamese composition and native event transport are not implemented.
App compatibility and callback performance remain unverified.

## Quick start

Requirements: Swift 6 or later, a macOS SDK, Python 3.9 or later, and Node.js 20.19 or later.
OpenSpec is a pinned local development dependency. The runtime has no Node or Python dependency.

```sh
make setup
make check
make bench
make app
```

`make app` builds `.artifacts/VietMac.app` without launching, installing, or signing it.
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
    VietMacPlatform/               macOS adapter boundary and capability inspection
    VietMacReplay/                 Synthetic fixture replay
    VietMacBench/                  Release benchmark with explicit measurement scope
  Tests/VietMacCoreTests/          Model and Unicode checks
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
The [bootstrap evidence](docs/verification/bootstrap.md) distinguishes tested scaffolding from pending native behavior.

The active OpenSpec change is [macos-transport-spike](openspec/changes/macos-transport-spike/proposal.md).
It proves ordered replacement and context resets with `as` → `á` and `aa` → `â` before a full Telex engine.
Native verification must cover the required fields and autocomplete behavior in all five apps.

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
