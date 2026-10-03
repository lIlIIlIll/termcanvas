# App Runtime

## Reader goal and runtime boundary

Use this page to choose an `App` entry point, connect application-owned state to
updates and immediate widgets, and understand where runtime behavior stops being
public API.

The main cjtui path is:

```text
application-owned state → App/update → immediate Widget rendering
```

`App.run(render, update)` is the small immediate-mode loop. The application owns
canonical state; `update` is the only owner that mutates it, and `render` paints
that state with immediate widgets. The update function returns
`ControlFlow.Continue` or `ControlFlow.Exit`.

`App.runWithCommands(render, update)` is the effectful variant. It uses
`UpdateResult`:

- `UpdateResult.next()` continues with no effect.
- `UpdateResult.exit()` exits immediately.
- `UpdateResult.withCommand(command)` queues an effect.

Accepted events and command results enter the INTERNAL `RuntimeQueue` in order.
Updates run to completion with no recursive update nesting. Dirty frame work is
then coalesced for presentation; this is internal scheduling, not a second
public scheduler API.

## Select and issue commands

Return a `Command` from an `UpdateResult.withCommand(...)` path when the update
needs an effect. The available commands are:

- `Command.Noop`: no effect.
- `Command.Quit`: exit the app.
- `Command.Emit(event)`: feed an event back into update.
- `Command.Message(text)`: feed `Event.Message(text)` back into update.
- `Command.Async(name)`: compatibility helper; starts a task that completes with `Event.Message("async:" + name)`.
- `Command.AsyncTask(id, task)`: spawn a Cangjie task and report `AsyncStarted`, then `AsyncCompleted`, `AsyncFailed`, or `AsyncCancelled`.
- `Command.AsyncExec(id, text)`: convenience helper that splits a simple command line, runs it in an async task, and returns an `ExecResult` through `AsyncCompleted`.
- `Command.AsyncExecArgs(id, program, args)`: run `program` with explicit argv in an async task and return an `ExecResult` through `AsyncCompleted`.
- `Command.CancelAsync(id)`: request cooperative cancellation for a pending async task.
- `Command.ProcessStart(id, spec)`: start a pipe-based subprocess with independent stdout/stderr byte events, a deadline, and an output limit.
- `Command.ProcessCancel(id)`: request termination of the subprocess group; completion follows child reaping and bounded output draining.
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

Prefer the `*ExecArgs` variants when command names or arguments come from user
input, file paths, or structured application state. The string-based `Exec` and
`AsyncExec` variants are convenience APIs for short literal commands and use
only the library's simple command-line splitter.

## Stream ordinary subprocesses

Use `ProcessStart` for build tools, searches, and other commands whose output
should arrive before exit. `App` configures `PosixProcessRuntime` by default on
Linux/macOS; the Windows default returns an explicit `ProcessFailed`. A PTY is
not allocated. The child receives EOF on stdin, and arguments are passed as
argv without shell interpretation:

```cangjie
UpdateResult.withCommand(Command.ProcessStart("build", ProcessSpec(
    "make", args: ["all"], timeoutMillis: 30_000, maxOutputBytes: 8 * 1024 * 1024
)))
```

`ProcessStarted(id)` acknowledges startup. `ProcessOutput(id, stream, bytes)`
preserves byte order within each stdout/stderr stream; no ordering is promised
between the two independent pipes. Use one `Utf8StreamDecoder` per stream when
text is wanted, call `feed(bytes)` for each chunk, and `finish()` at completion.
The raw-byte events remain suitable for binary data. Invalid UTF-8 uses
replacement characters and an unfinished scalar is flushed once at EOF.

`ProcessFinished(id, result)` is emitted once, after all retained output events
and reaping the direct child. The result includes the actual exit status,
delivered byte count, `outputComplete`, and a reason: `Exited`, `Cancelled`,
`TimedOut`, `OutputLimit`, or `DrainTimeout`. The output cap counts stdout and
stderr together and retains exactly the accepted prefix; exceeding it reports
`OutputLimit` and `outputComplete = false`. Startup failures and duplicate
active IDs return `ProcessFailed`; a duplicate leaves the original running.

Cancellation/deadline sends SIGTERM to the owned process group, escalating to
SIGKILL after 100 ms. After reaping, a cancelled process has a 250 ms total
termination/drain window. A naturally exited leader has a configurable absolute
`drainTimeoutMillis` (default 1000 ms), with an earlier 250 ms idle-drain limit.
An incomplete drain is explicit. Descendants that create a new session escape
process-group ownership; the runtime bounds its wait for inherited pipes but
does not claim to terminate those escaped processes.

`ProcessSpec.timeoutMillis = 0` disables the execution deadline; the default
output limit is 16 MiB. `PosixProcessRuntime` defaults to 32 active children,
16 KiB read quanta and 64 KiB queued bytes per child. Full output queues pause
reads and apply kernel-pipe backpressure. `metrics()` exposes queued/peak bytes,
delivered bytes and backpressure observations. `App.attachProcessRuntime` must
run before `run`; attaching transfers session ownership of that runtime, and
App shutdown calls `closeAll()`, including when update throws.

The lower-level `App.processCommands*` helpers accept an explicit
`processRuntime:`. Retain it, call the helper again to consume completions, and
close it when finished. Those helpers remain run-to-completion for their queued
commands; they do not wait for a running subprocess to finish.

## Runtime work and admission budgets

An App loop dispatches at most 256 command/event steps before returning to
input, timers and presentation. Pending work resumes in FIFO order on later
turns; command execution and event dispatch alternate. Above 128 pending events,
dispatch first reduces the event backlog before executing further commands, so
self-replenishing commands cannot permanently block new input or source events.
External-port imports
take at most 64 entries at a time and leave remaining entries and their wake
pending. Async, PTY and pipe-process snapshots each admit at most 64 events per
turn. An unfinished snapshot is retained in order and consumed before reading
another snapshot from that runtime, so a large source batch cannot overflow the
event queue. Pending snapshots prevent an idle wait. Explicit PTY close and
replacement preserve trailing output before their terminal events through the
same admission path.

Decoded input and due timers each admit at most 64 events per turn and pause
admission when the event queue reaches its 256-entry high-water mark. Deferred
input remains in the parser batch; deferred timers keep their deadlines and the
next timer scan resumes where the previous bounded scan stopped. These bounds
leave a turn for input, timers and presentation during sustained source traffic.
Internal event and command queues each have a 4096-entry hard limit;
overflow raises a descriptive exception and runs session cleanup rather than
silently dropping accepted output. These are entry-count bounds, not bounds on
arbitrary application-owned event payloads. User update callbacks still run to
completion and must avoid blocking work.

`AppMetrics.runtime()` reports `yieldedTurns` and `queueOverflows` alongside
queue depth and dispatch counts. `AsyncRuntime` admits at most 256 unfinished
tasks by default (`maxPendingTasks` is configurable); superseded tasks retain a
slot until they actually complete. Capacity failure is an `AsyncFailed` event.
Cancellation remains cooperative for arbitrary user task functions.

`LinuxPtyRuntime` defaults to 32 children, 16 KiB reads per source and a 2 MiB
queued-output budget. Readiness and nonblocking polling both respect read
quanta, including trailing output after child exit. Full queues pause reads;
`flowMetrics()` reports queued/peak bytes and backpressure. PTY close allows an
additional bounded 8 MiB reserve to drain bytes already in kernel buffers;
reserve exhaustion is an explicit `PtyFailed`, never silent truncation.

## Schedule ticks and timers

Choose one of these constructors for real-time ticks:

- `App(tickEvery: Some(Duration.millisecond * 16))` uses a fixed interval.
- `App(targetFps: 60)` uses frame-rate based ticks.

`Event.Tick(TickEvent)` reports `deltaMillis`, `elapsedMillis`, `frameIndex`,
and `droppedFrames`. With a late frame, `FrameMissPolicy.Drop` emits one tick
and records dropped frames. `FrameMissPolicy.CatchUp(n)` preserves the scheduled
intervals while emitting the current tick and at most `max(0, n)` additional
overdue ticks. Older slots beyond that budget are skipped and included in
`droppedFrames`. The same policy applies to repeating timers.

Timers emit `Event.Timer(TimerEvent)` and can be one-shot or repeating.

## Inspect rendered frames and metrics

`Terminal.draw(render)` renders through front/back buffers. `RenderMode.Diff` is
the default and performs partial refresh from dirty cells; `RenderMode.Full`
forces a full redraw every frame.

`RenderMetrics` reports terminal size, dirty cell count, diff write spans, media
op count, full-redraw status, render time, draw time, and total frame time. Tests
should prefer `Terminal.draw()` metrics and `TestBackend` helpers over calling
backend diff methods directly, so backend diff implementation details can evolve
without changing app-facing assertions.

To collect app-level frame metrics, construct `let metrics = AppMetrics()` and
pass `App(metrics: Some(metrics), ...)`. `FrameMetrics` then reports FPS,
render/draw/total time, event queue length, dirty cells, diff write spans, last
terminal size, dropped tick count, and tick delta. `DebugOverlay(metrics)`
renders the latest metrics line for in-app diagnostics.

## Configure terminal input

Use `KeyboardOptions` to control enhanced keyboard protocol mode (`Basic`,
`ModifyOtherKeys`, `Kitty`, or `Auto`) and probe mode (`Disabled`, `EnvOnly`, or
`Active`). Active probing uses `TerminalProbe.run()` with an injected
`InputSource`; probe response bytes are consumed by the probe and are not passed
to the normal `EventParser`. `KeyboardOptions.probeBudgetMillis` is clamped to
100ms.

`KeyboardOptions.escDelayMillis` controls how long the app loop waits before
treating a bare `Esc` byte as `KeyCode.Esc`; `Esc` followed by a printable or
control byte is parsed as an Alt-modified key.

`App` enables bracketed paste by default. Pass `bracketedPaste: false` only for
applications that intentionally want pasted bytes parsed as normal key input.
For deterministic app tests and custom terminal backends, inject each concern
independently with `App(inputSource: ..., terminalDriver: ..., probeInputSource: ...)`:
parser input, terminal mode/capability behavior, and active-probe input.

`App(mouseMove: true, focusEvents: true, keyboard: KeyboardOptions(...))`
enables mouse move tracking, focus events, and enhanced key reporting through
`TerminalSession`. `Event.Capabilities(TerminalCapabilities)` is emitted once
at startup so applications can choose color, image, keyboard, and refresh
fallbacks.

For the default configuration:

- `defaultApp()` returns `App()` with the platform-selected backend driver, diff renderer, raw-mode session, bracketed paste, and default event waiter.
- `runApp(render, update)` and `runAppWithCommands(render, update)` run the default app without manually constructing `App`.

## Understand event waiting and failures

`EventWaiter` is the idle-wait abstraction used by `App` after it drains
commands, timers, async tasks, and parsed input.

`defaultEventWaiter()` selects the default implementation:

- `LinuxEpollEventWaiter` on Linux/glibc.
- `MacOSPollEventWaiter` on macOS.
- `WindowsConsoleEventWaiter` on Windows for console input and deadline waits.

`defaultTerminalDriver()` selects matching terminal mode behavior: Linux
termios, macOS termios, or the experimental Windows VT console driver.

Platform-specific readiness behavior is:

- `LinuxEpollEventWaiter` waits on stdin and `PtyRuntime.sources()` or other `EventSource` file descriptors.
- `MacOSPollEventWaiter` waits on stdin and injected `EventSource` file descriptors through `poll()`.
- `WindowsConsoleEventWaiter` waits on the Windows console input handle, timer deadlines, and each `EventSource` that returns a native `waitHandle()`. An `EventSource` without a native Windows handle is not waitable by the default waiter and requires a custom waiter.
- `NoopEventWaiter` is useful for deterministic tests or unsupported platforms where terminal input is not available.

`App` closes the configured waiter on normal exit and when `render`/`update`
throws. When resize polling is enabled, `App(resizePollEvery: Duration.millisecond * 250)`
controls the idle resize check cadence. Tick deadlines, timers, async polling,
and resize polling all participate in the same minimum-timeout calculation, so
a long resize poll interval does not delay ticks.

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

When diagnosing an input or shutdown failure, first distinguish the public
producer result (`Accepted`, `Full`, or `Closed`) from update execution: an
accepted value can still be discarded during shutdown. For a render/update
exception, inspect the caller and update path after confirming that the waiter
was closed by `App`.

## Handle asynchronous, data, completion, and PTY events

Async events are:

- `Event.AsyncStarted(id)`
- `Event.AsyncCompleted(id, event)`
- `Event.AsyncFailed(id, message)`
- `Event.AsyncCancelled(id)`

Async ids are application-owned correlation keys. Worker tasks publish immutable
completion values, and the application update path is the only owner that
applies them to canonical state.

Data source events are:

- `Event.DataReady(sourceId, version)`
- `Event.DataFailed(sourceId, version, message)`
- `Event.DataCancelled(sourceId, version)`

For text completion, `TextArea.completionCommand(id, provider)` builds a
`Command.AsyncTask` from a completion provider. The task returns
`Event.TextCompletion(id, result)` and is delivered through
`Event.AsyncCompleted(id, event)`. `TextArea.handleCompletionEvent(event)`
accepts matching completion results and ignores stale revisions after text
changes.

PTY events are:

- `Event.PtyStarted(id)`
- `Event.PtyOutput(id, stream, bytes)`, where `stream` is `PtyOutputStream.Stdout` or `PtyOutputStream.Stderr`
- `Event.PtyExited(id, status)`
- `Event.PtyFailed(id, message)`

PTY stdout and stderr are separate event streams. The request/result values
`PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and `PtyExitStatus` are the
STABLE data protocol carried by the existing `Command.Pty*` and `Event.Pty*`
constructors. `PtyExitStatus` is either `Exited(code)` or `Signaled(signal)`.

`LinuxPtyRuntime` attaches stdin/stdout to the PTY slave and stderr to a
separate nonblocking pipe, then reports both through `EventSource` readiness. An
application that needs PTY support should construct an `App`, call
`app.attachPtyRuntime(LinuxPtyRuntime())` before `run`/`runWithCommands`, and then
run the app. The default remains `UnsupportedPtyRuntime()` so ordinary apps do
not fork processes implicitly. Attachment, runtime/process lifecycle, and
readiness APIs remain EXPERIMENTAL even though the neutral data protocol is
STABLE. ADR-011 records the boundary.

## Deterministic helpers and implementation boundaries

`Subscription` is a small deterministic source of repeated events for tests and
simple app loops. `AsyncRuntime` and `TimerRuntime` are used by
`App.runWithCommands()`; apps normally do not need to construct them directly
unless they are testing command queues.

`EventScript` is a test helper for deterministic event streams. `EventScenario`
adds render and assertion steps for workflow tests. `AppTestRunner` is the
headless app runner for tests that need synthetic ticks, mixed input/resize/mouse
scripts, captured frame buffers, snapshots, metrics, and snapshot diff messages
without sleeping or using a real terminal.
