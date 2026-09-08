# App Runtime

`App.run(render, update)` is the small immediate-mode loop. The application owns
canonical state; update is the only owner that mutates it, and render paints that
state with immediate widgets. The update function returns `ControlFlow.Continue`
or `ControlFlow.Exit`.

`App.runWithCommands(render, update)` uses `UpdateResult`:

- `UpdateResult.next()` continues with no effect.
- `UpdateResult.exit()` exits immediately.
- `UpdateResult.withCommand(command)` queues an effect.

Accepted events and command results enter the INTERNAL `RuntimeQueue` in order.
Updates are run-to-completion with no recursive update nesting. Dirty frame work
is then coalesced for presentation; this is internal scheduling, not a second
public scheduler API.

Commands:

- `Command.Noop`: no effect.
- `Command.Quit`: exit the app.
- `Command.Emit(event)`: feed an event back into update.
- `Command.Message(text)`: feed `Event.Message(text)` back into update.
- `Command.Async(name)`: compatibility helper; starts a task that completes with `Event.Message("async:" + name)`.
- `Command.AsyncTask(id, task)`: spawn a Cangjie task and report `AsyncStarted`, then `AsyncCompleted`, `AsyncFailed`, or `AsyncCancelled`.
- `Command.AsyncExec(id, text)`: convenience helper that splits a simple command line, runs it in an async task, and returns an `ExecResult` through `AsyncCompleted`.
- `Command.AsyncExecArgs(id, program, args)`: run `program` with explicit argv in an async task and return an `ExecResult` through `AsyncCompleted`.
- `Command.CancelAsync(id)`: request cooperative cancellation for a pending async task.
- `Command.PtyStart(id, spec)`: start a PTY process through the configured `PtyRuntime`.
- `Command.PtyWrite(id, bytes)`: write bytes to the PTY master stream.
- `Command.PtyResize(id, size)`: update PTY window size.
- `Command.PtySendSignal(id, signal)`: send a signal to the PTY child process group.
- `Command.PtyClose(id)`: close the PTY and report an exit event.
- `Command.StartTimer(TimerSpec(id, every, mode, missPolicy))`: start a real Duration-based timer.
- `Command.StopTimer(id)`: stop a timer.
- `Command.RestartTimer(spec)`: replace an existing timer with a new schedule.
- `Command.Exec(text)`: convenience helper that splits a simple command line, runs it synchronously with `std.process.executeWithOutput`, and feeds `Event.ExecResult(command, code, output)` back into update.
- `Command.ExecArgs(id, program, args)`: run `program` with explicit argv synchronously and feed `Event.ExecResult(id, code, output)` back into update.
- `Command.Batch(commands)`: enqueue commands in order. Nested batches are flattened by the public command queue path, including batches passed directly to `App.processCommandsWithEvents`.

Prefer the `*ExecArgs` variants when command names or arguments come from user input, file paths, or structured application state. The string-based `Exec` and `AsyncExec` variants are convenience APIs for short literal commands and use only the library's simple command-line splitter.

Real-time ticks:

- Construct `App(tickEvery: Some(Duration.millisecond * 16))` for a fixed interval, or `App(targetFps: 60)` for frame-rate based ticks.
- `Event.Tick(TickEvent)` reports `deltaMillis`, `elapsedMillis`, `frameIndex`, and `droppedFrames`.
- `FrameMissPolicy.Drop` emits one tick after a late frame and records dropped frames. `FrameMissPolicy.CatchUp(n)` advances by scheduled intervals with a bounded catch-up count.
- Timers emit `Event.Timer(TimerEvent)` and can be one-shot or repeating.

Frame metrics and debug overlay:

- `Terminal.draw(render)` renders through front/back buffers. `RenderMode.Diff` is the default and performs partial refresh from dirty cells; `RenderMode.Full` forces full redraw every frame.
- `RenderMetrics` reports terminal size, dirty cell count, diff write spans, media op count, full-redraw status, render time, draw time, and total frame time.
- Tests should prefer `Terminal.draw()` metrics and `TestBackend` helpers over calling backend diff methods directly, so backend diff implementation details can evolve without changing app-facing assertions.
- Construct `let metrics = AppMetrics()` and pass `App(metrics: Some(metrics), ...)` to collect `FrameMetrics` for each rendered frame.
- `FrameMetrics` reports FPS, render/draw/total time, event queue length, dirty cells, diff write spans, last terminal size, dropped tick count, and tick delta.
- `DebugOverlay(metrics)` renders the latest metrics line for in-app diagnostics.

Terminal input:

- `KeyboardOptions` controls enhanced keyboard protocol mode (`Basic`, `ModifyOtherKeys`, `Kitty`, or `Auto`) and probe mode (`Disabled`, `EnvOnly`, or `Active`).
- Active probing uses `TerminalProbe.run()` with an injected `InputSource`; probe response bytes are consumed by the probe and are not passed to the normal `EventParser`. `KeyboardOptions.probeBudgetMillis` is clamped to 100ms.
- `KeyboardOptions.escDelayMillis` controls how long the app loop waits before treating a bare `Esc` byte as `KeyCode.Esc`; `Esc` followed by a printable or control byte is parsed as an Alt-modified key.
- `App` enables bracketed paste by default. Pass `bracketedPaste: false` only for applications that intentionally want pasted bytes parsed as normal key input.
- `App(inputSource: ..., terminalDriver: ..., probeInputSource: ...)` injects parser input, terminal mode/capability behavior, and active-probe input independently. This is the preferred path for deterministic app tests and custom terminal backends.
- `App(mouseMove: true, focusEvents: true, keyboard: KeyboardOptions(...))` enables mouse move tracking, focus events, and enhanced key reporting through `TerminalSession`.
- `Event.Capabilities(TerminalCapabilities)` is emitted once at startup so applications can choose color, image, keyboard, and refresh fallbacks.

Convenience entry points:

- `defaultApp()` returns `App()` with the platform-selected backend driver, diff renderer, raw-mode session, bracketed paste, and default event waiter.
- `runApp(render, update)` and `runAppWithCommands(render, update)` run the default app without manually constructing `App`.

Event waiting:

- `EventWaiter` is the idle-wait abstraction used by `App` after it drains commands, timers, async tasks, and parsed input.
- `defaultEventWaiter()` selects the default implementation: `LinuxEpollEventWaiter` on Linux/glibc, `MacOSPollEventWaiter` on macOS, and `WindowsConsoleEventWaiter` on Windows for console input and deadline waits.
- `defaultTerminalDriver()` selects the matching terminal mode implementation: Linux termios, macOS termios, or the experimental Windows VT console driver.
- `LinuxEpollEventWaiter` waits on stdin and `PtyRuntime.sources()` / other `EventSource` file descriptors.
- `MacOSPollEventWaiter` waits on stdin and injected `EventSource` file descriptors through `poll()`.
- `WindowsConsoleEventWaiter` waits on the Windows console input handle and timer deadlines. External `EventSource` readiness on Windows should use a custom waiter until the source interface grows native HANDLE support.
- `NoopEventWaiter` is useful for deterministic tests or unsupported platforms where terminal input is not available.
- `App` closes the configured waiter on normal exit and when render/update throws.
- When resize polling is enabled, `App(resizePollEvery: Duration.millisecond * 250)` controls the idle resize check cadence. Tick deadlines, timers, async polling, and resize polling all participate in the same minimum-timeout calculation, so a long resize poll interval does not delay ticks.

`EventWaiter`, its concrete implementations, and `RuntimeQueue` are INTERNAL
implementation boundaries. The `ExternalPort` producer contract is STABLE: it
is an optional bounded external-delivery seam that wakes the same App queue, not
a second event bus and not required by ordinary applications. Its runtime drain,
readiness, closing-barrier, and state machinery remains non-public; counters and
latency capture remain EXPERIMENTAL diagnostics.

`tryEnqueue` is non-blocking and returns `Accepted`, `Full`, or `Closed`.
`Accepted` means the value entered a running port and any required
empty-to-nonempty wake became visible; it does not mean `App.update` ran and does
not promise survival across shutdown. Concurrent successful calls are ordered by
the port mutex, while each producer's sequential successful calls preserve that
producer's program order. `close()` is idempotent, rejects later enqueue, and may
discard accepted values not yet imported by the runtime.

Async events:

- `Event.AsyncStarted(id)`
- `Event.AsyncCompleted(id, event)`
- `Event.AsyncFailed(id, message)`
- `Event.AsyncCancelled(id)`

Async ids are application-owned correlation keys. Worker tasks publish immutable completion values, and the application update path is the only owner that applies them to canonical state.

Data source events:

- `Event.DataReady(sourceId, version)`
- `Event.DataFailed(sourceId, version, message)`
- `Event.DataCancelled(sourceId, version)`

Text completion events:

- `TextArea.completionCommand(id, provider)` builds a `Command.AsyncTask` from a completion provider.
- The task returns `Event.TextCompletion(id, result)` and is delivered through `Event.AsyncCompleted(id, event)`.
- `TextArea.handleCompletionEvent(event)` accepts matching completion results and ignores stale revisions after text changes.

PTY events:

- `Event.PtyStarted(id)`
- `Event.PtyOutput(id, stream, bytes)` where `stream` is `PtyOutputStream.Stdout` or `PtyOutputStream.Stderr`
- `Event.PtyExited(id, status)`
- `Event.PtyFailed(id, message)`

PTY stdout and stderr are separate event streams. The request/result values
`PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and `PtyExitStatus` are the
STABLE data protocol carried by the existing `Command.Pty*` and `Event.Pty*`
constructors. `PtyExitStatus` is either `Exited(code)` or `Signaled(signal)`.

`LinuxPtyRuntime` attaches stdin/stdout to the PTY slave and stderr to a separate
nonblocking pipe, then reports both through `EventSource` readiness. Applications
that need PTY support should construct an `App`, call
`app.attachPtyRuntime(LinuxPtyRuntime())` before `run`/`runWithCommands`, and then
run the app. The default remains `UnsupportedPtyRuntime()` so ordinary apps do
not fork processes implicitly. Attachment, runtime/process lifecycle, and
readiness APIs remain EXPERIMENTAL even though the neutral data protocol is
STABLE. ADR-011 records the boundary.

`Subscription` is a small deterministic source of repeated events for tests and simple app loops. `AsyncRuntime` and `TimerRuntime` are used by `App.runWithCommands()`; apps normally do not need to construct them directly unless they are testing command queues.

`EventScript` is a test helper for deterministic event streams. `EventScenario` adds render and assertion steps for workflow tests. `AppTestRunner` is the headless app runner for tests that need synthetic ticks, mixed input/resize/mouse scripts, captured frame buffers, snapshots, metrics, and snapshot diff messages without sleeping or using a real terminal.
