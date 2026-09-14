#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/termcanvas-codecov}"

if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$ROOT/$OUTPUT_DIR"
fi

echo "==> coverage report fixtures"
python3 "$ROOT/scripts/test_coverage_report.py"

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

# Preserve cjcov's unmodified report separately from the production summary.
cp -- "$OUTPUT_DIR/coverage.xml" "$OUTPUT_DIR/coverage-cjcov.xml"
python3 "$ROOT/scripts/coverage_report.py" "$OUTPUT_DIR" --root "$ROOT"

printf 'coverage report (all reported production files): %s\n' "$OUTPUT_DIR/coverage.xml"
printf 'coverage gate (legacy exemptions): %s\n' "$OUTPUT_DIR/coverage-gate.xml"
