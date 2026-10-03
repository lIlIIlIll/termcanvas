#!/usr/bin/env python3
"""Isolated behavior checks for scripts/new_example.sh."""

from __future__ import annotations

import shutil
import subprocess
import sys
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
        shutil.copy2(REPO / "scripts" / "new_example.py", self.root / "scripts" / "new_example.py")
        shutil.copytree(TEMPLATE, self.root / "templates" / "basic_app")
        for package in ("core", "testing"):
            directory = self.root / "packages" / package
            directory.mkdir(parents=True)
            (directory / "cjpm.toml").write_text("[package]\n", encoding="utf-8")
        self.script = self.root / "scripts" / "new_example.py"

    def run_generator(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(self.script), *args],
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
        self.assertEqual(generated_paths, {"cjpm.toml", "src", "src/main.cj", "src/main_test.cj"})
        self.assertEqual(manifest["dependencies"]["core"]["path"], "../../packages/core")

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
        symlink_supported = True
        try:
            dangling.symlink_to("missing-target")
        except OSError:
            symlink_supported = False

        names = ["already_here", "existing_file"]
        if symlink_supported:
            names.append("dangling")
        for name in names:
            with self.subTest(name=name):
                result = self.run_generator(name)
                self.assertEqual(result.returncode, 1)
        self.assertEqual(marker.read_text(encoding="utf-8"), "preserve")
        self.assertEqual(blocker.read_text(encoding="utf-8"), "keep file")
        if symlink_supported:
            self.assertTrue(dangling.is_symlink())
            self.assertEqual(str(dangling.readlink()), "missing-target")

    def test_failed_generation_rolls_back_partial_output(self):
        source = self.root / "templates" / "basic_app" / "src" / "main.cj"
        source.unlink()

        result = self.run_generator("broken")

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "examples" / "broken").exists())
        self.assertEqual(list((self.root / "examples").iterdir()), [])

    def test_external_app_uses_selected_library_and_valid_toml_paths(self):
        library = self.root / ('library with spaces' if sys.platform == "win32" else 'library with "quotes"')
        shutil.copytree(self.root / "packages", library / "packages")
        for mode in ("relative", "absolute"):
            destination = self.root / "independent apps" / mode
            result = self.run_generator("portal", "--output", str(destination),
                                        "--library-root", str(library), "--dependency-path", mode)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = tomllib.loads((destination / "cjpm.toml").read_text())
            for name, package in (("core", "core"), ("cjtui_testing", "testing")):
                dependency = Path(manifest["dependencies"][name]["path"])
                self.assertEqual((destination / dependency).resolve(), library / "packages" / package)
                self.assertEqual(dependency.is_absolute(), mode == "absolute")

    def test_symlinked_output_parent_uses_the_real_dependency_location(self):
        actual = self.root / "nested" / "actual"
        actual.mkdir(parents=True)
        alias = self.root / "alias"
        try:
            alias.symlink_to(actual, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"directory symlinks unavailable: {error}")
        result = self.run_generator("portal", "--output", str(alias / "app"))
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = tomllib.loads((actual / "app" / "cjpm.toml").read_text())
        dependency = manifest["dependencies"]["core"]["path"]
        self.assertEqual((actual / "app" / dependency).resolve(), self.root / "packages" / "core")

    def test_explicit_script_cache_is_emitted_for_independent_builds(self):
        destination = self.root / "independent app"
        script_cache = self.root / "scripts-cache"
        result = self.run_generator("portal", "--output", str(destination),
                                    "--script-dir", str(script_cache))
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = tomllib.loads((destination / "cjpm.toml").read_text())
        self.assertEqual(Path(manifest["package"]["script-dir"]), script_cache.resolve())
        self.assertFalse(script_cache.exists())


if __name__ == "__main__":
    unittest.main()
