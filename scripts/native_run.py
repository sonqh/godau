#!/usr/bin/env python3
"""Run one native automation scenario against VietMac in a real browser.

The runner serves Fixtures/ on 127.0.0.1, relaunches VietMac with the prototype enabled
and an evidence directory, opens the fixture in automation mode, types with the test-only
VietMacDriver app (HID-level key events), then compares the field and VietMac counters.
It quits VietMac at the end so the prototype is not left enabled.

Do not use the Mac while a scenario runs: the driver types into the frontmost window and
aborts if that window or the input source changes.
"""

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
import unicodedata
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / ".artifacts/GoDau.app"
DRIVER = ROOT / ".artifacts/VietMacDriver.app"
PORT = 8765

# Accessibility designation of each browser's address/search field (no field text involved).
ADDRESS_FIELDS = {
    "chrome": ["--target-role", "AXTextField", "--target-description", "Address and search bar"],
    "dia": ["--target-role", "AXTextArea", "--target-identifier", "commandBarTextField"],
    "safari": ["--target-role", "AXTextField", "--target-identifier", "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"],
}

BROWSERS = {
    "chrome": ("Google Chrome", "com.google.Chrome", False),
    # Dia keeps OS focus on its web area or tab strip after page focus(); click the field.
    "dia": ("Dia", "company.thebrowser.dia", True),
    "safari": ("Safari", "com.apple.Safari", True),
}

CATALOG = ROOT / "Fixtures/native-scenarios"
RULE_SETS = {"m0", "telex-mvp"}
APPS = {"chrome", "dia", "safari", "vscode", "notes"}


def validate_scenario(scenario):
    """Returns problems with one catalog scenario; an empty list means valid."""
    problems = []
    for key in ("id", "version", "rules", "apps"):
        if key not in scenario:
            problems.append(f"missing {key}")
    if scenario.get("rules") not in RULE_SETS:
        problems.append(f"unknown rules {scenario.get('rules')!r}")
    if not set(scenario.get("apps", [])) <= APPS:
        problems.append(f"unknown apps {sorted(set(scenario.get('apps', [])) - APPS)}")
    if ("keys" in scenario) == ("script" in scenario):
        problems.append("exactly one of keys or script")
    if scenario.get("surface") == "address":
        if "checkpoints" not in scenario or "seed" not in scenario:
            problems.append("address scenarios need seed and checkpoints")
    elif "field" not in scenario or "expect" not in scenario:
        problems.append("page scenarios need field and expect")
    if "replacements" not in scenario:
        problems.append("missing replacements")
    return problems


def load_catalog(directory=CATALOG):
    """Loads every family file; scenario IDs must be unique and valid."""
    scenarios, problems = {}, []
    for path in sorted(directory.glob("*.json")):
        document = json.loads(path.read_text())
        if document.get("schemaVersion") != 1:
            problems.append(f"{path.name}: unsupported schemaVersion")
        for scenario in document.get("scenarios", []):
            scenario = dict(scenario, family=document.get("family", path.stem))
            for problem in validate_scenario(scenario):
                problems.append(f"{path.name}:{scenario.get('id')}: {problem}")
            if scenario.get("id") in scenarios:
                problems.append(f"{path.name}: duplicate id {scenario['id']}")
            scenarios[scenario.get("id")] = scenario
    return scenarios, problems


SCENARIOS, CATALOG_PROBLEMS = load_catalog()

REPORTS = {}
REPORT_EVENT = threading.Condition()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / "Fixtures"), **kwargs)

    def do_POST(self):
        match = re.fullmatch(r"/report\?run=([A-Za-z0-9_-]{1,64})", self.path)
        length = int(self.headers.get("Content-Length", "0"))
        if not match or length > 1_000_000:
            self.send_error(400)
            return
        body = json.loads(self.rfile.read(length))
        with REPORT_EVENT:
            REPORTS.setdefault(match.group(1), []).append(body)
            REPORT_EVENT.notify_all()
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


def wait_for(predicate, timeout, message):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.05)
    raise SystemExit(f"timeout: {message}")


def vietmac_pids():
    out = subprocess.run(["pgrep", "-f", str(APP / "Contents/MacOS/VietMac")], capture_output=True, text=True)
    return [int(pid) for pid in out.stdout.split()]


def snapshot(pid, evidence):
    path = evidence / "session-diagnostics.json"
    before = path.stat().st_mtime_ns if path.exists() else 0
    os.kill(pid, signal.SIGUSR1)
    wait_for(lambda: path.exists() and path.stat().st_mtime_ns != before, 5, "VietMac snapshot")
    time.sleep(0.05)
    return json.loads(path.read_text())


def run_driver(out_dir, name, script, bundle_id, extra=(), timeout=180):
    """Runs one driver script; returns its result. Scripts are passed inline (no ~/Documents read)."""
    out = out_dir / f"{name}.json"
    (out_dir / f"{name}-script.json").write_text(json.dumps(script, indent=2))
    subprocess.run(["open", "-g", "-W", "-n", str(DRIVER), "--args", "--script-json", json.dumps(script),
                    "--expect-bundle", bundle_id, "--out", str(out), "--select-abc", *extra],
                   check=True, timeout=timeout)
    return json.loads(out.read_text())


# Invisible format characters a transport must never leave behind (OpenKey uses U+202F/U+200C).
INVISIBLE = {0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202F, 0xFEFF}


def preservation_failures(texts, page_log=(), driver=None, marked_ranges=()):
    """Returns failures for invisible characters, non-NFC text, composition, or clipboard changes."""
    failures = []
    for name, text in texts.items():
        if text is None:
            continue
        def emoji(c):
            return ord(c) >= 0x1F000 or 0x2600 <= ord(c) <= 0x27BF
        # U+200D between emoji is a legitimate joiner (for example the fixture's 👩🏽‍💻).
        hidden = sorted({f"U+{ord(c):04X}" for i, c in enumerate(text) if ord(c) in INVISIBLE and not (
            ord(c) == 0x200D and 0 < i < len(text) - 1 and emoji(text[i - 1]) and emoji(text[i + 1]))})
        if hidden:
            failures.append(f"{name}: invisible {' '.join(hidden)}")
        if not unicodedata.is_normalized("NFC", text):
            decomposed = sorted({f"U+{ord(c):04X}" for c in text if unicodedata.combining(c)})
            failures.append(f"{name}: not NFC {' '.join(decomposed)}")
    if any(" compositionstart " in line or "composing=true" in line for line in page_log):
        failures.append("page: composition (marked text) events")
    for marked in marked_ranges:
        if marked and marked[1] > marked[0]:
            failures.append(f"field: marked text range {marked}")
    if driver and driver.get("clipboardChangeCountBefore") != driver.get("clipboardChangeCountAfter"):
        failures.append("clipboard changed during the run")
    return failures


SETTINGS_FILE = ROOT / ".artifacts/native/browser-settings.json"


def declared_settings(browser):
    """Autocomplete/search-suggestion settings Son declares; browser profile data is protected and not read."""
    try:
        return json.loads(SETTINGS_FILE.read_text()).get(browser, "undeclared")
    except (OSError, ValueError):
        return f"undeclared (add {SETTINGS_FILE.relative_to(ROOT)})"


def stop_vietmac():
    for pid in vietmac_pids():
        os.kill(pid, signal.SIGTERM)
    wait_for(lambda: not vietmac_pids(), 5, "previous VietMac exit")


def launch_vietmac(evidence):
    stop_vietmac()
    subprocess.run(["open", "-g", "-n", str(APP), "--args", "--evidence-dir", str(evidence), "--enable-prototype"], check=True)
    pid = wait_for(lambda: (vietmac_pids() or [None])[0], 10, "VietMac launch")
    launch = json.loads(wait_for(lambda: (evidence / "session-diagnostics.json").exists() and
                                 (evidence / "session-diagnostics.json").read_text(), 10, "VietMac evidence"))
    missing = [k for k in ("accessibility", "eventListening", "eventPosting", "prototypeEnabled") if not launch.get(k)]
    if missing:
        raise SystemExit(f"VietMac not ready: {missing} false")
    return pid


def run_address(args, scenario, run_id, out_dir, evidence):
    """Address/search bar scenario: history seeding with VietMac off, then AX checkpoints."""
    app_name, bundle_id, _ = BROWSERS[args.browser]
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        stop_vietmac()
        subprocess.run(["open", "-a", app_name, f"http://127.0.0.1:{PORT}/native-fields.html"], check=True)
        time.sleep(2.0)
        seed_steps = []
        for url in scenario["seed"] * 2:  # Typed visits make the URL an inline-completion candidate.
            seed_steps += [{"key": "l", "modifiers": ["command"]}, {"pause": 300},
                           {"text": url, "interval": 30, "hold": 20}, {"pause": 200},
                           {"key": "return"}, {"pause": 1500}]
        seeding = run_driver(out_dir, "seed", {"steps": seed_steps}, bundle_id)
        if seeding["status"] != "pass":
            raise SystemExit(f"history seeding aborted: {seeding.get('reason')}")
        pid = launch_vietmac(evidence)
        time.sleep(0.8)
        before = snapshot(pid, evidence)
        driver = run_driver(out_dir, "driver", scenario["script"], bundle_id, ADDRESS_FIELDS[args.browser])
        time.sleep(0.5)
        after = snapshot(pid, evidence)
    finally:
        stop_vietmac()
        server.shutdown()
    deltas = {k: after["contextCounters"][k] - before["contextCounters"][k] for k in before["contextCounters"]
              if after["contextCounters"][k] != before["contextCounters"][k]}
    readings = {c["name"]: c for c in driver.get("checkpoints", [])}
    completion = (readings.get("completion") or {}).get("field") or {}
    selection = completion.get("selection") or [0, 0]
    inline_completion = completion.get("value", "") != "" and selection[1] > selection[0]
    expected_checkpoints, expected_replacements = scenario["checkpoints"], scenario["replacements"]
    minimum = scenario.get("minimum", {})
    if not inline_completion and "withoutInlineCompletion" in scenario:
        fallback = scenario["withoutInlineCompletion"]
        expected_checkpoints, expected_replacements, minimum = fallback, fallback["replacements"], {}
        expected_checkpoints = {k: v for k, v in fallback.items() if k != "replacements"}
    checkpoint_results = {}
    for name, expected in expected_checkpoints.items():
        field = (readings.get(name) or {}).get("field") or {}
        value, selection = field.get("value"), field.get("selection")
        ok = value is not None
        if "value" in expected:
            ok = ok and value == expected["value"]
        if "prefix" in expected:
            ok = ok and (value or "").startswith(expected["prefix"])
        if expected.get("selected"):
            ok = ok and bool(selection) and selection[1] > selection[0]
        checkpoint_results[name] = {"pass": ok, "value": value, "selection": selection,
                                    "reason": (readings.get(name) or {}).get("reason")}
    preservation = preservation_failures(
        {name: c["value"] for name, c in checkpoint_results.items()}, driver=driver,
        marked_ranges=[((readings.get(n) or {}).get("field") or {}).get("markedRange") for n in readings])
    checks = {
        "driver": driver["status"] == "pass",
        "preservation": not preservation,
        "checkpoints": all(c["pass"] for c in checkpoint_results.values()),
        "replacementsPosted": deltas.get("replacementsPosted", 0) == expected_replacements,
        "replacementsUnconfirmed": deltas.get("replacementsUnconfirmed", 0) == 0,
        "minimumCounters": all(deltas.get(k, 0) >= v for k, v in minimum.items()),
        "noDeliveryPause": "Replacement delivery became uncertain" not in after["state"],
    }
    summary = {
        "run": run_id, "scenario": args.scenario, "browser": bundle_id, "pass": all(checks.values()),
        "inlineCompletion": inline_completion, "browserSettings": declared_settings(args.browser),
        "preservationFailures": preservation,
        "checks": checks, "checkpoints": checkpoint_results, "counterDeltas": deltas, "driver": driver,
        "seeding": {"status": seeding["status"], "urls": scenario["seed"]},
        "vietmacState": after["state"],
        "evidence": "synthetic HID-level key events (native automation), not physical typing",
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary["pass"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenario", choices=sorted(SCENARIOS))
    parser.add_argument("--browser", choices=sorted(BROWSERS), default="chrome")
    args = parser.parse_args()
    if CATALOG_PROBLEMS:
        raise SystemExit("invalid scenario catalog:\n" + "\n".join(CATALOG_PROBLEMS))
    scenario = SCENARIOS[args.scenario]
    app_name, bundle_id, needs_click = BROWSERS[args.browser]
    for bundle in (APP, DRIVER):
        if not bundle.exists():
            raise SystemExit(f"missing {bundle}; run make app and make driver")

    run_id = f"{args.scenario}-{time.strftime('%Y%m%d-%H%M%S')}"
    out_dir = ROOT / ".artifacts/native/auto" / run_id
    evidence = out_dir / "vietmac"
    evidence.mkdir(parents=True)
    if scenario.get("surface") == "address":
        return run_address(args, scenario, run_id, out_dir, evidence)

    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    for pid in vietmac_pids():
        os.kill(pid, signal.SIGTERM)
    wait_for(lambda: not vietmac_pids(), 5, "previous VietMac exit")
    subprocess.run(["open", "-g", "-n", str(APP), "--args", "--evidence-dir", str(evidence), "--enable-prototype"], check=True)
    pid = wait_for(lambda: (vietmac_pids() or [None])[0], 10, "VietMac launch")
    try:
        launch = json.loads(wait_for(lambda: (evidence / "session-diagnostics.json").exists() and
                                     (evidence / "session-diagnostics.json").read_text(), 10, "VietMac evidence"))
        missing = [k for k in ("accessibility", "eventListening", "eventPosting", "prototypeEnabled") if not launch.get(k)]
        if missing:
            raise SystemExit(f"VietMac not ready: {missing} false")

        url = f"http://127.0.0.1:{PORT}/native-fields.html?auto={scenario['field']}&run={run_id}"
        if scenario.get("event"):
            url += f"&event={scenario['event']}&after={scenario['after']}&delay=300"
        subprocess.run(["open", "-a", app_name, url], check=True)
        with REPORT_EVENT:
            REPORT_EVENT.wait_for(lambda: REPORTS.get(run_id), timeout=15)
        if not REPORTS.get(run_id):
            raise SystemExit("timeout: fixture ready report")
        time.sleep(0.8)  # Let VietMac observe the focused field before the first key.

        before = snapshot(pid, evidence)
        driver_out = out_dir / "driver.json"
        if "script" in scenario:
            # {"click": "field"} clicks the field's reported screen point.
            point = REPORTS[run_id][0]["clickPoint"]
            script = json.loads(json.dumps(scenario["script"]))
            for step in script.get("steps", []):
                if step.get("click") == "field":
                    step["click"] = point
            # Inline: the driver would need Files & Folders consent to read a file under ~/Documents.
            (out_dir / "script.json").write_text(json.dumps(script, indent=2))
            driver_input = ["--script-json", json.dumps(script)]
        else:
            driver_input = ["--keys", scenario["keys"]]
        subprocess.run(["open", "-g", "-W", "-n", str(DRIVER), "--args", *driver_input,
                        "--interval-ms", str(scenario.get("interval", 80)), "--hold-ms", str(scenario.get("hold", 50)),
                        "--pause-ms", str(scenario.get("pause", 1000)),
                        *(["--click", ",".join(map(str, REPORTS[run_id][0]["clickPoint"]))] if needs_click else []),
                        "--expect-bundle", bundle_id, "--out", str(driver_out), "--select-abc"], check=True,
                       timeout=180)  # A consent dialog or hang must fail the run, not block it.
        driver = json.loads(driver_out.read_text())
        time.sleep(1.0)  # Quiet period: VietMac settles or pauses; the page reports its last input.
        after = snapshot(pid, evidence)
        timings = json.loads((evidence / "callback-timings.json").read_text())
    finally:
        for running in vietmac_pids():
            os.kill(running, signal.SIGTERM)
        server.shutdown()

    report = REPORTS[run_id][-1]
    values = dict(report["values"], rich=report["rich"])
    mismatched = {k: {"expected": v, "actual": values.get(k)} for k, v in scenario["expect"].items() if values.get(k) != v}
    deltas = {k: after["contextCounters"][k] - before["contextCounters"][k] for k in before["contextCounters"]
              if after["contextCounters"][k] != before["contextCounters"][k]}
    backspaces = sum('keydown key="Backspace"' in line for line in report["log"])
    checked = {k: values.get(k) for k in {*scenario["expect"], scenario["field"]}}
    preservation = preservation_failures(checked, report["log"], driver)
    if scenario.get("expectDriverAbort"):
        # Safety probe: only the driver's own stop reason and cleanup matter.
        checks = {"driverAbort": driver.get("reason") == scenario["expectDriverAbort"],
                  "keysReleased": driver.get("heldFlagsAfter") == 0, "preservation": not preservation}
        summary = {"run": run_id, "scenario": args.scenario, "browser": bundle_id, "pass": all(checks.values()),
                   "checks": checks, "driver": driver, "preservationFailures": preservation}
        (out_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0 if summary["pass"] else 1
    checks = {
        "driver": driver["status"] == "pass",
        "preservation": not preservation,
        "values": not mismatched,
        "replacementsPosted": deltas.get("replacementsPosted", 0) == scenario["replacements"],
        # One Backspace per replacement under M0; Telex replacements may delete several letters.
        "backspaces": backspaces == scenario.get("backspaces", scenario["replacements"]),
        "replacementsUnconfirmed": deltas.get("replacementsUnconfirmed", 0) == 0,
        "minimumCounters": all(deltas.get(k, 0) >= v for k, v in scenario.get("minimum", {}).items()),
        # The driver restores the user's input source before this snapshot, which can pause
        # VietMac for the source; only a delivery pause is a failure here.
        "noDeliveryPause": "Replacement delivery became uncertain" not in after["state"],
    }
    summary = {
        "run": run_id, "scenario": args.scenario, "browser": bundle_id, "pass": all(checks.values()),
        "checks": checks, "mismatched": mismatched,
        "values": {k: values.get(k) for k in scenario["expect"]}, "caret": report.get("caret"),
        "activeElement": report.get("activeElement"),
        "pageBackspaces": backspaces, "preservationFailures": preservation, "counterDeltas": deltas, "driver": driver,
        "vietmacState": after["state"], "inputSource": after.get("inputSource"),
        "callbackTimings": timings if scenario.get("timing") else None,
        "evidence": "synthetic HID-level key events (native automation), not physical typing",
    }
    (out_dir / "page-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
    (out_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
