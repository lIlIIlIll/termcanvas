package cjtui_api_example

import core.*

main(): Int64 {
    let span = RichSpan("Guide", linkUrl: Some("https://example.test"), sourceRange: Some("2:7"))
    let document = Document([DocumentLine(DocumentLineKind.Paragraph, [span])])
    let state = DocumentViewState()
    let view = DocumentView(document, state: Some(state), cacheLayout: true)
    view.setTextWidthOptions(TextWidthOptions())
    if (view.renderedLineCount(20) != 1 || view.sourceOffsetForRenderedLine(20, 0).getOrThrow() != 2 ||
        view.sourceOffsetAtRenderedLine(20, 0).getOrThrow() != 2 || view.sourceOffsetsForRenderedLines(20)[0] != 2 ||
        view.renderedLineForSourceOffset(20, 3) != 0 || view.linkAtRenderedLine(20, 0).getOrThrow() != "https://example.test") {
        throw IllegalStateException("document mapping failed")
    }
    let buffer = Buffer(Rect(0, 0, 20, 2))
    view.render(buffer.area, buffer)
    if (!view.handleKey(KeyEvent(KeyCode.Enter), 20, 2) || state.cursorSourceOffset.getOrThrow() != 2 ||
        view.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), buffer.area).getOrThrow() != 2) {
        throw IllegalStateException("document interaction failed")
    }
    MarkdownView("Plain text").render(buffer.area, buffer)
    MarkdownView(document).render(buffer.area, buffer)
    return 0
}
