# Examples

Run an example from its directory:

```bash
cjpm run
```

Build every example:

```bash
../scripts/build_examples.sh
```

The machine-owned inventory classifies the 17 current examples as follows.

## Recommended applications

- `taskpad`: task-board app with `Input`, `ListState`, `KeyMap`, `CommandPalette`, `ToastManager`, and command-driven updates.
- `form_studio`: profile form app with focus routing, paste handling, `Input`, `TextArea`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, and `Button`.
- `ops_dashboard`: real-time operations dashboard using `targetFps`, `TimerSpec`, `TickEvent`, `ProgressBar`, `Sparkline`, `Gauge`, `Chart`, `LogView`, and `StatusBar`.
- `data_browser`: data/file browser using `VirtualTable`, `Tree`, `FilePicker`, `FileDialog`, and `Paginator`.
- `markdown_studio`: Markdown authoring app using `TextArea`, multi-caret editing, completion events, `MarkdownEditorBehavior`, `DocumentView`, `markdown`, preview, and outline.
- `oh_my_pi_skin`: terminal-native oh-my-pi visual skin using `Canvas`, an interactive animated todo tree, true-color styles, `TerminalCapabilities`, `Composer`, `CommandPalette`, and independent region timers.
- `command_center`: command runtime app using `Command.Batch`-style command routing, async tasks, timers, menus, dialogs, spinner, and toasts.
- `assistant_console`: transcript console using `TranscriptView`, `Composer`, `ActivityTimeline`, `RequestDialog`, `DecisionDialog`, and rich `Document` content.

## Experimental applications

- `btm_clone`: primary App/update system monitor with application-owned state,
  core timers and async completions, regional dirty rendering, process interaction,
  and deterministic headless isolation proof.
- `media_gallery`: terminal capability/fallback demo with direct media placements
  and `DocumentLine.image`.

## Feature demonstrations

- `arcade`: playable Canvas app with held-key input, ticks, and resize fallback.
- `crystal_caves`: platform game with tile markers, sensors, physics, animation, and camera scrolling.
- `debug_lab`: terminal capabilities, keyboard options, mouse/focus events, metrics, and debug overlay.
- `game_demo`: farm-sim game with Canvas, stores, physics, tiles, sprites, saves, and headless smoke.
- `gif_ascii`: ffmpeg-decodable ASCII/half-block/braille animation with playback and display controls.
- `terminal_lab`: PTY, terminal transcript, and diff integration lab.

## Proof workload

- `game_pressure_suite`: six-category deterministic tick/input/render pressure workload.

The example suite is intentionally application-shaped: each example should be useful to run directly while still demonstrating a clear slice of the public API.
