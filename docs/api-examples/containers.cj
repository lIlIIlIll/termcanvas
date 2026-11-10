package cjtui_api_example

import core.*

main(): Int64 {
    let buffer = Buffer(Rect(0, 0, 20, 8))
    VBox([Paragraph("top"), Paragraph("bottom")], gap: 1).render(Rect(0, 0, 10, 5), buffer)
    HBox([Paragraph("L"), Paragraph("R")], gap: 1).render(Rect(0, 5, 7, 1), buffer)
    if (buffer.getCell(0, 0).symbol != "t" || buffer.getCell(0, 3).symbol != "b" ||
        buffer.getCell(4, 5).symbol != "R") { throw IllegalStateException("box layout failed") }
    let layers = Buffer(Rect(0, 0, 12, 4))
    Stack([Paragraph("bottom"), Paragraph("top")]).render(layers.area, layers)
    Overlay(Paragraph("base"), overlays: [Paragraph("overlay")]).render(Rect(0, 1, 12, 1), layers)
    Padding(Paragraph("pad"), Spacing.all(1)).render(Rect(0, 1, 10, 3), layers)
    Margin(Paragraph("margin"), Spacing.all(1)).render(Rect(5, 1, 7, 3), layers)
    if (layers.getCell(0, 0).symbol != "t" || layers.getCell(0, 1).symbol != "o" ||
        layers.getCell(1, 2).symbol != "p" || layers.getCell(6, 2).symbol != "m") {
        throw IllegalStateException("container layers failed")
    }
    let centered = Buffer(Rect(0, 0, 10, 3))
    Centered(Paragraph("center"), 6, 1).render(centered.area, centered)
    let docked = Buffer(Rect(0, 0, 20, 6))
    Dock(top: Some(Paragraph("T")), bottom: Some(Paragraph("B")), left: Some(Paragraph("L")),
        right: Some(Paragraph("R")), center: Some(Paragraph("C")), leftWidth: 2, rightWidth: 2)
        .render(docked.area, docked)
    if (centered.getCell(2, 1).symbol != "c" || docked.getCell(0, 0).symbol != "T" ||
        docked.getCell(0, 5).symbol != "B" || docked.getCell(0, 1).symbol != "L" ||
        docked.getCell(18, 1).symbol != "R" || docked.getCell(2, 1).symbol != "C") {
        throw IllegalStateException("center or dock failed")
    }
    let state = ScrollState()
    let scroll = Scrollable(["zero", "one", "two"], state: state)
    if (!scroll.handle(KeyEvent(KeyCode.Down), 2) || state.offset != 1 ||
        scroll.handleMouse(MouseEvent(MouseKind.Move, MouseButton.None, 30, 30), Rect(0, 0, 8, 2), PointerCapture(), "list")) {
        throw IllegalStateException("scroll input failed")
    }
    let output = Buffer(Rect(0, 0, 8, 2))
    scroll.render(output.area, output)
    if (output.getCell(0, 0).symbol != "o") { throw IllegalStateException("scroll rendering failed") }
    return 0
}
