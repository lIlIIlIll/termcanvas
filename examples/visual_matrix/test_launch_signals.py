import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('visual_matrix_launcher', Path(__file__).with_name('launch.py'))
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LaunchSignalsTest(unittest.TestCase):
    def test_signals_during_popen_reap_only_owned_child(self):
        real_popen = subprocess.Popen
        binary = Path(sys.executable).resolve()
        case = {
            'id': 'test-case', 'subject': 'core.Button', 'state': 'focused',
            'theme': 'light', 'glyph': 'unicode', 'color': '16',
            'widget_cells': [16, 3], 'terminal_cells': [80, 24],
        }
        env = {
            'TERMCANVAS_VISUAL_CASE': json.dumps(case),
            'TERMCANVAS_MATRIX_BINARY': str(binary),
            'TERMCANVAS_VISUAL_RENDERER_SHA256': hashlib.sha256(binary.read_bytes()).hexdigest(),
        }
        for signum in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            with self.subTest(signum=signum):
                started = []
                untouched = real_popen([sys.executable, '-c', 'import time; time.sleep(60)'])
                previous_handlers = {s: signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT)}

                def popen_with_signal(*_args, **_kwargs):
                    child = real_popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                                       stderr=subprocess.PIPE)
                    started.append(child)
                    # Real signal arrives after child creation but before the
                    # Popen wrapper returns its handle to the launcher.
                    os.kill(os.getpid(), signum)
                    return child

                try:
                    with patch.dict(os.environ, env), \
                         patch.object(launcher, 'validate_supported_case'), \
                         patch.object(launcher.os, 'get_terminal_size', return_value=os.terminal_size((80, 24))), \
                         patch.object(launcher.subprocess, 'Popen', side_effect=popen_with_signal):
                        with self.assertRaises(SystemExit) as caught:
                            launcher.main()
                    self.assertEqual(caught.exception.code, 128 + signum)
                    self.assertEqual(len(started), 1)
                    self.assertIsNotNone(started[0].poll())
                    self.assertIsNone(untouched.poll())
                    for s, handler in previous_handlers.items():
                        self.assertIs(signal.getsignal(s), handler)
                finally:
                    for child in started:
                        if child.poll() is None:
                            child.kill()
                            child.wait()
                        if child.stderr is not None:
                            child.stderr.close()
                    if untouched.poll() is None:
                        untouched.kill()
                    untouched.wait()


if __name__ == '__main__':
    unittest.main()
