# cjtui

`cjtui` is a small Linux/glibc-first terminal UI library for Cangjie.

It provides:

- ANSI backend: clear screen, cursor movement, SGR colors/styles, alternate screen, mouse and bracketed paste modes.
- Backend abstraction: `Backend`, `AnsiBackend`, and `TestBackend`.
- Terminal mode: raw-mode enter/restore through direct libc FFI.
- Buffer: styled cells, explicit wide-cell lead/continuation state, full draw, diff draw, double-buffered frame reuse, and frame copies for test capture.
- App runtime: `App`, `ControlFlow`, `RenderMode`, `AppMetrics`, `FrameMetrics`, `EventWaiter`, and `FocusManager`, with dirty-driven redraw, span-coalesced partial refresh, FPS/debug metrics, real-time `Duration` ticks, timers, and injectable idle waiting across stdin and registered event sources.
- Command runtime: `Command`, `UpdateResult`, `TimerSpec`, `TimerRuntime`, `Subscription`, and `App.runWithCommands()` for emitted events, messages, async placeholders, real-time timers, synchronous exec-result messages, batches, and quit effects.
- PTY runtime: `PtySpec`, `PtyProcess`, `PtyRuntime`, `PtySignal`, PTY Command/Event variants, `LinuxPtyRuntime` for Linux/glibc PTY processes, and `FakePtyRuntime` for deterministic tests.
- Component routing: `Component`, `HandleResult`, and `EventRouter` for focused event dispatch with global key bindings, consumed/ignored propagation, and command-producing handlers.
- Reactive/view-tree helpers: `StringState`, `IntState`, `ViewNode` dirty tracking, class queries, and event context helpers.
- Widgets: `Block`, `Paragraph`, `List`, `Table`, `Scrollbar`, `Input`, `Button`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, `ProgressBar`, `TextArea`, `Composer`, `TranscriptView`, `ActivityTimeline`, `RequestDialog`, `Tabs`, `Modal`, `Viewport`, `Tree`, `VirtualTable`, `FilePicker`, `FileDialog`, `ConfirmDialog`, `MenuBar`, `Menu`, `CommandPalette`, `ToastManager`, `Spinner`, `Dialog`, `Sparkline`, `Gauge`, `Chart`, `DocumentView`, `MarkdownView`, `LogView`, `SplitPane`, `Wizard`, `Accordion`, `Breadcrumb`, `TreeTable`, `ColorPicker`, `SearchPanel`, `ReplacePanel`, `TextDocumentView`, `TextEditor`, `SoftWrapView`, `HelpView`, and `DebugOverlay`.
- Extensions: Markdown, terminal transcript, diff, media, and game helpers live outside core; `packages/game` provides `game` ECS, input, continuous AABB physics, tile maps, tile markers, sensor overlaps, sprite animation, and sprite rendering.
- Stateful selection helpers: `ListState` and `TableState`.
- Text helpers: grapheme-aware Unicode display width, configurable East Asian ambiguous width, paragraph wrapping, text alignment, `TextBuffer`, selection/range editing, find/replace helpers, grouped undo, true color, and theme styles.
- Events: key down/up/repeat/held, arrows, text, Ctrl/Alt keys, delayed bare Esc, Tab/BackTab, PageUp/PageDown, Insert, F1-F12, CSI/Kitty/modifyOtherKeys modifiers, mouse move/drag/scroll, focus, bracketed paste enabled by default, tick, timer, capabilities, and resize.
- Layout and drawing helpers with length, percent, min, max, ratio, gap, margin, flex placement, `Grid`, `FlexLayout`, `LayoutCache`, `SizeHint`, `Canvas`, `Surface`, `SizeGuard`, and centered viewport helpers.
- Headless testing: `AppTestRunner`, `HeadlessScript`, frame buffer/snapshot capture, synthetic ticks, mixed input replay, and snapshot diff helpers.

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

```bash
/home/elliot/.codex/scripts/codex_cangjie_env cjpm run
```

Run from any application example directory:

- `examples/taskpad`: task-board app with input, keymap, command palette, and toasts.
- `examples/form_studio`: form workflow with focus routing, paste, common form widgets, and status feedback.
- `examples/game_demo`: game extension demo with ECS stores, continuous collision physics, tile maps, sprites, and debug metrics.
- `examples/game_pressure_suite`: six-category game pressure suite covering roguelike, snake, 2048, minesweeper, turn-based strategy, and lightweight real-time action loops.
- `examples/gif_ascii`: ffmpeg-decodable media-to-ASCII animation viewer using ASCII/half-block/braille render modes, optional RGB color, binary threshold control, tick-driven playback, pause, zoom, and speed controls.
- `examples/crystal_caves`: multi-level side-scrolling platform game with tile markers, sensor pickups, hazards, patrol enemies, sprite animation, and camera scrolling.
- `examples/ops_dashboard`: real-time dashboard with ticks, timers, progress, charts, logs, and status bars.
- `examples/data_browser`: data/file browser with virtual table, tree, file picker, file dialog, and paginator.
- `examples/markdown_studio`: Markdown authoring app with editor behavior, completion, preview, and outline.
- `examples/terminal_lab`: terminal, PTY, transcript, and diff lab.
- `examples/media_gallery`: terminal media capability and fallback gallery.
- `examples/style_lab`: DOM/CSS, layout, and canvas lab.
- `examples/oh_my_pi_skin`: oh-my-pi inspired terminal skin with a canvas-drawn hero, independently timed animated todo tree, transcript, composer, command palette, and status line.
- `examples/command_center`: command runtime, async task, timer, dialog, spinner, and toast app.
- `examples/assistant_console`: transcript, composer, activity timeline, and request dialog console.
- `examples/btm_clone`: bottom/btm-style system monitor replica with full-screen canvas graphs, resource panels, process selection, and sort hotkeys.
- `examples/arcade`: playable canvas app with `InputState`, held-key handling, ticks, and resize fallback.
- `examples/debug_lab`: capabilities, enhanced keyboard options, mouse/focus events, metrics, and debug overlay.

## Architecture

- `Backend` is the rendering and terminal-control abstraction. Use `AnsiBackend` for real terminals and `TestBackend` for assertions.
- `Terminal` owns frame drawing, front/back buffer reuse, and buffer diffing.
- `Terminal.draw()` returns `RenderMetrics`; `AppMetrics` records per-frame FPS, render/draw time, queue length, dirty cells, diff write spans, terminal size, and dropped ticks for `DebugOverlay` or custom diagnostics.
- `TerminalSession` owns terminal modes and restores/rolls back raw mode, cursor, mouse, paste, and alternate screen state.
- `TerminalDriver`, `LinuxTerminalDriver`, `MacOSTerminalDriver`, `WindowsTerminalDriver`, and `FallbackTerminalDriver` separate terminal mode/capability behavior from rendering backends.
- `App` provides a small event loop around `Terminal`, `TerminalSession`, `EventParser`, and an injectable `EventWaiter`.
- `App.runWithCommands()` lets update handlers return `UpdateResult` with queued `Command.Emit`, `Command.Message`, `Command.Async`, timer commands, `Command.ExecArgs` / `Command.AsyncExecArgs`, convenience `Command.Exec` / `Command.AsyncExec`, PTY commands, `Command.Batch`, or `Command.Quit` effects. The `*ExecArgs` variants pass explicit argv to `std.process.executeWithOutput`; the string variants use only a simple command-line splitter. PTY commands use the configured `PtyRuntime`.
- `defaultEventWaiter()` selects `LinuxEpollEventWaiter` on Linux/glibc, `MacOSPollEventWaiter` on macOS, and `WindowsConsoleEventWaiter` on Windows. Windows terminal mode itself uses the experimental VT console driver; Windows external `EventSource` readiness is still not equivalent to POSIX fd readiness. Custom `InputSource`, `TerminalDriver`, probe input, and `EventWaiter` implementations remain injectable.
- `FocusManager` tracks string IDs and handles Tab/BackTab focus movement.
- `KeyMap` maps key bindings to action names, `HelpView` renders those bindings, and `EventRouter` routes focused component events before falling back to global keys.
- `ScreenStack` provides push/pop/replace navigation for screen-oriented apps.
- `ViewNode` provides retained-tree style rendering, dirty tracking, id lookup, class query, and capture/target/bubble style event dispatch.
- `RichSpan`, `DocumentLine`, `Document`, `DocumentTheme`, and `DocumentView` form the core rich-document rendering boundary. Core renders spans, paragraphs, headings, lists, quotes, code blocks, tables, scroll, wrap, and theme styles; format parsing stays in extensions.
- `packages/document` provides the experimental document package facade for those rich-document model and view types while `core` keeps the compatibility surface during the pre-1.0 split.
- `packages/editor` provides the experimental editor package facade for `TextBuffer`, `TextArea`, completion, syntax highlighting, Markdown editing behavior, and editor shell widgets while `core` keeps the compatibility surface during the pre-1.0 split.
- Official content extensions should convert external formats into `Document`: `packages/markdown` provides the first adapter as the `markdown` package.
- `packages/terminal`, `packages/diff`, `packages/media`, and `packages/game` provide terminal-output, unified-diff, media, and game-specific helpers while keeping application policy separate.

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
- `Sparkline`, `Gauge`, `Chart`, `DocumentView`, `MarkdownView`, `LogView`, `SplitPane`, `Wizard`, and `ColorPicker` cover common visualization and workflow surfaces.
- `ProgressBar` supports determinate, indeterminate, horizontal, vertical, segmented, custom-symbol, and label-mode rendering while keeping the simple `ProgressBar(value, total, label)` constructor form.
- `MultiSelect`, `DatePicker`, `Accordion`, `Breadcrumb`, `TreeTable`, `FileDialog`, and `ConfirmDialog` cover additional application controls.
- `StyleSheet` supports legacy class rules plus DOM/CSS selector rules over `ViewNode` trees. The CSS subset covers type/id/class, descendant/child, pseudo-state, `::part(...)`, specificity/source-order cascade, visual styles, box spacing, sizing, and block/flex terminal-cell layout.
- `scripts/run_event_script.sh`, `scripts/check_golden_snapshots.sh`, and `scripts/generate_api_index.sh` provide basic engineering workflow checks.
- `Layout` supports `Constraint.Length`, `Percent`, `Min`, `Max`, and `Ratio`, plus `withGap`, `withMargin`, and `withFlex`.
- See `docs/` for API overview, architecture, layout, app runtime, widgets, content extensions, events, testing, examples, widget gallery, and limitations.

## Platform Notes

Default terminal setup is selected through `defaultTerminalDriver()` and `defaultEventWaiter()`. Linux/glibc selects `LinuxTerminalDriver` plus `LinuxEpollEventWaiter`; macOS selects `MacOSTerminalDriver` plus `MacOSPollEventWaiter`; Windows selects `WindowsTerminalDriver` plus `WindowsConsoleEventWaiter` for console input/deadline waiting. Windows external event-source readiness remains experimental because `EventSource` exposes POSIX-style file descriptors. `TerminalMode` is the Linux/glibc raw-mode implementation; `MacOSTerminalMode` uses Darwin termios with `cfmakeraw()` and `poll()`; `WindowsConsoleMode` preserves Win32 console modes while enabling virtual terminal input/output. Use `TerminalSession` to restore raw mode, cursor visibility, mouse mode, paste mode, and the alternate screen on normal exit or exceptions.
