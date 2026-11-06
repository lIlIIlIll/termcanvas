#!/usr/bin/env python3
"""Expand and audit visual evidence without claiming unenumerated project coverage.

Usage: visual_evidence.py expand INVENTORY.json MATRIX.json
       visual_evidence.py check INVENTORY.json MATRIX.json EVIDENCE.json ARTIFACT_DIR [--declared-scope]

An inventory has themes and subjects. Each subject has an id, kind (widget,
primitive, extension), states, and widget_sizes ([width, height] in cells).
States enumerate applicable *combinations*, not independent flags. Every one
is crossed with each theme, glyph mode, color mode, terminal size and widget
size. Inventory completeness is not inferred from the list. ``check`` refuses
project-wide success until a separately verifiable project inventory exists;
--declared-scope permits a limited audit of just the supplied inventory.

Evidence JSON contains source_sha, source_archive ({file, sha256}), binaries
(a map from binary sha256 to artifact path), captures and reviews. A
capture identifies a case by id and records image, sha256, source_sha,
binary_sha256, renderer_sha256, backend, platform, terminal, terminal_version, compositor,
font, font_version, actual_color, app_color, actual_glyphs, app_glyphs and
cells. Backend must be 'real-terminal'. Reviews are separate entries with
case_id, image_sha256, kind ('model' or 'independent'), reviewer, verdict,
and findings. A high_risk subject requires both review kinds; every image
requires the model review. 'pass' requires an empty findings list: unresolved
or dismissed findings need separate evidence and cannot silently pass.

Color/glyph overrides are deliberately separate from terminal capabilities;
setting app_color or app_glyphs is not proof of actual terminal capability.
The tool validates declared evidence and hashes, not whether an external model
actually observed an image or whether a binary was built from a given commit.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import struct
import sys
import tarfile
import tempfile
import tomllib
import zlib

COLORS = ('truecolor', '256', '16', 'monochrome')
GLYPHS = ('nerd-font', 'unicode', 'ascii')
TERMINALS = ((80, 24), (120, 36), (160, 45))
KINDS = {'widget', 'primitive', 'extension'}
MARKDOWN_OLD = '"markdown" = { git = "https://github.com/lIlIIlIll/markdown.git", tag = "v0.9.1", output-type = "static" }'
MARKDOWN_NEW = '"markdown" = { path = "../../vendor/markdown", output-type = "static" }'
HEX = re.compile(r'^[0-9a-f]{64}$')
SHA = re.compile(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_strings(value, name):
    require(isinstance(value, list) and bool(value), f'{name}: expected a nonempty list')
    require(all(isinstance(x, str) and x.strip() == x and x for x in value), f'{name}: invalid item')
    require(len(set(value)) == len(value), f'{name}: duplicates')
    return value


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_local_build_record(record_path, archive_path, source, binary_hashes):
    """Check local record/archive consistency, without asserting authenticity."""
    record = json.loads(record_path.read_text(encoding='utf-8'))
    require(record.get('kind') == 'local-build-record-not-attestation' and
            record.get('source_revision_verified') is False and
            record.get('build_source_link_independently_verified') is False and
            record.get('source_snapshot_sha256') == source and
            record.get('source_archive_sha256') == digest(archive_path.read_bytes()) and
            record.get('launcher_sha256') in binary_hashes and
            record.get('renderer_sha256') in binary_hashes,
            'local build record does not match evidence')
    tools = record.get('toolchain')
    rewrite = record.get('dependency_rewrite')
    require(isinstance(tools, dict) and all(isinstance(tools.get(key), str) and HEX.fullmatch(tools[key])
            for key in ('cjc_sha256', 'cjpm_sha256', 'runtime_sha256', 'cc_sha256', 'ar_sha256')) and
            all(isinstance(tools.get(key), str) and tools[key].strip() for key in ('cjc_version', 'cjpm_version')) and
            isinstance(record.get('native_archive_sha256'), str) and HEX.fullmatch(record['native_archive_sha256']),
            'incomplete local build tool record')
    require(isinstance(rewrite, dict) and rewrite.get('path') == 'packages/markdown_adapter/cjpm.toml' and
            rewrite.get('markdown_source') == 'vendor/markdown' and rewrite.get('commit_or_tag_verified') is False and
            all(isinstance(rewrite.get(key), str) and HEX.fullmatch(rewrite[key])
                for key in ('before_sha256', 'after_sha256')) and
            isinstance(record.get('limitations'), list) and bool(record['limitations']),
            'incomplete local build dependency record')
    try:
        with tarfile.open(archive_path, 'r') as archive:
            members = archive.getmembers()
            names = [member.name for member in members]
            require(len(names) == len(set(names)) and all(member.isfile() for member in members),
                    'source archive has duplicate or non-file entries')
            require(all(member.uid == 0 and member.gid == 0 and not member.uname and not member.gname and
                        member.mtime == 0 for member in members), 'source archive has unsanitized metadata')
            files = {}
            for member in members:
                name = member.name
                require(not name.startswith('/') and '..' not in Path(name).parts, 'unsafe source archive path')
                files[name] = archive.extractfile(member).read()
        require('snapshot-manifest.json' in files, 'source archive manifest missing')
        manifest = json.loads(files.pop('snapshot-manifest.json'))
        hashes = {name: digest(data) for name, data in files.items()}
        required = ('packages/core/cjpm.toml', 'packages/core/native/build.sh',
                    'packages/core/native/spawn.c', 'packages/core/src/app.cj',
                    'packages/diff/cjpm.toml', 'packages/diff/src/diff.cj',
                    'packages/game/cjpm.toml', 'packages/game/src/game.cj',
                    'packages/media/cjpm.toml', 'packages/media/src/media.cj',
                    'packages/terminal/cjpm.toml', 'packages/terminal/src/terminal.cj',
                    'packages/markdown_adapter/cjpm.toml', 'packages/markdown_adapter/src/markdown.cj',
                    'examples/visual_matrix/cjpm.toml',
                    'examples/visual_matrix/src/main.cj', 'examples/visual_matrix/launch.py',
                    'scripts/visual_capture.py', 'scripts/visual_matrix_runner.py',
                    'scripts/visual_matrix_build.py', 'scripts/native_sdk.py',
                    'scripts/visual_evidence.py', 'scripts/visual_inventory.py',
                    'scripts/visual_inventory.json', 'vendor/markdown/cjpm.toml')
        require(manifest.get('files') == hashes and manifest.get('source_snapshot_sha256') == source and
                digest(canonical(hashes)) == source and
                all(name in hashes for name in required) and
                any(name.startswith('vendor/markdown/src/') for name in hashes) and
                any(name.startswith('examples/visual_matrix/sample/') for name in hashes) and
                hashes.get('packages/markdown_adapter/cjpm.toml') == rewrite['before_sha256'] and
                hashes.get('examples/visual_matrix/launch.py') == record['launcher_sha256'],
                'source archive inventory or manifest mismatch')
        adapter = files['packages/markdown_adapter/cjpm.toml'].decode('utf-8')
        dependency = tomllib.loads(adapter).get('dependencies', {}).get('markdown')
        require(dependency == {'git': 'https://github.com/lIlIIlIll/markdown.git',
                               'tag': 'v0.9.1', 'output-type': 'static'} and adapter.count(MARKDOWN_OLD) == 1 and
                digest(adapter.replace(MARKDOWN_OLD, MARKDOWN_NEW).encode('utf-8')) == rewrite['after_sha256'],
                'local dependency rewrite hash mismatch')
        return record, hashes
    except (tarfile.TarError, KeyError, TypeError, UnicodeDecodeError, tomllib.TOMLDecodeError, json.JSONDecodeError) as error:
        raise ValueError('invalid local build record archive') from error


def case_geometry(subject, state, allocation, terminal):
    """Declared geometry for the fixture render call, not a pixel measurement."""
    targets = subject.get('state_target_widths', {})
    require(isinstance(targets, dict) and all(key in subject['states'] and type(value) is int and value > 0
            for key, value in targets.items()), 'invalid state target widths')
    height_limit = subject.get('max_effective_height')
    require(height_limit is None or (type(height_limit) is int and height_limit >= 0),
            'invalid maximum effective height')
    target = targets.get(state, 0)
    width, height = allocation
    width = min(width, target) if target else width
    height = min(height, height_limit) if height_limit is not None else height
    visible = 2 + width <= terminal[0] and 4 + height <= terminal[1]
    satisfied = (width == target and height > 0 and visible) if target else None
    return {'allocation_cells': list(allocation), 'target_width': target,
            'expected_effective_rect': [2, 4, width, height], 'target_width_satisfied': satisfied}


GEOMETRY_SOURCE = 'renderer-self-report-not-pixel-measurement'


def validate_case_geometry(case):
    require(case.get('case_schema_version') == 2, 'invalid case geometry schema')
    allocation = case.get('allocation_cells')
    rect = case.get('expected_effective_rect')
    terminal = case.get('terminal_cells')
    target = case.get('target_width')
    require(isinstance(allocation, list) and len(allocation) == 2 and
            all(type(v) is int and v >= 0 for v in allocation) and allocation == case.get('widget_cells') and
            isinstance(terminal, list) and len(terminal) == 2 and
            all(type(v) is int and v >= 0 for v in terminal) and
            type(target) is int and target >= 0 and isinstance(rect, list) and len(rect) == 4 and
            all(type(v) is int and v >= 0 for v in rect), 'invalid case geometry')
    x, y, width, height = rect
    require((x, y) == (2, 4) and width == (min(allocation[0], target) if target else allocation[0]) and
            height <= allocation[1], 'effective rectangle disagrees with allocation')
    satisfied = (width == target and height > 0 and x + width <= terminal[0] and
                 y + height <= terminal[1]) if target else None
    require(case.get('target_width_satisfied') is satisfied, 'target width satisfaction mismatch')
    return {'effective_rect': rect, 'target_width': target, 'source': GEOMETRY_SOURCE}


def target_coverage(cases, captured_ids):
    def key(case):
        return (case['subject'], case['state'], case['theme'], case['glyph'], case['color'],
                tuple(case['terminal_cells']))
    required = {key(case) for case in cases if case['target_width'] > 0}
    covered = {key(case) for case in cases if case['target_width'] > 0 and
               case['target_width_satisfied'] is True and case['id'] in captured_ids}
    return {'target_width_expected_contexts': len(required), 'target_width_covered_contexts': len(covered),
            'target_width_coverage': ('not-applicable' if not required else
                                      'complete' if required <= covered else 'partial')}


def matrix_from_inventory(inventory, *, version=2):
    require(isinstance(inventory, dict), 'inventory must be an object')
    require(version in (1, 2), 'unsupported matrix version')
    themes = unique_strings(inventory.get('themes'), 'themes')
    subjects = inventory.get('subjects')
    require(isinstance(subjects, list) and subjects, 'subjects: expected a nonempty list')
    ids = set()
    cases = []
    for subject in subjects:
        require(isinstance(subject, dict), 'subject must be an object')
        name = subject.get('id')
        require(isinstance(name, str) and name.strip() == name and name, 'subject id is required')
        require(name not in ids, f'duplicate subject: {name}')
        ids.add(name)
        kind = subject.get('kind')
        require(kind in KINDS, f'{name}: invalid kind')
        states = unique_strings(subject.get('states'), f'{name}.states')
        high_risk = subject.get('high_risk')
        require(type(high_risk) is bool, f'{name}: high_risk must be explicit')
        sizes = subject.get('widget_sizes')
        require(isinstance(sizes, list) and sizes, f'{name}: widget_sizes required')
        normalized = []
        for size in sizes:
            require(isinstance(size, list) and len(size) == 2 and
                    all(type(v) is int and v >= 0 for v in size), f'{name}: invalid widget size')
            normalized.append(tuple(size))
        require(len(set(normalized)) == len(normalized), f'{name}: duplicate widget size')
        for state, theme, glyph, color, terminal, widget in itertools.product(
                states, themes, GLYPHS, COLORS, TERMINALS, normalized):
            value = {'subject': name, 'kind': kind, 'state': state, 'theme': theme,
                     'glyph': glyph, 'color': color, 'terminal_cells': list(terminal),
                     'widget_cells': list(widget), 'high_risk': high_risk}
            if version == 2:
                value.update({'case_schema_version': 2, **case_geometry(subject, state, widget, terminal)})
            cases.append({'id': digest(canonical(value)), **value})
    return {'version': version, 'scope': 'declared-inventory-only',
            'inventory_sha256': digest(canonical(inventory)), 'cases': cases}


def read_png(path):
    """Validate PNG framing, CRCs and nonzero image dimensions."""
    data = path.read_bytes()
    require(data.startswith(b'\x89PNG\r\n\x1a\n'), f'{path.name}: not a PNG')
    offset = 8
    first = True
    saw_data = False
    width = height = 0
    while offset < len(data):
        require(offset + 12 <= len(data), f'{path.name}: truncated PNG chunk')
        size = struct.unpack_from('>I', data, offset)[0]
        end = offset + 12 + size
        require(end <= len(data), f'{path.name}: truncated PNG data')
        chunk = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        expected = struct.unpack_from('>I', data, offset + 8 + size)[0]
        require(zlib.crc32(chunk + payload) & 0xffffffff == expected, f'{path.name}: invalid PNG CRC')
        if first:
            require(chunk == b'IHDR' and size == 13, f'{path.name}: missing PNG IHDR')
            width, height = struct.unpack_from('>II', payload)
            require(width > 0 and height > 0, f'{path.name}: invalid dimensions')
            first = False
        saw_data |= chunk == b'IDAT'
        offset = end
        if chunk == b'IEND':
            require(size == 0 and saw_data and offset == len(data), f'{path.name}: invalid PNG ending')
            return digest(data), (width, height)
    raise ValueError(f'{path.name}: missing PNG IEND')


LEGACY_REVIEW_KEYS = ('case_id', 'kind', 'image_sha256', 'source_sha', 'reviewer', 'verdict', 'findings')
REVIEW_KEYS = (*LEGACY_REVIEW_KEYS, 'run_identity_sha256')


def verify_run_identity(evidence, root, *, required=False):
    binding = evidence.get('run_identity')
    if binding is None:
        require(not required, 'run identity required')
        return None
    require(isinstance(binding, dict) and isinstance(binding.get('file'), str) and
            binding['file'] and not Path(binding['file']).is_absolute() and
            isinstance(binding.get('sha256'), str) and HEX.fullmatch(binding['sha256']),
            'invalid run identity binding')
    path = (root / binding['file']).resolve(strict=True)
    require(path.is_relative_to(root) and path.is_file() and digest(path.read_bytes()) == binding['sha256'],
            'run identity artifact hash mismatch')
    run = json.loads(path.read_text(encoding='utf-8'))
    require(isinstance(run, dict) and isinstance(run.get('identity'), dict), 'invalid run identity')
    identity = run['identity']
    run_id = digest(canonical(identity))
    if identity.get('matrix_schema_version') == 2:
        require(isinstance(identity.get('run_nonce'), str) and HEX.fullmatch(identity['run_nonce']),
                'run identity nonce missing or invalid')
    require(identity.get('version') == 2 and run.get('identity_sha256') == run_id and
            binding.get('identity_sha256') == run_id, 'run identity digest mismatch')
    require(identity.get('source_revision_declared') == evidence.get('source_sha') and
            identity.get('source_kind') == evidence.get('source_kind') and
            identity.get('revision_verified') is False and identity.get('build_source_link_verified') is False and
            identity.get('source_archive_sha256') == evidence.get('source_archive', {}).get('sha256') and
            identity.get('launcher_sha256') in evidence.get('binaries', {}) and
            identity.get('renderer_sha256') in evidence.get('binaries', {}),
            'run identity source or binaries mismatch')
    config = identity.get('terminal_configuration')
    versions = identity.get('terminal_tool_versions')
    tools = identity.get('terminal_tools_sha256')
    require(isinstance(config, dict) and
            config.get('foot_config') == {'source': '/dev/null', 'xdg_config_roots': 'isolated empty directories'} and
            isinstance(config.get('locale'), dict) and
            set(config['locale']) == {'LC_ALL', 'LC_CTYPE', 'LANG', 'LANGUAGE', 'charmap'} and
            config['locale'].get('charmap') not in (None, '', 'unknown') and
            isinstance(config.get('fontconfig_candidate'), dict) and
            isinstance(config['fontconfig_candidate'].get('request'), str) and
            config['fontconfig_candidate']['request'] and
            isinstance(identity.get('font'), str) and
            type(identity.get('settle_seconds')) in (int, float) and identity['settle_seconds'] >= 0 and
            config['fontconfig_candidate']['request'] == identity['font'].split(',', 1)[0].strip() and
            config['fontconfig_candidate'].get('scope') ==
                'fc-match candidate; actual glyph fonts and fallback unverified' and
            isinstance(config['fontconfig_candidate'].get('sha256'), str) and
            HEX.fullmatch(config['fontconfig_candidate']['sha256']) and
            isinstance(config.get('font'), str) and config['font'] and
            isinstance(config.get('font_version'), str) and config['font_version'] and
            isinstance(versions, dict) and all(isinstance(versions.get(name), str) and versions[name].strip()
                                              for name in ('foot', 'sway')) and
            isinstance(tools, dict) and all(isinstance(tools.get(name), str) and HEX.fullmatch(tools[name])
                                           for name in ('foot', 'sway', 'swaymsg', 'grim', 'fc-match', 'locale', 'python')),
            'incomplete run terminal identity')
    return identity


def verify_capture_run(capture, binding, identity):
    run_id = binding['identity_sha256']
    config = identity['terminal_configuration']
    versions = identity['terminal_tool_versions']
    require(capture.get('run_identity_sha256') == run_id and
            capture.get('source_kind') == identity['source_kind'] and
            capture.get('source_revision_verified') is identity['revision_verified'] and
            capture.get('build_source_link_verified') is identity['build_source_link_verified'] and
            capture.get('binary_sha256') == identity['launcher_sha256'] and
            capture.get('renderer_sha256') == identity['renderer_sha256'] and
            capture.get('terminal') == 'foot' and capture.get('terminal_version') == versions['foot'] and
            capture.get('compositor') == versions['sway'] + ' headless pixman' and
            capture.get('actual_color') == 'truecolor' and capture.get('actual_glyphs') == 'unknown' and
            capture.get('capability_scope') ==
                'application override; restricted terminal and glyph support unverified' and
            isinstance(capture.get('capture_parameters'), dict) and
            capture['capture_parameters'].get('font_request') == identity['font'] and
            capture['capture_parameters'].get('settle_seconds') == identity['settle_seconds'] and
            all(capture.get(key) == value for key, value in config.items()),
            'capture run identity or terminal configuration mismatch')


@contextmanager
def review_lock(root):
    """Share the runner's output lock for capture and review mutations."""
    try:
        import fcntl
    except ImportError as error:
        raise ValueError('review mutation requires the runner file-lock implementation') from error
    root = root.resolve(strict=True)
    with (root / '.runner.lock').open('a+') as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError('another runner or review operation holds this output directory') from error
        yield root


def review_captures(evidence, root, *, invalid=None):
    source = evidence.get('source_sha')
    require(isinstance(source, str) and SHA.fullmatch(source), 'valid review source required')
    identity = verify_run_identity(evidence, root, required=True)
    captures = evidence.get('captures')
    require(isinstance(captures, list), 'capture list required')
    found = {}
    seen = set()
    for capture in captures:
        case_id = capture.get('case_id')
        require(isinstance(case_id, str) and HEX.fullmatch(case_id) and case_id not in seen,
                'invalid or duplicate review capture case')
        seen.add(case_id)
        try:
            require(capture.get('source_sha') == source, 'review capture source mismatch')
            verify_capture_run(capture, evidence['run_identity'], identity)
            name = capture.get('image')
            require(isinstance(name, str) and name and not Path(name).is_absolute(), 'review image path required')
            image = (root / name).resolve(strict=True)
            require(image.is_relative_to(root) and image.is_file(), 'review image path escapes output')
            image_sha, _ = read_png(image)
            require(image_sha == capture.get('sha256'), 'review capture image hash mismatch')
        except (OSError, ValueError, KeyError, TypeError) as error:
            if invalid is None:
                raise
            invalid.append(case_id)
            continue
        found[case_id] = capture
    return found


def validate_review_entry(entry, *, allow_legacy=False):
    require(isinstance(entry, dict) and (set(entry) == set(REVIEW_KEYS) or
            (allow_legacy and set(entry) == set(LEGACY_REVIEW_KEYS))), 'invalid review entry fields')
    require(isinstance(entry['case_id'], str) and HEX.fullmatch(entry['case_id']), 'invalid review case')
    require(entry['kind'] in ('model', 'independent'), 'invalid review kind')
    require(isinstance(entry['image_sha256'], str) and HEX.fullmatch(entry['image_sha256']), 'invalid review image hash')
    require(isinstance(entry['source_sha'], str) and SHA.fullmatch(entry['source_sha']), 'invalid review source')
    if 'run_identity_sha256' in entry:
        require(isinstance(entry['run_identity_sha256'], str) and HEX.fullmatch(entry['run_identity_sha256']),
                'invalid review run identity')
    require(isinstance(entry['reviewer'], str) and bool(entry['reviewer'].strip()), 'reviewer required')
    require(entry['verdict'] in ('pass', 'fail'), 'invalid review verdict')
    require(isinstance(entry['findings'], list) and all(isinstance(x, str) and x.strip() for x in entry['findings']),
            'review findings must be nonempty strings')
    require(entry['verdict'] != 'pass' or not entry['findings'], 'passing review cannot contain findings')


def collect_review_reports(evidence, root):
    """Return current records and stale count; never assert reviewer authenticity."""
    root = root.resolve(strict=True)
    directory = root / 'reviews' / 'reports'
    if not directory.exists():
        return [], 0
    require(not (root / 'reviews').is_symlink() and not directory.is_symlink() and directory.is_dir(),
            'invalid review report directory')
    captures = review_captures(evidence, root)
    source = evidence['source_sha']
    selected = {}
    stale = 0
    for path in sorted(directory.iterdir()):
        require(not path.is_symlink() and path.is_file() and path.suffix == '.json' and HEX.fullmatch(path.stem),
                'invalid review report artifact')
        data = path.read_bytes()
        require(digest(data) == path.stem, 'review report hash mismatch')
        report = json.loads(data)
        require(isinstance(report, dict) and isinstance(report.get('reviews'), list) and report['reviews'],
                'invalid review report')
        seen = set()
        for entry in report['reviews']:
            validate_review_entry(entry, allow_legacy=True)
            key = (entry['case_id'], entry['kind'])
            require(key not in seen, 'duplicate review in one report')
            seen.add(key)
            capture = captures.get(entry['case_id'])
            if (entry.get('run_identity_sha256') != evidence['run_identity']['identity_sha256'] or
                    entry['source_sha'] != source or capture is None or entry['image_sha256'] != capture['sha256']):
                stale += 1
                continue
            result = {**entry, 'report_file': path.relative_to(root).as_posix(), 'report_sha256': path.stem}
            if key in selected:
                previous = {name: selected[key][name] for name in REVIEW_KEYS}
                require(previous == entry, 'conflicting current review records')
            else:
                selected[key] = result
    return [selected[key] for key in sorted(selected)], stale



def current_review_summary(evidence, root):
    """Recompute review references for intact current captures; not a visual audit."""
    invalid = []
    captures = review_captures(evidence, root, invalid=invalid)
    # Reuse the runner's full attempt validation, including its capture.json,
    # case parameters, renderer geometry, image hash and run binding.
    from visual_matrix_runner import valid_capture
    run = json.loads((root / evidence['run_identity']['file']).read_text(encoding='utf-8'))
    expected = {**run['identity'], 'identity_sha256': evidence['run_identity']['identity_sha256']}
    for case_id, capture in list(captures.items()):
        try:
            case_dir = root / 'cases' / case_id
            require(not case_dir.is_symlink() and case_dir.resolve(strict=True).is_relative_to(root),
                    'invalid case directory')
            status = json.loads((case_dir / 'status.json').read_text(encoding='utf-8'))
            attempt = status.get('attempt')
            require(type(attempt) is int and attempt > 0, 'invalid current attempt')
            attempt_dir = case_dir / f'attempt-{attempt:06d}'
            require(not attempt_dir.is_symlink() and attempt_dir.resolve(strict=True).is_relative_to(root),
                    'invalid attempt directory')
            case = json.loads((attempt_dir / 'case.json').read_text(encoding='utf-8'))
            require(case.get('id') == case_id and
                    digest(canonical({key: value for key, value in case.items() if key != 'id'})) == case_id,
                    'case identity mismatch')
            require(valid_capture(case, case_dir, expected) == capture,
                    'capture is not the current validated attempt')
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
            invalid.append(case_id)
            del captures[case_id]
    filtered = {**evidence, 'captures': list(captures.values())}
    reviews, stale = collect_review_reports(filtered, root)
    return {'scope': 'current-evidence-capture-records-only', 'delivery_ready': False,
            'unexported_attempts_not_audited': True,
            'project_coverage_verified': False, 'visual_audit': 'not_performed',
            'review_identity_and_observation_verified': False,
            'valid_captures': len(captures), 'invalid_or_missing_captures': len(invalid),
            'current_review_records': len(reviews), 'stale_review_records': stale,
            'passing_review_records': sum(r['verdict'] == 'pass' for r in reviews),
            'failing_review_records': sum(r['verdict'] == 'fail' for r in reviews),
            'model_review_records': sum(r['kind'] == 'model' for r in reviews),
            'independent_review_records': sum(r['kind'] == 'independent' for r in reviews),
            'failure_case_ids': sorted({r['case_id'] for r in reviews if r['verdict'] == 'fail'}),
            'source_sha': evidence['source_sha'],
            'run_identity_sha256': evidence['run_identity']['identity_sha256']}


def review_summary(root):
    """Read a consistent view while capture and review mutation share the lock."""
    with review_lock(root) as root:
        path = root / 'evidence.json'
        raw = path.read_bytes()
        summary = current_review_summary(json.loads(raw), root)
        return {**summary, 'evidence_sha256': digest(raw)}

def import_review_report(evidence, root, report):
    """Validate and store reported judgments, without asserting who performed them."""
    root = root.resolve(strict=True)
    require(isinstance(report, dict) and isinstance(report.get('reviews'), list) and report['reviews'],
            'invalid review report')
    captures = review_captures(evidence, root)
    current, _ = collect_review_reports(evidence, root)
    selected = {(entry['case_id'], entry['kind']): {name: entry[name] for name in REVIEW_KEYS}
                for entry in current}
    incoming = {}
    for entry in report['reviews']:
        validate_review_entry(entry)
        key = (entry['case_id'], entry['kind'])
        require(key not in incoming, 'duplicate review in one report')
        capture = captures.get(entry['case_id'])
        require(capture is not None and entry['source_sha'] == evidence['source_sha'] and
                entry['image_sha256'] == capture['sha256'] and
                entry['run_identity_sha256'] == evidence['run_identity']['identity_sha256'],
                'review does not match current capture')
        require(key not in selected or selected[key] == entry, 'conflicting current review records')
        incoming[key] = entry
    normalized = {'reviews': [incoming[key] for key in sorted(incoming)],
                  'verification': 'reviewer identity and image observation not independently verified'}
    data = canonical(normalized) + b'\n'
    report_sha = digest(data)
    directory = root / 'reviews' / 'reports'
    require(not (root / 'reviews').is_symlink() and not directory.is_symlink(), 'invalid review report directory')
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / (report_sha + '.json')
    if path.exists():
        require(not path.is_symlink() and path.read_bytes() == data, 'review report hash collision or corruption')
    else:
        fd, tmp = tempfile.mkstemp(prefix='.review-', dir=directory)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(tmp, path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    return path.relative_to(root).as_posix(), report_sha


def update_reviews(root, report):
    """Persist an explicit report then atomically regenerate current references."""
    with review_lock(root) as root:
        evidence_path = root / 'evidence.json'
        evidence = json.loads(evidence_path.read_text(encoding='utf-8'))
        name, report_sha = import_review_report(evidence, root, report)
        evidence['reviews'], stale = collect_review_reports(evidence, root)
        fd, tmp = tempfile.mkstemp(prefix='.review-evidence-', dir=root)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as stream:
                json.dump(evidence, stream, indent=2, ensure_ascii=False, sort_keys=True)
                stream.write('\n')
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(tmp, evidence_path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        return {'report_file': name, 'report_sha256': report_sha, 'current_reviews': len(evidence['reviews']),
                'stale_reviews': stale, 'identity_and_image_observation_verified': False}


def audit(matrix, evidence, artifact_dir, *, require_local_build_record=False):
    require(isinstance(matrix, dict) and matrix.get('version') in (1, 2) and
            matrix.get('scope') == 'declared-inventory-only', 'invalid matrix header')
    cases = matrix.get('cases')
    require(isinstance(cases, list) and cases, 'matrix has no cases')
    expected = {}
    for case in cases:
        require(isinstance(case, dict), 'invalid case')
        payload = {k: v for k, v in case.items() if k != 'id'}
        case_id = case.get('id')
        require(case_id == digest(canonical(payload)) and case_id not in expected, 'invalid or duplicate case id')
        if matrix['version'] == 2:
            validate_case_geometry(case)
        expected[case_id] = case
    source = evidence.get('source_sha', '')
    require(isinstance(source, str) and SHA.fullmatch(source), 'source_sha must be a full source revision')
    root = artifact_dir.resolve(strict=True)
    def verify_file(name, expected_hash, description):
        require(isinstance(expected_hash, str) and HEX.fullmatch(expected_hash), f'{description} SHA-256 required')
        require(isinstance(name, str) and name and not Path(name).is_absolute(), f'{description} path required')
        path = (root / name).resolve(strict=True)
        require(path.is_relative_to(root) and path.is_file(), f'{description} path escapes artifact directory')
        require(digest(path.read_bytes()) == expected_hash, f'{description} hash mismatch')
    archive = evidence.get('source_archive')
    require(isinstance(archive, dict), 'source archive required')
    archive_sha = archive.get('sha256')
    verify_file(archive.get('file'), archive_sha, 'source archive')
    binaries = evidence.get('binaries')
    require(isinstance(binaries, dict) and binaries, 'archived binaries required')
    for binary_hash, binary_file in binaries.items():
        verify_file(binary_file, binary_hash, 'binary')
    local = evidence.get('local_build_record')
    local_sha = None
    local_record = None
    run_identity = verify_run_identity(evidence, root, required=require_local_build_record)
    if run_identity is not None and matrix['version'] == 2:
        require(run_identity.get('matrix_schema_version') == 2, 'run identity matrix schema mismatch')
    require(not require_local_build_record or local is not None, 'local build record required')
    if local is not None:
        require(isinstance(local, dict) and local.get('independently_verified') is False,
                'local build record must be explicitly unverified')
        require(evidence.get('source_kind') == 'dirty-worktree' and
                evidence.get('source_revision_verified') is False and
                evidence.get('build_source_link_verified') is False,
                'local build record evidence provenance flags mismatch')
        local_sha = local.get('sha256')
        verify_file(local.get('file'), local_sha, 'local build record')
        local_record, _ = verify_local_build_record(root / local['file'], root / archive['file'], source, binaries)
        try:
            with tarfile.open(root / archive['file'], 'r') as source_archive:
                archived_inventory = json.load(source_archive.extractfile('scripts/visual_inventory.json'))
        except (tarfile.TarError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
            raise ValueError('invalid archived visual inventory') from error
        require(matrix == matrix_from_inventory(archived_inventory, version=matrix['version']),
                'matrix differs from archived visual inventory')
        if run_identity is not None:
            require(run_identity.get('inventory_sha256') == digest(canonical(archived_inventory)) and
                    run_identity.get('local_build_record_sha256') == local_sha,
                    'run identity inventory or build record mismatch')
    captures = evidence.get('captures')
    reviews = evidence.get('reviews')
    require(isinstance(captures, list) and isinstance(reviews, list), 'captures and reviews must be lists')
    found = {}
    for capture in captures:
        require(isinstance(capture, dict), 'invalid capture')
        case_id = capture.get('case_id')
        require(capture.get('local_build_record_sha256') == local_sha,
                'capture local build record mismatch')
        if local_record is not None:
            require(capture.get('source_kind') == 'dirty-worktree' and
                    capture.get('source_revision_verified') is False and
                    capture.get('build_source_link_verified') is False,
                    'capture local build provenance flags mismatch')
            require(capture.get('binary_sha256') == local_record['launcher_sha256'] and
                    capture.get('renderer_sha256') == local_record['renderer_sha256'],
                    'capture local build binary mismatch')
        if run_identity is not None:
            verify_capture_run(capture, evidence['run_identity'], run_identity)
        require(case_id in expected and case_id not in found, 'unknown or duplicate capture')
        case = expected[case_id]
        require(capture.get('source_sha') == source and capture.get('source_archive_sha256') == archive_sha
                and capture.get('binary_sha256') in binaries and capture.get('renderer_sha256') in binaries,
                f'{case_id}: capture provenance mismatch')
        require(capture.get('backend') == 'real-terminal' and capture.get('platform') == 'Linux',
                f'{case_id}: Linux real-terminal capture required')
        for field in ('terminal', 'terminal_version', 'compositor', 'font', 'font_version', 'actual_color', 'actual_glyphs'):
            require(isinstance(capture.get(field), str) and capture[field].strip(), f'{case_id}: {field} required')
        require(capture.get('app_color') == case['color'] and capture.get('app_glyphs') == case['glyph'],
                f'{case_id}: application capability override mismatch')
        require(capture.get('cells') == case['terminal_cells'], f'{case_id}: terminal size mismatch')
        app_report = capture.get('app_report')
        applied = {key: case[key] for key in ('subject', 'state', 'theme', 'glyph', 'color', 'widget_cells')}
        require(isinstance(app_report, dict) and app_report.get('case_id') == case_id and
                app_report.get('renderer_sha256') == capture['renderer_sha256'] and
                app_report.get('cells') == case['terminal_cells'] and app_report.get('applied') == applied,
                f'{case_id}: application did not attest to the requested visual state')
        if matrix['version'] == 2:
            require(capture.get('geometry_evidence') == GEOMETRY_SOURCE and
                    app_report.get('renderer_geometry') == validate_case_geometry(case),
                    f'{case_id}: renderer geometry mismatch')
        name = capture.get('image')
        require(isinstance(name, str) and name and not Path(name).is_absolute(), f'{case_id}: invalid image path')
        image = (root / name).resolve(strict=True)
        require(image.is_relative_to(root) and image.is_file(), f'{case_id}: image escapes artifact directory')
        image_hash, pixels = read_png(image)
        require(image_hash == capture.get('sha256'), f'{case_id}: image hash mismatch')
        require(pixels[0] >= case['terminal_cells'][0] and pixels[1] >= case['terminal_cells'][1],
                f'{case_id}: image too small for declared terminal cells')
        found[case_id] = capture
    require(set(found) == set(expected), f'missing captures: {len(set(expected) - set(found))} of {len(expected)}')
    reviewed = {}
    report_cache = {}
    for review in reviews:
        require(isinstance(review, dict), 'invalid review')
        case_id = review.get('case_id')
        kind = review.get('kind')
        require(case_id in expected and kind in ('model', 'independent'), 'unknown case or review kind')
        key = (case_id, kind)
        require(key not in reviewed, f'{case_id}: duplicate {kind} review')
        require(review.get('image_sha256') == found[case_id]['sha256'], f'{case_id}: review image mismatch')
        require(isinstance(review.get('reviewer'), str) and review['reviewer'].strip(), f'{case_id}: reviewer required')
        require(review.get('source_sha') == source, f'{case_id}: review source mismatch')
        if run_identity is not None:
            require(review.get('run_identity_sha256') == evidence['run_identity']['identity_sha256'],
                    f'{case_id}: review run identity mismatch')
        report_file, report_sha = review.get('report_file'), review.get('report_sha256')
        if (report_file, report_sha) not in report_cache:
            verify_file(report_file, report_sha, f'{case_id}: review report')
            report = json.loads((root / report_file).read_text(encoding='utf-8'))
            require(isinstance(report, dict) and isinstance(report.get('reviews'), list), 'invalid review report')
            entries = {}
            for entry in report['reviews']:
                require(isinstance(entry, dict), 'invalid review report entry')
                entry_key = (entry.get('case_id'), entry.get('kind'))
                require(entry_key not in entries, 'duplicate review report entry')
                entries[entry_key] = entry
            report_cache[(report_file, report_sha)] = entries
        report_entry = {key: review.get(key) for key in (REVIEW_KEYS if run_identity is not None else LEGACY_REVIEW_KEYS)}
        require(report_cache[(report_file, report_sha)].get(key) == report_entry,
                f'{case_id}: report does not contain review')
        require(review.get('verdict') == 'pass' and review.get('findings') == [], f'{case_id}: review not clear')
        reviewed[key] = review
    for case_id, case in expected.items():
        require((case_id, 'model') in reviewed, f'{case_id}: missing model review')
        if case['high_risk']:
            require((case_id, 'independent') in reviewed, f'{case_id}: missing independent review')
            require(reviewed[(case_id, 'model')]['reviewer'] != reviewed[(case_id, 'independent')]['reviewer'],
                    f'{case_id}: reviewer labels must differ')
    geometry = target_coverage(cases, set(found)) if matrix['version'] == 2 else {}
    return {**geometry, 'geometry_check': GEOMETRY_SOURCE if matrix['version'] == 2 else 'legacy-unverified',
            'cases': len(expected), 'captures': len(found), 'reviews': len(reviewed),
            'source_sha': source, 'source_archive_sha256': archive_sha, 'binary_count': len(binaries),
            'local_build_record_check': 'local-consistency-only' if local_record is not None else 'not-provided',
            'run_identity_check': 'local-consistency-only' if run_identity is not None else 'not-provided',
            'scope': 'declared-inventory-only', 'project_coverage_verified': False,
            'limitations': ['inventory completeness not verified', 'binary/source build link not verified', 'renderer execution not independently verified',
                            'application-reported state not independently verified',
                            'review identity and execution not independently verified',
                            'macOS and Windows screenshot coverage not verified']}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    expand = commands.add_parser('expand')
    expand.add_argument('inventory', type=Path)
    expand.add_argument('output', type=Path)
    expand.add_argument('--version', type=int, choices=(1, 2), default=2)
    check = commands.add_parser('check')
    check.add_argument('inventory', type=Path)
    check.add_argument('matrix', type=Path)
    check.add_argument('evidence', type=Path)
    check.add_argument('artifact_dir', type=Path)
    check.add_argument('--declared-scope', action='store_true',
                       help='allow success for the declared inventory only, never project-wide coverage')
    check.add_argument('--require-local-build-record', action='store_true',
                       help='require a consistent unsigned local build record')
    summary = commands.add_parser('review-summary', help='recompute current review records; never a visual audit')
    summary.add_argument('artifact_dir', type=Path)
    create = commands.add_parser('review-create', help='record an explicit reviewer judgment without verifying identity')
    create.add_argument('artifact_dir', type=Path)
    create.add_argument('--case', required=True)
    create.add_argument('--kind', choices=('model', 'independent'), required=True)
    create.add_argument('--reviewer', required=True)
    create.add_argument('--verdict', choices=('pass', 'fail'), required=True)
    create.add_argument('--finding', action='append', default=[])
    importer = commands.add_parser('review-import', help='import an explicit report bound to current screenshots')
    importer.add_argument('artifact_dir', type=Path)
    importer.add_argument('report', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'expand':
            inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
            matrix = matrix_from_inventory(inventory, version=args.version)
            args.output.write_text(json.dumps(matrix, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
            print(json.dumps({'cases': len(matrix['cases']), 'scope': matrix['scope']}))
            return 0
        if args.command == 'review-summary':
            print(json.dumps(review_summary(args.artifact_dir), ensure_ascii=False, sort_keys=True))
            return 0
        if args.command == 'review-create':
            root = args.artifact_dir.resolve(strict=True)
            evidence = json.loads((root / 'evidence.json').read_text(encoding='utf-8'))
            captures = review_captures(evidence, root)
            require(args.case in captures, 'requested review case has no current capture')
            entry = {'case_id': args.case, 'kind': args.kind, 'image_sha256': captures[args.case]['sha256'],
                     'source_sha': evidence['source_sha'], 'reviewer': args.reviewer,
                     'verdict': args.verdict, 'findings': args.finding,
                     'run_identity_sha256': evidence['run_identity']['identity_sha256']}
            print(json.dumps(update_reviews(root, {'reviews': [entry]}), ensure_ascii=False))
            return 0
        if args.command == 'review-import':
            print(json.dumps(update_reviews(args.artifact_dir, json.loads(args.report.read_text(encoding='utf-8'))),
                             ensure_ascii=False))
            return 0
        inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
        matrix = json.loads(args.matrix.read_text(encoding='utf-8'))
        require(matrix == matrix_from_inventory(inventory, version=matrix.get('version')), 'matrix does not match the expanded inventory')
        evidence = json.loads(args.evidence.read_text(encoding='utf-8'))
        report = audit(matrix, evidence, args.artifact_dir, require_local_build_record=args.require_local_build_record)
        report['passed'] = (args.declared_scope and report['run_identity_check'] == 'local-consistency-only' and
                            report['geometry_check'] == GEOMETRY_SOURCE and
                            report['target_width_coverage'] in ('complete', 'not-applicable'))
        if args.declared_scope and not report['passed']:
            report['error'] = 'run identity, renderer geometry or target-width coverage is unverified'
        elif not args.declared_scope:
            report['error'] = 'project-wide inventory and other-platform coverage are not verified'
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        return 0 if report['passed'] else 1
    except (ValueError, OSError, TypeError, json.JSONDecodeError) as error:
        print(json.dumps({'passed': False, 'error': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
