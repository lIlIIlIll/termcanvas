# Getting Started

## Hello TUI

Create an app with a render function and an update function:

```cj
let app = App(rawMode: false, alternateScreen: false, hideCursor: false)
app.run(
    { frame => frame.renderWidget(Paragraph("hello", block: Block(title: "cjtui")), frame.area) },
    { event =>
        match (event) {
            case Event.KeyDown(KeyEvent(KeyCode.CtrlC, _)) => ControlFlow.Exit
            case _ => ControlFlow.Continue
        }
    }
)
```

## Widgets And Layout

Use `Layout.horizontal()` and `Layout.vertical()` to split the frame. Render widgets with `frame.renderWidget(widget, area)`.

Common first widgets:

- `Block` and `Paragraph` for framed text.
- `List` and `Table` for structured rows.
- `Input` and `TextArea` for editing.
- `DocumentView` for rich documents and previews.

## Runtime Commands

Use `App.runWithCommands()` when updates need side effects. Return `UpdateResult.withCommand(...)` from the update function.

- Use `Command.Message` for internal actions.
- Use `Command.AsyncTask` for background work.
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
scripts/run_event_script.sh tests/events/basic.events tests/events/scenario.events
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
