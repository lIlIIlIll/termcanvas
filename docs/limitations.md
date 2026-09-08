# Limitations

This page is an explanation of current boundaries rather than a list of future commitments. For API tiering, see [`versioning.md`](versioning.md); for platform selection and the verification matrix, see [`platforms.md`](platforms.md).

## Reference: platform and terminal boundaries

- Linux/glibc is the target for fully validated terminal behavior. `LinuxTerminalDriver` uses Linux termios and winsize layouts through `TerminalMode`.
- Support outside Linux/glibc remains experimental. macOS has a native source path using Darwin termios, `cfmakeraw()`, and `poll()`. Windows has a native source path using Win32 console mode preservation, VT input/output enablement, and console window-size detection. Both must remain in the platform regression matrix before they are treated as fully supported.
- `FallbackTerminalDriver` is the no-raw portability fallback. It reports a fixed terminal size and disables mouse tracking, bracketed paste, alternate screen, raw mode, and other terminal features when a native driver is unavailable or intentionally bypassed.
- `TerminalSession` installs a best-effort signal guard while active to restore raw mode and common ANSI modes for catchable termination signals such as SIGINT, SIGHUP, SIGQUIT, and SIGTERM. It does not handle SIGKILL or crash signals. The restore path is last-resort cleanup, not a substitute for normal `stop()` / `run { ... }` lifecycles.
- Rendering is terminal-cell based, with a frame-level media overlay path for Kitty graphics, Sixel, and text fallback. There is no GPU renderer or embedded browser.

## Reference: media and external tools

- Media-to-ASCII animation in `media` uses external `ffmpeg` for frame extraction, so supported inputs depend on the installed `ffmpeg` build. The installed build must support `-fps_mode passthrough`. A real invocation was verified with local `ffmpeg` n9.0.1, but that observation does not establish a minimum supported version.
- Media supports monochrome or RGB-colored ASCII, half-block, and braille render modes. Half-block and braille improve effective sample density, but still depend on terminal cell geometry, Unicode glyph rendering, and terminal true-color support.
- Decode has a 10-second deadline, a 16 MiB output limit, and a 256-frame limit. It asks `ffmpeg` for a 257th frame to detect overflow and returns `None` for 257 frames or incomplete RGBA data rather than presenting a truncated animation. Cancelling the calling `Future` interrupts the wait and cleans up the tool process. `gif_ascii` cancels an old load when options change and checks its load revision before publishing a result.
- The first animation version uses fixed-FPS sampling and does not preserve every source GIF disposal rule or per-frame delay.

## Reference: Unicode and terminal-cell layout

- Unicode grapheme segmentation is generated from Unicode 17.0.0 `GraphemeBreakProperty.txt`, `DerivedCoreProperties.txt`, and `emoji-data.txt`. Core tests run the full official `GraphemeBreakTest.txt` fixture.
- Display width remains terminal-cell oriented. CJK and emoji presentation are estimated for TUI layout. East Asian Ambiguous characters default to one cell and can be configured as two cells; font-specific clusters and terminal-specific emoji presentation can differ across terminals.
- A wide character that would start in the final cell of a render area is clipped instead of writing a dangling continuation cell or forcing terminal wrap.

## Reference: event loop, commands, and cancellation

- The event loop is immediate-mode. `Command.AsyncTask`, `Command.AsyncExec`, and `Command.AsyncExecArgs` use Cangjie `spawn` / `Future` and are polled between event-loop iterations. `Command.Exec` and `Command.ExecArgs` remain synchronous and are best for short commands with bounded output.
- Prefer `ExecArgs` / `AsyncExecArgs` for structured argv. `Exec` / `AsyncExec` use only a simple command-line splitter and are not shell-compatible.
- `App.processCommands` and `App.processCommandsWithEvents` create a temporary `AsyncRuntime` when the caller does not supply one. That temporary runtime closes when the helper call ends. To process asynchronous results across calls, pass the same explicit `AsyncRuntime` to each call and retain it for caller-managed cancellation and shutdown.
- Async cancellation is cooperative. `Command.CancelAsync` sends `Future.cancel()` and reports `AsyncCancelled`, but long-running user tasks must check cancellation themselves when they need prompt shutdown.

## Reference: PTY boundary and resource limits

The neutral PTY command/event values are stable, but PTY runtime integration remains Linux/glibc-first and experimental. PTY stdin/stdout use the slave terminal; stderr is exposed through a separate pipe; and signals target the child process group. Applications must explicitly attach `LinuxPtyRuntime()` to an `App` before running it or pass a runtime to lower-level command processing.

Each process has at most 4 MiB of pending stdin data. A successful asynchronous write means that the runtime accepted a snapshot of the complete request. If the request would exceed remaining capacity, the whole request is rejected.

Close sends SIGTERM and allows 100 ms for a normal exit. If the child is still running, close sends SIGKILL, waits for the actual exit, and reports that exit. The neutral values (`PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and `PtyExitStatus`) are stable; runtime attachment and lifecycle remain experimental.

## Reference: file and API boundaries

- `FilePicker` uses standard directory listing and simple string paths. It does not resolve symlinks or expose file metadata.
- API compatibility is pre-1.0 and follows the four-tier policy in [`versioning.md`](versioning.md). Experimental APIs can change or be removed after an intentional documented decision; their presence is not a promise of stabilization.

## Explanation: performance and data-size caveats

- Performance gates separate deterministic regressions from benchmark diagnostics. Release-gate tests assert scale invariants and do not use wall-clock thresholds. `@Bench` / `cjpm bench` is the explicit non-gating path for elapsed-time and slope analysis.
- `TextBuffer` and `TextArea` are not yet large-file editor data structures. Stable viewport rendering reuses cached line indexes and local diff locality is guarded, but cache rebuilds after broad edits, full-text search, full-string edit copies, undo snapshots, fold visibility scans, and Markdown editing helpers may still scale with the whole document until a future rope/piece-table or indexed text model exists.
- Log viewers, huge files, and unbounded streams should use a virtual line provider, ring buffer, or externally paged model. `LogView` is for tail-style bounded log slices; `VirtualTable` is the preferred data-grid shape when rows can be fetched by viewport.
- `VirtualTable`'s unsorted and unfiltered provider path is expected to scale with viewport rows. Sorting and filtering intentionally derive row sets from the full table and may scale with total rows unless a future indexed or externally paged provider is introduced.
