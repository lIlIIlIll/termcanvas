#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from native_sdk import sdk_environment, verify_sdk


class NativeSdkTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="cjtui-sdk-")
        self.addCleanup(temp.cleanup)
        # macOS /var aliases and Windows 8.3 temporary paths resolve to the
        # same directory that sdk_environment deliberately canonicalizes.
        self.root = Path(temp.name).resolve()

    def fixture(self, system, arch):
        prefix, extension, executable = {
            "Linux": ("linux", ".so", ""),
            "Darwin": ("darwin", ".dylib", ""),
            "Windows": ("windows", ".dll", ".exe"),
        }[system]
        for relative in ("bin/cjc" + executable, "tools/bin/cjpm" + executable,
                         f"runtime/lib/{prefix}_{arch}_cjnative/libcangjie-runtime{extension}"):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        (self.root / "tools/lib").mkdir()

    def test_linux_environment_uses_verified_runtime_and_tools(self):
        self.fixture("Linux", "x86_64")
        root, env, runtime = sdk_environment(str(self.root), system="Linux", machine="x86_64")
        self.assertEqual(root, self.root)
        self.assertIn(str(runtime.parent), env["LD_LIBRARY_PATH"].split(os.pathsep))
        self.assertIn(str(root / "tools/lib"), env["LD_LIBRARY_PATH"].split(os.pathsep))

    def test_native_macos_arm64_environment(self):
        self.fixture("Darwin", "aarch64")
        with patch.dict(os.environ, {"SDKROOT": "/already/configured"}):
            _, env, runtime = sdk_environment(str(self.root), system="Darwin", machine="arm64")
        self.assertEqual(env["SDKROOT"], "/already/configured")
        self.assertIn(str(runtime.parent), env["DYLD_LIBRARY_PATH"].split(os.pathsep))

    def test_windows_dll_search_path(self):
        self.fixture("Windows", "x86_64")
        _, env, runtime = sdk_environment(str(self.root), system="Windows", machine="AMD64")
        self.assertIn(str(runtime.parent), env["PATH"].split(os.pathsep))

    def test_wrong_architecture_and_missing_tool_are_rejected(self):
        self.fixture("Linux", "x86_64")
        with self.assertRaises(ValueError):
            sdk_environment(str(self.root), system="Linux", machine="aarch64")
        (self.root / "tools/bin/cjpm").unlink()
        with self.assertRaises(ValueError):
            sdk_environment(str(self.root), system="Linux", machine="x86_64")

    def test_version_comparison_does_not_accept_a_prefix(self):
        result = subprocess.CompletedProcess([], 0, "Cangjie Compiler: 1.1.30", "")
        with patch("native_sdk.subprocess.run", return_value=result):
            with self.assertRaises(ValueError):
                verify_sdk(self.root, {})

    def test_failed_version_command_cannot_pass_by_printing_version(self):
        result = subprocess.CompletedProcess([], 1, "1.1.3", "failed")
        with patch("native_sdk.subprocess.run", return_value=result):
            with self.assertRaises(ValueError):
                verify_sdk(self.root, {})


if __name__ == "__main__":
    unittest.main()
