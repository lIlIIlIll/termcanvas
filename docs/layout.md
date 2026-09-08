# Layout

## Reader task

Use layout helpers to derive widget areas from the current `Frame.area`. Layout
is presentation data: the application owns the values that determine which
panels are visible, while `Layout` computes `Rect` values during rendering. It
does not own application state, events, or widget lifecycles.

For the stable path, split the frame and render immediate widgets in the
resulting rectangles:

```cj
func render(frame: Frame): Unit {
    let panels = Layout.horizontal([
        Constraint.Length(24),
        Constraint.Min(0)
    ]).withGap(1).withMargin(Spacing.all(1)).split(frame.area)
    frame.renderWidget(Paragraph("navigation"), panels[0])
    frame.renderWidget(Paragraph("content"), panels[1])
}
```

`Layout.horizontal()` and `Layout.vertical()` take an array of constraints and
return child rectangles from `split(area)`. Margins and gaps are applied before
size normalization, so returned rectangles do not exceed the input area. A
zero-constraint layout returns no rectangles.

## Constraints

- `Constraint.Length(n)`: allocate a fixed size, clamped to available space.
- `Constraint.Percent(n)`: allocate a percentage of the available axis.
- `Constraint.Min(n)`: share remaining space while respecting a minimum.
- `Constraint.Max(n)`: share remaining space up to a maximum.
- `Constraint.Ratio(n, d)`: allocate a proportional share; non-positive
  numerators or denominators produce zero for that item.

A layout's direction is `Direction.Horizontal` or `Direction.Vertical`.
`Layout.horizontal(constraints)` and `Layout.vertical(constraints)` are the
named constructors; `Layout(direction: ..., constraints: ...)` is the explicit
form when direction is computed.

## Spacing and flex positioning

The builder methods return a new layout value:

- `withGap(n)` inserts fixed spacing between chunks.
- `withMargin(Spacing.all(n))` or `withMargin(Spacing.symmetric(horizontal: ..., vertical: ...))`
  shrinks the input area before splitting.
- `withFlex(Flex.Start)`, `Flex.Center`, `Flex.End`, or `Flex.SpaceBetween`
  positions chunks when their sizes do not consume the complete axis.

`Spacing` also has `Spacing.zero()`. Negative spacing and gaps are normalized to
non-negative values. `Flex.SpaceBetween` distributes remaining space between
chunks in addition to the configured gap.

## Two-dimensional and grow-based layout

`Grid(rows: ..., columns: ..., gap: ..., margin: ...)` first splits rows and
then splits every row into columns. `split(area)` returns an array of row arrays;
all cell rectangles are derived from the same input area.

`FlexLayout(direction: ..., items: ..., gap: ...)` is a lightweight grow-based
alternative. Each `FlexItem(basis: ..., grow: ..., shrink: ...)` describes a
preferred basis and growth weight. Extra available space is distributed by
`grow`; the current implementation uses basis and growth for the split, while
`shrink` remains part of the public item shape for callers that model flexible
content.

## Preferred sizes and reuse

`SizeHint` is a small preferred-size value with minimum, preferred, and maximum
width/height. A custom widget or layout container can implement `Sizable` and
return `sizeHint()`; the protocol does not replace explicit `Rect` allocation.

`LayoutCache` stores the last result for one `Rect` area:

```cj
let cache = LayoutCache()
let columns = cache.get(frame.area, { area =>
    Layout.horizontal([Constraint.Percent(30), Constraint.Min(0)]).split(area)
})
// Invalidate when application-owned inputs other than area change.
cache.invalidate()
```

Use a cache only when the computation is worth retaining. The cache invalidates
explicitly when application state changes; a changed area automatically causes a
new computation.

## Boundary and related pages

Layout computes presentation rectangles after `App` update has applied an
`Event` or command result. It does not dispatch input or mutate canonical state.
See [`architecture.md`](architecture.md) for the complete state → update →
render path, [`widgets.md`](widgets.md) for widget selection, and
[`events.md`](events.md) for input ownership.
