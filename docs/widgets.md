# Widgets

Available widgets include:

- Layout and framing: `Block`, `Paragraph`, `Tabs`, `StatusBar`, `Viewport`.
- Inputs and forms: `Input`, `TextArea`, `Button`, `Checkbox`, `RadioGroup`, `Select`, `Dropdown`, `MultiSelect`, `DatePicker`.
- Commands and overlays: `MenuBar`, `Menu`, `CommandPalette`, `ToastManager`, `Spinner`, `Dialog`.
- Data display: `List`, `Table`, `VirtualTable`, `Tree`, `FilePicker`, `ProgressBar`, `Scrollbar`.
- Support widgets: `HelpView`, `DebugOverlay`.

Stateful widgets keep state in small public state holders such as `ListState`, `TableState`, `TextBuffer`, `Paginator`, or widget fields. `TextBuffer` is sized for small and medium editable text. For large logs, huge files, and unbounded streams, keep data in a virtual line provider, ring buffer, or paged store and render only the visible slice.

`DebugOverlay` renders the latest `AppMetrics` frame with FPS, render/draw time, dirty cells, event queue length, terminal size, and dropped ticks.

`FocusManager` is an EXPERIMENTAL shared primitive that tracks flat
application-owned focus IDs. It owns no second event loop, state model,
lifecycle host, or overlay stack.

`StatusBar` can reserve a compact progress slot through `StatusBarProgress`; it reuses `ProgressBar` label modes and symbols while keeping left and right status text from overlapping on narrow terminal widths.

`TextArea` supports selection, multi-caret editing, paste insertion, undo/redo, find next/previous, word movement, PageUp/PageDown, Ctrl+A/Ctrl+E, readonly mode, optional line numbers, line-number click navigation, mouse drag selection, `DocumentViewState` fold ranges, async completion requests, and line decorations for syntax styling. Line rendering preserves multiple styled spans in one line, resolves overlapping syntax spans, and selection styling patches rendered spans instead of discarding syntax styles. `TextAreaCaret`, `TextCompletionRequest`, `TextCompletionItem`, and `TextCompletionResult` expose editor-oriented state without requiring a full editor shell. `HighlightSpan`, `LineHighlight`, `markdownDecorations()`, `markdownLineHighlights()`, and `MarkdownHighlightCache` provide cached full-document and visible-line highlighter output. `MarkdownEditorBehavior` adds optional Markdown-aware editing on top of `TextArea`: heading/list/task/code/link/table/quote highlighting, fenced-code styling, Enter continuation for unordered, ordered, and task lists, empty-marker list termination, Tab/Shift-Tab multi-line indentation, paired delimiters, selection wrapping, link/image/reference wrapping, frontmatter insertion, and bold/italic/code/link/table/code-fence commands. `MarkdownTextEditor` packages that behavior with a `TextArea` for editor surfaces. Data widgets expose `handle` helpers for keyboard navigation.

For app-level composition, keep canonical state and event ownership in the `App` update function. Use core timer and async commands for effects, derive panel layout with `Layout`, return regional `DirtyRects`, and render immediate widgets or application-local helpers from that state.

`Canvas` is an optional STABLE low-level drawing helper, not a second application
or Widget architecture. `Frame.canvas` exposes the current Frame Buffer through
the stable construction/fill/text contract. Advanced transforms, line/sprite
helpers, Widget bridging, `Surface` composition, and viewport/resize policy
remain EXPERIMENTAL; consult the generated inventory before relying on them.

`VirtualTranscriptView` is a specialized EXPERIMENTAL high-volume transcript
path with its own source/state/metrics contract. It remains attached to the same
App/update model and is not a replacement for the primary Widget abstraction.

`Menu` and `CommandPalette` return action strings from their `handle` methods. Apps can map those action strings to `Command.Message` values and process them in `App.runWithCommands()`. `ToastManager.tick()` ages notifications and is commonly called from `Event.Tick(TickEvent)`.

`VirtualTable` can sort by a column, filter rows by text, track selected source-row indices, style the selected cell, and keep the selected column visible. Its unsorted and unfiltered path reads only viewport rows, making it the preferred table/list shape for large row sets when the app can provide rows by index. It exposes `dirtyHeader`, `dirtyBody`, `dirtyRows`, `dirtySelectionChange`, `dirtyStatus`, and row-cache helpers for application-owned regional dirty rendering. `Tree` supports id-based lookup and expansion helpers. `FilePicker` exposes selected paths, parent navigation, directory entry, and extension filtering that keeps directories visible.

`Sparkline`, `Gauge`, and `Chart` provide lightweight terminal visualizations. `DocumentView` renders rich `Document` content from `RichSpan` and `DocumentLine` nodes, including paragraphs, level-aware heading styles, lists, task items, quotes, code blocks, table headers/rows, horizontal rules, HTML rows, strikethrough rows, image fallback rows, diagnostic rows, word wrapping that preserves spans, scrolling, links, search highlights via `DocumentHighlight`, current-source highlighting, fold ranges through `DocumentViewState`, source-offset lookup in both directions, keyboard scrolling, mouse-to-source lookup, and theme styles. `MarkdownView` is a compatibility wrapper; Markdown parsing belongs in the `packages/markdown` package. `LogView` renders bounded tailing log slices; keep the retention/ring-buffer policy in app state when log volume is unbounded.

`FileDialog`, `ConfirmDialog`, and `ColorPicker` support common app workflows.
