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
