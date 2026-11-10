package cjtui_api_example

import core.*

main(): Int64 {
    let size = Rect(0, 0, 12, 3)
    let capabilities = TerminalCapabilities(size: size, trueColor: true, colorLevel: 24,
        mouse: true, mouseMove: true, focusEvents: true, bracketedPaste: true, alternateScreen: true,
        unicode: true, kittyGraphics: false, sixel: false, osc8: true, keyboardProtocol: KeyProtocol.Basic,
        keyUp: false, keyRepeat: true, recommendedFps: 30, cellWidthPixels: 8, cellHeightPixels: 16,
        driverName: "example")
    if (capabilities.size != size || !capabilities.trueColor || capabilities.colorLevel != 24 ||
        !capabilities.mouse || !capabilities.mouseMove || !capabilities.focusEvents || !capabilities.bracketedPaste ||
        !capabilities.alternateScreen || !capabilities.unicode || capabilities.kittyGraphics || capabilities.sixel ||
        !capabilities.osc8 || capabilities.keyUp || !capabilities.keyRepeat || capabilities.recommendedFps != 30 ||
        capabilities.cellWidthPixels != 8 || capabilities.cellHeightPixels != 16 || capabilities.driverName != "example") {
        throw IllegalStateException("incorrect terminal capabilities")
    }
    match (capabilities.keyboardProtocol) {
        case KeyProtocol.Basic => ()
        case _ => throw IllegalStateException("incorrect keyboard protocol")
    }
    let backend = TestBackend(area: size)
    let terminal = Terminal(backend, renderMode: RenderMode.Diff, instrumentationEnabled: true)
    terminal.setCapabilities(capabilities)
    terminal.setTheme(Theme.graphite())
    terminal.setTextWidthOptions(TextWidthOptions())
    let first = terminal.draw({ frame => frame.renderWidget(Paragraph("Hello"), frame.area) })
    let second = terminal.draw({ frame => frame.renderWidget(Paragraph("Hi"), frame.area) },
        dirtyRects: DirtyRects([Rect(0, 0, 5, 1)]))
    if (first.size != size || second.size != size || !backend.snapshot().contains("Hi")) {
        throw IllegalStateException("terminal render failed")
    }
    let metrics = RenderMetrics(size: size, dirtyCells: 2, diffWrites: 1, mediaOps: 0, fullRedraw: false,
        renderMillis: 1, drawMillis: 2, totalMillis: 3, renderedCells: 2, dirtyRects: 1, copiedCells: 2,
        bufferCellAttempts: 3, bufferCellWrites: 2, renderNanos: 4, diffNanos: 5, writeNanos: 6,
        totalNanos: 15, ansiBytes: -1)
    if (metrics.size != size || metrics.dirtyCells != 2 || metrics.diffWrites != 1 || metrics.mediaOps != 0 ||
        metrics.fullRedraw || metrics.renderMillis != 1 || metrics.drawMillis != 2 || metrics.totalMillis != 3 ||
        metrics.renderedCells != 2 || metrics.dirtyRects != 1 || metrics.copiedCells != 2 ||
        metrics.bufferCellAttempts != 3 || metrics.bufferCellWrites != 2 || metrics.diffCells != 2 ||
        metrics.diffSpans != 1 || metrics.renderNanos != 4 || metrics.diffNanos != 5 || metrics.writeNanos != 6 ||
        metrics.totalNanos != 15 || metrics.ansiBytes != -1) { throw IllegalStateException("incorrect render metrics") }
    terminal.clear()
    let full = Terminal(TestBackend(area: size), renderMode: RenderMode.Full)
    _ = full.draw({ frame => frame.renderWidget(Paragraph("Full"), frame.area) })
    return 0
}
