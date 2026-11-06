#!/usr/bin/env python3
"""Verify bounded, resumable capture bookkeeping without running a matrix."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import visual_matrix_runner as runner
import visual_evidence as visual
from test_visual_evidence import png, complete_local_files, complete_local_record


class MatrixRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='visual-runner-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture = self.root / 'fixture'
        (fixture / 'scripts').mkdir(parents=True)
        (fixture / 'examples/visual_matrix/sample').mkdir(parents=True)
        self.launcher = fixture / 'examples/visual_matrix/launch.py'
        self.launcher.write_text('launcher')
        (fixture / 'scripts/visual_inventory.py').write_text('inventory code')
        (fixture / 'scripts/visual_evidence.py').write_text('evidence code')
        (fixture / 'examples/visual_matrix/sample/example.txt').write_text('sample')
        self.inventory = {'themes': ['dark'], 'subjects': [{'id': 'core.Button', 'kind': 'widget',
                          'states': ['normal'], 'widget_sizes': [[1, 1]], 'high_risk': True}]}
        self.inventory_path = fixture / 'scripts/visual_inventory.json'
        self.inventory_path.write_text(json.dumps(self.inventory))
        self.renderer = self.root / 'renderer'
        self.renderer.write_bytes(b'renderer')
        self.archive = self.root / 'archive.tar'
        self.archive.write_bytes(b'dirty source archive')
        self.args = argparse.Namespace(inventory=self.inventory_path, launcher=self.launcher, renderer=self.renderer,
            source_archive=self.archive, source_revision='a' * 40, source_kind='dirty-worktree',
            output=self.root / 'output', limit=1, all=False, subject=['core.Button'], state=[], theme=[],
            glyph=[], color=[], terminal=[], widget_size=[], retry_failed=False, font='monospace:size=14',
            runtime_base=None, timeout=15, settle=0.3)
        self.tools = patch.object(runner, 'tool_identity', return_value={name: 'a' * 64 for name in
                                  ('foot', 'sway', 'swaymsg', 'grim', 'fc-match', 'locale', 'python')})
        self.tools.start()
        self.addCleanup(self.tools.stop)
        self.versions_patch = patch.object(runner, 'tool_versions', return_value={'foot': '1', 'sway': 'sway'})
        self.versions_patch.start()
        self.addCleanup(self.versions_patch.stop)
        self.facts = {'font': 'mono', 'font_version': '1',
                      'foot_config': {'source': '/dev/null', 'xdg_config_roots': 'isolated empty directories'},
                      'fontconfig_candidate': {'request': 'monospace:size=14', 'sha256': 'a' * 64,
                                               'scope': 'fc-match candidate; actual glyph fonts and fallback unverified'},
                      'locale': {'LC_ALL': None, 'LC_CTYPE': None, 'LANG': 'C', 'LANGUAGE': None, 'charmap': 'UTF-8'}}
        self.facts_patch = patch.object(runner, 'terminal_configuration', return_value=self.facts)
        self.facts_patch.start()
        self.addCleanup(self.facts_patch.stop)

    def captured(self, case, case_dir, args, run_id, current):
        directory = case_dir / 'attempt-000001'
        directory.mkdir(parents=True)
        runner.write_json(directory / 'case.json', case)
        data = png(160, 45)
        (directory / 'capture.png').write_bytes(data)
        identity = current['identity']
        applied = {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        meta = {'case_id': case['id'], 'sha256': hashlib.sha256(data).hexdigest(),
                'run_identity_sha256': run_id, 'source_kind': args.source_kind,
                'source_revision_verified': False, 'build_source_link_verified': False,
                'source_sha': args.source_revision, 'source_archive_sha256': identity['source_archive_sha256'],
                'binary_sha256': identity['launcher_sha256'], 'renderer_sha256': identity['renderer_sha256'],
                'backend': 'real-terminal', 'platform': 'Linux', 'cells': case['terminal_cells'],
                'terminal': 'foot', 'terminal_version': '1', 'compositor': 'sway headless pixman', 'font': 'mono',
                'font_version': '1', 'actual_color': 'truecolor', 'actual_glyphs': 'unknown',
                'capability_scope': 'application override; restricted terminal and glyph support unverified',
                'capture_parameters': {'font_request': args.font, 'settle_seconds': args.settle, 'arguments': []},
                'app_color': case['color'], 'app_glyphs': case['glyph'], 'geometry_evidence': visual.GEOMETRY_SOURCE,
                'app_report': {'case_id': case['id'], 'cells': case['terminal_cells'], 'applied': applied,
                               'renderer_sha256': identity['renderer_sha256'], 'renderer_geometry': visual.validate_case_geometry(case)}}
        meta.update(self.facts)
        runner.write_json(directory / 'capture.json', meta)
        status = {'state': 'captured', 'attempt': 1, 'run_identity_sha256': run_id, 'review_status': 'not_run',
                  'cleanup_confirmation_required': False}
        runner.write_json(case_dir / 'status.json', status)
        return status

    def test_bounded_run_resume_and_changed_source_rejected(self):
        with patch.object(runner, 'capture', side_effect=self.captured) as capture:
            first = runner.execute(self.args)
            self.assertEqual(first['total_declared_cases'], 36)
            self.assertEqual(first['captured_cases'], 1)
            self.assertEqual(first['capture_status'], 'partial')
            self.assertFalse(first['project_coverage_verified'])
            self.assertEqual(first['model_review'], 'not_run')
            self.assertEqual(first['independent_review'], 'not_run')
            second = runner.execute(self.args)
            self.assertEqual(second['captured_cases'], 2)
            self.assertEqual(capture.call_count, 2)
        evidence = json.loads((self.args.output / 'evidence.json').read_text())
        self.assertEqual(evidence['reviews'], [])
        self.assertEqual(evidence['source_kind'], 'dirty-worktree')
        self.assertFalse(evidence['source_revision_verified'])
        self.archive.write_bytes(b'changed source')
        with self.assertRaisesRegex(ValueError, 'run inputs changed'):
            runner.execute(self.args)

    def test_capture_checks_bound_inputs_without_losing_nonce(self):
        case = visual.matrix_from_inventory(self.inventory)['cases'][0]
        identity = {**runner.identity(self.args, self.inventory), 'run_nonce': 'a' * 64}
        run_id = visual.digest(visual.canonical(identity))
        def fake_process(cmd, env, log, timeout):
            Path(cmd[cmd.index('--metadata') + 1]).write_text('{}')
            return 0
        with patch.object(runner, 'run_capture_process', side_effect=fake_process), \
             patch.object(runner, 'valid_capture', return_value={'case_id': case['id']}):
            result = runner.capture(case, self.root / 'case-dir', self.args, run_id,
                                    {'identity': identity, 'inventory': self.inventory})
        self.assertEqual(result['state'], 'captured')
        self.assertFalse(result['cleanup_confirmation_required'])
        meta = json.loads((self.root / 'case-dir/attempt-000001/capture.json').read_text())
        self.assertEqual(meta['run_identity_sha256'], run_id)

    def test_independent_runs_cannot_share_review_records(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
            first_root = self.args.output
            first_evidence = json.loads((first_root / 'evidence.json').read_text())
            self.args.output = self.root / 'second-output'
            second = runner.execute(self.args)
        self.assertNotEqual(first['run_identity_sha256'], second['run_identity_sha256'])
        second_evidence = json.loads((self.args.output / 'evidence.json').read_text())
        capture = first_evidence['captures'][0]
        self.assertEqual(capture['sha256'], second_evidence['captures'][0]['sha256'])
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': first_evidence['source_sha'], 'reviewer': 'reviewer-a', 'verdict': 'pass',
                 'findings': [], 'run_identity_sha256': first_evidence['run_identity']['identity_sha256']}
        with self.assertRaisesRegex(ValueError, 'does not match current capture'):
            visual.update_reviews(self.args.output, {'reviews': [entry]})

    def test_resume_rejects_tampered_renderer_geometry(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        evidence = json.loads((self.args.output / 'evidence.json').read_text())
        case_id = evidence['captures'][0]['case_id']
        case = next(c for c in visual.matrix_from_inventory(self.inventory)['cases'] if c['id'] == case_id)
        run = json.loads((self.args.output / 'run.json').read_text())
        expected = dict(run['identity'], identity_sha256=run['identity_sha256'])
        case_dir = self.args.output / 'cases' / case_id
        self.assertIsNotNone(runner.valid_capture(case, case_dir, expected))
        meta_path = case_dir / 'attempt-000001' / 'capture.json'
        meta = json.loads(meta_path.read_text())
        meta['app_report']['renderer_geometry']['effective_rect'][2] += 1
        runner.write_json(meta_path, meta)
        self.assertIsNone(runner.valid_capture(case, case_dir, expected))

    def test_review_records_survive_incremental_capture_and_reject_conflict(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
        evidence = json.loads((self.args.output / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'reviewer-a', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        imported = visual.update_reviews(self.args.output, {'reviews': [entry]})
        self.assertFalse(imported['identity_and_image_observation_verified'])
        stored = self.args.output / imported['report_file']
        self.assertTrue(stored.is_file())
        self.assertEqual(visual.update_reviews(self.args.output, {'reviews': [entry]})['report_sha256'],
                         imported['report_sha256'])
        different = dict(entry, reviewer='reviewer-b')
        with self.assertRaisesRegex(ValueError, 'conflicting current review records'):
            visual.update_reviews(self.args.output, {'reviews': [different]})
        stale = dict(entry, image_sha256='f' * 64)
        with self.assertRaisesRegex(ValueError, 'does not match current capture'):
            visual.update_reviews(self.args.output, {'reviews': [stale]})
        other_run = dict(entry, run_identity_sha256='f' * 64)
        with self.assertRaisesRegex(ValueError, 'does not match current capture'):
            visual.update_reviews(self.args.output, {'reviews': [other_run]})
        independent = dict(entry, kind='independent', reviewer='reviewer-b')
        visual.update_reviews(self.args.output, {'reviews': [independent]})
        one_case = visual.matrix_from_inventory(self.inventory)
        one_case['cases'] = [case for case in one_case['cases'] if case['id'] == entry['case_id']]
        self.assertEqual(visual.audit(one_case, json.loads((self.args.output / 'evidence.json').read_text()),
                                      self.args.output)['reviews'], 2)
        with patch.object(runner, 'capture', side_effect=self.captured):
            second = runner.execute(self.args)
        self.assertEqual(second['captured_cases'], 2)
        self.assertEqual(second['current_review_records'], 2)
        self.assertEqual(second['model_review'], 'records_present_unverified')
        merged = json.loads((self.args.output / 'evidence.json').read_text())
        self.assertEqual(merged['reviews'][0]['case_id'], first['results'][0]['case_id'])
        self.assertTrue(stored.is_file())
        # A changed screenshot invalidates the capture and the immutable review
        # becomes stale, never a review of the replacement image.
        image = self.args.output / capture['image']
        image.write_bytes(png(161, 45))
        self.args.subject = ['missing']
        with patch.object(runner, 'capture'):
            third = runner.execute(self.args)
        self.assertEqual(third['stale_review_records'], 2)
        self.assertEqual(third['current_review_records'], 0)
        self.assertTrue(stored.is_file())

    def resolution_fixture(self, model_findings=None, independent_verdict='pass', same_reviewer=False):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
        root = self.args.output
        evidence = json.loads((root / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        model = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'model-a', 'verdict': 'fail',
                 'findings': ['first concern', 'second concern'] if model_findings is None else model_findings,
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        independent = dict(model, kind='independent', reviewer='model-a' if same_reviewer else 'reviewer-b',
                           verdict=independent_verdict,
                           findings=[] if independent_verdict == 'pass' else ['confirmed problem'])
        visual.update_reviews(root, {'reviews': [model, independent]})
        evidence = json.loads((root / 'evidence.json').read_text())
        reviews = {r['kind']: r for r in evidence['reviews']}
        entry = {'case_id': model['case_id'], 'image_sha256': model['image_sha256'],
                 'source_sha': model['source_sha'], 'run_identity_sha256': model['run_identity_sha256'],
                 'decision': 'false_positive', 'reviewer': independent['reviewer'],
                 'model_report_sha256': reviews['model']['report_sha256'],
                 'model_entry_sha256': visual.review_entry_sha256(reviews['model']),
                 'independent_report_sha256': reviews['independent']['report_sha256'],
                 'independent_entry_sha256': visual.review_entry_sha256(reviews['independent']),
                 'findings': [{'index': i, 'sha256': visual.digest(f.encode('utf-8')),
                               'reason': 'The complete image shows the reported clipping does not occur.'}
                              for i, f in enumerate(model['findings'])]}
        matrix = visual.matrix_from_inventory(self.inventory)
        matrix['cases'] = [case for case in matrix['cases'] if case['id'] == capture['case_id']]
        return root, matrix, entry, first

    def test_false_positive_resolution_preserves_model_fail_and_survives_resume(self):
        root, matrix, entry, _ = self.resolution_fixture()
        evidence_path = root / 'evidence.json'
        evidence = json.loads(evidence_path.read_text())
        original_reviews = evidence['reviews']
        with self.assertRaisesRegex(ValueError, 'review not clear'):
            visual.audit(matrix, evidence, root)
        with patch.object(visual, 'read_png', wraps=visual.read_png) as read:
            saved = visual.update_resolutions(root, {'resolutions': [entry]})
        self.assertEqual(read.call_count, len(evidence['captures']))
        self.assertEqual(saved['report_sha256'], visual.update_resolutions(root, {'resolutions': [entry]})['report_sha256'])
        evidence = json.loads(evidence_path.read_text())
        self.assertEqual(evidence['reviews'], original_reviews)
        self.assertEqual(next(r for r in evidence['reviews'] if r['kind'] == 'model')['verdict'], 'fail')
        self.assertEqual(visual.audit(matrix, evidence, root)['reviews'], 2)
        summary = visual.review_summary(root)
        self.assertEqual(summary['resolved_model_failures'], 1)
        self.assertEqual(summary['failure_case_ids'], [entry['case_id']])
        self.assertEqual(summary['unresolved_failure_case_ids'], [])
        # An interruption after persisting a report can recover its reference.
        evidence['resolutions'] = []
        runner.write_json(evidence_path, evidence)
        self.assertEqual(visual.review_summary(root)['resolved_model_failures'], 1)
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        evidence = json.loads(evidence_path.read_text())
        self.assertEqual(len(evidence['resolutions']), 1)
        self.assertEqual(evidence['reviews'], original_reviews)
        self.assertTrue((root / saved['report_file']).is_file())

    def test_resolution_requires_complete_and_exact_independent_reasons(self):
        root, matrix, entry, _ = self.resolution_fixture()
        for mutate in (
            lambda e: e.pop('decision'),
            lambda e: e.update(decision='uncertain'),
            lambda e: e.update(image_sha256='f' * 64),
            lambda e: e.update(run_identity_sha256='f' * 64),
            lambda e: e.update(model_entry_sha256='f' * 64),
            lambda e: e.update(independent_report_sha256='f' * 64),
            lambda e: e.update(reviewer='model-a'),
            lambda e: e['findings'].pop(),
            lambda e: e['findings'][1].update(index=0),
            lambda e: e['findings'][0].update(sha256='f' * 64),
            lambda e: e['findings'][0].update(reason='  '),
        ):
            trial = json.loads(json.dumps(entry))
            mutate(trial)
            with self.subTest(trial=trial), self.assertRaises(ValueError):
                visual.update_resolutions(root, {'resolutions': [trial]})
        self.assertEqual(json.loads((root / 'evidence.json').read_text()).get('resolutions', []), [])
        with self.assertRaisesRegex(ValueError, 'review not clear'):
            visual.audit(matrix, json.loads((root / 'evidence.json').read_text()), root)
        visual.update_resolutions(root, {'resolutions': [entry]})
        changed = json.loads(json.dumps(entry))
        changed['findings'][0]['reason'] = 'A conflicting explanation.'
        with self.assertRaisesRegex(ValueError, 'conflicting current resolution'):
            visual.update_resolutions(root, {'resolutions': [changed]})

    @unittest.skipUnless(hasattr(signal, 'SIGKILL'), 'requires POSIX SIGKILL')
    def test_audit_rejects_unindexed_orphan_failure_and_recovers_it(self):
        self.inventory['subjects'][0]['high_risk'] = False
        self.inventory_path.write_text(json.dumps(self.inventory))
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        root = self.args.output
        evidence_path = root / 'evidence.json'
        evidence = json.loads(evidence_path.read_text())
        capture = evidence['captures'][0]
        model = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'model-a', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        visual.update_reviews(root, {'reviews': [model]})
        evidence = json.loads(evidence_path.read_text())
        old_evidence = evidence_path.read_bytes()
        matrix = visual.matrix_from_inventory(self.inventory)
        matrix['cases'] = [case for case in matrix['cases'] if case['id'] == capture['case_id']]
        self.assertEqual(visual.audit(matrix, evidence, root)['reviews'], 1)
        stale = dict(model, kind='independent', reviewer='old', verdict='fail', findings=['old result'],
                     run_identity_sha256='f' * 64)
        stale_data = visual.canonical({'reviews': [stale]}) + b'\n'
        stale_path = root / 'reviews' / 'reports' / (visual.digest(stale_data) + '.json')
        stale_path.write_bytes(stale_data)
        self.assertEqual(visual.audit(matrix, evidence, root)['reviews'], 1)
        orphan = dict(model, kind='independent', reviewer='reviewer-b', verdict='fail', findings=['visible issue'])
        data = visual.canonical({'reviews': [orphan],
                'verification': 'reviewer identity and image observation not independently verified'}) + b'\n'
        path = root / 'reviews' / 'reports' / (visual.digest(data) + '.json')
        child = r'''import json, os, signal, sys
import visual_evidence as visual
from pathlib import Path
replace = os.replace
def kill_before_index(src, dst):
    if os.path.basename(dst) == 'evidence.json':
        os.kill(os.getpid(), signal.SIGKILL)
    return replace(src, dst)
os.replace = kill_before_index
visual.update_reviews(Path(sys.argv[1]), {'reviews': [json.load(sys.stdin)]})
'''
        process = subprocess.run([sys.executable, '-c', child, str(root)], input=json.dumps(orphan),
                                 text=True, capture_output=True, cwd=runner.ROOT / 'scripts', timeout=15)
        self.assertEqual(process.returncode, -signal.SIGKILL, process.stderr)
        self.assertEqual(path.read_bytes(), data)
        self.assertEqual(evidence_path.read_bytes(), old_evidence)
        with self.assertRaisesRegex(ValueError, 'unindexed or mismatched current review'):
            visual.audit(matrix, evidence, root)
        with visual.review_lock(root):
            with self.assertRaisesRegex(ValueError, 'another runner or review'):
                visual.audit(matrix, evidence, root)
        self.args.subject = ['no-such-subject']
        with patch.object(runner, 'capture'):
            runner.execute(self.args)
        recovered = json.loads(evidence_path.read_text())
        self.assertIn(('independent', 'fail'), {(r['kind'], r['verdict']) for r in recovered['reviews']})
        with self.assertRaisesRegex(ValueError, 'review not clear'):
            visual.audit(matrix, recovered, root)
        self.assertTrue(path.is_file())

    def test_audit_rejects_conflicting_orphan_report(self):
        self.inventory['subjects'][0]['high_risk'] = False
        self.inventory_path.write_text(json.dumps(self.inventory))
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        root = self.args.output
        evidence = json.loads((root / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        model = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'model-a', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        visual.update_reviews(root, {'reviews': [model]})
        evidence = json.loads((root / 'evidence.json').read_text())
        conflict = dict(model, verdict='fail', findings=['conflicting result'])
        data = visual.canonical({'reviews': [conflict]}) + b'\n'
        (root / 'reviews' / 'reports' / (visual.digest(data) + '.json')).write_bytes(data)
        matrix = visual.matrix_from_inventory(self.inventory)
        matrix['cases'] = [case for case in matrix['cases'] if case['id'] == capture['case_id']]
        with self.assertRaisesRegex(ValueError, 'conflicting current review records'):
            visual.audit(matrix, evidence, root)

    def test_audit_requires_resolution_index_after_interrupted_write(self):
        root, matrix, entry, _ = self.resolution_fixture()
        visual.update_resolutions(root, {'resolutions': [entry]})
        evidence = json.loads((root / 'evidence.json').read_text())
        evidence['resolutions'] = []
        runner.write_json(root / 'evidence.json', evidence)
        with self.assertRaisesRegex(ValueError, 'unindexed or mismatched current resolution'):
            visual.audit(matrix, evidence, root)
        self.args.subject = ['no-such-subject']
        with patch.object(runner, 'capture'):
            runner.execute(self.args)
        recovered = json.loads((root / 'evidence.json').read_text())
        self.assertEqual(len(recovered['resolutions']), 1)
        self.assertEqual(visual.audit(matrix, recovered, root)['reviews'], 2)

    def test_grouped_duplicate_review_keeps_original_resolution_reference(self):
        root, matrix, resolution, _ = self.resolution_fixture()
        saved = visual.update_resolutions(root, {'resolutions': [resolution]})
        original_report = resolution['model_report_sha256']
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        evidence = json.loads((root / 'evidence.json').read_text())
        model = next(r for r in evidence['reviews'] if r['kind'] == 'model')
        model = {key: model[key] for key in visual.REVIEW_KEYS}
        independent = next(r for r in evidence['reviews'] if r['kind'] == 'independent')
        independent = {key: independent[key] for key in visual.REVIEW_KEYS}
        other = next(c for c in evidence['captures'] if c['case_id'] != model['case_id'])
        other_entry = dict(model, case_id=other['case_id'], image_sha256=other['sha256'],
                           verdict='pass', findings=[])
        # Force the new duplicate's report to sort before the one referenced
        # by the existing resolution, independent of random run identity.
        for i in range(65536):
            other_entry['reviewer'] = f'other-{i}'
            entries = sorted([model, independent, other_entry], key=lambda x: (x['case_id'], x['kind']))
            data = visual.canonical({'reviews': entries,
                'verification': 'reviewer identity and image observation not independently verified'}) + b'\n'
            if visual.digest(data) < original_report:
                break
        else:
            self.fail('could not build an earlier content-addressed duplicate report')
        with patch.object(visual, 'read_png', wraps=visual.read_png) as read:
            imported = visual.update_reviews(root, {'reviews': [model, independent, other_entry]})
        self.assertEqual(read.call_count, len(evidence['captures']))
        self.assertLess(imported['report_sha256'], original_report)
        evidence = json.loads((root / 'evidence.json').read_text())
        new_rep = next(r for r in evidence['reviews'] if r['case_id'] == model['case_id'] and r['kind'] == 'model')
        self.assertEqual(new_rep['report_sha256'], imported['report_sha256'])
        independent_rep = next(r for r in evidence['reviews'] if r['case_id'] == model['case_id'] and r['kind'] == 'independent')
        self.assertEqual(independent_rep['report_sha256'], imported['report_sha256'])
        self.assertEqual(evidence['resolutions'][0]['model_report_sha256'], original_report)
        self.assertEqual(evidence['resolutions'][0]['independent_report_sha256'], original_report)
        # Audit a one-case subset; unrelated capture/review belong to another case.
        case_id = model['case_id']
        subset = dict(evidence, captures=[c for c in evidence['captures'] if c['case_id'] == case_id],
                      reviews=[r for r in evidence['reviews'] if r['case_id'] == case_id])
        self.assertEqual(visual.audit(matrix, subset, root)['reviews'], 2)
        original_path = root / 'reviews' / 'reports' / (original_report + '.json')
        original_data = original_path.read_bytes()
        original_path.unlink()
        with self.assertRaisesRegex(ValueError, 'resolution review report missing'):
            visual.audit(matrix, subset, root)
        original_path.write_bytes(original_data)
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        self.assertTrue((root / saved['report_file']).is_file())
        self.assertEqual(visual.review_summary(root)['resolved_model_failures'], 1)

    def test_failed_review_import_leaves_no_new_report_or_index(self):
        root, _, resolution, _ = self.resolution_fixture()
        visual.update_resolutions(root, {'resolutions': [resolution]})
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        evidence_path = root / 'evidence.json'
        before = evidence_path.read_bytes()
        evidence = json.loads(before)
        other = next(c for c in evidence['captures'] if c['case_id'] != resolution['case_id'])
        entry = {'case_id': other['case_id'], 'kind': 'model', 'image_sha256': other['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'other', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        directory = root / 'reviews' / 'reports'
        names_before = {p.name for p in directory.iterdir()}
        original = visual.collect_review_reports
        calls = 0
        def fail_after_write(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError('simulated post-write failure')
            return original(*args, **kwargs)
        with patch.object(visual, 'collect_review_reports', side_effect=fail_after_write):
            with self.assertRaisesRegex(ValueError, 'simulated post-write failure'):
                visual.update_reviews(root, {'reviews': [entry]})
        self.assertEqual(evidence_path.read_bytes(), before)
        self.assertEqual({p.name for p in directory.iterdir()}, names_before)
        self.assertEqual(visual.review_summary(root)['resolved_model_failures'], 1)
        visual.update_reviews(root, {'reviews': [entry]})

    def test_failed_first_review_import_leaves_no_review_directory(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        root = self.args.output
        evidence_path = root / 'evidence.json'
        before = evidence_path.read_bytes()
        evidence = json.loads(before)
        capture = evidence['captures'][0]
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'first', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        original = visual.collect_review_reports
        calls = 0
        def fail_after_write(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError('simulated post-write failure')
            return original(*args, **kwargs)
        with patch.object(visual, 'collect_review_reports', side_effect=fail_after_write):
            with self.assertRaisesRegex(ValueError, 'simulated post-write failure'):
                visual.update_reviews(root, {'reviews': [entry]})
        self.assertEqual(evidence_path.read_bytes(), before)
        self.assertFalse((root / 'reviews').exists())
        visual.update_reviews(root, {'reviews': [entry]})

    def test_interrupt_after_review_index_replace_preserves_committed_report(self):
        self.inventory['subjects'][0]['high_risk'] = False
        self.inventory_path.write_text(json.dumps(self.inventory))
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        root = self.args.output
        before = json.loads((root / 'evidence.json').read_text())
        capture = before['captures'][0]
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': before['source_sha'], 'reviewer': 'model-a', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': before['run_identity']['identity_sha256']}
        replace = os.replace
        def interrupt_after_replace(src, dst):
            replace(src, dst)
            if Path(dst).name == 'evidence.json':
                raise KeyboardInterrupt('after successful evidence replace')
        with patch.object(visual.os, 'replace', side_effect=interrupt_after_replace):
            with self.assertRaises(KeyboardInterrupt):
                visual.update_reviews(root, {'reviews': [entry]})
        published = json.loads((root / 'evidence.json').read_text())
        self.assertEqual(len(published['reviews']), 1)
        report = published['reviews'][0]
        path = root / report['report_file']
        self.assertTrue(path.is_file())
        self.assertEqual(visual.digest(path.read_bytes()), report['report_sha256'])
        matrix = visual.matrix_from_inventory(self.inventory)
        matrix['cases'] = [case for case in matrix['cases'] if case['id'] == capture['case_id']]
        self.assertEqual(visual.audit(matrix, published, root)['reviews'], 1)
        self.assertEqual(visual.update_reviews(root, {'reviews': [entry]})['report_sha256'], report['report_sha256'])

    def test_interrupt_after_resolution_index_replace_preserves_committed_report(self):
        root, matrix, entry, _ = self.resolution_fixture()
        replace = os.replace
        def interrupt_after_replace(src, dst):
            replace(src, dst)
            if Path(dst).name == 'evidence.json':
                raise KeyboardInterrupt('after successful evidence replace')
        with patch.object(visual.os, 'replace', side_effect=interrupt_after_replace):
            with self.assertRaises(KeyboardInterrupt):
                visual.update_resolutions(root, {'resolutions': [entry]})
        published = json.loads((root / 'evidence.json').read_text())
        self.assertEqual(len(published['resolutions']), 1)
        report = published['resolutions'][0]
        path = root / report['report_file']
        self.assertTrue(path.is_file())
        self.assertEqual(visual.digest(path.read_bytes()), report['report_sha256'])
        self.assertEqual(visual.audit(matrix, published, root)['reviews'], 2)
        self.assertEqual(visual.update_resolutions(root, {'resolutions': [entry]})['report_sha256'], report['report_sha256'])

    def test_identical_index_replacement_never_discards_a_new_report(self):
        path = self.root / 'evidence.json'
        path.write_text('{"reviews": []}\n')
        original = path.stat()
        identity = (original.st_dev, original.st_ino)
        self.assertTrue(visual.unreferenced_after_failed_update(path, 'reviews/reports/x.json', 'a' * 64,
                                                               'reviews', identity))
        replacement = self.root / 'replacement.json'
        replacement.write_bytes(path.read_bytes())
        os.replace(replacement, path)
        self.assertFalse(visual.unreferenced_after_failed_update(path, 'reviews/reports/x.json', 'a' * 64,
                                                                'reviews', identity))

    def test_failed_idempotent_retry_keeps_existing_reports(self):
        root, _, entry, _ = self.resolution_fixture()
        saved = visual.update_resolutions(root, {'resolutions': [entry]})
        evidence_path = root / 'evidence.json'
        before = evidence_path.read_bytes()
        evidence = json.loads(before)
        original_reviews = [{key: review[key] for key in visual.REVIEW_KEYS} for review in evidence['reviews']]
        review_path = root / evidence['reviews'][0]['report_file']
        resolution_path = root / saved['report_file']
        for helper, callback in (
                ('collect_review_reports', lambda: visual.update_reviews(root, {'reviews': original_reviews})),
                ('collect_resolution_reports', lambda: visual.update_resolutions(root, {'resolutions': [entry]}))):
            original = getattr(visual, helper)
            calls = 0
            def fail_after_write(*args, **kwargs):
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise ValueError('simulated retry failure')
                return original(*args, **kwargs)
            with self.subTest(helper=helper), patch.object(visual, helper, side_effect=fail_after_write):
                with self.assertRaisesRegex(ValueError, 'simulated retry failure'):
                    callback()
            self.assertTrue(review_path.is_file())
            self.assertTrue(resolution_path.is_file())
            self.assertEqual(evidence_path.read_bytes(), before)
        self.assertEqual(visual.review_summary(root)['resolved_model_failures'], 1)

    def test_failed_resolution_import_leaves_no_new_report_or_index(self):
        root, _, entry, _ = self.resolution_fixture()
        evidence_path = root / 'evidence.json'
        before = evidence_path.read_bytes()
        original = visual.collect_resolution_reports
        calls = 0
        def fail_after_write(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError('simulated post-write failure')
            return original(*args, **kwargs)
        with patch.object(visual, 'collect_resolution_reports', side_effect=fail_after_write):
            with self.assertRaisesRegex(ValueError, 'simulated post-write failure'):
                visual.update_resolutions(root, {'resolutions': [entry]})
        self.assertEqual(evidence_path.read_bytes(), before)
        directory = root / 'reviews' / 'resolutions'
        self.assertFalse(directory.exists())
        visual.update_resolutions(root, {'resolutions': [entry]})

    def test_resolution_import_cli_accepts_a_bound_report(self):
        root, matrix, entry, _ = self.resolution_fixture()
        report = self.root / 'resolution.json'
        report.write_text(json.dumps({'resolutions': [entry]}))
        command = [sys.executable, str(runner.ROOT / 'scripts/visual_evidence.py'),
                   'resolution-import', str(root), str(report)]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['current_resolutions'], 1)
        self.assertEqual(visual.audit(matrix, json.loads((root / 'evidence.json').read_text()), root)['reviews'], 2)

    def test_resolution_missing_or_tampered_reports_fail_closed(self):
        root, matrix, entry, _ = self.resolution_fixture()
        result = visual.update_resolutions(root, {'resolutions': [entry]})
        evidence = json.loads((root / 'evidence.json').read_text())
        report_path = root / result['report_file']
        original = report_path.read_bytes()
        report_path.write_bytes(original + b' ')
        with self.assertRaisesRegex(ValueError, 'resolution report hash mismatch'):
            visual.audit(matrix, evidence, root)
        report_path.unlink()
        with self.assertRaises((OSError, ValueError)):
            visual.audit(matrix, evidence, root)
        report_path.write_bytes(original)
        model = next(r for r in evidence['reviews'] if r['kind'] == 'model')
        original_review = (root / model['report_file']).read_bytes()
        (root / model['report_file']).unlink()
        with self.assertRaises((OSError, ValueError)):
            visual.audit(matrix, evidence, root)
        (root / model['report_file']).write_bytes(original_review)
        evidence['resolutions'] = []
        with self.assertRaisesRegex(ValueError, 'unindexed or mismatched current resolution'):
            visual.audit(matrix, evidence, root)

    def test_empty_failure_and_independent_disagreement_cannot_be_resolved(self):
        root, _, entry, _ = self.resolution_fixture(model_findings=[])
        with self.assertRaisesRegex(ValueError, 'model failure findings'):
            visual.update_resolutions(root, {'resolutions': [entry]})
        # Separate runs avoid replacing any original report.
        self.args.output = self.root / 'disagreement'
        root, _, entry, _ = self.resolution_fixture(independent_verdict='fail')
        with self.assertRaisesRegex(ValueError, 'passing independent'):
            visual.update_resolutions(root, {'resolutions': [entry]})
        self.args.output = self.root / 'same-reviewer'
        root, _, entry, _ = self.resolution_fixture(same_reviewer=True)
        with self.assertRaisesRegex(ValueError, 'different independent'):
            visual.update_resolutions(root, {'resolutions': [entry]})

    def test_review_summary_is_fresh_fail_closed_and_recovers_reports(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
            runner.execute(self.args)
        root = self.args.output
        evidence = json.loads((root / 'evidence.json').read_text())
        entries = []
        for index, capture in enumerate(evidence['captures']):
            entries.append({'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                            'source_sha': evidence['source_sha'], 'reviewer': 'reviewer',
                            'verdict': 'pass' if index == 0 else 'fail',
                            'findings': [] if index == 0 else ['visual issue'],
                            'run_identity_sha256': evidence['run_identity']['identity_sha256']})
        visual.update_reviews(root, {'reviews': entries})
        report = json.loads((root / 'report.json').read_text())
        self.assertIn('snapshot-at-last-capture', report['review_summary_scope'])
        self.assertEqual(report['current_review_records'], 0)
        summary = visual.review_summary(root)
        self.assertEqual((summary['passing_review_records'], summary['failing_review_records']), (1, 1))
        self.assertEqual(summary['failure_case_ids'], [entries[1]['case_id']])
        cli = subprocess.run([sys.executable, str(runner.ROOT / 'scripts/visual_evidence.py'),
                              'review-summary', str(root)], capture_output=True, text=True, check=False)
        self.assertEqual(cli.returncode, 0, cli.stderr)
        self.assertEqual(json.loads(cli.stdout), summary)
        self.assertFalse(summary['delivery_ready'])
        self.assertEqual(summary['visual_audit'], 'not_performed')
        with visual.review_lock(root):
            with self.assertRaisesRegex(ValueError, 'another runner or review'):
                visual.review_summary(root)
        # Recovery reads immutable reports even if the evidence index was not refreshed.
        evidence = json.loads((root / 'evidence.json').read_text())
        evidence['reviews'] = []
        runner.write_json(root / 'evidence.json', evidence)
        self.assertEqual(visual.review_summary(root)['current_review_records'], 2)
        # A modified image is invalid, and its old review becomes stale.
        (root / evidence['captures'][0]['image']).write_bytes(png(161, 45))
        summary = visual.review_summary(root)
        self.assertEqual((summary['valid_captures'], summary['invalid_or_missing_captures']), (1, 1))
        self.assertEqual((summary['current_review_records'], summary['stale_review_records']), (1, 1))
        # A newer interrupted attempt also invalidates the previous attempt's review.
        second = evidence['captures'][1]['case_id']
        status_path = root / 'cases' / second / 'status.json'
        status = json.loads(status_path.read_text())
        status.update(state='failed', cleanup_confirmation_required=True, attempt=2)
        runner.write_json(status_path, status)
        summary = visual.review_summary(root)
        self.assertEqual((summary['valid_captures'], summary['stale_review_records']), (0, 2))
        self.assertFalse(summary['delivery_ready'])

    def test_review_summary_rejects_missing_or_changed_attempt_metadata(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        root = self.args.output
        evidence = json.loads((root / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'reviewer', 'verdict': 'pass',
                 'findings': [], 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        visual.update_reviews(root, {'reviews': [entry]})
        case_dir = root / 'cases' / capture['case_id'] / 'attempt-000001'
        metadata = case_dir / 'capture.json'
        original = metadata.read_bytes()
        metadata.unlink()
        summary = visual.review_summary(root)
        self.assertEqual((summary['valid_captures'], summary['invalid_or_missing_captures'],
                          summary['stale_review_records']), (0, 1, 1))
        metadata.write_bytes(original)
        data = json.loads(original)
        data['terminal_version'] = 'changed'
        runner.write_json(metadata, data)
        summary = visual.review_summary(root)
        self.assertEqual((summary['passing_review_records'], summary['stale_review_records']), (0, 1))
        metadata.write_bytes(original)
        case_path = case_dir / 'case.json'
        case = json.loads(case_path.read_text())
        case['allocation_cells'] = [999, 1]
        runner.write_json(case_path, case)
        self.assertEqual(visual.review_summary(root)['invalid_or_missing_captures'], 1)

    def test_resume_rejects_changed_font_or_locale(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        changed = dict(self.facts)
        changed['fontconfig_candidate'] = dict(self.facts['fontconfig_candidate'], sha256='b' * 64)
        with patch.object(runner, 'terminal_configuration', return_value=changed):
            with self.assertRaisesRegex(ValueError, 'run inputs changed'):
                runner.execute(self.args)
        changed = dict(self.facts)
        changed['locale'] = dict(self.facts['locale'], charmap='ASCII')
        with patch.object(runner, 'terminal_configuration', return_value=changed):
            with self.assertRaisesRegex(ValueError, 'run inputs changed'):
                runner.execute(self.args)

    def test_legacy_review_without_run_identity_is_stale(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            runner.execute(self.args)
        evidence = json.loads((self.args.output / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        entry = {'case_id': capture['case_id'], 'kind': 'model', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'legacy', 'verdict': 'pass', 'findings': []}
        data = visual.canonical({'reviews': [entry]}) + b'\n'
        directory = self.args.output / 'reviews/reports'
        directory.mkdir(parents=True)
        path = directory / (visual.digest(data) + '.json')
        path.write_bytes(data)
        current, stale = visual.collect_review_reports(evidence, self.args.output)
        self.assertEqual(current, [])
        self.assertEqual(stale, 1)
        with self.assertRaisesRegex(ValueError, 'invalid review entry fields'):
            visual.update_reviews(self.args.output, {'reviews': [entry]})
        self.assertTrue(path.is_file())

    def test_capture_with_inconsistent_terminal_version_is_invalid(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
        case_id = first['results'][0]['case_id']
        meta_path = self.args.output / 'cases' / case_id / 'attempt-000001/capture.json'
        meta = json.loads(meta_path.read_text())
        meta['terminal_version'] = 'contradictory-version'
        runner.write_json(meta_path, meta)
        self.args.subject = ['missing']
        report = runner.execute(self.args)
        self.assertEqual(report['failed_or_invalid_cases'], 1)
        self.assertEqual(report['captured_cases'], 0)

    def test_review_cli_creates_and_imports_explicit_reports(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
        case_id = first['results'][0]['case_id']
        command = [sys.executable, str(runner.ROOT / 'scripts/visual_evidence.py'),
                   'review-create', str(self.args.output), '--case', case_id, '--kind', 'model',
                   '--reviewer', 'reviewer-a', '--verdict', 'pass']
        created = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(created.returncode, 0, created.stderr)
        evidence = json.loads((self.args.output / 'evidence.json').read_text())
        capture = evidence['captures'][0]
        entry = {'case_id': case_id, 'kind': 'independent', 'image_sha256': capture['sha256'],
                 'source_sha': evidence['source_sha'], 'reviewer': 'reviewer-b', 'verdict': 'pass', 'findings': [],
                 'run_identity_sha256': evidence['run_identity']['identity_sha256']}
        report = self.root / 'review.json'
        report.write_text(json.dumps({'reviews': [entry]}))
        imported = subprocess.run([sys.executable, str(runner.ROOT / 'scripts/visual_evidence.py'),
                                   'review-import', str(self.args.output), str(report)],
                                  capture_output=True, text=True, check=False)
        self.assertEqual(imported.returncode, 0, imported.stderr)
        self.assertEqual(len(json.loads((self.args.output / 'evidence.json').read_text())['reviews']), 2)

    def test_failed_and_damaged_cases_require_explicit_retry(self):
        def failed(case, case_dir, args, run_id, current):
            status = {'state': 'failed', 'attempt': 1, 'run_identity_sha256': run_id, 'review_status': 'not_run',
                      'cleanup_confirmation_required': False}
            runner.write_json(case_dir / 'status.json', status)
            return status
        with patch.object(runner, 'capture', side_effect=failed):
            first = runner.execute(self.args)
            self.assertEqual(first['failed_or_invalid_cases'], 1)
        self.args.retry_failed = True
        with patch.object(runner, 'capture', side_effect=self.captured):
            second = runner.execute(self.args)
            self.assertEqual(second['captured_cases'], 1)
            self.assertEqual(second['failed_or_invalid_cases'], 0)
        case_id = second['results'][0]['case_id']
        (self.args.output / 'cases' / case_id / 'attempt-000001' / 'capture.png').write_bytes(b'bad')
        self.args.retry_failed = False
        with patch.object(runner, 'capture') as capture:
            # Prevent another pending case from being captured so only damage is counted.
            self.args.subject = ['missing']
            third = runner.execute(self.args)
            self.assertEqual(third['failed_or_invalid_cases'], 1)
            capture.assert_not_called()

    def test_interrupted_retry_requires_explicit_cleanup_confirmation(self):
        def interrupted(case, case_dir, args, run_id, current):
            status = {'state': 'failed', 'attempt': 1, 'run_identity_sha256': run_id,
                      'review_status': 'not_run', 'cleanup_confirmation_required': True}
            runner.write_json(case_dir / 'status.json', status)
            return status
        with patch.object(runner, 'capture', side_effect=interrupted):
            runner.execute(self.args)
        self.args.retry_failed = True
        with self.assertRaisesRegex(ValueError, 'requires cleanup confirmation'):
            runner.execute(self.args)
        self.args.ack_interrupted_cleanup = True
        with patch.object(runner, 'capture', side_effect=self.captured):
            report = runner.execute(self.args)
            self.assertEqual(report['captured_cases'], 1)
            self.assertFalse(report['cleanup_confirmation_required'])

    def test_unconfirmed_other_case_blocks_new_and_filtered_retry(self):
        def interrupted(case, case_dir, args, run_id, current):
            status = {'state': 'failed', 'attempt': 1, 'run_identity_sha256': run_id,
                      'review_status': 'not_run', 'cleanup_confirmation_required': True}
            runner.write_json(case_dir / 'status.json', status)
            return status
        with patch.object(runner, 'capture', side_effect=interrupted):
            runner.execute(self.args)
            with self.assertRaisesRegex(ValueError, 'requires cleanup confirmation'):
                runner.execute(self.args)  # A is interrupted; a normal run would start B.
            self.args.ack_interrupted_cleanup = True
            runner.execute(self.args)  # Explicitly allow B to start and also be interrupted.
        self.args.ack_interrupted_cleanup = False
        self.args.retry_failed = True
        self.args.terminal = ['120x36']  # Select B but exclude the earlier interrupted A.
        with self.assertRaisesRegex(ValueError, 'requires cleanup confirmation'):
            runner.execute(self.args)

    def test_uncertain_failure_stops_same_invocation_and_reports_partial(self):
        self.args.limit = 2
        def interrupted(case, case_dir, args, run_id, current):
            status = {'state': 'failed', 'attempt': 1, 'run_identity_sha256': run_id,
                      'review_status': 'not_run', 'cleanup_confirmation_required': True}
            runner.write_json(case_dir / 'status.json', status)
            return status
        with patch.object(runner, 'capture', side_effect=interrupted) as capture:
            report = runner.execute(self.args)
        self.assertEqual(capture.call_count, 1)
        self.assertEqual(report['capture_status'], 'partial')
        self.assertTrue(report['cleanup_confirmation_required'])
        self.assertEqual(len(report['results']), 1)
        self.assertTrue(json.loads((self.args.output / 'report.json').read_text())['cleanup_confirmation_required'])

    def test_captured_status_with_pending_cleanup_blocks_other_cases(self):
        with patch.object(runner, 'capture', side_effect=self.captured):
            first = runner.execute(self.args)
        path = self.args.output / 'cases' / first['results'][0]['case_id'] / 'status.json'
        status = json.loads(path.read_text())
        status['cleanup_confirmation_required'] = True
        runner.write_json(path, status)
        with self.assertRaisesRegex(ValueError, 'requires cleanup confirmation'):
            runner.execute(self.args)

    def test_captured_status_requires_explicit_false(self):
        for value in ('missing', None, 'false', True):
            with self.subTest(value=value):
                self.args.output = self.root / ('output-' + str(value))
                with patch.object(runner, 'capture', side_effect=self.captured):
                    first = runner.execute(self.args)
                path = self.args.output / 'cases' / first['results'][0]['case_id'] / 'status.json'
                status = json.loads(path.read_text())
                if value == 'missing':
                    status.pop('cleanup_confirmation_required')
                else:
                    status['cleanup_confirmation_required'] = value
                runner.write_json(path, status)
                with self.assertRaisesRegex(ValueError, 'requires cleanup confirmation'):
                    runner.execute(self.args)

    def test_nondefault_sigchld_fails_before_spawn(self):
        with patch.object(runner.signal, 'getsignal', return_value=signal.SIG_IGN), \
             patch.object(runner.subprocess, 'Popen') as spawn:
            with self.assertRaisesRegex(ValueError, 'SIGCHLD must have the default'):
                runner.run_capture_process([], {}, None, 1)
            spawn.assert_not_called()

    def test_rejects_fixture_inventory_mismatch_and_unknown_output(self):
        self.inventory_path.write_text(json.dumps({'themes': ['different'], 'subjects': []}))
        with self.assertRaises(ValueError):
            runner.execute(self.args)

    def test_terminate_capture_group_stops_real_child_processes(self):
        code = ('import subprocess,sys,time; '
                'p=subprocess.Popen([sys.executable,"-c","import time; time.sleep(60)"]); '
                'print(p.pid,flush=True); time.sleep(60)')
        process = subprocess.Popen([sys.executable, '-c', code], start_new_session=True,
                                   stdout=subprocess.PIPE, text=True)
        child = int(process.stdout.readline())
        child_fd = os.pidfd_open(child)
        other = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True)
        try:
            runner.terminate_capture_group(process)
            self.assertIsNotNone(process.returncode)
            with selectors.DefaultSelector() as selector:
                selector.register(child_fd, selectors.EVENT_READ)
                self.assertTrue(selector.select(5), 'capture descendant did not exit')
            self.assertIsNone(other.poll(), 'unrelated session was terminated')
        finally:
            if process.poll() is None:
                runner.terminate_capture_group(process)
            os.close(child_fd)
            other.terminate()
            other.wait()
            process.stdout.close()

    def test_exited_unreaped_leader_does_not_leave_group_child(self):
        code = ('import subprocess,sys; '
                'p=subprocess.Popen([sys.executable,"-c","import time; time.sleep(60)"]); '
                'print(p.pid,flush=True)')
        process = subprocess.Popen([sys.executable, '-c', code], start_new_session=True,
                                   stdout=subprocess.PIPE, text=True)
        child = int(process.stdout.readline())
        child_fd = os.pidfd_open(child)
        os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOWAIT)
        try:
            runner.terminate_capture_group(process)
            with selectors.DefaultSelector() as selector:
                selector.register(child_fd, selectors.EVENT_READ)
                self.assertTrue(selector.select(5), 'capture descendant did not exit')
        finally:
            os.close(child_fd)
            process.stdout.close()

    def test_startup_signal_window_cleans_spawned_process(self):
        code = '''
import os, signal, subprocess, sys
import visual_matrix_runner as runner
for sig in runner.STOP_SIGNALS: signal.signal(sig, runner.interrupt_signal)
original = subprocess.Popen
def spawn(*args, **kwargs):
    child = original(*args, **kwargs)
    print(child.pid, flush=True)
    os.kill(os.getpid(), signal.SIGTERM)
    return child
runner.subprocess.Popen = spawn
with open(os.devnull, 'w') as log:
    runner.run_capture_process([sys.executable, '-c', 'import time; time.sleep(60)'], os.environ, log, 30)
'''
        env = os.environ.copy()
        env['PYTHONPATH'] = str(runner.ROOT / 'scripts')
        process = subprocess.Popen([sys.executable, '-c', code], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, env=env)
        child = int(process.stdout.readline())
        _, errors = process.communicate(timeout=15)
        self.assertEqual(process.returncode, 143, errors)
        stat = Path(f'/proc/{child}/stat')
        if stat.exists():
            self.assertEqual(stat.read_text().split()[2], 'Z')

    def test_mixed_signals_do_not_interrupt_cleanup(self):
        code = '''
import os, signal, sys
import visual_matrix_runner as runner
def report(sig, frame):
    try:
        runner.interrupt_signal(sig, frame)
    except SystemExit:
        print('HANDLING', flush=True)
        raise
for sig in runner.STOP_SIGNALS: signal.signal(sig, report)
runner.run_capture_process([sys.executable, '-c',
    'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print("READY",flush=True); time.sleep(60)'],
    os.environ, sys.stdout, 30)
'''
        env = os.environ.copy()
        env['PYTHONPATH'] = str(runner.ROOT / 'scripts')
        process = subprocess.Popen([sys.executable, '-c', code], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, env=env)
        try:
            self.assertEqual(process.stdout.readline().strip(), 'READY')
            os.kill(process.pid, signal.SIGTERM)
            self.assertEqual(process.stdout.readline().strip(), 'HANDLING')
            for sig in (signal.SIGHUP, signal.SIGINT):
                os.kill(process.pid, sig)
            _, errors = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 143, errors)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

    def test_build_record_binds_archive_renderer_and_runtime_inputs(self):
        fixture = self.launcher.parents[2]
        (fixture / 'scripts/visual_evidence.py').write_bytes((runner.ROOT / 'scripts/visual_evidence.py').read_bytes())
        files = {p.relative_to(fixture).as_posix(): p.read_bytes() for p in fixture.rglob('*') if p.is_file()}
        for name in ('visual_capture.py', 'visual_matrix_runner.py'):
            files['scripts/' + name] = (runner.ROOT / 'scripts' / name).read_bytes()
        complete_local_files(files)
        files.pop('examples/visual_matrix/sample/demo.txt')
        hashes = {name: hashlib.sha256(value).hexdigest() for name, value in files.items()}
        source_digest = runner.digest(runner.canonical(hashes))
        manifest = {'files': hashes, 'source_snapshot_sha256': source_digest}
        files['snapshot-manifest.json'] = json.dumps(manifest).encode()
        with tarfile.open(self.archive, 'w') as tar:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        record = complete_local_record({'kind': 'local-build-record-not-attestation', 'source_revision_verified': False,
                  'build_source_link_independently_verified': False, 'source_snapshot_sha256': source_digest,
                  'source_archive_sha256': runner.sha_file(self.archive),
                  'renderer_sha256': runner.sha_file(self.renderer), 'launcher_sha256': runner.sha_file(self.launcher)}, hashes)
        record_path = self.root / 'record.json'
        record_path.write_text(json.dumps(record))
        self.args.source_revision = source_digest
        self.args.build_record = record_path
        self.assertEqual(runner.verify_build_record(record_path, self.args), runner.sha_file(record_path))
        self.renderer.write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'does not match'):
            runner.verify_build_record(record_path, self.args)
        self.renderer.write_bytes(b'renderer')
        sample = fixture / 'examples/visual_matrix/sample/example.txt'
        sample.unlink()
        with self.assertRaisesRegex(ValueError, 'runtime input differs'):
            runner.verify_build_record(record_path, self.args)
        sample.write_text('sample')
        (fixture / 'scripts/visual_inventory.py').write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'runtime input differs'):
            runner.verify_build_record(record_path, self.args)


if __name__ == '__main__':
    unittest.main()
