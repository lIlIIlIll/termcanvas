#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v cjc >/dev/null 2>&1; then
    echo "cjc not found; install a Cangjie SDK before running CI gate" >&2
    exit 127
fi

"$ROOT/scripts/release_gate.sh"
