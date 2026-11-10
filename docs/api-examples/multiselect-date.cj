package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 24, 3)
    let buffer = Buffer(area)
    let multi = MultiSelect(["Build", "Test", "Deploy"], selected: [0])
    multi.handle(KeyEvent(KeyCode.Down))
    multi.toggle()
    if (multi.cursor != 1 || multi.selectedIndices().size != 2) { throw IllegalStateException("multi select failed") }
    multi.render(area, buffer)
    if (!multi.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area) ||
        multi.selectedIndices().size != 1) { throw IllegalStateException("mouse toggle failed") }
    let date = DatePicker(year: 2024, month: 2, day: 29)
    date.setVisualState(focused: true)
    if (!date.handle(KeyEvent(KeyCode.PageUp)) || date.year != 2025 || date.month != 2 || date.day != 28 ||
        date.value() != "2025-02-28") { throw IllegalStateException("date adjustment failed") }
    date.render(area, buffer)
    return 0
}
