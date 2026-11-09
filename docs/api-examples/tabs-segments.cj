package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 30, 1)
    let buffer = Buffer(area)
    let tabs = Tabs(["Overview", "Tasks"], selected: 0)
    tabs.setFocused(true)
    tabs.setTheme(Option<Theme>.None)
    if (!tabs.handle(KeyEvent(KeyCode.Right)) || tabs.selected != 1) { throw IllegalStateException("tab navigation failed") }
    tabs.render(area, buffer)
    if (!tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0), area) || tabs.selected != 0) {
        throw IllegalStateException("tab hit testing failed")
    }
    let segments = SegmentedControl(["Day", "Week"], selected: 0)
    if (!segments.handle(KeyEvent(KeyCode.End)) || segments.selectedValue().getOrThrow() != "Week") {
        throw IllegalStateException("segment navigation failed")
    }
    segments.setVisualState(focused: true)
    segments.render(area, buffer)
    if (!segments.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0), area) || segments.selected != 0) {
        throw IllegalStateException("segment hit testing failed")
    }
    segments.setVisualState(disabled: true)
    if (segments.handle(KeyEvent(KeyCode.Right))) { throw IllegalStateException("disabled segment accepted input") }
    return 0
}
