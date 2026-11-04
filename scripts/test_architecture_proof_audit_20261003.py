import contextlib
import importlib.util
import io
import json
import os
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


class ScratchBuildTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="termcanvas-scratch-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.toolkit = self.root / "toolkit"
        self.consumer = self.root / "consumer"
        self.sdk = self.root / "sdk"
        self.default = self.root / "default"
        self.explicit = self.root / "explicit"
        for path in (self.toolkit / "packages/core", self.toolkit / "packages/markdown_adapter",
                     self.consumer / "agent_tui", self.consumer / "scripts", self.sdk,
                     self.default, self.explicit):
            path.mkdir(parents=True)
        pinned = self.consumer / "scripts/pinned_cangjie"
        pinned.write_text(
            '#!/bin/sh\nif [ "$1" = cjpm ]; then mkdir -p target/release/bin; '
            'printf fake > target/release/bin/agent_app; else echo fake-compiler; fi\n',
            encoding="utf-8",
        )
        pinned.chmod(0o755)

    def run_build(self, name, extra):
        output = self.root / name
        env = os.environ.copy()
        env.update({"TMPDIR": str(self.default), "TMP": str(self.default), "TEMP": str(self.default)})
        command = [sys.executable, str(Path(__file__).with_name("architecture_proof_step05_build.py")),
                   "--cj-tui-root", str(self.toolkit), "--consumer-root", str(self.consumer),
                   "--sdk-root", str(self.sdk), "--output", str(output), *extra]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        return result, output

    def test_default_uses_tmpdir(self):
        result, output = self.run_build("default-output", [])
        self.assertEqual(result.returncode, 0, result.stderr)
        provenance = json.loads((output / "provenance.json").read_text())
        self.assertEqual(Path(provenance["build_root"]).parent, self.default)

    def test_explicit_directory_overrides_tmpdir(self):
        result, output = self.run_build("explicit-output", ["--scratch-dir", str(self.explicit)])
        self.assertEqual(result.returncode, 0, result.stderr)
        provenance = json.loads((output / "provenance.json").read_text())
        self.assertEqual(Path(provenance["build_root"]).parent, self.explicit)

    def test_missing_explicit_directory_does_not_fall_back(self):
        result, output = self.run_build("missing-output", ["--scratch-dir", str(self.root / "missing")])
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((output / "provenance.json").exists())
        self.assertEqual(list(self.default.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
