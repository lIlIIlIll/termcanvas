#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_cjpm_test() {
    local dir="$1"
    local label="$2"
    echo "==> $label"
    "$ROOT/scripts/cangjie_cmd.sh" "$dir" cjpm test --no-color
}

run_cjpm_test "$ROOT/packages/cj_markdown" "cj_markdown tests"
run_cjpm_test "$ROOT/packages/core" "core tests"
run_cjpm_test "$ROOT/packages/document" "document facade tests"
run_cjpm_test "$ROOT/packages/editor" "editor facade tests"
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

echo "==> unicode generated data"
python3 "$ROOT/scripts/generate_unicode_tables.py" --check

echo "==> examples"
"$ROOT/scripts/build_examples.sh"

echo "==> example smoke checks"
"$ROOT/scripts/test_examples.sh"

echo "==> scripted example workflows"
"$ROOT/scripts/cangjie_cmd.sh" "$ROOT/packages/example_smoke" cjpm run

echo "==> pressure gate"
"$ROOT/scripts/run_pressure.sh"

echo "release gate ok"
