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
  sdk_root=$("$ROOT/scripts/check_sdk.sh")
  stdx_root="$sdk_root/linux_x86_64_cjnative/dynamic/stdx"
  if [[ ! -d "$stdx_root" ]]; then
    stdx_root="$(dirname -- "$sdk_root")/linux_x86_64_cjnative/dynamic/stdx"
  fi
  runtime_root="$sdk_root/runtime/lib/linux_x86_64_cjnative"

  export CANGJIE_HOME="$sdk_root"
  export CANGJIE_ROOT="$sdk_root"
  export CANGJIE_PATH="$sdk_root"
  export CANGJIE_STDX_PATH="$(readlink -f -- "$stdx_root")"
  export PATH="$sdk_root/bin:$sdk_root/tools/bin:$PATH"
  export LD_LIBRARY_PATH="$runtime_root:$CANGJIE_STDX_PATH:$sdk_root/tools/lib"

  command=("$@")
  if [[ -n "${TERMCANVAS_CANONICAL_TARGET_ROOT:-}" && ${command[0]##*/} == cjpm && ${#command[@]} -ge 2 && ${command[1]} =~ ^(bench|build|run|test)$ ]]; then
    workdir_key=$(printf '%s' "$(readlink -f -- "$WORKDIR")" | sha256sum | cut -c1-16)
    target_dir="$TERMCANVAS_CANONICAL_TARGET_ROOT/$workdir_key"
    mkdir -p -- "$target_dir"
    command+=(--target-dir "$target_dir")
  fi
  (cd "$WORKDIR" && DISABLE_ZOXIDE=1 "${command[@]}")
elif [[ -f "$HOME/.codex/.zshenv" ]]; then
  (cd "$WORKDIR" && DISABLE_ZOXIDE=1 zsh -lc 'source ~/.codex/.zshenv; cangjie_env; "$@"' cangjie-cmd "$@")
else
  (cd "$WORKDIR" && DISABLE_ZOXIDE=1 "$@")
fi
