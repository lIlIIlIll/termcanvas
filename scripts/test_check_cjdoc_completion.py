"""Test the release gate against missing, failed, and stale example evidence."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from check_cjdoc_completion import check
from generate_cjdoc import MARKER, sha256


class CompletionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.portal = self.root / "portal"
        self.portal.mkdir()
        self.source = self.root / "example.cj"
        self.source.write_text("main(): Int64 { 0 }", encoding="utf-8")
        self.sources = {"source.cj": "a" * 64}
        (self.portal / MARKER).write_text(json.dumps({"sources": self.sources, "sdk": {"cjc_sha256": "a" * 64,
            "cjpm_sha256": "b" * 64, "runtime_sha256": "c" * 64}}), encoding="utf-8")
        (self.portal / "api-inventory.json").write_text('{"symbols": []}', encoding="utf-8")
        self.scenario = {"id": "one", "source": "example.cj", "platforms": ["linux", "macos", "windows"]}
        self.summary = {"scope_partial": False, "counts": {"application_declarations": 1, "mapped": 1,
            "chinese_summary": 1, "parameters_documented": 1, "returns_documented": 1, "shared_example_linked": 1}}
        self.patches = [patch("check_cjdoc_completion.ROOT", self.root),
            patch("check_cjdoc_completion.audit", return_value=self.summary),
            patch("check_cjdoc_completion.load_examples", return_value=([self.scenario], []))]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def report(self, target, status="passed", sources=None):
        sources = self.sources if sources is None else sources
        digest = hashlib.sha256(json.dumps(sources, sort_keys=True).encode("utf-8")).hexdigest()
        report = {"format_version": 1, "platform": target, "selected": False, "sources": sources,
            "sources_sha256": digest, "sdk": {"cjc_version": "Cangjie Compiler: 1.2.0", "cjpm_version": "cjpm 1.2.0",
            "cjc_sha256": "a" * 64, "cjpm_sha256": "b" * 64, "runtime_sha256": "c" * 64},
            "results": [{"id": "one", "source": "example.cj", "source_sha256": sha256(self.source), "status": status}]}
        path = self.root / (target + ".json")
        path.write_text(json.dumps(report), encoding="utf-8")
        return path

    def test_matching_three_platform_reports_pass(self):
        reports = [self.report(target) for target in ("linux", "macos", "windows")]
        self.assertEqual(check(self.portal, reports)["status"], "passed")

    def test_missing_native_platforms_fail(self):
        result = check(self.portal, [self.report("linux")])
        self.assertEqual(result["status"], "failed")
        self.assertIn("missing native example report: windows", result["failures"])

    def test_stale_sources_fail(self):
        reports = [self.report("linux", sources={"source.cj": "b" * 64}), self.report("macos"), self.report("windows")]
        result = check(self.portal, reports)
        self.assertIn("source identities do not match portal: linux", result["failures"])

    def test_failed_scenario_and_missing_docs_fail(self):
        self.summary["counts"]["chinese_summary"] = 0
        reports = [self.report("linux", "failed"), self.report("macos"), self.report("windows")]
        result = check(self.portal, reports)
        self.assertIn("chinese_summary: 0/1", result["failures"])
        self.assertIn("scenario one is not verified on linux", result["failures"])


if __name__ == "__main__":
    unittest.main()
