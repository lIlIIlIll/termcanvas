package cjtui_api_example

import core.*

main(): Int64 {
    let progress = StatusBarProgress(25, total: 100, width: 10, label: "build", labelMode: ProgressBarLabelMode.Percent)
    if (progress.value != 25 || progress.total != 100 || progress.width != 10 || progress.label != "build") {
        throw IllegalStateException("progress configuration failed")
    }
    let area = Rect(0, 0, 40, 3)
    let buffer = Buffer(area)
    StatusBar(left: "Ready", right: "1 task", progress: Some(progress)).render(Rect(0, 0, 40, 1), buffer)
    if (buffer.getCell(0, 0).symbol != "R") { throw IllegalStateException("status bar failed") }
    let viewport = Viewport(["first", "second", "third"])
    if (!viewport.handle(KeyEvent(KeyCode.Down), 2) || viewport.offset != 1) { throw IllegalStateException("scroll failed") }
    viewport.scroll(-1, 2)
    viewport.render(Rect(0, 1, 40, 2), buffer)
    if (viewport.offset != 0 || buffer.getCell(0, 1).symbol != "f") { throw IllegalStateException("viewport failed") }
    return 0
}
