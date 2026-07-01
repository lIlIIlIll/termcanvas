# Platform Support

`cjtui` is Linux/glibc-first today.

Supported runtime path:

- Linux/glibc terminal sessions use `LinuxTerminalDriver`, raw mode, alternate screen, mouse, bracketed paste, terminal size detection, capability detection, and ANSI rendering.
- Linux/glibc app loops use `LinuxEpollEventWaiter` for stdin and external event-source readiness.
- Linux/glibc PTY sessions can use `LinuxPtyRuntime` for PTY-backed child processes, separate stdout/stderr output events, resize, process-group signals, and `EventSource` readiness.
- Tests and examples should use `TestBackend` when terminal behavior is not the subject under test.
- Unsupported or unknown platforms should use `FallbackTerminalDriver`. It never enters raw mode and reports a fixed fallback size, so apps can still render deterministic output without relying on platform termios or winsize layouts.

Portability boundary:

- `TerminalDriver` is the real portability boundary for terminal mode, terminal size, and terminal capability behavior.
- `EventWaiter` is the portability boundary for blocking/idle waits and file-descriptor readiness.
- `Backend` is the drawing and terminal-control output interface used by a driver/session combination.
- Widgets, `Buffer`, `Layout`, `DocumentView`, `TextArea`, `EventScenario`, and `TestBackend` must remain platform-neutral.
- Platform-specific code should stay in terminal/session/driver/waiter modules, not in widgets.

Before claiming support for another platform, add a driver implementation and run:

```bash
scripts/run_regression_matrix.sh
```

Release notes must state the tested platform matrix. Until a platform is tested in that matrix, document it as experimental.
