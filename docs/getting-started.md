# Getting Started

## Goal

Build and run the repository's basic application, then verify the complete path:
application-owned state → `App`/`update` → immediate `Widget` rendering. The
application exits from a key event and changes its state through a `Command`.

## Prerequisites

- A checkout of this repository, with commands run from its root unless noted.
- The Cangjie SDK available locally. Set `CANGJIE_SDK_ROOT` to its location;
  the repository wrapper configures the compiler and runtime paths.
- A terminal that can run an interactive application. The template manifest
  declares `cjc-version = "1.1.0"`; the exact canonical verification pin is
  recorded in [Versioning and Compatibility](versioning.md).

## Run the basic application

The complete first application is already in
[`templates/basic_app/src/main.cj`](../templates/basic_app/src/main.cj), with its
package manifest in [`templates/basic_app/cjpm.toml`](../templates/basic_app/cjpm.toml).
Open the source first so the state, event, command, and render paths are visible:

```cangjie
package cjtui_basic_app

import core.*

class DemoApp {
    var count: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r'+') => UpdateResult.withCommand(Command.Message("inc"))
                case _ => UpdateResult.next()
            }
            case Event.Message("inc") =>
                count++
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(
            Paragraph("count: ${count}\n+: increment\nq/Ctrl-C: quit", block: Block(title: "cjtui")),
            frame.area
        )
    }
}

main(): Int64 {
    let app = DemoApp()
    App(targetFps: 10).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
```

From the repository root, build the template with the wrapper:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh templates/basic_app cjpm build
```

Run it with the same command shape:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh templates/basic_app cjpm run
```

### Verify the first success

The running application renders `count` and the `+`/quit key hints. Press `+`
and verify that `count` increases. Press `q` or `Ctrl-C` and verify that the
application exits. This exercises the application-owned state update, the
`Command.Message("inc")` message action, and the immediate `Paragraph` render.

## Add layout and widgets

Keep rendering immediate: compute layout from `frame.area`, then pass each area
to `frame.renderWidget(widget, area)`. Start with:

- `Block` and `Paragraph` for framed text;
- `List` and `Table` for structured rows; and
- `Input`, `TextArea`, or `DocumentView` for editing and rich content.

When selection or scrolling must persist across frames, keep the corresponding
state in the application-owned state and pass `ListState` or `TableState` rather
than relying on transient constructor values.

## Add effects through `Command`

Use `App.runWithCommands()` when an update needs an effect. Return
`UpdateResult.withCommand(...)` from `update`; the runtime executes accepted work
in order and delivers results back through `Event` and the same update path.

- Use `Command.Message` for internal actions.
- Use `Command.AsyncTask` for background work. Workers return immutable results;
  apply them to application-owned state only from `update`.
- Use `Command.AsyncExec` for background process execution.
- Use `Command.StartTimer(TimerSpec(...))` for one-shot or repeating real-time
  timers.
- Keep `Command.Exec` for short synchronous commands.

## Verify event workflows

For deterministic event-script checks, run this command from the repository root:

```bash
scripts/run_event_script.sh \
  packages/core/tests/events/basic.events \
  packages/core/tests/events/scenario.events
```

The script validates the repository's event scenario syntax. For render
assertions and captured frames, use `TestBackend` and the snapshot helpers
covered by [Testing](testing.md).

## Next steps

- Browse the [17-example catalog](examples.md), starting with
  [`taskpad`](../examples/taskpad/) and then choosing a focused application.
- Read [App runtime](app-runtime.md) for event, command, timer, and redraw
  behavior.
- Read [Widgets](widgets.md), [Layout](layout.md), and [Events](events.md) as
  the application grows.
- Check [API Overview](api.md) and [Versioning and Compatibility](versioning.md)
  before adopting experimental or extension-package declarations.
- Before sharing a build, run the repository [release gate](../scripts/release_gate.sh):

  ```bash
  scripts/release_gate.sh
  ```
