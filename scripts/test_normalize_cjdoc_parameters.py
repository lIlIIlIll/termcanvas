"""Verify the bounded workaround for cjdoc anonymous parameters."""
import json
from pathlib import Path
import tempfile
import unittest

from audit_cjdoc import parameters_documented
from normalize_cjdoc_parameters import normalize


class AnonymousParameterRepairTest(unittest.TestCase):
    def make_site(self, root: Path, tags: list[dict]) -> None:
        html = root / "html"
        html.mkdir()
        (html / "symbol-index.json").write_text(json.dumps({"entries": [{"id": "id", "href": "symbol.html"}]}))
        (html / "symbol.html").write_text('<main><dl class="parameter-list">' +
            '<div class="parameter-row"><dd class="parameter-description"></dd></div>' * 2 + '</dl></main>')
        declaration = {"id": "id", "parameters": [{"name": "_", "documentation": None}] * 2,
                       "documentation": {"tags": tags}}
        (root / "docs.json").write_text(json.dumps({"declarations": [declaration]}))

    def test_repairs_json_and_visible_html(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_site(root, [{"name": "param", "subject": "_0", "description": "索引"},
                                  {"name": "param", "subject": "_1", "description": "宽度 <限制>"}])
            self.assertEqual(normalize(root), 1)
            doc = json.loads((root / "docs.json").read_text())["declarations"][0]
            self.assertEqual([p["documentation"] for p in doc["parameters"]], ["索引", "宽度 <限制>"])
            page = (root / "html/symbol.html").read_text()
            self.assertIn('data-termcanvas-anonymous-index="0"><p>索引</p>', page)
            self.assertIn('data-termcanvas-anonymous-index="1"><p>宽度 &lt;限制&gt;</p>', page)
            self.assertEqual(doc["termcanvasAnonymousParameterRepair"]["generator"], "cjdoc-0.7.7")
            self.assertTrue(parameters_documented(doc, root / "html/symbol.html"))
            (root / "html/symbol.html").write_text(page.replace('data-termcanvas-anonymous-index="1"', ''))
            self.assertFalse(parameters_documented(doc, root / "html/symbol.html"))

    def test_leaves_incomplete_tag_set_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_site(root, [{"name": "param", "subject": "_0", "description": "索引"}])
            original = (root / "docs.json").read_bytes()
            self.assertEqual(normalize(root), 0)
            self.assertEqual((root / "docs.json").read_bytes(), original)

    def test_leaves_unannotated_declarations_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_site(root, [])
            self.assertEqual(normalize(root), 0)


if __name__ == "__main__":
    unittest.main()
