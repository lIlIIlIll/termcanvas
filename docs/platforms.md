# Platform Support

## Explanation: support level and selection

`termcanvas` is Linux/glibc-first today. Linux/glibc is the fully validated terminal target. macOS and Windows have native experimental terminal paths; until a platform is included in the tested regression matrix, document it as experimental.

Platform defaults are isolated behind `@When[os == ...]` factories, so non-Linux targets do not have to use Linux terminal defaults. The default selectors are:

- `defaultTerminalDriver()` selects `LinuxTerminalDriver` on Linux, `MacOSTerminalDriver` on macOS, and `WindowsTerminalDriver` on Windows.
- `defaultEventWaiter()` selects `LinuxEpollEventWaiter` on Linux, `MacOSPollEventWaiter` on macOS, and `WindowsConsoleEventWaiter` on Windows.
- On unsupported or unknown platforms, use `FallbackTerminalDriver`. It never enters raw mode and reports a fixed fallback size, allowing deterministic rendering without platform termios or winsize layouts.

## Reference: platform behavior

### Linux/glibc

Linux terminal sessions use `LinuxTerminalDriver`, raw mode, alternate screen, mouse, bracketed paste, terminal-size detection, capability detection, and ANSI rendering.

Linux app loops use `LinuxEpollEventWaiter` for stdin and external event-source readiness. Linux PTY sessions can use `LinuxPtyRuntime` for PTY-backed child processes, separate stdout/stderr output events, resize, process-group signals, and `EventSource` readiness. PTY runtime attachment remains experimental even though the neutral PTY data protocol is stable; see [`versioning.md`](versioning.md).

### macOS

macOS terminal sessions use `MacOSTerminalDriver`, Darwin termios with `cfmakeraw()`, window-size detection, capability detection, and ANSI rendering.

macOS app loops use `MacOSPollEventWaiter` for stdin and external `EventSource` readiness. The same smoke package must be run from a checkout on the macOS host. Transferring this repository to a remote macOS host requires explicit approval or a pre-synced checkout.

### Windows

Windows terminal sessions use `WindowsTerminalDriver`, Win32 console mode
preservation, virtual-terminal input/output enablement, console window-size
detection, capability detection, and ANSI rendering.

Windows app loops use `WindowsConsoleEventWaiter` for console input, timer
deadlines, and `EventSource` values that provide a native `waitHandle()`.
External readiness remains experimental. A source without a native Windows
handle is not waitable by the default waiter and requires a custom waiter.

## Reference: portability boundaries
- `TerminalDriver` is the portability boundary for terminal mode, terminal size, and terminal capability behavior.
- `EventWaiter` is the portability boundary for blocking/idle waits and readiness. POSIX platforms use file descriptors; Windows uses console input, timer deadlines, and `EventSource.waitHandle()` where available. Sources without native Windows handles require a custom waiter.
- `Backend` is the drawing and terminal-control output interface used by a driver/session combination.
- Widgets, `Buffer`, `Layout`, `DocumentView`, `TextArea`, `EventScenario`, and `TestBackend` remain platform-neutral.
- Platform-specific code belongs in terminal/session/driver/waiter modules, gated with `@When[os == ...]` where behavior differs by OS, not in widgets.

Tests and examples should use `TestBackend` when terminal behavior is not the subject under test. The application path remains application-owned state → `App` / `update` → immediate `Widget` rendering on every platform; platform code supplies terminal mode, waiting, and output boundaries rather than a second application lifecycle.

## Reference: verification matrix

Before claiming full support for another platform, add or update its driver implementation and run the regression matrix from the repository root:

```bash
scripts/run_regression_matrix.sh
```

For Windows, also run:

```bash
scripts/run_windows_smoke.sh
```

For macOS, run the same smoke package on the macOS host:

```bash
MACOS_REPO=/path/to/termcanvas scripts/run_macos_smoke.sh
```

If the macOS host does not expose `cjpm` through its default shell or the linker cannot infer the macOS SDK, pass explicit paths:

```bash
MACOS_REPO=/path/to/termcanvas \
MACOS_CANGJIE_ROOT=/path/to/cangjie \
MACOS_SDKROOT=/path/to/MacOSX.sdk \
scripts/run_macos_smoke.sh
```

Release notes must state the tested platform matrix. A platform not tested in that matrix remains experimental in the documentation, regardless of whether a native source path exists.
