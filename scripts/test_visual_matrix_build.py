#!/usr/bin/env python3
"""Controlled dependency and snapshot-boundary checks for matrix builds."""
from pathlib import Path
import tempfile
import tarfile
import unittest

import visual_matrix_build as build


class MatrixBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='matrix-build-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'snapshot'
        self.root.mkdir()
        for directory in build.DIRS:
            (self.root / directory).mkdir(parents=True)
            (self.root / directory / 'cjpm.toml').write_text('[dependencies]\n')
        (self.root / 'vendor/markdown').mkdir(parents=True)
        (self.root / 'vendor/markdown/cjpm.toml').write_text('[dependencies]\n')

    def test_dependency_must_stay_in_snapshot_and_not_use_git(self):
        matrix = self.root / 'examples/visual_matrix/cjpm.toml'
        matrix.write_text('[dependencies]\ncore = { path = "../../packages/core" }\n')
        build.validate_dependencies(self.root)
        core = self.root / 'packages/core/cjpm.toml'
        core.write_text('[dependencies]\nnested = { git = "https://example.test/nested" }\n')
        with self.assertRaisesRegex(ValueError, 'uncontrolled dependency'):
            build.validate_dependencies(self.root)
        outside = self.root.parent / 'external'
        outside.mkdir()
        (outside / 'cjpm.toml').write_text('[dependencies]\n')
        core.write_text('[dependencies]\nnested = { path = "../../../external" }\n')
        with self.assertRaisesRegex(ValueError, 'escapes source snapshot'):
            build.validate_dependencies(self.root)
        core.write_text('[dependencies]\n')
        matrix.write_text('[dependencies]\ncore = { git = "https://example.test/repo" }\n')
        with self.assertRaisesRegex(ValueError, 'uncontrolled dependency'):
            build.validate_dependencies(self.root)
        matrix.write_text('[dependencies]\nexternal = { path = "../../../external" }\n')
        with self.assertRaisesRegex(ValueError, 'escapes source snapshot'):
            build.validate_dependencies(self.root)

    def test_game_dependency_is_included_and_checked_recursively(self):
        matrix = self.root / 'examples/visual_matrix/cjpm.toml'
        game = self.root / 'packages/game/cjpm.toml'
        matrix.write_text('[dependencies]\ngame = { path = "../../packages/game" }\n')
        game.write_text('[dependencies]\ncore = { path = "../core" }\n')
        build.validate_dependencies(self.root)
        game.write_text('[dependencies]\nunknown = { git = "https://example.test/dependency" }\n')
        with self.assertRaisesRegex(ValueError, 'uncontrolled dependency'):
            build.validate_dependencies(self.root)

    def test_input_symlink_rejected(self):
        src = self.root / 'packages/core/src'
        src.mkdir()
        (src / 'link').symlink_to(self.root / 'packages/core/cjpm.toml')
        with self.assertRaisesRegex(ValueError, 'symlinked'):
            build.walk(self.root / 'packages/core', 'packages/core')

    def test_tool_change_is_rejected(self):
        tool = self.root / 'tool'
        tool.write_bytes(b'original')
        paths = {'cc': tool}
        expected = {'cc': build.sha_file(tool)}
        build.verify_tool_identity(paths, expected)
        tool.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'changed during build'):
            build.verify_tool_identity(paths, expected)

    def test_native_archive_change_is_rejected(self):
        archive = self.root / 'libtermcanvas_posix.a'
        archive.write_bytes(b'original')
        expected = build.sha_file(archive)
        build.verify_native_archive(archive, expected)
        archive.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'native archive changed'):
            build.verify_native_archive(archive, expected)

    def test_source_tar_metadata_is_sanitized(self):
        info = tarfile.TarInfo('source.cj')
        info.uid, info.gid, info.uname, info.gname, info.mtime = 123, 456, 'private', 'private', 12345
        result = build.sanitize_tar_info(info)
        self.assertEqual((result.uid, result.gid, result.uname, result.gname, result.mtime), (0, 0, '', '', 0))


if __name__ == '__main__':
    unittest.main()
