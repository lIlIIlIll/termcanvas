#!/usr/bin/env python3
"""Capture one application state using isolated headless Sway, Foot and Grim.

The launcher must draw the requested state and write one JSON line to the FIFO
in TERMCANVAS_VISUAL_READY_FIFO after the renderer flushes its terminal output.
The report includes case_id, renderer_sha256, the measured PTY cells, and an
applied object containing subject, state, theme, glyph, color and widget_cells.
widget_cells is the requested allocation, not the effective drawing rectangle.
For a v2 case, renderer_geometry must also report effective_rect, target_width,
and source='renderer-self-report-not-pixel-measurement'. The effective rectangle
is reported by the renderer; it is not an independent measurement of pixels.

The requested case is provided as JSON in TERMCANVAS_VISUAL_CASE. Keep the app
running until capture. Application reports do not independently verify output,
and this command does not perform visual review.

Example (the launcher must implement the ready FIFO contract):
  python scripts/visual_capture.py --case matrix-case.json --binary ./launcher --renderer ./renderer \
      --source-sha <source-sha> --source-archive sources.tar --image capture.png --metadata capture.json

Use a private disk-backed TMPDIR. Application color and glyph overrides do not
establish the actual terminal capabilities. The fontconfig candidate does not
prove the font or fallback used for each glyph.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import selectors
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def write_ready(path):
    with open(path, 'w', encoding='utf-8') as stream:
        json.dump({'wayland': os.environ['WAYLAND_DISPLAY'], 'sway': os.environ['SWAYSOCK']}, stream)
        stream.write('\n')


def read_fifo(path, timeout, processes):
    # Open read/write so a writer that has not opened yet is not confused with
    # EOF. The deadline bounds both compositor and application readiness.
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    selector = selectors.DefaultSelector()
    selector.register(fd, selectors.EVENT_READ)
    try:
        deadline = time.monotonic() + timeout
        contents = bytearray()
        while True:
            events = selector.select(max(0, deadline - time.monotonic()))
            if not events:
                raise TimeoutError('timed out waiting for compositor/application readiness')
            for _key, _mask in events:
                contents.extend(os.read(fd, 65536))
                if b'\n' in contents:
                    return bytes(contents).split(b'\n', 1)[0].decode('utf-8')
            if any(p.poll() is not None for p in processes):
                raise RuntimeError('compositor or terminal exited before readiness')
    finally:
        selector.close()
        os.close(fd)


def stop(process):
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def unblock_child_signals():
    # This CLI is single-threaded. Children must not inherit the parent's
    # temporary Popen signal mask after exec.
    signal.pthread_sigmask(signal.SIG_UNBLOCK, (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))


def tree_find(node, app_id):
    if node.get('app_id') == app_id:
        return node
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        found = tree_find(child, app_id)
        if found is not None:
            return found
    return None


def validate_ready(raw, case, renderer_sha256):
    report = json.loads(raw)
    if not isinstance(report, dict) or report.get('case_id') != case['id']:
        raise ValueError('application readiness case id does not match')
    if report.get('renderer_sha256') != renderer_sha256:
        raise ValueError('application renderer hash does not match supplied renderer')
    if report.get('cells') != case['terminal_cells']:
        raise ValueError('application did not report the requested terminal size')
    expected = {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
    if report.get('applied') != expected:
        raise ValueError('application did not report applying the requested visual state')
    if case.get('case_schema_version') == 2:
        from visual_evidence import validate_case_geometry
        if report.get('renderer_geometry') != validate_case_geometry(case):
            raise ValueError('application renderer geometry mismatch')
    return report


def isolated_config_environment(env, private):
    """Keep both user and system XDG config lookup inside empty private roots."""
    config_home = private / 'xdg-config-home'
    config_dirs = private / 'xdg-config-dirs'
    config_home.mkdir(mode=0o700)
    config_dirs.mkdir(mode=0o700)
    env.update({'XDG_CONFIG_HOME': str(config_home), 'XDG_CONFIG_DIRS': str(config_dirs)})


def foot_command(width, height, font, binary, arguments):
    return ['foot', '--config=/dev/null', '--app-id=termcanvas-visual-capture',
            '--window-size-chars', f'{width}x{height}', '--font', font,
            '-o', 'main.pad=0x0', str(binary), *arguments]


def environment_metadata(env, font, timeout):
    # fc-match identifies a fontconfig candidate, not necessarily the font or
    # fallback chosen by Foot for every rendered glyph.
    primary_request = font.split(',', 1)[0].strip()
    match = subprocess.check_output(
        ['fc-match', '-f', '%{family}|%{style}|%{fontversion}\n%{file}', primary_request],
        env=env, text=True, timeout=timeout)
    description, separator, filename = match.partition('\n')
    if not separator or not filename:
        raise ValueError('fontconfig did not report a primary font candidate')
    candidate = Path(filename)
    font_hash = hashlib.sha256(candidate.read_bytes()).hexdigest()
    locale_result = subprocess.run(['locale', 'charmap'], env=env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    locale_info = {name: env.get(name) for name in ('LC_ALL', 'LC_CTYPE', 'LANG', 'LANGUAGE')}
    locale_info['charmap'] = locale_result.stdout.strip() if locale_result.returncode == 0 else 'unknown'
    return {'font': description, 'font_version': description.split('|')[-1] or 'unknown',
            'fontconfig_candidate': {'request': primary_request, 'sha256': font_hash,
                                     'scope': 'fc-match candidate; actual glyph fonts and fallback unverified'},
            'locale': locale_info,
            'foot_config': {'source': '/dev/null', 'xdg_config_roots': 'isolated empty directories'}}


def run(args):
    if platform.system() != 'Linux':
        raise ValueError('isolated Sway capture is Linux-only')
    case = json.loads(args.case.read_text(encoding='utf-8'))
    from visual_evidence import canonical, digest, read_png, SHA
    payload = {k: v for k, v in case.items() if k != 'id'}
    if case.get('id') != digest(canonical(payload)):
        raise ValueError('case id does not match its parameters')
    if not SHA.fullmatch(args.source_sha):
        raise ValueError('source-sha must be a full source revision')
    if args.timeout <= 0 or args.settle < 0:
        raise ValueError('invalid timeout or settle interval')
    width, height = case['terminal_cells']
    if type(width) is not int or type(height) is not int or width <= 0 or height <= 0:
        raise ValueError('terminal dimensions must be positive integer cells')
    binary = args.binary.resolve(strict=True)
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    renderer = args.renderer.resolve(strict=True)
    renderer_hash = hashlib.sha256(renderer.read_bytes()).hexdigest()
    archive_hash = hashlib.sha256(args.source_archive.resolve(strict=True).read_bytes()).hexdigest()
    image = args.image.resolve()
    image.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    runtime_base = args.runtime_base or env.get('XDG_RUNTIME_DIR')
    if not runtime_base:
        raise ValueError('set XDG_RUNTIME_DIR or pass --runtime-base for short-lived Wayland sockets')
    # Unix socket paths have a small kernel limit. Use a short private runtime
    # directory for sockets only; logs and image artifacts remain in TMPDIR.
    with tempfile.TemporaryDirectory(prefix='visual-capture-') as directory, \
            tempfile.TemporaryDirectory(prefix='tcv-', dir=runtime_base) as runtime_directory:
        private = Path(directory)
        runtime = Path(runtime_directory)
        if len(os.fsencode(str(runtime))) > 70:
            raise ValueError('runtime socket path is too long; use a shorter --runtime-base')
        sway_fifo = private / 'sway-ready'
        app_fifo = private / 'app-ready'
        os.mkfifo(sway_fifo, 0o600)
        os.mkfifo(app_fifo, 0o600)
        config = private / 'sway.conf'
        ready_command = ' '.join(shlex.quote(x) for x in (sys.executable, str(Path(__file__).resolve()),
                                                         '--sway-ready', str(sway_fifo)))
        config.write_text('output HEADLESS-1 resolution 3840x2160\n'
                          'default_border none\n'
                          'for_window [app_id="termcanvas-visual-capture"] floating enable, move position 0 0, border none\n'
                          f'exec {ready_command}\n', encoding='utf-8')
        isolated_config_environment(env, private)
        env.update({'XDG_RUNTIME_DIR': str(runtime), 'WLR_BACKENDS': 'headless', 'WLR_RENDERER': 'pixman',
                    'WLR_LIBINPUT_NO_DEVICES': '1'})
        for name in ('WAYLAND_DISPLAY', 'SWAYSOCK', 'DISPLAY'):
            env.pop(name, None)
        sway = terminal = None
        try:
            with (private / 'sway.log').open('wb') as sway_log, (private / 'foot.log').open('wb') as foot_log:
                oldmask = signal.pthread_sigmask(signal.SIG_BLOCK, (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))
                try:
                    sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=sway_log, stderr=sway_log,
                                            preexec_fn=unblock_child_signals)
                finally:
                    signal.pthread_sigmask(signal.SIG_SETMASK, oldmask)
                ready = json.loads(read_fifo(sway_fifo, args.timeout, [sway]))
                env.update({'WAYLAND_DISPLAY': ready['wayland'], 'SWAYSOCK': ready['sway'],
                            'TERMCANVAS_VISUAL_READY_FIFO': str(app_fifo),
                            'TERMCANVAS_VISUAL_CASE': json.dumps(case, ensure_ascii=False),
                            'TERMCANVAS_VISUAL_RENDERER_SHA256': renderer_hash})
                oldmask = signal.pthread_sigmask(signal.SIG_BLOCK, (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))
                try:
                    terminal = subprocess.Popen(foot_command(width, height, args.font, binary, args.arguments),
                        env=env, stdout=foot_log, stderr=foot_log, preexec_fn=unblock_child_signals)
                finally:
                    signal.pthread_sigmask(signal.SIG_SETMASK, oldmask)
                ready_report = validate_ready(read_fifo(app_fifo, args.timeout, [sway, terminal]), case, renderer_hash)
                # The marker follows the application flush, not compositor frame
                # presentation. Allow the compositor to present before capture.
                time.sleep(args.settle)
                tree = json.loads(subprocess.check_output(['swaymsg', '-t', 'get_tree', '-r'], env=env, timeout=args.timeout))
                window = tree_find(tree, 'termcanvas-visual-capture')
                if window is None:
                    raise ValueError('terminal window not found in isolated compositor')
                rect = window['rect']
                geometry = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                subprocess.run(['grim', '-g', geometry, str(image)], env=env, check=True, timeout=args.timeout)
                image_hash, pixels = read_png(image)
                versions = {}
                for program in ('foot', 'sway'):
                    versions[program] = subprocess.check_output([program, '--version'], text=True, timeout=args.timeout).strip()
                environment = environment_metadata(env, args.font, args.timeout)
                metadata = {'case_id': case['id'], 'image': image.name, 'sha256': image_hash,
                    'source_sha': args.source_sha, 'source_archive_sha256': archive_hash,
                    'binary_sha256': binary_hash, 'renderer_sha256': renderer_hash, 'backend': 'real-terminal',
                    'platform': 'Linux', 'terminal': 'foot', 'terminal_version': versions['foot'],
                    'compositor': versions['sway'] + ' headless pixman', **environment, 'actual_color': 'truecolor',
                    'actual_glyphs': 'unknown', 'app_color': case['color'], 'app_glyphs': case['glyph'],
                    'cells': ready_report['cells'], 'app_report': ready_report, 'image_pixels': list(pixels),
                    'geometry_evidence': ('renderer-self-report-not-pixel-measurement' if
                                          case.get('case_schema_version') == 2 else 'legacy-unverified'),
                    'capture_parameters': {'font_request': args.font, 'settle_seconds': args.settle,
                                           'arguments': args.arguments}}
                args.metadata.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
                return metadata
        except Exception:
            # Preserve failure evidence next to the requested metadata; the
            # private compositor directory itself is cleaned on exit.
            for log_name in ('sway.log', 'foot.log'):
                source_log = private / log_name
                if source_log.exists():
                    destination = args.metadata.with_name(args.metadata.name + '.' + log_name)
                    shutil.copyfile(source_log, destination)
            raise
        finally:
            oldmask = signal.pthread_sigmask(signal.SIG_BLOCK, (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))
            try:
                stop(terminal)
                stop(sway)
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, oldmask)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--sway-ready':
        write_ready(sys.argv[2])
        return 0
    def interrupt(signum, _frame):
        for item in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            signal.signal(item, signal.SIG_IGN)
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, interrupt)
    signal.signal(signal.SIGHUP, interrupt)
    signal.signal(signal.SIGINT, interrupt)
    # The runner blocks signals around Popen; remove the inherited mask only
    # after our cleanup handlers are installed.
    signal.pthread_sigmask(signal.SIG_UNBLOCK, (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True, help='actual launcher executable')
    parser.add_argument('--renderer', type=Path, required=True, help='actual renderer executable (may equal launcher)')
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--source-archive', type=Path, required=True, help='archived actual source inputs; not proof of build provenance')
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--metadata', type=Path, required=True)
    parser.add_argument('--runtime-base', help='short-lived private Unix-socket directory parent (default: XDG_RUNTIME_DIR)')
    parser.add_argument('--font', default='monospace:size=14')
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--settle', type=float, default=0.3)
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.arguments and args.arguments[0] == '--':
        args.arguments = args.arguments[1:]
    try:
        print(json.dumps(run(args), ensure_ascii=False, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, TimeoutError) as error:
        print(json.dumps({'passed': False, 'error': f'{type(error).__name__}: {error}'}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
