#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARE="${SHARE:-/home/elliot/share}"
BACKEND="${BACKEND:-libvirt}"
RUNNER="${RUN_VBOX_CJ_TESTS:-run-vbox-cj-tests}"

CASES="$SHARE/cases"
CUSTOM_RUNNER="$CASES/run-tests.ps1"
STAGE=""
BACKUP=""
OWNED_RUNNER=""
HAD_CUSTOM_RUNNER=0
CUSTOM_RUNNER_INSTALLED=0

cleanup() {
    local rc=$?
    local cleanup_failed=0
    local preserve_backup=0
    trap - EXIT INT TERM
    if [[ "$CUSTOM_RUNNER_INSTALLED" -eq 1 ]]; then
        if [[ "$HAD_CUSTOM_RUNNER" -eq 1 && -f "$BACKUP" ]]; then
            if mv -f "$BACKUP" "$CUSTOM_RUNNER"; then
                BACKUP=""
            else
                echo "Windows smoke could not restore the prior runner; backup preserved at $BACKUP" >&2
                preserve_backup=1
                cleanup_failed=1
            fi
        else
            if ! rm -f "$CUSTOM_RUNNER"; then
                echo "Windows smoke could not remove its temporary runner: $CUSTOM_RUNNER" >&2
                cleanup_failed=1
            fi
        fi
    fi
    [[ -z "$OWNED_RUNNER" ]] || rm -f "$OWNED_RUNNER"
    if [[ -n "$BACKUP" && "$preserve_backup" -eq 0 ]]; then
        rm -f "$BACKUP"
    fi
    if [[ -n "$STAGE" ]] && ! rm -rf "$STAGE"; then
        echo "Windows smoke could not remove its staging directory: $STAGE" >&2
        cleanup_failed=1
    fi
    if [[ "$cleanup_failed" -ne 0 && "$rc" -eq 0 ]]; then
        rc=1
    fi
    exit "$rc"
}

generate_runner() {
    local marker='$RepoName = "cj_tui" # CJ_TUI_STAGE_NAME_PLACEHOLDER'
    local line
    local replacements=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$marker" ]]; then
            printf '$RepoName = "%s" # CJ_TUI_STAGE_NAME_PLACEHOLDER\n' "$STAGE_NAME" || return 1
            replacements=$((replacements + 1))
        else
            printf '%s\n' "$line" || return 1
        fi
    done
    [[ "$replacements" -eq 1 ]]
}

command -v "$RUNNER" >/dev/null 2>&1 || {
    echo "Windows runner not found: $RUNNER" >&2
    exit 127
}
command -v rsync >/dev/null 2>&1 || {
    echo "rsync not found" >&2
    exit 127
}
command -v flock >/dev/null 2>&1 || {
    echo "flock not found" >&2
    exit 127
}

[[ -d "$SHARE/sdk" ]] || {
    echo "Windows SDK share not found: $SHARE/sdk" >&2
    exit 2
}
[[ -f "$ROOT/scripts/windows_repo_smoke.ps1" ]] || {
    echo "Windows smoke runner template not found" >&2
    exit 2
}

mkdir -p "$CASES"
exec {LOCK_FD}>"$CASES/.cj_tui_windows_smoke.lock"
flock "$LOCK_FD"

STAGE=$(mktemp -d "$CASES/cj_tui.XXXXXXXX")
STAGE_NAME=${STAGE##*/}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
BACKUP=$(mktemp "$CASES/run-tests.ps1.cj_tui_backup.XXXXXXXX")

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

OWNED_RUNNER=$(mktemp "$CASES/run-tests.ps1.cj_tui_new.XXXXXXXX")
if ! generate_runner < "$ROOT/scripts/windows_repo_smoke.ps1" > "$OWNED_RUNNER"; then
    echo "Windows smoke runner template has no unique staging placeholder" >&2
    exit 2
fi
CUSTOM_RUNNER_INSTALLED=1
mv -f "$OWNED_RUNNER" "$CUSTOM_RUNNER"
OWNED_RUNNER=""

"$RUNNER" --backend "$BACKEND" --share "$SHARE" --all-logs "$@"
