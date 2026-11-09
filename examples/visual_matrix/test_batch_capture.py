import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('batch_capture', Path(__file__).with_name('batch_capture.py'))
batch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(batch)


class MarkerTest(unittest.TestCase):
    def test_pixel_marker_rejects_old_or_partial_frame(self):
        nonce = 'f0123456789abcde'
        pixels = b''.join(bytes((230, 210, 190) if bit == '1' else (20, 40, 60))
                          for bit in ''.join(f'{int(c, 16):04b}' for c in nonce))
        class Result:
            stdout = pixels
        with patch.object(batch, 'read_png', return_value=('x', (80, 24))), \
             patch.object(batch.subprocess, 'run', return_value=Result()):
            batch.verify_nonce(Path('unused.png'), [80, 24], nonce)
            with self.assertRaisesRegex(ValueError, 'nonce'):
                batch.verify_nonce(Path('unused.png'), [80, 24], '00123456789abcde')
            with self.assertRaisesRegex(ValueError, 'dimensions'):
                batch.verify_nonce(Path('unused.png'), [79, 24], nonce)

    def test_resume_requires_identity_state_dimensions_and_safe_image_name(self):
        case = {'id': 'a', 'subject': 'core.Button', 'state': 'normal', 'theme': 'indigo',
                'glyph': 'unicode', 'color': 'truecolor', 'widget_cells': [16, 3], 'terminal_cells': [80, 24]}
        applied = {k: case[k] for k in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            status = {'state': 'captured', 'case_id': 'a', 'renderer_sha256': 'renderer', 'identity_sha256': 'identity',
                      'cells': [80, 24], 'applied': applied, 'image': 'attempt-000001.png', 'attempt': 1,
                      'nonce': '0123456789abcdef', 'sha256': 'imagehash'}
            def save():
                (root / 'status.json').write_text(json.dumps(status))
            with patch.object(batch, 'read_png', return_value=('imagehash', (80, 24))), \
                 patch.object(batch, 'verify_nonce'):
                save()
                self.assertTrue(batch.valid_previous(root, case, 'renderer', 'identity'))
                self.assertFalse(batch.valid_previous(root, case, 'renderer', 'different'))
                status['image'] = '../elsewhere.png'
                save()
                self.assertFalse(batch.valid_previous(root, case, 'renderer', 'identity'))
                status['image'] = 'attempt-000001.png'
                status['cells'] = [120, 36]
                save()
                self.assertFalse(batch.valid_previous(root, case, 'renderer', 'identity'))


if __name__ == '__main__':
    unittest.main()
