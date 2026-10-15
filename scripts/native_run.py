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
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / ".artifacts/VietMac.app"
DRIVER = ROOT / ".artifacts/VietMacDriver.app"
PORT = 8765

BROWSERS = {
    "chrome": ("Google Chrome", "com.google.Chrome"),
}

# M0 rule for expected text: a word that starts with `as` or `aa` gets `á` or `â`; other words stay.
def m0(text):
    return " ".join("á" + w[2:] if w.startswith("as") else "â" + w[2:] if w.startswith("aa") else w
                    for w in text.split(" "))


WORKLOAD_WORDS = "as aa ok the quick brown fox jumps over the lazy dog asking aaron has a sad".split()
WORKLOAD = " " + " ".join(WORKLOAD_WORDS * 9)  # 684 characters, 1,368 driver key events.

# keys: driver input (`|` pauses). event: page context change after the nth key input.
# expect: final field values. replacements: exact VietMac replacements and page Backspaces.
# minimum: lower bounds for VietMac counter deltas. Fields start from the fixture defaults;
# automation focuses the field with the caret at the end, and the leading space ends the
# first-word-after-focus literal hold.
SCENARIOS = {
    "spike-area-as": {
        "field": "area", "keys": " as", "interval": 120, "hold": 60,
        "expect": {"area": "LEFT  RIGHT á"}, "replacements": 1,
    },
    "spike-area-rollover": {
        "field": "area", "keys": " as as as as as", "interval": 70, "hold": 110,
        "expect": {"area": "LEFT  RIGHT á á á á á"}, "replacements": 5,
    },
    "ctx-external-edit": {
        "field": "ordinary", "keys": " a|s", "interval": 120, "hold": 60, "pause": 1200,
        "event": "external", "after": 2,
        "expect": {"ordinary": "EXTERNAL CONTsENT"}, "replacements": 0,
        "minimum": {"unexplainedFieldChanges": 1},
    },
    "ctx-focus-switch": {
        "field": "ordinary", "keys": " a|s", "interval": 120, "hold": 60, "pause": 1200,
        "event": "focus", "after": 2,
        "expect": {"ordinary": "LEFT  RIGHT a", "other": "OTHER s END"}, "replacements": 0,
        "minimum": {"focusChanges": 1},
    },
    "ctx-selection": {
        "field": "ordinary", "keys": " a|s", "interval": 120, "hold": 60, "pause": 1200,
        "event": "selection", "after": 2,
        "expect": {"ordinary": "LEFT  RIGHT as"}, "replacements": 0,
        "minimum": {"selectionsObserved": 1},
    },
    "ctx-fast-typing": {
        "field": "area", "keys": " as" * 10, "interval": 70, "hold": 110,
        "expect": {"area": "LEFT  RIGHT" + " á" * 10}, "replacements": 10,
    },
    "timing-workload": {
        "field": "area", "keys": WORKLOAD, "interval": 45, "hold": 30, "timing": True,
        "expect": {"area": "LEFT  RIGHT" + m0(WORKLOAD)},
        "replacements": sum(w.startswith(("as", "aa")) for w in WORKLOAD.split()),
    },
}

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


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenario", choices=sorted(SCENARIOS))
    parser.add_argument("--browser", choices=sorted(BROWSERS), default="chrome")
    args = parser.parse_args()
    scenario = SCENARIOS[args.scenario]
    app_name, bundle_id = BROWSERS[args.browser]
    for bundle in (APP, DRIVER):
        if not bundle.exists():
            raise SystemExit(f"missing {bundle}; run make app and make driver")

    run_id = f"{args.scenario}-{time.strftime('%Y%m%d-%H%M%S')}"
    out_dir = ROOT / ".artifacts/native/auto" / run_id
    evidence = out_dir / "vietmac"
    evidence.mkdir(parents=True)

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
        subprocess.run(["open", "-g", "-W", "-n", str(DRIVER), "--args", "--keys", scenario["keys"],
                        "--interval-ms", str(scenario["interval"]), "--hold-ms", str(scenario["hold"]),
                        "--pause-ms", str(scenario.get("pause", 1000)),
                        "--expect-bundle", bundle_id, "--out", str(driver_out), "--select-abc"], check=True)
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
    checks = {
        "driver": driver["status"] == "pass",
        "values": not mismatched,
        "replacementsPosted": deltas.get("replacementsPosted", 0) == scenario["replacements"],
        "backspaces": backspaces == scenario["replacements"],
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
        "pageBackspaces": backspaces, "counterDeltas": deltas, "driver": driver,
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
