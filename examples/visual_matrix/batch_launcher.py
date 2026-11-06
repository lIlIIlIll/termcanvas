#!/usr/bin/env python3
"""Experimental persistent terminal launcher; the controller verifies screenshots.

The terminal stays open, but every case gets a fresh renderer process. A
controller-issued nonce is painted only after that renderer flushes its frame.
"""
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from visual_inventory import validate_supported_case


def send(stream, value):
    stream.write((json.dumps(value, separators=(',', ':')) + '\n').encode())
    stream.flush()


def write_all(fd, data):
    remaining = memoryview(data)
    while remaining:
        count = os.write(fd, remaining)
        if count <= 0:
            raise OSError('terminal write made no progress')
        remaining = remaining[count:]


def main():
    binary = Path(os.environ['TERMCANVAS_MATRIX_BINARY']).resolve(strict=True)
    expected_hash = os.environ['TERMCANVAS_VISUAL_RENDERER_SHA256']
    if hashlib.sha256(binary.read_bytes()).hexdigest() != expected_hash:
        raise ValueError('renderer hash mismatch')
    def terminate(signum, _frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGHUP, terminate)
    sample = (ROOT / 'examples/visual_matrix/sample').resolve(strict=True)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.connect(os.environ['TERMCANVAS_MATRIX_BATCH_SOCKET'])
        stream = connection.makefile('rwb', buffering=0)
        send(stream, {'event': 'ready'})
        while True:
            line = stream.readline()
            if not line:
                return 0
            request = json.loads(line)
            if request.get('command') == 'stop':
                return 0
            case = request['case']
            nonce = request['nonce']
            if request.get('command') != 'render' or len(nonce) != 16 or any(c not in '0123456789abcdef' for c in nonce):
                raise ValueError('invalid render command or nonce')
            validate_supported_case(case)
            size = os.get_terminal_size(1)
            cells = [size.columns, size.lines]
            if cells != case['terminal_cells']:
                raise ValueError('terminal size mismatch')
            if hashlib.sha256(binary.read_bytes()).hexdigest() != expected_hash:
                raise ValueError('renderer changed during session')
            # Full terminal reset precedes each fresh renderer. This prevents
            # alternate screen, style and cursor state leaking across cases.
            write_all(1, b'\x1bc\x1b[?25l\x1b[0m\x1b[2J\x1b[H')
            env = os.environ.copy()
            env['TERMCANVAS_MATRIX_SAMPLE_DIR'] = '.'
            command = [str(binary), case['subject'], case['state'], case['theme'], case['glyph'], case['color'],
                       *(str(x) for x in case['widget_cells']), f'{cells[0]}x{cells[1]}']
            process = subprocess.Popen(command, stderr=subprocess.PIPE, cwd=sample, env=env)
            try:
                line = process.stderr.readline()
                if line != b'TERMCANVAS_MATRIX_DRAWN\n' or process.poll() is not None:
                    raise RuntimeError('renderer did not finish the frame')
                # First screen row is reserved for capture attestation; the
                # existing fixture starts its widget at row 5. Each cell's
                # solid background encodes one bit of this attempt's nonce.
                bits = ''.join(f'{int(c, 16):04b}' for c in nonce)
                marker = bytearray(b'\x1b[1;1H')
                for bit in bits:
                    marker.extend(b'\x1b[48;2;230;210;190m ' if bit == '1' else b'\x1b[48;2;20;40;60m ')
                marker.extend(b'\x1b[0m')
                write_all(1, marker)
                applied = {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
                send(stream, {'event': 'drawn', 'case_id': case['id'], 'nonce': nonce, 'cells': cells,
                              'renderer_sha256': expected_hash, 'applied': applied})
                ack = json.loads(stream.readline())
                if ack != {'command': 'captured', 'case_id': case['id'], 'nonce': nonce}:
                    raise ValueError('capture acknowledgment mismatch')
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, KeyError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f'batch launcher: {type(error).__name__}: {error}', file=sys.stderr)
        sys.exit(1)
