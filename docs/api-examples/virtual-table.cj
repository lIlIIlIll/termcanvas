package cjtui_api_example

import core.*

main(): Int64 {
    let rows = [["Alpha", "2"], ["Beta", "1"]]
    let table = VirtualTable([TableColumn("Name"), TableColumn("Count")], rows.size, { i => rows[i] })
    let area = Rect(0, 0, 30, 5)
    let buffer = Buffer(area)
    table.render(area, buffer)
    if (table.cachedRowCount() != 2) { throw IllegalStateException("table cache failed") }
    _ = table.handle(KeyEvent(KeyCode.Home), 4)
    table.toggleSelectedRow()
    if (!table.isSelected(0) || table.selectedRowIndices().size != 1) { throw IllegalStateException("table selection failed") }
    table.sortBy(0, descending: true)
    if (table.sortColumn != Some(0) || !table.sortDescending) { throw IllegalStateException("table sort failed") }
    table.setFilter("Beta")
    table.render(area, buffer)
    if (table.filterText != "Beta" || !table.resizeColumn(0, 12)) { throw IllegalStateException("table filter failed") }
    table.clearSort()
    table.clearCachedRows()
    if (table.cachedRowCount() != 0) { throw IllegalStateException("table cache invalidation failed") }
    return 0
}
