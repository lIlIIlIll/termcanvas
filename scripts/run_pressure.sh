#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> pressure-oriented unittest scenarios"
"$ROOT/scripts/cangjie_cmd.sh" "$ROOT/packages/core" cjpm test --no-color

echo "==> build application examples under pressure gate"
"$ROOT/scripts/build_examples.sh"

echo "pressure gate ok"
