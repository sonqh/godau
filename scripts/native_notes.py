#!/usr/bin/env python3
"""Run Telex native automation in Apple Notes (body and title) against one test note.

Son allowed this on 2026-11-14: the script creates one note named "VietMac test" in the default
Notes account, types into it with the test-only VietMacDriver, reads back only that note's plain
text, and deletes the note (Notes keeps it in Recently Deleted). It reads no other note.

Do not use the Mac while it runs: the driver types into the frontmost window.
"""

import json
import subprocess
import sys
import time
import unicodedata

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
import native_run as nr  # noqa: E402

NOTES = "com.apple.Notes"
NOTE_NAME = "VietMac test"
CASES = [
    # name, cursor keys before typing, keys typed, text expected in the note's plain text
    ("notes-body", [{"key": "down", "modifiers": ["command"]}],
     # Notes capitalizes the first word of a new line, so the expected text starts with `Tiếng`.
     " tieengs Vieetj laf ngoon nguwx cuar nguowif Vieetj", "\n Tiếng Việt là ngôn ngữ của người Việt"),
    ("notes-title", [{"key": "up", "modifiers": ["command"]}, {"key": "right", "modifiers": ["command"]}],
     " Tieengs Vieetj", "VietMac test Tiếng Việt\n"),
]


def osascript(script):
    out = subprocess.run(["osascript", "-e", "with timeout of 60 seconds", "-e", script, "-e", "end timeout"],
                         capture_output=True, text=True, timeout=90)
    if out.returncode != 0:
        raise SystemExit(f"osascript failed: {out.stderr.strip()}")
    return out.stdout.strip()


def create_note(body):
    escaped = body.replace('"', '\\"')
    return osascript(f'tell application "Notes" to set n to make new note with properties '
                     f'{{name:"{NOTE_NAME}", body:"{escaped}"}}\n'
                     f'tell application "Notes" to return id of n')


def show_note(note_id):
    osascript(f'tell application "Notes"\nactivate\nshow note id "{note_id}" separately true\nend tell')


def note_text(note_id):
    return osascript(f'tell application "Notes" to return plaintext of note id "{note_id}"')


def delete_note(note_id):
    try:
        osascript(f'tell application "Notes" to delete note id "{note_id}"')
    except SystemExit as error:
        print(f"warning: {error}", file=sys.stderr)


def run_case(name, cursor, keys, expected, run_dir):
    evidence = run_dir / name / "vietmac"
    evidence.mkdir(parents=True)
    note_id = create_note("<div>LEFT</div>")
    try:
        pid = nr.launch_vietmac(evidence)
        show_note(note_id)
        time.sleep(1.5)
        before = nr.snapshot(pid, evidence)
        script = {"steps": [*cursor, {"pause": 400}, {"text": keys, "interval": 110, "hold": 50}]}
        driver = nr.run_driver(run_dir / name, "driver", script, NOTES,
                               extra=["--target-role", "AXTextArea", "--require-target"])
        time.sleep(1.0)
        after = nr.snapshot(pid, evidence)
        text = note_text(note_id)
    finally:
        nr.stop_vietmac()
        delete_note(note_id)
    deltas = {k: after["contextCounters"][k] - before["contextCounters"][k] for k in before["contextCounters"]
              if after["contextCounters"][k] != before["contextCounters"][k]}
    checks = {
        "driver": driver.get("status") == "pass",
        "text": expected in text,
        "nfc": unicodedata.is_normalized("NFC", text),
        "replacementsUnconfirmed": deltas.get("replacementsUnconfirmed", 0) == 0,
        "noDeliveryPause": "Replacement delivery became uncertain" not in after["state"],
        "preservation": not nr.preservation_failures({"note": text}, driver=driver),
    }
    return {"case": name, "pass": all(checks.values()), "checks": checks, "text": text, "expected": expected,
            "counterDeltas": deltas, "vietmacState": after["state"], "driverStatus": driver.get("status"),
            "evidence": "synthetic HID-level key events (native automation), not physical typing"}


def main():
    for bundle in (nr.APP, nr.DRIVER):
        if not bundle.exists():
            raise SystemExit(f"missing {bundle}; run make app and make driver")
    run_dir = nr.ROOT / ".artifacts/native/auto" / f"notes-{time.strftime('%Y%m%d-%H%M%S')}"
    run_dir.mkdir(parents=True)
    results = [run_case(*case, run_dir) for case in CASES]
    (run_dir / "summary.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0 if all(r["pass"] for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
