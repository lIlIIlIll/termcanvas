import copy
import json
from pathlib import Path
import re
import unittest

import visual_evidence
import visual_inventory


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.inventory = json.loads(visual_inventory.INVENTORY.read_text(encoding='utf-8'))
        self.matrix = visual_evidence.matrix_from_inventory(self.inventory)

    def test_all_declared_cases_are_recognized(self):
        for case in self.matrix['cases']:
            visual_inventory.validate_supported_case(case, self.inventory)

    def test_unknown_and_tampered_cases_are_rejected(self):
        case = copy.deepcopy(self.matrix['cases'][0])
        case['subject'] = 'core.MissingWidget'
        case['id'] = visual_evidence.digest(visual_evidence.canonical({k: v for k, v in case.items() if k != 'id'}))
        with self.assertRaises(ValueError):
            visual_inventory.validate_supported_case(case, self.inventory)
        case = copy.deepcopy(self.matrix['cases'][0])
        case['state'] = 'unknown'
        with self.assertRaises(ValueError):
            visual_inventory.validate_supported_case(case, self.inventory)

    def test_source_audit_exposes_unimplemented_subjects(self):
        partial = copy.deepcopy(self.inventory)
        partial['subjects'] = [s for s in partial['subjects'] if s['id'] != 'core.Table']
        report = visual_inventory.audit(inventory=partial)
        self.assertIn('core.Button', report['implemented_subjects'])
        self.assertIn('core.Table', report['missing_subjects'])
        self.assertFalse(report['project_coverage_verified'])
        self.assertTrue(report['unverified'])
        self.assertEqual(report['unknown_declared_subjects'], [])

    def test_every_declared_subject_has_a_renderer_branch(self):
        source = (visual_inventory.ROOT / 'examples/visual_matrix/src/main.cj').read_text(encoding='utf-8')
        branches = set(re.findall(r'subject == "([^"]+)"', source))
        declared = {item['id'] for item in self.inventory['subjects']}
        self.assertEqual(declared, branches)

    def test_boundary_cases_are_counted_separately_and_alias_is_not_expanded(self):
        self.assertEqual(self.inventory['theme_aliases'], {'default': 'indigo'})
        self.assertNotIn('default', self.inventory['themes'])
        self.assertIn('indigo', self.inventory['themes'])
        partial = copy.deepcopy(self.inventory)
        partial['subjects'] = [partial['subjects'][0]]
        report = visual_inventory.audit(inventory=partial)
        counts = report['declared_case_counts']
        self.assertEqual(counts['zero_area_boundary'], report['declared_case_count'] // 4)
        self.assertEqual(counts['nonzero_area'] + counts['zero_area_boundary'], report['declared_case_count'])
        self.assertEqual(report['theme_aliases_not_counted'], {'default': 'indigo'})
        self.assertIn('nonzero area does not guarantee a visible or distinct widget', report['unverified'])

    def test_invalid_theme_aliases_are_rejected(self):
        partial = copy.deepcopy(self.inventory)
        partial['subjects'] = [partial['subjects'][0]]
        partial['theme_aliases'] = {'default': 'missing'}
        with self.assertRaisesRegex(ValueError, 'theme aliases'):
            visual_inventory.audit(inventory=partial)
        partial['theme_aliases'] = {'indigo': 'indigo'}
        with self.assertRaisesRegex(ValueError, 'theme aliases'):
            visual_inventory.audit(inventory=partial)

    def test_tabs_declares_focused_state(self):
        tabs = next(subject for subject in self.inventory['subjects'] if subject['id'] == 'core.Tabs')
        self.assertEqual(tabs['states'], ['normal', 'focused'])

    def test_game_drawing_methods_are_discovered_and_missing_cases_reported(self):
        names = {'game.SpriteRenderer.render', 'game.SpriteRenderer.drawSprite', 'game.TileMap.render'}
        discovered = visual_inventory.discover()
        self.assertTrue(names <= discovered.keys())
        self.assertTrue(names <= {subject['id'] for subject in self.inventory['subjects']})
        partial = copy.deepcopy(self.inventory)
        partial['subjects'] = [subject for subject in partial['subjects'] if subject['id'] != 'game.TileMap.render']
        self.assertIn('game.TileMap.render', visual_inventory.audit(inventory=partial)['missing_subjects'])

    def test_animation_cases_declare_frames_and_unverified_time_scheduling(self):
        subjects = {item['id']: item for item in self.inventory['subjects']}
        frames = ['frame-0', 'frame-1', 'frame-2', 'frame-3']
        for name in ('core.Spinner', 'core.LoadingOverlay'):
            self.assertEqual(subjects[name]['states'], frames)
            self.assertIn('real-time frame scheduling', subjects[name]['unverified_states'])
        self.assertEqual(subjects['media.AsciiAnimationView']['states'],
                         ['frame-0', 'frame-1', 'paused-frame-0', 'paused-frame-1'])
        self.assertIn('real-time scheduling and caller-controlled pause timing',
                      subjects['media.AsciiAnimationView']['unverified_states'])
        self.assertIn('indeterminate-early', subjects['core.ProgressBar']['states'])
        self.assertIn('indeterminate-mid', subjects['core.ProgressBar']['states'])

    def test_workbench_specific_states_are_declared(self):
        subjects = {item['id']: item for item in self.inventory['subjects']}
        expected = {
            'core.Input': {'empty+focused', 'empty+error', 'empty+focused+error'},
            'core.Table': {'no-selection', 'scrolled+selected', 'scrolled+focused', 'custom-surface'},
            'core.VirtualTable': {'custom-surface', 'sort-asc+width-1', 'sort-asc+width-2',
                                  'sort-desc+width-1', 'sort-desc+width-2'},
            'core.Tree': {'long-name+collapsed', 'long-name+expanded',
                          'long-name+expanded+width-39', 'long-name+expanded+width-40',
                          'long-name+expanded+width-41', 'long-name+expanded+width-42'},
            'core.ProgressBar': {'tiny', 'tiny+width-3', 'tiny+width-4', 'tiny+width-8'},
            'core.VirtualTable': {'empty', 'loading', 'error', 'empty+custom-surface',
                                  'loading+custom-surface', 'error+custom-surface', 'paged+custom-surface'},
            'core.TaskActivityView': {'mixed-stages+expanded', 'long-title+duration+expanded'},
        }
        for name, states in expected.items():
            with self.subTest(subject=name):
                self.assertTrue(states <= set(subjects[name]['states']))
        self.assertIn([16, 1], subjects['core.Input']['widget_sizes'])
        self.assertIn([40, 1], subjects['core.Input']['widget_sizes'])
        self.assertTrue(all(height <= 1 for _, height in subjects['core.Input']['widget_sizes']))
        self.assertEqual(subjects['core.Input']['max_effective_height'], 1)
        self.assertEqual(subjects['core.ProgressBar']['state_target_widths'],
                         {'tiny+width-3': 3, 'tiny+width-4': 4, 'tiny+width-8': 8})
        self.assertEqual(subjects['core.Tree']['state_target_widths'],
                         {f'long-name+expanded+width-{width}': width for width in (39, 40, 41, 42)})
        self.assertEqual(subjects['core.VirtualTable']['state_target_widths'],
                         {f'sort-{direction}+width-{width}': width
                          for direction in ('asc', 'desc') for width in (1, 2)})
        self.assertIn([41, 3], subjects['core.Tree']['widget_sizes'])
        self.assertIn([42, 3], subjects['core.Tree']['widget_sizes'])


if __name__ == '__main__':
    unittest.main()
