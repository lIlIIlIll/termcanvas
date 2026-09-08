#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLES="$ROOT/examples"

expected=(
  arcade
  assistant_console
  btm_clone
  command_center
  crystal_caves
  data_browser
  debug_lab
  form_studio
  game_pressure_suite
  game_demo
  gif_ascii
  markdown_studio
  media_gallery
  oh_my_pi_skin
  ops_dashboard
  taskpad
  terminal_lab
)

for name in "${expected[@]}"; do
  [[ -f "$EXAMPLES/$name/cjpm.toml" ]] || { echo "missing example: $name" >&2; exit 1; }
  [[ -f "$EXAMPLES/$name/src/main.cj" ]] || { echo "missing main: $name" >&2; exit 1; }
done

actual_count="$(find "$EXAMPLES" -maxdepth 2 -name cjpm.toml | wc -l | tr -d ' ')"
if [[ "$actual_count" != "${#expected[@]}" ]]; then
  echo "unexpected example count: $actual_count, expected ${#expected[@]}" >&2
  find "$EXAMPLES" -maxdepth 2 -name cjpm.toml -print | sort >&2
  exit 1
fi

check_source() {
  local file="$1"
  shift
  for token in "$@"; do
    if ! grep -q -- "$token" "$file"; then
      echo "example smoke check failed: $file missing $token" >&2
      exit 1
    fi
  done
}

check_source "$EXAMPLES/taskpad/src/main.cj" "KeyMap" "CommandPalette" "ToastManager"
check_source "$EXAMPLES/form_studio/src/main.cj" "FocusManager" "MultiSelect" "DatePicker"
check_source "$EXAMPLES/game_demo/src/main.cj" "FarmGame" "Canvas" "RenderMode.Diff" "--headless-smoke" "File.writeTo" "sleepNight" "shipInventory"
check_source "$EXAMPLES/game_pressure_suite/src/main.cj" "roguelike" "snake" "2048" "minesweeper" "turn-based strategy" "lightweight real-time action" "RenderMode.Diff" "Event.Tick" "SizeGuard" "Canvas"
check_source "$EXAMPLES/gif_ascii/src/main.cj" "MediaAsciiApp" "FfmpegAsciiAnimationDecoder" "AsciiAnimationView" "AsciiRenderMode" "--mode" "--color" "--threshold" "Event.Tick" "paused" "zoom"
check_source "$EXAMPLES/ops_dashboard/src/main.cj" "TimerSpec" "Event.Tick" "StatusBarProgress"
check_source "$EXAMPLES/data_browser/src/main.cj" "VirtualTable" "FileDialog" "Paginator"
check_source "$EXAMPLES/markdown_studio/src/main.cj" "MarkdownEditorBehavior" "DocumentView" "TextCompletion"
check_source "$EXAMPLES/terminal_lab/src/main.cj" "LinuxPtyRuntime" "TerminalView" "DiffView"
check_source "$EXAMPLES/media_gallery/src/main.cj" "TerminalCapabilities" "mediaPlacementWithAdapter" "DocumentLine.image" "--headless-smoke"
if grep -q -- "retained_view_experimental\|ViewNode\|StyleSheet\|StyleDeclaration" "$EXAMPLES/media_gallery/cjpm.toml" "$EXAMPLES/media_gallery/src/main.cj"; then
  echo "example smoke check failed: media_gallery still contains retained-view dependencies" >&2
  exit 1
fi
check_source "$EXAMPLES/oh_my_pi_skin/src/main.cj" "TerminalCapabilities" "CommandPalette" "Composer" "TimerSpec" "Event.Timer" "DirtyRects" "Color.Rgb" "Canvas"
check_source "$EXAMPLES/command_center/src/main.cj" "AsyncTask" "StartTimer" "Dialog"
check_source "$EXAMPLES/assistant_console/src/main.cj" "TranscriptView" "Composer" "RequestDialog"
check_source "$EXAMPLES/btm_clone/src/main.cj" "Canvas" "drawGraph" "Event.Tick" "sortMode" "Command.AsyncTask" "Event.AsyncCompleted" "DebugOverlay"
if grep -q -- "component_experimental" "$EXAMPLES/btm_clone/cjpm.toml" "$EXAMPLES/btm_clone/src/main.cj"; then
  echo "example smoke check failed: btm_clone still depends on component_experimental" >&2
  exit 1
fi
check_source "$EXAMPLES/arcade/src/main.cj" "InputState" "SizeGuard" "Event.Tick"
check_source "$EXAMPLES/crystal_caves/src/main.cj" "TileMap" "SpriteAnimation" "physics.overlaps"
check_source "$EXAMPLES/debug_lab/src/main.cj" "KeyboardOptions" "DebugOverlay" "TerminalCapabilities"

btm_smoke_output="$("$ROOT/scripts/cangjie_cmd.sh" "$EXAMPLES/btm_clone" cjpm run -- --headless-smoke 2>&1)"
if ! grep -q "btm_clone headless smoke ok" <<<"$btm_smoke_output"; then
  echo "$btm_smoke_output" >&2
  exit 1
fi

media_smoke_output="$("$ROOT/scripts/cangjie_cmd.sh" "$EXAMPLES/media_gallery" cjpm run -- --headless-smoke 2>&1)"
if ! grep -q "media_gallery headless smoke ok" <<<"$media_smoke_output"; then
  echo "$media_smoke_output" >&2
  exit 1
fi

game_demo_smoke_output="$(GCOV_PREFIX=/tmp/termcanvas_gcov "$ROOT/scripts/cangjie_cmd.sh" "$EXAMPLES/game_demo" cjpm run -- --headless-smoke --save-path /tmp/termcanvas_game_demo_smoke.save --reset-save 2>&1)"
if ! grep -q "game_demo headless smoke ok" <<<"$game_demo_smoke_output"; then
  echo "$game_demo_smoke_output" >&2
  exit 1
fi

echo "example smoke checks ok: ${#expected[@]} examples"
