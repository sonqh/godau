# Development ledger

`events.jsonl` records decisions, checks, and handoffs for Claude, Codex, and Son.
It is an append-only development record. It never runs inside the input app.
The JSON field `confidence` separates verified evidence, inference, and unknown behavior.

Use OpenSpec tasks for implementation progress. Use specifications for behavior and change designs for technical decisions.
The ledger links those artifacts and records what an agent actually checked.
It does not duplicate the task list or store keystrokes, user documents, or secrets.

Read the latest records:

```sh
python3 scripts/ledger.py recent --limit 5
```

Append one useful record at a milestone or handoff:

```sh
python3 scripts/ledger.py append \
  --actor claude --kind verification --scope core-model \
  --confidence verified --summary "Focused model checks passed. Native typing remains untested." \
  --artifact Tests/SonKeyCoreTests/ReplacementPlanTests.swift \
  --command "make test" --result pass
```

Only record commands that actually ran. A native claim needs native evidence with OS, app version, field, and options.
Record `not-run` for an unperformed check and keep the claimed scope narrow.
Append a correction instead of editing a previous record.

The writer uses an advisory file lock, validates previous records, and flushes the new record to disk.
The validator rejects duplicate IDs, malformed records, incomplete final lines, and unsafe artifact references.
It checks syntax and structure. It cannot establish whether a claim is true or detect a coordinated rewrite of the file.
Git history provides the review trail. This is not a cryptographic audit system or a concurrent task scheduler.
References identify artifacts at recording time. Archive moves or later edits do not rewrite older records.
