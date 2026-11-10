package cjtui_api_example

import core.*

class Panel <: Sizable {
    public func sizeHint(): SizeHint {
        SizeHint(minWidth: 2, minHeight: 1, preferredWidth: 4, preferredHeight: 2,
            maxWidth: 8, maxHeight: 4)
    }
}

main(): Int64 {
    let hint = Panel().sizeHint()
    if (hint.minWidth != 2 || hint.minHeight != 1 || hint.preferredWidth != 4 ||
        hint.preferredHeight != 2 || hint.maxWidth != 8 || hint.maxHeight != 4) {
        throw IllegalStateException("incorrect size hint")
    }
    let item = FlexItem.fromSizeHint(hint, Direction.Horizontal, grow: 2, shrink: 1)
    let vertical = FlexItem.fromSizeHint(hint, Direction.Vertical)
    if (item.basis != 4 || item.minSize != 2 || item.maxSize != 8 || item.grow != 2 ||
        item.shrink != 1 || vertical.basis != 2 || vertical.minSize != 1 || vertical.maxSize != 4) {
        throw IllegalStateException("incorrect flex item")
    }
    let area = Rect(0, 0, 12, 4)
    let grid = Grid([Constraint.Length(2), Constraint.Min(0)],
        [Constraint.Length(4), Constraint.Min(0)], gap: 1, margin: Spacing.zero())
    let cells = grid.split(area)
    if (cells.size != 2 || cells[0].size != 2 || cells[0][0] != Rect(0, 0, 4, 2)) {
        throw IllegalStateException("incorrect grid")
    }
    let layout = FlexLayout(Direction.Horizontal, [item, FlexItem(basis: 2, grow: 1)], gap: 1)
    let result = layout.resolve(area)
    if (!result.constraintsSatisfied || result.effectiveGap != 1 || result.rects.size != 2 ||
        result.rects[0].width + result.rects[1].width != 11 || layout.split(area).size != 2) {
        throw IllegalStateException("incorrect flex layout")
    }
    let manual = FlexLayoutResult([area], true, 0)
    let cache = LayoutCache()
    if (!manual.constraintsSatisfied || cache.get(area, { r => [r] })[0] != area) {
        throw IllegalStateException("incorrect layout cache")
    }
    cache.invalidate()
    if (cache.get(area, { r => [Rect(r.x, r.y, 1, 1)] })[0].width != 1) {
        throw IllegalStateException("cache was not invalidated")
    }
    return 0
}
