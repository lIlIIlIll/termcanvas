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
- `SegmentedControl` (EXPERIMENTAL): one-line selected-value presentation with
  bounded keyboard navigation and visible-text mouse selection.
- `StatusBar`: left/right status text with an optional progress slot.
- `StatusBarProgress`: compact progress state used by `StatusBar`.
- `Viewport`: bounded content viewport and scrolling surface.

### Inputs and forms

- `Input`: single-line editable value and cursor.
- `TextArea`: multiline editing, selection, scrolling, folds, decorations, and
  completion.
- `Button`: action-oriented button presentation.
- `Checkbox`: boolean choice.
- `Switch`: EXPERIMENTAL boolean choice; Space/Enter or a left-button Down on its first visible row toggles the state.
- `RadioGroup`: one choice from a group.
- `Select`, `Dropdown`, `MultiSelect`: one or many selectable values. `Dropdown` can opt into transactional preview/commit; legacy behavior remains the default.
- `DatePicker` (EXPERIMENTAL): displays `year-MM-DD`; Left/Right adjust days,
  Up/Down months, and PageUp/PageDown years with saturation and day clamping.
  Supported key operations normalize its public date fields; callers assigning
  fields directly must keep them valid. Cyan remains the default; use Theme
  roles with `style: Style.default()` and `theme`, or via `setVisualState`.
  No calendar grid, parser, locale/timezone, date range, or DatePicker mouse-field editing.
- `ColorPicker` (EXPERIMENTAL): preserves its candidate palette and
  `selected`/`selectedColor()` contract; Left/Right clamp, Home/End select the
  endpoints. Empty palettes return no selection, draw nothing, and reject
  input. Supported keys and rendering normalize direct invalid indices. Narrow
  areas keep the selected swatch visible; mouse hits only visible two-cell
  swatches, never gaps, partial swatches, releases, or outside cells. Selected
  non-Reset swatches use black foreground only when
  `2126*r + 7152*g + 722*b > 1,400,000`, otherwise white; Reset uses
  `theme.normal.fg` or Reset. Focus adds bold and underline; disabled state
  rejects keyboard and mouse input. Palette adaptation remains application-owned.
  `setVisualState` is EXPERIMENTAL.

### Commands and overlays

- `MenuBar`: horizontal menu navigation.
- `Menu`: selectable items that return optional action strings.
- `CommandPalette`: substring search across labels and actions, case-sensitive
  by default; `caseSensitive: false` uses Unicode lowercase matching. `paste(text)`
  appends and synchronizes selection/offset; `setTheme` enables semantic roles.
  Explicit selected styles remain authoritative; disabled items use
  `disabledStyle`; missing results show `No matches` and cannot activate.
  Without a theme, the default disabled style uses indexed color 8.
- `ToastManager`: theme-aware semantic notifications; it preserves `kind=None`
  styles, draws stable markers, and can cap the queue while retaining newest
  rows. `tick()` advances positive TTL values in tick-count units.
- `Badge` (EXPERIMENTAL): display-only `[label]`; resolves the normal Theme role
  and styles visible text cells only.
- `Spinner`: lightweight progress animation.
- `Dialog`: centered buttons with optional semantic themes. No-theme rendering
  remains unchanged; explicit selected styles win, and public selection is
  clamped before input or rendering.
- `ConfirmDialog`: No/Yes confirmation; Enter starts on No, Left/Right select,
  and left-button-down on a rendered label returns its boolean result.
- `RequestDialog` / `DecisionDialog`: request workflows with optional Dialog
  styles and themes; risk text and document-detail composition remain separate.

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
- `TaskActivityView` (EXPERIMENTAL): one compact or expanded task with status,
  elapsed text, details, and individual or count-based subtask progress.
- `TaskActivityList` (EXPERIMENTAL): mixed compact and expanded tasks with
  task-index scrolling and an indicator for hidden or partially visible tasks.

### Show task activity

Create `TaskActivity` values from application state and pass them to a
`TaskActivityList`. The following app displays a compact completed task and an
expanded running task, alongside a progress bar, a trend, and a tree. Press
`a` to force ASCII with eight colors, `u` to restore detected capabilities,
and `q` or Ctrl-C to exit:

```cangjie
import core.*

main(): Int64 {
    let theme = Theme.graphite().withIconSet(IconSet.Unicode)
    let done = TaskActivity("Checkout", status: TaskStatus.Done, duration: "2s")
    let build = TaskActivity("Build", status: TaskStatus.Running, id: "job-1",
        duration: "12s", progressLabel: "Jobs", detail: "Compiling source",
        progress: Some(TaskProgress.Items([TaskStatus.Done, TaskStatus.Running, TaskStatus.Pending])))
    let entries = [TaskActivityListEntry(done, layout: TaskActivityLayout.Compact),
        TaskActivityListEntry(build)]
    let tree = Tree([TreeNode("root", "project", expanded: true,
        children: [TreeNode("src", "src")])], focused: true, theme: Some(theme))
    App().runWithCommands(
        { frame =>
            let area = frame.area
            frame.fill(area, theme.canvas)
            frame.renderWidget(TaskActivityList(entries, theme: theme), Rect(area.x, area.y, area.width, 4))
            frame.renderWidget(ProgressBar(2, total: 3, labelMode: ProgressBarLabelMode.Percent),
                Rect(area.x, area.y + 5, area.width, 1))
            frame.renderWidget(Sparkline([1, 2, 3, 2, 4]), Rect(area.x, area.y + 7, area.width, 1))
            frame.renderWidget(tree, Rect(area.x, area.y + 9, area.width, 3))
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) => match (key.code) {
                    case KeyCode.Char(r'q') | KeyCode.CtrlC => UpdateResult.exit()
                    case KeyCode.Char(r'a') => UpdateResult.withCommand(Command.SetCapabilitiesOverride(
                        Some(TerminalCapabilities(unicode: false, trueColor: false, colorLevel: 8))))
                    case KeyCode.Char(r'u') => UpdateResult.withCommand(Command.SetCapabilitiesOverride(
                        Option<TerminalCapabilities>.None))
                    case _ => UpdateResult.next()
                }
                case _ => UpdateResult.next()
            }
        }
    )
    0
}
```

The first task occupies one line. The second task displays its title, a `Jobs`
line, and a detail line. Use `TaskProgress.Counts(completed, total)` for aggregate progress;
counts are clamped to `0 <= completed <= total` and negative totals become
zero. `Items` copies its array when `TaskActivity` is created. The component
draws only the progress marks that fit its area.

`TaskActivityList` uses `offset` as a task index. Set `layout` on each entry to
mix compact and expanded tasks, and pass a new `activityFrame` on each tick to
animate running tasks. The application owns the task data, offset, and timer.
The list displays the number of hidden or partially visible tasks when space
allows. `TaskActivityView` renders one task; its expanded layout hides the
right-aligned duration if the area is too narrow. Both widgets accept a `Theme`
and an optional `unicode` override.
The [`ci_activity`](../examples/ci_activity/) example demonstrates both progress
forms and the tick/update loop.

### Migrate existing widget layouts

- Default `Block` borders now use rounded Unicode lines when Unicode is
  available and ASCII otherwise. Use `BlockOptions.borderKind`, `border`, or
  `asciiFallback` to select a specific appearance. An `Input` without a block
  now draws `[` and `]`; pass `showBoundary: false` to omit them.
- Default selection and focus styles have changed. `List`,
  `Table`, and `Tree` have a separate selection marker; selected tree rows use
  the full row width. Provide `selectedStyle` and, where available,
  `selectionMarker` or `focusedStyle` to preserve a custom appearance. Review
  layouts and mouse coordinates that assumed the old tree indentation.
- `ProgressBar` and `Sparkline` choose their default symbols from terminal
  capabilities. Percentage labels, when enabled, appear outside the progress
  track. `Sparkline` now shows the latest fitting samples and scales to their
  visible maximum by default. Pass explicit symbols or `latest: false` to
  choose the older presentation. The optional `unicode` argument on task
  widgets overrides automatic icon selection; `unicode: true` selects Unicode
  rather than the theme's Nerd Font icons.
- Expanded `TaskActivityView` and `TaskActivityList` align durations within a
  preferred header width of 88 columns. The width grows when needed to fit a
  title and duration. Pass `maxHeaderWidth: 0` to align against the full
  available width.

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

`Chart` draws bottom-up bars for a sample series. `maxValue <= 0` keeps the
automatic maximum; a positive `maxValue` fixes the upper scale and saturates
higher samples. Zero and negative samples retain the one-cell minimum.
`Sparkline` uses Unicode levels when supported and ASCII levels (` `, `.`, `-`,
`=`, `#`) otherwise. It displays the latest samples that fit and scales them
to their visible maximum. Set `maxValue` to a positive value for a fixed scale,
`latest: false` to show the earliest samples, or `symbols` to supply custom
levels. An optional `Block` draws first; empty data can still show the block.
These options are EXPERIMENTAL. Use `Gauge` for one value against a total.

`ProgressBar` chooses its track symbols from terminal capabilities. Its label
is hidden by default; `labelMode: ProgressBarLabelMode.Percent` shows a
two-decimal percentage outside the track. A nonzero value below 0.01% displays
`<0.01%`, and a nonzero value smaller than one track cell still receives a
visible mark. Narrow areas replace a label that does not fit with an ellipsis.
Pass `ProgressBarSymbols` to supply your own track characters.

### Shared visual states

`Theme()` uses the terminal's foreground and background for its normal and
canvas styles. It supplies semantic `normal`, `focused`, `selected`, `disabled`,
`error`, `accent`, `success`, `warning`, and `info` styles, plus `canvas`,
`surface`, `raisedSurface`, `heading`, `secondary`, `border`, and
`strongBorder` roles. `Theme.graphite()` and `Theme.light()` provide dark and
light palettes. Use `Theme.light(accent: Color.Red)` to choose an accent; an
explicit accent is preserved.

`Theme.withIconSet(IconSet.Unicode)`, `IconSet.Ascii`, and `IconSet.NerdFont`
select the icon set used by participating widgets. Nerd Font is opt-in and
requires a compatible terminal font. Default `Block` borders and the progress
and trend symbols choose Unicode or ASCII from terminal capabilities. Explicit
progress and trend symbols take precedence. For `Block`, `asciiFallback: true`
overrides a custom border.

`Theme.serialize()` appends the new visual roles and icon set after the existing
role entries. Consumers that parse this text should allow the additional lines.

The runtime passes terminal capabilities to widget rendering and adapts output
colors to the detected color tier. `Command.SetCapabilitiesOverride(Some(caps))`
replaces those capabilities and requests a full redraw; pass
`Option<TerminalCapabilities>.None` to restore detection. Use
`theme.adapted(caps)` when you need a separately adapted theme value. Adapt the
original theme again when capabilities change, because downgraded colors and
icon sets cannot recover their original values.

`Tabs.setTheme(theme: ?Theme)` is EXPERIMENTAL. The default selected style uses
the theme's selected role when a theme is set. A custom `selectedStyle` takes
precedence. Passing `None` clears the theme. A focused selected tab adds bold
and underline.

`SegmentedControl` is EXPERIMENTAL. It draws the selected value as `[value]`,
other values as ` value `, and adds one non-hit separator cell between segments.
Left/Right clamp at the ends; Home/End select the first/last value.
`selectedValue()` normalizes the public index and returns `None` for an empty
list; empty controls render blank and reject input. `setVisualState` applies
normal/selected/disabled Theme roles when `selectedStyle` is `Style.default()`;
focus adds bold and underline to the selected segment, and disabled controls
ignore input. Narrow rendering keeps the selected segment visible without
splitting wide glyphs; mouse hits only visible segment text, never the separator.

`Button` fills its assigned cell rectangle, centers its label, and resolves
disabled and focused styles through its existing style parameters and optional
theme. Workbench maps `Primary` to `accentButtonStyle`, `Secondary` to
`surfaceStyle`, `Ghost` to `theme.normal`, and `Danger` to `theme.error`. Each
variant uses `theme.focused` as `focusedStyle`, `theme.disabled` as
`disabledStyle`, and `theme` for semantic state resolution. The Disabled row
sets `disabled`; these are style choices, not separate widget classes or an
enum.

`Switch` is EXPERIMENTAL. It renders as `label [off]` or `label [on]`, with only
the bracketed state for an empty label. Space or Enter toggles; a left-button
Down on the first visible row toggles once. `setVisualState` selects normal,
focused, or disabled Theme roles; disabled state rejects input.

The EXPERIMENTAL `Input.setVisualState(focused: Bool = false, disabled: Bool = false,
error: Bool = false, theme: ?Theme = None)` method configures the visual and
interactive state without changing its editing model. Resolution precedence is
disabled, error, focused, then normal. Disabled inputs ignore keyboard, mouse,
and paste editing. `Input.paste(text)` is EXPERIMENTAL. For nonempty text on an
enabled input, it clamps the cursor to the text bounds and moves any mid-rune
offset backward to a UTF-8 rune boundary, inserts text without normalization,
and advances the byte-offset cursor. Empty text and disabled inputs leave
`value` and `cursor` unchanged. Applications retain control of paste
normalization and event routing.

The default placeholder color uses the theme's muted `disabled` foreground and
the input's resolved background; without a theme it keeps the indexed-gray
fallback. A non-default `placeholderStyle` overrides that derived color.

The stable `Tabs.setFocused(focused: Bool)` method lets the application report
real focus. A focused selected tab adds a bold underline; selection remains
independent of focus. `Block` already supports rounded or absent borders,
background/content styles, padding, focus state, and ASCII border fallback.

These additions extend existing stable widgets; exact signatures are maintained
in the generated stable API contract.

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
helpers. The selected marker is separate from the disclosure marker, and the
selected style covers the full row. Use `setFocused` to report keyboard focus;
`selectedStyle` and `focusedStyle` override the theme styles. The same
presentation applies to a tree backed by `LazyTreeModel`. `FilePicker` exposes
selected paths, parent navigation, directory entry, search text, hidden-file
toggling, directory-first sorting, selected metadata, and extension filtering
that keeps directories visible.

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
`App.runWithCommands()`.

`Toast` retains the legacy `Toast(message, ttl:, style:)` constructor, its
black/yellow default, and unmarked `kind=None` rendering. Semantic notices use
`Toast(message, kind: Some(ToastKind.Success))`; the stored message remains
unchanged. A themed manager renders `+`, `!`, `x`, or `i`, then patches the
matching Theme role with the toast's explicit style. Without a theme, semantic
notices use the black/yellow base; `kind=None` always uses stored style.
`setTheme` updates existing notices. `maxToasts: None` is unbounded; `Some(n)` clamps at
zero and evicts oldest notices. Notices with `ttl <= 0` are ignored; each
`tick()` reduces remaining TTL by one tick. The manager fills each displayed
row, truncates messages to width, and renders only the latest visible rows.
Call `ToastManager.tick()` from the application's `Event.Tick(TickEvent)`
handling when notifications should age.

The exact stability tier of each declaration is defined by
[`api-inventory.json`](api-inventory.json), not by this page or by its package
name. See [`api.md`](api.md) for the human map and [`extensions.md`](extensions.md)
for document and specialized packages.
