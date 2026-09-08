#!/usr/bin/env python3
"""Replay the recorded Linux diagnostics in a separate output directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / 'evidence'
ORIGINAL = '/tmp/cjtui-audit-20260908-3klxuhqr'
ORIGINAL_ROOT = '/home/elliot/playground/cj_tui'
ORIGINAL_SDK = '/home/elliot/cangjie_sdk/main/linux_x64/vanilla/20260817/cangjie'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', action='store_true')
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--run', metavar='CASE')
    selection.add_argument('--all', action='store_true')
    parser.add_argument('--sdk', default=os.environ.get('CANGJIE_SDK_ROOT'))
    parser.add_argument('--repo', type=Path, default=HERE.parents[2])
    parser.add_argument('--targets', type=Path, help='Existing canonical target root')
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    cases = json.loads((EVIDENCE / 'run-results.json').read_text())
    names = {x['name'] for x in cases}
    if args.list or not (args.run or args.all):
        print('\n'.join(sorted(names)))
        return
    if args.run and args.run not in names:
        parser.error('Unknown case; use --list')
    if not args.sdk:
        parser.error('Set --sdk or CANGJIE_SDK_ROOT to the recorded SDK')
    if args.skip_build and not args.targets:
        parser.error('--skip-build requires --targets')
    root = args.repo.resolve()
    sdk = Path(args.sdk).resolve()
    baseline = json.loads((EVIDENCE / 'baseline.json').read_text())
    changed = [x['path'] for x in baseline['files']
               if not (root / x['path']).is_file()
               or hashlib.sha256((root / x['path']).read_bytes()).hexdigest() != x['sha256']]
    if changed:
        parser.error('Source differs from recorded baseline: ' + ', '.join(changed[:8]))
    out = Path(tempfile.mkdtemp(prefix='cjtui-review-replay-'))
    targets = args.targets.resolve() if args.targets else out / 'targets'
    print(f'Output: {out}', flush=True)
    for directory in ['logs', 'probes']:
        (out / directory).mkdir()
    for group in ['runtime', 'render', 'widgets', 'extensions']:
        (out / group).mkdir()
        for source in (EVIDENCE / group).iterdir():
            if source.suffix == '.cj' or source.name.startswith('fake_'):
                shutil.copy2(source, out / group / source.name)
    env = {**os.environ, 'CANGJIE_SDK_ROOT': str(sdk),
           'CJ_TUI_CANONICAL_TARGET_ROOT': str(targets), 'DISABLE_ZOXIDE': '1'}
    if not args.skip_build:
        for package in ['core', 'cj_markdown', 'markdown', 'terminal', 'diff', 'media', 'game']:
            subprocess.run(['bash', 'scripts/cangjie_cmd.sh', 'packages/' + package,
                            'cjpm', 'build'], cwd=root, env=env, check=True)

    def relocated(name):
        source = (EVIDENCE / name).read_text()
        for old, new in [(ORIGINAL, str(out)), (ORIGINAL_ROOT, str(root)), (ORIGINAL_SDK, str(sdk))]:
            source = source.replace(repr(old), repr(new))
        return source.replace("a/'targets'/key", "Path(" + repr(str(targets)) + ")/key")

    compiler = relocated('compile_probes.py')
    exec(compile(compiler, str(EVIDENCE / 'compile_probes.py'), 'exec'), {'__name__': '__main__'})
    compiled = json.loads((out / 'compile-results.json').read_text())
    if any(x['returncode'] for x in compiled):
        raise SystemExit('Compilation failed; see output logs')
    runner = relocated('run_probes.py')
    if args.run:
        marker = 'results=[]\nfor binary,args in cases:'
        selected = repr(args.run)
        runner = runner.replace(marker, 'cases=[(b,a) for b,a in cases if b+"-"+(a[0] if a else "all")=='+selected+']\n'+marker)
    exec(compile(runner, str(EVIDENCE / 'run_probes.py'), 'exec'), {'__name__': '__main__'})
    print('Diagnostics recorded; compare observations, not only exit codes.', flush=True)


if __name__ == '__main__':
    main()
