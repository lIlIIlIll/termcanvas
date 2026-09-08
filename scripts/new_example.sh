#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: scripts/new_example.sh <name>" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="$1"
DEST="$ROOT/examples/$NAME"

if [[ -e "$DEST" ]]; then
    echo "example already exists: $DEST" >&2
    exit 1
fi

mkdir -p "$DEST"
cp -R "$ROOT/templates/basic_app/." "$DEST/"
echo "created $DEST"
