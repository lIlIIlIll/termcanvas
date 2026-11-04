#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cjtui-codecov}"

if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$ROOT/$OUTPUT_DIR"
fi

sdk_root=$("$ROOT/scripts/check_sdk.sh")
export CANGJIE_SDK_ROOT="$sdk_root"
# Use a clean target root so dependencies are rebuilt with coverage enabled.
export CJ_TUI_CANONICAL_TARGET_ROOT="$ROOT/.coverage-target"

# Never recursively erase an arbitrary caller-supplied directory. Only a
# directory marked by a previous coverage run belongs to this script.
OUTPUT_DIR=$(python3 - "$ROOT" "$OUTPUT_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
requested = Path(sys.argv[2])
output = requested.resolve()
marker = output / ".cjtui-coverage-output"
target = root / ".coverage-target"
if requested.is_symlink() or output == root or output in root.parents or output.is_relative_to(target):
    raise SystemExit(f"refusing unsafe coverage output: {requested}")
if output.exists():
    if not output.is_dir():
        raise SystemExit(f"coverage output is not a directory: {output}")
    if any(output.iterdir()) and not (marker.is_file() and marker.read_text() == "cjtui coverage\n"):
        raise SystemExit(f"coverage output contains unowned files; choose an empty directory: {output}")
    shutil.rmtree(output)
output.mkdir(parents=True)
marker.write_text("cjtui coverage\n")
print(output)
PY
)
rm -rf -- "$CJ_TUI_CANONICAL_TARGET_ROOT"
mkdir -p -- "$CJ_TUI_CANONICAL_TARGET_ROOT"

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

run_coverage_test "$ROOT/packages/core" "core coverage"
run_coverage_test "$ROOT/packages/markdown_adapter" "markdown adapter coverage"
run_coverage_test "$ROOT/packages/terminal" "terminal coverage"
run_coverage_test "$ROOT/packages/diff" "diff coverage"
run_coverage_test "$ROOT/packages/media" "media coverage"
run_coverage_test "$ROOT/packages/game" "game coverage"
run_coverage_test "$ROOT/packages/testing" "downstream testing API coverage"

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
    --include="$ROOT"
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

cp -- "$OUTPUT_DIR/coverage.xml" "$OUTPUT_DIR/coverage-cjcov.xml"
python3 "$ROOT/scripts/coverage_report.py" "$OUTPUT_DIR" --root "$ROOT"

printf 'coverage report: %s\n' "$OUTPUT_DIR/coverage.xml"
