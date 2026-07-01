#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v cjc >/dev/null 2>&1; then
    echo "cjc not found; install a Cangjie SDK before running CI gate" >&2
    exit 127
fi

if [[ -z "${CJ_MARKDOWN_DIR:-}" ]]; then
    export CJ_MARKDOWN_DIR="$(cd "$ROOT/.." && pwd)/cj_markdown"
fi

"$ROOT/scripts/release_gate.sh"
