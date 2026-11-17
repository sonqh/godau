# Development with Claude and Codex

Both engines use `AGENTS.md`, the same OpenSpec artifacts, and the same development ledger.
Choose either engine for a task. There is no automatic multi-agent orchestrator or mandatory role split.

## Source of truth

| Question | Read or update |
| --- | --- |
| What behavior currently exists? | `openspec/specs` and source with verification evidence |
| What behavior is planned? | The active change's proposal and delta specs |
| How will it work? | Change design and `docs/architecture.md` |
| What work remains? | The active change's `tasks.md` |
| What did the previous agent establish? | Recent ledger records and linked evidence |

Specifications do not prove runtime behavior. Keep their status and evidence scope explicit.
The initial baseline covers project workflow, replacement planning, and measurement tooling.
Native text transport is a planned capability in `macos-transport-spike`.
OpenSpec status reports completed planning artifacts separately from implementation.
Use `instructions apply --change macos-transport-spike --json` for the remaining implementation task count.
The status field `isComplete` alone does not establish a working native feature.

## Start or resume work

```sh
./scripts/openspec.sh list
./scripts/openspec.sh status --change macos-transport-spike
python3 scripts/ledger.py recent --limit 5
```

In Claude, use `/opsx:apply macos-transport-spike`.
In Codex, use `$openspec-apply-change macos-transport-spike` or select that skill in the interface.
The generated workflows can ask the CLI for current instructions and artifact dependencies.
Translate an `openspec` terminal command from a skill into `./scripts/openspec.sh` to use this project's pinned CLI.

For new behavior, use `/opsx:propose` in Claude or `$openspec-propose` in Codex.
Keep one change for a cohesive user outcome.
Do not create a separate proposal for every helper file or routine documentation correction.
Existing user authorization remains the authority to act within the requested scope.

## Verify and hand off

Run focused tests first. Use `make check` for a local scaffold check.
Use `make bench` when changing the measured planner path, and `make app` to build the shell.
Use `make test-sanitize` for address-safety checks when indexes or buffer bounds change.
Record command results separately from native typing results.

Mark completed tasks only when their completion criteria hold.
Append one ledger record with the outcome, evidence scope, artifact links, and the next action.
Use a new record to correct old evidence rather than rewriting it.

Example handoff content:

```text
Goal: continue macos-transport-spike.
Read AGENTS.md, the active change, and the last five ledger records.
Complete the next unchecked implementation outcome with focused local checks.
Preserve the planner baseline and keep native checks pending unless they run.
Record results and remaining limitations in the ledger.
Stop at the change's completion criteria or a specific external blocker.
```

Archive only after the change's acceptance criteria pass.
An archive, a build, and a merge are separate actions.
Merging or publishing requires Son's authorization.

## Tooling maintenance

The lockfile pins OpenSpec 1.14.1. `make setup` restores the dependency with `npm ci`.
`npm run spec:refresh` recreates the core Claude/Codex integration profile locally.
Generated OpenSpec skill files remain upstream-owned. Put project guidance in `AGENTS.md` and `openspec/config.yaml`.
Do not hand-edit generated skills as a substitute for project rules.

The official integration paths and invocation forms are documented by
[OpenSpec supported tools](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md).

## Build, install, and package

You need Swift 6 or later and a macOS SDK. The checks also need Python 3.9 or later and Node.js 20.19 or later. The app itself has no Node or Python dependency.

| Command | What it does |
| --- | --- |
| `make setup` | Installs the pinned development tools |
| `make check` | Runs the spec checks, the ledger check, the tests, and the fixture replay |
| `make bench` | Measures the replacement planner in a release build |
| `make app` | Builds `.artifacts/GoDau.app` and signs it locally. It does not open or install the app |
| `make install` | Builds the app, replaces `/Applications/GoDau.app`, and opens it |
| `make dist` | Builds a universal app and writes `GoDau.zip`, `GoDau.zip.sha256`, and `install.sh` to `.artifacts/dist`. It uploads nothing |

To publish a build, set `VIETMAC_DIST_URL` to the public HTTPS folder that will hold the three files, run `make dist`, and upload them.

More build details:

- Signing is ad hoc by default. To sign with an identity you chose, set `VIETMAC_SIGNING_IDENTITY`.
- `scripts/swift.sh` uses the installed Command Line Tools when they are available. It does not change global developer settings. To use another toolchain, set `VIETMAC_SWIFT_BIN` to a Swift executable.
- The tests use Swift Testing. The test command disables XCTest. When the Command Line Tools layout requires it, the wrapper loads the bundled test macro.
- For a read-only capability report, run `.artifacts/GoDau.app/Contents/MacOS/VietMac --diagnostics`. This command creates no event tap.
- To record a session, open the app with `open .artifacts/GoDau.app --args --evidence-dir <absolute path>`. The app writes its capabilities, context counters, and callback timings there. Send `SIGUSR1` to write them again. The record holds no typed text.

The app was named VietMac until 2026-11-16. The Swift modules, the scripts, and the executable keep that name. The GitHub repository was renamed from `vietmac` to `godau` on 2026-11-17.
The bundle ID changed from `local.sonquach.vietmac` to `io.github.sonqh.godau` on 2026-11-17, before the first public release. The app copies its old preferences once. macOS permissions do not move, so grant them again after that update.

## Project layout

```text
Apps/VietMac/             Menu bar app and bundle metadata
Sources/VietMacCore/      Telex composer and replacement planner. No macOS frameworks
Sources/VietMacPlatform/  Event tap, field inspection, and event transport
Sources/VietMacShell/     Menu, Setup, Settings, and Help as data, plus the strings
Sources/VietMacReplay/    Fixture replay
Sources/VietMacBench/     Release benchmark
Tests/                    Model tests
Fixtures/                 Expected results for the replay
openspec/                 Requirements and planned changes
ledger/                   Append-only development evidence
scripts/                  Build, install, spec, and ledger commands
docs/                     Architecture, UX, workflow, and verification records
```

## Where the detail is

- [Project status](project-status.md): what is delivered, what is pending, and the active changes.
- [Architecture](architecture.md), [development workflow](development.md), and [performance policy](performance.md).
- [Manual test guide](verification/ux-shell-manual-test.md).
- [Provenance](provenance.md): where the requirements and the research come from.
- `AGENTS.md` holds the instructions for the Codex and Claude assistants that work in this repository.
