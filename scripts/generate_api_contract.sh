#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Python extractor owns production/test source boundaries, architecture
# classification, and all generated views. Keep this shell entry point for
# existing release-gate and consumer workflows.
exec python3 "$ROOT/scripts/api_contract.py" "$@"
