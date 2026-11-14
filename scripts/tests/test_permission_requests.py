"""FG-3: permission requests run only from a click in the setup or settings window.

The launch path, the status observer, the menu, and the platform must hold no reference to the
request functions or to PermissionRequester (ux-shell task 3.2, guided-setup spec)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
REQUEST_FUNCTIONS = ("CGRequestListenEventAccess", "CGRequestPostEventAccess", "AXIsProcessTrustedWithOptions")
REQUESTER_FILE = "Apps/VietMac/PermissionRequester.swift"
# Windows whose button actions may call the requester.
ALLOWED_CALLERS = {"Apps/VietMac/SetupWindowController.swift", "Apps/VietMac/SettingsWindowController.swift"}


def swift_files():
    for folder in ("Apps/VietMac", "Sources"):
        for path in sorted((ROOT / folder).rglob("*.swift")):
            yield path.relative_to(ROOT).as_posix(), path.read_text(encoding="utf-8")


def code_only(text):
    """Drops line comments so documentation may name the functions."""
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


class PermissionRequestTests(unittest.TestCase):
    def test_request_functions_live_only_in_the_requester(self):
        for name, text in swift_files():
            if name == REQUESTER_FILE:
                continue
            for function in REQUEST_FUNCTIONS:
                self.assertNotIn(function, code_only(text), f"{name} calls {function}")

    def test_requester_is_used_only_by_window_buttons(self):
        callers = {name for name, text in swift_files()
                   if name != REQUESTER_FILE and re.search(r"\bPermissionRequester\.", code_only(text))}
        self.assertTrue(callers, "no window calls the requester")
        self.assertLessEqual(callers, ALLOWED_CALLERS)

    def test_setup_window_calls_requester_from_a_command_only(self):
        text = code_only((ROOT / "Apps/VietMac/SetupWindowController.swift").read_text(encoding="utf-8"))
        calls = [line.strip() for line in text.splitlines() if "PermissionRequester." in line]
        self.assertEqual(calls, ["PermissionRequester.request(grant)"])
        # The single call sits under the requestPermission command, which only a button sends.
        index = text.index("PermissionRequester.request(grant)")
        self.assertIn("case .requestPermission(let grant):", text[max(0, index - 120):index])


if __name__ == "__main__":
    unittest.main()
