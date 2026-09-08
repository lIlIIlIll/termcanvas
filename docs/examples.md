# Examples

Use this page to choose an example by the part of `termcanvas` you want to learn. All
17 current examples are grouped by support and purpose; the links open their
source directories. For the directory-local index and commands, see
[`examples/README.md`](../examples/README.md).

## Before running an example

Run commands from the repository root. Set `CANGJIE_SDK_ROOT` to the canonical
Cangjie SDK used by the repository wrapper:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

Replace `taskpad` with any linked example directory. To build the complete
example set instead of launching one application:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie scripts/build_examples.sh
```

## Recommended applications (8)

These are the best starting points for application-shaped code on the primary
application-owned state → `App`/`update` → immediate `Widget` path.

- [`taskpad`](../examples/taskpad/): task-board workflow with input, `KeyMap`,
  command palette, and toasts.
- [`form_studio`](../examples/form_studio/): form workflow with focus policy,
  paste, controls, and status feedback.
- [`ops_dashboard`](../examples/ops_dashboard/): real-time dashboard with ticks,
  timers, progress, charts, logs, and status bars.
- [`data_browser`](../examples/data_browser/): data and file browser with virtual
  table, tree, file picker/dialog, and paginator.
- [`markdown_studio`](../examples/markdown_studio/): Markdown editing with
  completion, preview, and outline.
- [`command_center`](../examples/command_center/): command runtime with async
  tasks, timers, dialogs, spinner, and toasts.
- [`assistant_console`](../examples/assistant_console/): transcript, composer,
  activity timeline, and request/decision dialogs.
- [`oh_my_pi_skin`](../examples/oh_my_pi_skin/): terminal-native skin with canvas,
  transcript, composer, palette, status line, and timed regions.

## Experimental applications (2)

These applications exercise capabilities whose compatibility tier is
`EXPERIMENTAL`; they are not alternate application architectures.

- [`btm_clone`](../examples/btm_clone/): nontrivial primary-model application
  with application-owned state, core timers, async completions, focus/layout,
  regional dirty rendering, process interaction, and deterministic headless
  proof.
- [`media_gallery`](../examples/media_gallery/): direct terminal media placement,
  `DocumentLine.image` integration, protocol fallback, and capability reporting.

## Feature demonstrations (6)

Use these when a specific input, rendering, game, or terminal extension is the
next concept you need.

- [`arcade`](../examples/arcade/): held-key and tick-driven `Canvas` application
  with resize fallback and metrics.
- [`crystal_caves`](../examples/crystal_caves/): side-scrolling game with tile
  markers, sensors, physics, animation, and camera scrolling.
- [`debug_lab`](../examples/debug_lab/): terminal capabilities, keyboard
  options, mouse/focus events, metrics, and debug overlay.
- [`game_demo`](../examples/game_demo/): farm-sim game with `Canvas`, stores,
  physics, tiles, sprites, saves, and headless smoke.
- [`gif_ascii`](../examples/gif_ascii/): ffmpeg-backed ASCII, half-block, or
  braille animation with playback and display controls.
- [`terminal_lab`](../examples/terminal_lab/): PTY, terminal transcript, and diff
  integration lab.

## Proof workload (1)

- [`game_pressure_suite`](../examples/game_pressure_suite/): six-category
  deterministic tick, input, and render pressure workload.

## Focused commands

Create a new example scaffold from the repository root:

```bash
scripts/new_example.sh my_example
```

Open a Markdown file directly with `markdown_studio`:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run -- README.md
```

Play an ffmpeg-decodable image, GIF, or video with `gif_ascii`:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/media-file --width 80 --height 32 --fps 12"
```

Braille mode provides higher effective sample density per terminal cell:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/video.mp4 --width 120 --height 50 --fps 15 --mode braille --color --threshold 110"
```

`gif_ascii` runtime controls include `space` to pause, `+/-` to zoom, `[]` to
change speed, and `,/.` or `<>` to adjust threshold.
