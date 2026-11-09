package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 20, 5)
    let buffer = Buffer(area)
    let style = Style(fg: Color.Cyan)
    let blank = Cell()
    let cell = Cell("X", style: style, kind: CellKind.Normal)
    let kinds = [CellKind.Normal, CellKind.WideLead, CellKind.WideCont]
    if (blank.symbol != " " || cell.symbol != "X" || cell.style != style || !(cell == Cell("X", style: style)) ||
        kinds.size != 3 || buffer.area != area || buffer.indexOf(0, 0).getOrThrow() != 0 ||
        !buffer.indexOf(99, 99).isNone()) { throw IllegalStateException("incorrect cells") }
    buffer.setCapabilities(TerminalCapabilities(unicode: true))
    buffer.setTheme(Theme.graphite())
    if (!buffer.capabilities().unicode || buffer.theme().isNone() || buffer.resolveTheme(Option<Theme>.None).isNone()) {
        throw IllegalStateException("visual context failed")
    }
    buffer.withParentTheme(Theme.light(), { => buffer.setCell(0, 0, cell) })
    buffer.setTextWidthOptions(TextWidthOptions())
    _ = buffer.textWidthOptions()
    if (buffer.getCell(0, 0) != cell) { throw IllegalStateException("cell write failed") }
    buffer.clear()
    buffer.fill(Rect(0, 0, 2, 1), cell)
    buffer.fill(Rect(2, 0, 2, 1), style: style)
    buffer.fillRect(4, 0, 2, 1, style: style)
    buffer.fillLine(1, 0, 2, cell)
    buffer.fillLine(1, 2, 2, style: style)
    buffer.hline(0, 2, 3, "-", style)
    buffer.hline(3, 2, 3, style: style)
    buffer.vline(6, 0, 3, "|", style)
    buffer.vline(7, 0, 3, style: style)
    if (!buffer.writeAsciiSpan(0, 3, "ABC", style: style)) { throw IllegalStateException("ASCII write failed") }
    buffer.writeAsciiSpanUnchecked(3, 3, "DEF", style: style)
    buffer.setString(0, 4, "界", style: style)
    let copy = buffer.copy()
    let resized = buffer.resize(Rect(0, 0, 22, 5))
    let target = Buffer(area)
    target.blitFrom(copy, Rect(0, 0, 4, 1), 0, 0)
    target.blitFromUnchecked(copy, Rect(0, 3, 6, 1), 0, 3)
    let operations = target.diff(Buffer(area))
    let op = DrawOp(0, 0, cell)
    let source = MediaSource("logo", "asset:logo", alt: "Logo")
    let placement = MediaPlacement("logo", source, Rect(10, 0, 2, 2))
    buffer.addMedia(placement)
    if (copy.getCell(0, 3).symbol != "A" || resized.area.width != 22 || operations.size == 0 ||
        op.x != 0 || op.y != 0 || op.cell != cell || buffer.mediaPlacements().size != 1) {
        throw IllegalStateException("buffer copy or diff failed")
    }
    return 0
}
