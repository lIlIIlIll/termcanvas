# Platform Support

`cjtui` is Linux/glibc-first today. macOS and Windows have native experimental terminal paths. Platform defaults are isolated through `@When[os == ...]` factories so non-Linux targets do not have to use Linux terminal defaults.

Supported runtime path:

- Linux/glibc terminal sessions use `LinuxTerminalDriver`, raw mode, alternate screen, mouse, bracketed paste, terminal size detection, capability detection, and ANSI rendering.
- Linux/glibc app loops use `LinuxEpollEventWaiter` for stdin and external event-source readiness.
- Linux/glibc PTY sessions can use `LinuxPtyRuntime` for PTY-backed child processes, separate stdout/stderr output events, resize, process-group signals, and `EventSource` readiness.
- macOS terminal sessions use `MacOSTerminalDriver`, Darwin termios with `cfmakeraw()`, window-size detection, capability detection, and ANSI rendering.
- macOS app loops use `MacOSPollEventWaiter` for stdin and external event-source readiness.
- Windows terminal sessions use `WindowsTerminalDriver`, Win32 console mode preservation, virtual terminal input/output enablement, console window-size detection, capability detection, and ANSI rendering. Windows app loops use `WindowsConsoleEventWaiter` for console input and deadline waits.
- `defaultTerminalDriver()` selects `LinuxTerminalDriver` on Linux, `MacOSTerminalDriver` on macOS, and `WindowsTerminalDriver` on Windows.
- `defaultEventWaiter()` selects `LinuxEpollEventWaiter` on Linux, `MacOSPollEventWaiter` on macOS, and `WindowsConsoleEventWaiter` on Windows. Windows external `EventSource` readiness is still experimental because the public source interface is POSIX-fd based.
- Tests and examples should use `TestBackend` when terminal behavior is not the subject under test.
- Unsupported or unknown platforms should use `FallbackTerminalDriver`. It never enters raw mode and reports a fixed fallback size, so apps can still render deterministic output without relying on platform termios or winsize layouts.

Portability boundary:

- `TerminalDriver` is the real portability boundary for terminal mode, terminal size, and terminal capability behavior.
- `EventWaiter` is the portability boundary for blocking/idle waits and readiness. POSIX platforms use file descriptors; Windows currently guarantees console input/deadline waits and should use a custom waiter for non-console external sources.
- `Backend` is the drawing and terminal-control output interface used by a driver/session combination.
- Widgets, `Buffer`, `Layout`, `DocumentView`, `TextArea`, `EventScenario`, and `TestBackend` must remain platform-neutral.
- Platform-specific code should stay in terminal/session/driver/waiter modules, gated with `@When[os == ...]` when it differs by OS, not in widgets.

Before claiming full support for another platform, add or update the driver implementation and run:

```bash
scripts/run_regression_matrix.sh
```

For Windows, also run:

```bash
scripts/run_windows_smoke.sh
```

For macOS, run the same smoke package from a checkout on the macOS host; transferring this repository to a remote macOS host requires explicit approval or a pre-synced checkout.

```bash
MACOS_REPO=/path/to/cj_tui scripts/run_macos_smoke.sh
```

If the macOS host does not expose `cjpm` through its default shell or if the linker cannot infer the macOS SDK, pass explicit paths:

```bash
MACOS_REPO=/path/to/cj_tui \
MACOS_CANGJIE_ROOT=/path/to/cangjie \
MACOS_SDKROOT=/path/to/MacOSX.sdk \
scripts/run_macos_smoke.sh
```

Release notes must state the tested platform matrix. Until a platform is tested in that matrix, document it as experimental.
