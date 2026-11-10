package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 20, 4)
    let buffer = Buffer(area)
    let dropdown = Dropdown(["Alpha", "Beta"])
    dropdown.setVisualState(focused: true)
    dropdown.setTransactionalSelection(enabled: true)
    dropdown.handle(KeyEvent(KeyCode.Enter))
    dropdown.handle(KeyEvent(KeyCode.Down))
    dropdown.cancelSelection()
    if (dropdown.open || dropdown.selectedValue().getOrThrow() != "Alpha") { throw IllegalStateException("cancel failed") }
    dropdown.handle(KeyEvent(KeyCode.Enter))
    dropdown.handle(KeyEvent(KeyCode.Down))
    if (dropdown.handle(KeyEvent(KeyCode.Enter)).getOrThrow() != "Beta") { throw IllegalStateException("commit failed") }
    dropdown.render(area, buffer)
    dropdown.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area)
    if (!dropdown.open) { throw IllegalStateException("mouse open failed") }
    let picker = ColorPicker(colors: [Color.Red, Color.Blue])
    picker.setVisualState(focused: true)
    if (!picker.handle(KeyEvent(KeyCode.Right)) || picker.selected != 1 ||
        !picker.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area) || picker.selected != 0) {
        throw IllegalStateException("color selection failed")
    }
    match (picker.selectedColor()) {
        case Some(Color.Red) => ()
        case _ => throw IllegalStateException("color value failed")
    }
    picker.render(area, buffer)
    return 0
}
