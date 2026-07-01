# Examples

Run an example from its directory:

```bash
cjpm run
```

Build every example:

```bash
../scripts/build_examples.sh
```

Examples:

- `taskpad`: task-board app with `Input`, `ListState`, `KeyMap`, `CommandPalette`, `ToastManager`, and command-driven updates.
- `form_studio`: profile form app with focus routing, paste handling, `Input`, `TextArea`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, and `Button`.
- `game_demo`: game extension app using `game`, generic component stores, continuous collision physics, tile maps, sprite rendering, ticks, and debug metrics.
- `gif_ascii`: ffmpeg-decodable media-to-ASCII animation viewer using ASCII/half-block/braille render modes, optional RGB color, binary threshold control, tick-driven playback, pause, zoom, and speed controls.
- `crystal_caves`: playable multi-level side-scrolling platform game using `game` tile markers, sensor overlaps, sprite animation, physics, patrol enemies, and camera scrolling.
- `ops_dashboard`: real-time operations dashboard using `targetFps`, `TimerSpec`, `TickEvent`, `ProgressBar`, `Sparkline`, `Gauge`, `Chart`, `LogView`, and `StatusBar`.
- `btm_clone`: bottom/btm-style system monitor replica using full-screen `Canvas`, animated metric graphs, resource panels, process-table selection, and sort hotkeys.
- `data_browser`: data/file browser using `VirtualTable`, `Tree`, `FilePicker`, `FileDialog`, and `Paginator`.
- `markdown_studio`: Markdown authoring app using `TextArea`, multi-caret editing, completion events, `MarkdownEditorBehavior`, `DocumentView`, `markdown`, preview, and outline.
- `terminal_lab`: terminal lab using PTY commands/events, `LinuxPtyRuntime`, `terminal`, `TerminalView`, and `diff`.
- `media_gallery`: media-capability app using `TerminalCapabilities`, media protocol fallback, frame media placements, DOM media nodes, document image rows, and `media`.
- `style_lab`: DOM/CSS/layout/canvas app using `ViewNode`, `StyleSheet`, flex layout, `Canvas`, and `SizeGuard`.
- `oh_my_pi_skin`: terminal-native oh-my-pi visual skin using `Canvas`, true-color styles, `TerminalCapabilities`, `Composer`, `CommandPalette`, and tick animation.
- `command_center`: command runtime app using `Command.Batch`-style command routing, async tasks, timers, menus, dialogs, spinner, and toasts.
- `assistant_console`: transcript console using `TranscriptView`, `Composer`, `ActivityTimeline`, `RequestDialog`, `DecisionDialog`, and rich `Document` content.
- `arcade`: playable canvas app using `InputState`, held-key handling, `TickEvent`, `Canvas`, `SizeGuard`, resize fallback, and `AppMetrics`.
- `debug_lab`: terminal diagnostics app using `TerminalCapabilities`, `KeyboardOptions`, mouse move, focus events, `AppMetrics`, `RenderMetrics`, and `DebugOverlay`.

The example suite is intentionally application-shaped: each example should be useful to run directly while still demonstrating a clear slice of the public API.
