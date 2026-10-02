#!/usr/bin/env python3
"""Focused resolver tests that do not access the network or install an SDK."""

from __future__ import annotations

import argparse
import io
import tarfile
import zipfile
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import resolve_nightly_sdk as resolver


REQUESTED = "1.1.0-alpha.20260817040003"
NEWER_PREFIX_MATCH = REQUESTED + ".1"
STS_VERSION = "1.1.3"


def candidate(name_version: str) -> dict[str, str]:
    return {
        "name": f"cangjie-sdk-linux-x64-{name_version}.tar.gz",
        "version": name_version,
        "url": f"https://example.test/{name_version}.tar.gz",
    }


class FakeResponse:
    def __init__(self, payload: dict):
        self.payload = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self) -> bytes:
        return self.payload


class ResolverVersionSelectionTest(unittest.TestCase):
    def manifest(self, versions: list[str]) -> Path:
        directory = tempfile.TemporaryDirectory(prefix="cj-sdk-manifest-")
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "manifest.json"
        path.write_text(json.dumps([candidate(version) for version in versions]), encoding="utf-8")
        return path

    def test_explicit_manifest_version_is_an_exact_match(self):
        path = self.manifest([REQUESTED, NEWER_PREFIX_MATCH])
        selected = resolver.load_manifest(path, "linux", "x64", "main", REQUESTED)
        self.assertEqual(selected.version, REQUESTED)

    def test_manifest_channel_without_pin_keeps_prefix_selection(self):
        path = self.manifest([REQUESTED, NEWER_PREFIX_MATCH])
        selected = resolver.load_manifest(path, "linux", "x64", "main")
        self.assertEqual(selected.version, NEWER_PREFIX_MATCH)

    def test_sts_channel_selects_only_the_pinned_release(self):
        path = self.manifest([STS_VERSION, STS_VERSION + ".1"])
        selected = resolver.load_manifest(path, "linux", "x64", "sts")
        self.assertEqual(selected.version, STS_VERSION)

    def test_explicit_manifest_version_rejects_prefix_only_candidate(self):
        path = self.manifest([NEWER_PREFIX_MATCH])
        with self.assertRaisesRegex(SystemExit, REQUESTED):
            resolver.load_manifest(path, "linux", "x64", "main", REQUESTED)

    def test_devrepo_version_is_an_exact_match_when_requested(self):
        response = FakeResponse({
            "files": [
                {
                    "real_name": item["name"],
                    "package_version": item["version"],
                    "download_url": item["url"],
                }
                for item in [candidate(REQUESTED), candidate(NEWER_PREFIX_MATCH)]
            ]
        })
        with patch.object(resolver.urllib.request, "urlopen", return_value=response):
            selected = resolver.devrepo_latest("linux", "x64", "main", "token", REQUESTED)
        self.assertEqual(selected.version, REQUESTED)

    def test_explicit_url_uses_the_same_exact_version_contract(self):
        args = argparse.Namespace(
            url=f"https://example.test/cangjie-sdk-linux-x64-{NEWER_PREFIX_MATCH}.tar.gz",
            version=REQUESTED,
            channel="main",
            manifest="",
            os="linux",
            arch="x64",
        )
        with self.assertRaisesRegex(SystemExit, "does not match requested"):
            resolver.resolve(args)


class ResolverArchiveSafetyTest(unittest.TestCase):
    def test_tar_rejects_sibling_prefix_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "sdk.tar.gz"
            with tarfile.open(archive, "w:gz") as tf:
                member = tarfile.TarInfo("../install-sibling/escaped")
                member.size = 1
                tf.addfile(member, io.BytesIO(b"x"))
            with self.assertRaises((SystemExit, tarfile.TarError)):
                resolver.safe_extract(archive, root / "install")
            self.assertFalse((root / "install-sibling/escaped").exists())

    def test_tar_rejects_escaping_symlink_before_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "outside").mkdir()
            archive = root / "sdk.tar.gz"
            with tarfile.open(archive, "w:gz") as tf:
                link = tarfile.TarInfo("link")
                link.type = tarfile.SYMTYPE
                link.linkname = "../outside"
                tf.addfile(link)
                member = tarfile.TarInfo("link/escaped")
                member.size = 1
                tf.addfile(member, io.BytesIO(b"x"))
            with self.assertRaises((SystemExit, tarfile.TarError)):
                resolver.safe_extract(archive, root / "install")
            self.assertFalse((root / "outside/escaped").exists())

    def test_tar_keeps_safe_sdk_relative_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "sdk.tar.gz"
            with tarfile.open(archive, "w:gz") as tf:
                member = tarfile.TarInfo("lib/runtime.so")
                member.size = 1
                tf.addfile(member, io.BytesIO(b"x"))
                link = tarfile.TarInfo("lib/runtime-current.so")
                link.type = tarfile.SYMTYPE
                link.linkname = "runtime.so"
                tf.addfile(link)
            resolver.safe_extract(archive, root / "install")
            self.assertEqual((root / "install/lib/runtime-current.so").read_bytes(), b"x")

    def test_zip_rejects_sibling_prefix_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "sdk.zip"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("../install-sibling/escaped", b"x")
            with self.assertRaises(SystemExit):
                resolver.safe_extract(archive, root / "install")

    def test_install_locates_official_archive_top_level_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "official.tar.gz"
            with tarfile.open(archive, "w:gz") as tf:
                for name in ("cangjie/bin/cjc", "cangjie/tools/bin/cjpm"):
                    member = tarfile.TarInfo(name)
                    member.size = 1
                    tf.addfile(member, io.BytesIO(b"x"))
            sdk = resolver.SdkCandidate(STS_VERSION, "https://example.test/sdk", "sdk.tar.gz")
            with patch.object(resolver, "download", side_effect=lambda url, dest: shutil.copyfile(archive, dest)):
                installed = resolver.install(sdk, root / "install")
            self.assertEqual(installed, root / "install/cangjie")
            self.assertTrue((installed / "bin/cjc").exists())

    def test_github_env_contains_actual_native_runtime_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sdk = root / "sdk"
            runtime = sdk / "runtime/lib/linux_x86_64_cjnative"
            runtime.mkdir(parents=True)
            env_file = root / "github-env"
            path_file = root / "github-path"
            with patch.dict(os.environ, {"GITHUB_ENV": str(env_file), "GITHUB_PATH": str(path_file)}):
                resolver.emit_github_env(sdk, STS_VERSION)
            library_line = next(line for line in env_file.read_text().splitlines() if line.startswith("LD_LIBRARY_PATH="))
            self.assertIn(str(runtime), library_line.split("=", 1)[1].split(":"))
            self.assertIn(str(sdk / "tools/lib"), library_line.split("=", 1)[1].split(":"))

    def test_native_manifest_does_not_select_cross_sdk(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manifest.json"
            native = candidate(STS_VERSION)
            cross = dict(native, name="cangjie-sdk-linux-x64-ohos-1.1.3.tar.gz", url="https://example.test/cross")
            path.write_text(json.dumps([native, cross]), encoding="utf-8")
            self.assertEqual(resolver.load_manifest(path, "linux", "x64", "sts"), resolver.SdkCandidate(STS_VERSION, native["url"], native["name"]))


if __name__ == "__main__":
    unittest.main()
