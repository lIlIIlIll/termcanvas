# API Overview

Core runtime:

- `Backend`, `AnsiBackend`, `TestBackend`, `TerminalDriver`, `LinuxTerminalDriver`, `FallbackTerminalDriver`
- `Terminal`, `Frame`, `TerminalSession`, `TerminalMode`, `TerminalCapabilities`, `KeyboardOptions`, `KeyboardProtocolMode`, `TerminalProbeMode`, `RenderMode`, `RenderMetrics`, `RenderDiffPlan`, `RenderDiffSpan`
- `App`, `ControlFlow`, `Command`, `UpdateResult`, `HandleResult`, `AsyncRuntime`, `TimerSpec`, `TimerRuntime`, `TickEvent`, `TimerEvent`, `TimerMode`, `FrameMissPolicy`, `FrameMetrics`, `AppMetrics`, `PtyRuntime`, `PtyProcess`, `PtySpec`, `PtySize`, `PtySignal`, `PtyExitStatus`, `LinuxPtyRuntime`, `FakePtyRuntime`, `EventSource`, `EventSourceInterest`, `Subscription`, `EventScript`, `EventScenario`, `ScenarioStep`, `ScenarioResult`, `HeadlessStep`, `HeadlessScript`, `HeadlessRunOptions`, `HeadlessRunResult`, `AppTestRunner`, `SnapshotDiff`, `SnapshotDiffResult`, `StringState`, `IntState`
- `Event`, `EventParser`, `KeyEvent`, `KeyProtocol`, `KeyModifier`, `InputState`, `PressedKey`, `MouseEvent`, `MouseKind`, `MouseButton`, `TextCompletionRequest`, `TextCompletionItem`, `TextCompletionResult`
- `FocusManager`, `Component`, `EventRouter`, `ViewNode`, `EventPhase`, `EventPropagation`, `KeyMap`, `KeyBinding`

Rendering and layout:

- `Rect`, `Position`, `SizeHint`, `Sizable`
- `Layout`, `Direction`, `Constraint`, `Flex`, `Spacing`, `Grid`, `FlexItem`, `FlexLayout`, `LayoutCache`
- `Buffer`, `Cell`, `Style`, `Color`, `Modifier`, `Theme`, `StyleClass`, `StyleSheet`, `StyleRule`, `DesignTokens`, `ThemePack`
- `Canvas`, `Surface`, `ViewportFit`, `ResizePolicy`, `SizeGuard`, `centeredViewport()`
- DOM/CSS styling: `CssDisplay`, `CssFlexDirection`, `CssSelectorRelation`, `CssSelector`, `CssRule`, `StyleDeclaration`, `ComputedStyle`

Widgets:

- Text and frame: `Block`, `Paragraph`, `StatusBar`, `Viewport`, `Modal`, `Dialog`, `DocumentView`, `DocumentViewState`, `DocumentFoldRange`, `DocumentHighlight`, `MarkdownView`, `SoftWrapView`
- Lists and data: `List`, `ListState`, `Table`, `TableState`, `VirtualTable`, `TableColumn`, `Tree`, `TreeNode`, `FilePicker`, `Paginator`
- Forms: `Input`, `TextArea`, `TextAreaCaret`, `Composer`, `TextDecoration`, `HighlightSpan`, `LineHighlight`, `markdownDecorations()`, `markdownLineHighlights()`, `MarkdownHighlightCache`, `MarkdownEditorBehavior`, `MarkdownTextEditor`, `Button`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`, `ProgressBar`, `ProgressBarDirection`, `ProgressBarLabelMode`, `ProgressBarSymbols`, `ProgressBarSegment`, `SearchPanel`, `ReplacePanel`, `TextDocumentView`, `TextEditor`
- Commands: `MenuBar`, `Menu`, `MenuItem`, `CommandPalette`, `Toast`, `ToastManager`, `Spinner`
- Visuals and workflows: `Sparkline`, `Gauge`, `Chart`, `LogView`, `Transcript`, `TranscriptView`, `ActivityTimeline`, `RequestDialog`, `DecisionDialog`, `SplitPane`, `Wizard`, `Accordion`, `Breadcrumb`, `TreeTable`, `FileDialog`, `ConfirmDialog`, `ColorPicker`, `EditorBuffer`, `BufferSet`, `SaveDiagnostic`
- Support: `Scrollbar`, `HelpView`, `DebugOverlay`

Text model:

- `RichSpan`, `DocumentLineKind`, `DocumentLine`, `Document`, `DocumentTheme`, `TextBuffer`, `TextPosition`, `TextRange`, `Clipboard`, `MemoryClipboard`, `SyntaxRule`, `SyntaxHighlighter`
- Unicode display width and wrapping helpers are available for widget implementations.

DOM/CSS style system:

- `ViewNode` is the DOM host. It stores `tag`, `id`, classes, pseudo states, optional part name, inline style declarations, computed style, layout box, parent, children, and an optional component.
- `StyleSheet.parse(text)` accepts a practical CSS subset for terminal UI styling: type, id, class, descendant, child, comma-list, pseudo-state, and `::part(...)` selectors.
- CSS rules cascade by selector specificity first and source order second; inline declarations are applied last.
- Supported declarations include foreground/background colors, bold/italic/underline/reversed modifiers, `display`, `width`, `height`, min/max sizes, `margin`, `padding`, `border`, `gap`, and flex direction.
- `Frame.renderNode(node, sheet)` computes styles and block/flex terminal-cell layout before rendering the DOM tree into the frame.

Module layout:

- `packages/core/src/document.cj` owns the rich document model and `DocumentView`.
- `packages/core/src/widgets.cj` keeps general-purpose widgets.
- `packages/markdown` owns Markdown AST to `Document` conversion.
- `packages/cj_markdown` owns Markdown tokenization, parsing, AST, diagnostics, and source ranges.

Content extension boundary:

- Core provides rich document rendering plus frame-level media placement primitives.
- Format adapters such as Markdown, ANSI terminal output, syntax highlighting, diff, JSON, images, video, HTML, and diagnostics should live in extension packages and return `Document`, media placements, or dedicated view models.
- `DocumentView` supports rich spans, wrapped span styling, level-aware heading styles through `DocumentTheme.headingStyle(level)`, task list rows, horizontal rules, HTML rows, strikethrough rows, table headers, media image rows with fallback text, diagnostic rows, search highlights, current-source highlighting, fold ranges, keyboard scrolling, mouse-to-source lookup, and source-offset lookup from rendered lines or back to rendered lines.
- `TextArea` owns common editing history through `undo()`, `redo()`, and `clearHistory()`, supports readonly mode, multi-caret editing, multi-selection rendering, mouse click/drag selection, line-number hit testing, `DocumentViewState` fold ranges, multi-span syntax decorations, selection-compatible styling, async completion requests through `Command.AsyncTask`, and optional Markdown editing helpers, so examples do not need private edit stacks.
- `Terminal.draw()` returns `RenderMetrics`; `App(renderMode: RenderMode.Diff, metrics: Some(AppMetrics()))` records `FrameMetrics` for FPS, render/draw time, dirty cell count, diff write spans, event queue length, terminal size, and dropped tick count. `DebugOverlay` renders those metrics.
- `Backend.drawDiff(next, plan)` receives a `RenderDiffPlan` computed once by `Terminal.draw()`, so backend implementations should render the supplied spans instead of rescanning buffers.
- `AppTestRunner` is the headless workflow runner for deterministic app tests. It replays `HeadlessScript` steps, emits synthetic `TickEvent`s, captures frame buffers and snapshots, and reports snapshot mismatches through `SnapshotDiff`.
- `Component.handle(event)` returns `HandleResult`, so focused dispatch can distinguish ignored events, consumed events, exit requests, and commands. `EventRouter.handleResult()` preserves those details; the older `handle()` helpers remain wrappers when only `ControlFlow` is needed.
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
- `docs/api-index.txt` is the public symbol baseline checked by `scripts/release_gate.sh`.
