# API Overview

Core runtime:

- `Backend`, `AnsiBackend`, `TestBackend`, `TerminalDriver`, `LinuxTerminalDriver`, `MacOSTerminalDriver`, `WindowsTerminalDriver`, `FallbackTerminalDriver`, `defaultTerminalDriver`
- `Terminal`, `Frame`, `TerminalSession`, `TerminalMode`, `TerminalCapabilities`, `TerminalProbe`, `TerminalProbeResult`, `KeyboardOptions`, `KeyboardProtocolMode`, `TerminalProbeMode`, `RenderMode`, `RenderMetrics`, `RenderDiffPlan`, `RenderDiffSpan`
- `App`, `ControlFlow`, `Command`, `UpdateResult`, `HandleResult`, `AsyncRuntime`, `TimerSpec`, `TimerRuntime`, `TickEvent`, `TimerEvent`, `TimerMode`, `FrameMissPolicy`, `FrameMetrics`, `AppMetrics`, `PtyRuntime`, `PtyProcess`, `PtySpec`, `PtySize`, `PtySignal`, `PtyExitStatus`, `LinuxPtyRuntime`, `FakePtyRuntime`, `EventSource`, `EventSourceInterest`, `Subscription`, `EventScript`, `EventScenario`, `ScenarioStep`, `ScenarioResult`, `HeadlessStep`, `HeadlessScript`, `HeadlessRunOptions`, `HeadlessRunResult`, `AppTestRunner`, `SnapshotDiff`, `SnapshotDiffResult`, `StringState`, `IntState`, `LinuxEpollEventWaiter`, `MacOSPollEventWaiter`, `WindowsConsoleEventWaiter`, `NoopEventWaiter`, `defaultEventWaiter`
- `Event`, `EventParser`, `InputSource`, `StdinInputSource`, `KeyEvent`, `KeyProtocol`, `KeyModifier`, `InputState`, `PressedKey`, `MouseEvent`, `MouseKind`, `MouseButton`, `TextCompletionRequest`, `TextCompletionItem`, `TextCompletionResult`
- `FocusManager`, `Component`, `RuntimeComponent`, `ComponentHost`, `ComponentNode`, `ComponentLayoutProvider`, `VerticalComponentLayoutProvider`, `ComponentContext`, `ComponentResult`, `ComponentProfile`, `ComponentProfiler`, `ProfilerSnapshot`, `ProfilerEntry`, `ProfilerOverlay`, `Dirty`, `DashboardGrid`, `DashboardRegion`, `ComponentContainer`, `WidgetComponent`, `ListComponent`, `InputComponent`, `TextAreaComponent`, `LegacyComponentAdapter`, `DataEvent`, `DataSource`, `AsyncDataSource`, `AsyncPoller`, `IdleTask`, `AsyncRefreshMode`, `EventRouter`, `ViewNode`, `EventPhase`, `EventPropagation`, `KeyMap`, `KeyBinding`

API stability tiers:

- Stable candidates: `Widget.render(area, buffer)`, `Backend` / `TestBackend`, `Terminal.draw`, `Buffer`, `Cell`, `CellKind`, `Style`, `Color`, `Rect`, `Position`, `InputSource`, `TerminalDriver`, and the basic `App.run` / `App.runWithCommands` entry points.
- Experimental public: component runtime, datasource/poller runtime, profiler, PTY, dashboard widgets, DOM/CSS styling, media helpers, editor/document facades, and game-oriented helpers. These remain source-compatible where practical but may change before 1.0.
- Test/internal exported: metrics counters, deterministic performance probes, fake runtimes, and low-level dirty/render helpers used by the release gate. These are documented for contributors, not promised as stable application API.

Rendering and layout:

- `Rect`, `Position`, `SizeHint`, `Sizable`
- `Layout`, `Direction`, `Constraint`, `Flex`, `Spacing`, `Grid`, `FlexItem`, `FlexLayout`, `LayoutCache`
- `Buffer`, `Cell`, `CellKind`, `Style`, `Color`, `Modifier`, `Theme`, `StyleClass`, `StyleSheet`, `StyleRule`, `DesignTokens`, `ThemePack`
- `Canvas`, `Surface`, `ViewportFit`, `ResizePolicy`, `SizeGuard`, `centeredViewport()`
- DOM/CSS styling: `CssDisplay`, `CssFlexDirection`, `CssSelectorRelation`, `CssSelector`, `CssRule`, `StyleDeclaration`, `ComputedStyle`

Widgets:

- Text and frame: `Block`, `Paragraph`, `StatusBar`, `Viewport`, `Modal`, `Dialog`, `DocumentView`, `DocumentViewState`, `DocumentFoldRange`, `DocumentHighlight`, `MarkdownView`, `SoftWrapView`
- Lists and data: `List`, `ListState`, `Table`, `TableState`, `VirtualTable`, `TableColumn`, `TableStatus`, `Tree`, `TreeNode`, `FilePicker`, `Paginator`
- Forms: `Input`, `TextArea`, `TextAreaCaret`, `Composer`, `TextDecoration`, `HighlightSpan`, `LineHighlight`, `markdownDecorations()`, `markdownLineHighlights()`, `MarkdownHighlightCache`, `MarkdownEditorBehavior`, `MarkdownTextEditor`, `Button`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, `ProgressBar`, `ProgressBarDirection`, `ProgressBarLabelMode`, `ProgressBarSymbols`, `ProgressBarSegment`, `SearchPanel`, `ReplacePanel`, `TextDocumentView`, `TextEditor`
- Commands: `MenuBar`, `Menu`, `MenuItem`, `CommandPalette`, `Toast`, `ToastManager`, `Spinner`
- Visuals and workflows: `Sparkline`, `Gauge`, `Chart`, `LogView`, `Transcript`, `TranscriptView`, `ActivityTimeline`, `RequestDialog`, `DecisionDialog`, `SplitPane`, `Wizard`, `Accordion`, `Breadcrumb`, `TreeTable`, `FileDialog`, `ConfirmDialog`, `ColorPicker`, `EditorBuffer`, `BufferSet`, `SaveDiagnostic`
- Support: `Scrollbar`, `HelpView`, `DebugOverlay`

Text model:

- `RichSpan`, `DocumentLineKind`, `DocumentLine`, `Document`, `DocumentTheme`, `TextBuffer`, `TextPosition`, `TextRange`, `Clipboard`, `MemoryClipboard`, `SyntaxRule`, `SyntaxHighlighter`
- Unicode text helpers include `displayWidth`, `TextWidthOptions`, `AmbiguousWidth`, `GraphemeCluster`, `graphemeClusters`, `graphemeDisplayWidth`, `nextGraphemeOffset`, and `previousGraphemeOffset`. Grapheme segmentation is generated from Unicode 17.0.0 data and checked against the full official `GraphemeBreakTest.txt` fixture. East Asian Ambiguous characters default to one cell and can be configured as two cells.

DOM/CSS style system:

- `ViewNode` is the DOM host. It stores `tag`, `id`, classes, pseudo states, optional part name, inline style declarations, computed style, layout box, parent, children, and an optional component.
- `StyleSheet.parse(text)` accepts a practical CSS subset for terminal UI styling: type, id, class, descendant, child, comma-list, pseudo-state, and `::part(...)` selectors.
- CSS rules cascade by selector specificity first and source order second; inline declarations are applied last.
- Supported declarations include foreground/background colors, bold/italic/underline/reversed modifiers, `display`, `width`, `height`, min/max sizes, `margin`, `padding`, `border`, `gap`, and flex direction.
- `Frame.renderNode(node, sheet)` computes styles and block/flex terminal-cell layout before rendering the DOM tree into the frame.

Module layout:

- `packages/core/src/document.cj` owns the rich document model and `DocumentView`.
- `packages/core/src/widgets.cj` keeps general-purpose widgets.
- `packages/document` exposes the experimental rich document model and view facade while the implementation remains in `core` for pre-1.0 compatibility.
- `packages/editor` exposes the experimental editor facade for `TextBuffer`, `TextArea`, completion, syntax highlighting, Markdown editing behavior, and editor shell widgets while the implementation remains in `core` for pre-1.0 compatibility.
- `packages/markdown` owns Markdown AST to `Document` conversion.
- `packages/cj_markdown` owns Markdown tokenization, parsing, AST, diagnostics, and source ranges.

Content extension boundary:

- Core provides rich document rendering plus frame-level media placement primitives.
- Format adapters such as Markdown, ANSI terminal output, syntax highlighting, diff, JSON, images, video, HTML, and diagnostics should live in extension packages and return `Document`, media placements, or dedicated view models.
- `DocumentView` supports rich spans, wrapped span styling, level-aware heading styles through `DocumentTheme.headingStyle(level)`, task list rows, horizontal rules, HTML rows, strikethrough rows, table headers, media image rows with fallback text, diagnostic rows, search highlights, current-source highlighting, fold ranges, keyboard scrolling, mouse-to-source lookup, and source-offset lookup from rendered lines or back to rendered lines.
- `TextArea` owns common editing history through `undo()`, `redo()`, and `clearHistory()`, supports readonly mode, multi-caret editing, multi-selection rendering, mouse click/drag selection, line-number hit testing, `DocumentViewState` fold ranges, multi-span syntax decorations, selection-compatible styling, async completion requests through `Command.AsyncTask`, and optional Markdown editing helpers, so examples do not need private edit stacks.
- `TextArea.lineCacheRebuildCount()` is an experimental diagnostic counter for deterministic performance guards. It is not a stable editing API.
- `TextBuffer` is intended for small and medium editable documents plus editor-building blocks. Log viewers, huge files, and unbounded streams should use a virtual line provider, ring buffer, or externally paged model and render through `LogView`, `VirtualTable`, `DocumentView`, or a custom widget instead of loading all text into one `TextBuffer`.
- `Terminal.draw()` returns `RenderMetrics`; `App(renderMode: RenderMode.Diff, metrics: Some(AppMetrics()))` records `FrameMetrics` for FPS, render/draw time, dirty cell count, diff write spans, copied cell count, event queue length, terminal size, and dropped tick count. `DebugOverlay` renders those metrics.
- `Backend.drawDiff(next, plan)` receives a `RenderDiffPlan` computed once by `Terminal.draw()`, so backend implementations should render the supplied spans instead of rescanning buffers.
- Hot render paths can use `Frame.fillRect(x, y, width, height, style)`, `Buffer.fillRect(...)`, `Buffer.writeAsciiSpanUnchecked(...)`, `DirtyRects.intersectsCell(...)`, and `DirtyRects.intersectsRect(...)` to avoid temporary `Rect` allocation and redundant ASCII validation when the caller already owns the bounds and text invariants.
- `CellKind.Normal`, `CellKind.WideLead`, and `CellKind.WideCont` make wide-character layout explicit. The legacy empty-string continuation symbol is retained for compatibility, but new code should check `Cell.kind`.
- `defaultApp()`, `runApp()`, and `runAppWithCommands()` are one-line entry points for the default terminal session and app loop.
- `defaultTerminalDriver()` and `defaultEventWaiter()` are selected with `@When[os == ...]`. Linux uses the real Linux/glibc terminal driver and epoll waiter; macOS uses a Darwin termios driver plus `poll()` waiter; Windows uses the experimental VT console driver and `WindowsConsoleEventWaiter` for console input/deadline waits. Windows external `EventSource` readiness remains experimental because the current source interface is POSIX-fd based.
- `AppTestRunner` is the headless workflow runner for deterministic app tests. It replays `HeadlessScript` steps, emits synthetic `TickEvent`s, captures frame buffers and snapshots, and reports snapshot mismatches through `SnapshotDiff`.
- `Component.handle(event)` returns `HandleResult`, so focused dispatch can distinguish ignored events, consumed events, exit requests, and commands. `EventRouter.handleResult()` preserves those details; the older `handle()` helpers remain wrappers when only `ControlFlow` is needed.
- `RuntimeComponent` is the component-tree lifecycle interface. `ComponentHost` handles mount/unmount, resize, focused dispatch, component timer routing, local-to-global `Dirty` mapping, dirty-aware render skipping, layout through `ComponentLayoutProvider`, and lightweight `ComponentProfile` counters for update/render/timer activity.
- `ComponentContext.pollAsync()` plus `AsyncPoller` and `IdleTask` provide the compatibility background sampling hook. `DataSource<T>` and `AsyncDataSource<T>` add typed latest/stale/error/version state, pending de-duplication, debounce/idle guards, cancellation state, and low-priority poll accounting while the app event loop uses component-scoped `DataReady`, `DataFailed`, and `DataCancelled` notifications.
- `ComponentProfiler`, `ProfilerSnapshot`, and `ProfilerOverlay` expose per-component update/render/timer/async counts, elapsed time, dirty cells/rects, skipped renders, pending datasource count, low-priority data polls, last error, lookup by component id, sorted views, and resettable frame counters for dashboard-level performance diagnosis.
- `ListComponent`, `InputComponent`, and `TextAreaComponent` adapt stateful widgets into the component runtime and return component-level dirty regions for navigation and editing.
- `VirtualTable` exposes local update helpers such as `dirtyHeader()`, `dirtyBody()`, `dirtyRows()`, `dirtySelectionChange()`, `dirtyStatus()`, `clearCachedRows()`, and `cachedRowCount()` so apps can avoid table-wide invalidation for selection and viewport updates.
- `EventParser` parses pushed byte chunks and can read from an injected `InputSource`; `StdinInputSource` is only the default source. Tests, terminal probes, and alternate platform drivers can provide their own input source without changing parser logic.
- `TerminalProbe.run()` sends bounded active terminal queries and consumes probe response bytes through an injected `InputSource`. `KeyboardOptions.probeBudgetMillis` is clamped to at most 100ms. `TerminalSession.probeResult()` exposes the last active probe result when `KeyboardProtocolMode.Auto` and `TerminalProbeMode.Active` are used.
- `MarkdownEditorBehavior` keeps Markdown-specific editor behavior outside the parser layer. It provides cached syntax highlighting, visible-line highlight extraction for large documents, ordered/unordered/task list continuation, empty-marker list termination, multi-line indentation and outdent, paired delimiter insertion, closing-delimiter skipping, selection wrapping, link/image/reference wrapping, frontmatter insertion, and Markdown commands for bold, italic, inline code, links, images, reference links, tables, and code fences.
- `markdown` depends on the in-repository `cj_markdown` parser and maps its AST, source ranges, nested lists, links, images, tasks, HTML, nested emphasis/strong, strikethrough, table alignment, and diagnostics into `Document`.
- `markdown` also provides `markdownOutline()` and `markdownPreviewIndex()` helpers for outline panels and source/preview synchronization.
- `terminal` provides ANSI token parsing, `TerminalScreen`, bounded `TerminalTranscript`, and `TerminalView` with search highlighting.
- `diff` provides unified diff parsing, `DiffDocument` line summaries, and `DiffView` with inline or side-by-side rendering.
- `media` provides media adapter interfaces, terminal protocol selection, external-tool backed image/video frame preparation with safe text fallback, and ffmpeg-backed media-to-ASCII animation helpers through `AsciiRenderMode`, `AsciiRenderOptions`, `AsciiAnimation`, `AsciiFrame` per-cell color data, `FfmpegAsciiAnimationDecoder`, and `AsciiAnimationView`.
- `game` provides `EntityWorld`, generic `ComponentStore<T>`, `GameInputState`, continuous swept-AABB `PhysicsWorld` with sensor-overlap queries, `TileMap` symbol lookup and marker discovery, `Sprite2D`, `SpriteFrame`, `SpriteAnimation`, `Camera2D`, and `SpriteRenderer` for terminal games and simulations.
- See `docs/extensions.md` for the extension roadmap.
- See `docs/platforms.md` for platform support policy.
- See `docs/versioning.md` for API compatibility policy.
- See `docs/regression-matrix.md` for release validation.
- `docs/api-index.txt` is the public symbol baseline checked by `scripts/release_gate.sh`. It records exported symbol drift; it is not itself a stability promise. Use the tiers in this document and `docs/versioning.md` to decide whether an exported symbol is stable candidate, experimental, or test/internal exported.
