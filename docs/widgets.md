# Widgets

## Reader task

Choose an immediate widget for presentation, decide which values belong to
application-owned state, and route interaction through `App` / update. A widget
receives an area and paints the current values into a `Frame`/`Buffer`; it is
not a lifecycle host or a second state/event architecture.

```cj
func render(frame: Frame): Unit {
    let body = frame.area
    frame.renderWidget(
        Paragraph("current value", block: Block(title: "Status")),
        body
    )
}
```

Derive child areas with [`Layout`](layout.md), and use the same application
state in both `update` and `render`. See [`architecture.md`](architecture.md)
for the ownership boundary and [`events.md`](events.md) for key/mouse routing.
The [`widget-gallery.md`](widget-gallery.md) is a visual-oriented catalog.

For app-level composition, keep canonical state and event ownership in the
`App` update function. Use core timer and async `Command` values for effects,
derive panel rectangles with `Layout`, return regional `DirtyRects` when the
runtime API is used, and render immediate widgets or application-local helpers
from the resulting state.

## API map by job

### Layout and framing

- `Block`: border, title, padding, margin, and content area.
- `Paragraph`: wrapped, aligned, styled text.
- `Tabs`: tab labels and selected-tab presentation.
- `StatusBar`: left/right status text with an optional progress slot.
- `StatusBarProgress`: compact progress state used by `StatusBar`.
- `Viewport`: bounded content viewport and scrolling surface.

### Inputs and forms

- `Input`: single-line editable value and cursor.
- `TextArea`: multiline editing, selection, scrolling, folds, decorations, and
  completion.
- `Button`: action-oriented button presentation.
- `Checkbox`: boolean choice.
- `RadioGroup`: one choice from a group.
- `Select`, `Dropdown`, `MultiSelect`: one or many selectable values.
- `DatePicker`: date selection workflow.

### Commands and overlays

- `MenuBar`: horizontal menu navigation.
- `Menu`: selectable items that return optional action strings.
- `CommandPalette`: queryable command items that return optional action strings.
- `ToastManager`: short-lived notifications; `tick()` ages them.
- `Spinner`: lightweight progress animation.
- `Dialog`: centered overlay content.
- `FileDialog`, `ConfirmDialog`, `ColorPicker`: common application workflows.

### Data display

- `List` / `ListState`: simple rows with selected and offset state.
- `Table` / `TableState`: fixed rows and table selection state.
- `VirtualTable`: indexed large-row display with sorting, filtering, and dirty
  regions.
- `Tree`: nested rows with ID lookup and expansion helpers.
- `FilePicker`: directory and file selection with filtering.
- `ProgressBar`: determinate progress and label modes.
- `Scrollbar`: visible-range indication.
- `Paginator`: page and page-size state with keyboard navigation.

### Documents, logs, and visuals

- `DocumentView`: themed rich `Document` rendering, source mapping, scrolling,
  links, highlights, and fold state.
- `MarkdownView`: compatibility wrapper around a `DocumentView`; parsing belongs
  to the `packages/markdown` adapter.
- `LogView`: bounded tailing log slice; retention belongs in application state
  for unbounded logs.
- `Sparkline`, `Gauge`, `Chart`: lightweight terminal visualizations.
- `HelpView`: renders `KeyMap` bindings.
- `DebugOverlay`: renders the latest `AppMetrics` frame.

## State and data size

Stateful widgets expose small public holders such as `ListState`, `TableState`,
`TextBuffer`, `Paginator`, or widget fields. Treat these as presentation and
interaction state unless the application intentionally promotes a value into
its model. `TextBuffer` is sized for small and medium editable text. For large
logs, huge files, and unbounded streams, keep the source in a virtual line
provider, ring buffer, or paged store and render only the visible slice.

`DebugOverlay` reports FPS, render/draw time, dirty cells, event queue length,
terminal size, and dropped ticks from the latest `AppMetrics` frame.
`StatusBar` can reserve a compact slot through `StatusBarProgress`; it reuses
`ProgressBar` label modes and symbols while keeping left and right text from
overlapping at narrow widths.

## Editing and completion

`TextArea` supports selection, multi-caret editing, paste insertion, undo/redo,
find next/previous, word movement, PageUp/PageDown, Ctrl+A/Ctrl+E, read-only
mode, optional line numbers, line-number click navigation, and mouse-drag
selection. It can use `DocumentViewState` fold ranges, request asynchronous
completion, and render line decorations for syntax styling.

Line rendering preserves multiple styled spans on one line, resolves
overlapping syntax spans, and patches selection styling onto rendered spans
instead of discarding syntax styles. `TextAreaCaret`,
`TextCompletionRequest`, `TextCompletionItem`, and `TextCompletionResult` expose
editor-oriented state without a full editor shell.

`HighlightSpan`, `LineHighlight`, `markdownDecorations()`,
`markdownLineHighlights()`, and `MarkdownHighlightCache` provide cached
full-document and visible-line highlighter output. `MarkdownEditorBehavior`
adds optional Markdown-aware editing: heading/list/task/code/link/table/quote
highlighting, fenced-code styling, Enter continuation for unordered, ordered,
and task lists, empty-marker termination, Tab/Shift-Tab multiline indentation,
paired delimiters, selection wrapping, link/image/reference wrapping,
frontmatter insertion, and bold/italic/code/link/table/code-fence commands.
`MarkdownTextEditor` packages that behavior with a `TextArea` for editor
surfaces. Data widgets expose `handle` helpers for keyboard navigation.

## Larger and richer displays

`VirtualTable` accepts a row-count and row callback. It can sort by a column,
filter rows by text, track selected source-row indices, style the selected cell,
keep the selected column visible, and track multiple selected rows. Its
unsorted and unfiltered path reads only viewport rows, making it the preferred
large-table/list shape when the application can provide rows by index. Its
regional helpers include `dirtyHeader`, `dirtyBody`, `dirtyRows`,
`dirtySelectionChange`, `dirtyStatus`, and row-cache helpers for
application-owned dirty rendering.

`Tree` supports ID-based lookup, selection by ID, and expansion/collapse
helpers. `FilePicker` exposes selected paths, parent navigation, directory
entry, search text, hidden-file toggling, directory-first sorting, selected
metadata, and extension filtering that keeps directories visible.

`DocumentView` renders `Document` nodes built from `RichSpan` and
`DocumentLine`: paragraphs, level-aware headings, lists, task items, quotes,
code blocks, table headers/rows, horizontal rules, HTML rows, strikethrough
rows, image fallback rows, and diagnostic rows. It preserves spans during word
wrapping, supports scrolling, links, `DocumentHighlight` search highlights,
current-source highlighting, `DocumentViewState` fold ranges, source-offset
lookup in both directions, keyboard scrolling, mouse-to-source lookup, and
`DocumentTheme` styles.

## Optional and experimental helpers

`Canvas` is an optional STABLE low-level drawing helper, not another application
or Widget architecture. `Frame.canvas` exposes the current `Frame` buffer
through the stable construction/fill/text contract. Advanced transforms,
line/rectangle/sprite helpers, Widget bridging, `Surface` composition, and
viewport/resize policy remain EXPERIMENTAL; consult the generated inventory
before relying on them.

`VirtualTranscriptView` is a specialized EXPERIMENTAL high-volume transcript
path with its own source/state/metrics contract. It remains attached to the
same application-owned state → `App` / update → immediate rendering model and
is not a replacement for the primary Widget abstraction.

`FocusManager` is an EXPERIMENTAL shared primitive for flat,
application-owned focus IDs. It owns no second event loop, state model,
lifecycle host, or overlay stack. `KeyMap` remains STABLE application policy.

`Menu` and `CommandPalette` return action strings from `handle`. Map those
strings to `Command.Message` (or another command) inside update when using
`App.runWithCommands()`. Call `ToastManager.tick()` from the application's
`Event.Tick(TickEvent)` handling when notifications should age.

The exact stability tier of each declaration is defined by
[`api-inventory.json`](api-inventory.json), not by this page or by its package
name. See [`api.md`](api.md) for the human map and [`extensions.md`](extensions.md)
for document and specialized packages.
