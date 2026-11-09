package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 12, 4)
    let buffer = Buffer(area)
    buffer.setTheme(Theme.graphite())
    let dirty = DirtyRects([Rect(0, 0, 6, 2)])
    let frame = Frame(area, buffer, dirty: dirty)
    let shapes = [CursorShape.Block, CursorShape.Bar]
    if (frame.area != area || frame.theme().isNone() || !frame.isDirty(Rect(0, 0, 1, 1)) ||
        !frame.isDirtyCell(1, 1) || frame.isDirtyCell(11, 3) || frame.dirtyRects().size != 1 || shapes.size != 2) {
        throw IllegalStateException("incorrect frame state")
    }
    _ = frame.textWidthOptions()
    frame.fill(Rect(0, 0, 6, 1), Style())
    frame.fillRect(0, 1, 6, 1, Style())
    frame.renderWidget(Paragraph("OK"), Rect(0, 0, 6, 1))
    frame.canvas().drawText(0, 1, "frame", Style())
    frame.setCursor(Position(2, 1))
    frame.setCursorShape(CursorShape.Bar)
    let cursor = frame.getCursor().getOrThrow()
    let source = MediaSource("image", "asset:image", alt: "Image")
    frame.addMedia(MediaPlacement("image", source, Rect(0, 0, 2, 1)))
    let span = RenderDiffSpan(0, 0, "OK", Style())
    let plan = RenderDiffPlan(2, [span])
    if (cursor.x != 2 || cursor.y != 1 || span.x != 0 || span.y != 0 || span.text != "OK" ||
        span.style != Style() || plan.dirtyCells != 2 || plan.spans.size != 1 || buffer.mediaPlacements().size != 1) {
        throw IllegalStateException("frame rendering failed")
    }
    return 0
}
