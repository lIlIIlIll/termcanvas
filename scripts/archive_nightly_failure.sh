#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_VERSION="${1:-${CJ_TUI_NIGHTLY_SDK_VERSION:-unknown-sdk}}"
COMMIT="${2:-$(git -C "$ROOT" rev-parse HEAD)}"
SHORT_SHA="$(git -C "$ROOT" rev-parse --short "$COMMIT")"
SAFE_VERSION="$(printf '%s' "$SDK_VERSION" | tr -c 'A-Za-z0-9._-' '-')"
BRANCH="archive/nightly-fail/${SAFE_VERSION}/${SHORT_SHA}"
PUSH_ARCHIVE="${CJ_TUI_PUSH_NIGHTLY_ARCHIVE:-}"

if [[ -z "$PUSH_ARCHIVE" ]]; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        PUSH_ARCHIVE=1
    else
        PUSH_ARCHIVE=0
    fi
fi

if git -C "$ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    echo "nightly failure archive already exists on origin: $BRANCH"
    exit 0
fi

if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "nightly failure archive already exists locally: $BRANCH"
else
    git -C "$ROOT" branch "$BRANCH" "$COMMIT"
    echo "created nightly failure archive branch: $BRANCH -> $COMMIT"
fi

if [[ "$PUSH_ARCHIVE" == "1" ]]; then
    git -C "$ROOT" push origin "refs/heads/$BRANCH:refs/heads/$BRANCH"
else
    echo "nightly failure archive push disabled; set CJ_TUI_PUSH_NIGHTLY_ARCHIVE=1 to push $BRANCH"
fi
