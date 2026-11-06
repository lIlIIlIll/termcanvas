#!/usr/bin/env python3
"""Translate one validated visual case into the Cangjie renderer's arguments.

Set TERMCANVAS_MATRIX_BINARY to the built renderer. The captured application is
the renderer on the terminal, not a synthetic buffer image. This launcher only
reports readiness after the renderer acknowledges that its frame was flushed.
"""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from visual_inventory import validate_supported_case
from visual_evidence import case_geometry


def main():
    case = json.loads(os.environ['TERMCANVAS_VISUAL_CASE'])
    validate_supported_case(case)
    if case.get('case_schema_version') == 2:
        inventory = json.loads((ROOT / 'scripts/visual_inventory.json').read_text(encoding='utf-8'))
        subject = next(item for item in inventory['subjects'] if item['id'] == case['subject'])
        expected = case_geometry(subject, case['state'], case['widget_cells'], case['terminal_cells'])
        if any(case.get(key) != value for key, value in expected.items()):
            raise ValueError('case geometry does not match the declared inventory')
    size = os.get_terminal_size(1)
    cells = [size.columns, size.lines]
    if cells != case['terminal_cells']:
        raise ValueError('actual terminal size differs from requested size')
    binary = Path(os.environ['TERMCANVAS_MATRIX_BINARY']).resolve(strict=True)
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    if binary_hash != os.environ['TERMCANVAS_VISUAL_RENDERER_SHA256']:
        raise ValueError('renderer does not match the capture tool expected hash')
    sample_dir = (ROOT / 'examples/visual_matrix/sample').resolve(strict=True)
    os.environ['TERMCANVAS_MATRIX_SAMPLE_DIR'] = '.'
    command = [str(binary), case['subject'], case['state'], case['theme'],
               case['glyph'], case['color'], *(str(x) for x in case['widget_cells']),
               f'{cells[0]}x{cells[1]}']
    process = None
    launching = True
    cleaning = False
    pending_signal = None
    previous_handlers = {}

    def terminate(signum, _frame):
        nonlocal pending_signal
        if cleaning:
            return
        if launching:
            if pending_signal is None:
                pending_signal = signum
            return
        raise SystemExit(128 + signum)

    try:
        # Do not raise while Popen is creating a child: Python may run this
        # handler before the returned process handle has been assigned.
        for signum in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            previous_handlers[signum] = signal.signal(signum, terminate)
        if pending_signal is not None:
            raise SystemExit(128 + pending_signal)
        process = subprocess.Popen(command, stderr=subprocess.PIPE, cwd=sample_dir)
        launching = False
        if pending_signal is not None:
            raise SystemExit(128 + pending_signal)
        line = process.stderr.readline()
        if line != b'TERMCANVAS_MATRIX_DRAWN\n' or process.poll() is not None:
            raise RuntimeError('renderer exited or did not report a flushed frame: ' + line.decode(errors='replace'))
        applied = {k: case[k] for k in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        report = {'case_id': case['id'], 'cells': cells, 'applied': applied,
                  'renderer_sha256': binary_hash}
        if case.get('case_schema_version') == 2:
            geometry = json.loads(process.stderr.readline())
            if (not isinstance(geometry, dict) or set(geometry) != {'effective_rect', 'target_width'} or
                    geometry['effective_rect'] != case['expected_effective_rect'] or
                    type(geometry['target_width']) is not int or geometry['target_width'] != case['target_width']):
                raise ValueError('renderer geometry does not match the declared case')
            report['renderer_geometry'] = {**geometry, 'source': 'renderer-self-report-not-pixel-measurement'}
        with open(os.environ['TERMCANVAS_VISUAL_READY_FIFO'], 'w', encoding='utf-8') as stream:
            json.dump(report, stream)
            stream.write('\n')
        return process.wait()
    finally:
        cleaning = True
        try:
            if process is not None:
                if process.poll() is None:
                    try:
                        process.terminate()
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        try:
                            process.kill()
                        except ProcessLookupError:
                            pass
                        process.wait()
                if process.stderr is not None:
                    process.stderr.close()
        finally:
            for signum, previous in previous_handlers.items():
                signal.signal(signum, previous)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (KeyError, ValueError, OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f'visual matrix launcher: {error}', file=sys.stderr)
        sys.exit(1)
