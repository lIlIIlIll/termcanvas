# cjtui

`cjtui` is a Linux/glibc-first terminal UI library for Cangjie. An application owns
its canonical state, applies `Event`s in an `App` update loop, returns effects as
`Command`s, and renders the resulting state with immediate `Widget`s. The
rendering path ends at a `Backend` through `Frame` and `Buffer`.

## Start here

1. Follow [Getting Started](docs/getting-started.md) for the first runnable
   application and its verification commands.
2. Use the [example catalog](docs/examples.md) to choose a complete application
   or a focused feature demonstration.
3. Read the [API overview](docs/api.md) and
   [Versioning and Compatibility](docs/versioning.md) before depending on a
   less familiar declaration.

## Core model

Keep the application's data and policy in application-owned state. `App` calls
`update` for input, timers, and command results; `update` changes that state and
returns an `UpdateResult`. Immediate widgets render a snapshot of the current
state. Background work returns immutable completion events to the same update
path instead of mutating widgets or application state directly.

```text
application-owned state
        ↓
App / update / Event / Command
        ↓
ordered, run-to-completion runtime
        ↓
dirty-region coalescing
        ↓
immediate Widget rendering
        ↓
Frame / Buffer / Backend
```

`Backend`, `Terminal`, and `TerminalSession` handle terminal I/O and restoration.
`Frame` and `Buffer` provide presentation storage; `Layout`, styles, themes,
text, and widgets operate on the current frame. `core` owns the stable editor
primitives and rich document model. The former advanced editor shell and the
`packages/editor` and `packages/document` alias facades are retired; use the
same-named canonical `core` types instead. `packages/markdown` converts Markdown
into the core document model, while PTY, media, transcript, diff, and game
facilities extend this model without introducing a second application lifecycle.

## Minimal use

This is the smallest stable rendering path. It renders one immediate widget and
leaves event handling on the normal `App` update path:

```cangjie
import core.*

main(): Int64 {
    runAppWithCommands(
        { frame =>
            frame.renderWidget(
                Paragraph("Hello, cjtui", block: Block(title: "Demo")),
                frame.area
            )
        },
        { _ => UpdateResult.next() }
    )
    0
}
```

For a stateful application, use `App(targetFps: 10).runWithCommands(...)` as in
the runnable [basic application template](templates/basic_app/). The template
keeps application-owned state in an object, handles `Event`s in `update`, and
renders immediate widgets from that state.

## Examples

Run commands from the repository root. Set `CANGJIE_SDK_ROOT` to the canonical
Cangjie SDK before using the repository wrapper:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

`taskpad` is the recommended first example. The [example catalog](docs/examples.md)
links all 17 current examples by purpose: eight recommended applications, two
experimental applications, six feature demonstrations, and one deterministic
pressure/proof workload. The [examples directory index](examples/README.md)
provides the same taxonomy next to the source directories.

## Release gate

Run the repository's release gate from the root before sharing a build:

```bash
scripts/release_gate.sh
```

The gate checks package tests, event scripts, golden snapshots, generated API
contracts and Unicode data, example builds and smoke checks, scripted workflows,
and pressure scenarios. `packages/markdown` uses the in-repository
`packages/cj_markdown` parser package, so the gate does not require a sibling
parser checkout.

## Limits and support boundaries

- Current packages use `0.1.x` and the API has four support tiers. The generated
  inventory is exhaustive; use [Versioning and Compatibility](docs/versioning.md)
  and [API Overview](docs/api.md) to distinguish `STABLE`, `EXPERIMENTAL`,
  `INTERNAL`, and `TEST_ONLY` declarations.
- The stable entry path is application-owned state → `App`/`update` → immediate
  widget rendering. Do not make background workers mutate widgets or state
  directly.
- Linux/glibc is the primary terminal target. macOS and Windows drivers exist.
  Windows external `EventSource` readiness remains experimental. The default
  waiter accepts sources that provide a native `waitHandle()`; sources that
  expose only a POSIX file descriptor require a custom waiter.
- Raw mode can fail on non-tty input or a `termios` error. Check
  `TerminalSession.rawModeEnabled` and `TerminalMode.lastError()` when
  `TerminalSession.start()` returns `false`; modes enabled by the session are
  rolled back on failure.
- `TerminalSession` restores terminal state, cursor visibility, and enabled input
  modes. Use it for interactive applications rather than managing restoration
  ad hoc.

See `docs/` for the [application runtime](docs/app-runtime.md),
[widgets](docs/widgets.md), [events](docs/events.md), [testing](docs/testing.md),
[platform notes](docs/platforms.md), and [limitations](docs/limitations.md).
