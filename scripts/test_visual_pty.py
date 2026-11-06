#!/usr/bin/env python3
"""Exercise input/output, resize and shutdown through a real private PTY."""
import base64
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unittest

SCRIPT = Path(__file__).with_name('visual_pty.py')
APP = r'''
import os,signal,sys,tty

def report(*_):
    size=os.get_terminal_size()
    os.write(1, f'SIZE:{size.columns}x{size.lines}\n'.encode())
signal.signal(signal.SIGWINCH, report)
tty.setraw(0)
report()
while True:
    ch=os.read(0,1)
    if not ch or ch==b'q': break
    os.write(1,b'GOT:'+ch.hex().encode()+b'\n')
'''


class PtyProxyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='visual-pty-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.fifo = self.root / 'control'
        os.mkfifo(self.fifo, 0o600)
        self.transcript = self.root / 'transcript.jsonl'
        self.master, self.slave = pty.openpty()
        self.original = termios.tcgetattr(self.slave)
        self.resize(80, 24)
        self.process = subprocess.Popen([sys.executable, str(SCRIPT), '--control', str(self.fifo),
                                         '--transcript', str(self.transcript), '--', sys.executable, '-u', '-c', APP],
                                        stdin=self.slave, stdout=self.slave, stderr=self.slave, close_fds=True)
        self.output = bytearray()
        self.addCleanup(self.close)
        self.await_output(b'SIZE:80x24')

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.master)
        os.close(self.slave)

    def resize(self, cols, rows):
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))

    def await_output(self, marker):
        deadline = time.monotonic() + 5
        while marker not in self.output:
            ready, _, _ = select.select([self.master], [], [], max(0, deadline - time.monotonic()))
            if not ready:
                self.fail(f'timed out waiting for {marker!r}; got {bytes(self.output)!r}')
            self.output.extend(os.read(self.master, 65536))

    def inject(self, data):
        fd = os.open(self.fifo, os.O_WRONLY | os.O_NONBLOCK)
        try:
            os.write(fd, json.dumps({'hex': data.hex()}).encode() + b'\n')
        finally:
            os.close(fd)

    def test_forwards_and_injects_bytes_then_restores_terminal(self):
        os.write(self.master, b'x')
        self.await_output(b'GOT:78')
        self.inject(b'z')
        self.await_output(b'GOT:7a')
        self.inject(b'q')
        self.assertEqual(self.process.wait(timeout=5), 0)
        self.assertEqual(termios.tcgetattr(self.slave), self.original)
        events = [json.loads(line) for line in self.transcript.read_text().splitlines()]
        self.assertTrue(any(e['event'] == 'forwarded_input' and base64.b64decode(e['base64']) == b'x' for e in events))
        self.assertTrue(any(e['event'] == 'injected' and base64.b64decode(e['base64']) == b'z' for e in events))
        self.assertTrue(any(e['event'] == 'output' for e in events))

    def test_propagates_resize_and_stops_child_on_signal(self):
        self.resize(101, 37)
        os.kill(self.process.pid, signal.SIGWINCH)
        self.await_output(b'SIZE:101x37')
        start = json.loads(self.transcript.read_text().splitlines()[0])
        self.process.terminate()
        self.process.wait(timeout=5)
        self.assertEqual(termios.tcgetattr(self.slave), self.original)
        with self.assertRaises(ProcessLookupError):
            os.kill(start['pid'], 0)
        events = [json.loads(line) for line in self.transcript.read_text().splitlines()]
        self.assertTrue(any(e['event'] == 'resize' and e['columns'] == 101 and e['rows'] == 37 for e in events))


class TranscriptTests(unittest.TestCase):
    def test_expected_text_must_follow_recorded_input(self):
        from visual_preview import verify_injection
        with tempfile.TemporaryDirectory(prefix='visual-pty-transcript-') as temp:
            path = Path(temp) / 'events.jsonl'
            def event(kind, data):
                return json.dumps({'event': kind, 'base64': base64.b64encode(data).decode()})
            path.write_text('\n'.join([event('output', b'Reset'), event('injected', b'\x1bOR'),
                                       event('output', b'\x1b[1mRe\x1b[0mset')]) + '\n')
            self.assertTrue(verify_injection(path, b'\x1bOR', 'Reset')['observed_in_pty_output'])
            with self.assertRaisesRegex(ValueError, 'expected text'):
                verify_injection(path, b'\x1bOR', 'never-rendered')
            with self.assertRaisesRegex(ValueError, 'not recorded'):
                verify_injection(path, b'bad', 'Reset')


if __name__ == '__main__':
    unittest.main()
