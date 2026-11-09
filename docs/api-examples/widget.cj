package cjtui_api_example

import core.*

main(): Int64 {
    let buffer = Buffer(Rect(0, 0, 8, 3))
    let first: Widget = Paragraph("first", wrap: WrapMode.NoWrap, align: TextAlign.Left)
    let second: Widget = Paragraph("mid", wrap: WrapMode.Word, align: TextAlign.Center)
    let third: Widget = Paragraph("end", wrap: WrapMode.Character, align: TextAlign.Right)
    first.render(Rect(0, 0, 8, 1), buffer)
    StyledWidget(second, override: StyleOverride(bold: true)).render(Rect(0, 1, 8, 1), buffer)
    third.render(Rect(0, 2, 8, 1), buffer)
    let adapted = adaptStyleForCapabilities(Style(fg: Color.Red), TerminalCapabilities(trueColor: false, colorLevel: 1))
    if (buffer.getCell(0, 0).symbol != "f" || buffer.getCell(2, 1).symbol != "m" ||
        !buffer.getCell(2, 1).style.modifier.bold || buffer.getCell(5, 2).symbol != "e" ||
        adapted != Style()) { throw IllegalStateException("incorrect widget rendering") }
    return 0
}
