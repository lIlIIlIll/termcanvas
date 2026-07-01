#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYGROUND="$(cd "$ROOT/.." && pwd)"
CJ_MARKDOWN_DIR="${CJ_MARKDOWN_DIR:-$PLAYGROUND/cj_markdown}"

run_cjpm_test() {
    local dir="$1"
    local label="$2"
    echo "==> $label"
    "$ROOT/scripts/cangjie_cmd.sh" "$dir" cjpm test --no-color
}

if [[ ! -d "$CJ_MARKDOWN_DIR" ]]; then
    echo "missing cj_markdown dependency: $CJ_MARKDOWN_DIR" >&2
    echo "set CJ_MARKDOWN_DIR to the standalone cj_markdown checkout" >&2
    exit 2
fi

run_cjpm_test "$CJ_MARKDOWN_DIR" "cj_markdown tests"
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

echo "==> examples"
"$ROOT/scripts/build_examples.sh"

echo "==> example smoke checks"
"$ROOT/scripts/test_examples.sh"

echo "==> pressure gate"
"$ROOT/scripts/run_pressure.sh"

echo "release gate ok"
