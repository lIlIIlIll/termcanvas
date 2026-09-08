#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$ROOT/packages/core/tests/golden"

if [[ ! -d "$dir" ]]; then
    echo "no golden snapshots"
    exit 0
fi

count=0
for file in "$dir"/*.snap; do
    [[ -e "$file" ]] || continue
    [[ -s "$file" ]] || { echo "empty snapshot: $file" >&2; exit 1; }
    count=$((count + 1))
done

echo "golden snapshots ok: $count"
