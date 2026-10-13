import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
import uuid

spec = importlib.util.spec_from_file_location("ledger", Path(__file__).resolve().parents[1] / "ledger.py")
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)


def entry():
    return {
        "schema_version": 1,
        "id": str(uuid.uuid4()),
        "recorded_at": "2026-10-13T10:00:00+07:00",
        "actor": "codex",
        "kind": "verification",
        "scope": "core-model",
        "confidence": "verified",
        "summary": "Synthetic checks passed. Native behavior remains untested.",
        "artifacts": ["docs/verification/bootstrap.md"],
        "evidence": [{"command": "make test", "result": "pass"}],
    }


class LedgerTests(unittest.TestCase):
    def testAppendPreservesExistingBytes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            ledger.append_entry(path, entry())
            before = path.read_bytes()
            ledger.append_entry(path, entry())
            self.assertTrue(path.read_bytes().startswith(before))
            self.assertEqual(len(ledger.decode_entries(path.read_text())), 2)

    def testDuplicateAndIncompleteRecordsCannotOverwriteEvidence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            original = entry()
            ledger.append_entry(path, original)
            before = path.read_bytes()
            with self.assertRaises(ValueError):
                ledger.append_entry(path, original)
            self.assertEqual(path.read_bytes(), before)
            path.write_text('{"incomplete":')
            before = path.read_bytes()
            with self.assertRaises(ValueError):
                ledger.append_entry(path, entry())
            self.assertEqual(path.read_bytes(), before)

    def testVerificationRequiresEvidenceAndSafeReferences(self):
        for field, value in [("evidence", []), ("artifacts", ["../outside.md"]), ("confidence", "complete")]:
            invalid = copy.deepcopy(entry())
            invalid[field] = value
            with self.assertRaises(ValueError):
                ledger.validate_entry(invalid)

    def testDuplicateIDsAreRejectedDuringRead(self):
        import json
        line = json.dumps(entry()) + "\n"
        with self.assertRaises(ValueError):
            ledger.decode_entries(line + line)

    def testConcurrentWritersKeepEveryRecord(self):
        from concurrent.futures import ThreadPoolExecutor
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            records = [entry() for _ in range(8)]
            with ThreadPoolExecutor(max_workers=4) as executor:
                list(executor.map(lambda record: ledger.append_entry(path, record), records))
            self.assertEqual({record["id"] for record in ledger.read_entries(path)}, {record["id"] for record in records})


if __name__ == "__main__":
    unittest.main()
