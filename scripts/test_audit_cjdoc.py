"""Check that documentation audits do not accept stale or ambiguous evidence."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from audit_cjdoc import audit
from generate_cjdoc import MARKER, sha256


class AuditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.portal = Path(self.temp.name) / "portal"
        (self.root / "packages/core/src").mkdir(parents=True)
        self.portal.mkdir()
        self.source = self.root / "packages/core/src/item.cj"
        self.source.write_text("public class Item {}\n", encoding="utf-8")
        self.marker = {"format_version": 1, "partial": True,
                       "sources": {"packages/core/src/item.cj": sha256(self.source)},
                       "sites": [{"package": "core", "platform": "linux"}]}
        self.inventory = {"symbols": [{"stability": "STABLE", "package": "core",
            "path": "packages/core/src/item.cj", "line": 1, "kind": "class", "qualified_symbol": "Item",
            "signature": "public class Item {"}]}
        self.declaration = {"qualifiedName": "core.Item", "kind": "class",
            "source": {"path": "src/item.cj", "start": {"line": 1}, "end": {"line": 1}},
            "documentation": {"summary": "一个条目。", "tags": [{"name": "example"}]}}
        self.write_portal([self.declaration])
        self.root_patch = patch("audit_cjdoc.ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.examples_patch = patch("audit_cjdoc.load_examples", return_value=([], []))
        self.examples_patch.start()
        self.addCleanup(self.examples_patch.stop)

    def write_portal(self, declarations):
        (self.portal / MARKER).write_text(json.dumps(self.marker), encoding="utf-8")
        (self.portal / "api-inventory.json").write_text(json.dumps(self.inventory), encoding="utf-8")
        site = self.portal / "packages/core/linux"
        site.mkdir(parents=True, exist_ok=True)
        (site / "docs.json").write_text(json.dumps({"status": "complete", "diagnostics": [],
            "declarations": declarations}), encoding="utf-8")

    def test_report_does_not_treat_example_tag_as_execution(self):
        report = audit(self.portal)
        self.assertEqual(report["counts"]["chinese_summary"], 1)
        self.assertEqual(report["counts"]["direct_example_tag"], 1)
        self.assertFalse(report["example_execution_verified"])
        self.assertTrue(report["scope_partial"])

    def test_changed_source_rejects_old_portal(self):
        self.source.write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "does not match current source"):
            audit(self.portal)

    def test_duplicate_declaration_is_ambiguous(self):
        self.write_portal([self.declaration, self.declaration])
        report = audit(self.portal)
        self.assertEqual(report["counts"]["ambiguous"], 1)
        self.assertNotIn("mapped", report["counts"])

    def test_missing_parameter_and_return_documentation_are_reported(self):
        self.inventory["symbols"][0].update({"kind": "func", "qualified_symbol": "run", "signature": "public func run(value: Int64): Int64"})
        self.declaration.update({"qualifiedName": "core.run", "kind": "function",
                                 "parameters": [{"name": "value", "documentation": None}],
                                 "returnType": {"spelling": "Int64"}})
        self.write_portal([self.declaration])
        report = audit(self.portal)
        self.assertNotIn("parameters_documented", report["counts"])
        self.assertNotIn("returns_documented", report["counts"])
        reasons = {item["reason"] for item in report["first_missing"]}
        self.assertIn("missing parameter documentation", reasons)
        self.assertIn("missing or unknown return documentation", reasons)

    def test_non_chinese_summary_is_not_counted(self):
        self.declaration["documentation"]["summary"] = "An item."
        self.write_portal([self.declaration])
        report = audit(self.portal)
        self.assertNotIn("chinese_summary", report["counts"])
        self.assertEqual(report["first_missing"][0]["reason"], "missing Chinese summary")


if __name__ == "__main__":
    unittest.main()
