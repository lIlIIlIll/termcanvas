# Examples

This index sits beside the 17 example directories. Use
[`docs/examples.md`](../docs/examples.md) to choose an example by learning goal;
use this page when you are already working in `examples/`.

## Run and build

From this directory, run the selected package directly:

```bash
cd taskpad
cjpm run
```

If the Cangjie SDK is not already configured in your shell, use the repository
wrapper instead (still from `examples/`):

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  ../scripts/cangjie_cmd.sh taskpad cjpm run
```

Build every example from this directory:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie ../scripts/build_examples.sh
```

The runnable starter application is also available at
[`templates/basic_app`](../templates/basic_app/).

## Recommended applications (8)

- [`taskpad`](taskpad/): task board with input, `KeyMap`, command palette, and toasts.
- [`form_studio`](form_studio/): forms, focus routing, paste, and common controls.
- [`ops_dashboard`](ops_dashboard/): ticks, timers, progress, charts, logs, and status bars.
- [`data_browser`](data_browser/): virtual table, tree, file picker/dialog, and paginator.
- [`markdown_studio`](markdown_studio/): Markdown editing, completion, preview, and outline.
- [`command_center`](command_center/): async tasks, timers, dialogs, spinner, and toasts.
- [`assistant_console`](assistant_console/): transcript, composer, activity timeline, and dialogs.
- [`oh_my_pi_skin`](oh_my_pi_skin/): terminal-native canvas skin with timed regions.

## Experimental applications (2)

- [`btm_clone`](btm_clone/): primary-model system monitor with timers, async
  completions, focus/layout, dirty rendering, process interaction, and headless proof.
- [`media_gallery`](media_gallery/): direct media placement, `DocumentLine.image`,
  protocol fallback, and terminal capability reporting.

## Feature demonstrations (6)

- [`arcade`](arcade/): held-key/tick-driven `Canvas` app with resize fallback and metrics.
- [`crystal_caves`](crystal_caves/): side-scrolling game with tiles, sensors, physics, and animation.
- [`debug_lab`](debug_lab/): terminal capabilities, keyboard options, mouse/focus events, and metrics.
- [`game_demo`](game_demo/): farm-sim game with `Canvas`, stores, physics, tiles, sprites, saves, and headless smoke.
- [`gif_ascii`](gif_ascii/): ffmpeg-backed ASCII, half-block, or braille animation.
- [`terminal_lab`](terminal_lab/): PTY, terminal transcript, and diff integration.

## Proof workload (1)

- [`game_pressure_suite`](game_pressure_suite/): deterministic tick, input, and
  render pressure workload across six categories.

All entries are application-shaped: each can be run directly and demonstrates a
focused slice of the public API. Check the API tier in
[`docs/versioning.md`](../docs/versioning.md) before using an experimental
capability in a production application.
