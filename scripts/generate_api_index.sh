#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# api-index is a generated view of the same classified inventory used by the
# stable and experimental contracts; it is not an independent source of truth.
exec python3 "$ROOT/scripts/api_contract.py" "$@"
