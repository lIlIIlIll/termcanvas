#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cjpm_build_jobs=()
if [[ ${TERMCANVAS_CJPM_JOBS+x} ]]; then
    if [[ ! $TERMCANVAS_CJPM_JOBS =~ ^[0-9]+$ || ! $TERMCANVAS_CJPM_JOBS =~ [1-9] ]]; then
        echo "TERMCANVAS_CJPM_JOBS must be a positive integer" >&2
        exit 2
    fi
    cjpm_build_jobs=(--jobs "$TERMCANVAS_CJPM_JOBS")
fi

build_example() {
    local example="$1"
    if ! "$ROOT/scripts/cangjie_cmd.sh" "$example" cjpm build "${cjpm_build_jobs[@]}"; then
        echo "retrying $(basename "$example") after dependency archive race"
        "$ROOT/scripts/cangjie_cmd.sh" "$example" cjpm build "${cjpm_build_jobs[@]}"
    fi
}

for example in "$ROOT"/examples/*; do
    if [[ -f "$example/cjpm.toml" ]]; then
        echo "==> $(basename "$example")"
        build_example "$example"
    fi
done
