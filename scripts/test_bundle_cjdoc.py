"""Test offline archive reproducibility and output protection."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from bundle_cjdoc import bundle


class BundleTest(unittest.TestCase):
    def test_reproducible_archive_contains_site(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            portal = root / "portal"
            portal.mkdir()
            (portal / "index.html").write_text('<a href="doc.html#api">API</a>', encoding="utf-8")
            (portal / "doc.html").write_text('<h1 id="api">API</h1>', encoding="utf-8")
            first, second = root / "a.zip", root / "b.zip"
            with patch("bundle_cjdoc.audit"):
                one = bundle(portal, first)
                two = bundle(portal, second)
            self.assertEqual(one, two)
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(set(archive.namelist()), {"index.html", "doc.html"})
                self.assertIn(b'id="api"', archive.read("doc.html"))

    def test_existing_archive_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            portal = root / "portal"
            portal.mkdir()
            output = root / "existing.zip"
            output.write_bytes(b"user data")
            with self.assertRaisesRegex(ValueError, "already exists"):
                bundle(portal, output)
            self.assertEqual(output.read_bytes(), b"user data")

    def test_failed_publication_leaves_no_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            portal = root / "portal"
            portal.mkdir()
            (portal / "index.html").write_text("<h1>API</h1>", encoding="utf-8")
            output = root / "failed.zip"
            with patch("bundle_cjdoc.audit"), patch("bundle_cjdoc.os.link", side_effect=OSError("failed")):
                with self.assertRaises(OSError):
                    bundle(portal, output)
            self.assertFalse(output.exists())

    def test_broken_link_prevents_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            portal = root / "portal"
            portal.mkdir()
            (portal / "index.html").write_text('<a href="missing.html">x</a>', encoding="utf-8")
            output = root / "failed.zip"
            with patch("bundle_cjdoc.audit"):
                with self.assertRaisesRegex(ValueError, "broken local links"):
                    bundle(portal, output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
