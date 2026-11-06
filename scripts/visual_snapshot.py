#!/usr/bin/env python3
"""Copy showcase inputs to an isolated snapshot, rejecting concurrent edits.

The snapshot contains only the six named packages/examples and excludes build,
cache and screenshot directories. The source inventory is hashed before and
again after copying; the copy is hashed independently. A change at any point
causes failure rather than an inconsistent snapshot. This is a working-tree
snapshot, not a commit and not proof of an atomic filesystem snapshot.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

INPUTS = ('packages/core', 'packages/testing', 'packages/diff',
          'examples/workbench', 'examples/showcase_data', 'examples/showcase_editor')
EXCLUDE = {'target', 'build', '.git', '.cjpm', '__pycache__', 'screenshots', '.cache', 'build-script-cache'}


def inventory(root):
    files = {}
    for relative in INPUTS:
        directory = root / relative
        if not directory.is_dir():
            raise ValueError(f'missing source directory: {relative}')
        for parent, dirs, names in os.walk(directory, topdown=True, followlinks=False):
            dirs[:] = sorted(d for d in dirs if d not in EXCLUDE)
            for directory_name in dirs:
                if (Path(parent) / directory_name).is_symlink():
                    raise ValueError('symlinked source directory is unsupported')
            for name in sorted(names):
                path = Path(parent) / name
                if path.is_symlink() or not path.is_file():
                    raise ValueError('symlinked or non-regular source is unsupported')
                relative_path = path.relative_to(root).as_posix()
                files[relative_path] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not files:
        raise ValueError('source inventory is empty')
    return dict(sorted(files.items()))


def manifest(files):
    raw = json.dumps(files, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    return {'kind': 'provisional-dirty-worktree', 'algorithm': 'sha256-canonical-path-to-file-sha256-json',
            'source_snapshot_sha256': hashlib.sha256(raw).hexdigest(), 'files': files}


def create(source, output):
    source = source.resolve(strict=True)
    output = output.resolve()
    if output.is_relative_to(source) or output.exists():
        raise ValueError('snapshot output must not exist and must be outside the source tree')
    before = inventory(source)
    output.mkdir(parents=True)
    try:
        for relative in before:
            destination = output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / relative, destination)
        copied = inventory(output)
        after = inventory(source)
        if before != copied or before != after:
            raise ValueError('source changed while snapshotting; discard this attempt and retry when writers are idle')
        result = manifest(copied)
        (output / 'snapshot-manifest.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        return result
    except Exception:
        shutil.rmtree(output)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = create(args.source, args.output)
        print(json.dumps({'kind': result['kind'], 'files': len(result['files']),
                          'source_snapshot_sha256': result['source_snapshot_sha256']}))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps({'error': f'{type(error).__name__}: {error}'}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
