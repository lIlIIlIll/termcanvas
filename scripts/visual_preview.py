#!/usr/bin/env python3
"""Capture a provisional ordinary application preview in isolated Sway/Foot.

The application is not modified. A wrapper waits a fixed interval and reports
its actual PTY size; it cannot prove the application painted a complete frame.
Inspect the PNG and never treat this preview as a reviewed visual matrix. The
source is a verified dirty-worktree snapshot, not a claimed commit SHA.

Build binaries from a visual_snapshot.py snapshot first, with isolated target
and native build directories. Run with a private disk-backed TMPDIR.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

from visual_capture import read_fifo, stop, tree_find
from visual_evidence import read_png
from visual_snapshot import inventory, manifest


def launch_app(fifo, wait, binary, arguments):
    app = subprocess.Popen([binary, *arguments])
    try:
        try:
            code = app.wait(timeout=wait)
        except subprocess.TimeoutExpired:
            size = os.get_terminal_size()
            message = {'running': True, 'cells': [size.columns, size.lines]}
        else:
            message = {'running': False, 'exit_code': code}
        with open(fifo, 'w', encoding='utf-8') as stream:
            stream.write(json.dumps(message) + '\n')
        return app.wait() if message['running'] else message['exit_code']
    finally:
        stop(app)


def snapshot_digest(snapshot):
    recorded = json.loads((snapshot / 'snapshot-manifest.json').read_text(encoding='utf-8'))
    current = manifest(inventory(snapshot))
    if recorded != current:
        raise ValueError('snapshot source differs from its original manifest')
    return recorded['source_snapshot_sha256']


def verify_injection(transcript, injected, expected):
    """Check application output emitted after the private PTY injection."""
    found = False
    output = bytearray()
    for line in transcript.read_text(encoding='utf-8').splitlines():
        event = json.loads(line)
        if event['event'] == 'injected' and base64.b64decode(event['base64']) == injected:
            found = True
        elif found and event['event'] == 'output':
            output.extend(base64.b64decode(event['base64']))
    if not found:
        raise ValueError('requested input was not recorded in private PTY transcript')
    # Strip terminal control sequences so output text can be checked regardless
    # of color/style changes. This is evidence of output, not an OCR claim.
    plain = re.sub(rb'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\\\)|.)', b'', bytes(output))
    if expected.encode('utf-8') not in plain:
        raise ValueError(f'expected text after injection not observed: {expected!r}')
    return {'expected_output_after_input': expected, 'observed_in_pty_output': True}



def encode_gif(frame_directory, output, fps, env, timeout):
    """Build a palette from captured frames and avoid dithering flat surfaces."""
    filters = ('[0:v]split[image][palette_input];'
               '[palette_input]palettegen=stats_mode=full:reserve_transparent=0[palette];'
               '[image][palette]paletteuse=dither=none')
    subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-framerate', str(fps),
                    '-i', str(frame_directory / 'frame-%04d.png'), '-filter_complex', filters,
                    '-loop', '0', str(output)], env=env, check=True, timeout=max(timeout, 60))

def capture(args):
    if platform.system() != 'Linux':
        raise ValueError('isolated Sway preview is Linux-only')
    if (args.timeout <= 0 or args.wait <= 0 or args.settle < 0 or args.width <= 0 or args.height <= 0
            or args.gif_fps < 1 or args.gif_fps > 20 or args.gif_seconds <= 0 or args.gif_seconds > 30):
        raise ValueError('invalid timeout, wait or terminal size')
    if args.inject_hex:
        try:
            injected = bytes.fromhex(args.inject_hex)
        except ValueError as error:
            raise ValueError('invalid injection hex') from error
        if (not args.gif or not args.expect_after or not injected or len(injected) > 128 or
                args.inject_frame < 1 or args.inject_frame >= int(args.gif_fps * args.gif_seconds) - 1):
            raise ValueError('injection requires GIF, expected output, and an interior frame index')
    else:
        injected = None
        if args.expect_after:
            raise ValueError('expected output requires injection')
    source = args.snapshot.resolve(strict=True)
    source_hash = snapshot_digest(source)
    binary = args.binary.resolve(strict=True)
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    image = args.image.resolve()
    metadata = args.metadata.resolve()
    gif = args.gif.resolve() if args.gif else None
    if image.exists() or metadata.exists() or (gif and gif.exists()):
        raise ValueError('image, GIF and metadata paths must not already exist')
    image.parent.mkdir(parents=True, exist_ok=True)
    metadata.parent.mkdir(parents=True, exist_ok=True)
    if gif:
        gif.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    runtime_base = args.runtime_base or env.get('XDG_RUNTIME_DIR')
    if not runtime_base:
        raise ValueError('set XDG_RUNTIME_DIR or pass --runtime-base for Wayland sockets')
    with tempfile.TemporaryDirectory(prefix='visual-preview-') as directory, \
            tempfile.TemporaryDirectory(prefix='tcv-', dir=runtime_base) as runtime_directory:
        private = Path(directory)
        runtime = Path(runtime_directory)
        if len(os.fsencode(str(runtime))) > 70:
            raise ValueError('runtime socket path is too long; use a shorter --runtime-base')
        sway_fifo, app_fifo = private / 'sway-ready', private / 'app-ready'
        control_fifo = private / 'input-control'
        transcript = gif.with_name(gif.stem + '-pty.jsonl') if injected else None
        if transcript and transcript.exists():
            raise ValueError('PTY transcript path must not already exist')
        os.mkfifo(sway_fifo, 0o600)
        os.mkfifo(app_fifo, 0o600)
        if injected:
            os.mkfifo(control_fifo, 0o600)
        config = private / 'sway.conf'
        ready_command = ' '.join(shlex.quote(x) for x in (sys.executable,
            str(Path(__file__).with_name('visual_capture.py').resolve()), '--sway-ready', str(sway_fifo)))
        config.write_text('output HEADLESS-1 resolution 3840x2160\n'
                          'default_border none\n'
                          'for_window [app_id="termcanvas-visual-preview"] floating enable, move position 0 0, border none\n'
                          f'exec {ready_command}\n', encoding='utf-8')
        env.update({'XDG_RUNTIME_DIR': str(runtime), 'WLR_BACKENDS': 'headless', 'WLR_RENDERER': 'pixman',
                    'WLR_LIBINPUT_NO_DEVICES': '1'})
        for key in ('WAYLAND_DISPLAY', 'SWAYSOCK', 'DISPLAY'):
            env.pop(key, None)
        sway = terminal = None
        try:
            with (private / 'sway.log').open('wb') as sway_log, (private / 'foot.log').open('wb') as foot_log:
                sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=sway_log, stderr=sway_log)
                ready = json.loads(read_fifo(sway_fifo, args.timeout, [sway]))
                env.update({'WAYLAND_DISPLAY': ready['wayland'], 'SWAYSOCK': ready['sway']})
                app_command = [str(binary), *args.arguments]
                if injected:
                    app_command = [sys.executable, str(Path(__file__).with_name('visual_pty.py').resolve()),
                                   '--control', str(control_fifo), '--transcript', str(transcript), '--', *app_command]
                command = [sys.executable, str(Path(__file__).resolve()), '--launch-app', str(app_fifo),
                           str(args.wait), *app_command]
                terminal = subprocess.Popen(['foot', '--config=/dev/null', '--app-id=termcanvas-visual-preview',
                    '--window-size-chars', f'{args.width}x{args.height}', '--font', args.font,
                    '-o', 'main.pad=0x0', *command], env=env, stdout=foot_log, stderr=foot_log)
                started = json.loads(read_fifo(app_fifo, args.timeout + args.wait, [sway, terminal]))
                if not started.get('running'):
                    raise ValueError(f"application exited before preview: {started.get('exit_code')}")
                if started.get('cells') != [args.width, args.height]:
                    raise ValueError('PTY size does not match requested terminal dimensions')
                time.sleep(args.settle)
                if terminal.poll() is not None:
                    raise ValueError('terminal exited before screenshot')
                tree = json.loads(subprocess.check_output(['swaymsg', '-t', 'get_tree', '-r'], env=env, timeout=args.timeout))
                window = tree_find(tree, 'termcanvas-visual-preview')
                if window is None:
                    raise ValueError('terminal window not found')
                rect = window['rect']
                geometry = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                subprocess.run(['grim', '-g', geometry, str(image)], env=env, check=True, timeout=args.timeout)
                image_hash, pixels = read_png(image)
                animation = None
                if gif:
                    frames = max(1, int(args.gif_fps * args.gif_seconds))
                    started_at = time.monotonic()
                    frame_times = []
                    for index in range(frames):
                        delay = started_at + index / args.gif_fps - time.monotonic()
                        if delay > 0:
                            time.sleep(delay)
                        if terminal.poll() is not None:
                            raise ValueError('terminal exited during GIF recording')
                        if injected and index == args.inject_frame:
                            control = os.open(control_fifo, os.O_WRONLY | os.O_NONBLOCK)
                            try:
                                os.write(control, json.dumps({'hex': injected.hex()}).encode() + b'\n')
                            finally:
                                os.close(control)
                        frame = private / f'frame-{index:04d}.png'
                        subprocess.run(['grim', '-g', geometry, str(frame)], env=env, check=True, timeout=args.timeout)
                        frame_times.append(round(time.monotonic() - started_at, 3))
                        if injected and index in (args.inject_frame - 1, frames - 1):
                            suffix = '-before.png' if index == args.inject_frame - 1 else '-after.png'
                            shutil.copyfile(frame, gif.with_name(gif.stem + suffix))
                    encode_gif(private, gif, args.gif_fps, env, args.timeout)
                    observation = verify_injection(transcript, injected, args.expect_after) if injected else None
                    animation = {'file': gif.name, 'sha256': hashlib.sha256(gif.read_bytes()).hexdigest(),
                                 'frames': frames, 'nominal_fps': args.gif_fps, 'frame_capture_seconds': frame_times,
                                 'source': 'consecutive real-terminal screenshots',
                                 'encoding': 'ffmpeg full-frame palette; dithering disabled',
                                 'interaction': 'private PTY injection' if injected else 'none; live default application state',
                                 'injected_hex': injected.hex() if injected else None,
                                 'input_frame': args.inject_frame if injected else None,
                                 'transcript': transcript.name if injected else None, 'observation': observation}
                if snapshot_digest(source) != source_hash:
                    raise ValueError('snapshot changed during preview')
                versions = {p: subprocess.check_output([p, '--version'], text=True, timeout=args.timeout).strip()
                            for p in ('foot', 'sway')}
                font = subprocess.check_output(['fc-match', '-f', '%{family}|%{style}|%{fontversion}', args.font],
                                               text=True, timeout=args.timeout).strip()
                result = {'kind': 'provisional-dirty-worktree-preview', 'reviewed': False,
                    'source_snapshot_sha256': source_hash, 'binary_sha256': binary_hash,
                    'capture_backend': 'real-terminal-preview', 'platform': 'Linux',
                    'terminal': versions['foot'], 'compositor': versions['sway'] + ' headless pixman',
                    'font_request': args.font, 'font_resolved': font, 'actual_color': 'truecolor',
                    'actual_glyphs': 'unknown', 'terminal_cells': started['cells'],
                    'image': image.name, 'image_sha256': image_hash, 'image_pixels': list(pixels),
                    'application_arguments': args.arguments,
                    'readiness': 'process alive after time-based wait; painted frame not automatically verified',
                    'application_wait_seconds': args.wait, 'compositor_settle_seconds': args.settle,
                    'animation': animation}
                metadata.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
                return result
        except Exception:
            for log_name in ('sway.log', 'foot.log'):
                if (private / log_name).exists():
                    shutil.copyfile(private / log_name, metadata.with_name(metadata.name + '.' + log_name))
            raise
        finally:
            stop(terminal)
            stop(sway)


def main():
    if len(sys.argv) >= 5 and sys.argv[1] == '--launch-app':
        return launch_app(sys.argv[2], float(sys.argv[3]), sys.argv[4], sys.argv[5:])
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--snapshot', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--metadata', type=Path, required=True)
    parser.add_argument('--width', type=int, default=120)
    parser.add_argument('--height', type=int, default=36)
    parser.add_argument('--font', default='monospace:size=14')
    parser.add_argument('--runtime-base')
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--wait', type=float, default=2)
    parser.add_argument('--settle', type=float, default=0.5)
    parser.add_argument('--gif', type=Path, help='encode consecutive real screenshots as an animation')
    parser.add_argument('--gif-fps', type=int, default=4)
    parser.add_argument('--gif-seconds', type=float, default=4)
    parser.add_argument('--inject-hex', help='private PTY input bytes as hex; requires GIF and --expect-after')
    parser.add_argument('--inject-frame', type=int, default=6)
    parser.add_argument('--expect-after', help='required application output following input')
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.arguments and args.arguments[0] == '--':
        args.arguments = args.arguments[1:]
    try:
        print(json.dumps(capture(args), ensure_ascii=False, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, TimeoutError) as error:
        print(json.dumps({'kind': 'provisional-dirty-worktree-preview', 'passed': False,
                          'error': f'{type(error).__name__}: {error}'}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
