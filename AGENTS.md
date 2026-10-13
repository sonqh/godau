# SonKey instructions for Codex and Claude

## Working with Son

- Respond in Vietnamese. Write repository artifacts in English unless Son requests another language.
- State the result first. Use short bullets and concrete evidence.
- Distinguish `verified`, `inferred`, and `unknown` when a claim affects a decision.
- Complete authorized, reversible work without repeated confirmation.
- Preserve unrelated changes. Do not merge, publish, send messages, or install apps without authorization.
- Do not accept software licenses, grant system permissions, or change global developer settings on Son's behalf.
- Do not start sub-agents unless Son explicitly requests delegation.

## Read the relevant context

1. Read `README.md` for implemented capabilities and the current next task.
2. Read `docs/architecture.md` when a change affects module boundaries.
3. Run `python3 scripts/ledger.py recent --limit 5` for recent evidence and handoffs.
4. Read the active change's proposal, design, specs, and tasks when you implement that change.
5. Read any local instructions in the target directory before editing it.

If `CLAUDE.local.md` exists, read it for Son's local preferences.
Keep shared instructions here. `CLAUDE.md` directs Claude to this file.

## Architecture constraints

- macOS only. MVP input is Telex with precomposed Unicode and no composition underline.
- Core code must not import AppKit, Core Graphics, ApplicationServices, or development ledger code.
- Keep event normalization, lifecycle, context, and text transport in `SonKeyMac`.
- Keep presentation and bundle metadata in `Apps/SonKey`.
- Keep the input pipeline on one owning run loop. Do not create a Task, actor hop, or process for each key.
- Avoid process-global mutable composition state.
- Track logical characters separately from UTF-16 units and physical keycodes.
- Prepare every generated event before sending deletion. Invalidate uncertain context instead of attempting a blind rollback.
- Keep instance-local buffers bounded. Current tracked-word maximum is 64 logical characters.
- Do not create marked text, modify the clipboard, or insert invisible sentinels as the default transport.
- Preserve literal brackets and leading `w` in the planned MVP.
- Macros and invalid-word restoration are later work.

## OpenSpec workflow

Use the generated OpenSpec workflows. Use `./scripts/openspec.sh` wherever a generated workflow calls the `openspec` CLI.
The wrapper invokes the pinned local version and disables telemetry for that invocation.
Do not install global tooling or change OpenSpec global profiles as a routine project step.

- Keep delivered baseline behavior in `openspec/specs`.
- Keep planned behavior and implementation tasks in `openspec/changes`.
- Update the active change when its scope changes. Avoid a new change for every file.
- Routine documentation corrections and behavior-preserving fixes need no separate proposal unless an existing workflow requires it.
- An existing user instruction authorizes its scope. Do not add an approval step solely because an artifact is a proposal.
- Keep native acceptance tasks pending until native evidence exists.
- Archive a change only after its completion criteria are satisfied.

## Reuse and performance

- Add a component only when its responsibility and dependency direction are clear.
- Prefer one Swift package and a few modules over multiple repositories or independent packages.
- Add extensibility at semantic input and transport boundaries when a concrete feature requires it.
- Avoid plugin registries, generic orchestration, custom OpenSpec schemas, and persistent runtime event logs for the MVP.
- Keep I/O, UI presentation, network calls, ledger writes, and window enumeration out of the key callback.
- Compare release measurements before claiming a performance improvement.
- Read `docs/performance.md` when changing a measured path.
- Report planner, engine, callback, and native latency as separate scopes.

## Verification and handoff

Run focused checks first. `make check` covers specs, ledger, model tests, and synthetic replay.
`make bench` measures only the replacement planner. `make app` builds the shell without launching it.
Run sanitizer checks when indexes, bounds, or buffer ownership change.
Do not call native typing verified because model tests or a build passed.

Update task status and append one useful ledger record at a meaningful milestone or handoff.
Use `scripts/ledger.py` instead of rewriting `ledger/events.jsonl`.
Record the actual command, result, scope, and evidence artifact.
Append corrections to old claims. Do not change historical records to hide a failed check.
Keep typed content, secrets, and user documents out of development evidence.

Finish with the changed behavior, checks, limits, and one concrete next action.
