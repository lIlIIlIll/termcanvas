#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/termcanvas-codecov}"

if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$ROOT/$OUTPUT_DIR"
fi

sdk_root=$("$ROOT/scripts/check_sdk.sh")
export CANGJIE_SDK_ROOT="$sdk_root"
# Use a clean target root so dependencies are rebuilt with coverage enabled.
export TERMCANVAS_CANONICAL_TARGET_ROOT="$ROOT/.coverage-target"

rm -rf -- "$OUTPUT_DIR" "$TERMCANVAS_CANONICAL_TARGET_ROOT"
mkdir -p -- "$OUTPUT_DIR" "$TERMCANVAS_CANONICAL_TARGET_ROOT"

# Do not accumulate counters from an earlier local run.
while IFS= read -r -d '' artifact; do
    rm -f -- "$artifact"
done < <(
    find "$ROOT/packages" "$ROOT/examples" -type f \
        \( -name '*.gcda' -o -name '*.gcno' -o -name '*.gcov' \) \
        -print0
)

run_coverage_test() {
    local package_dir="$1"
    local label="$2"
    echo "==> $label"
    "$ROOT/scripts/cangjie_cmd.sh" "$package_dir" cjpm test --no-color --coverage
}

run_coverage_test "$ROOT/packages/cj_markdown" "cj_markdown coverage"
run_coverage_test "$ROOT/packages/core" "core coverage"
run_coverage_test "$ROOT/packages/markdown" "markdown adapter coverage"
run_coverage_test "$ROOT/packages/terminal" "terminal coverage"
run_coverage_test "$ROOT/packages/diff" "diff coverage"
run_coverage_test "$ROOT/packages/media" "media coverage"
run_coverage_test "$ROOT/packages/game" "game coverage"

declare -A tested_examples=()
while IFS= read -r -d '' test_file; do
    example_dir=${test_file%/src/*}
    if [[ -n "${tested_examples[$example_dir]:-}" ]]; then
        continue
    fi
    tested_examples[$example_dir]=1
    run_coverage_test "$example_dir" "example coverage: ${example_dir#"$ROOT/"}"
done < <(
    find "$ROOT/examples" -mindepth 3 -maxdepth 3 -type f \
        -name '*_test.cj' -print0 | sort -z
)

echo "==> cjcov report"
cjcov_args=(
    --root="$ROOT"
    --source="$ROOT/packages $ROOT/examples"
    --xml
    --branches
    --html-details
    --output="$OUTPUT_DIR"
)
"$ROOT/scripts/cangjie_cmd.sh" "$ROOT" cjcov "${cjcov_args[@]}"

if [[ ! -s "$OUTPUT_DIR/coverage.xml" ]]; then
    echo "coverage report was not generated: $OUTPUT_DIR/coverage.xml" >&2
    exit 1
fi

python3 - "$OUTPUT_DIR" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

output = Path(sys.argv[1])
file_pattern = re.compile(
    r'<td class="headerName">File:</td>\s*'
    r'<td class="headerValue">([^<]+)</td>',
)
line_pattern = re.compile(
    r'<td class="headerName">Lines:</td>\s*'
    r'<td class="headerTableEntry">(\d+)</td>\s*'
    r'<td class="headerTableEntry">(\d+)</td>',
)
branch_pattern = re.compile(
    r'<td class="headerName">Branches:</td>\s*'
    r'<td class="headerTableEntry">(\d+)</td>\s*'
    r'<td class="headerTableEntry">(\d+)</td>',
)
excluded = {
    # These are OS/terminal lifecycle integration surfaces; they are exercised
    # by the package and example tests but are outside the deterministic package
    # widget/parser coverage gate.
    "packages/core/src/app.cj",
    "packages/core/src/event.cj",
    "packages/core/src/pty.cj",
    "packages/core/src/terminal.cj",
}

covered_lines = total_lines = covered_branches = total_branches = 0
included = []
for page in output.glob("*.html"):
    text = page.read_text(encoding="utf-8", errors="replace")
    file_match = file_pattern.search(text)
    line_match = line_pattern.search(text)
    branch_match = branch_pattern.search(text)
    if file_match is None or line_match is None or branch_match is None:
        continue
    source = file_match.group(1)
    if source.endswith("_test.cj") or source.startswith("examples/") or source in excluded:
        continue
    line_hit, line_total = (int(value) for value in line_match.groups())
    branch_hit, branch_total = (int(value) for value in branch_match.groups())
    covered_lines += line_hit
    total_lines += line_total
    covered_branches += branch_hit
    total_branches += branch_total
    included.append(source)

if not included or total_lines == 0 or total_branches == 0:
    raise SystemExit("coverage scope is empty")

line_rate = covered_lines / total_lines
branch_rate = covered_branches / total_branches
report = ET.Element("coverage-data")
for tag, value in (
    ("coverage-line", covered_lines),
    ("total-line", total_lines),
    ("coverage-branch", covered_branches),
    ("total-branch", total_branches),
    ("coverage-function", 0),
    ("total-function", 0),
):
    ET.SubElement(report, tag).text = str(value)
ET.ElementTree(report).write(output / "coverage.xml", encoding="utf-8", xml_declaration=True)

print(
    "coverage scope: "
    f"{len(included)} production package files; "
    f"lines={covered_lines}/{total_lines} ({line_rate:.2%}); "
    f"branches={covered_branches}/{total_branches} ({branch_rate:.2%})"
)
if line_rate < 0.90 or branch_rate < 0.80:
    raise SystemExit("coverage thresholds not met: require lines >= 90% and branches >= 80%")
PY

printf 'coverage report: %s\n' "$OUTPUT_DIR/coverage.xml"

