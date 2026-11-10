"""Exercise local and fragment link checks for offline documentation."""
from pathlib import Path
import tempfile
import unittest
from check_cjdoc_links import check


class LinkCheckTest(unittest.TestCase):
    def test_valid_file_and_anchor(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "index.html").write_text('<a href="doc.html#label">Doc</a>', encoding="utf-8")
            (root / "doc.html").write_text('<h1 id="label">Doc</h1>', encoding="utf-8")
            self.assertEqual(check(root), (1, []))

    def test_missing_anchor_and_escaping_link_are_reported(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "index.html").write_text('<a href="#missing">x</a><a href="../other">y</a>', encoding="utf-8")
            count, errors = check(root)
            self.assertEqual(count, 2)
            self.assertEqual(len(errors), 2)
            self.assertTrue(any("missing anchor" in error for error in errors))
            self.assertTrue(any("leaves portal" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
