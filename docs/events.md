# Events

## Reader task

Use this page to decode terminal input and route every external result through
one application-owned update function. `Event` is data; it does not mutate
application state and it does not render. The stable path is

> `Event` → `App` / update → application-owned state → immediate Widget render

See [`app-runtime.md`](app-runtime.md) for queueing, waiting, timers, and
shutdown, and [`architecture.md`](architecture.md) for the ownership diagram.

## Event vocabulary

The `Event` vocabulary includes the following input and lifecycle values:

### Keyboard, mouse, and terminal state

- `Event.KeyDown(KeyEvent)`, `Event.KeyUp(KeyEvent)`, and
  `Event.KeyRepeat(KeyEvent)` describe terminal key transitions.
- `Event.KeyHeld(KeyEvent)` represents a held-key approximation from
  `InputState` when a terminal cannot report key-up reliably.
- `Event.Mouse(MouseEvent)` covers down, up, drag, move, and scroll with button,
  modifiers, and terminal coordinates.
- `Event.FocusIn` and `Event.FocusOut` are emitted when focus tracking is enabled.
- `Event.Capabilities(TerminalCapabilities)` reports terminal capabilities at
  startup.
- `Event.Paste(String)` carries bracketed-paste payloads.
- `Event.Resize(Rect)` reports the current terminal area.
- `Event.Unknown(Array<Byte>)` preserves bytes that have no recognized event
  mapping.

### Time and application messages

- `Event.Tick(TickEvent)` reports `deltaMillis`, `elapsedMillis`, `frameIndex`,
  and `droppedFrames` for configured real-time ticks.
- `Event.Timer(TimerEvent)` reports a timer ID, elapsed time, fired count, and
  dropped frames.
- `Event.Message(String)` is the small internal message path used by
  `Command.Message` and the compatibility `Command.Async` helper.
- `Event.ExecResult(String, Int64, String)` carries synchronous command output.

### Async and data-source results

- `Event.AsyncStarted(id)` announces a task.
- `Event.AsyncCompleted(id, event)` carries its event result.
- `Event.AsyncFailed(id, message)` and `Event.AsyncCancelled(id)` report the
  terminal task state.
- `Event.DataReady(sourceId, version)`, `Event.DataFailed(sourceId, version,
  message)`, and `Event.DataCancelled(sourceId, version)` identify versioned
  data-source transitions.
- `Event.TextCompletion(id, TextCompletionResult)` carries editor completion
  results; `TextArea.handleCompletionEvent(event)` ignores stale revisions.

### PTY results

- `Event.PtyStarted(id)` announces a PTY.
- `Event.PtyOutput(id, stream, bytes)` carries stdout or stderr, distinguished
  by `PtyOutputStream.Stdout` and `PtyOutputStream.Stderr`.
- `Event.PtyExited(id, status)` carries `PtyExitStatus.Exited(code)` or
  `PtyExitStatus.Signaled(signal)`.
- `Event.PtyFailed(id, message)` reports startup or runtime failure.

The neutral PTY value protocol is STABLE; PTY runtime attachment, process
lifecycle, and readiness APIs are EXPERIMENTAL. See [`app-runtime.md`](app-runtime.md)
and ADR-011 for that boundary.

## Decoding keyboard input

`KeyEvent` includes a `KeyCode`, `KeyModifier`, optional text, the source
`KeyProtocol` (`Basic`, `ModifyOtherKeys`, or `Kitty`), and `nativeRepeat`.
Basic input recognizes common control bytes as Ctrl-modified keys while keeping
Tab, Enter, and Backspace as their conventional key codes.

`Esc` followed by a printable or control byte is parsed as an Alt-modified key.
A bare `Esc` is emitted after the app loop's
`KeyboardOptions.escDelayMillis` delay. `InputState` can consume events through
`handle(event)`, expose `pressedKeys()` and current `modifiers()`, and generate
held-key approximations with `advance(deltaMillis)` when key-up is unavailable.
A `FocusOut` clears its pressed-key state.

`EventParser.push(bytes)` is the preferred deterministic entry point for tests,
headless runners, and injected input. `EventParser(inputSource: ...)` can read
available bytes from an `InputSource`; the default `StdinInputSource` is the
only built-in source that reads stdin. `readEvents()` drains a bounded burst,
while `readEvent()` returns one queued event and `flushEsc()`/`flushEscAfterPolls`
resolve a pending bare escape when the caller controls polling.

Active terminal capability probe responses are consumed by `TerminalProbe`, not
emitted as `Event.Unknown` or key events. After probing, ordinary input flows
through `EventParser`.

## Terminal modes and input policy

`TerminalSession` and `App` enable bracketed paste by default, so terminals that
support mode `?2004` deliver a paste as one `Event.Paste(String)` instead of a
stream of key presses. Pass `bracketedPaste: false` only when an application
intentionally wants pasted bytes parsed as normal key input. Mouse reporting is
opt-in through `mouse` or `mouseMove`; focus reporting is opt-in through
`focusEvents`.

`KeyboardOptions` selects enhanced keyboard mode (`Basic`, `ModifyOtherKeys`,
`Kitty`, or `Auto`) and probe mode (`Disabled`, `EnvOnly`, or `Active`).
`App(inputSource: ..., terminalDriver: ..., probeInputSource: ...)` keeps parser
input, terminal behavior, and probe input independently injectable for
repeatable applications and tests.

## Update boundary and widget interaction

The application update function matches events, changes application-owned state,
and optionally returns a `Command`. Workers and widgets do not bypass this
boundary:

```cj
func update(event: Event): UpdateResult {
    match (event) {
        case Event.KeyDown(key) =>
            match (key.code) {
                case KeyCode.Char(r'q') => UpdateResult.exit()
                case _ => UpdateResult.next()
            }
        case Event.Timer(timer) =>
            if (timer.id == "refresh") {
                refreshRequested = true
            }
            UpdateResult.next()
        case Event.AsyncCompleted(id, result) =>
            applyResult(id, result)
            UpdateResult.next()
        case _ => UpdateResult.next()
    }
}
```

`KeyMap` maps one or more `KeyEvent` values to application action names, and
`HelpView` can render those bindings. Widgets with `handle` methods consume the
input relevant to their local interaction and return their documented result.
For example, `Menu.handle` and `CommandPalette.handle` return an optional action
string; applications map that string to `Command.Message` or another command
inside update. `FocusManager` can help choose an application-owned focus ID,
but it is EXPERIMENTAL and does not create another router or event loop.

## External delivery and testing

`ExternalPort<A>` is an optional STABLE bounded, non-blocking producer seam. A
successful `tryEnqueue` returns `Accepted`, `Full`, or `Closed` and wakes the
same ordered `App` queue; `Accepted` means port acceptance, not that update has
already run or that the value will survive shutdown. Runtime draining,
readiness sources, closing barriers, and port diagnostics are nonstable
implementation surfaces.

For deterministic input-only scenarios use `EventScript` and
`EventParser.push`. `EventScenario` adds render assertions, while
`AppTestRunner` can drive synthetic ticks, mixed input/resize/mouse scripts,
captured buffers, snapshots, metrics, and snapshot-diff messages without a real
terminal. Their exact tier is defined by the generated inventory.
