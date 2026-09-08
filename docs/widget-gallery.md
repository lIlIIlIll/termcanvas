# Widget Gallery

## Reader task

Use this page to scan the available immediate widgets by job, then read
[`widgets.md`](widgets.md) for state ownership and behavior details. Each widget
renders into an area supplied by the application; derive those areas with
[`layout.md`](layout.md) and apply input in the `App` update path.

## Framing and text

- `Block` draws borders, titles, padding, margins, and content areas.
- `Paragraph` renders wrapped, aligned text.
- `Tabs` presents tab labels and the selected tab.
- `StatusBar` renders left/right status text and an optional
  `StatusBarProgress` slot without overlap on narrow terminals.
- `Viewport` provides bounded content scrolling.

## Editing and forms

- `Input` edits one line with cursor state.
- `TextArea` edits multiline text with selection, scrolling, find helpers,
  PageUp/PageDown, Ctrl+A/Ctrl+E, optional line numbers, multi-caret editing,
  paste, undo/redo, folds, decorations, and completion.
- `Button`, `Checkbox`, and `RadioGroup` cover common choices and actions.
- `Select`, `Dropdown`, and `MultiSelect` cover one- or many-value selection.
- `DatePicker` supports date selection workflows.

## Lists, tables, and navigation

- `List` and `Table` provide simple stateful displays with `ListState` and
  `TableState` forms for selection and offset.
- `VirtualTable` renders large row sets from a callback. It supports sorting,
  filtering, selected cells, horizontal column viewport adjustment,
  multi-selection row tracking, status states, and viewport-only reads on its
  unsorted/unfiltered path.
- `Tree` supports nested rows, ID lookup, selection by ID, and expand/collapse
  helpers.
- `FilePicker` lists files, enters selected directories, returns selected paths,
  filters by search text and extension, keeps directories visible under
  extension filters, toggles hidden files, sorts directories first, and exposes
  selected metadata.
- `Paginator` provides page, page-size, total, and keyboard navigation state.
- `Scrollbar` indicates a visible range.

## Commands, overlays, and feedback

- `MenuBar` navigates horizontal menu labels.
- `Menu` and `CommandPalette` return optional action strings from `handle`; map
  those strings to `Command.Message` or another `Command` in update.
- `ToastManager` renders short-lived notifications; call `tick()` from the
  application's `Event.Tick(TickEvent)` handling to age them.
- `Spinner` renders lightweight progress.
- `Dialog` renders centered overlay content.
- `FileDialog`, `ConfirmDialog`, and `ColorPicker` support common application
  workflows.

## Documents, logs, and visualizations

- `DocumentView` renders rich `Document` nodes: paragraphs, headings, lists,
  task items, quotes, code blocks, table rows, themed spans, HTML rows,
  strikethrough rows, image fallback rows, and diagnostics. It also supports
  wrapping, scrolling, links, source-offset mapping, search/current-source
  highlights, and fold ranges.
- `MarkdownView` is a compatibility wrapper; Markdown parsing is provided by
  the `packages/markdown` adapter rather than core.
- `LogView` renders bounded tailing log slices. Keep retention or ring-buffer
  policy in application-owned state for unbounded logs.
- `Sparkline`, `Gauge`, and `Chart` provide lightweight terminal
  visualizations.
- `HelpView` renders `KeyMap` bindings.
- `DebugOverlay` renders the latest `AppMetrics` frame, including FPS,
  render/draw time, dirty cells, event queue length, terminal size, and dropped
  ticks.

## Optional families

`Canvas` is a STABLE low-level fill/text drawing helper over the current
caller/`Frame`-owned buffer. Transforms, line/sprite helpers, Widget bridging,
`Surface` composition, and viewport/resize policy remain EXPERIMENTAL.

`VirtualTranscriptView` is an EXPERIMENTAL high-volume transcript path, not a
replacement for immediate widgets. `FocusManager` is an EXPERIMENTAL flat
focus-ID helper, not a second event loop or retained UI tree. Check the
generated [`api-inventory.json`](api-inventory.json) before depending on any
advanced declaration.
