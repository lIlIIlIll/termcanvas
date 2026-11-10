package cjtui_api_example

import core.*

main(): Int64 {
    let focus = FocusManager()
    focus.add("name")
    focus.add("notes")
    focus.add("save", enabled: false)
    if (!focus.isFocused("name") || focus.next().getOrThrow() != "notes" ||
        focus.previous().getOrThrow() != "name") { throw IllegalStateException("focus navigation failed") }
    if (!focus.setEnabled("save", true) || !focus.focus("save") ||
        !focus.handle(KeyEvent(KeyCode.Tab)) || focus.current().getOrThrow() != "name") {
        throw IllegalStateException("focus update failed")
    }
    focus.remove("name")
    if (focus.current().getOrThrow() != "notes") { throw IllegalStateException("focus removal failed") }
    return 0
}
