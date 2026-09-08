# Examples

Run an example from the repository root. `CANGJIE_SDK_ROOT` must point at the
canonical Cangjie SDK described in [Versioning And Compatibility](versioning.md):

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

Build all examples:

```bash
scripts/build_examples.sh
```

The machine-owned taxonomy classifies 17 current examples. “Experimental” below
describes support tier, not a competing application architecture.

## Recommended applications (8)

- `taskpad`: task-board app with input, `KeyMap`, command palette, and toasts.
- `form_studio`: form workflow with application-owned focus policy, paste, common controls, and status feedback.
- `ops_dashboard`: real-time dashboard with ticks, timers, progress, charts, logs, and status bars.
- `data_browser`: data/file browser with virtual table, tree, file picker/dialog, and paginator.
- `markdown_studio`: Markdown authoring with text editing, completion, preview, and outline.
- `command_center`: command runtime with async tasks, timers, dialogs, spinner, and toasts.
- `assistant_console`: transcript, composer, activity timeline, and request/decision dialogs.
- `oh_my_pi_skin`: terminal-native skin with canvas, independently timed content, transcript, composer, palette, and status line.

## Experimental applications (2)

- `btm_clone`: nontrivial primary-model application with application-owned state,
  exact core timer IDs, async completions, application-owned focus/layout,
  regional `DirtyRects`, process interaction, and deterministic headless proof.
- `media_gallery`: direct terminal media placement, `DocumentLine.image`
  integration, protocol fallback, and terminal capability reporting.

## Feature demonstrations (6)

- `arcade`: held-key/tick-driven Canvas application with resize fallback and metrics.
- `crystal_caves`: side-scrolling game using tile markers, sensors, physics, animation, and camera scrolling.
- `debug_lab`: terminal capabilities, keyboard options, mouse/focus events, metrics, and debug overlay.
- `game_demo`: farm-sim game using Canvas, game stores, physics, tiles, sprites, saves, and headless smoke.
- `gif_ascii`: ffmpeg-backed ASCII/half-block/braille animation with playback and display controls.
- `terminal_lab`: PTY, terminal transcript, and diff integration lab.

## Proof workload (1)

- `game_pressure_suite`: six-category deterministic tick/input/render pressure workload.

Create a new example scaffold:

```bash
scripts/new_example.sh my_example
```

Open a Markdown file directly:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run -- README.md
```

Play any ffmpeg-decodable image, GIF, or video as ASCII animation:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/media-file --width 80 --height 32 --fps 12"
```

Use braille mode for higher effective sample density per terminal cell:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/video.mp4 --width 120 --height 50 --fps 15 --mode braille --color --threshold 110"
```

Runtime controls include `space` pause, `+/-` zoom, `[]` speed, and `,/.` or `<>` threshold adjustment.
