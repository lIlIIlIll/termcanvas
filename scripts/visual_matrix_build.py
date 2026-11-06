#!/usr/bin/env python3
"""Create a local, reproducible-input visual-matrix build bundle.

This captures dirty working-tree content and an explicitly supplied markdown
source tree; neither is asserted to match a Git commit. The build record is
local consistency evidence, not a signed attestation or complete toolchain
proof. The markdown Git dependency is rewritten only in a disposable build
copy, so cjpm cannot silently use a cached or network checkout.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tomllib

from visual_evidence import canonical, digest
from visual_matrix_runner import sha_file, write_json
from native_sdk import sdk_environment, verify_sdk

DIRS = ('packages/core', 'packages/diff', 'packages/game', 'packages/media', 'packages/terminal',
        'packages/markdown_adapter', 'examples/visual_matrix')
FILES = ('scripts/visual_inventory.py', 'scripts/visual_inventory.json',
         'scripts/visual_evidence.py', 'scripts/visual_matrix_build.py',
         'scripts/visual_matrix_runner.py', 'scripts/visual_capture.py', 'scripts/native_sdk.py')
EXCLUDE = {'.git', '.cjpm', '__pycache__', 'target', 'build', '.cache', 'build-script-cache'}
GIT_DEP = {'git': 'https://github.com/lIlIIlIll/markdown.git', 'tag': 'v0.9.1', 'output-type': 'static'}


def walk(directory, prefix):
    result = {}
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f'missing or symlinked input directory: {prefix}')
    for parent, dirs, names in os.walk(directory, followlinks=False):
        dirs[:] = sorted(x for x in dirs if x not in EXCLUDE)
        for name in dirs:
            if (Path(parent) / name).is_symlink():
                raise ValueError('symlinked input directory is unsupported')
        for name in sorted(names):
            path = Path(parent) / name
            if path.is_symlink() or not path.is_file():
                raise ValueError('symlinked or non-regular source is unsupported')
            key = (Path(prefix) / path.relative_to(directory)).as_posix()
            result[key] = sha_file(path)
    return result


def inventory(source, markdown):
    found = {}
    for part in DIRS:
        found.update(walk(source / part, part))
    for part in FILES:
        path = source / part
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'missing or symlinked input file: {part}')
        found[part] = sha_file(path)
    found.update(walk(markdown, 'vendor/markdown'))
    if not found:
        raise ValueError('empty input')
    return dict(sorted(found.items()))


def validate_dependencies(root):
    pending = [root / 'examples/visual_matrix']
    seen = set()
    while pending:
        directory = pending.pop().resolve(strict=True)
        if not directory.is_relative_to(root.resolve()):
            raise ValueError('dependency escapes source snapshot')
        if directory in seen:
            continue
        seen.add(directory)
        file = directory / 'cjpm.toml'
        manifest = tomllib.loads(file.read_text(encoding='utf-8'))
        for name, dep in manifest.get('dependencies', {}).items():
            if not isinstance(dep, dict) or 'path' not in dep or 'git' in dep:
                raise ValueError(f'uncontrolled dependency {name} in {file.relative_to(root)}')
            path = (file.parent / dep['path']).resolve(strict=True)
            if not path.is_relative_to(root.resolve()) or not (path / 'cjpm.toml').is_file():
                raise ValueError(f'dependency escapes source snapshot: {name}')
            pending.append(path)


def verify_tool_identity(paths, expected):
    if {name: sha_file(path) for name, path in paths.items()} != expected:
        raise ValueError('build tool or runtime changed during build')


def verify_native_archive(path, expected):
    if sha_file(path) != expected:
        raise ValueError('native archive changed during Cangjie build')


def sanitize_tar_info(info):
    info.uid = info.gid = 0
    info.uname = info.gname = ''
    info.mtime = 0
    return info


def create_bundle(source, markdown, work, sdk_root):
    source, markdown = source.resolve(strict=True), markdown.resolve(strict=True)
    work = work.resolve()
    if work.exists() or work.is_relative_to(source) or work.is_relative_to(markdown):
        raise ValueError('work directory must not exist and must be outside both input trees')
    before = inventory(source, markdown)
    for name in ('visual_matrix_build.py', 'visual_matrix_runner.py', 'visual_capture.py', 'visual_evidence.py', 'native_sdk.py'):
        if sha_file(Path(__file__).parent / name) != before['scripts/' + name]:
            raise ValueError('executing build helper differs from source snapshot')
    work.mkdir(parents=True)
    snapshot = work / 'source'
    snapshot.mkdir()
    for key in before:
        rel = Path(key)
        origin = markdown / rel.relative_to('vendor/markdown') if key.startswith('vendor/markdown/') else source / rel
        dest = snapshot / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin, dest)
    copied = inventory(snapshot, snapshot / 'vendor/markdown')
    if before != copied or before != inventory(source, markdown):
        raise ValueError('input changed during snapshot')
    source_digest = digest(canonical(before))
    manifest = {'kind': 'provisional-dirty-worktree', 'algorithm': 'sha256-canonical-path-to-file-sha256-json',
                'source_snapshot_sha256': source_digest, 'files': before}
    write_json(snapshot / 'snapshot-manifest.json', manifest)
    archive = work / 'source.tar'
    with tarfile.open(archive, 'w') as tar:
        for key in [*before, 'snapshot-manifest.json']:
            tar.add(snapshot / key, arcname=key, recursive=False, filter=sanitize_tar_info)
    build = work / 'build'
    shutil.copytree(snapshot, build)
    adapter = build / 'packages/markdown_adapter/cjpm.toml'
    text = adapter.read_text(encoding='utf-8')
    parsed = tomllib.loads(text)
    if parsed.get('dependencies', {}).get('markdown') != GIT_DEP:
        raise ValueError('unexpected markdown dependency; update the controlled rewrite')
    old = '"markdown" = { git = "https://github.com/lIlIIlIll/markdown.git", tag = "v0.9.1", output-type = "static" }'
    new = '"markdown" = { path = "../../vendor/markdown", output-type = "static" }'
    if text.count(old) != 1:
        raise ValueError('markdown dependency syntax changed; refusing rewrite')
    adapter.write_text(text.replace(old, new), encoding='utf-8')
    (build / 'packages/markdown_adapter/cjpm.lock').unlink(missing_ok=True)
    (build / 'examples/visual_matrix/cjpm.lock').unlink(missing_ok=True)
    validate_dependencies(build)
    sdk, env, runtime = sdk_environment(str(sdk_root))
    cjc_version, cjpm_version = verify_sdk(sdk, env)
    for name, default in (('CC', 'cc'), ('AR', 'ar')):
        resolved = shutil.which(env.get(name, default))
        if not resolved:
            raise ValueError(f'missing native build tool: {name}')
        tool = Path(resolved).resolve(strict=True)
        env[name] = str(tool)
    tool_paths = {'cjc': sdk / 'bin/cjc', 'cjpm': sdk / 'tools/bin/cjpm',
                  'runtime': runtime, 'cc': Path(env['CC']), 'ar': Path(env['AR'])}
    tool_hashes = {name: sha_file(path) for name, path in tool_paths.items()}
    env['MARKDOWN_NATIVE_SCANNER'] = '0'
    target = work / 'target'
    with (work / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run(['sh', str(build / 'packages/core/native/build.sh')], cwd=build, env=env,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
        native_archive = build / 'packages/core/native/build/libtermcanvas_posix.a'
        native_sha = sha_file(native_archive)
        subprocess.run([str(sdk / 'tools/bin/cjpm'), 'build', '--target-dir', str(target)],
                       cwd=build / 'examples/visual_matrix', env=env, stdout=log,
                       stderr=subprocess.STDOUT, check=True)
    renderer = target / 'release/bin/main'
    if not renderer.is_file() or not os.access(renderer, os.X_OK):
        raise ValueError('renderer missing or not executable')
    verify_tool_identity(tool_paths, tool_hashes)
    verify_native_archive(native_archive, native_sha)
    if inventory(snapshot, snapshot / 'vendor/markdown') != before:
        raise ValueError('snapshot changed during build')
    for name in ('visual_matrix_build.py', 'visual_matrix_runner.py', 'visual_capture.py', 'visual_evidence.py', 'native_sdk.py'):
        if sha_file(Path(__file__).parent / name) != before['scripts/' + name]:
            raise ValueError('executing build helper changed during build')
    built_files = inventory(build, build / 'vendor/markdown')
    expected_files = dict(before)
    expected_files['packages/markdown_adapter/cjpm.toml'] = sha_file(adapter)
    # cjpm is allowed to regenerate the local dependency lock.
    for lock in ('packages/markdown_adapter/cjpm.lock', 'examples/visual_matrix/cjpm.lock'):
        built_files.pop(lock, None)
        expected_files.pop(lock, None)
    if built_files != expected_files:
        raise ValueError('build input set changed during build')
    for key, expected in before.items():
        path = build / key
        if key == 'packages/markdown_adapter/cjpm.toml':
            if path.read_text(encoding='utf-8') != text.replace(old, new):
                raise ValueError('rewritten build manifest changed during build')
        elif key in ('packages/markdown_adapter/cjpm.lock', 'examples/visual_matrix/cjpm.lock'):
            # cjpm may regenerate this file for the local dependency.
            continue
        elif not path.is_file() or path.is_symlink() or sha_file(path) != expected:
            raise ValueError(f'build input changed: {key}')
    launcher = snapshot / 'examples/visual_matrix/launch.py'
    record = {'kind': 'local-build-record-not-attestation', 'source_snapshot_sha256': source_digest,
              'source_archive_sha256': sha_file(archive), 'renderer_sha256': sha_file(renderer),
              'launcher_sha256': sha_file(launcher), 'source_revision_verified': False,
              'build_source_link_independently_verified': False,
              'dependency_rewrite': {'path': 'packages/markdown_adapter/cjpm.toml',
                                     'before_sha256': digest(text.encode()),
                                     'after_sha256': sha_file(adapter), 'markdown_source': 'vendor/markdown',
                                     'commit_or_tag_verified': False},
              'toolchain': {'cjc_version': cjc_version, 'cjpm_version': cjpm_version,
                            'cjc_sha256': tool_hashes['cjc'],
                            'cjpm_sha256': tool_hashes['cjpm'],
                            'runtime_sha256': tool_hashes['runtime'],
                            'cc_sha256': tool_hashes['cc'], 'ar_sha256': tool_hashes['ar']},
              'native_archive_sha256': native_sha,
              'limitations': ['local unsigned record', 'dynamic libraries not fully inventoried',
                              'compiler and native toolchain inputs not fully inventoried',
                              'network isolation not verified', 'visual review not performed']}
    write_json(work / 'build-record.json', record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'markdown', 'work', 'sdk'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = create_bundle(args.source, args.markdown, args.work, args.sdk)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, tomllib.TOMLDecodeError) as error:
        print(json.dumps({'error': f'{type(error).__name__}: {error}'}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
