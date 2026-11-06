#!/usr/bin/env python3
"""Proxy one private PTY for isolated terminal recording and key injection.

A private control FIFO accepts JSON lines {"hex": "1b4f52"}. Only bytes sent
through this FIFO reach the child PTY; no desktop input or global seat is used.
The controlling terminal is put into raw mode and restored on exit. Terminal
resize propagates on SIGWINCH. Output and injected bytes are recorded in a
JSONL transcript so the caller can prove what happened at the PTY boundary.
"""
from __future__ import annotations

import argparse
import base64
import errno
import fcntl
import json
import os
import pty
import selectors
import signal
import struct
import subprocess
import sys
import termios
import tty


def set_size(fd, columns, rows):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, columns, 0, 0))


def write_all(fd, data):
    view = memoryview(data)
    while view:
        count = os.write(fd, view)
        if count <= 0:
            raise OSError('terminal write made no progress')
        view = view[count:]


def signal_group(process, sig):
    if process.poll() is None:
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass


def run(control, transcript, command):
    if not os.isatty(0) or not os.isatty(1):
        raise ValueError('proxy requires an actual parent terminal')
    original = termios.tcgetattr(0)
    master, slave = pty.openpty()
    control_fd = None
    process = None
    selector = selectors.DefaultSelector()
    stopped = False
    resized = False
    previous_handlers = {}
    def notify(sig, _frame):
        nonlocal stopped, resized
        if sig == signal.SIGWINCH:
            resized = True
        else:
            stopped = True
    def controlling_tty():
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    try:
        for sig in (signal.SIGWINCH, signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            previous_handlers[sig] = signal.signal(sig, notify)
        tty.setraw(0)
        size = os.get_terminal_size(0)
        set_size(slave, size.columns, size.lines)
        control_fd = os.open(control, os.O_RDWR | os.O_NONBLOCK)
        process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave,
                                   start_new_session=True, preexec_fn=controlling_tty, close_fds=True)
        os.close(slave)
        slave = None
        selector.register(0, selectors.EVENT_READ, 'input')
        selector.register(master, selectors.EVENT_READ, 'output')
        selector.register(control_fd, selectors.EVENT_READ, 'control')
        pending = bytearray()
        with open(transcript, 'w', encoding='utf-8') as log:
            def record(kind, data=b'', **extra):
                json.dump({'event': kind, 'base64': base64.b64encode(data).decode('ascii'), **extra}, log)
                log.write('\n')
                log.flush()
            record('start', columns=size.columns, rows=size.lines, pid=process.pid)
            while not stopped:
                if resized:
                    resized = False
                    size = os.get_terminal_size(0)
                    set_size(master, size.columns, size.lines)
                    signal_group(process, signal.SIGWINCH)
                    record('resize', columns=size.columns, rows=size.lines)
                for key, _ in selector.select(0.1):
                    if key.data == 'control':
                        pending.extend(os.read(control_fd, 65536))
                        while b'\n' in pending:
                            line, _, rest = pending.partition(b'\n')
                            pending[:] = rest
                            message = json.loads(line.decode('utf-8'))
                            data = bytes.fromhex(message['hex'])
                            if not data or len(data) > 128:
                                raise ValueError('injected byte sequence must contain 1..128 bytes')
                            write_all(master, data)
                            record('injected', data)
                    elif key.data == 'input':
                        data = os.read(0, 65536)
                        if not data:
                            stopped = True
                            break
                        write_all(master, data)
                        record('forwarded_input', data)
                    else:
                        try:
                            data = os.read(master, 65536)
                        except OSError as error:
                            if error.errno == errno.EIO:
                                stopped = True
                                break
                            raise
                        if not data:
                            stopped = True
                            break
                        write_all(1, data)
                        record('output', data)
                if process.poll() is not None:
                    # Continue draining until the PTY reports EOF.
                    continue
            record('stop', exit_code=process.poll())
        return process.returncode if process.returncode is not None else 0
    finally:
        selector.close()
        if process is not None and process.poll() is None:
            signal_group(process, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                signal_group(process, signal.SIGKILL)
                process.wait(timeout=3)
        if control_fd is not None:
            os.close(control_fd)
        os.close(master)
        if slave is not None:
            os.close(slave)
        termios.tcsetattr(0, termios.TCSANOW, original)
        for sig, handler in previous_handlers.items():
            signal.signal(sig, handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--control', required=True)
    parser.add_argument('--transcript', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('command is required')
    try:
        return run(args.control, args.transcript, command)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f'visual PTY proxy: {type(error).__name__}: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
