#!/usr/bin/env python3
"""Tests for the README program extractor and incremental PTY screen."""
import unittest
import os
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import check_readme_quickstart
from check_readme_quickstart import (
    END, START, MANIFEST_END, MANIFEST_START, Screen, extract_manifest, extract_quickstart,
)


class ReadmeQuickstartTest(unittest.TestCase):
    def test_extracts_manifest_and_relocates_only_core_path(self):
        readme = f'{MANIFEST_START}\n```toml\nname = "demo"\npath = "../packages/core"\n```\n{MANIFEST_END}'
        self.assertEqual(extract_manifest(readme, '/isolated/core'), 'name = "demo"\npath = "/isolated/core"\n')

    def test_rejects_missing_or_ambiguous_manifest(self):
        for value in ("", f'{MANIFEST_START}```toml\nname = "demo"\n```{MANIFEST_END}',
                      f'{MANIFEST_START}```toml\npath = "../packages/core"\n```{MANIFEST_END}{MANIFEST_END}'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                extract_manifest(value, '/isolated/core')

    def test_extracts_only_marked_program(self):
        readme = f"```cangjie\nignore\n```\n{START}\n```cangjie\nmain() {{}}\n```\n{END}"
        self.assertEqual(extract_quickstart(readme), "main() {}\n")

    def test_rejects_missing_or_duplicate_markers_and_blocks(self):
        for value in ("", f"{START}{START}{END}", f"{START}```cangjie\na\n```\n```cangjie\nb\n```{END}"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                extract_quickstart(value)

    def test_streaming_screen_observes_cursor_updates(self):
        screen = Screen()
        screen.feed(b"\x1b[6;3H0.00%")
        self.assertEqual(screen.progress(), {"0.00%"})
        screen.feed(b"\x1b[6;")
        screen.feed(b"3H\x1b[0;37m5")
        self.assertEqual(screen.progress(), {"5.00%"})

    def test_incomplete_utf8_and_osc_sequences(self):
        screen = Screen()
        screen.feed("界".encode()[:1])
        screen.feed("界".encode()[1:] + b"\x1b]0;title")
        screen.feed(b"\x07\x1b[2;1H10%")
        self.assertEqual(screen.progress(), {"10%"})

    def test_build_uses_its_own_target_with_canonical_target_configured(self):
        readme = (check_readme_quickstart.ROOT / "README.md").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as directory:
            canonical = Path(directory) / "caller-target"
            canonical.mkdir()
            marker = canonical / "keep"
            marker.write_text("caller data", encoding="utf-8")

            def build(command, *, check):
                self.assertTrue(check)
                project = Path(command[1])
                self.assertEqual(command[2:], ["cjpm", "build", "--target-dir", str(project / "target")])
                self.assertEqual((project / "src/main.cj").read_text(encoding="utf-8"), extract_quickstart(readme))
                self.assertEqual((project / "cjpm.toml").read_text(encoding="utf-8"),
                                 extract_manifest(readme, str(check_readme_quickstart.ROOT / "packages/core")))

            def exercise(binary, project):
                self.assertEqual(binary, project / "target/release/bin/main")

            with patch.dict(os.environ, {"CJ_TUI_CANONICAL_TARGET_ROOT": str(canonical)}), \
                    patch.object(check_readme_quickstart.subprocess, "run", side_effect=build), \
                    patch.object(check_readme_quickstart, "exercise", side_effect=exercise) as checked:
                check_readme_quickstart.main()
            checked.assert_called_once()
            self.assertEqual(marker.read_text(encoding="utf-8"), "caller data")
            self.assertEqual(list(canonical.iterdir()), [marker])

    def test_build_failure_is_not_masked_and_skips_exercise(self):
        failure = subprocess.CalledProcessError(37, ["cjpm", "build"])
        with patch.object(check_readme_quickstart.subprocess, "run", side_effect=failure), \
                patch.object(check_readme_quickstart, "exercise") as checked:
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                check_readme_quickstart.main()
        self.assertIs(raised.exception, failure)
        self.assertEqual(raised.exception.returncode, 37)
        checked.assert_not_called()


if __name__ == "__main__":
    unittest.main()
