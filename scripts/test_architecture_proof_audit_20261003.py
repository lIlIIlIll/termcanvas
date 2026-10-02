import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("architecture_proof_step3b5_long_gate.py")
SPEC = importlib.util.spec_from_file_location("audit_long_gate", SCRIPT)
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class LongGateAuditTest(unittest.TestCase):
    def run_gate(self, output):
        with tempfile.TemporaryDirectory() as directory:
            arguments = [str(SCRIPT), "--binary", sys.executable, "--output", directory,
                         "--runs", "1", "--history", "10"]
            completed = subprocess.CompletedProcess([sys.executable], 0, output)
            with patch.object(sys, "argv", arguments), patch.object(
                GATE.subprocess, "run", return_value=completed
            ), contextlib.redirect_stdout(io.StringIO()):
                return GATE.main()

    def test_zero_exit_without_proof_is_not_a_pass(self):
        self.assertNotEqual(self.run_gate(""), 0)

    def test_reported_failed_invariants_are_not_a_pass(self):
        prefix = "tui long transcript frames=2 render=1ms max=1ms documents=3\n"
        for fields in (
            "configured=10 transcript_expected=11 transcript_actual=10 content_preserved=true documents_expected<=3 documents_actual=3",
            "configured=10 transcript_expected=11 transcript_actual=11 content_preserved=false documents_expected<=3 documents_actual=3",
            "configured=10 transcript_expected=11 transcript_actual=11 content_preserved=true documents_expected<=3 documents_actual=4",
        ):
            with self.subTest(fields=fields):
                self.assertNotEqual(self.run_gate(prefix + "tui long transcript gates " + fields), 0)

    def test_complete_passing_proof_is_accepted(self):
        self.assertEqual(self.run_gate(
            "tui long transcript frames=2 render=1ms max=1ms documents=3\n"
            "tui long transcript gates configured=10 transcript_expected=11 transcript_actual=11 "
            "content_preserved=true documents_expected<=3 documents_actual=3\n"
        ), 0)


if __name__ == "__main__":
    unittest.main()
