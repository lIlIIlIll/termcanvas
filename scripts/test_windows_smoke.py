#!/usr/bin/env python3
"""Local wrapper tests for generated Windows smoke runner ownership and shape."""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "scripts/run_windows_smoke.sh"


class WindowsSmokeWrapperTest(unittest.TestCase):
    def run_wrapper(
        self,
        runner_exit: int,
        *,
        fail_install: bool = False,
    ) -> tuple[subprocess.CompletedProcess[str], str]:
        directory = tempfile.TemporaryDirectory(prefix="cj-windows-smoke-")
        self.addCleanup(directory.cleanup)
        work = Path(directory.name)
        share = work / "share"
        cases = share / "cases"
        fake_bin = work / "bin"
        (share / "sdk").mkdir(parents=True)
        cases.mkdir()
        fake_bin.mkdir()

        previous_runner = "Write-Output 'previous runner'\n"
        custom_runner = cases / "run-tests.ps1"
        custom_runner.write_text(previous_runner, encoding="utf-8")
        capture = work / "generated-runner.ps1"

        fake_rsync = fake_bin / "rsync"
        fake_rsync.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            "destination=''\n"
            "for argument in \"$@\"; do destination=\"$argument\"; done\n"
            "mkdir -p \"$destination\"\n",
            encoding="utf-8",
        )
        fake_runner = fake_bin / "capture-runner"
        fake_runner.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            "share=''\n"
            "while [[ $# -gt 0 ]]; do\n"
            "  case \"$1\" in\n"
            "    --share) share=\"$2\"; shift 2 ;;\n"
            "    *) shift ;;\n"
            "  esac\n"
            "done\n"
            "cp \"$share/cases/run-tests.ps1\" \"$CAPTURE_PATH\"\n"
            "exit \"${FAKE_RUNNER_RC:-0}\"\n",
            encoding="utf-8",
        )
        fake_rsync.chmod(0o755)
        fake_runner.chmod(0o755)

        if fail_install:
            real_mv = shutil.which("mv")
            self.assertIsNotNone(real_mv)
            fake_mv = fake_bin / "mv"
            fake_mv.write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "if [[ \"${1:-}\" == '-f' && \"${2:-}\" == *run-tests.ps1.termcanvas_new.* "
                "&& \"${3:-}\" == */run-tests.ps1 ]]; then\n"
                "  printf 'partial runner\\n' > \"$3\"\n"
                "  exit 23\n"
                "fi\n"
                f"exec {shlex.quote(real_mv)} \"$@\"\n",
                encoding="utf-8",
            )
            fake_mv.chmod(0o755)

        env = os.environ.copy()
        env.update({
            "PATH": f"{fake_bin}:{env.get('PATH', '')}",
            "SHARE": str(share),
            "RUN_VBOX_CJ_TESTS": str(fake_runner),
            "CAPTURE_PATH": str(capture),
            "FAKE_RUNNER_RC": str(runner_exit),
        })
        result = subprocess.run(
            ["bash", str(WRAPPER)],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

        generated = capture.read_text(encoding="utf-8") if capture.exists() else ""
        self.assertEqual(custom_runner.read_text(encoding="utf-8"), previous_runner)
        self.assertEqual(list(cases.glob("termcanvas.*")), [])
        return result, generated

    def assert_runner_shape(self, generated: str) -> None:
        significant = [
            line.strip()
            for line in generated.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(significant[0], "param(")
        self.assertRegex(
            generated,
            r'(?m)^\$RepoName = "termcanvas\.[A-Za-z0-9]{8}" # TERMCANVAS_STAGE_NAME_PLACEHOLDER$',
        )
        self.assertNotIn('$env:TERMCANVAS_STAGE_NAME', generated)
        self.assertLess(generated.index("param("), generated.index("$RepoName = "))

    def test_generated_runner_keeps_param_first_and_uses_unique_stage(self):
        result, generated = self.run_wrapper(0)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assert_runner_shape(generated)

    def test_runner_failure_is_returned_after_restoring_shared_files(self):
        result, generated = self.run_wrapper(7)
        self.assertEqual(result.returncode, 7, result.stdout)
        self.assert_runner_shape(generated)

    def test_partial_install_failure_restores_previous_runner(self):
        result, generated = self.run_wrapper(0, fail_install=True)
        self.assertEqual(result.returncode, 23, result.stdout)
        self.assertEqual(generated, "")


if __name__ == "__main__":
    unittest.main()
