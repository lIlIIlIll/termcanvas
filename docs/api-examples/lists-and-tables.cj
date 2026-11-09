package cjtui_api_example

import core.*

main(): Int64 {
    let listState = ListState(selected: 0, offset: 0)
    listState.next(3)
    listState.previous(3)
    listState.move(1, 3, viewportHeight: 2)
    let dirty = listState.moveWithDirty(1, 3, 2, Rect(0, 0, 10, 2))
    listState.scrollToVisible(3, 2)
    if (listState.selected.getOrThrow() != 2 || listState.offset != 1 || dirty.isEmpty()) {
        throw IllegalStateException("list state failed")
    }
    listState.select(0)
    let tableState = TableState(selectedRow: 0, offset: 0)
    tableState.next(3)
    tableState.previous(3)
    tableState.move(2, 3, viewportHeight: 2)
    tableState.scrollToVisible(3, 2)
    if (tableState.selectedRow.getOrThrow() != 2 || tableState.offset != 1) { throw IllegalStateException("table state failed") }
    tableState.select(0)
    let list = List(["one", "two", "three"], state: listState, selectionMarker: ">", focused: true)
    let table = Table(["Name"], [["one"], ["two"], ["three"]], widths: [8], state: tableState, selectionMarker: ">")
    let outside = MouseEvent(MouseKind.Move, MouseButton.None, 50, 50)
    let listArea = Rect(0, 0, 12, 3)
    let tableArea = Rect(0, 3, 12, 5)
    if (list.handleMouse(outside, listArea) || list.handleMouse(outside, listArea, layoutTheme: Theme.graphite()) ||
        table.handleMouse(outside, tableArea) || table.handleMouse(outside, tableArea, layoutTheme: Theme.graphite())) {
        throw IllegalStateException("outside mouse event was handled")
    }
    let buffer = Buffer(Rect(0, 0, 16, 8))
    list.render(listArea, buffer)
    table.render(tableArea, buffer)
    let scroll = ScrollState()
    let bar = Scrollbar(10, offset: 0, viewport: 3)
    if (bar.handleMouse(outside, Rect(12, 0, 1, 3), scroll, PointerCapture(), "scroll")) {
        throw IllegalStateException("outside scrollbar event was handled")
    }
    bar.render(Rect(12, 0, 1, 3), buffer)
    if (buffer.getCell(2, 3).symbol != "N") { throw IllegalStateException("table did not render") }
    return 0
}
