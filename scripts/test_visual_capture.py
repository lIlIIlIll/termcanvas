#!/usr/bin/env python3
"""Validate the screenshot fixture readiness contract without a compositor."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from visual_capture import (environment_metadata, foot_command, isolated_config_environment,
                            validate_ready)
from visual_evidence import matrix_from_inventory


class CaptureReadinessTests(unittest.TestCase):
    def setUp(self):
        inventory = {'themes': ['dark'], 'subjects': [{'id': 'probe', 'kind': 'primitive',
                     'states': ['normal'], 'widget_sizes': [[1, 0]], 'high_risk': False}]}
        self.case = matrix_from_inventory(inventory)['cases'][0]
        self.report = {'case_id': self.case['id'], 'renderer_sha256': 'a' * 64, 'cells': self.case['terminal_cells'],
                       'applied': {key: self.case[key] for key in
                                   ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')},
                       'renderer_geometry': {'effective_rect': self.case['expected_effective_rect'],
                           'target_width': self.case['target_width'],
                           'source': 'renderer-self-report-not-pixel-measurement'}}

    def test_renderer_geometry_is_required_and_bound(self):
        geometry = self.report.pop('renderer_geometry')
        with self.assertRaisesRegex(ValueError, 'renderer geometry'):
            validate_ready(json.dumps(self.report), self.case, 'a' * 64)
        self.report['renderer_geometry'] = dict(geometry, effective_rect=[2, 4, 2, 0])
        with self.assertRaisesRegex(ValueError, 'renderer geometry'):
            validate_ready(json.dumps(self.report), self.case, 'a' * 64)

    def test_app_must_confirm_size_and_applied_state(self):
        self.assertEqual(validate_ready(json.dumps(self.report), self.case, 'a' * 64), self.report)
        with self.assertRaisesRegex(ValueError, 'renderer hash'):
            validate_ready(json.dumps(self.report), self.case, 'b' * 64)
        self.report['cells'] = [79, 24]
        with self.assertRaisesRegex(ValueError, 'terminal size'):
            validate_ready(json.dumps(self.report), self.case, 'a' * 64)
        self.report['cells'] = self.case['terminal_cells']
        self.report['applied']['color'] = 'different'
        with self.assertRaisesRegex(ValueError, 'visual state'):
            validate_ready(json.dumps(self.report), self.case, 'a' * 64)
        self.report['case_id'] = 'different'
        with self.assertRaisesRegex(ValueError, 'case id'):
            validate_ready(json.dumps(self.report), self.case, 'a' * 64)


class CaptureEnvironmentTests(unittest.TestCase):
    def test_private_xdg_roots_and_explicit_foot_config(self):
        env = {'XDG_CONFIG_HOME': '/old/user/config', 'XDG_CONFIG_DIRS': '/old/system/config'}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            isolated_config_environment(env, root)
            self.assertEqual(Path(env['XDG_CONFIG_HOME']).parent, root)
            self.assertEqual(Path(env['XDG_CONFIG_DIRS']).parent, root)
            self.assertEqual(list(Path(env['XDG_CONFIG_HOME']).iterdir()), [])
            self.assertEqual(list(Path(env['XDG_CONFIG_DIRS']).iterdir()), [])
        command = foot_command(120, 36, 'Example:size=14', Path('/bin/renderer'), ['--case'])
        self.assertIn('--config=/dev/null', command)
        self.assertEqual(command[command.index('--font') + 1], 'Example:size=14')
        self.assertEqual(command[-2:], ['/bin/renderer', '--case'])

    def test_font_candidate_and_locale_are_limited_to_observed_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            font = Path(directory) / 'candidate.ttf'
            font.write_bytes(b'candidate-font')
            env = {'LC_ALL': 'C.UTF-8', 'LANG': 'en_US.UTF-8', 'XDG_CONFIG_HOME': '/private'}
            class LocaleResult:
                returncode = 0
                stdout = 'UTF-8\n'
            with patch('visual_capture.subprocess.check_output',
                       return_value=f'Example|Regular|42\n{font}') as match, \
                 patch('visual_capture.subprocess.run', return_value=LocaleResult()) as locale:
                result = environment_metadata(env, 'Example:size=14,Other:size=14', 4)
            self.assertEqual(match.call_args.args[0][-1], 'Example:size=14')
            self.assertIs(match.call_args.kwargs['env'], env)
            self.assertIs(locale.call_args.kwargs['env'], env)
            self.assertEqual(result['font'], 'Example|Regular|42')
            self.assertEqual(result['fontconfig_candidate']['sha256'], hashlib.sha256(b'candidate-font').hexdigest())
            self.assertIn('unverified', result['fontconfig_candidate']['scope'])
            self.assertNotIn(str(font), json.dumps(result))
            self.assertEqual(result['locale']['LC_ALL'], 'C.UTF-8')
            self.assertEqual(result['locale']['charmap'], 'UTF-8')


if __name__ == '__main__':
    unittest.main()
