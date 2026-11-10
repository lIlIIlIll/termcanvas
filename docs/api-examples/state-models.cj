package cjtui_api_example

import core.*

main(): Int64 {
    let single = SelectionModel(mode: SelectionMode.Single)
    single.select(1)
    single.toggle(2)
    if (!single.isSelected(2) || single.selectedIndices().size != 1 || single.current.getOrThrow() != 2 ||
        single.move(1, 5).getOrThrow() != 3) { throw IllegalStateException("single selection failed") }
    let multiple = SelectionModel(mode: SelectionMode.Multiple)
    multiple.select(1)
    multiple.toggle(2)
    if (!multiple.isSelected(1) || !multiple.isSelected(2)) { throw IllegalStateException("multiple selection failed") }
    multiple.clear()
    let disabled = SelectionModel(mode: SelectionMode.NoSelection)
    disabled.select(1)
    if (multiple.selectedIndices().size != 0 || disabled.isSelected(1)) { throw IllegalStateException("selection clear failed") }
    let scroll = ScrollState()
    scroll.scroll(2, 20, 5)
    scroll.scrollTo(4, 20, 5)
    scroll.ensureVisible(10, 20, 5)
    if (scroll.offset != 6 || !scroll.handle(KeyEvent(KeyCode.Down), 20, 5) || scroll.offset != 7) {
        throw IllegalStateException("scroll state failed")
    }
    let sort = SortState()
    sort.set(1)
    sort.toggle(1)
    if (sort.column.getOrThrow() != 1 || !sort.descending) { throw IllegalStateException("sort failed") }
    sort.clear()
    let filter = FilterState(query: "row")
    if (!filter.active || filter.query != "row" || !filter.matches("row-1") || filter.matches("item")) {
        throw IllegalStateException("filter failed")
    }
    filter.set("item")
    filter.clear()
    if (!sort.column.isNone() || filter.active || !filter.matches("anything")) { throw IllegalStateException("clear failed") }
    return 0
}
