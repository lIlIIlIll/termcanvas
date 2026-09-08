#!/usr/bin/env bash
set -euo pipefail

HOST="${MACOS_HOST:-cjlibs@10.0.0.10}"
REPO="${MACOS_REPO:-}"
SSH_CONFIG="${MACOS_SSH_CONFIG:-/dev/null}"
MACOS_CANGJIE_ROOT="${MACOS_CANGJIE_ROOT:-}"
MACOS_SDKROOT="${MACOS_SDKROOT:-}"

if [[ -z "$REPO" ]]; then
    cat >&2 <<'EOF'
usage: MACOS_REPO=/path/to/cj_tui [MACOS_CANGJIE_ROOT=/path/to/cangjie] [MACOS_SDKROOT=/path/to/MacOSX.sdk] [MACOS_HOST=user@host] scripts/run_macos_smoke.sh

Runs packages/example_smoke and builds examples/game_pressure_suite from a
checkout that already exists on the
macOS host. This script does not transfer repository contents.
EOF
    exit 2
fi

ssh -o BatchMode=yes -F "$SSH_CONFIG" "$HOST" 'bash -s' -- "$REPO" "$MACOS_CANGJIE_ROOT" "$MACOS_SDKROOT" <<'EOF'
set -euo pipefail

repo="$1"
cangjie_root="$2"
sdkroot="$3"
expected_cjc_version='1.1.0-alpha.20260817040003'
expected_cjpm_version='1.1.3'
if [[ ! -d "$repo" ]]; then
    echo "macOS checkout not found: $repo" >&2
    exit 2
fi
cd "$repo"

if [[ -n "$cangjie_root" ]]; then
    requested_cangjie_root="$cangjie_root"
    cangjie_root="$(cd "$cangjie_root" 2>/dev/null && pwd -P)" || {
        echo "macOS Cangjie SDK not found: $requested_cangjie_root" >&2
        exit 2
    }
    if [[
        ! -x "$cangjie_root/tools/bin/cjpm"
        || ! -x "$cangjie_root/bin/cjc"
        || ! -d "$cangjie_root/lib/darwin_aarch64_cjnative"
        || ! -d "$cangjie_root/runtime/lib/darwin_aarch64_cjnative"
    ]]; then
        echo "macOS Cangjie SDK not usable: $cangjie_root" >&2
        exit 2
    fi
    export CANGJIE_HOME="$cangjie_root"
    export CANGJIE_SDK_ROOT="$cangjie_root"
    export PATH="$cangjie_root/tools/bin:$cangjie_root/bin:$PATH"
    export DYLD_LIBRARY_PATH="$cangjie_root/lib/darwin_aarch64_cjnative:$cangjie_root/runtime/lib/darwin_aarch64_cjnative:$cangjie_root/tools/lib:${DYLD_LIBRARY_PATH:-}"
fi
cjc="$(command -v cjc || true)"
cjpm="$(command -v cjpm || true)"
if [[ -z "$cjc" || -z "$cjpm" ]]; then
    echo "macOS Cangjie commands not found; set MACOS_CANGJIE_ROOT or remote PATH" >&2
    exit 2
fi
cjc_version=$("$cjc" -v 2>&1 || true)
cjpm_version=$("$cjpm" --version 2>&1 || true)
if [[ "$cjc_version" != *"$expected_cjc_version"* ]]; then
    echo "macOS cjc version mismatch: expected $expected_cjc_version, got ${cjc_version//$'\n'/; }" >&2
    exit 2
fi
if [[ "$cjpm_version" != *"$expected_cjpm_version"* ]]; then
    echo "macOS cjpm version mismatch: expected $expected_cjpm_version, got ${cjpm_version//$'\n'/; }" >&2
    exit 2
fi
if [[ -z "$sdkroot" ]] && command -v xcrun >/dev/null 2>&1; then
    sdkroot="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
fi
if [[ -n "$sdkroot" ]]; then
    if [[ ! -d "$sdkroot" ]]; then
        echo "macOS SDKROOT not found: $sdkroot" >&2
        exit 2
    fi
    export SDKROOT="$sdkroot"
fi

for package in packages/example_smoke examples/game_pressure_suite; do
    if [[ ! -d "$package" ]]; then
        echo "macOS package not found: $repo/$package" >&2
        exit 2
    fi
done
(cd packages/example_smoke && DISABLE_ZOXIDE=1 "$cjpm" run)
(cd examples/game_pressure_suite && DISABLE_ZOXIDE=1 "$cjpm" build)
EOF
