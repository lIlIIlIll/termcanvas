package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 20, 3)
    let buffer = Buffer(area)
    let click = MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0)
    let radios = RadioGroup(["Small", "Large"])
    radios.render(area, buffer)
    if (!radios.handle(KeyEvent(KeyCode.Down)) || radios.selected != 1 ||
        !radios.handleMouse(click, area) || radios.selected != 0 ||
        !radios.handleMouse(click, area, layoutTheme: Option<Theme>.None)) {
        throw IllegalStateException("radio selection failed")
    }
    let select = Select(["Alpha", "Beta"])
    select.render(area, buffer)
    select.handle(KeyEvent(KeyCode.Down))
    if (select.selectedValue().getOrThrow() != "Beta" ||
        select.handle(KeyEvent(KeyCode.Enter)).getOrThrow() != "Beta" ||
        select.handleMouse(click, area).getOrThrow() != "Alpha" ||
        select.handleMouse(click, area, layoutTheme: Option<Theme>.None).getOrThrow() != "Alpha") {
        throw IllegalStateException("list selection failed")
    }
    return 0
}
