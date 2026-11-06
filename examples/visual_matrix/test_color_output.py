#!/usr/bin/env python3
"""Verify actual ANSI emitted by the built matrix renderer, not its report.

Run with Cangjie runtime environment and TERMCANVAS_MATRIX_TEST_BINARY set.
This checks terminal output on a PTY; it does not claim real terminal display
capabilities or replace screenshot review.
"""
import fcntl
import os
from pathlib import Path
import pty
import re
import selectors
import signal
import struct
import subprocess
import termios
import time
import unittest


def render(binary, mode):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    process = None
    selector = selectors.DefaultSelector()
    output, diagnostic = bytearray(), bytearray()
    try:
        sample = Path(__file__).resolve().parent / 'sample'
        env = os.environ.copy()
        env['TERMCANVAS_MATRIX_SAMPLE_DIR'] = '.'
        process = subprocess.Popen([str(binary), 'core.StyledWidget', 'normal', 'indigo', 'ascii', mode,
                                    '40', '10', '80x24'], stdin=slave, stdout=slave,
                                   stderr=subprocess.PIPE, cwd=sample, env=env, start_new_session=True)
        os.close(slave)
        slave = None
        selector.register(master, selectors.EVENT_READ, 'screen')
        selector.register(process.stderr, selectors.EVENT_READ, 'diagnostic')
        deadline = time.monotonic() + 10
        ready = False
        while not ready:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f'{mode}: renderer did not flush: {diagnostic!r}')
            for key, _ in selector.select(remaining):
                data = os.read(key.fd, 65536)
                if not data:
                    raise AssertionError(f'{mode}: renderer exited before flush: {diagnostic!r}')
                if key.data == 'screen':
                    output.extend(data)
                else:
                    diagnostic.extend(data)
                    ready = b'TERMCANVAS_MATRIX_DRAWN\n' in diagnostic
        os.set_blocking(master, False)
        while True:
            try:
                data = os.read(master, 65536)
                if not data:
                    break
                output.extend(data)
            except BlockingIOError:
                break
        return bytes(output)
    finally:
        selector.close()
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait()
        if process is not None:
            process.stderr.close()
        os.close(master)
        if slave is not None:
            os.close(slave)


def sgr_color_forms(data):
    """Read SGR parameters while skipping RGB/index values as color operands."""
    forms = set()
    for payload in re.findall(rb'\x1b\[([0-9;]*)m', data):
        params = [int(part or b'0') for part in payload.split(b';')]
        index = 0
        while index < len(params):
            value = params[index]
            if value in (38, 48) and index + 1 < len(params):
                mode = params[index + 1]
                if mode == 2 and index + 4 < len(params):
                    forms.add('truecolor')
                    index += 5
                    continue
                if mode == 5 and index + 2 < len(params):
                    forms.add('indexed')
                    index += 3
                    continue
            if 30 <= value <= 37 or 40 <= value <= 47 or 90 <= value <= 97 or 100 <= value <= 107:
                forms.add('ansi16')
            index += 1
    return forms


class ColorOutputTest(unittest.TestCase):
    def test_sgr_parser_does_not_mistake_color_operands_for_ansi16(self):
        self.assertEqual(sgr_color_forms(b'\x1b[0;38;5;90;48;2;30;90;40;1m'), {'indexed', 'truecolor'})
        self.assertEqual(sgr_color_forms(b'\x1b[0;32;44m\x1b[39;49m'), {'ansi16'})

    def test_four_modes_produce_corresponding_ansi(self):
        value = os.environ.get('TERMCANVAS_MATRIX_TEST_BINARY')
        if not value:
            self.skipTest('set TERMCANVAS_MATRIX_TEST_BINARY to the built renderer')
        binary = Path(value).resolve(strict=True)
        rendered = {mode: render(binary, mode) for mode in ('truecolor', '256', '16', 'monochrome')}
        forms = {mode: sgr_color_forms(data) for mode, data in rendered.items()}
        self.assertIn('truecolor', forms['truecolor'])
        self.assertIn('indexed', forms['256'])
        self.assertNotIn('truecolor', forms['256'])
        self.assertEqual(forms['16'], {'ansi16'})
        self.assertEqual(forms['monochrome'], set())


if __name__ == '__main__':
    unittest.main()
