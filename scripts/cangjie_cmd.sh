#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: scripts/cangjie_cmd.sh <workdir> <command> [args...]" >&2
    exit 2
fi

WORKDIR="$1"
shift

if [[ -f "$HOME/.codex/zshrc" ]]; then
    (cd "$WORKDIR" && DISABLE_ZOXIDE=1 zsh -lc 'source ~/.codex/zshrc; cangjie_env; "$@"' cangjie-cmd "$@")
else
    (cd "$WORKDIR" && DISABLE_ZOXIDE=1 "$@")
fi
