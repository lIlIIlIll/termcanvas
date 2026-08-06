# Architecture

`cjtui` uses an immediate-mode render loop. Applications render widgets into a `Buffer`; `Terminal` compares the new buffer with the previous frame and asks a `Backend` to draw either a full frame or a diff.

Core layers:

- `Backend`: terminal control and drawing abstraction.
- `TerminalSession`: raw mode, alternate screen, cursor, mouse, and paste lifecycle.
- `TerminalDriver`: terminal mode and capability behavior selected through OS-gated defaults for Linux/glibc, macOS termios, Windows VT console, fallback, or explicit custom drivers.
- `EventParser`: keyboard, mouse, scroll, and paste parsing over pushed byte chunks or an injected `InputSource`.
- `EventWaiter`: idle wait and external event-source readiness abstraction.
- `App`: small render/update loop.
- `Widget`: render-only components that draw into a `Buffer`.
- `Component`: render plus event handling for stateful app pieces; handlers return `HandleResult`.
- `ViewNode`: retained DOM host for component trees, selector matching, computed styles, and cell-based layout boxes.
- `EventRouter`: sends key events to the focused `Component` first, then falls back to global `KeyMap` bindings when the focused component ignores the key.

`App.run()` keeps the simple `Event -> ControlFlow` model. `App.runWithCommands()` adds `Event -> UpdateResult`, where updates can enqueue messages, batches, async tasks, process commands, or quit requests. Messages re-enter the update function as `Event.Message`; async tasks are managed by `AsyncRuntime` and report lifecycle events back through the same update path.

`App` accepts injectable input, terminal, and waiting boundaries. `inputSource` feeds the normal `EventParser`, `probeInputSource` feeds active terminal probes before normal parsing starts, `terminalDriver` owns terminal mode/capability behavior, and `eventWaiter` owns idle waits plus external readiness. `defaultEventWaiter()` is OS-gated: Linux uses `LinuxEpollEventWaiter` to wait on stdin plus registered `EventSource` file descriptors, macOS uses `MacOSPollEventWaiter`, and Windows uses `WindowsConsoleEventWaiter` for console input and deadline waits. Windows external `EventSource` readiness remains experimental because the current public source shape is POSIX-fd based. Tests and unsupported platforms can pass custom sources, drivers, waiters, or `NoopEventWaiter` without changing render/update code.

`EventParser` accepts an injectable `InputSource`. The default `StdinInputSource` reads stdin, while tests and future platform drivers can feed parser bytes without binding parser logic to a concrete file descriptor. `TerminalProbe` also uses `InputSource`, but it consumes active-probe response bytes before normal event parsing starts.

`FocusManager` remains the low-level focus primitive. `EventRouter` owns a `FocusManager` and registers each component's optional `focusId()`, so Tab and Shift-Tab can move focus without each app rewriting the same dispatch loop. `EventRouter.handleResult()` keeps consumed/ignored, exit, and command results intact; `handle()` remains a `ControlFlow` wrapper for simple apps.

`Layout` supports fixed and proportional sizing with `Constraint.Length`, `Percent`, `Min`, `Max`, and `Ratio`. Use `withGap`, `withMargin`, and `withFlex` for spacing and placement when chunks do not consume all available space. `ComponentHost` uses a `ComponentLayoutProvider` for app-specific panel placement; the default provider preserves the simple vertical equal split used by early examples.

`StyleSheet` now has two layers. Legacy `StyleClass` / `StyleRule` lookups remain available for direct class-style resolution, while the DOM path parses a controlled CSS subset into `CssRule` values. `StyleSheet.apply()` walks a `ViewNode` tree, computes inherited visual style, cascades matching rules by specificity and source order, applies inline declarations last, and assigns block or flex layout boxes in terminal cells. `Frame.renderNode()` is the high-level render entry point for DOM-styled trees.

`TextBuffer` is the reusable text model behind richer editors. It supports byte/rune-safe positions, ranges, find next/previous/all, replace all, word movement, undo/redo, and grouped undo for multi-step edits that should revert as one action. It is intended for small and medium editable text; large logs and huge files should use a virtual line, ring-buffer, or paged provider model and render only visible rows.

The experimental package split now exposes `packages/document` and `packages/editor` as facade packages. `document` carries the rich-document model/view surface, and `editor` carries text-buffer, text-area, completion, syntax, Markdown-editing, and editor-shell surfaces. The underlying implementations remain in `core` for pre-1.0 compatibility while applications migrate to the clearer package boundaries.
