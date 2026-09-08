# cjtui

`cjtui` is a Linux/glibc-first terminal UI library for Cangjie. Applications own
their canonical state and update it from `Event`s in an `App` loop. Effects are
returned as `Command`s, and immediate `Widget`s render the resulting state through
`Frame` and `Buffer` to a `Backend`.

The primary model is one path:

```text
application-owned state
        ↓
App / update / Event / Command
        ↓
ordered, run-to-completion runtime
        ↓
DirtyRects / frame coalescing
        ↓
immediate Widget rendering
        ↓
Frame / Buffer / Backend
```

Key capabilities include:

- application runtime, ordered commands, timers, async completions, and regional redraws;
- immediate widgets, layout, styles/themes, text editing, rich documents, and Unicode-aware buffers;
- keyboard, mouse, paste, focus, terminal capability, and resize events;
- terminal/session restoration plus real and headless backends;
- optional PTY, media, transcript, diff, editor, document, and game facilities; and
- deterministic event, snapshot, headless-example, pressure, and release-gate testing.

Not every exported declaration has the same support promise. Start with the stable
primary path above; current experimental facilities are labelled in
[`docs/api.md`](docs/api.md) and governed by
[`docs/versioning.md`](docs/versioning.md).

## Minimal Use

```cangjie
import core.*

main(): Int64 {
    runAppWithCommands(
        { frame =>
            frame.renderWidget(
                Paragraph("Hello, cjtui", block: Block(title: "Demo")),
                frame.area
            )
        },
        { _ => UpdateResult.next() }
    )
    0
}
```

Use `Terminal`, `Backend`, and `TerminalSession` directly when writing a custom backend, low-level terminal test, or advanced session wrapper.

## Examples

From the repository root, point `CANGJIE_SDK_ROOT` at the canonical SDK and run
an example through the repository wrapper:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

The authoritative taxonomy is in
[`docs/examples.md`](docs/examples.md): eight recommended applications, two
experimental applications, six feature demonstrations, and one pressure/proof
workload. Start with `taskpad`; use `btm_clone` for a nontrivial experimental
App/update example with timers, async completion, focus, and regional dirty
rendering; use `media_gallery` for direct terminal-media and `DocumentLine.image`
integration.

## Architecture

`App` is the single top-level event owner. Its update function mutates
application-owned state and returns effects; background work returns immutable
completion events to that same update path rather than mutating widgets. The
runtime drains accepted work in order and runs each update to completion before
coalescing dirty regions into a frame. Widgets are immediate renderers over the
current state and layout.

`Backend`, `Terminal`, `TerminalSession`, `Frame`, and `Buffer` own terminal I/O,
restoration, and presentation. Focus, media, PTY, transcripts, documents, and
other facilities are shared or specialized capabilities attached to this model,
not alternative UI architectures. See [`docs/architecture.md`](docs/architecture.md)
for the current topology and ADR-008 for historical architecture decisions.

## Release Gate

```bash
scripts/release_gate.sh
```

The gate runs parser tests, extension tests, core tests, event script validation, golden snapshot validation, API baseline checks, Unicode generated-data drift checks, example builds, smoke checks, and pressure-oriented scenarios.

`packages/markdown` depends on the in-repository `packages/cj_markdown` parser package, so a clean checkout can run the full gate without a sibling parser checkout.

## Notes

- `TerminalSession.rawModeEnabled` reports whether raw mode was actually enabled.
- `TerminalMode.lastError()` returns the last raw-mode setup failure reason, such as non-tty stdin or `termios` failure. If raw mode fails during `TerminalSession.start()`, modes already enabled by the session are rolled back before `false` is returned.
- `List` and `Table` still accept direct `selected`/`offset` style arguments where supported; pass `ListState` or `TableState` when selection and scrolling should persist across frames.
- `Input` supports placeholder text, helper methods such as `setValue()`/`clear()`, and horizontal viewport adjustment so the cursor remains visible in narrow areas.
- `TextArea` supports multiline editing, multi-caret and mouse selection, paste insertion, find next/previous, word movement, cursor movement, PageUp/PageDown, Ctrl+A/Ctrl+E, optional line numbers with click navigation, fold ranges, async completion results, and vertical scrolling.
- `displayWidth`, `graphemeClusters`, `nextGraphemeOffset`, and `previousGraphemeOffset` use Unicode 17.0.0 grapheme-break data for cursor movement, truncation, wrapping, and `TextBuffer` deletion. The release gate checks the generated tables and the full official `GraphemeBreakTest.txt` fixture.
- `Paragraph` supports `WrapMode.NoWrap`, `WrapMode.Word`, `WrapMode.Character`, and `TextAlign.Left`/`Center`/`Right`.
- `Color.Rgb(r, g, b)` renders true color SGR sequences.
- `Theme.default()` provides normal/focused/selected/disabled/error/accent styles for newer form widgets.
- `TestBackend.snapshot()`, `TestBackend.assertCell()`, `AppTestRunner`, and `SnapshotDiff` support render assertions, captured frame workflows, synthetic tick replay, and useful snapshot mismatch messages.
- `VirtualTable`, `Tree`, `FilePicker`, and `Paginator` expose keyboard navigation helpers for app-level event handlers. `VirtualTable` also supports sorting, filtering, selected cells, horizontal column viewport adjustment, frozen columns, column resizing, sort indicators, and multi-selection row tracking.
- `Tree` supports selected ids, id lookup, expand-all, and collapse-all. `FilePicker` supports parent navigation, entering selected directories, choosing selected paths, hidden-file toggling, search filtering, directory-first sorting, selected metadata, and keeps directories visible when filtering by extension.
- `Menu`, `MenuBar`, `CommandPalette`, `ToastManager`, `Spinner`, and `Dialog` cover common command surfaces.
- `Sparkline`, `Gauge`, `Chart`, `DocumentView`, `MarkdownView`, `LogView`, and `ColorPicker` cover common visualization and workflow surfaces.
- `ProgressBar` supports determinate, indeterminate, horizontal, vertical, segmented, custom-symbol, and label-mode rendering while keeping the simple `ProgressBar(value, total, label)` constructor form.
- `MultiSelect`, `DatePicker`, `FileDialog`, and `ConfirmDialog` cover additional application controls.
- `scripts/run_event_script.sh`, `scripts/check_golden_snapshots.sh`, and `scripts/generate_api_index.sh` provide basic engineering workflow checks.
- `Layout` supports `Constraint.Length`, `Percent`, `Min`, `Max`, and `Ratio`, plus `withGap`, `withMargin`, and `withFlex`.
- See `docs/` for API overview, architecture, layout, app runtime, widgets, content extensions, events, testing, examples, widget gallery, and limitations.

## Platform Notes

Default terminal setup is selected through `defaultTerminalDriver()` and `defaultEventWaiter()`. Linux/glibc selects `LinuxTerminalDriver` plus `LinuxEpollEventWaiter`; macOS selects `MacOSTerminalDriver` plus `MacOSPollEventWaiter`; Windows selects `WindowsTerminalDriver` plus `WindowsConsoleEventWaiter` for console input/deadline waiting. Windows external event-source readiness remains experimental because `EventSource` exposes POSIX-style file descriptors. `TerminalMode` is the Linux/glibc raw-mode implementation; `MacOSTerminalMode` uses Darwin termios with `cfmakeraw()` and `poll()`; `WindowsConsoleMode` preserves Win32 console modes while enabling virtual terminal input/output. Use `TerminalSession` to restore raw mode, cursor visibility, mouse mode, paste mode, and the alternate screen on normal exit or exceptions.
