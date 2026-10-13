#!/usr/bin/env python3
"""Append development evidence. This tool is never part of the input runtime."""
import argparse
from datetime import datetime, timezone
import fcntl
import json
from pathlib import Path, PurePosixPath
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
FIELDS = {"schema_version", "id", "recorded_at", "actor", "kind", "scope", "confidence", "summary", "artifacts", "evidence"}


def validate_entry(entry):
    if not isinstance(entry, dict) or set(entry) != FIELDS:
        raise ValueError("Ledger entry fields do not match schema version 1")
    if type(entry["schema_version"]) is not int or entry["schema_version"] != 1:
        raise ValueError("Unsupported ledger schema version")
    if not isinstance(entry["id"], str) or not isinstance(entry["recorded_at"], str):
        raise ValueError("Record ID and timestamp must be strings")
    uuid.UUID(entry["id"])
    timestamp = datetime.fromisoformat(entry["recorded_at"])
    if timestamp.tzinfo is None:
        raise ValueError("recorded_at must include a timezone")
    if entry["actor"] not in ("codex", "claude", "human"):
        raise ValueError("Unsupported actor")
    if entry["kind"] not in ("decision", "verification", "handoff"):
        raise ValueError("Unsupported entry kind")
    if entry["confidence"] not in ("verified", "inferred", "unknown"):
        raise ValueError("Unsupported evidence confidence")
    for field in ("scope", "summary"):
        if not isinstance(entry[field], str) or not entry[field].strip():
            raise ValueError(f"{field} must be a nonempty string")
    if not isinstance(entry["artifacts"], list):
        raise ValueError("artifacts must be an array")
    for artifact in entry["artifacts"]:
        if not isinstance(artifact, str) or not artifact:
            raise ValueError("Artifact paths must be nonempty strings")
        path = PurePosixPath(artifact)
        if path.is_absolute() or ".." in path.parts or "\\" in artifact:
            raise ValueError("Artifact paths must stay relative to the project")
    if not isinstance(entry["evidence"], list):
        raise ValueError("evidence must be an array")
    for evidence in entry["evidence"]:
        if not isinstance(evidence, dict) or set(evidence) != {"command", "result"}:
            raise ValueError("Evidence requires command and result")
        if not isinstance(evidence["command"], str) or not evidence["command"].strip():
            raise ValueError("Evidence command must be nonempty")
        if evidence["result"] not in ("pass", "fail", "not-run"):
            raise ValueError("Evidence result must be pass, fail, or not-run")
    if entry["kind"] == "verification" and not entry["evidence"]:
        raise ValueError("Verification entries require evidence")


def decode_entries(content):
    if content and not content.endswith("\n"):
        raise ValueError("Ledger has an incomplete final record")
    entries, identifiers = [], set()
    for line in content.splitlines():
        entry = json.loads(line)
        validate_entry(entry)
        if entry["id"] in identifiers:
            raise ValueError("Duplicate ledger entry ID")
        identifiers.add(entry["id"])
        entries.append(entry)
    return entries


def append_entry(path, entry):
    validate_entry(entry)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        handle.seek(0)
        entries = decode_entries(handle.read())
        if any(previous["id"] == entry["id"] for previous in entries):
            raise ValueError("Duplicate ledger entry ID")
        handle.seek(0, 2)
        handle.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")
        handle.flush()
        # Persist this development record. Never call this from a key callback.
        import os
        os.fsync(handle.fileno())


def read_entries(path):
    with path.open("r", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_SH)
        return decode_entries(handle.read())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("validate")
    recent = sub.add_parser("recent")
    recent.add_argument("--limit", type=int, default=5)
    append = sub.add_parser("append")
    append.add_argument("--actor", choices=["codex", "claude", "human"], required=True)
    append.add_argument("--kind", choices=["decision", "verification", "handoff"], required=True)
    append.add_argument("--scope", required=True)
    append.add_argument("--confidence", choices=["verified", "inferred", "unknown"], required=True)
    append.add_argument("--summary", required=True)
    append.add_argument("--artifact", action="append", default=[])
    append.add_argument("--command")
    append.add_argument("--result", choices=["pass", "fail", "not-run"])
    args = parser.parse_args()
    path = ROOT / "ledger/events.jsonl"
    try:
        if args.action == "append":
            if bool(args.command) != bool(args.result):
                parser.error("Provide --command and --result together")
            entry = {
                "schema_version": 1,
                "id": str(uuid.uuid4()),
                "recorded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "actor": args.actor,
                "kind": args.kind,
                "scope": args.scope,
                "confidence": args.confidence,
                "summary": args.summary,
                "artifacts": args.artifact,
                "evidence": [{"command": args.command, "result": args.result}] if args.command else [],
            }
            append_entry(path, entry)
            print(entry["id"])
        else:
            entries = read_entries(path)
            if args.action == "validate":
                print(f"PASS ledger: {len(entries)} valid records")
            else:
                if args.limit < 1:
                    parser.error("--limit must be positive")
                for entry in entries[-args.limit:]:
                    print(json.dumps(entry, ensure_ascii=False))
    except (ValueError, TypeError, KeyError, OSError) as error:
        print(f"Ledger error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
