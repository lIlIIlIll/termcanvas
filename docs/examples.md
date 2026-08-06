# Examples

Run an example from its directory:

```bash
/home/elliot/.codex/scripts/codex_cangjie_env cjpm run
```

Build all examples:

```bash
scripts/build_examples.sh
```

The examples are application-shaped rather than one-widget snippets. Each app demonstrates a coherent public-API slice:

- `taskpad`: task-board app with `Input`, `ListState`, `KeyMap`, `CommandPalette`, `ToastManager`, and command-driven updates.
- `form_studio`: profile form app with focus routing, paste handling, `Input`, `TextArea`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, and `Button`.
- `crystal_caves`: multi-level side-scrolling platform game using `game` tile markers, sensor pickups, hazards, patrol enemies, sprite animation, and camera scrolling.
- `game_pressure_suite`: compact six-category game pressure suite covering roguelike, snake, 2048, minesweeper, turn-based strategy, and lightweight real-time action loops with tick/input/render pressure.
- `gif_ascii`: ffmpeg-decodable media-to-ASCII animation viewer using `FfmpegAsciiAnimationDecoder`, `AsciiAnimationView`, ASCII/half-block/braille render modes, optional RGB color, binary threshold control, tick-driven playback, pause, zoom, and speed controls.
- `ops_dashboard`: real-time operations dashboard using `targetFps`, `TimerSpec`, `TickEvent`, `ProgressBar`, `Sparkline`, `Gauge`, `Chart`, `LogView`, and `StatusBar`.
- `data_browser`: data/file browser using `VirtualTable`, `Tree`, `FilePicker`, `FileDialog`, and `Paginator`.
- `markdown_studio`: Markdown authoring app using `TextArea`, completion events, `MarkdownEditorBehavior`, `DocumentView`, `markdown`, preview, and outline.
- `terminal_lab`: terminal lab using PTY commands/events, `LinuxPtyRuntime`, `terminal`, `TerminalView`, and `diff`.
- `media_gallery`: media-capability app using `TerminalCapabilities`, media protocol fallback, frame media placements, DOM media nodes, document image rows, and `media`.
- `style_lab`: DOM/CSS/layout/canvas app using `ViewNode`, `StyleSheet`, flex layout, `Canvas`, and `SizeGuard`.
- `oh_my_pi_skin`: oh-my-pi inspired terminal skin using `Canvas`, an interactive animated todo tree, true-color styles, `TerminalCapabilities`, `Composer`, `CommandPalette`, and independent region timers.
- `command_center`: command runtime app using async tasks, timers, menus, dialogs, spinner, and toasts.
- `assistant_console`: transcript console using `TranscriptView`, `Composer`, `ActivityTimeline`, `RequestDialog`, `DecisionDialog`, and rich `Document` content.
- `btm_clone`: bottom/btm-style monitor using component-scoped datasource sampling, dirty-rendered resource panels, process-table selection, sort hotkeys, and a `--headless-smoke` regression path for profiler/dirty isolation.
- `arcade`: playable canvas app using `InputState`, held-key handling, `TickEvent`, `Canvas`, `SizeGuard`, resize fallback, and `AppMetrics`.
- `debug_lab`: terminal diagnostics app using `TerminalCapabilities`, `KeyboardOptions`, mouse move, focus events, `AppMetrics`, `RenderMetrics`, and `DebugOverlay`.

Create a new example scaffold:

```bash
scripts/new_example.sh my_example
```

Open a Markdown file directly:

```bash
cd examples/markdown_studio
/home/elliot/.codex/scripts/codex_cangjie_env cjpm run -- README.md
```

Play any ffmpeg-decodable image, GIF, or video as ASCII animation:

```bash
cd examples/gif_ascii
/home/elliot/.codex/scripts/codex_cangjie_env cjpm run --run-args="/path/to/media-file --width 80 --height 32 --fps 12"
```

Use braille mode for higher effective sample density per terminal cell:

```bash
/home/elliot/.codex/scripts/codex_cangjie_env cjpm run --run-args="/path/to/video.mp4 --width 120 --height 50 --fps 15 --mode braille --color --threshold 110"
```

Runtime controls include `space` pause, `+/-` zoom, `[]` speed, and `,/.` or `<>` threshold adjustment.
