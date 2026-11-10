"""Check shared example binding validation and generated-page links."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from cjdoc_examples import link_examples, load_examples
from check_cjdoc_links import check


class ExampleLinkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.output = Path(self.temp.name) / "output"
        examples = self.root / "docs/api-examples"
        examples.mkdir(parents=True)
        self.output.mkdir()
        (examples / "example.cj").write_text('main(): Int64 { 0 }\n', encoding="utf-8")
        self.manifest = examples / "manifest.json"
        self.binding = {"package": "core", "path": "packages/core/src/item.cj", "symbol": "Item",
                        "signature": "public class Item {"}
        self.inventory = {"symbols": [{"package": "core", "path": "packages/core/src/item.cj",
            "qualified_symbol": "Item", "signature": "public class Item {", "stability": "STABLE",
            "line": 1, "kind": "class"}]}
        self.data = {"format_version": 1, "scenarios": [{"id": "item-example",
            "source": "docs/api-examples/example.cj", "dependencies": [], "platforms": ["linux"],
            "declarations": [self.binding]}]}
        self.write_manifest()
        self.patch_root = patch("cjdoc_examples.ROOT", self.root)
        self.patch_manifest = patch("cjdoc_examples.MANIFEST", self.manifest)
        self.patch_root.start()
        self.patch_manifest.start()
        self.addCleanup(self.patch_root.stop)
        self.addCleanup(self.patch_manifest.stop)

    def write_manifest(self):
        self.manifest.write_text(json.dumps(self.data), encoding="utf-8")

    def test_unknown_signature_is_rejected(self):
        self.data["scenarios"][0]["declarations"][0]["signature"] = "public class Other {"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "unknown or duplicate"):
            load_examples(self.inventory)

    def test_unknown_dependency_is_rejected(self):
        self.data["scenarios"][0]["dependencies"] = ["unknown"]
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "invalid dependencies"):
            load_examples(self.inventory)

    def test_source_outside_examples_is_rejected(self):
        self.data["scenarios"][0]["source"] = "../outside.cj"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "invalid source"):
            load_examples(self.inventory)

    def test_conditional_implementations_link_on_each_platform(self):
        second = dict(self.inventory["symbols"][0], line=20)
        self.inventory["symbols"].append(second)
        self.data["scenarios"][0]["platforms"] = ["linux", "windows"]
        self.write_manifest()
        scenarios, _ = load_examples(self.inventory)
        sites = []
        for platform, line in (("linux", 1), ("windows", 20)):
            html_root = self.output / "packages" / "core" / platform / "html"
            html_root.mkdir(parents=True)
            (html_root / "item.html").write_text("<main></main>", encoding="utf-8")
            entry = {"qualifiedName": "core.Item", "kind": "class", "href": "item.html",
                     "source": {"path": "src/item.cj", "start": {"line": line}, "end": {"line": line}}}
            (html_root / "symbol-index.json").write_text(json.dumps({"entries": [entry]}), encoding="utf-8")
            sites.append({"package": "core", "platform": platform})
        link_examples(self.output, sites, scenarios)
        for site in sites:
            page = self.output / "packages" / "core" / site["platform"] / "html" / "item.html"
            self.assertIn("termcanvas-example-item-example", page.read_text(encoding="utf-8"))

    def test_missing_binding_only_fails_for_an_applicable_selected_site(self):
        scenarios, _ = load_examples(self.inventory)
        cases = (
            ("windows", [("core", "windows")], False),
            ("macos", [("core", "macos")], False),
            ("other-package", [("diff", "linux")], False),
            ("crossed-pairs", [("core", "windows"), ("diff", "linux")], False),
            ("linux", [("core", "linux")], True),
            ("mixed-platforms", [("core", "windows"), ("core", "linux")], True),
        )
        for name, selected, should_fail in cases:
            with self.subTest(name=name):
                output = self.output / name
                output.mkdir()
                sites = []
                for package, platform in selected:
                    html_root = output / "packages" / package / platform / "html"
                    html_root.mkdir(parents=True)
                    (html_root / "symbol-index.json").write_text('{"entries": []}', encoding="utf-8")
                    sites.append({"package": package, "platform": platform})
                if should_fail:
                    with self.assertRaisesRegex(ValueError, "example binding has no generated page: Item"):
                        link_examples(output, sites, scenarios)
                else:
                    link_examples(output, sites, scenarios)

    def test_link_points_to_shared_offline_example(self):
        scenarios, _ = load_examples(self.inventory)
        html_root = self.output / "packages/core/linux/html"
        (html_root / "symbols").mkdir(parents=True)
        page = html_root / "symbols/item.html"
        page.write_text('<html><main><h1>Item</h1></main></html>', encoding="utf-8")
        entry = {"qualifiedName": "core.Item", "kind": "class", "href": "symbols/item.html",
                 "source": {"path": "src/item.cj", "start": {"line": 1}, "end": {"line": 1}}}
        (html_root / "symbol-index.json").write_text(json.dumps({"entries": [entry]}), encoding="utf-8")
        (self.output / "index.html").write_text('<a href="packages/core/linux/html/symbols/item.html">Item</a>', encoding="utf-8")
        link_examples(self.output, [{"package": "core", "platform": "linux"}], scenarios)
        self.assertIn('termcanvas-example-item-example', page.read_text(encoding="utf-8"))
        self.assertIn('main(): Int64', (self.output / "examples/item-example.html").read_text(encoding="utf-8"))
        self.assertEqual(check(self.output)[1], [])


if __name__ == "__main__":
    unittest.main()
