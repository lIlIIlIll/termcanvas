"""Exercise cjdoc output ownership and publication failure behavior."""
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from generate_cjdoc import GenerationError, MARKER, ROOT, check_owned, replace_owned


class ManagedOutputTest(unittest.TestCase):
    def test_unmanaged_directory_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = root / "docs"
            output.mkdir()
            sentinel = output / "keep.txt"
            sentinel.write_text("user data", encoding="utf-8")
            with self.assertRaises(GenerationError):
                check_owned(output)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "user data")

    def test_corrupt_marker_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "docs"
            output.mkdir()
            (output / MARKER).write_text("not-json", encoding="utf-8")
            with self.assertRaises(GenerationError):
                check_owned(output)

    def test_successful_replacement_removes_stale_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output, built, staging = root / "docs", root / "built", root / "staging"
            for path in (output, built, staging):
                path.mkdir()
            (output / MARKER).write_text(json.dumps({"format_version": 1}), encoding="utf-8")
            (output / "stale.txt").write_text("old", encoding="utf-8")
            (built / "index.html").write_text("new", encoding="utf-8")
            replace_owned(output, built, staging)
            self.assertEqual((output / "index.html").read_text(encoding="utf-8"), "new")
            self.assertFalse((output / "stale.txt").exists())

    def test_failed_publication_restores_previous_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output, built, staging = root / "docs", root / "built", root / "staging"
            for path in (output, built, staging):
                path.mkdir()
            (output / MARKER).write_text(json.dumps({"format_version": 1}), encoding="utf-8")
            (output / "index.html").write_text("old", encoding="utf-8")
            (built / "index.html").write_text("new", encoding="utf-8")
            real_replace = os.replace
            count = 0

            def fail_second(src, dst):
                nonlocal count
                count += 1
                if count == 2:
                    raise OSError("simulated install failure")
                return real_replace(src, dst)

            with patch("generate_cjdoc.os.replace", side_effect=fail_second):
                with self.assertRaises(OSError):
                    replace_owned(output, built, staging)
            self.assertEqual((output / "index.html").read_text(encoding="utf-8"), "old")
            self.assertTrue((built / "index.html").exists())


@unittest.skipUnless(os.environ.get("TERMCANVAS_CJDOC_BINARY"), "set TERMCANVAS_CJDOC_BINARY for a real cjdoc integration test")
class CjdocIntegrationTest(unittest.TestCase):
    def test_testing_parameters_bind_in_generated_doc_ir(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "portal"
            subprocess.run([sys.executable, str(ROOT / "scripts/generate_cjdoc.py"),
                "--cjdoc", os.environ["TERMCANVAS_CJDOC_BINARY"], "--output", str(output),
                "--package", "testing", "--platform", "linux"], check=True, timeout=180)
            document = json.loads((output / "packages/testing/linux/docs.json").read_text(encoding="utf-8"))
            declaration = next(item for item in document["declarations"]
                               if item["qualifiedName"] == "cjtui_testing.TestScenario.run")
            parameters = {item["name"]: item["documentation"] for item in declaration["parameters"]}
            self.assertEqual(parameters["render"], "根据应用状态绘制当前帧的回调")
            self.assertEqual(parameters["width"], "初始终端宽度，单位为单元格")
            marker = json.loads((output / MARKER).read_text(encoding="utf-8"))
            self.assertTrue(marker["partial"])
            self.assertFalse(marker["examples_verified_at_generation"])


if __name__ == "__main__":
    unittest.main()
