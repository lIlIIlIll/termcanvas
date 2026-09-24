#!/usr/bin/env python3
"""Isolated behavior checks for scripts/new_example.sh."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GENERATOR = REPO / "scripts" / "new_example.sh"
TEMPLATE = REPO / "templates" / "basic_app"


class NewExampleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cjtui-new-example-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "templates").mkdir()
        (self.root / "examples").mkdir()
        shutil.copy2(GENERATOR, self.root / "scripts" / "new_example.sh")
        shutil.copytree(TEMPLATE, self.root / "templates" / "basic_app")
        self.script = self.root / "scripts" / "new_example.sh"

    def run_generator(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.script), *args],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_generated_package_manifest_and_files_match_name(self):
        result = self.run_generator("portal")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "created examples/portal")
        generated = self.root / "examples" / "portal"
        manifest_text = (generated / "cjpm.toml").read_text(encoding="utf-8")
        manifest = tomllib.loads(manifest_text)
        source = (generated / "src" / "main.cj").read_text(encoding="utf-8")
        self.assertEqual(manifest["package"]["name"], "cjtui_portal")
        self.assertTrue(source.startswith("package cjtui_portal\n"))
        self.assertNotIn("cjtui_basic_app", source)
        generated_paths = {
            path.relative_to(generated).as_posix()
            for path in generated.rglob("*")
        }
        self.assertEqual(generated_paths, {"cjpm.toml", "src", "src/main.cj"})

    def test_invalid_names_and_argument_counts_do_not_create_destinations(self):
        for name in ("../outside", "bad-name", "UpperCase", ""):
            with self.subTest(name=name):
                result = self.run_generator(name)
                self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "outside").exists())
        self.assertEqual(list((self.root / "examples").iterdir()), [])

        self.assertEqual(self.run_generator().returncode, 2)
        self.assertEqual(self.run_generator("one", "two").returncode, 2)

    def test_existing_directories_files_and_dangling_symlinks_are_preserved(self):
        existing = self.root / "examples" / "already_here"
        existing.mkdir()
        marker = existing / "keep.txt"
        marker.write_text("preserve", encoding="utf-8")
        blocker = self.root / "examples" / "existing_file"
        blocker.write_text("keep file", encoding="utf-8")
        dangling = self.root / "examples" / "dangling"
        dangling.symlink_to("missing-target")

        for name in ("already_here", "existing_file", "dangling"):
            with self.subTest(name=name):
                result = self.run_generator(name)
                self.assertEqual(result.returncode, 1)
        self.assertEqual(marker.read_text(encoding="utf-8"), "preserve")
        self.assertEqual(blocker.read_text(encoding="utf-8"), "keep file")
        self.assertTrue(dangling.is_symlink())
        self.assertEqual(str(dangling.readlink()), "missing-target")

    def test_failed_generation_rolls_back_partial_output(self):
        source = self.root / "templates" / "basic_app" / "src" / "main.cj"
        source.unlink()

        result = self.run_generator("broken")

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "examples" / "broken").exists())
        self.assertEqual(list((self.root / "examples").iterdir()), [])


if __name__ == "__main__":
    unittest.main()
