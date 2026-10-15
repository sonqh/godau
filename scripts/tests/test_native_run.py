import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("native_run", Path(__file__).resolve().parents[1] / "native_run.py")
native_run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native_run)


class PreservationTests(unittest.TestCase):
    def test_clean_precomposed_text_passes(self):
        self.assertEqual(native_run.preservation_failures({"area": "LEFT  RIGHT á â Á"}), [])

    def test_emoji_joiner_is_allowed(self):
        self.assertEqual(native_run.preservation_failures({"rich": "RIGHT \U0001F469\U0001F3FD\u200d\U0001F4BB"}), [])

    def test_invisible_sentinel_fails(self):
        failures = native_run.preservation_failures({"area": "a á"})
        self.assertEqual(failures, ["area: invisible U+202F"])

    def test_decomposed_mark_fails(self):
        failures = native_run.preservation_failures({"area": "á"})
        self.assertEqual(failures, ["area: not NFC U+0301"])

    def test_composition_marked_text_and_clipboard_fail(self):
        log = ["1.0 area compositionstart inputType=- data=- composing=true"]
        driver = {"clipboardChangeCountBefore": 5, "clipboardChangeCountAfter": 6}
        failures = native_run.preservation_failures({}, log, driver, marked_ranges=[[2, 3]])
        self.assertEqual(failures, ["page: composition (marked text) events", "field: marked text range [2, 3]",
                                    "clipboard changed during the run"])

    def test_catalog_is_valid(self):
        self.assertEqual(native_run.CATALOG_PROBLEMS, [])
        self.assertIn("timing-workload", native_run.SCENARIOS)

    def test_invalid_scenario_is_reported(self):
        problems = native_run.validate_scenario({"id": "x", "version": 1, "rules": "vni", "apps": ["teams"],
                                                 "keys": "a", "script": {}, "field": "area"})
        self.assertIn("unknown rules 'vni'", problems)
        self.assertIn("unknown apps ['teams']", problems)
        self.assertIn("exactly one of keys or script", problems)
        self.assertIn("missing replacements", problems)


if __name__ == "__main__":
    unittest.main()
