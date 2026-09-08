#!/usr/bin/env python3
"""Focused resolver tests that do not access the network or install an SDK."""

from __future__ import annotations

import argparse
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import resolve_nightly_sdk as resolver


REQUESTED = "1.1.0-alpha.20260817040003"
NEWER_PREFIX_MATCH = REQUESTED + ".1"


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


if __name__ == "__main__":
    unittest.main()
