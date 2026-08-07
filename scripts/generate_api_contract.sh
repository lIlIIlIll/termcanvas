#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/api-contract-v1.txt"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
RG=${RG:-rp-rg}

# Keep the versioned integration inventory independent of source line numbers.
# Consumers pin the SHA-256 of this file, so any public declaration change is
# explicit even when a sibling path dependency is used for local development.
(
    cd "$ROOT"
    "$RG" --no-line-number --with-filename \
        'public (class|struct|enum|interface|func|type)' packages/*/src \
        | sort > "$TMP"
)

if [[ "${1:-}" == "--check" ]]; then
    if ! cmp -s "$TMP" "$OUT"; then
        echo "api contract is stale; run scripts/generate_api_contract.sh" >&2
        diff -u "$OUT" "$TMP" >&2 || true
        exit 1
    fi
    echo "api contract v1 ok"
    exit 0
fi

cp "$TMP" "$OUT"
echo "wrote docs/api-contract-v1.txt"
