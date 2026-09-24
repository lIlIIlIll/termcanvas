package core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

class CountingTableRows {
    var calls: Int64 = 0
    var minRow: Int64 = Int64.Max
    var maxRow: Int64 = -1

    func reset(): Unit {
        calls = 0
        minRow = Int64.Max
        maxRow = -1
    }

    func rowAt(index: Int64): Array<String> {
        calls++
        minRow = min(minRow, index)
        maxRow = max(maxRow, index)
        ["row-${index}", "value-${index}"]
    }
}

class BenchTableRows {
    func rowAt(index: Int64): Array<String> {
        ["row-${index}", "value-${index}"]
    }
}

func largePerformanceText(lineCount: Int64): String {
    let text = StringBuilder()
    for (i in 0..lineCount) {
        text.append("line ${i} ascii 中文 e\u{301} 🙂 target-${i}\n")
    }
    text.toString()
}

func runTerminalDiffBench(variant: Int64): RenderMetrics {
    let viewport = Rect(0, 0, 80, 24)
    let backend = TestBackend(area: viewport)
    let terminal = Terminal(backend, renderMode: RenderMode.Diff)
    _ = terminal.draw { frame =>
        frame.canvas().drawText(0, 0, "alpha", Style.default())
        frame.canvas().drawText(0, 1, "stable 中文 🙂", Style.default())
        frame.canvas().drawText(0, 2, "row-2 stable", Style.default())
        frame.canvas().drawText(0, 3, "row-3 stable", Style.default())
    }
    match (variant) {
        case 0 =>
            terminal.draw { frame =>
                frame.canvas().drawText(0, 0, "alpXa", Style.default())
                frame.canvas().drawText(0, 1, "stable 中文 🙂", Style.default())
                frame.canvas().drawText(0, 2, "row-2 stable", Style.default())
                frame.canvas().drawText(0, 3, "row-3 stable", Style.default())
            }
        case 1 =>
            terminal.draw { frame =>
                frame.canvas().drawText(0, 0, "alpha", Style.default())
                frame.canvas().drawText(0, 1, "stable 中文 🙂", Style.default())
                frame.canvas().drawText(0, 2, "row-2 stable with changed row tail", Style.default())
                frame.canvas().drawText(0, 3, "row-3 stable", Style.default())
            }
        case 2 =>
            terminal.draw { frame =>
                frame.canvas().drawText(0, 0, "alpha", Style.default())
                frame.canvas().drawText(0, 1, "stable 文a  ", Style.default())
                frame.canvas().drawText(0, 2, "row-2 stable", Style.default())
                frame.canvas().drawText(0, 3, "row-3 stable", Style.default())
            }
        case _ =>
            terminal.draw { frame =>
                frame.canvas().drawText(0, 0, "alpXa", Style.default())
                frame.canvas().drawText(0, 1, "stable 中文 🙂", Style.default())
                frame.canvas().drawText(0, 2, "row-2 stable changed", Style.default())
                frame.canvas().drawText(0, 3, "row-3 stable changed", Style.default())
            }
    }
}

func runCanvasFillRectBench(size: Int64): Int64 {
    let width = if (size == 0) { Int64(80) } else { Int64(160) }
    let height = if (size == 0) { Int64(24) } else { Int64(48) }
    let buffer = Buffer(Rect(0, 0, width, height))
    let canvas = Canvas(buffer, buffer.area)
    for (_ in 0..20) {
        canvas.fillRect(buffer.area, Style(bg: Color.Black))
        canvas.drawText(0, 0, "ascii table row ----------------", Style.default())
        canvas.drawText(width / 2, height / 2, "界a", Style.default())
    }
    buffer.getCell(width / 2, height / 2).symbol.size
}

func runVirtualTableBench(rowCount: Int64): RenderMetrics {
    let rows = BenchTableRows()
    let table = VirtualTable(
        [TableColumn("Name", width: 12), TableColumn("Value", width: 12)],
        rowCount,
        { index => rows.rowAt(index) }
    )
    let terminal = Terminal(TestBackend(area: Rect(0, 0, 40, 10)), renderMode: RenderMode.Diff)
    _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
    _ = table.handle(KeyEvent(KeyCode.PageDown), 9)
    _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
    _ = table.handle(KeyEvent(KeyCode.End), 9)
    terminal.draw { frame => frame.renderWidget(table, frame.area) }
}

func runTextAreaBench(lineCount: Int64): RenderMetrics {
    let viewport = Rect(0, 0, 80, 24)
    let terminal = Terminal(TestBackend(area: viewport), renderMode: RenderMode.Diff)
    let area = TextArea(value: largePerformanceText(lineCount), cursor: 0, lineNumbers: true, markdownEditing: true)
    _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
    let target = "target-${lineCount / 2}"
    area.cursor = 0
    _ = area.findNext(target)
    _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
    area.selectionStart = None
    area.selectionEnd = None
    _ = area.handle(KeyEvent(KeyCode.Char(r'X')))
    _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
    _ = area.handle(KeyEvent(KeyCode.Backspace))
    terminal.draw { frame => frame.renderWidget(area, frame.area) }
}

func benchmarkTableRows(rowCount: Int64): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    for (index in 0..rowCount) {
        var key = "${rowCount - index}"
        while (key.size < 6) { key = "0${key}" }
        let tag = if (index % 2 == 0) { "keep" } else { "drop" }
        rows.add([key, tag, "source-${index}"])
    }
    rows.toArray()
}

func runVirtualTableSortBench(rowCount: Int64, filter!: Bool = false, repeatRender!: Bool = false): Int64 {
    let rows = benchmarkTableRows(rowCount)
    let table = VirtualTable(
        [TableColumn("Key", width: 10), TableColumn("Tag", width: 8), TableColumn("Source", width: 12)],
        rowCount,
        { index => rows[index] }
    )
    if (filter) { table.setFilter("keep") }
    table.sortBy(0)

    let area = Rect(0, 0, 40, 10)
    let terminal = Terminal(
        TestBackend(area: area, captureSnapshots: false),
        renderMode: RenderMode.Diff
    )
    var consumed: Int64 = 0
    let initial = terminal.draw { frame => frame.renderWidget(table, frame.area) }
    consumed += initial.dirtyCells + initial.diffWrites
    if (repeatRender) {
        for (_ in 0..8) {
            let metrics = terminal.draw { frame => frame.renderWidget(table, frame.area) }
            consumed += metrics.dirtyCells + metrics.diffWrites
        }
    }
    consumed + rows.size
}

func benchmarkTraversalText(size: Int64, mixed!: Bool = false): String {
    let text = StringBuilder()
    if (mixed) {
        for (_ in 0..size) { text.append("中e\u{301}🙂") }
    } else {
        for (_ in 0..size) { text.append("a") }
    }
    text.toString()
}

func runGraphemeTraversalBench(text: String): Int64 {
    var offset: Int64 = 0
    var consumed: Int64 = 0
    while (offset < text.size) {
        let next = nextGraphemeOffset(text, offset)
        if (next <= offset) { break }
        offset = next
        consumed++
    }
    offset + consumed
}

func runTextAreaViewportBench(lineCount: Int64, warm!: Bool = false, move!: Bool = false): Int64 {
    let viewport = Rect(0, 0, 80, 24)
    let text = largePerformanceText(lineCount)
    let area = TextArea(value: text, cursor: text.size, lineNumbers: true, markdownEditing: true)
    let terminal = Terminal(
        TestBackend(area: viewport, captureSnapshots: false),
        renderMode: RenderMode.Diff
    )
    var consumed: Int64 = 0
    if (warm || move) {
        let initial = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        consumed += initial.dirtyCells + initial.diffWrites
    }
    if (move) {
        for (_ in 0..8) {
            _ = area.handle(KeyEvent(KeyCode.Up))
            let up = terminal.draw { frame => frame.renderWidget(area, frame.area) }
            _ = area.handle(KeyEvent(KeyCode.Down))
            let down = terminal.draw { frame => frame.renderWidget(area, frame.area) }
            consumed += up.dirtyCells + up.diffWrites + down.dirtyCells + down.diffWrites
        }
    } else if (warm) {
        for (_ in 0..8) {
            let metrics = terminal.draw { frame => frame.renderWidget(area, frame.area) }
            consumed += metrics.dirtyCells + metrics.diffWrites
        }
    } else {
        let initial = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        consumed += initial.dirtyCells + initial.diffWrites
    }
    consumed + area.cursor
}

func benchmarkBufferPayload(size: Int64, multiline!: Bool = false): String {
    let text = StringBuilder()
    if (multiline) {
        for (_ in 0..(size / 2)) { text.append("x\n") }
        if (size % 2 != 0) { text.append("x") }
    } else {
        for (_ in 0..size) { text.append("x") }
    }
    text.toString()
}

func runTextBufferPasteBench(size: Int64, multiline!: Bool = false): Int64 {
    let payload = benchmarkBufferPayload(size, multiline: multiline)
    let buffer = TextBuffer(text: "prefix-suffix")
    let end = buffer.insert(TextPosition(0, 6), payload)
    end.line + end.column + buffer.text().size
}

func runTextBufferReplaceBench(size: Int64): Int64 {
    let source = benchmarkBufferPayload(size)
    let buffer = TextBuffer(text: source)
    let replaced = buffer.replaceAll("x", "中")
    replaced + buffer.text().size
}

@Test
class CjTuiPerformanceRegressionTest {
    @TestCase
    func terminalDiffKeepsSmallAsciiUpdateLocal(): Unit {
        let viewport = Rect(0, 0, 20, 4)
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        let first = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "alpha", Style.default())
            frame.canvas().drawText(0, 1, "stable", Style.default())
        }
        @Expect(first.fullRedraw)
        @Expect(first.dirtyCells, viewport.width * viewport.height)

        let changedTextWidth: Int64 = 1
        let dirtyLimit = changedTextWidth
        let writeLimit: Int64 = 1
        let second = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "alpXa", Style.default())
            frame.canvas().drawText(0, 1, "stable", Style.default())
        }
        @Expect(!second.fullRedraw)
        @Expect(second.dirtyCells <= dirtyLimit)
        @Expect(second.diffWrites <= writeLimit)
        @Expect(backend.lastDiffWrites() <= writeLimit)
        @Expect(backend.snapshot().contains("alpXa"))
    }

    @TestCase
    func terminalDiffKeepsWideCellContinuationLocal(): Unit {
        let viewport = Rect(0, 0, 12, 3)
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "界界", Style.default())
            frame.canvas().drawText(0, 1, "stable", Style.default())
        }

        let dirtyLimit = viewport.width
        let writeLimit: Int64 = 3
        let second = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "界a ", Style.default())
            frame.canvas().drawText(0, 1, "stable", Style.default())
        }
        @Expect(!second.fullRedraw)
        @Expect(second.dirtyCells <= dirtyLimit)
        @Expect(second.diffWrites <= writeLimit)
        @Expect(backend.assertCell(0, 0, "界"))
        @Expect(backend.assertCell(2, 0, "a"))
    }

    @TestCase
    func terminalPartialRenderCopiesOnlyDirtyCells(): Unit {
        let viewport = Rect(0, 0, 20, 4)
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "header", Style.default())
            frame.canvas().drawText(0, 1, "value: old", Style.default())
            frame.canvas().drawText(0, 2, "footer", Style.default())
        }

        let dirty = DirtyRects()
        dirty.add(Rect(7, 1, 3, 1))
        let metrics = terminal.draw({ frame =>
            frame.canvas().drawText(7, 1, "new", Style.default())
        }, dirtyRects: Some(dirty))

        @Expect(!metrics.fullRedraw)
        // Partial redraw reserves one boundary cell on each side so a new
        // width-2 grapheme can be written atomically without widening to a row.
        let boundaryAllowance: Int64 = 2
        @Expect(metrics.renderedCells <= dirty.cellCount() + boundaryAllowance)
        @Expect(metrics.copiedCells <= dirty.cellCount() + boundaryAllowance)
        @Expect(metrics.dirtyCells <= dirty.cellCount())
        @Expect(backend.snapshot().contains("header"))
        @Expect(backend.snapshot().contains("value: new"))
        @Expect(backend.snapshot().contains("footer"))
    }

    @TestCase
    func virtualTableProviderReadsOnlyViewportRows(): Unit {
        let rows = CountingTableRows()
        let table = VirtualTable(
            [TableColumn("Name", width: 12), TableColumn("Value", width: 12)],
            1000000,
            { index => rows.rowAt(index) }
        )
        let viewport = Rect(0, 0, 40, 10)
        let visibleRows = viewport.height - 1
        let providerCallLimit = visibleRows
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        rows.reset()
        _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
        @Expect(rows.calls <= providerCallLimit)
        @Expect(rows.minRow, 0)
        @Expect(rows.maxRow, visibleRows - 1)

        @Expect(table.handle(KeyEvent(KeyCode.PageDown), visibleRows))
        rows.reset()
        _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
        @Expect(rows.calls <= providerCallLimit)
        @Expect(rows.minRow >= 1)
        @Expect(rows.maxRow < 1 + visibleRows)

        @Expect(table.handle(KeyEvent(KeyCode.End), visibleRows))
        rows.reset()
        _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
        @Expect(rows.calls <= providerCallLimit)
        @Expect(rows.minRow >= 1000000 - visibleRows)
        @Expect(rows.maxRow, 999999)
    }

    @TestCase
    func virtualTableSelectionDirtyRowsOnly(): Unit {
        let rows = CountingTableRows()
        let table = VirtualTable(
            [TableColumn("Name", width: 12), TableColumn("Value", width: 12)],
            1000,
            { index => rows.rowAt(index) },
            selectedRow: Some(0)
        )
        let viewport = Rect(0, 0, 40, 10)
        let visibleRows = viewport.height - 1
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(table, frame.area) }
        match (table.handleWithDirty(KeyEvent(KeyCode.Down), viewport)) {
            case Some(dirty) =>
                @Expect(dirty.rects().size <= 2)
                let metrics = terminal.draw({ frame => frame.renderWidget(table, frame.area) }, dirtyRects: Some(dirty))
                @Expect(!metrics.fullRedraw)
                @Expect(metrics.renderedCells <= viewport.width * 2)
                @Expect(metrics.dirtyRects <= 2)
            case None => @Expect(false)
        }
    }

    @TestCase
    func largeTextAreaEditKeepsDiffLocal(): Unit {
        let lineCount: Int64 = 200
        let viewport = Rect(0, 0, 80, 24)
        let backend = TestBackend(area: viewport)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        let area = TextArea(value: largePerformanceText(lineCount), cursor: 0, lineNumbers: true, markdownEditing: true)

        _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        @Expect(backend.snapshot().contains("line 0"))

        @Expect(area.handle(KeyEvent(KeyCode.PageDown)))
        @Expect(area.cursor > 0)
        _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        @Expect(backend.snapshot().contains("line"))
        @Expect(!backend.snapshot().contains("line 199"))

        @Expect(area.handle(KeyEvent(KeyCode.End, modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, area.value.size)
        area.cursor = 0
        match (area.findNext("target-100")) {
            case Some(index) =>
                @Expect(index >= 0)
                @Expect(area.cursor, index)
            case None => @Expect(false)
        }
        _ = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        @Expect(backend.snapshot().contains("target-100"))

        area.selectionStart = None
        area.selectionEnd = None
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'X'))))
        let edited = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        let affectedRows: Int64 = 3
        let dirtyLimit = viewport.width * affectedRows
        @Expect(!edited.fullRedraw)
        @Expect(edited.dirtyCells <= dirtyLimit)
        @Expect(edited.diffWrites <= affectedRows)
        @Expect(backend.snapshot().contains("Xtarget-100"))

        @Expect(area.handle(KeyEvent(KeyCode.Backspace)))
        let deleted = terminal.draw { frame => frame.renderWidget(area, frame.area) }
        @Expect(!deleted.fullRedraw)
        @Expect(deleted.dirtyCells <= dirtyLimit)
        @Expect(deleted.diffWrites <= affectedRows)
        @Expect(backend.snapshot().contains("target-100"))
    }
}

@Test
class CjTuiPerformanceBench {
    var sink: Int64 = 0

    @Bench[variant in [0, 1, 2, 3]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func terminalDiffTouchedCellsSlope(variant: Int64): Unit {
        let metrics = runTerminalDiffBench(variant)
        sink += metrics.dirtyCells + metrics.diffWrites
    }

    @Bench[size in [0, 1]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func canvasFillRectAsciiFastPath(size: Int64): Unit {
        sink += runCanvasFillRectBench(size)
    }

    @Bench[rowCount in [1000, 100000, 1000000]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func virtualTableViewportProviderSlope(rowCount: Int64): Unit {
        let metrics = runVirtualTableBench(rowCount)
        sink += metrics.dirtyCells + metrics.diffWrites
    }

    @Bench[lineCount in [200, 1000, 2000]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textAreaViewportEditSlope(lineCount: Int64): Unit {
        let metrics = runTextAreaBench(lineCount)
        sink += metrics.dirtyCells + metrics.diffWrites
    }
    @Bench[rowCount in [128, 256, 512]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func virtualTableFirstSort(rowCount: Int64): Unit {
        sink += runVirtualTableSortBench(rowCount)
    }

    @Bench[rowCount in [128, 256, 512]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func virtualTableFilterAndSort(rowCount: Int64): Unit {
        sink += runVirtualTableSortBench(rowCount, filter: true)
    }

    @Bench[rowCount in [128, 256, 512]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func virtualTableWarmRepeatedRender(rowCount: Int64): Unit {
        sink += runVirtualTableSortBench(rowCount, repeatRender: true)
    }

    @Bench[size in [1024, 4096, 16384]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func asciiGraphemeTraversal(size: Int64): Unit {
        let text = benchmarkTraversalText(size)
        sink += runGraphemeTraversalBench(text)
    }

    @Bench[size in [1024, 4096, 16384]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func mixedGraphemeTraversal(size: Int64): Unit {
        let text = benchmarkTraversalText(size, mixed: true)
        sink += runGraphemeTraversalBench(text)
    }

    @Bench[lineCount in [1000, 10000, 100000]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textAreaColdViewportRender(lineCount: Int64): Unit {
        sink += runTextAreaViewportBench(lineCount)
    }

    @Bench[lineCount in [1000, 10000, 100000]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textAreaWarmViewportRender(lineCount: Int64): Unit {
        sink += runTextAreaViewportBench(lineCount, warm: true)
    }

    @Bench[lineCount in [1000, 10000, 100000]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textAreaViewportVerticalMovement(lineCount: Int64): Unit {
        sink += runTextAreaViewportBench(lineCount, move: true)
    }

    @Bench[size in [1024, 4096, 16384]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textBufferSingleLinePaste(size: Int64): Unit {
        sink += runTextBufferPasteBench(size)
    }

    @Bench[size in [1024, 4096, 16384]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textBufferMultilinePaste(size: Int64): Unit {
        sink += runTextBufferPasteBench(size, multiline: true)
    }

    @Bench[size in [1024, 4096, 16384]]
    @Configure[warmup: 0, batchSize: 1, minBatches: 1, minDuration: Duration.millisecond]
    func textBufferReplaceAll(size: Int64): Unit {
        sink += runTextBufferReplaceBench(size)
    }

}
