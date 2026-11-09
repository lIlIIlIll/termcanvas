#!/usr/bin/env python3
"""Exercise fixture states on a PTY, without claiming screenshots or review.

Requires the Cangjie runtime environment and a built fixture. Each declared
subject/state is exercised at zero and representative sizes in one theme and
capability configuration. This only verifies that drawing reaches the flushed
frame marker; it is not a visual assertion or the full screenshot matrix.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import pty
import selectors
import signal
import struct
import subprocess
import sys
import termios
import time

from visual_inventory import INVENTORY, ROOT


def run_case(binary, subject, state, size, timeout):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    env = os.environ.copy()
    sample_dir = ROOT / 'examples/visual_matrix/sample'
    env['TERMCANVAS_MATRIX_SAMPLE_DIR'] = '.'
    command = [str(binary), subject, state, 'indigo', 'unicode', 'truecolor',
               str(size[0]), str(size[1]), '80x24']
    process = None
    selector = selectors.DefaultSelector()
    diagnostic = bytearray()
    try:
        process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=subprocess.PIPE,
                                   env=env, cwd=sample_dir, start_new_session=True)
        os.close(slave)
        slave = None
        selector.register(master, selectors.EVENT_READ, 'screen')
        selector.register(process.stderr, selectors.EVENT_READ, 'diagnostic')
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for key, _ in selector.select(max(0, deadline - time.monotonic())):
                try:
                    chunk = os.read(key.fd, 65536)
                except OSError:
                    chunk = b''
                if not chunk:
                    selector.unregister(key.fileobj)
                elif key.data == 'diagnostic':
                    diagnostic.extend(chunk)
                    if b'TERMCANVAS_MATRIX_DRAWN\n' in diagnostic:
                        return None
            if process.poll() is not None:
                return f'exit {process.returncode}: {diagnostic.decode(errors="replace")[-1000:]}'
        return f'timeout: {diagnostic.decode(errors="replace")[-1000:]}'
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--timeout', type=float, default=10)
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    if args.timeout <= 0:
        parser.error('timeout must be positive')
    inventory = json.loads(INVENTORY.read_text(encoding='utf-8'))
    failures, count = [], 0
    for subject in inventory['subjects']:
        for state in subject['states']:
            for size in ([0, 0], [40, 10]):
                count += 1
                error = run_case(binary, subject['id'], state, size, args.timeout)
                if error:
                    failures.append({'subject': subject['id'], 'state': state, 'size': size, 'error': error})
    print(json.dumps({'passed': not failures, 'cases': count, 'failures': failures,
                      'scope': 'PTY smoke only; no screenshots or visual review'}, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
