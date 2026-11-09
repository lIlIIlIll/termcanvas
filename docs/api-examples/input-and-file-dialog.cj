package cjtui_api_example

import core.*

main(): Int64 {
    let input = Input(value: "hi", cursor: 2, style: Style(), placeholder: "Name", showBoundary: true)
    input.setVisualState(focused: true, disabled: false, error: false, theme: Theme.graphite())
    input.paste("!")
    if (input.value != "hi!" || input.cursor != 3 || !input.handle(KeyEvent(KeyCode.Left))) {
        throw IllegalStateException("input editing failed")
    }
    let area = Rect(0, 0, 20, 1)
    if (input.handleWithDirty(KeyEvent(KeyCode.Right), area).isNone() ||
        input.handleWithDirty(KeyEvent(KeyCode.Left), area, layoutTheme: Theme.graphite()).isNone()) {
        throw IllegalStateException("input dirty region failed")
    }
    let outside = MouseEvent(MouseKind.Move, MouseButton.None, 30, 30)
    if (input.handleMouse(outside, area) || input.handleMouse(outside, area, layoutTheme: Theme.graphite())) {
        throw IllegalStateException("outside mouse event was handled")
    }
    let buffer = Buffer(Rect(0, 0, 20, 5))
    input.render(area, buffer)
    _ = input.cursorPosition(area)
    _ = input.cursorPosition(area, layoutTheme: Theme.graphite())
    _ = input.cursorPosition(area, options: TextWidthOptions(), layoutTheme: Theme.graphite())
    input.setValue("ok")
    input.moveToStart()
    if (input.cursor != 0) { throw IllegalStateException("move to start failed") }
    input.moveToEnd()
    if (input.cursor != 2) { throw IllegalStateException("move to end failed") }
    input.clear()
    if (input.value != "") { throw IllegalStateException("input clear failed") }
    let dialog = FileDialog(path: ".", extension: ".cj", title: "Files")
    _ = dialog.picker
    _ = dialog.selectedPath()
    _ = dialog.handle(KeyEvent(KeyCode.Down), 3)
    dialog.render(Rect(0, 1, 20, 4), buffer)
    return 0
}
