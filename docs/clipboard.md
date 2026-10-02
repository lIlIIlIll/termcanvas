# Clipboard adapters

`Clipboard` separates memory storage from operating-system and terminal clipboard access. `readText()` and `writeText(text)` return `ClipboardResult`; check `isSuccess()`, `status`, `message`, and `backend`. The legacy `getText()` / `setText()` forms throw on adapter failure, so callers cannot mistake unavailable clipboard access for an empty successful paste.

`SystemClipboard()` detects available executables and the current display session without installing software:

| Environment | Copy | Paste |
| --- | --- | --- |
| Linux Wayland (`WAYLAND_DISPLAY`) | `wl-copy --type text/plain;charset=utf-8` | `wl-paste --no-newline` |
| Linux X11 (`DISPLAY`) | `xclip -selection clipboard -in`, or `xsel --clipboard --input` | corresponding output command |
| macOS | `pbcopy` | `pbpaste` |
| Windows | PowerShell `Set-Clipboard` with UTF-8 stdin | PowerShell `Get-Clipboard -Raw` with UTF-8 stdout |

`capabilities()` reports reader and writer availability independently. Detection means an executable and a relevant session were found; the server can still reject access. Each operation reports its actual result. Missing tools produce `Unavailable`, nonzero exits and I/O failures produce `Failed`, expired deadlines produce `Timeout`, and UTF-8 byte budgets produce `TooLarge`. Native defaults are 2 seconds and 1 MiB; options are bounded to 60 seconds and 16 MiB. Cleanup terminates and reaps a timed-out helper, with a bounded cleanup allowance after the operation deadline.

Clipboard content is never interpolated into a shell command or placed in arguments. The native runner sends it on stdin through an automatically removed temporary file: SDK 1.1's stdin wrapper cannot close its write end, so file redirection provides the EOF that copy helpers require. Read output is collected incrementally with a byte limit and drains before process wait. Linux and macOS use the nonblocking process runtime, which drains stdout and stderr independently and owns timeout cleanup; stderr is discarded, with an additional 16 MiB allowance beyond the configured text budget for total process output. Copy helpers can keep a background selection owner; their stdout/stderr use discard streams so that selection ownership does not hold an output pipe open. Native tests exercise stdin, timeout, nonzero exit and live output limiting against real processes. Inject `ClipboardCommandRunner` for headless adapter tests.

## SSH and OSC 52

```cj
let clipboard = Osc52Clipboard({ sequence => terminalOutput.write(sequence.toArray()) })
let result = clipboard.writeText("Unicode 多行\ntext\n")
```

OSC 52 supports writing only. Reading returns `Unsupported`; incoming terminal paste should flow through the normal paste event. Success means the escape sequence was emitted, not that the terminal acknowledged or accepted it. Enable OSC 52 only when the chosen terminal permits it. The default UTF-8 payload limit is 100,000 bytes; the adapter also supports explicit tmux passthrough framing.

`detectClipboard(osc52Emitter: Some(emitter))` selects OSC 52 for an SSH session, otherwise prefers a detected native adapter and uses the explicit emitter if no native writer exists. Without an emitter, the factory never silently writes escape sequences. `MemoryClipboard` remains useful for tests and application-local copy buffers and identifies itself as `memory`.

## Editor use

Pass an adapter to the text area's clipboard methods and show operation failures in application status. Failed copying must not delete a selection; failed reading must not insert an empty string. An application may retain a `MemoryClipboard` separately, but it must not present memory-only copies as successful system clipboard writes.
