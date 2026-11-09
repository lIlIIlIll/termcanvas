package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 20, 8)
    let fit = SizeGuard(10, 4).fit(area, policy: ResizePolicy.Center)
    let guard = SizeGuard(10, 4)
    let policies = [ResizePolicy.Stretch, ResizePolicy.Letterbox, ResizePolicy.Pillarbox, ResizePolicy.Center]
    let stretch = guard.fit(area, policy: policies[0])
    let manual = ViewportFit(area, fit.content, tooSmall: false, scaleX: 1.0, scaleY: 1.0)
    if (guard.minWidth != 10 || guard.minHeight != 4 || fit.area != area || fit.tooSmall ||
        fit.content != Rect(5, 2, 10, 4) || manual.scaleX != 1.0 || manual.scaleY != 1.0 ||
        stretch.scaleX != 2.0 || stretch.scaleY != 2.0 || centeredViewport(area, 10, 4) != fit.content ||
        guard.fit(area, policy: policies[1]).content != fit.content || guard.fit(area, policy: policies[2]).content != fit.content) {
        throw IllegalStateException("incorrect viewport")
    }
    let buffer = Buffer(area)
    let canvas = Canvas(buffer, area, translateX: 0, translateY: 0)
    let style = Style(fg: Color.Cyan)
    canvas.fillRect(Rect(0, 0, 20, 8), Style())
    canvas.fillRect(1, 1, 2, 1, style)
    canvas.hline(0, 0, 4, "-", style)
    canvas.vline(0, 1, 3, "|", style)
    canvas.strokeRect(Rect(4, 0, 4, 3), style)
    canvas.strokeBorder(Rect(9, 0, 4, 3), style, border: BorderSet.ascii())
    canvas.drawLine(0, 4, 2, 4, "*", style)
    canvas.drawText(4, 4, "text", style)
    canvas.drawSprite(0, 5, ["AB", "CD"], style)
    canvas.render(Paragraph("widget"), Rect(4, 5, 8, 1))
    canvas.withClip(Rect(0, 0, 20, 8)).translated(1, 0).viewport(Position(1, 0)).drawText(12, 5, "clip", style)
    let surface = canvas.createSurface(Rect(14, 4, 4, 2), zIndex: 2)
    surface.canvas().drawText(14, 4, "S", style)
    canvas.composite(surface)
    let separate = Surface(Rect(14, 6, 2, 1), zIndex: 3)
    separate.bufferView().setString(14, 6, "B")
    canvas.composite(separate)
    if (surface.area != Rect(14, 4, 4, 2) || surface.zIndex != 2 || separate.zIndex != 3 ||
        buffer.getCell(4, 4).symbol != "t" || buffer.getCell(0, 5).symbol != "A" ||
        buffer.getCell(4, 5).symbol != "w" || buffer.getCell(14, 4).symbol != "S" ||
        buffer.getCell(14, 6).symbol != "B") { throw IllegalStateException("canvas rendering failed") }
    _ = canvas.textWidthOptions()
    return 0
}
