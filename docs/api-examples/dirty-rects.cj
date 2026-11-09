package cjtui_api_example

import core.*

main(): Int64 {
    let dirty = DirtyRects([Rect(0, 0, 2, 2)])
    dirty.add(Rect(2, 0, 2, 2))
    dirty.addAll([Rect(8, 0, 1, 1)])
    let more = DirtyRects.full(Rect(10, 0, 1, 1))
    dirty.addAll(more)
    if (dirty.isEmpty() || !dirty.covers(Rect(0, 0, 4, 2)) ||
        !dirty.intersects(Rect(1, 1, 2, 2)) || !dirty.intersectsRect(8, 0, 1, 1) ||
        !dirty.intersectsCell(10, 0) || dirty.cellCount() != 10 || dirty.rects().size != 3) {
        throw IllegalStateException("incorrect dirty regions")
    }
    let copy = dirty.copy()
    dirty.clear()
    if (!dirty.isEmpty() || copy.isEmpty() || DirtyRects().cellCount() != 0) {
        throw IllegalStateException("incorrect dirty region copy")
    }
    return 0
}
