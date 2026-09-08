# Getting Started

## Hello TUI

Keep canonical state in an application object. Its update function is the only
owner that applies events and command completions; its render function paints the
current state with immediate widgets:

```cj
package hello_cjtui

import core.*

class HelloApp {
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
    let app = HelloApp()
    App(targetFps: 10).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
```

The repository's `templates/basic_app` contains this same stable API shape as a
runnable project and is built by the official template check.

## Widgets And Layout

Use `Layout.horizontal()` and `Layout.vertical()` to split the frame. Render widgets with `frame.renderWidget(widget, area)`.

Common first widgets:

- `Block` and `Paragraph` for framed text.
- `List` and `Table` for structured rows.
- `Input` and `TextArea` for editing.
- `DocumentView` for rich documents and previews.

## Runtime Commands

Use `App.runWithCommands()` when updates need side effects. Return
`UpdateResult.withCommand(...)` from the update function; the runtime executes
accepted work in order and delivers results back through update.

- Use `Command.Message` for internal actions.
- Use `Command.AsyncTask` for background work. Workers return immutable results;
  apply them to state only from update.
- Use `Command.AsyncExec` for background process execution.
- Use `Command.StartTimer(TimerSpec(...))` for one-shot or repeating real-time timers.
- Keep `Command.Exec` for short synchronous commands only.
- `App` redraws after input, resize, real-time ticks, timers, and command-produced events. On Linux it waits for stdin readiness with `epoll_wait`; tune `tickEvery`, `targetFps`, and `idleSleep` for periodic refresh without busy polling.

## Testing

Use `TestBackend` for render snapshots and `EventScenario` for workflow tests. Scenarios can drive keys, paste text, resize events, and expected cells or snapshots.

```text
scenario:save
key:ctrl-s
expect:flow:continue
```

Run:

```bash
scripts/run_event_script.sh packages/core/tests/events/basic.events packages/core/tests/events/scenario.events
```

## Next Examples

Start with `examples/taskpad`, then read `examples/command_center` for runtime effects, `examples/form_studio` for focus and forms, `examples/markdown_studio` for text editing, and `examples/debug_lab` for diagnostics.

## Release Checks

Before sharing a build, run:

```bash
scripts/run_regression_matrix.sh
scripts/run_pressure.sh
```

Platform support and API stability are documented in `docs/platforms.md` and `docs/versioning.md`.
