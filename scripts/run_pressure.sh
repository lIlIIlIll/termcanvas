#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cjpm_test_jobs=()
if [[ ${TERMCANVAS_CJPM_JOBS+x} ]]; then
    if [[ ! $TERMCANVAS_CJPM_JOBS =~ ^[0-9]+$ || ! $TERMCANVAS_CJPM_JOBS =~ [1-9] ]]; then
        echo "TERMCANVAS_CJPM_JOBS must be a positive integer" >&2
        exit 2
    fi
    cjpm_test_jobs=(--jobs "$TERMCANVAS_CJPM_JOBS")
fi

echo "==> pressure-oriented unittest scenarios"
"$ROOT/scripts/cangjie_cmd.sh" "$ROOT/packages/core" cjpm test --no-color "${cjpm_test_jobs[@]}"

echo "==> build application examples under pressure gate"
"$ROOT/scripts/build_examples.sh"

echo "pressure gate ok"
