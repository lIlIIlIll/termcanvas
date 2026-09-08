#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

build_example() {
    local example="$1"
    if ! "$ROOT/scripts/cangjie_cmd.sh" "$example" cjpm build; then
        echo "retrying $(basename "$example") after dependency archive race"
        "$ROOT/scripts/cangjie_cmd.sh" "$example" cjpm build
    fi
}

for example in "$ROOT"/examples/*; do
    if [[ -f "$example/cjpm.toml" ]]; then
        echo "==> $(basename "$example")"
        build_example "$example"
    fi
done
