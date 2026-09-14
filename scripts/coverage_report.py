#!/usr/bin/env python3
"""Keep reported production coverage separate from the legacy CI gate scope."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

# These are legacy exceptions, not assertions that the files contain only OS
# code. In particular event parsing and diff planning remain coverage debt.
GATE_EXCLUSIONS = frozenset({
    "packages/core/src/app.cj",
    "packages/core/src/event.cj",
    "packages/core/src/pty.cj",
    "packages/core/src/terminal.cj",
})

FILE_PATTERN = re.compile(
    r'<td class="headerName">File:</td>\s*'
    r'<td class="headerValue">([^<]+)</td>',
)


def counter_pattern(label: str) -> re.Pattern[str]:
    return re.compile(
        rf'<td class="headerName">{label}:</td>\s*'
        r'<td class="headerTableEntry">(\d+)</td>\s*'
        r'<td class="headerTableEntry">(\d+)</td>',
    )


LINE_PATTERN = counter_pattern("Lines")
BRANCH_PATTERN = counter_pattern("Branches")


@dataclass(frozen=True)
class Counts:
    covered_lines: int
    total_lines: int
    covered_branches: int
    total_branches: int

    def __post_init__(self) -> None:
        for hits, total in ((self.covered_lines, self.total_lines),
                            (self.covered_branches, self.total_branches)):
            if not 0 <= hits <= total:
                raise ValueError(f"invalid coverage counters: {hits}/{total}")


def total_counts(rows: Iterable[Counts]) -> Counts:
    values = [asdict(row) for row in rows]
    return Counts(**{
        key: sum(row[key] for row in values)
        for key in Counts.__dataclass_fields__
    })


def normalize_source(source: str, root: Path) -> str:
    source = html.unescape(source).strip().replace("\\", "/")
    path = Path(source)
    if path.is_absolute():
        try:
            path = path.relative_to(root.resolve())
        except ValueError as error:
            raise ValueError(f"coverage source outside repository: {source}") from error
    if ".." in path.parts:
        raise ValueError(f"invalid coverage source: {source}")
    return path.as_posix()


def collect_files(output: Path, root: Path) -> dict[str, Counts]:
    files: dict[str, Counts] = {}
    for page in sorted(output.glob("*.html")):
        text = page.read_text(encoding="utf-8")
        match = FILE_PATTERN.search(text)
        if match is None:
            continue  # Index pages have no per-file counters.
        source = normalize_source(match.group(1), root)
        if (not source.startswith("packages/") or
                not source.endswith(".cj") or source.endswith("_test.cj")):
            continue
        lines = LINE_PATTERN.search(text)
        branches = BRANCH_PATTERN.search(text)
        if lines is None or branches is None:
            raise ValueError(f"missing coverage counters for {source}: {page.name}")
        counts = Counts(*(int(value) for value in (*lines.groups(), *branches.groups())))
        if source in files and files[source] != counts:
            raise ValueError(f"conflicting coverage pages for {source}")
        files[source] = counts  # Identical duplicate pages must not inflate totals.
    if not files:
        raise ValueError("coverage scope is empty")
    return files


def write_xml(path: Path, counts: Counts) -> None:
    report = ET.Element("coverage-data")
    for tag, value in (
        ("coverage-line", counts.covered_lines),
        ("total-line", counts.total_lines),
        ("coverage-branch", counts.covered_branches),
        ("total-branch", counts.total_branches),
        ("coverage-function", 0),
        ("total-function", 0),
    ):
        ET.SubElement(report, tag).text = str(value)
    ET.ElementTree(report).write(path, encoding="utf-8", xml_declaration=True)


def generate_reports(output: Path, root: Path) -> tuple[Counts, Counts]:
    files = collect_files(output, root)
    gated = {source: counts for source, counts in files.items()
             if source not in GATE_EXCLUSIONS}
    production = total_counts(files.values())
    gate = total_counts(gated.values())
    if not gated or gate.total_lines == 0 or gate.total_branches == 0:
        raise ValueError("coverage gate scope is empty")

    # Codecov receives all reported production files, including the four legacy
    # exceptions. Only the separate gate report uses the historical subset.
    write_xml(output / "coverage.xml", production)
    write_xml(output / "coverage-gate.xml", gate)
    scope = {
        "production": {"files": sorted(files), **asdict(production)},
        "gate": {"files": sorted(gated), **asdict(gate)},
        "gate_exclusions": {
            source: {
                "reported": source in files,
                "counts": asdict(files[source]) if source in files else None,
                "reason": "Legacy gate exemption; includes deterministic logic. "
                          "Included in production coverage when reported.",
            }
            for source in sorted(GATE_EXCLUSIONS)
        },
    }
    (output / "coverage-scope.json").write_text(
        json.dumps(scope, indent=2, sort_keys=True) + "\n", encoding="utf-8",
    )
    return production, gate


def describe(label: str, counts: Counts) -> str:
    line_rate = counts.covered_lines / counts.total_lines if counts.total_lines else 0.0
    branch_rate = counts.covered_branches / counts.total_branches if counts.total_branches else 0.0
    return (f"{label}: lines={counts.covered_lines}/{counts.total_lines} ({line_rate:.2%}); "
            f"branches={counts.covered_branches}/{counts.total_branches} ({branch_rate:.2%})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args(argv)
    try:
        production, gate = generate_reports(args.output, args.root)
    except (ValueError, OSError) as error:
        print(f"coverage report error: {error}", file=sys.stderr)
        return 1
    print(describe("All reported production files", production))
    print(describe("Legacy CI gate (not full production coverage)", gate))
    print("Gate exemptions are recorded in coverage-scope.json: " +
          ", ".join(sorted(GATE_EXCLUSIONS)))
    # Integer arithmetic preserves the exact existing >=90% / >=80% gates.
    if (gate.covered_lines * 100 < gate.total_lines * 90 or
            gate.covered_branches * 100 < gate.total_branches * 80):
        print("coverage thresholds not met: require lines >= 90% and branches >= 80%",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
