#!/usr/bin/env python3
"""Experimental same-size terminal batch capture; not the release evidence runner.

Each image carries a 64-bit visual nonce in the reserved first row. Only a
matching decoded PNG is accepted. Cases are independently resumable; interrupted
attempts remain failed and require --retry-failed. Source/build provenance and
visual review remain unverified, just as in the existing capture runner.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from visual_capture import read_fifo, stop, tree_find
from visual_evidence import SHA, canonical, digest, read_png
from visual_inventory import validate_supported_case


def send(stream, obj):
    stream.write((json.dumps(obj, separators=(',', ':')) + '\n').encode())
    stream.flush()


def receive(stream):
    line = stream.readline()
    if not line:
        raise RuntimeError('terminal control connection closed')
    return json.loads(line)


def write_json(path, obj):
    data = json.dumps(obj, indent=2, sort_keys=True) + '\n'
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(data, encoding='utf-8')
    os.replace(temporary, path)


def verify_nonce(image, cells, nonce):
    _, (width, height) = read_png(image)
    cols, rows = cells
    if width % cols or height % rows:
        raise ValueError('image dimensions do not match terminal cells')
    cw, ch = width // cols, height // rows
    if cw < 1 or ch < 1 or cols < 64:
        raise ValueError('terminal cells cannot carry the nonce')
    # Crop one raster row from the first cell row. The capture has no terminal
    # padding; every sampled pixel lies inside the center of one marker cell.
    geometry = f'{cw * 64}x1+0+{ch // 2}'
    result = subprocess.run(['magick', str(image), '-crop', geometry, '-depth', '8', 'rgb:-'],
                            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    pixels = result.stdout
    if len(pixels) != cw * 64 * 3:
        raise ValueError('unexpected marker pixel data')
    bits = ''.join(f'{int(ch, 16):04b}' for ch in nonce)
    for i, bit in enumerate(bits):
        start = (i * cw + cw // 2) * 3
        expected = bytes((230, 210, 190) if bit == '1' else (20, 40, 60))
        if pixels[start:start + 3] != expected:
            raise ValueError('captured pixels do not contain the current nonce')


def valid_previous(directory, case, binary_hash, identity_sha):
    try:
        status = json.loads((directory / 'status.json').read_text())
        applied = {k: case[k] for k in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        if (status['state'] != 'captured' or status['case_id'] != case['id'] or
                status['renderer_sha256'] != binary_hash or status['identity_sha256'] != identity_sha or
                status['cells'] != case['terminal_cells'] or status['applied'] != applied):
            return False
        if type(status['attempt']) is not int or status['attempt'] < 1 or status['image'] != f"attempt-{status['attempt']:06d}.png":
            return False
        if not re.fullmatch(r'[0-9a-f]{16}', status['nonce']):
            return False
        image = directory / status['image']
        if read_png(image)[0] != status['sha256']:
            return False
        verify_nonce(image, case['terminal_cells'], status['nonce'])
        return True
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, json.JSONDecodeError):
        return False


def file_hash(path):
    checksum = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(part)
    return checksum.hexdigest()


def run(args):
    cases = json.loads(args.cases.read_text())
    if not isinstance(cases, list) or not cases:
        raise ValueError('cases must be a nonempty JSON list')
    for case in cases:
        validate_supported_case(case)
        if case.get('id') != digest(canonical({k: v for k, v in case.items() if k != 'id'})):
            raise ValueError('case id mismatch')
    if len({case['id'] for case in cases}) != len(cases):
        raise ValueError('duplicate case id')
    if len({tuple(c['terminal_cells']) for c in cases}) != 1:
        raise ValueError('one session requires a single terminal size')
    cols, rows = cases[0]['terminal_cells']
    binary = args.renderer.resolve(strict=True)
    binary_hash = file_hash(binary)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not SHA.fullmatch(args.source_revision):
        raise ValueError('source revision must be a full SHA-1 or SHA-256')
    tools = {}
    for name in ('sway', 'swaymsg', 'foot', 'grim', 'magick', 'fc-match'):
        executable = shutil.which(name)
        if not executable:
            raise ValueError('missing capture tool: ' + name)
        tools[name] = file_hash(Path(executable).resolve(strict=True))
    font_file = subprocess.check_output(['fc-match', '-f', '%{file}', args.font], text=True, timeout=args.timeout).strip()
    source_archive = args.source_archive.resolve(strict=True)
    files = [ROOT / 'examples/visual_matrix/batch_launcher.py', ROOT / 'scripts/visual_inventory.py',
             ROOT / 'scripts/visual_inventory.json', ROOT / 'scripts/visual_capture.py', ROOT / 'scripts/visual_evidence.py']
    sample = ROOT / 'examples/visual_matrix/sample'
    for path in sorted(sample.rglob('*')):
        if path.is_symlink():
            raise ValueError('symlinked sample inputs are unsupported')
        if path.is_file():
            files.append(path)
    inputs = {str(p.relative_to(ROOT)): file_hash(p) for p in files}
    identity = {'version': 1, 'renderer_sha256': binary_hash, 'source_archive_sha256': file_hash(source_archive),
                'source_revision_declared': args.source_revision, 'source_revision_verified': False,
                'build_source_link_verified': False, 'controller_sha256': file_hash(Path(__file__)),
                'inputs': inputs, 'tools': tools, 'python_sha256': file_hash(Path(sys.executable).resolve(strict=True)),
                'font': args.font, 'font_file_sha256': file_hash(Path(font_file)),
                'terminal_cells': cases[0]['terminal_cells'], 'settle': args.settle, 'timeout': args.timeout,
                'environment': {name: digest(os.environ.get(name, '').encode()) for name in
                                ('PATH', 'LD_LIBRARY_PATH', 'LANG', 'LC_ALL', 'TERM', 'COLORTERM')}}
    identity_sha = digest(canonical(identity))
    def verify_bound_inputs():
        if file_hash(binary) != binary_hash or file_hash(source_archive) != identity['source_archive_sha256']:
            raise ValueError('renderer or source archive changed during batch')
        if file_hash(Path(__file__)) != identity['controller_sha256'] or file_hash(Path(font_file)) != identity['font_file_sha256']:
            raise ValueError('controller or font changed during batch')
        if any(file_hash(ROOT / path) != expected for path, expected in inputs.items()):
            raise ValueError('launcher or fixture inputs changed during batch')
        current_sample = {str(path.relative_to(ROOT)) for path in sample.rglob('*') if path.is_file()}
        original_sample = {path for path in inputs if path.startswith('examples/visual_matrix/sample/')}
        if current_sample != original_sample or any(path.is_symlink() for path in sample.rglob('*')):
            raise ValueError('fixture sample inventory changed during batch')
        if file_hash(Path(sys.executable).resolve(strict=True)) != identity['python_sha256']:
            raise ValueError('Python interpreter changed during batch')
        for name, expected in tools.items():
            executable = shutil.which(name)
            if not executable or file_hash(Path(executable).resolve(strict=True)) != expected:
                raise ValueError('capture tool changed during batch')
    identity_path = output / 'run.json'
    if identity_path.exists():
        if json.loads(identity_path.read_text()) != {'identity': identity, 'sha256': identity_sha}:
            raise ValueError('batch inputs changed; choose a new output directory')
    else:
        write_json(identity_path, {'identity': identity, 'sha256': identity_sha})
    pending = []
    for case in cases:
        directory = output / case['id']
        if directory.exists():
            if valid_previous(directory, case, binary_hash, identity_sha):
                continue
            if not args.retry_failed:
                raise ValueError('failed or invalid case requires --retry-failed')
        pending.append(case)
    if not pending:
        return {'captured': 0, 'reused': len(cases), 'failed': 0}
    runtime_base = os.environ.get('XDG_RUNTIME_DIR')
    if not runtime_base:
        raise ValueError('XDG_RUNTIME_DIR required for short Wayland socket paths')
    with tempfile.TemporaryDirectory(prefix='batch-capture-') as private_dir, \
         tempfile.TemporaryDirectory(prefix='tcb-', dir=runtime_base) as runtime_dir:
        private, runtime = Path(private_dir), Path(runtime_dir)
        if len(os.fsencode(str(runtime))) > 70:
            raise ValueError('runtime socket path too long')
        ready_fifo = private / 'sway-ready'
        os.mkfifo(ready_fifo, 0o600)
        socket_path = runtime / 'control.sock'
        control = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        control.settimeout(args.timeout)
        control.bind(str(socket_path))
        control.listen(1)
        command = ' '.join(shlex.quote(x) for x in (sys.executable, str(ROOT / 'scripts/visual_capture.py'),
                                                    '--sway-ready', str(ready_fifo)))
        config = private / 'sway.conf'
        config.write_text('output HEADLESS-1 resolution 3840x2160\ndefault_border none\n'
                          'for_window [app_id="termcanvas-batch"] floating enable, move position 0 0, border none\n'
                          f'exec {command}\n')
        env = os.environ.copy()
        env.update({'XDG_RUNTIME_DIR': str(runtime), 'WLR_BACKENDS': 'headless', 'WLR_RENDERER': 'pixman',
                    'WLR_LIBINPUT_NO_DEVICES': '1'})
        for name in ('WAYLAND_DISPLAY', 'SWAYSOCK', 'DISPLAY'):
            env.pop(name, None)
        sway = terminal = None
        try:
            with (private / 'sway.log').open('wb') as sway_log, (private / 'foot.log').open('wb') as foot_log:
                sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=sway_log, stderr=sway_log)
                ready = json.loads(read_fifo(ready_fifo, args.timeout, [sway]))
                env.update({'WAYLAND_DISPLAY': ready['wayland'], 'SWAYSOCK': ready['sway'],
                            'TERMCANVAS_MATRIX_BINARY': str(binary), 'TERMCANVAS_VISUAL_RENDERER_SHA256': binary_hash,
                            'TERMCANVAS_MATRIX_BATCH_SOCKET': str(socket_path)})
                launcher = ROOT / 'examples/visual_matrix/batch_launcher.py'
                terminal = subprocess.Popen(['foot', '--config=/dev/null', '--app-id=termcanvas-batch',
                    '--window-size-chars', f'{cols}x{rows}', '--font', args.font, '-o', 'main.pad=0x0',
                    sys.executable, str(launcher)], env=env, stdout=foot_log, stderr=foot_log)
                conn, _ = control.accept()
                with conn:
                    conn.settimeout(args.timeout)
                    stream = conn.makefile('rwb', buffering=0)
                    if receive(stream) != {'event': 'ready'}:
                        raise ValueError('invalid launcher readiness')
                    tree = json.loads(subprocess.check_output(['swaymsg', '-t', 'get_tree', '-r'], env=env, timeout=args.timeout))
                    window = tree_find(tree, 'termcanvas-batch')
                    if window is None:
                        raise ValueError('terminal window not found')
                    rect = window['rect']
                    geometry = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                    for case in pending:
                        verify_bound_inputs()
                        directory = output / case['id']
                        directory.mkdir(exist_ok=True)
                        attempts = [int(p.name.split('-')[-1]) for p in directory.glob('attempt-*') if p.name.split('-')[-1].isdigit()]
                        attempt = max(attempts, default=0) + 1
                        name = f'attempt-{attempt:06d}.png'
                        nonce = secrets.token_hex(8)
                        status = {'state': 'failed', 'case_id': case['id'], 'attempt': attempt, 'identity_sha256': identity_sha,
                                  'renderer_sha256': binary_hash, 'nonce': nonce}
                        write_json(directory / 'status.json', status)
                        send(stream, {'command': 'render', 'case': case, 'nonce': nonce})
                        report = receive(stream)
                        applied = {k: case[k] for k in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
                        expected = {'event': 'drawn', 'case_id': case['id'], 'nonce': nonce,
                                    'cells': case['terminal_cells'], 'renderer_sha256': binary_hash, 'applied': applied}
                        if report != expected:
                            raise ValueError('renderer readiness does not match case')
                        time.sleep(args.settle)
                        image = directory / name
                        subprocess.run(['grim', '-g', geometry, str(image)], env=env, check=True, timeout=args.timeout)
                        verify_nonce(image, case['terminal_cells'], nonce)
                        verify_bound_inputs()
                        image_hash, pixels = read_png(image)
                        status.update({'state': 'captured', 'sha256': image_hash, 'image': name, 'cells': case['terminal_cells'],
                                       'image_pixels': pixels, 'applied': applied, 'review_status': 'not_run',
                                       'backend': 'real-terminal', 'terminal': 'foot', 'compositor': 'sway headless pixman',
                                       'actual_color': 'truecolor', 'actual_glyphs': 'unknown',
                                       'source_revision_verified': False, 'build_source_link_verified': False})
                        write_json(directory / 'status.json', status)
                        send(stream, {'command': 'captured', 'case_id': case['id'], 'nonce': nonce})
                    send(stream, {'command': 'stop'})
                    return {'captured': len(pending), 'reused': len(cases) - len(pending), 'failed': 0,
                            'identity_sha256': identity_sha, 'delivery_ready': False, 'review_status': 'not_run',
                            'build_source_link_verified': False, 'source_revision_verified': False}
        except Exception:
            # Local diagnostics can include environment paths; never mark as a
            # deliverable until separately privacy-checked.
            for name in ('sway.log', 'foot.log'):
                path = private / name
                if path.exists():
                    shutil.copyfile(path, output / ('local-' + name))
            raise
        finally:
            control.close()
            stop(terminal)
            stop(sway)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=Path, required=True)
    parser.add_argument('--renderer', type=Path, required=True)
    parser.add_argument('--source-archive', type=Path, required=True)
    parser.add_argument('--source-revision', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--retry-failed', action='store_true')
    parser.add_argument('--font', default='monospace:size=14')
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--settle', type=float, default=0.3)
    args = parser.parse_args()
    try:
        if args.timeout <= 0 or args.settle < 0:
            raise ValueError('timeout must be positive and settle nonnegative')
        args.output.mkdir(parents=True, exist_ok=True)
        with (args.output / '.batch.lock').open('a+') as lock:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise ValueError('another batch holds this output directory') from error
            print(json.dumps(run(args)))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        print(json.dumps({'error': f'{type(error).__name__}: {error}'}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
