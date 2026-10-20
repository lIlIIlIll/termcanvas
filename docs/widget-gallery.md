# Widget Gallery

## Reader task

Use this page to scan the available immediate widgets by job, then read
[`widgets.md`](widgets.md) for state ownership and behavior details. Each widget
renders into an area supplied by the application; derive those areas with
[`layout.md`](layout.md) and apply input in the `App` update path.

## Interactive Workbench Gallery

Run the live gallery from the repository root with the configured Cangjie SDK:

```bash
scripts/cangjie_cmd.sh examples/workbench cjpm run
```

The Workbench opens in the Graphite / Cyan theme. `Tab` enters category
navigation; Left/Right changes categories; Tab then reaches the category's real
controls. Mouse clicks use the same widget hit regions. `F2` opens the existing
command palette, `F3` changes Workbench pages, and `Esc` closes overlays. The
Forms page demonstrates normal, focused, error, and disabled control states.
Its Button row maps Primary to accent, Secondary to surface, Ghost to normal,
and Danger to error styles. The live editor remains separate from static state
previews.
Themes switches Dark/Light, the accent, and a color-tier preview capped at
detected terminal capability; Layout toggles ASCII border fallback. The gallery
uses ASCII borders automatically when the terminal reports no Unicode support
and remains interactive at `80×24`, adapting panel content to available cells.

The data gallery uses task progress in hundredths of a percent (`0..10000`) for
both its label and `Gauge`; `0.83%` is therefore a small fraction, not 83% of the
bar. Toast examples use the Workbench's shared `ToastManager` and tick lifecycle.

The Data category exposes Table, List, and Progress samples through a `Tabs`
selector. Switching samples preserves separate table/list selections, and only
visible controls enter the focus order. Table and List viewports expand with
available height; Progress pairs the weighted gauge with the progress-history
sparkline.

### Theme and terminal capabilities

`Style.patch` treats `Color.Reset` and `Modifier.none()` as inheritance markers.
Other foreground/background colors replace their corresponding base colors; a
non-empty modifier replaces the entire modifier set. The themed state order is
disabled, error, selected, focused, then normal. A focused selected/error state
keeps that role's colors and adds focus modifiers; disabled state suppresses
focus styling.

`Theme.graphite`, `Theme.light`, `Theme.forCapabilities`, and
`adaptStyleForCapabilities` are EXPERIMENTAL. Capability adaptation preserves
RGB for true-color terminals, maps RGB to the nearest xterm-256 entry for
xterm-256, maps RGB/indexed colors to the nearest ANSI-8 color for ANSI-8, and
resets foreground/background colors for monochrome. Palette ties choose the
lowest index. Modifiers are preserved. A `colorLevel` of 16 uses ANSI-8
adaptation; levels below 8 use monochrome unless `trueColor` is true.
The monochrome preview replaces colored accent swatches with ASCII initials and
keeps the selected palette value unchanged for later theme changes.

The Themes page previews the detected tier or a lower tier only; a preview
cannot claim capabilities above the actual `Event.Capabilities` value. The
Workbench also selects ASCII borders when terminal capabilities report no
Unicode support. Environment-based detection is an inference, not a native
low-color terminal test; such terminals remain unverified without exercising
the real terminal.

### Capability matrix

API tiers follow the generated [API inventory](api-inventory.json); a Gallery
demonstration does not promote an experimental declaration.

| Capability | Status | API tier | Current evidence |
| --- | --- | --- | --- |
| `Button`, `Input`, `List`, `Table`, and stable `Tabs` controls | Implemented | STABLE | Focus preview, visible List-row hit/render, and Tabs keyboard, mouse, and no-theme boundary behavior in the [Workbench tests](../examples/workbench/src/main_test.cj) and [core widget tests](../packages/core/src/widget_render_boundary_test.cj). |
| `Tabs.setTheme` | Implemented | EXPERIMENTAL | Workbench category, sample, and Navigation selectors use semantic roles; core tests cover opt-in, explicit-style preservation, focus modifiers, Unicode, and clipping. |
| `Gauge`, `Sparkline`, `Dialog`, `CommandPalette`, `FocusManager`, and `ModalFocusState` | Implemented | EXPERIMENTAL | Demonstrated by the Workbench; consult each symbol's inventory entry before depending on it. |
| Sample routing, visible-control focus sets, responsive layout, and modal focus restoration | Application composition required | Application code | Covered by `dataSampleNavigationPreservesFocusAndValuesAcrossResponsiveSizes` and `dataGallerySupportsKeyboardAndMouseSelection`. |
| Remaining gallery scope in tracking issue #16 | Planned | Varies; inventory is authoritative | Later issue batches add coverage without changing the library's API tier by demonstration alone. |
| Native captures on other terminals and Windows/macOS | Unverified | N/A | Not established by B00; see capture record below. |

### Capture evidence

The [B00 capture manifest](../examples/workbench/screenshots/b00-capture-manifest.json)
records the source revision and digest, responsive TestBackend sizes, observed
80×24 PTY size, and capture outcome. No B00 PNG is published: the native capture
attempt did not expose the Workbench surface, and isolated headless compositor
startup did not become ready.

Historical PNGs without source-bound provenance are excluded from B00 and are
not used as evidence; no metadata has been backfilled.

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
