# Widget Gallery

Text:

- `Paragraph` renders wrapped and aligned text.
- `TextArea` renders multiline editable text with selection, scrolling, find helpers, PageUp/PageDown, Ctrl+A/Ctrl+E, and optional line numbers.

Forms:

- `Input`, `Button`, `Checkbox`, `RadioGroup`, `Select`, and `Dropdown` cover common form workflows.

Data:

- `List` and `Table` provide simple stateful displays.
- `VirtualTable` renders large row sets from a callback and supports sorting, filtering, selected cells, horizontal column viewport adjustment, and multi-selection row tracking.
- `Tree` supports nested rows, id lookup, selection by id, and expand/collapse helpers.
- `FilePicker` lists files, keeps directories visible under extension filters, enters selected directories, returns selected paths, filters by search text, toggles hidden files, sorts directories first, and exposes selected metadata.

Commands and overlays:

- `MenuBar`, `Menu`, and `CommandPalette` expose action strings.
- `ToastManager` renders short-lived notifications.
- `Spinner` renders lightweight progress.
- `Dialog` renders a centered overlay.

Visuals and workflows:

- `Sparkline`, `Gauge`, and `Chart` provide lightweight terminal visualizations.
- `DocumentView` renders rich document nodes such as paragraphs, headings, lists, quotes, code blocks, table rows, and themed spans.
- `MarkdownView` remains as a compatibility wrapper; Markdown parsing is provided by the `packages/markdown` adapter.
- `LogView` renders tailing logs.
- `ColorPicker` supports common app workflows.
