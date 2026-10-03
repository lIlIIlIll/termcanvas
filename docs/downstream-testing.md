# Downstream Application Testing

The `cjtui_testing` package is the supported application-test entry point for
0.0.1. It depends on `core` and internally delegates to the repository's runner,
while its public signatures expose only application types and its own report.
Downstream tests do not import test-only runtime queues, clocks, or scripts.

```toml
[dependencies]
core = { path = "/path/to/termcanvas/packages/core", output-type = "static" }
cjtui_testing = { path = "/path/to/termcanvas/packages/testing", output-type = "static" }
```

Relative paths are also supported. The application generator creates both
dependencies and a complete `std.unittest` example automatically.

## Scenarios and reports

Import `core.*` and `cjtui_testing.*`. Build a `TestScenario` with fluent methods:

| Method | Contract |
| --- | --- |
| `event(Event)` | Dispatch an application event through its update path. |
| `key(KeyEvent)` | Dispatch a key-down event. |
| `paste(String)` | Dispatch a paste event. |
| `message(String)` | Dispatch an application message. |
| `resize(width, height)` | Resize the backend, dispatch Resize, then capture a frame. Dimensions must be positive. |
| `tick(count: n)` | Advance the test clock by the configured interval for each tick and dispatch Tick. The default count is 1; negative counts are rejected. |
| `render()` | Capture another frame without an input event. |
| `expectSnapshot(String)` | Compare the latest complete text snapshot exactly. |
| `expectCell(x, y, String)` | Compare a terminal cell's symbol. |
| `run(render, update, width:, height:, tickDeltaMillis:)` | Start at 80×24 by default, capture the initial frame, execute the scenario and collect a report. Tick interval defaults to 16 ms and must be positive. |

`run` executes returned commands through the same application update path.
The report contains `passed`, `exited`, `frames: Array<Buffer>`,
`snapshots: Array<String>`, and `failures: Array<String>`. `lastSnapshot()` returns
the final capture. Assertion failures accumulate in the report; exceptions
from application code propagate to the calling test. Exit stops further event
dispatch. Scripted render and assertion steps can still inspect the final state.

```cangjie
let report = TestScenario()
    .paste("hello 世界")
    .key(KeyEvent(KeyCode.Enter))
    .resize(100, 30)
    .tick(count: 3)
    .run({ frame => app.render(frame) }, { event => app.update(event) })
@Expect(report.passed)
@Expect(report.lastSnapshot().contains("hello 世界"))
```

Snapshot tests exercise application state and rendering. They do not verify
native terminal mode, OS input delivery, clipboard availability, PTY process
creation, or a real terminal's image support. For deterministic asynchronous
business tests, inject completion events or use a fake application service;
the test API does not promise scheduling determinism for OS processes and
arbitrary background tasks.

## Clean downstream integration check

```sh
CANGJIE_SDK_ROOT=/path/to/cangjie python3 scripts/test_downstream_app.py
```

The script creates an independent temporary directory with a space in its name,
generates a real application, uses a fresh separate target directory, runs
`cjpm build` and `cjpm test`, and launches the resulting binary's smoke mode.
The smoke drives an increment command and a quit event. The temporary application
and build products are removed after success or failure. The library checkout
remains the path dependency; no existing repository target cache is reused.

## Native terminal harness

The repository owns the native probe at `tests/fixtures/native_terminal` and
the Python PTY driver at `scripts/native_terminal_harness.py`. No external
omp-cj checkout or harness is required.

```sh
CANGJIE_SDK_ROOT=/path/to/cangjie python3 scripts/native_terminal_harness.py \
  --output /tmp/termcanvas-native-terminal.json
```

The driver builds the probe in a temporary target unless `--binary` supplies an
existing probe. `--target-dir` preserves a selected build target; `--timeout`
sets the positive per-step deadline. On Linux and macOS it checks:

1. The application enters raw mode, receives an ordinary key, BMP and
   supplementary Unicode characters and an arrow key, and observes a real
   PTY resize from 80×24 to 93×31. A separate redirected-stdin probe preserves
   UTF-8 across two-byte reads.
2. A background producer wakes an otherwise idle application through
   `ExternalPort`, with no ticks or resize polling needed to deliver the event.
3. An exception thrown from update unwinds the terminal session and exits with
   the probe's expected nonzero status.
4. A continuously replenished 64-entry external port delivers at least 1,024
   sequenced events while real keyboard input, a 101×37 resize, timer ticks,
   and rendering keep progressing. The producer retries `Full` without
   discarding a value. After stopping and joining the producer, every accepted
   event must have reached update in order. The report includes event, frame,
   tick, backpressure and queue counts, and rejects queue overflow.
5. Each scenario restores the exact original termios attributes, leaves the
   alternate screen, and restores cursor visibility.

The POSIX driver enforces deadlines and reaps the process group on a failed scenario.
Its JSON report records only completed checks. It does not treat a timeout or
missing expected output as success. It measures PTY-observed behavior, not screen
presentation latency or physical keyboard delivery.

On Windows, install `python -m pip install pywinpty==3.0.5`, then run the same
script with `CANGJIE_SDK_ROOT` set. `windows_terminal_harness.py` explicitly
selects the native ConPTY backend; it does not fall back to WinPTY. It drives
the same ordinary key (without a newline), resize, external wake, sustained
load, and exception exit scenarios. The child queries `GetConsoleMode` to verify line
input and echo are disabled and VT input/output are enabled. Before returning
from both ordinary and exception paths it checks the original input/output
modes and `GetConsoleCursorInfo` cursor size/visibility are restored exactly.
Windows also repeats the redirected-input check through a native message-mode
named pipe. Reads smaller than a message must preserve the prefix returned
with `ERROR_MORE_DATA`, including a UTF-8 character split across reads.

ConPTY may turn stdout into partial screen updates. The native probe therefore
writes sidecar observations only after handling an event or checking console
state; the harness uses those observations and the native process exit status
as evidence. It drains ConPTY output for diagnostics, enforces deadlines, and
terminates an unfinished probe. Its JSON report identifies the transport and
the platform-specific restoration checks. Windows checks do not inspect
termios or claim to verify alternate-screen restoration or visual fidelity.

The socket-backed `PtyProcess` adapter is pinned to the
[upstream 3.0.5 API](https://github.com/andfoy/pywinpty/blob/v3.0.5/winpty/ptyprocess.py)
and its [transport tests](https://github.com/andfoy/pywinpty/blob/v3.0.5/winpty/tests/test_ptyprocess.py).
`python scripts/test_windows_terminal_harness.py` runs the adapter's mock
contract checks on any platform; those checks are not evidence that Windows
Console APIs work. Actual Windows/macOS coverage is established only by a
successful native CI job on that OS. Linux PTY checks can run locally.
The native CI job preserves the JSON report as an artifact, and each package
validation command has a 15-minute deadline so a blocked process produces a
bounded failure rather than consuming the entire platform job.

With Cangjie/cjpm 1.1.3, a project directory containing spaces needs
`package.script-dir` set to a build-script output directory without spaces:
the SDK currently fails to quote its default build-script cache path on both
Windows and Linux. Use the same setting on macOS for portable projects. The
downstream fixture retains its `standalone app` directory and uses an isolated
sibling script cache; build hooks, compilation, tests and execution all run.
The generator exposes this setting through its public `--script-dir` option.
For Windows:

```powershell
python scripts/new_example.py my_app --output "C:/work/my app" --script-dir C:/work/my-app-build-scripts
cd "C:/work/my app"
cjpm build --target-dir C:/work/my-app-target
cjpm test --target-dir C:/work/my-app-target
& C:/work/my-app-target/release/bin/main.exe --headless-smoke
```

For Linux and macOS (from a library checkout without spaces):

```sh
python3 scripts/new_example.py my_app --output "/tmp/my app" --script-dir /tmp/my-app-build-scripts
cd "/tmp/my app"
cjpm build --target-dir /tmp/my-app-target
cjpm test --target-dir /tmp/my-app-target
/tmp/my-app-target/release/bin/main --headless-smoke
```

Keep the library checkout and both output directories free of spaces with
this SDK. The application directory itself is covered by the native test.
