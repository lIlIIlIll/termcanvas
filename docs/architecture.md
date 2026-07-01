# Architecture

`cjtui` uses an immediate-mode render loop. Applications render widgets into a `Buffer`; `Terminal` compares the new buffer with the previous frame and asks a `Backend` to draw either a full frame or a diff.

Core layers:

- `Backend`: terminal control and drawing abstraction.
- `TerminalSession`: raw mode, alternate screen, cursor, mouse, and paste lifecycle.
- `TerminalDriver`: terminal mode and capability behavior for Linux/glibc or fallback environments.
- `EventParser`: keyboard, mouse, scroll, and paste parsing.
- `EventWaiter`: idle wait and external event-source readiness abstraction.
- `App`: small render/update loop.
- `Widget`: render-only components that draw into a `Buffer`.
- `Component`: render plus event handling for stateful app pieces; handlers return `HandleResult`.
- `ViewNode`: retained DOM host for component trees, selector matching, computed styles, and cell-based layout boxes.
- `EventRouter`: dispatches global `KeyMap` bindings first, then sends events to the focused `Component`.

`App.run()` keeps the simple `Event -> ControlFlow` model. `App.runWithCommands()` adds `Event -> UpdateResult`, where updates can enqueue messages, batches, async tasks, process commands, or quit requests. Messages re-enter the update function as `Event.Message`; async tasks are managed by `AsyncRuntime` and report lifecycle events back through the same update path.

`App` accepts an injectable `EventWaiter`. The default `LinuxEpollEventWaiter` waits on stdin plus registered `EventSource` file descriptors. Tests and unsupported platforms can pass `NoopEventWaiter` or a custom implementation without changing render/update code.

`FocusManager` remains the low-level focus primitive. `EventRouter` owns a `FocusManager` and registers each component's optional `focusId()`, so Tab and Shift-Tab can move focus without each app rewriting the same dispatch loop. `EventRouter.handleResult()` keeps consumed/ignored, exit, and command results intact; `handle()` remains a `ControlFlow` wrapper for simple apps.

`Layout` supports fixed and proportional sizing with `Constraint.Length`, `Percent`, `Min`, `Max`, and `Ratio`. Use `withGap`, `withMargin`, and `withFlex` for spacing and placement when chunks do not consume all available space.

`StyleSheet` now has two layers. Legacy `StyleClass` / `StyleRule` lookups remain available for direct class-style resolution, while the DOM path parses a controlled CSS subset into `CssRule` values. `StyleSheet.apply()` walks a `ViewNode` tree, computes inherited visual style, cascades matching rules by specificity and source order, applies inline declarations last, and assigns block or flex layout boxes in terminal cells. `Frame.renderNode()` is the high-level render entry point for DOM-styled trees.

`TextBuffer` is the reusable text model behind richer editors. It supports byte/rune-safe positions, ranges, find next/previous/all, replace all, word movement, undo/redo, and grouped undo for multi-step edits that should revert as one action.
