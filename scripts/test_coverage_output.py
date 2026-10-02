#!/usr/bin/env python3
"""Exercise coverage cleanup only, with a deliberately failing test runner."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CoverageOutputSafetyTest(unittest.TestCase):
    def run_coverage(self, output_kind):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name) / 'repo'
        scripts = root / 'scripts'
        scripts.mkdir(parents=True)
        for directory in ('packages', 'examples'):
            (root / directory).mkdir()
        shutil.copy2(ROOT / 'scripts/coverage.sh', scripts / 'coverage.sh')
        for name, body in (('check_sdk.sh', 'echo /unused-sdk'), ('cangjie_cmd.sh', 'exit 23')):
            path = scripts / name
            path.write_text('#!/bin/sh\n' + body + '\n')
            path.chmod(0o755)
        output = root if output_kind == 'repo' else root.parent / 'output'
        if output_kind in ('target', 'nested-target'):
            output = root / '.coverage-target'
            if output_kind == 'nested-target':
                output /= 'report'
        output.mkdir(parents=True, exist_ok=True)
        sentinel = output / 'keep.txt'
        sentinel.write_text('user data')
        if output_kind == 'owned':
            (output / '.cjtui-coverage-output').write_text('cjtui coverage\n')
        result = subprocess.run(['bash', str(scripts / 'coverage.sh'), str(output)], env=os.environ.copy(), capture_output=True, text=True)
        return result, sentinel, output

    def test_unowned_nonempty_directory_is_preserved(self):
        result, sentinel, _ = self.run_coverage('unowned')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(sentinel.exists(), result.stderr)

    def test_repository_directory_is_preserved(self):
        result, sentinel, _ = self.run_coverage('repo')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(sentinel.exists(), result.stderr)

    def test_owned_previous_report_is_replaced(self):
        result, sentinel, output = self.run_coverage('owned')
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertFalse(sentinel.exists())
        self.assertTrue((output / '.cjtui-coverage-output').exists())

    def test_output_cannot_overlap_the_build_target(self):
        for kind in ('target', 'nested-target'):
            with self.subTest(kind=kind):
                result, sentinel, _ = self.run_coverage(kind)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(sentinel.exists(), result.stderr)


if __name__ == '__main__':
    unittest.main()
