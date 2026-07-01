# App Runtime

`App.run(render, update)` is the small immediate-mode loop. The update function returns `ControlFlow.Continue` or `ControlFlow.Exit`.

`App.runWithCommands(render, update)` uses `UpdateResult`:

- `UpdateResult.next()` continues with no effect.
- `UpdateResult.exit()` exits immediately.
- `UpdateResult.withCommand(command)` queues an effect.

Commands:

- `Command.Noop`: no effect.
- `Command.Quit`: exit the app.
- `Command.Emit(event)`: feed an event back into update.
- `Command.Message(text)`: feed `Event.Message(text)` back into update.
- `Command.Async(name)`: compatibility helper; starts a task that completes with `Event.Message("async:" + name)`.
- `Command.AsyncTask(id, task)`: spawn a Cangjie task and report `AsyncStarted`, then `AsyncCompleted`, `AsyncFailed`, or `AsyncCancelled`.
- `Command.AsyncExec(id, text)`: run a command in an async task and return an `ExecResult` through `AsyncCompleted`.
- `Command.CancelAsync(id)`: request cooperative cancellation for a pending async task.
- `Command.PtyStart(id, spec)`: start a PTY process through the configured `PtyRuntime`.
- `Command.PtyWrite(id, bytes)`: write bytes to the PTY master stream.
- `Command.PtyResize(id, size)`: update PTY window size.
- `Command.PtySendSignal(id, signal)`: send a signal to the PTY child process group.
- `Command.PtyClose(id)`: close the PTY and report an exit event.
- `Command.StartTimer(TimerSpec(id, every, mode, missPolicy))`: start a real Duration-based timer.
- `Command.StopTimer(id)`: stop a timer.
- `Command.RestartTimer(spec)`: replace an existing timer with a new schedule.
- `Command.Exec(text)`: split a simple command line, run it synchronously with `std.process.executeWithOutput`, and feed `Event.ExecResult(command, code, output)` back into update.
- `Command.Batch(commands)`: enqueue commands in order. Nested batches are flattened by the public command queue path, including batches passed directly to `App.processCommandsWithEvents`.

Component routing:

- `Component.handle(event)` returns `HandleResult`.
- `HandleResult.ignored()` leaves the event available for other routing paths.
- `HandleResult.consumed()` stops focused/component propagation without exiting.
- `HandleResult.exit()` requests app exit.
- `HandleResult.withCommand(command)` consumes the event and queues an effect when routed through `EventRouter.handleResult()`.

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
- `KeyboardOptions.escDelayMillis` controls how long the app loop waits before treating a bare `Esc` byte as `KeyCode.Esc`; `Esc` followed by a printable or control byte is parsed as an Alt-modified key.
- `App(mouseMove: true, focusEvents: true, keyboard: KeyboardOptions(...))` enables mouse move tracking, focus events, and enhanced key reporting through `TerminalSession`.
- `Event.Capabilities(TerminalCapabilities)` is emitted once at startup so applications can choose color, image, keyboard, and refresh fallbacks.

Event waiting:

- `EventWaiter` is the idle-wait abstraction used by `App` after it drains commands, timers, async tasks, and parsed input.
- `LinuxEpollEventWaiter` is the default implementation. It waits on stdin and `PtyRuntime.sources()` / other `EventSource` file descriptors.
- `NoopEventWaiter` is useful for deterministic tests or unsupported platforms where terminal input is not available.
- `App` closes the configured waiter on normal exit and when render/update throws.

Async events:

- `Event.AsyncStarted(id)`
- `Event.AsyncCompleted(id, event)`
- `Event.AsyncFailed(id, message)`
- `Event.AsyncCancelled(id)`

Text completion events:

- `TextArea.completionCommand(id, provider)` builds a `Command.AsyncTask` from a completion provider.
- The task returns `Event.TextCompletion(id, result)` and is delivered through `Event.AsyncCompleted(id, event)`.
- `TextArea.handleCompletionEvent(event)` accepts matching completion results and ignores stale revisions after text changes.

PTY events:

- `Event.PtyStarted(id)`
- `Event.PtyOutput(id, stream, bytes)` where `stream` is `PtyOutputStream.Stdout` or `PtyOutputStream.Stderr`
- `Event.PtyExited(id, status)`
- `Event.PtyFailed(id, message)`

PTY stdout and stderr are separate event streams. `LinuxPtyRuntime` attaches stdin/stdout to the PTY slave and stderr to a separate nonblocking pipe, then reports both through `EventSource` readiness. Applications that need PTY support should construct `App(ptyRuntime: LinuxPtyRuntime())`; the default remains `UnsupportedPtyRuntime()` so ordinary apps do not fork processes implicitly.

`Subscription` is a small deterministic source of repeated events for tests and simple app loops. `AsyncRuntime` and `TimerRuntime` are used by `App.runWithCommands()`; apps normally do not need to construct them directly unless they are testing command queues.

`EventScript` is a test helper for deterministic event streams. `EventScenario` adds render and assertion steps for workflow tests. `AppTestRunner` is the headless app runner for tests that need synthetic ticks, mixed input/resize/mouse scripts, captured frame buffers, snapshots, metrics, and snapshot diff messages without sleeping or using a real terminal.
