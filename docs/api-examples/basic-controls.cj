package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 20, 1)
    let buffer = Buffer(area)
    let click = MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0)
    let button = Button("Save", focused: true)
    button.setGhost(true)
    button.render(area, buffer)
    if (!button.handle(KeyEvent(KeyCode.Enter)) || !button.handleMouse(click, area) ||
        !button.handleMouse(click, area, layoutTheme: Option<Theme>.None)) { throw IllegalStateException("button failed") }
    let checkbox = Checkbox("Remember")
    if (!checkbox.handle(KeyEvent(KeyCode.Char(r' '))) || !checkbox.checked ||
        !checkbox.handleMouse(click, area) || checkbox.checked) { throw IllegalStateException("checkbox failed") }
    checkbox.render(area, buffer)
    let toggle = Switch("Network")
    if (!toggle.handle(KeyEvent(KeyCode.Enter)) || !toggle.checked || !toggle.handleMouse(click, area) || toggle.checked) {
        throw IllegalStateException("switch failed")
    }
    toggle.setVisualState(disabled: true)
    if (toggle.handle(KeyEvent(KeyCode.Enter))) { throw IllegalStateException("disabled switch accepted input") }
    toggle.render(area, buffer)
    return 0
}
