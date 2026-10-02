#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: scripts/cangjie_cmd.sh <workdir> <command> [args...]" >&2
  exit 2
fi

WORKDIR="$1"
shift

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${CANGJIE_SDK_ROOT:-}" ]]; then
  exec python3 "$ROOT/scripts/native_sdk.py" --run "$WORKDIR" -- "$@"
elif [[ -f "$HOME/.codex/.zshenv" ]]; then
  (cd "$WORKDIR" && DISABLE_ZOXIDE=1 zsh -lc 'source ~/.codex/.zshenv; cangjie_env; "$@"' cangjie-cmd "$@")
else
  (cd "$WORKDIR" && DISABLE_ZOXIDE=1 "$@")
fi
