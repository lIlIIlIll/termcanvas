#!/usr/bin/env python3
"""Behavioral checks for the declared-scope visual evidence audit."""
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import tarfile
import unittest
import zlib

import visual_evidence as visual


def png(width=120, height=36):
    def chunk(kind, payload):
        return (struct.pack('>I', len(payload)) + kind + payload +
                struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff))
    rows = b''.join(b'\0' + b'\0\0\0' * width for _ in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def complete_local_files(files):
    required = ('packages/core/cjpm.toml', 'packages/core/native/build.sh', 'packages/core/native/spawn.c',
                'packages/core/src/app.cj', 'packages/diff/src/diff.cj', 'packages/media/src/media.cj',
                'packages/terminal/src/terminal.cj', 'packages/markdown_adapter/src/markdown.cj',
                'packages/diff/cjpm.toml', 'packages/game/cjpm.toml', 'packages/game/src/game.cj',
                'packages/media/cjpm.toml', 'packages/terminal/cjpm.toml',
                'packages/markdown_adapter/cjpm.toml', 'examples/visual_matrix/cjpm.toml',
                'examples/visual_matrix/src/main.cj', 'examples/visual_matrix/sample/demo.txt',
                'scripts/visual_capture.py', 'scripts/visual_matrix_runner.py', 'scripts/visual_matrix_build.py',
                'scripts/native_sdk.py', 'scripts/visual_evidence.py', 'scripts/visual_inventory.py',
                'scripts/visual_inventory.json', 'vendor/markdown/cjpm.toml', 'vendor/markdown/src/main.cj')
    for name in required:
        files.setdefault(name, b'fixture')
    files['packages/markdown_adapter/cjpm.toml'] = ('[dependencies]\n' + visual.MARKDOWN_OLD + '\n').encode()
    return files


def complete_local_record(record, hashes):
    record['toolchain'] = {key + '_sha256': 'a' * 64 for key in ('cjc', 'cjpm', 'runtime', 'cc', 'ar')}
    record['toolchain'].update(cjc_version='1.2', cjpm_version='1.2')
    record['native_archive_sha256'] = 'b' * 64
    record['dependency_rewrite'] = {'path': 'packages/markdown_adapter/cjpm.toml',
        'before_sha256': hashes['packages/markdown_adapter/cjpm.toml'],
        'after_sha256': visual.digest(('[dependencies]\n' + visual.MARKDOWN_NEW + '\n').encode()),
        'markdown_source': 'vendor/markdown', 'commit_or_tag_verified': False}
    record['limitations'] = ['unsigned']
    return record


class VisualEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='visual-evidence-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.inventory = {'themes': ['dark'], 'subjects': [{'id': 'button', 'kind': 'widget',
                         'states': ['normal', 'focused+selected'], 'widget_sizes': [[0, 1], [8, 1]],
                         'high_risk': True}]}
        self.matrix = visual.matrix_from_inventory(self.inventory)
        data = png(160, 45)
        (self.root / 'screen.png').write_bytes(data)
        image_hash = hashlib.sha256(data).hexdigest()
        (self.root / 'fixture.bin').write_bytes(b'visual fixture')
        binary_hash = hashlib.sha256(b'visual fixture').hexdigest()
        (self.root / 'renderer.bin').write_bytes(b'actual renderer')
        renderer_hash = hashlib.sha256(b'actual renderer').hexdigest()
        (self.root / 'source.tar').write_bytes(b'source archive')
        archive_hash = hashlib.sha256(b'source archive').hexdigest()
        self.evidence = {'source_sha': 'a' * 40, 'source_archive': {'file': 'source.tar', 'sha256': archive_hash},
                         'binaries': {binary_hash: 'fixture.bin', renderer_hash: 'renderer.bin'}, 'captures': [], 'reviews': []}
        for case in self.matrix['cases']:
            self.evidence['captures'].append({'case_id': case['id'], 'image': 'screen.png', 'sha256': image_hash,
                'source_sha': 'a' * 40, 'source_archive_sha256': archive_hash, 'binary_sha256': binary_hash, 'renderer_sha256': renderer_hash, 'backend': 'real-terminal',
                'platform': 'Linux', 'terminal': 'foot', 'terminal_version': '1', 'compositor': 'sway',
                'font': 'Mono', 'font_version': '1', 'actual_color': 'truecolor', 'actual_glyphs': 'unicode',
                'app_color': case['color'], 'app_glyphs': case['glyph'], 'cells': case['terminal_cells'],
                'geometry_evidence': visual.GEOMETRY_SOURCE,
                'app_report': {'case_id': case['id'], 'renderer_sha256': renderer_hash, 'cells': case['terminal_cells'],
                    'renderer_geometry': visual.validate_case_geometry(case), 'applied':
                    {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}}})
            for kind in ('model', 'independent'):
                self.evidence['reviews'].append({'case_id': case['id'], 'kind': kind, 'image_sha256': image_hash,
                                                 'reviewer': kind, 'verdict': 'pass', 'findings': [], 'source_sha': 'a' * 40,
                                                 'report_file': 'review.json', 'report_sha256': ''})
        entries = [{key: review[key] for key in ('case_id', 'kind', 'image_sha256', 'source_sha',
                                                  'reviewer', 'verdict', 'findings')}
                   for review in self.evidence['reviews']]
        report = json.dumps({'reviews': entries}).encode()
        (self.root / 'review.json').write_bytes(report)
        for review in self.evidence['reviews']:
            review['report_sha256'] = hashlib.sha256(report).hexdigest()

    def test_matrix_expands_cross_product_including_boundaries(self):
        self.assertEqual(len(self.matrix['cases']), 2 * 2 * 1 * 3 * 4 * 3)
        self.assertEqual(len({c['id'] for c in self.matrix['cases']}), len(self.matrix['cases']))
        self.assertEqual(visual.audit(self.matrix, self.evidence, self.root)['scope'], 'declared-inventory-only')

    def test_geometry_targets_and_legacy_case_identity(self):
        subject = {'id': 'tree', 'kind': 'widget', 'states': ['width-42'], 'high_risk': False,
                   'widget_sizes': [[40, 10], [42, 3], [42, 0]], 'state_target_widths': {'width-42': 42}}
        inventory = {'themes': ['dark'], 'subjects': [subject]}
        matrix = visual.matrix_from_inventory(inventory)
        cases = matrix['cases']
        small = next(c for c in cases if c['allocation_cells'] == [40, 10])
        enough = next(c for c in cases if c['allocation_cells'] == [42, 3])
        zero = next(c for c in cases if c['allocation_cells'] == [42, 0])
        self.assertEqual(small['expected_effective_rect'], [2, 4, 40, 10])
        self.assertIs(small['target_width_satisfied'], False)
        self.assertIs(enough['target_width_satisfied'], True)
        self.assertIs(zero['target_width_satisfied'], False)
        self.assertEqual(visual.target_coverage([small, enough], {small['id']})['target_width_coverage'], 'partial')
        self.assertEqual(visual.target_coverage([small, enough], {enough['id']})['target_width_coverage'], 'complete')
        legacy = visual.matrix_from_inventory(inventory, version=1)['cases'][0]
        self.assertNotIn('case_schema_version', legacy)
        self.assertEqual(legacy['id'], visual.digest(visual.canonical({k: v for k, v in legacy.items() if k != 'id'})))
        input_subject = {'states': ['normal'], 'max_effective_height': 1}
        self.assertEqual(visual.case_geometry(input_subject, 'normal', [40, 10], [80, 24])['expected_effective_rect'], [2, 4, 40, 1])
        self.assertEqual(visual.case_geometry(input_subject, 'normal', [40, 0], [80, 24])['expected_effective_rect'], [2, 4, 40, 0])

    def test_legacy_matrix_audits_as_geometry_unverified(self):
        legacy = visual.matrix_from_inventory(self.inventory, version=1)
        mapping = {new['id']: old['id'] for new, old in zip(self.matrix['cases'], legacy['cases'])}
        for capture in self.evidence['captures']:
            capture['case_id'] = mapping[capture['case_id']]
            capture['app_report']['case_id'] = capture['case_id']
            capture.pop('geometry_evidence')
            capture['app_report'].pop('renderer_geometry')
        for review in self.evidence['reviews']:
            review['case_id'] = mapping[review['case_id']]
        entries = [{key: review[key] for key in visual.LEGACY_REVIEW_KEYS} for review in self.evidence['reviews']]
        report = json.dumps({'reviews': entries}).encode()
        (self.root / 'review.json').write_bytes(report)
        for review in self.evidence['reviews']:
            review['report_sha256'] = visual.digest(report)
        self.assertEqual(visual.audit(legacy, self.evidence, self.root)['geometry_check'], 'legacy-unverified')

    def test_geometry_missing_or_forged_is_rejected(self):
        capture = self.evidence['captures'][0]
        geometry = capture['app_report'].pop('renderer_geometry')
        with self.assertRaisesRegex(ValueError, 'renderer geometry mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['app_report']['renderer_geometry'] = dict(geometry, effective_rect=[2, 4, 99, 1])
        with self.assertRaisesRegex(ValueError, 'renderer geometry mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        case = dict(self.matrix['cases'][0], target_width_satisfied=True)
        with self.assertRaisesRegex(ValueError, 'target width satisfaction'):
            visual.validate_case_geometry(case)

    def test_missing_capture_and_review_fail(self):
        self.evidence['captures'].pop()
        with self.assertRaisesRegex(ValueError, 'missing captures'):
            visual.audit(self.matrix, self.evidence, self.root)
        self.setUp()
        self.evidence['reviews'].pop()
        with self.assertRaisesRegex(ValueError, 'missing independent review'):
            visual.audit(self.matrix, self.evidence, self.root)

    def test_provenance_override_and_review_mismatches_fail(self):
        capture = self.evidence['captures'][0]
        capture['source_sha'] = 'c' * 40
        with self.assertRaisesRegex(ValueError, 'provenance mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['source_sha'] = 'a' * 40
        capture['app_color'] = 'not-the-case'
        with self.assertRaisesRegex(ValueError, 'override mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['app_color'] = self.matrix['cases'][0]['color']
        self.evidence['reviews'][0]['findings'] = ['unresolved']
        with self.assertRaisesRegex(ValueError, 'report does not contain review'):
            visual.audit(self.matrix, self.evidence, self.root)

    def test_launcher_and_renderer_are_separately_bound(self):
        capture = self.evidence['captures'][0]
        capture['renderer_sha256'] = 'f' * 64
        with self.assertRaisesRegex(ValueError, 'provenance mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        renderer_hash = self.evidence['binaries']
        capture['renderer_sha256'] = next(key for key, value in renderer_hash.items() if value == 'renderer.bin')
        capture['app_report']['renderer_sha256'] = 'f' * 64
        with self.assertRaisesRegex(ValueError, 'application did not attest'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['app_report']['renderer_sha256'] = capture['renderer_sha256']
        (self.root / 'renderer.bin').write_bytes(b'different renderer')
        with self.assertRaisesRegex(ValueError, 'binary hash mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)

    def test_local_build_record_missing_or_tampered_is_rejected(self):
        launcher_hash = hashlib.sha256(b'visual fixture').hexdigest()
        renderer_hash = hashlib.sha256(b'actual renderer').hexdigest()
        files = complete_local_files({'examples/visual_matrix/launch.py': b'visual fixture'})
        files['scripts/visual_inventory.json'] = json.dumps(self.inventory).encode()
        hashes = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
        source = visual.digest(visual.canonical(hashes))
        files['snapshot-manifest.json'] = json.dumps({'files': hashes, 'source_snapshot_sha256': source}).encode()
        with tarfile.open(self.root / 'source.tar', 'w') as tar:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        archive_sha = visual.digest((self.root / 'source.tar').read_bytes())
        record = complete_local_record({'kind': 'local-build-record-not-attestation', 'source_revision_verified': False,
                  'build_source_link_independently_verified': False, 'source_snapshot_sha256': source,
                  'source_archive_sha256': archive_sha, 'launcher_sha256': launcher_hash,
                  'renderer_sha256': renderer_hash}, hashes)
        path = self.root / 'build-record.json'
        path.write_text(json.dumps(record))
        record_sha = visual.digest(path.read_bytes())
        self.evidence['source_sha'] = source
        self.evidence['source_archive']['sha256'] = archive_sha
        self.evidence.update(source_kind='dirty-worktree', source_revision_verified=False,
                             build_source_link_verified=False)
        self.evidence['local_build_record'] = {'file': 'build-record.json', 'sha256': record_sha,
                                               'independently_verified': False}
        facts = {'font': 'Mono', 'font_version': '1',
                 'foot_config': {'source': '/dev/null', 'xdg_config_roots': 'isolated empty directories'},
                 'fontconfig_candidate': {'request': 'Mono', 'sha256': 'a' * 64,
                    'scope': 'fc-match candidate; actual glyph fonts and fallback unverified'},
                 'locale': {'LC_ALL': None, 'LC_CTYPE': None, 'LANG': 'C', 'LANGUAGE': None, 'charmap': 'UTF-8'}}
        identity = {'version': 2, 'matrix_schema_version': 2, 'run_nonce': 'b' * 64, 'source_revision_declared': source, 'source_kind': 'dirty-worktree',
                    'revision_verified': False, 'build_source_link_verified': False,
                    'source_archive_sha256': archive_sha, 'launcher_sha256': launcher_hash,
                    'renderer_sha256': renderer_hash, 'local_build_record_sha256': record_sha,
                    'inventory_sha256': visual.digest(visual.canonical(self.inventory)),
                    'font': 'Mono', 'settle_seconds': 0.3,
                    'terminal_configuration': facts, 'terminal_tool_versions': {'foot': '1', 'sway': 'sway'},
                    'terminal_tools_sha256': {name: 'a' * 64 for name in
                       ('foot', 'sway', 'swaymsg', 'grim', 'fc-match', 'locale', 'python')}}
        run_id = visual.digest(visual.canonical(identity))
        run_path = self.root / 'run.json'
        run_path.write_text(json.dumps({'identity': identity, 'identity_sha256': run_id}))
        self.evidence['run_identity'] = {'file': 'run.json', 'sha256': visual.digest(run_path.read_bytes()),
                                         'identity_sha256': run_id}
        for capture in self.evidence['captures']:
            capture.update(source_sha=source, source_archive_sha256=archive_sha,
                           local_build_record_sha256=record_sha, source_kind='dirty-worktree',
                           source_revision_verified=False, build_source_link_verified=False,
                           run_identity_sha256=run_id, compositor='sway headless pixman', actual_glyphs='unknown',
                           capability_scope='application override; restricted terminal and glyph support unverified',
                           capture_parameters={'font_request': 'Mono', 'settle_seconds': 0.3, 'arguments': []}, **facts)
        for review in self.evidence['reviews']:
            review['source_sha'] = source
            review['run_identity_sha256'] = run_id
        entries = [{key: review[key] for key in ('case_id', 'kind', 'image_sha256', 'source_sha',
                                                 'reviewer', 'verdict', 'findings', 'run_identity_sha256')}
                   for review in self.evidence['reviews']]
        report = json.dumps({'reviews': entries}).encode()
        (self.root / 'review.json').write_bytes(report)
        for review in self.evidence['reviews']:
            review['report_sha256'] = visual.digest(report)
        self.assertEqual(visual.audit(self.matrix, self.evidence, self.root, require_local_build_record=True)
                         ['local_build_record_check'], 'local-consistency-only')
        capture = self.evidence['captures'][0]
        for field, replacement in (('terminal_version', 'different-version'), ('compositor', 'different-compositor'),
                                   ('foot_config', {'source': 'user-config'}),
                                   ('locale', dict(facts['locale'], charmap='ASCII')),
                                   ('fontconfig_candidate', dict(facts['fontconfig_candidate'], sha256='f' * 64))):
            original = capture[field]
            capture[field] = replacement
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'capture run identity or terminal'):
                visual.audit(self.matrix, self.evidence, self.root, require_local_build_record=True)
            capture[field] = original
        review = self.evidence['reviews'][0]
        review['run_identity_sha256'] = 'f' * 64
        with self.assertRaisesRegex(ValueError, 'review run identity mismatch'):
            visual.audit(self.matrix, self.evidence, self.root, require_local_build_record=True)
        review['run_identity_sha256'] = run_id
        saved_run = run_path.read_bytes()
        run_path.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'run identity artifact hash mismatch'):
            visual.audit(self.matrix, self.evidence, self.root, require_local_build_record=True)
        run_path.write_bytes(saved_run)
        different_matrix = json.loads(json.dumps(self.matrix))
        different_matrix['cases'].pop()
        with self.assertRaisesRegex(ValueError, 'matrix differs from archived visual inventory'):
            visual.audit(different_matrix, self.evidence, self.root, require_local_build_record=True)
        with self.assertRaisesRegex(ValueError, 'matrix differs from archived visual inventory'):
            visual.audit(different_matrix, self.evidence, self.root)
        self.evidence['source_revision_verified'] = True
        with self.assertRaisesRegex(ValueError, 'evidence provenance flags mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        self.evidence['source_revision_verified'] = False
        self.evidence['captures'][0]['build_source_link_verified'] = True
        with self.assertRaisesRegex(ValueError, 'capture local build provenance flags mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        self.evidence['captures'][0]['build_source_link_verified'] = False
        third = b'third renderer'
        third_hash = visual.digest(third)
        (self.root / 'third.bin').write_bytes(third)
        self.evidence['binaries'][third_hash] = 'third.bin'
        self.evidence['captures'][0]['renderer_sha256'] = third_hash
        with self.assertRaisesRegex(ValueError, 'capture local build binary mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        self.evidence['captures'][0]['renderer_sha256'] = renderer_hash
        incomplete = dict(record)
        incomplete.pop('native_archive_sha256')
        path.write_text(json.dumps(incomplete))
        bad_hash = visual.digest(path.read_bytes())
        self.evidence['local_build_record']['sha256'] = bad_hash
        with self.assertRaisesRegex(ValueError, 'incomplete local build tool record'):
            visual.audit(self.matrix, self.evidence, self.root)
        wrong_rewrite = json.loads(json.dumps(record))
        wrong_rewrite['dependency_rewrite']['after_sha256'] = 'd' * 64
        path.write_text(json.dumps(wrong_rewrite))
        self.evidence['local_build_record']['sha256'] = visual.digest(path.read_bytes())
        with self.assertRaisesRegex(ValueError, 'dependency rewrite hash mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        path.write_text(json.dumps(record))
        self.evidence['local_build_record']['sha256'] = record_sha
        self.evidence['local_build_record']['sha256'] = 'f' * 64
        with self.assertRaisesRegex(ValueError, 'local build record hash mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        self.evidence['local_build_record']['sha256'] = record_sha
        path.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'local build record hash mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        path.unlink()
        with self.assertRaises((OSError, ValueError)):
            visual.audit(self.matrix, self.evidence, self.root)
        self.evidence.pop('local_build_record')
        with self.assertRaisesRegex(ValueError, 'capture local build record mismatch'):
            visual.audit(self.matrix, self.evidence, self.root)
        for capture in self.evidence['captures']:
            capture.pop('local_build_record_sha256')
        with self.assertRaisesRegex(ValueError, 'local build record required'):
            visual.audit(self.matrix, self.evidence, self.root, require_local_build_record=True)

    def test_fake_backend_corrupt_png_and_escaping_path_fail(self):
        capture = self.evidence['captures'][0]
        capture['backend'] = 'buffer'
        with self.assertRaisesRegex(ValueError, 'real-terminal'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['backend'] = 'real-terminal'
        (self.root / 'screen.png').write_bytes(b'not a png')
        with self.assertRaisesRegex(ValueError, 'not a PNG'):
            visual.audit(self.matrix, self.evidence, self.root)
        capture['image'] = '../escape.png'
        # A missing path also fails closed before it can be considered an artifact.
        with self.assertRaises((OSError, ValueError)):
            visual.audit(self.matrix, self.evidence, self.root)

    def test_local_archive_missing_package_source_is_rejected(self):
        files = complete_local_files({'examples/visual_matrix/launch.py': b'visual fixture'})
        files.pop('packages/media/src/media.cj')
        hashes = {name: visual.digest(data) for name, data in files.items()}
        source = visual.digest(visual.canonical(hashes))
        files['snapshot-manifest.json'] = json.dumps({'files': hashes, 'source_snapshot_sha256': source}).encode()
        archive = self.root / 'incomplete.tar'
        with tarfile.open(archive, 'w') as tar:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        launcher = visual.digest(b'visual fixture')
        renderer = visual.digest(b'actual renderer')
        record = complete_local_record({'kind': 'local-build-record-not-attestation',
            'source_revision_verified': False, 'build_source_link_independently_verified': False,
            'source_snapshot_sha256': source, 'source_archive_sha256': visual.digest(archive.read_bytes()),
            'launcher_sha256': launcher, 'renderer_sha256': renderer}, hashes)
        record_path = self.root / 'incomplete-record.json'
        record_path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'source archive inventory or manifest mismatch'):
            visual.verify_local_build_record(record_path, archive, source, {launcher, renderer})

    def test_local_archive_missing_game_source_is_rejected(self):
        files = complete_local_files({'examples/visual_matrix/launch.py': b'visual fixture'})
        files.pop('packages/game/src/game.cj')
        hashes = {name: visual.digest(data) for name, data in files.items()}
        source = visual.digest(visual.canonical(hashes))
        files['snapshot-manifest.json'] = json.dumps({'files': hashes, 'source_snapshot_sha256': source}).encode()
        archive = self.root / 'incomplete-game.tar'
        with tarfile.open(archive, 'w') as tar:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        launcher, renderer = visual.digest(b'visual fixture'), visual.digest(b'actual renderer')
        record = complete_local_record({'kind': 'local-build-record-not-attestation',
            'source_revision_verified': False, 'build_source_link_independently_verified': False,
            'source_snapshot_sha256': source, 'source_archive_sha256': visual.digest(archive.read_bytes()),
            'launcher_sha256': launcher, 'renderer_sha256': renderer}, hashes)
        record_path = self.root / 'incomplete-game-record.json'
        record_path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'source archive inventory or manifest mismatch'):
            visual.verify_local_build_record(record_path, archive, source, {launcher, renderer})

    def test_local_archive_with_unsanitized_metadata_is_rejected(self):
        files = complete_local_files({'examples/visual_matrix/launch.py': b'visual fixture'})
        hashes = {name: visual.digest(data) for name, data in files.items()}
        source = visual.digest(visual.canonical(hashes))
        files['snapshot-manifest.json'] = json.dumps({'files': hashes, 'source_snapshot_sha256': source}).encode()
        archive = self.root / 'unsanitized.tar'
        with tarfile.open(archive, 'w') as tar:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                info.uname = 'private' if name == 'snapshot-manifest.json' else ''
                tar.addfile(info, io.BytesIO(data))
        launcher, renderer = visual.digest(b'visual fixture'), visual.digest(b'actual renderer')
        record = complete_local_record({'kind': 'local-build-record-not-attestation',
            'source_revision_verified': False, 'build_source_link_independently_verified': False,
            'source_snapshot_sha256': source, 'source_archive_sha256': visual.digest(archive.read_bytes()),
            'launcher_sha256': launcher, 'renderer_sha256': renderer}, hashes)
        record_path = self.root / 'unsanitized-record.json'
        record_path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'unsanitized metadata'):
            visual.verify_local_build_record(record_path, archive, source, {launcher, renderer})

    def test_cli_rejects_project_wide_and_matrix_tampering(self):
        inventory, matrix, evidence = (self.root / x for x in ('inventory.json', 'matrix.json', 'evidence.json'))
        inventory.write_text(json.dumps(self.inventory))
        matrix.write_text(json.dumps(self.matrix))
        evidence.write_text(json.dumps(self.evidence))
        command = [sys.executable, str(Path(visual.__file__)), 'check', str(inventory), str(matrix),
                   str(evidence), str(self.root)]
        project = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(project.returncode, 1)
        self.assertFalse(json.loads(project.stdout)['project_coverage_verified'])
        scoped = subprocess.run(command + ['--declared-scope'], capture_output=True, text=True, check=False)
        self.assertEqual(scoped.returncode, 1)
        self.assertIn('run identity, renderer geometry or target-width coverage is unverified', scoped.stdout)
        self.matrix['cases'].pop()
        matrix.write_text(json.dumps(self.matrix))
        tampered = subprocess.run(command + ['--declared-scope'], capture_output=True, text=True, check=False)
        self.assertEqual(tampered.returncode, 1)
        self.assertIn('matrix does not match', tampered.stderr)


if __name__ == '__main__':
    unittest.main()
