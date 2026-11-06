#!/usr/bin/env python3
"""Capture a bounded, resumable subset of the declared Linux visual matrix.

Each case runs the repository's real Sway/Foot/Grim capture in its own attempt
folder. The supplied revision is a *declared reference*: neither a clean
worktree nor a binary-to-source build relationship is inferred. Dirty-source
runs are explicitly marked provisional. Run identity binds the source archive,
launcher, renderer, inventory, capture/runtime scripts, sample files, terminal
tools, Python and relevant environment. Changed inputs require a new output
folder. Successful images are revalidated before reuse; failed or damaged
cases run only with --retry-failed. Limits apply to captures, never coverage.

Example:
  python scripts/visual_matrix_runner.py --launcher examples/visual_matrix/launch.py \\
    --renderer /path/to/main --source-archive /path/to/sources.tar \\
    --source-revision <full-sha> --source-kind dirty-worktree --output /path/to/run \\
    --subject core.Button --limit 2

New runs start with no review records. On resume, evidence.json retains current
records from imported review reports; stale records are excluded and counted.
Records do not prove reviewer identity or that an image was viewed. A completed
capture is not visual review, and project coverage is not asserted.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import selectors
import secrets
import shutil
import signal
import subprocess
import sys
import tempfile

from visual_evidence import (SHA, canonical, collect_review_reports, digest, matrix_from_inventory,
                             read_png, verify_local_build_record)
from visual_capture import environment_metadata, isolated_config_environment

ROOT = Path(__file__).resolve().parents[1]
STOP_SIGNALS = (signal.SIGTERM, signal.SIGHUP, signal.SIGINT)


def sha_file(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.visual-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False, sort_keys=True)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def runtime_inputs(launcher):
    # The repository fixture imports these files at runtime. Bind their actual
    # bytes, including every sample file, rather than only hashing launch.py.
    fixture_root = launcher.resolve(strict=True).parents[2]
    paths = [fixture_root / 'scripts/visual_inventory.py', fixture_root / 'scripts/visual_inventory.json',
             fixture_root / 'scripts/visual_evidence.py']
    sample = fixture_root / 'examples/visual_matrix/sample'
    if not sample.is_dir():
        raise ValueError('launcher fixture sample directory is missing')
    for path in sorted(sample.rglob('*')):
        if path.is_symlink():
            raise ValueError('symlinked sample inputs are unsupported')
        if path.is_file():
            paths.append(path)
    return {path.relative_to(fixture_root).as_posix(): sha_file(path) for path in paths}


def tool_identity():
    result = {}
    for name in ('sway', 'swaymsg', 'foot', 'grim', 'fc-match', 'locale'):
        path = shutil.which(name)
        if not path:
            raise ValueError(f'missing terminal capture tool: {name}')
        result[name] = sha_file(Path(path).resolve(strict=True))
    result['python'] = sha_file(Path(sys.executable).resolve(strict=True))
    return result


def tool_versions(timeout):
    return {name: subprocess.check_output([name, '--version'], text=True, timeout=timeout).strip()
            for name in ('foot', 'sway')}


def terminal_configuration(font, timeout):
    """Probe the same isolated config policy used by the real capture."""
    env = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix='visual-identity-') as directory:
        isolated_config_environment(env, Path(directory))
        facts = environment_metadata(env, font, timeout)
    if (not facts.get('locale', {}).get('charmap') or facts['locale']['charmap'] == 'unknown' or
            not isinstance(facts.get('fontconfig_candidate', {}).get('sha256'), str)):
        raise ValueError('font candidate or locale unavailable for reproducible capture')
    return facts


def verify_build_record(path, args):
    """Check a local build record and archive; this is not an attestation."""
    if args.source_kind != 'dirty-worktree':
        raise ValueError('build record does not match requested capture inputs')
    launcher_sha, renderer_sha = sha_file(args.launcher), sha_file(args.renderer)
    record, hashes = verify_local_build_record(path, args.source_archive, args.source_revision,
                                               {launcher_sha, renderer_sha})
    if record['launcher_sha256'] != launcher_sha or record['renderer_sha256'] != renderer_sha:
        raise ValueError('build record does not match requested capture inputs')
    actual = runtime_inputs(args.launcher)
    expected = {name: value for name, value in hashes.items() if name in
                ('scripts/visual_inventory.py', 'scripts/visual_inventory.json', 'scripts/visual_evidence.py')
                or name.startswith('examples/visual_matrix/sample/')}
    if actual != expected:
        raise ValueError('launcher runtime input differs from source archive')
    for name in ('visual_capture.py', 'visual_matrix_runner.py', 'visual_evidence.py'):
        if hashes.get('scripts/' + name) != sha_file(ROOT / 'scripts' / name):
            raise ValueError('capture tool differs from source archive')
    return sha_file(path)


def identity(args, inventory):
    launcher, renderer, archive = (p.resolve(strict=True) for p in
                                   (args.launcher, args.renderer, args.source_archive))
    if not SHA.fullmatch(args.source_revision):
        raise ValueError('source revision must be a full hexadecimal SHA-1 or SHA-256')
    if not launcher.is_file() or not renderer.is_file() or not archive.is_file():
        raise ValueError('launcher, renderer and source archive must be regular files')
    fixture_inventory = launcher.parents[2] / 'scripts/visual_inventory.json'
    if json.loads(fixture_inventory.read_text(encoding='utf-8')) != inventory:
        raise ValueError('requested inventory differs from launcher runtime inventory')
    env_names = {'LANG', 'LANGUAGE', 'LC_ALL', 'LC_CTYPE', 'TERM', 'COLORTERM', 'LD_LIBRARY_PATH', 'PATH',
                 'HOME', 'FONTCONFIG_FILE', 'FONTCONFIG_PATH', 'XDG_DATA_HOME', 'XDG_DATA_DIRS', 'XDG_CACHE_HOME'}
    env_names.update(name for name in os.environ if name.startswith('LC_'))
    environment = {name: digest(os.environ.get(name, '').encode('utf-8')) for name in sorted(env_names)}
    build_record = getattr(args, 'build_record', None)
    record_sha = verify_build_record(build_record, args) if build_record else None
    return {'version': 2, 'source_kind': args.source_kind, 'source_revision_declared': args.source_revision,
            'revision_verified': False, 'build_source_link_verified': False, 'matrix_schema_version': 2,
            'local_build_record_sha256': record_sha,
            'source_archive_sha256': sha_file(archive), 'launcher_sha256': sha_file(launcher),
            'renderer_sha256': sha_file(renderer), 'inventory_sha256': digest(canonical(inventory)),
            'runner_sha256': sha_file(Path(__file__)), 'capture_sha256': sha_file(ROOT / 'scripts/visual_capture.py'),
            'runtime_inputs': runtime_inputs(launcher), 'terminal_tools_sha256': tool_identity(),
            'terminal_tool_versions': tool_versions(args.timeout),
            'terminal_configuration': terminal_configuration(args.font, args.timeout),
            'environment_sha256': environment, 'font': args.font, 'settle_seconds': args.settle,
            'timeout_seconds': args.timeout}


def selected(case, args):
    for attr in ('subject', 'state', 'theme', 'glyph', 'color'):
        values = getattr(args, attr)
        if values and case[attr] not in values:
            return False
    if args.terminal and f"{case['terminal_cells'][0]}x{case['terminal_cells'][1]}" not in args.terminal:
        return False
    return not args.widget_size or f"{case['widget_cells'][0]}x{case['widget_cells'][1]}" in args.widget_size


def valid_capture(case, case_dir, expected):
    """Return verified metadata or None; never trust a stale success marker."""
    try:
        status = json.loads((case_dir / 'status.json').read_text(encoding='utf-8'))
        if (status.get('state') != 'captured' or status.get('cleanup_confirmation_required') is not False or
                status.get('run_identity_sha256') != expected['identity_sha256']):
            return None
        attempt = status['attempt']
        if type(attempt) is not int or attempt < 1:
            return None
        directory = case_dir / f'attempt-{attempt:06d}'
        meta = json.loads((directory / 'capture.json').read_text(encoding='utf-8'))
        image = directory / 'capture.png'
        image_hash, pixels = read_png(image)
        report = meta['app_report']
        required_fields = ('terminal', 'terminal_version', 'compositor', 'font', 'font_version',
                           'actual_color', 'actual_glyphs', 'capability_scope')
        if not all(isinstance(meta.get(field), str) and meta[field].strip() for field in required_fields):
            return None
        facts = expected['terminal_configuration']
        if any(meta.get(key) != value for key, value in facts.items()):
            return None
        versions = expected['terminal_tool_versions']
        if (meta.get('terminal') != 'foot' or meta.get('terminal_version') != versions['foot'] or
                meta.get('compositor') != versions['sway'] + ' headless pixman'):
            return None
        from visual_evidence import GEOMETRY_SOURCE, validate_case_geometry
        if (case.get('case_schema_version') != 2 or meta.get('geometry_evidence') != GEOMETRY_SOURCE or
                report.get('renderer_geometry') != validate_case_geometry(case)):
            return None
        applied = {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        if not (meta['case_id'] == case['id'] and meta['sha256'] == image_hash and
                meta['run_identity_sha256'] == expected['identity_sha256'] and
                meta['source_kind'] == expected['source_kind'] and meta['source_revision_verified'] is False and
                meta['build_source_link_verified'] is False and
                meta.get('local_build_record_sha256') == expected.get('local_build_record_sha256') and
                meta['source_sha'] == expected['source_revision_declared'] and
                meta['source_archive_sha256'] == expected['source_archive_sha256'] and
                meta['binary_sha256'] == expected['launcher_sha256'] and
                meta['renderer_sha256'] == expected['renderer_sha256'] and
                meta['backend'] == 'real-terminal' and meta['platform'] == 'Linux' and
                meta['cells'] == case['terminal_cells'] and meta['app_color'] == case['color'] and
                meta['app_glyphs'] == case['glyph'] and report['case_id'] == case['id'] and
                report['renderer_sha256'] == expected['renderer_sha256'] and
                report['cells'] == case['terminal_cells'] and report['applied'] == applied and
                pixels[0] >= case['terminal_cells'][0] and pixels[1] >= case['terminal_cells'][1]):
            return None
        meta['image'] = image.relative_to(case_dir.parent.parent).as_posix()
        return meta
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None


def cleanup_confirmation_pending(case_root):
    for path in case_root.iterdir():
        if not path.is_dir():
            continue
        try:
            status = json.loads((path / 'status.json').read_text(encoding='utf-8'))
            if status.get('cleanup_confirmation_required') is not False:
                return True
        except (OSError, ValueError, TypeError, AttributeError):
            return True
    return False


def archive_input(src, destination, expected_hash):
    if destination.exists():
        if not destination.is_file() or sha_file(destination) != expected_hash:
            raise ValueError(f'archived input changed: {destination.name}')
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.visual-copy-', dir=destination.parent)
    os.close(fd)
    try:
        shutil.copyfile(src, tmp)
        if sha_file(Path(tmp)) != expected_hash:
            raise ValueError(f'input changed during archive: {Path(src).name}')
        os.replace(tmp, destination)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def terminate_capture_group(process, pidfd=None):
    """Kill the private group while its unreaped leader still reserves its PID."""
    owned_fd = pidfd is None
    if owned_fd:
        pidfd = os.pidfd_open(process.pid)
    try:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        with selectors.DefaultSelector() as selector:
            selector.register(pidfd, selectors.EVENT_READ)
            selector.select(5)
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)
    finally:
        if owned_fd:
            os.close(pidfd)


def interrupt_signal(signum, _frame):
    for item in STOP_SIGNALS:
        signal.signal(item, signal.SIG_IGN)
    raise SystemExit(128 + signum)


def run_capture_process(cmd, env, log, timeout):
    """Keep the leader unreaped until group cleanup, even on signal/timeout."""
    if not hasattr(os, 'pidfd_open'):
        raise ValueError('Linux pidfd support is required for safe capture cleanup')
    if signal.getsignal(signal.SIGCHLD) != signal.SIG_DFL:
        raise ValueError('SIGCHLD must have the default disposition for safe capture cleanup')
    process = None
    pidfd = None
    try:
        previous = signal.pthread_sigmask(signal.SIG_BLOCK, STOP_SIGNALS)
        try:
            process = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            pidfd = os.pidfd_open(process.pid)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous)
        with selectors.DefaultSelector() as selector:
            selector.register(pidfd, selectors.EVENT_READ)
            if not selector.select(timeout):
                raise subprocess.TimeoutExpired(cmd, timeout)
    finally:
        previous = signal.pthread_sigmask(signal.SIG_BLOCK, STOP_SIGNALS)
        try:
            if process is not None:
                # No poll/wait before killpg: the unreaped PID prevents reuse.
                if pidfd is None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=5)
                else:
                    terminate_capture_group(process, pidfd)
            if pidfd is not None:
                os.close(pidfd)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous)
    return process.returncode


def capture(case, case_dir, args, run_id, current_identity):
    case_dir.mkdir(parents=True, exist_ok=True)
    existing = sorted(p for p in case_dir.glob('attempt-*') if p.is_dir())
    numbers = [int(p.name.removeprefix('attempt-')) for p in existing if p.name.removeprefix('attempt-').isdigit()]
    attempt = max(numbers, default=0) + 1
    directory = case_dir / f'attempt-{attempt:06d}'
    directory.mkdir()
    raw = directory / 'raw'
    raw.mkdir()
    write_json(directory / 'case.json', case)
    env = os.environ.copy()
    env['TERMCANVAS_MATRIX_BINARY'] = str(args.renderer.resolve(strict=True))
    cmd = [sys.executable, str(ROOT / 'scripts/visual_capture.py'), '--case', str(directory / 'case.json'),
           '--binary', str(args.launcher.resolve(strict=True)), '--renderer', str(args.renderer.resolve(strict=True)),
           '--source-sha', args.source_revision, '--source-archive', str(args.source_archive.resolve(strict=True)),
           '--image', str(directory / 'capture.png'), '--metadata', str(directory / 'capture.json'),
           '--font', args.font, '--timeout', str(args.timeout), '--settle', str(args.settle)]
    if args.runtime_base:
        cmd += ['--runtime-base', args.runtime_base]
    status = {'state': 'failed', 'attempt': attempt, 'run_identity_sha256': run_id,
              'review_status': 'not_run', 'reason': 'capture did not complete',
              'cleanup_confirmation_required': True}
    # Persist before launch, so interrupts and crashes cannot appear as success.
    write_json(case_dir / 'status.json', status)
    try:
        with (raw / 'capture.log').open('w', encoding='utf-8') as log:
            returncode = run_capture_process(cmd, env, log, max(30, args.timeout * 4))
        for diagnostic in directory.glob('capture.json.*.log'):
            shutil.move(str(diagnostic), raw / diagnostic.name)
        if returncode:
            status['reason'] = f'capture exited {returncode}; see local raw/capture.log'
        elif identity(args, current_identity['inventory']) != {key: value for key, value in
                current_identity['identity'].items() if key != 'run_nonce'}:
            status['reason'] = 'bound runtime inputs changed during capture'
        else:
            meta = json.loads((directory / 'capture.json').read_text(encoding='utf-8'))
            meta.update({'source_kind': args.source_kind, 'source_revision_verified': False,
                         'build_source_link_verified': False, 'run_identity_sha256': run_id,
                         'local_build_record_sha256': current_identity['identity']['local_build_record_sha256'],
                         'capability_scope': 'application override; restricted terminal and glyph support unverified'})
            write_json(directory / 'capture.json', meta)
            status['state'] = 'captured'
            status['cleanup_confirmation_required'] = False
            status.pop('reason')
            write_json(case_dir / 'status.json', status)
            if valid_capture(case, case_dir, {**current_identity['identity'], 'identity_sha256': run_id}) is None:
                status['state'] = 'failed'
                status['cleanup_confirmation_required'] = True
                status['reason'] = 'captured metadata or image failed validation'
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        (raw / 'exception.log').write_text(f'{type(error).__name__}: {error}\n', encoding='utf-8')
        status['reason'] = f'{type(error).__name__}; see local raw/exception.log'
    write_json(case_dir / 'status.json', status)
    return status


def execute(args):
    inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
    matrix = matrix_from_inventory(inventory)
    inputs = identity(args, inventory)
    args.output.mkdir(parents=True, exist_ok=True)
    root = args.output.resolve(strict=True)
    lock = (root / '.runner.lock').open('a+')
    try:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError('another runner holds this output directory') from error
        run_file = root / 'run.json'
        if run_file.exists():
            saved = json.loads(run_file.read_text(encoding='utf-8'))
            nonce = saved.get('identity', {}).get('run_nonce')
            if not isinstance(nonce, str) or not SHA.fullmatch(nonce) or len(nonce) != 64:
                raise ValueError('legacy or invalid run nonce; choose a new output directory')
        else:
            nonce = secrets.token_hex(32)
        run_identity = {**inputs, 'run_nonce': nonce}
        run_id = digest(canonical(run_identity))
        if run_file.exists():
            if saved != {'identity': run_identity, 'identity_sha256': run_id}:
                raise ValueError('run inputs changed; choose a new output directory')
        else:
            write_json(run_file, {'identity': run_identity, 'identity_sha256': run_id})
        for src, dest, key in ((args.launcher, root / 'inputs/launcher', 'launcher_sha256'),
                               (args.renderer, root / 'inputs/renderer', 'renderer_sha256'),
                               (args.source_archive, root / 'inputs/source.archive', 'source_archive_sha256')):
            archive_input(src, dest, run_identity[key])
        if getattr(args, 'build_record', None):
            archive_input(args.build_record, root / 'inputs/build-record.json', run_identity['local_build_record_sha256'])
        cases = matrix['cases']
        by_id = {case['id']: case for case in cases}
        case_root = root / 'cases'
        case_root.mkdir(exist_ok=True)
        existing = {p.name: p for p in case_root.iterdir() if p.is_dir() and p.name in by_id}
        expected = {**run_identity, 'identity_sha256': run_id}
        good = {}
        failed = set()
        for case_id, path in existing.items():
            meta = valid_capture(by_id[case_id], path, expected)
            if meta is None:
                failed.add(case_id)
            else:
                good[case_id] = meta
        matches = [case for case in cases if selected(case, args)]
        candidates = [case for case in matches if case['id'] in failed] if args.retry_failed else [
            case for case in matches if case['id'] not in good and case['id'] not in failed]
        if args.limit is not None:
            candidates = candidates[:args.limit]
        pending_cleanup = cleanup_confirmation_pending(case_root)
        if candidates and pending_cleanup and not getattr(args, 'ack_interrupted_cleanup', False):
            raise ValueError('continuing requires cleanup confirmation; inspect local processes and pass '
                             '--ack-interrupted-cleanup')
        results = []
        for case in candidates:
            if identity(args, inventory) != inputs:
                raise ValueError('run inputs changed; stopping before next capture')
            case_id = case['id']
            status = capture(case, case_root / case_id, args, run_id, {'identity': run_identity, 'inventory': inventory})
            results.append({'case_id': case_id, 'state': status['state'], 'attempt': status['attempt']})
            if status['state'] == 'captured':
                verified = valid_capture(case, case_root / case_id, expected)
                if verified is None:
                    status['state'] = 'failed'
                    status['cleanup_confirmation_required'] = True
                    status['reason'] = 'capture became invalid before report generation'
                    results[-1]['state'] = 'failed'
                    write_json(case_root / case_id / 'status.json', status)
                    good.pop(case_id, None)
                    failed.add(case_id)
                else:
                    good[case_id] = verified
                    failed.discard(case_id)
            else:
                good.pop(case_id, None)
                failed.add(case_id)
            if status.get('cleanup_confirmation_required') is True:
                pending_cleanup = True
                break
        pending_cleanup = cleanup_confirmation_pending(case_root)
        # Export only verified captures. Reviews are always supplied separately.
        evidence = {'source_sha': args.source_revision, 'source_kind': args.source_kind,
                    'source_revision_verified': False, 'build_source_link_verified': False,
                    'run_identity': {'file': 'run.json', 'sha256': sha_file(run_file), 'identity_sha256': run_id},
                    'source_archive': {'file': 'inputs/source.archive', 'sha256': run_identity['source_archive_sha256']},
                    'binaries': {run_identity['launcher_sha256']: 'inputs/launcher',
                                 run_identity['renderer_sha256']: 'inputs/renderer'},
                    'captures': list(good.values()), 'reviews': []}
        if run_identity['local_build_record_sha256']:
            evidence['local_build_record'] = {'file': 'inputs/build-record.json',
                                              'sha256': run_identity['local_build_record_sha256'],
                                              'independently_verified': False}
        evidence['reviews'], stale_reviews = collect_review_reports(evidence, root)
        from visual_evidence import collect_resolution_reports
        evidence['resolutions'], _ = collect_resolution_reports(evidence, root, evidence['reviews'])
        write_json(root / 'evidence.json', evidence)
        from visual_evidence import GEOMETRY_SOURCE, target_coverage
        report = {**target_coverage(cases, set(good)), 'geometry_check': GEOMETRY_SOURCE,
                  'review_summary_scope': 'snapshot-at-last-capture; use visual_evidence.py review-summary for current records',
                  'review_summary_evidence_sha256': sha_file(root / 'evidence.json'),
                  'scope': 'declared-inventory-only', 'project_coverage_verified': False,
                  'source_kind': args.source_kind, 'source_revision_verified': False,
                  'source_archive_sha256': run_identity['source_archive_sha256'], 'run_identity_sha256': run_id,
                  'local_build_record_sha256': run_identity['local_build_record_sha256'],
                  'total_declared_cases': len(cases), 'matching_filter_cases': len(matches),
                  'captured_cases': len(good), 'failed_or_invalid_cases': len(failed),
                  'unattempted_cases': len(cases) - len(good) - len(failed),
                  'all_declared_cases_captured': len(good) == len(cases),
                  'capture_status': 'all-declared-captured' if len(good) == len(cases) else 'partial',
                  'model_review': ('records_present_unverified' if any(r['kind'] == 'model' for r in evidence['reviews']) else 'not_run'),
                  'independent_review': ('records_present_unverified' if any(r['kind'] == 'independent' for r in evidence['reviews']) else 'not_run'),
                  'current_review_records': len(evidence['reviews']), 'stale_review_records': stale_reviews,
                  'review_identity_and_observation_verified': False, 'results': results,
                  'capability_scope': 'application overrides in Foot; restricted terminal and glyph support unverified',
                  'delivery_ready': False, 'privacy_scan': 'not_run',
                  'cleanup_confirmation_required': pending_cleanup,
                  'local_only_diagnostics': 'cases/*/attempt-*/raw',
                  'limitations': ['inventory completeness unverified', 'binary/source build link unverified',
                                  'dynamic runtime libraries not individually bound',
                                  'fontconfig candidate does not prove per-glyph font or fallback',
                                  'detached or uninterruptible descendants may outlive capture cleanup',
                                  'effective rectangle is renderer self-report, not independent pixel measurement',
                                   'actual review not performed', 'macOS and Windows not checked',
                                  'source archive and delivery assets require privacy review before upload']}
        write_json(root / 'report.json', report)
        return report
    finally:
        lock.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--inventory', type=Path, default=ROOT / 'scripts/visual_inventory.json')
    parser.add_argument('--launcher', type=Path, required=True)
    parser.add_argument('--renderer', type=Path, required=True)
    parser.add_argument('--source-archive', type=Path, required=True)
    parser.add_argument('--source-revision', required=True, help='declared full source SHA; an unsigned build record uses its source snapshot digest')
    parser.add_argument('--source-kind', choices=('committed', 'dirty-worktree'), required=True)
    parser.add_argument('--build-record', type=Path, help='local unsigned build record to check and bind; not an attestation')
    parser.add_argument('--output', type=Path, required=True)
    amount = parser.add_mutually_exclusive_group(required=True)
    amount.add_argument('--limit', type=int, help='maximum cases to capture in this invocation')
    amount.add_argument('--all', action='store_true', help='explicitly allow every matching pending case')
    for name in ('subject', 'state', 'theme', 'glyph', 'color', 'terminal'):
        parser.add_argument('--' + name, action='append', help='restrict case dimension; may be repeated')
    parser.add_argument('--widget-size', action='append', help='restrict widget size WIDTHxHEIGHT; may repeat')
    parser.add_argument('--retry-failed', action='store_true', help='run only previously failed or invalid cases')
    parser.add_argument('--ack-interrupted-cleanup', action='store_true',
                        help='confirm cleanup was inspected before continuing after interruption or failure')
    parser.add_argument('--font', default='monospace:size=14')
    parser.add_argument('--runtime-base')
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--settle', type=float, default=0.3)
    args = parser.parse_args()
    for item in STOP_SIGNALS:
        signal.signal(item, interrupt_signal)
    if (args.limit is not None and args.limit <= 0) or args.timeout <= 0 or args.settle < 0:
        parser.error('limit and timeout must be positive and settle nonnegative')
    try:
        report = execute(args)
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        return 1 if report['failed_or_invalid_cases'] or not report['matching_filter_cases'] else 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(json.dumps({'error': f'{type(error).__name__}: {error}', 'project_coverage_verified': False}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
