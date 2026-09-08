# Layout

`Layout.horizontal()` and `Layout.vertical()` split a `Rect` into child `Rect` values.

Constraints:

- `Constraint.Length(n)`: fixed size.
- `Constraint.Percent(n)`: percentage of available space.
- `Constraint.Min(n)`: consumes remaining space while respecting a minimum.
- `Constraint.Max(n)`: consumes remaining space up to a maximum.
- `Constraint.Ratio(n, d)`: proportional size based on the available space.

Spacing:

- `withGap(n)` inserts fixed spacing between chunks.
- `withMargin(Spacing.all(n))` or `Spacing.symmetric()` shrinks the input area before splitting.
- `withFlex(Flex.Center)`, `Flex.End`, or `Flex.SpaceBetween` positions chunks when they do not consume the full axis.

Margins and gaps are applied before size normalization, so child rectangles never exceed the input area.

`Grid` splits an area into row and column constraints and returns a two-dimensional array of cells.

`FlexLayout` uses `FlexItem(basis, grow, shrink)` values for lightweight grow-based splitting.

`LayoutCache` stores the last computed layout for an area and can be invalidated when app state changes.

`SizeHint` and `Sizable` provide a minimal preferred-size protocol for custom widgets and layout containers.
