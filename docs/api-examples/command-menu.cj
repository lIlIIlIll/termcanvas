package cjtui_api_example

import core.*

main(): Int64 {
    let items = [MenuItem("Build", action: "build"), MenuItem("Disabled", enabled: false)]
    let menu = Menu("Tasks", items)
    let buffer = Buffer(Rect(0, 0, 40, 12))
    menu.render(Rect(0, 0, 20, 4), buffer)
    if (menu.handle(KeyEvent(KeyCode.Enter)) != Some("build")) { throw IllegalStateException("menu action failed") }
    _ = menu.handle(KeyEvent(KeyCode.Down))
    if (menu.handle(KeyEvent(KeyCode.Enter)).isSome()) { throw IllegalStateException("disabled action triggered") }
    let bar = MenuBar(["File", "Tasks"])
    _ = bar.handle(KeyEvent(KeyCode.Right))
    if (bar.selected != 1) { throw IllegalStateException("menu bar navigation failed") }
    let palette = CommandPalette(items, caseSensitive: false)
    palette.paste("BUILD")
    if (palette.handle(KeyEvent(KeyCode.Enter)) != Some("build")) { throw IllegalStateException("palette filter failed") }
    return 0
}
