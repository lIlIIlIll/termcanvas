#!/usr/bin/env python3
"""Local fixtures for coverage accounting; no Cangjie SDK is required."""

import contextlib
import html
import io
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from coverage_report import Counts, GATE_EXCLUSIONS, collect_files, generate_reports, main


class CoverageReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "report"
        self.output.mkdir()
        self.page_number = 0

    def page(self, source, lines=(100, 100), branches=(100, 100)):
        self.page_number += 1
        path = self.output / f"page-{self.page_number}.html"
        content = ('<td class="headerName">File:</td>'
                   f'<td class="headerValue">{html.escape(str(source))}</td>')
        for label, counts in (("Lines", lines), ("Branches", branches)):
            if counts is not None:
                content += (f'<td class="headerName">{label}:</td>'
                            f'<td class="headerTableEntry">{counts[0]}</td>'
                            f'<td class="headerTableEntry">{counts[1]}</td>')
        path.write_text(content, encoding="utf-8")
        return path

    def run_cli(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return main([str(self.output), "--root", str(self.root)])

    def test_full_report_includes_every_legacy_gate_exception(self):
        self.page("packages/core/src/text.cj")
        for source in GATE_EXCLUSIONS:
            self.page(source, (0, 100), (0, 100))
        production, gate = generate_reports(self.output, self.root)
        self.assertEqual(production, Counts(100, 500, 100, 500))
        self.assertEqual(gate, Counts(100, 100, 100, 100))
        self.assertEqual(ET.parse(self.output / "coverage.xml").findtext("total-line"), "500")
        self.assertEqual(ET.parse(self.output / "coverage-gate.xml").findtext("total-line"), "100")
        scope = json.loads((self.output / "coverage-scope.json").read_text())
        self.assertTrue(all(row["reported"] for row in scope["gate_exclusions"].values()))
        # Historical gate behavior is retained, not mislabelled as full coverage.
        self.assertEqual(self.run_cli(), 0)

    def test_missing_exemption_reports_are_explicit(self):
        self.page("packages/core/src/text.cj")
        generate_reports(self.output, self.root)
        scope = json.loads((self.output / "coverage-scope.json").read_text())
        self.assertEqual(set(scope["gate_exclusions"]), GATE_EXCLUSIONS)
        for row in scope["gate_exclusions"].values():
            self.assertFalse(row["reported"])
            self.assertIsNone(row["counts"])

    def test_exact_thresholds_pass(self):
        self.page("packages/core/src/text.cj", (90, 100), (80, 100))
        self.assertEqual(self.run_cli(), 0)

    def test_below_line_threshold_fails_and_still_writes_reports(self):
        self.page("packages/core/src/text.cj", (89, 100), (100, 100))
        self.assertEqual(self.run_cli(), 1)
        self.assertTrue((self.output / "coverage.xml").is_file())
        self.assertTrue((self.output / "coverage-scope.json").is_file())

    def test_below_branch_threshold_fails(self):
        self.page("packages/core/src/text.cj", (100, 100), (79, 100))
        self.assertEqual(self.run_cli(), 1)

    def test_tests_examples_and_index_pages_do_not_inflate_production(self):
        self.page("packages/core/src/text.cj", (90, 100), (80, 100))
        self.page("packages/core/src/lib_test.cj", (1000, 1000), (1000, 1000))
        self.page("examples/demo/src/main.cj", (1000, 1000), (1000, 1000))
        (self.output / "index.html").write_text("<html>summary</html>")
        files = collect_files(self.output, self.root)
        self.assertEqual(files, {"packages/core/src/text.cj": Counts(90, 100, 80, 100)})

    def test_empty_scope_fails(self):
        self.assertEqual(self.run_cli(), 1)

    def test_exemption_only_scope_does_not_pass_the_gate(self):
        self.page("packages/core/src/event.cj")
        self.assertEqual(self.run_cli(), 1)

    def test_missing_production_counters_fail_instead_of_being_dropped(self):
        self.page("packages/core/src/text.cj")
        self.page("packages/core/src/event.cj", branches=None)
        self.assertEqual(self.run_cli(), 1)

    def test_identical_duplicate_pages_are_counted_once(self):
        self.page("packages/core/src/text.cj")
        self.page("packages/core/src/text.cj")
        production, _ = generate_reports(self.output, self.root)
        self.assertEqual(production, Counts(100, 100, 100, 100))

    def test_conflicting_duplicate_pages_fail(self):
        self.page("packages/core/src/text.cj")
        self.page("packages/core/src/text.cj", (1, 100))
        self.assertEqual(self.run_cli(), 1)

    def test_invalid_counters_fail(self):
        self.page("packages/core/src/text.cj", (101, 100))
        self.assertEqual(self.run_cli(), 1)

    def test_absolute_and_dot_paths_use_the_same_exclusion_identity(self):
        self.page("./packages/core/src/text.cj")
        self.page(self.root / "packages/core/src/terminal.cj", (1, 100), (1, 100))
        production, gate = generate_reports(self.output, self.root)
        self.assertEqual(production, Counts(101, 200, 101, 200))
        self.assertEqual(gate, Counts(100, 100, 100, 100))

    def test_backslashes_and_html_entities_are_normalized(self):
        self.page(r"packages\core\src\a&b.cj")
        self.assertEqual(set(collect_files(self.output, self.root)), {"packages/core/src/a&b.cj"})

    def test_path_traversal_fails(self):
        self.page("packages/core/../outside.cj")
        self.assertEqual(self.run_cli(), 1)

    def test_zero_total_branch_gate_is_rejected(self):
        self.page("packages/core/src/text.cj", (100, 100), (0, 0))
        self.assertEqual(self.run_cli(), 1)


if __name__ == "__main__":
    unittest.main()
