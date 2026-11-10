"""Check that Pages preparation rejects incomplete or mismatched evidence."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from check_cjdoc_links import check as check_links
from generate_cjdoc import MARKER
from prepare_cjdoc_publication import prepare


class PublicationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.portal = self.root / "portal"
        self.portal.mkdir()
        (self.portal / "index.html").write_text('<h1>API</h1><ul></ul>', encoding="utf-8")
        (self.portal / MARKER).write_text(json.dumps({"sources": {"source.cj": "a" * 64}}), encoding="utf-8")
        self.archive = self.root / "offline.zip"
        with zipfile.ZipFile(self.archive, "w") as z:
            for path in self.portal.iterdir():
                z.write(path, path.name)
        self.result = {"status": "passed", "format_version": 1}
        self.attestation = self.root / "attestation.json"
        self.attestation.write_text(json.dumps(self.result), encoding="utf-8")
        self.reports = []
        for target in ("linux", "macos", "windows"):
            report = self.root / (target + ".json")
            report.write_text(json.dumps({"platform": target, "sources": {"source.cj": "a" * 64}}), encoding="utf-8")
            self.reports.append(report)

    def test_verified_site_has_download_evidence_and_working_links(self):
        with patch("prepare_cjdoc_publication.check", return_value=self.result), patch("prepare_cjdoc_publication.verify_commit"):
            prepare(self.portal, self.archive, self.attestation, self.reports, "a" * 40)
        self.assertTrue((self.portal / "downloads/termcanvas-api-reference.zip").is_file())
        self.assertTrue((self.portal / "evidence/completion.json").is_file())
        self.assertEqual(check_links(self.portal)[1], [])
        publication = json.loads((self.portal / "publication-manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(publication["source_revision"], "a" * 40)
        self.assertIn("downloads/termcanvas-api-reference.zip", publication["files"])

    def test_incomplete_attestation_does_not_change_site(self):
        with patch("prepare_cjdoc_publication.check", return_value={"status": "failed"}):
            with self.assertRaisesRegex(ValueError, "incomplete or mismatched"):
                prepare(self.portal, self.archive, self.attestation, self.reports, "a" * 40)
        self.assertFalse((self.portal / "downloads").exists())

    def test_archive_from_another_site_is_rejected(self):
        (self.portal / "index.html").write_text('<h1>Changed</h1><ul></ul>', encoding="utf-8")
        with patch("prepare_cjdoc_publication.check", return_value=self.result), patch("prepare_cjdoc_publication.verify_commit"):
            with self.assertRaisesRegex(ValueError, "differs from portal"):
                prepare(self.portal, self.archive, self.attestation, self.reports, "a" * 40)
        self.assertFalse((self.portal / "downloads").exists())


if __name__ == "__main__":
    unittest.main()
