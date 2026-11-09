#!/usr/bin/env python3
"""Check isolated showcase snapshot integrity and edit detection."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import visual_snapshot as snap
import visual_preview as preview


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='visual-snapshot-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        for item in snap.INPUTS:
            path = self.source / item
            path.mkdir(parents=True)
            (path / 'cjpm.toml').write_text(item)
            (path / 'target').mkdir()
            (path / 'target' / 'artifact').write_text('ignored')
        self.output = self.root / 'snapshot'

    def test_snapshot_excludes_build_and_detects_later_changes(self):
        result = snap.create(self.source, self.output)
        self.assertEqual(result['kind'], 'provisional-dirty-worktree')
        self.assertEqual(preview.snapshot_digest(self.output), result['source_snapshot_sha256'])
        self.assertFalse((self.output / snap.INPUTS[0] / 'target').exists())
        (self.output / snap.INPUTS[0] / 'cjpm.toml').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'differs'):
            preview.snapshot_digest(self.output)

    def test_concurrent_source_change_rejects_and_removes_partial_copy(self):
        original = snap.shutil.copy2
        changed = False
        def modify_after_copy(src, dst):
            nonlocal changed
            result = original(src, dst)
            if not changed:
                Path(src).write_text('concurrent change')
                changed = True
            return result
        with patch.object(snap.shutil, 'copy2', side_effect=modify_after_copy):
            with self.assertRaisesRegex(ValueError, 'source changed'):
                snap.create(self.source, self.output)
        self.assertFalse(self.output.exists())

    def test_refuse_output_inside_source_or_existing_output(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            snap.create(self.source, self.source / 'nested')
        self.output.mkdir()
        with self.assertRaisesRegex(ValueError, 'must not exist'):
            snap.create(self.source, self.output)


if __name__ == '__main__':
    unittest.main()
