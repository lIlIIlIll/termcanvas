#!/usr/bin/env python3
"""Audit the fixture inventory against source without claiming full coverage.

Direct Widget declarations and public Canvas/Buffer drawing methods are a
conservative discovery aid, not a language parser or proof that all visual
surfaces and applicable states were found. Every unimplemented item is missing;
even implemented items retain an explicit state-completeness review gap.
"""
import argparse
import json
from pathlib import Path
import re
import sys

from visual_evidence import COLORS, GLYPHS, TERMINALS, canonical, digest, matrix_from_inventory

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / 'scripts' / 'visual_inventory.json'
WIDGET = re.compile(r'\b(?:public\s+)?class\s+(\w+)(?:\s*<[^\n{]+)?\s*<:\s*([^\n{]+)')
METHOD = re.compile(r'\bpublic\s+func\s+(\w+)\s*\(')
DRAW_METHODS = {'fill', 'fillRect', 'fillLine', 'hline', 'vline', 'strokeRect', 'strokeBorder',
                'drawLine', 'drawText', 'drawSprite', 'render', 'composite', 'setCell', 'setString',
                'writeAsciiSpan', 'blitFrom', 'addMedia', 'withClip', 'translated', 'viewport', 'renderWidget'}
GAME_DRAW_METHODS = {'SpriteRenderer': {'render', 'drawSprite'}, 'TileMap': {'render'}}


def discover(root=ROOT):
    found = {}
    for package in (root / 'packages').iterdir():
        src = package / 'src'
        if not src.is_dir() or package.name in ('testing', 'example_smoke'):
            continue
        for path in sorted(src.glob('*.cj')):
            if path.name.endswith('_test.cj'):
                continue
            text = path.read_text(encoding='utf-8')
            for match in WIDGET.finditer(text):
                if re.search(r'\bWidget\b', match.group(2)):
                    found[f'{package.name}.{match.group(1)}'] = path.relative_to(root).as_posix()
            if package.name == 'core' and path.name in ('canvas.cj', 'buffer.cj', 'terminal.cj'):
                name = {'canvas.cj': 'Canvas', 'buffer.cj': 'Buffer', 'terminal.cj': 'Frame'}[path.name]
                # Restrict to methods within the named class; the source includes
                # unrelated public types before and after these definitions.
                start = text.find(f'public class {name} ')
                if start < 0:
                    continue
                body = text[start:]
                next_class = re.search(r'\n(?:public\s+)?(?:class|struct|interface|enum)\s+\w+', body[1:])
                if next_class:
                    body = body[:next_class.start() + 1]
                for method in METHOD.findall(body):
                    if method in DRAW_METHODS:
                        found[f'core.{name}.{method}'] = path.relative_to(root).as_posix()
            if package.name == 'game' and path.name == 'game.cj':
                for name, methods in GAME_DRAW_METHODS.items():
                    start = text.find(f'public class {name} ')
                    if start < 0:
                        continue
                    body = text[start:]
                    next_class = re.search(r'\n(?:public\s+)?(?:class|struct|interface|enum)\s+\w+', body[1:])
                    if next_class:
                        body = body[:next_class.start() + 1]
                    for method in METHOD.findall(body):
                        if method in methods:
                            found[f'game.{name}.{method}'] = path.relative_to(root).as_posix()
    return dict(sorted(found.items()))


def validate_supported_case(case, inventory=None):
    inventory = inventory or json.loads(INVENTORY.read_text(encoding='utf-8'))
    payload = {k: v for k, v in case.items() if k != 'id'}
    if case.get('id') != digest(canonical(payload)):
        raise ValueError('case id does not match parameters')
    subjects = {s['id']: s for s in inventory['subjects']}
    subject = subjects.get(case.get('subject'))
    if not subject or case.get('kind') != subject['kind'] or case.get('high_risk') != subject['high_risk']:
        raise ValueError('subject is not implemented by the fixture')
    if (case.get('state') not in subject['states'] or case.get('theme') not in inventory['themes'] or
            case.get('glyph') not in GLYPHS or case.get('color') not in COLORS or
            tuple(case.get('terminal_cells', [])) not in TERMINALS or case.get('widget_cells') not in subject['widget_sizes']):
        raise ValueError('requested combination is not implemented by the fixture')


def audit(root=ROOT, inventory=None):
    inventory = inventory or json.loads((root / 'scripts/visual_inventory.json').read_text(encoding='utf-8'))
    matrix = matrix_from_inventory(inventory)
    aliases = inventory.get('theme_aliases', {})
    if not isinstance(aliases, dict) or any(
            not isinstance(alias, str) or not isinstance(representative, str) or
            alias in inventory['themes'] or representative not in inventory['themes']
            for alias, representative in aliases.items()):
        raise ValueError('theme aliases must be distinct from and point to a declared theme')
    zero_area = sum(1 for case in matrix['cases'] if 0 in case['widget_cells'])
    declared = {s['id'] for s in inventory['subjects']}
    discovered = discover(root)
    return {'project_coverage_verified': False, 'scope': 'declared-inventory-only',
            'implemented_subjects': sorted(declared & discovered.keys()),
            'missing_subjects': {name: path for name, path in discovered.items() if name not in declared},
            'unknown_declared_subjects': sorted(declared - discovered.keys()),
            'declared_case_count': len(matrix['cases']),
            'declared_case_counts': {
                'zero_area_boundary': zero_area,
                'nonzero_area': len(matrix['cases']) - zero_area,
            },
            'theme_aliases_not_counted': aliases,
            'unverified_states_by_subject': {s['id']: s['unverified_states'] for s in inventory['subjects']
                                             if s.get('unverified_states')},
            'unverified': ['state completeness for every subject', 'indirect Widget implementations',
                'other drawing primitives and application-specific visual surfaces', 'terminal capture and image review',
                'macOS and Windows', 'nonzero area does not guarantee a visible or distinct widget'],
            'source_discovery': 'conservative text scan; manual review still required'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    result = audit(args.root)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if result['missing_subjects'] or result['unknown_declared_subjects'] or result['unverified'] else 0


if __name__ == '__main__':
    sys.exit(main())
