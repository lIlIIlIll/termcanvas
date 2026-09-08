#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-/tmp/cj_tui-macos-smoke-bundle}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$OUT_DIR"

MANIFEST="$OUT_DIR/manifest-$STAMP.txt"
MANIFEST0="$OUT_DIR/manifest-$STAMP.nul"
ARCHIVE="$OUT_DIR/cj_tui-macos-smoke-$STAMP.tar.gz"
SHA256="$ARCHIVE.sha256"

git -C "$ROOT" ls-files -z --cached --modified --others --exclude-standard |
    sort -z -u |
    while IFS= read -r -d '' path; do
        case "$path" in
            .envrc|.git/*|*.tmp|*/target/*|target/*|.cjpm/*|*/.cjpm/*)
                ;;
            *)
                if [[ -f "$ROOT/$path" ]]; then
                    printf '%s\0' "$path"
                fi
                ;;
        esac
    done > "$MANIFEST0"

tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
tar -C "$ROOT" --null -T "$MANIFEST0" -czf "$ARCHIVE"
sha256sum "$ARCHIVE" > "$SHA256"

echo "archive=$ARCHIVE"
echo "manifest=$MANIFEST"
echo "sha256=$SHA256"
echo "files=$(wc -l < "$MANIFEST")"
