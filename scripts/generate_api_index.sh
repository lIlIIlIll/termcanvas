#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/api-index.txt"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

(cd "$ROOT" && rg -n 'public (class|struct|enum|interface|func|type)' packages/*/src | sort > "$TMP")

if [[ "${1:-}" == "--check" ]]; then
    if ! cmp -s "$TMP" "$OUT"; then
        echo "api index is stale; run scripts/generate_api_index.sh" >&2
        diff -u "$OUT" "$TMP" >&2 || true
        exit 1
    fi
    echo "api index ok"
    exit 0
fi

cp "$TMP" "$OUT"
echo "wrote docs/api-index.txt"
