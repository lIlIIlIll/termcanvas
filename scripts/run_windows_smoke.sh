#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARE="${SHARE:-/home/elliot/share}"
BACKEND="${BACKEND:-libvirt}"
RUNNER="${RUN_VBOX_CJ_TESTS:-run-vbox-cj-tests}"

CASES="$SHARE/cases"
STAGE="$CASES/cj_tui"
CUSTOM_RUNNER="$CASES/run-tests.ps1"
BACKUP="$CASES/run-tests.ps1.cj_tui_backup.$$"
HAD_CUSTOM_RUNNER=0

cleanup() {
    local rc=$?
    if [[ "$HAD_CUSTOM_RUNNER" -eq 1 && -f "$BACKUP" ]]; then
        cp -f "$BACKUP" "$CUSTOM_RUNNER"
    else
        rm -f "$CUSTOM_RUNNER"
    fi
    rm -f "$BACKUP"
    rm -rf "$STAGE"
    exit "$rc"
}

trap cleanup EXIT INT TERM

command -v "$RUNNER" >/dev/null 2>&1 || {
    echo "Windows runner not found: $RUNNER" >&2
    exit 127
}

[[ -d "$SHARE/sdk" ]] || {
    echo "Windows SDK share not found: $SHARE/sdk" >&2
    exit 2
}

mkdir -p "$CASES" "$STAGE"

if [[ -f "$CUSTOM_RUNNER" ]]; then
    cp -f "$CUSTOM_RUNNER" "$BACKUP"
    HAD_CUSTOM_RUNNER=1
fi

rsync -a --delete \
    --exclude .git \
    --exclude target \
    --exclude .cjpm \
    --exclude '/packages/*/target' \
    --exclude '/examples/*/target' \
    "$ROOT/" "$STAGE/"

cp -f "$ROOT/scripts/windows_repo_smoke.ps1" "$CUSTOM_RUNNER"

"$RUNNER" --backend "$BACKEND" --share "$SHARE" --all-logs "$@"
