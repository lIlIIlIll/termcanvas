#!/usr/bin/env bash
set -euo pipefail

expected_version=${CANGJIE_SDK_VERSION:-1.1.3}
expected_cjpm_version=${CANGJIE_CJPM_VERSION:-1.1.3}
sdk_root=${CANGJIE_SDK_ROOT:-}

if [[ -z "$sdk_root" ]]; then
  printf '%s\n' \
    'termcanvas: set CANGJIE_SDK_ROOT to the canonical Cangjie SDK' >&2
  exit 2
fi

sdk_root=$(readlink -f -- "$sdk_root")
if [[ -d "$sdk_root/cangjie" && ! -x "$sdk_root/bin/cjc" ]]; then
  sdk_root=$(readlink -f -- "$sdk_root/cangjie")
fi

cjc="$sdk_root/bin/cjc"
cjpm="$sdk_root/tools/bin/cjpm"
runtime="$sdk_root/runtime/lib/linux_x86_64_cjnative/libcangjie-runtime.so"
stdx=${CANGJIE_STDX_PATH:-"$sdk_root/linux_x86_64_cjnative/dynamic/stdx"}
if [[ ! -d "$stdx" ]]; then
  stdx="$(dirname -- "$sdk_root")/linux_x86_64_cjnative/dynamic/stdx"
fi

if [[ ! -x "$cjc" || ! -x "$cjpm" || ! -f "$runtime" ]]; then
  printf 'termcanvas: incomplete Cangjie SDK at %s\n' "$sdk_root" >&2
  exit 2
fi

sdk_ld="$(dirname -- "$runtime"):$sdk_root/tools/lib"
if [[ -d "$stdx" ]]; then
  sdk_ld="$stdx:$sdk_ld"
fi
cjc_version=$(env LD_LIBRARY_PATH="$sdk_ld" \
  "$cjc" -v 2>&1 || true)
cjpm_version=$(env \
  PATH="$sdk_root/bin:$sdk_root/tools/bin:$PATH" \
  LD_LIBRARY_PATH="$sdk_ld" \
  "$cjpm" --version 2>&1 || true)

if [[ "$cjc_version" != *"$expected_version"* ]]; then
  printf 'termcanvas: unsupported cjc; expected %s, got: %s\n' \
    "$expected_version" "${cjc_version//$'\n'/; }" >&2
  exit 2
fi
if [[ "$cjpm_version" != *"$expected_cjpm_version"* ]]; then
  printf 'termcanvas: unsupported cjpm; expected %s, got: %s\n' \
    "$expected_cjpm_version" "${cjpm_version//$'\n'/; }" >&2
  exit 2
fi

if [[ ${1:-} == --report ]]; then
  printf 'CANGJIE_SDK_ROOT=%s\n' "$sdk_root"
  printf 'CJC_VERSION=%s\n' "${cjc_version//$'\n'/; }"
  printf 'CJC_SHA256=%s\n' "$(sha256sum "$cjc" | cut -d' ' -f1)"
  printf 'CJPM_VERSION=%s\n' "${cjpm_version//$'\n'/; }"
  printf 'RUNTIME=%s\n' "$runtime"
  printf 'RUNTIME_SHA256=%s\n' "$(sha256sum "$runtime" | cut -d' ' -f1)"
  if [[ -d "$stdx" ]]; then
    printf 'STDX=%s\n' "$(readlink -f -- "$stdx")"
  else
    printf 'STDX=embedded\n'
  fi
else
  printf '%s\n' "$sdk_root"
fi
