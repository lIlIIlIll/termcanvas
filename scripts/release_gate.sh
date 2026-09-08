#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sdk_root=$("$ROOT/scripts/check_sdk.sh")
export CANGJIE_SDK_ROOT="$sdk_root"
export TERMCANVAS_CANONICAL_TARGET_ROOT="${TERMCANVAS_CANONICAL_TARGET_ROOT:-${TMPDIR:-/tmp}/termcanvas-canonical-target/1.1.3}"

echo "==> canonical Cangjie SDK"
"$ROOT/scripts/check_sdk.sh" --report
printf 'CANONICAL_TARGET_ROOT=%s\n' "$TERMCANVAS_CANONICAL_TARGET_ROOT"
printf 'SOURCE_CANDIDATE_SHA256=%s\n' "$(
  sha256sum \
    "$ROOT/packages/core/src/content_widgets.cj" \
    "$ROOT/packages/core/src/lib_test.cj" \
    "$ROOT/packages/core/src/performance_test.cj" |
    sha256sum | cut -d' ' -f1
)"

run_cjpm_test() {
    local dir="$1"
    local label="$2"
    echo "==> $label"
    "$ROOT/scripts/cangjie_cmd.sh" "$dir" cjpm test --no-color
}

run_cjpm_test "$ROOT/packages/cj_markdown" "cj_markdown tests"
run_cjpm_test "$ROOT/packages/core" "core tests"
run_cjpm_test "$ROOT/packages/markdown" "markdown adapter tests"
run_cjpm_test "$ROOT/packages/terminal" "terminal tests"
run_cjpm_test "$ROOT/packages/diff" "diff tests"
run_cjpm_test "$ROOT/packages/media" "media tests"
run_cjpm_test "$ROOT/packages/game" "game tests"

echo "==> event script syntax"
"$ROOT/scripts/run_event_script.sh" "$ROOT/packages/core/tests/events/basic.events" "$ROOT/packages/core/tests/events/scenario.events"

echo "==> golden snapshot files"
"$ROOT/scripts/check_golden_snapshots.sh"

echo "==> api index"
"$ROOT/scripts/generate_api_index.sh" --check

echo "==> versioned api contract"
"$ROOT/scripts/generate_api_contract.sh" --check

echo "==> api extractor fixtures"
python3 "$ROOT/scripts/test_api_contract.py"

echo "==> SDK resolver local fixtures"
python3 "$ROOT/scripts/test_resolve_nightly_sdk.py"

echo "==> Windows smoke wrapper local fixtures"
python3 "$ROOT/scripts/test_windows_smoke.py"

echo "==> architecture classification and fitness contracts"
python3 "$ROOT/scripts/validate_architecture.py"

echo "==> unicode generated data"
python3 "$ROOT/scripts/generate_unicode_tables.py" --check

echo "==> examples"
"$ROOT/scripts/build_examples.sh"

echo "==> example package tests"
declare -A tested_examples=()
while IFS= read -r -d '' test_file; do
    example_dir=${test_file%/src/*}
    if [[ -n "${tested_examples[$example_dir]:-}" ]]; then
        continue
    fi
    tested_examples[$example_dir]=1
    run_cjpm_test "$example_dir" "example tests: ${example_dir#"$ROOT/"}"
done < <(find "$ROOT/examples" -mindepth 3 -maxdepth 3 -type f -name '*_test.cj' -print0 | sort -z)

echo "==> example smoke checks"
"$ROOT/scripts/test_examples.sh"

echo "==> scripted example workflows"
"$ROOT/scripts/cangjie_cmd.sh" "$ROOT/packages/example_smoke" cjpm run

echo "==> pressure gate"
"$ROOT/scripts/run_pressure.sh"

echo "release gate ok"
