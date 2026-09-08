#!/usr/bin/env python3
"""Check the recorded baseline, evidence references and artifact checksums."""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EVIDENCE = HERE / 'evidence'
ORIGINAL = '/tmp/termcanvas-audit-20260908-3klxuhqr/'


def main():
    errors = []
    for path in HERE.rglob('*.json'):
        try:
            json.loads(path.read_text())
        except (ValueError, UnicodeError) as exc:
            errors.append(f'{path.relative_to(HERE)}: {exc}')
    baseline = json.loads((EVIDENCE / 'baseline.json').read_text())['files']
    ledger = json.loads((EVIDENCE / 'coverage/coverage_ledger.json').read_text())
    baseline_paths = {x['path'] for x in baseline}
    if len(ledger) != len(baseline) or {x['path'] for x in ledger} != baseline_paths:
        errors.append('Coverage paths do not match baseline')
    for item in baseline:
        path = ROOT / item['path']
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
            errors.append('Baseline changed: ' + item['path'])
    findings = json.loads((EVIDENCE / 'synthesis/unified_findings.json').read_text())
    mappings = json.loads((EVIDENCE / 'synthesis/rejected_or_merged.json').read_text())
    source_ids = [s for item in findings for s in item['source_ids']]
    expected = {f'{prefix}-{i:02}' for prefix, count in [('RT',17),('IN',23),('WD',24),('EX',22),('DOC',8),('TOOL',6)] for i in range(1,count+1)}
    if set(source_ids) != expected or len(source_ids) != len(expected):
        errors.append('Finding source IDs are missing or duplicated')
    if {x['source_id'] for x in mappings} != expected or len(mappings) != len(expected):
        errors.append('Candidate mapping is incomplete')
    ownership = {s:f['id'] for f in findings for s in f['source_ids']}
    for item in mappings:
        if ownership.get(item['source_id']) != item['target_id']:
            errors.append('Mapping target mismatch: ' + item['source_id'])
    for item in findings:
        for path in item['verification_logs']:
            if not (EVIDENCE / path).is_file():
                errors.append('Missing evidence: ' + path)
        for location in item['locations']:
            path, line = location.rsplit(':', 1)
            if not (ROOT/path).is_file() or not 1 <= int(line) <= len((ROOT/path).read_text().splitlines()):
                errors.append('Invalid source location: ' + location)
    for name in ['README.md','findings.md','validation.md','reproduction.md']:
        for link in re.findall(r'\]\(([^)]+)\)', (HERE/name).read_text()):
            path = link.split('#')[0]
            if path and not path.startswith(('https://','http://')) and not (HERE/path).exists():
                errors.append(f'Broken link in {name}: {link}')
    compiled = json.loads((EVIDENCE/'compile-results.json').read_text())
    runs = json.loads((EVIDENCE/'run-results.json').read_text())
    if len(compiled) != 11 or len(runs) != 75:
        errors.append('Unexpected original compilation or case count')
    for item in compiled:
        path = EVIDENCE/item['source'].removeprefix(ORIGINAL)
        if hashlib.sha256(path.read_bytes()).hexdigest() != item['source_sha256']:
            errors.append('Probe source hash mismatch: '+str(path))
    for item in compiled+runs:
        if not (EVIDENCE/item['log'].removeprefix(ORIGINAL)).is_file():
            errors.append('Missing original log: '+item['log'])
    manifest = HERE/'artifact-manifest.sha256'
    for line in manifest.read_text().splitlines():
        digest, name = line.split('  ',1)
        path = HERE/name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append('Artifact hash mismatch: '+name)
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'PASS: {len(baseline)} baseline files, {len(findings)} findings, 100 source IDs, 11 probe sources, 75 case logs; links and artifact hashes match.')


if __name__ == '__main__':
    main()
