#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: scripts/new_example.sh <name>" >&2
    exit 2
fi

NAME="$1"
if [[ ! "$NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "example name must match [a-z][a-z0-9_]*" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLES="$ROOT/examples"
DEST="$EXAMPLES/$NAME"

if [[ -e "$DEST" || -L "$DEST" ]]; then
    echo "example already exists: $NAME" >&2
    exit 1
fi

mkdir -- "$DEST"
trap 'rm -rf -- "$DEST"' EXIT
mkdir -- "$DEST/src"
sed "s/cjtui_basic_app/cjtui_${NAME}/g" "$ROOT/templates/basic_app/cjpm.toml" > "$DEST/cjpm.toml"
sed "s/cjtui_basic_app/cjtui_${NAME}/g" "$ROOT/templates/basic_app/src/main.cj" > "$DEST/src/main.cj"
trap - EXIT
printf 'created examples/%s\n' "$NAME"
