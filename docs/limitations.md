# Limitations

- Platform target is Linux/glibc. `LinuxTerminalDriver` uses Linux termios and winsize layouts through `TerminalMode`.
- Cross-platform support is still experimental outside Linux/glibc. See `docs/platforms.md`.
- `FallbackTerminalDriver` is the no-raw portability fallback. It reports a fixed terminal size and disables terminal features such as mouse tracking, bracketed paste, alternate screen, and raw mode.
- `TerminalSession` installs a best-effort signal guard while active to restore raw mode and common ANSI modes for catchable termination signals such as SIGINT, SIGHUP, SIGQUIT, and SIGTERM. It does not handle SIGKILL or crash signals, and the restore path should still be treated as a last-resort cleanup rather than a substitute for normal `stop()` / `run { ... }` lifecycles.
- Rendering is terminal-cell based with a frame-level media overlay path for Kitty graphics, Sixel, and text fallback. There is no GPU renderer or embedded browser.
- Media-to-ASCII animation in `media` uses external `ffmpeg` for frame extraction, so supported inputs depend on the installed `ffmpeg` build. It supports monochrome or RGB-colored ASCII, half-block, and braille render modes; half-block and braille improve effective sample density but still depend on terminal cell geometry, Unicode glyph rendering, and terminal true-color support. The first version uses fixed FPS sampling and does not preserve every source GIF disposal rule or per-frame delay.
- Unicode width handling covers common terminal cases, CJK wide characters, combining marks, variation selectors, and conservative emoji width. Wide characters that would start in the final cell of a render area are clipped instead of writing a dangling continuation cell or forcing terminal wrap. It is not a full Unicode grapheme-cluster engine: ZWJ emoji sequences and font-specific clusters may occupy different cells in different terminals.
- The event loop is immediate-mode. `Command.AsyncTask` and `Command.AsyncExec` use Cangjie `spawn`/`Future` and are polled between event-loop iterations. `Command.Exec` remains synchronous and is best for short commands with bounded output.
- `LinuxPtyRuntime` is Linux/glibc-first. PTY stdin/stdout use the slave terminal, stderr is exposed through a separate pipe, signals target the child process group, and applications must explicitly pass `LinuxPtyRuntime()` to `App` or command processing.
- Async cancellation is cooperative. `Command.CancelAsync` sends `Future.cancel()` and reports `AsyncCancelled`, but long-running user tasks must check cancellation themselves if they need prompt shutdown.
- API compatibility is pre-1.0 and documented in `docs/versioning.md`.
- `FilePicker` uses standard directory listing and simple string paths. It does not resolve symlinks or expose file metadata.
- CSS/DOM support covers selector matching, cascade, block/flex layout, text nodes, component nodes, and media nodes. It is intentionally smaller than browser CSS.
