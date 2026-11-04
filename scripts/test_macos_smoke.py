#!/usr/bin/env python3
"""Check that the macOS smoke wrapper uses an explicit SSH destination."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


WRAPPER = Path(__file__).resolve().parent / "run_macos_smoke.sh"


class MacOSSmokeWrapperTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="termcanvas-macos-smoke-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        fake_ssh = self.root / "ssh"
        fake_ssh.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$@" > "$TASK_SSH_CAPTURE"\ncat >/dev/null\n',
            encoding="utf-8",
        )
        fake_ssh.chmod(0o755)
        self.capture = self.root / "ssh-args.txt"
        self.environment = os.environ.copy()
        for name in ("MACOS_HOST", "MACOS_REPO", "MACOS_SSH_CONFIG"):
            self.environment.pop(name, None)
        self.environment.update({
            "PATH": str(self.root) + os.pathsep + self.environment.get("PATH", ""),
            "TASK_SSH_CAPTURE": str(self.capture),
        })

    def run_wrapper(self, **variables):
        env = {**self.environment, **variables}
        return subprocess.run(["bash", str(WRAPPER)], env=env, text=True, capture_output=True)

    def test_missing_host_or_repository_does_not_connect(self):
        for variables in ({"MACOS_REPO": "/example/repo"}, {"MACOS_HOST": "user@example-host"}):
            with self.subTest(variables=variables):
                result = self.run_wrapper(**variables)
                self.assertEqual(result.returncode, 2)
                self.assertIn("MACOS_HOST=", result.stderr)
                self.assertFalse(self.capture.exists())

    def test_explicit_host_and_repository_reach_ssh(self):
        result = self.run_wrapper(MACOS_HOST="user@example-host", MACOS_REPO="/example/repo")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.capture.read_text(encoding="utf-8").splitlines()
        self.assertIn("user@example-host", args)
        self.assertIn("/example/repo", args)


if __name__ == "__main__":
    unittest.main()
