#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: scripts/run_event_script.sh <script-file> [more-script-files...]" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

events=0
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "event script not found: $file" >&2
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        case "$line" in
            scenario:*|key:*|message:*|paste:*|resize:*|tick|ctrl-c|expect:flow:*|expect:snapshot:*|expect:cell:*) events=$((events + 1)) ;;
            *) echo "invalid event script line: $line" >&2; exit 1 ;;
        esac
    done < "$file"
done

echo "event scripts ok: $# files, $events lines"
