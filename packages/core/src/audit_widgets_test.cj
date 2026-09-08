package core

import std.unittest.*
import std.unittest.testmacro.*

class AuditWidgetSource <: VirtualTranscriptSource {
    let count: Int64
    let text: String
    var calls: Int64 = 0
    var requestedWidth: Int64 = 0

    init(count!: Int64 = 1, text!: String = "abcdefgh") {
        this.count = count
        this.text = text
    }

    public func size(): Int64 { count }
    public func itemId(index: Int64): String { "item-${index}" }
    public func revision(_: Int64): Int64 { 0 }
    public func document(_: Int64, width: Int64, _: String): Document {
        calls++
        requestedWidth = width
        Document.plain(text)
    }
}

class AuditWidgetRows {
    var calls: Int64 = 0

    func row(index: Int64): Array<String> {
        calls++
        ["row-${index}"]
    }
}

func auditWidgetRow(buffer: Buffer, y: Int64): String {
    var text = ""
    for (x in buffer.area.x..buffer.area.right) { text += buffer.getCell(x, y).symbol }
    text
}

func auditWidgetSentinels(): Buffer {
    let buffer = Buffer(Rect(0, 0, 20, 8))
    for (y in 0..8) { buffer.setString(0, y, "....................") }
    buffer
}

func auditWidgetOutsideChanges(buffer: Buffer, area: Rect): Int64 {
    var count: Int64 = 0
    for (y in buffer.area.y..buffer.area.bottom) {
        for (x in buffer.area.x..buffer.area.right) {
            if ((x < area.x || x >= area.right || y < area.y || y >= area.bottom) &&
                buffer.getCell(x, y).symbol != ".") { count++ }
        }
    }
    count
}

func auditWidgetDocument(): Document {
    Document([
        DocumentLine(DocumentLineKind.Paragraph, [RichSpan("head", sourceRange: Some("0:4"))]),
        DocumentLine(DocumentLineKind.Paragraph, [RichSpan("folded", sourceRange: Some("10:16"))]),
        DocumentLine(DocumentLineKind.Paragraph, [RichSpan("tail", sourceRange: Some("20:24"))])
    ])
}

@Test
class TermCanvasAuditWidgetsTest {
    @TestCase
    func inputUsesAssociatedTextFromParsedKeyEvents(): Unit {
        let frames = ["\u{1B}[97;2;65u", "\u{1B}[0;;229u", "\u{1B}[0;;65:769u"]
        let texts = ["A", "å", "A\u{0301}"]
        for (i in 0..frames.size) {
            let events = EventParser().push(unsafe { frames[i].rawData() })
            @Assert(events.size, 1)
            let input = Input()
            match (events[0]) {
                case Event.KeyDown(key) => @Expect(input.handle(key))
                case _ => @Expect(false)
            }
            @Expect(input.value, texts[i])
            @Expect(input.cursor, texts[i].size)
        }
        let input = Input()
        @Expect(input.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true))))
        @Expect(input.value, "a")
        @Expect(input.handle(KeyEvent(KeyCode.Home, text: Some("ignored"))))
        @Expect(input.value, "a")
        @Expect(input.cursor, 0)
        @Expect(!input.handle(KeyEvent(KeyCode.Enter, text: Some("ignored"))))
        @Expect(input.value, "a")
    }

    @TestCase
    func wd01DocumentCacheTracksFoldChangesAndClearing(): Unit {
        let doc = auditWidgetDocument()
        let state = DocumentViewState()
        let view = DocumentView(doc, state: Some(state), cacheLayout: true)
        let area = Rect(0, 0, 20, 5)
        view.render(area, Buffer(area))
        state.setFolded(0, 16, true)
        let folded = Buffer(area)
        view.render(area, folded)
        let expected = Buffer(area)
        DocumentView(doc, state: Some(state), cacheLayout: true).render(area, expected)
        @Expect(folded.diff(expected).size, 0)
        @Expect(view.renderedLineCount(area.width), 2)
        @Expect(auditWidgetRow(folded, 1).startsWith("tail"))
        state.clearFolds()
        @Expect(view.renderedLineCount(area.width), 3)
        state.setFolded(0, 16, true)
        @Expect(view.renderedLineCount(area.width), 2)
        state.setFolded(0, 16, false)
        @Expect(view.renderedLineCount(area.width), 3)
    }

    @TestCase
    func wd01DocumentCacheTracksCurrentSource(): Unit {
        let doc = auditWidgetDocument()
        let state = DocumentViewState(cursorSourceOffset: Some(1))
        let view = DocumentView(doc, state: Some(state), cacheLayout: true)
        let area = Rect(0, 0, 20, 5)
        view.render(area, Buffer(area))
        state.cursorSourceOffset = Some(21)
        let actual = Buffer(area)
        view.render(area, actual)
        let expected = Buffer(area)
        DocumentView(doc, state: Some(state), cacheLayout: true).render(area, expected)
        @Expect(actual.diff(expected).size, 0)
        @Expect(actual.getCell(0, 2).style, Style(bg: Color.Indexed(8)))
        state.cursorSourceOffset = None
        let cleared = Buffer(area)
        view.render(area, cleared)
        @Expect(cleared.getCell(0, 2).style, Style.default())
    }

    @TestCase
    func wd02CardThemeRemeasuresChangedGeometry(): Unit {
        let source = AuditWidgetSource()
        let view = VirtualTranscriptView(source)
        let area = Rect(0, 0, 30, 12)
        view.setCardChrome(true)
        view.render(area, Buffer(area))
        let theme = TranscriptCardTheme(fullFrame: true, contentPadding: Spacing.all(1))
        view.setCardTheme(theme)
        let actual = Buffer(area)
        view.render(area, actual)
        let fresh = VirtualTranscriptView(source)
        fresh.setCardChrome(true)
        fresh.setCardTheme(theme)
        let expected = Buffer(area)
        fresh.render(area, expected)
        @Expect(actual.diff(expected).size, 0)
        @Expect(view.totalRows(), fresh.totalRows())
        let calls = source.calls
        view.setCardTheme(TranscriptCardTheme(fullFrame: true, contentPadding: Spacing.all(1)))
        view.render(area, Buffer(area))
        @Expect(source.calls, calls)
    }

    @TestCase
    func wd03ListAndTableStayInsideTheirSubregions(): Unit {
        let area = Rect(2, 1, 4, 3)
        let list = auditWidgetSentinels()
        List(["ABCDEFGHIJKL"]).render(area, list)
        @Expect(auditWidgetOutsideChanges(list, area), 0)
        @Expect(list.getCell(4, 1).symbol, "A")
        let table = auditWidgetSentinels()
        Table(["ABCDEFGHIJKL"], [["mnopqrstuvwx"]], widths: [12]).render(area, table)
        @Expect(auditWidgetOutsideChanges(table, area), 0)
        @Expect(table.getCell(2, 1).symbol, "A")
        @Expect(table.getCell(2, 3).symbol, "m")
        let empty = auditWidgetSentinels()
        Table(["HEAD"], []).render(Rect(2, 1, 4, 0), empty)
        List(["body"]).render(Rect(2, 1, 0, 3), empty)
        @Expect(auditWidgetOutsideChanges(empty, Rect(2, 1, 0, 0)), 0)
    }

    @TestCase
    func wd03VirtualTableClipsWideAndFrozenColumns(): Unit {
        let area = Rect(2, 1, 4, 3)
        let table = VirtualTable([TableColumn("HEADER", width: 12)], 1, { _ => ["ABCDEFGHIJKL"] })
        table.setFrozenColumns(1)
        let actual = auditWidgetSentinels()
        table.render(area, actual)
        @Expect(auditWidgetOutsideChanges(actual, area), 0)
        @Expect(actual.getCell(2, 2).symbol, "A")
        @Expect(actual.getCell(5, 2).symbol, "D")
        let framed = auditWidgetSentinels()
        let outer = Rect(2, 1, 8, 4)
        VirtualTable([TableColumn("HEAD", width: 12)], 1, { _ => ["abcdefghijk"] }, block: Some(Block(title: "T"))).render(outer, framed)
        @Expect(auditWidgetOutsideChanges(framed, outer), 0)
        @Expect(framed.getCell(3, 3).symbol, "a")
        @Expect(framed.getCell(outer.right - 1, 3).symbol, "|")
    }

    @TestCase
    func wd04ColorPickerClipsTheLastCell(): Unit {
        let area = Rect(2, 1, 1, 1)
        let actual = auditWidgetSentinels()
        ColorPicker(colors: [Color.Red]).render(area, actual)
        @Expect(auditWidgetOutsideChanges(actual, area), 0)
        @Expect(actual.getCell(2, 1).symbol, "#")
    }

    @TestCase
    func wd05DocumentMouseUsesItsContentArea(): Unit {
        let area = Rect(4, 5, 12, 4)
        let view = DocumentView(auditWidgetDocument(), block: Some(Block(title: "doc")))
        view.render(area, Buffer(Rect(0, 0, 30, 20)))
        @Expect(view.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 6), area), Some(0))
        @Expect(view.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 29, 6), area).isNone())
        @Expect(view.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 5), area).isNone())
    }

    @TestCase
    func wd06VirtualTableNavigationPublishesSharedScroll(): Unit {
        let scroll = ScrollState()
        let table = VirtualTable([TableColumn("N", width: 8)], 100, { index => ["r${index}"] }, scrollState: Some(scroll))
        let area = Rect(0, 0, 12, 4)
        table.render(area, Buffer(area))
        @Expect(table.handle(KeyEvent(KeyCode.End), 3))
        @Expect(scroll.offset, 97)
        let actual = Buffer(area)
        table.render(area, actual)
        @Expect(table.offset, 97)
        @Expect(auditWidgetRow(actual, 1).startsWith("r97"))
        @Expect(table.handle(KeyEvent(KeyCode.Home), 3))
        @Expect(scroll.offset, 0)
        scroll.offset = 5
        let external = Buffer(area)
        table.render(area, external)
        @Expect(auditWidgetRow(external, 1).startsWith("r5"))
    }

    @TestCase
    func wd07ConfirmEnterMatchesTheDisplayedChoice(): Unit {
        let dialog = ConfirmDialog("Continue?")
        let buffer = Buffer(Rect(0, 0, 40, 7))
        dialog.render(buffer.area, buffer)
        @Expect(!dialog.confirmed)
        @Expect(auditWidgetRow(buffer, 5).contains("[No] [Yes]"))
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some(false))
        @Expect(dialog.handle(KeyEvent(KeyCode.Char(r'y'))), Some(true))
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some(true))
        @Expect(dialog.handle(KeyEvent(KeyCode.Char(r'n'))), Some(false))
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some(false))
    }

    @TestCase
    func wd08FilePickerReturnsToTheAbsoluteRoot(): Unit {
        for (path in ["/termcanvas-audit-placeholder", "/termcanvas-audit-placeholder/"]) {
            let picker = FilePicker(path: path)
            @Expect(picker.parent())
            @Expect(picker.path, "/")
            @Expect(!picker.parent())
        }
    }

    @TestCase
    func wd09InputDirtyCoversTheChangedContentCell(): Unit {
        let area = Rect(2, 1, 10, 3)
        let input = Input(value: "a", cursor: 1, block: Some(Block(title: "input")))
        input.render(area, Buffer(Rect(0, 0, 20, 8)))
        let dirty = input.handleWithDirty(KeyEvent(KeyCode.Char(r'b')), area)
        @Assert(dirty.isSome())
        @Expect(dirty.getOrThrow().covers(Rect(4, 2, 1, 1)))
        let actual = Buffer(Rect(0, 0, 20, 8))
        input.render(area, actual)
        @Expect(actual.getCell(4, 2).symbol, "b")
    }

    @TestCase
    func wd10DocumentWrapKeepsCompleteGraphemes(): Unit {
        for (wrap in [WrapMode.Character, WrapMode.Word]) {
            for (text in ["A\u{0301}B", "👩\u{200D}💻x"]) {
                let width: Int64 = if (text.startsWith("A")) { 1 } else { 2 }
                let area = Rect(0, 0, width, 6)
                let actual = Buffer(area)
                DocumentView(Document.plain(text), wrap: wrap).render(area, actual)
                let expected = Buffer(area)
                Paragraph(text, wrap: wrap).render(area, expected)
                @Expect(actual.diff(expected).size, 0)
                @Expect(actual.getCell(0, 0).symbol, if (width == 1) { "A\u{0301}" } else { "👩\u{200D}💻" })
            }
        }
    }

    @TestCase
    func wd11ComposerRefreshesAfterDirectValueChanges(): Unit {
        let area = Rect(0, 0, 10, 2)
        let composer = Composer(value: "abc")
        composer.render(area, Buffer(area))
        composer.area.value = "axc"
        let actual = Buffer(area)
        composer.render(area, actual)
        let expected = Buffer(area)
        Composer(value: "axc").render(area, expected)
        @Expect(actual.diff(expected).size, 0)
        @Expect(auditWidgetRow(actual, 0).contains("axc"))
    }

    @TestCase
    func wd11ComposerRefreshesAfterUndoAndRedo(): Unit {
        let area = Rect(0, 0, 10, 2)
        let composer = Composer(value: "a")
        composer.area.cursor = 1
        _ = composer.handle(KeyEvent(KeyCode.Char(r'b')))
        @Expect(composer.area.value, "ab")
        composer.render(area, Buffer(area))
        @Expect(composer.area.undo())
        let undone = Buffer(area)
        composer.render(area, undone)
        let expectedUndo = Buffer(area)
        Composer(value: "a").render(area, expectedUndo)
        @Expect(undone.diff(expectedUndo).size, 0)
        @Expect(composer.area.redo())
        let redone = Buffer(area)
        composer.render(area, redone)
        let expectedRedo = Buffer(area)
        Composer(value: "ab").render(area, expectedRedo)
        @Expect(redone.diff(expectedRedo).size, 0)
    }

    @TestCase
    func wd12EmptyMultiSelectNeverReturnsAMissingIndex(): Unit {
        let empty = MultiSelect([])
        @Expect(empty.handle(KeyEvent(KeyCode.Enter)))
        @Expect(empty.selectedIndices().size, 0)
        @Expect(empty.handle(KeyEvent(KeyCode.Char(r' '))))
        @Expect(empty.selectedIndices().size, 0)
        empty.toggle()
        @Expect(empty.selectedIndices().size, 0)
        let one = MultiSelect(["one"])
        one.toggle()
        @Expect(one.selectedIndices(), [0])
    }

    @TestCase
    func wd13DatePickerClampsToTheCurrentMonth(): Unit {
        let date = DatePicker(year: 2026, month: 1, day: 31)
        @Expect(date.handle(KeyEvent(KeyCode.Up)))
        @Expect(date.value(), "2026-02-28")
        @Expect(date.handle(KeyEvent(KeyCode.Right)))
        @Expect(date.value(), "2026-02-28")
        let leap = DatePicker(year: 2024, month: 3, day: 31)
        @Expect(leap.handle(KeyEvent(KeyCode.Down)))
        @Expect(leap.value(), "2024-02-29")
        @Expect(DatePicker(year: 1900, month: 2, day: 31).value(), "1900-02-28")
        @Expect(DatePicker(year: 2000, month: 2, day: 31).value(), "2000-02-29")
    }

    @TestCase
    func wd14AsciiCardRailReservesItsFullWidth(): Unit {
        let source = AuditWidgetSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        view.setUnicode(false)
        let area = Rect(0, 0, 10, 10)
        let actual = Buffer(area)
        view.render(area, actual)
        @Expect(source.requestedWidth, 7)
        @Expect(actual.getCell(3, 2).symbol, "h")
        view.setUnicode(true)
        let unicode = Buffer(area)
        view.render(area, unicode)
        @Expect(source.requestedWidth, 8)
        @Expect(unicode.getCell(9, 1).symbol, "h")
    }

    @TestCase
    func wd15ChartSaturatesAtTheTopOfItsArea(): Unit {
        let area = Rect(2, 2, 2, 2)
        let actual = auditWidgetSentinels()
        TimeSeriesChart([3, 9223372036854775807], maxValue: 1).render(area, actual)
        @Expect(auditWidgetOutsideChanges(actual, area), 0)
        @Expect(actual.getCell(2, 2).symbol, "#")
        @Expect(actual.getCell(3, 3).symbol, "#")
    }

    @TestCase
    func wd16CustomBordersAndBuiltInKindsRemainDistinct(): Unit {
        let area = Rect(0, 0, 6, 3)
        let custom = Buffer(area)
        let border = BorderSet(horizontal: "=", vertical: "!")
        Block(BlockOptions(border: border)).render(area, custom)
        @Expect(custom.getCell(1, 0).symbol, "=")
        @Expect(custom.getCell(0, 1).symbol, "!")
        let rounded = Buffer(area)
        Block(BlockOptions(borderKind: BorderKind.Rounded)).render(area, rounded)
        @Expect(rounded.getCell(0, 0).symbol, "╭")
        let fallback = Buffer(area)
        Block(BlockOptions(border: border, asciiFallback: true)).render(area, fallback)
        @Expect(fallback.getCell(1, 0).symbol, "-")
        let narrowArea = Rect(2, 2, 3, 3)
        let narrow = auditWidgetSentinels()
        Block(BlockOptions(border: BorderSet(horizontal: "==", vertical: "!!", topRight: "++"))).render(narrowArea, narrow)
        @Expect(auditWidgetOutsideChanges(narrow, narrowArea), 0)
        @Expect(narrow.getCell(2, 3).symbol, "!")
    }

    @TestCase
    func wd17TranscriptAllocatesWrappedBodyRows(): Unit {
        let item = TranscriptItem("one", title: "T", stateLabel: "x", body: Document.plain("abcdefghijklmnopqrstuvwxyz"))
        let area = Rect(0, 0, 12, 8)
        let actual = Buffer(area)
        TranscriptView(Transcript(items: [item])).render(area, actual)
        let expected = Buffer(area)
        DocumentView(transcriptCardDocument(item)).render(area, expected)
        @Expect(auditWidgetRow(actual, 3), auditWidgetRow(expected, 3))
        @Expect(auditWidgetRow(actual, 3), "mnopqrstuvwx")
    }

    @TestCase
    func wd17TranscriptBringsTheSelectedCardIntoView(): Unit {
        let first = TranscriptItem("first", title: "FIRST", body: Document.plain("a\nb\nc\nd\ne"))
        let second = TranscriptItem("second", title: "SECOND", body: Document.plain("tail"))
        let view = TranscriptView(Transcript(items: [first, second]))
        let area = Rect(0, 0, 30, 4)
        view.render(area, Buffer(area))
        @Expect(view.handle(KeyEvent(KeyCode.Down), area.height))
        let actual = Buffer(area)
        view.render(area, actual)
        @Expect(view.selected, 1)
        @Expect(view.offset, 1)
        @Expect(auditWidgetRow(actual, 0).contains("SECOND"))
    }

    @TestCase
    func wd18VirtualTableQueriesTheBoundSelectionModel(): Unit {
        let model = SelectionModel(mode: SelectionMode.Multiple)
        let values = ["zero", "one", "two"]
        let table = VirtualTable([TableColumn("N")], 3, { index => [values[index]] }, selectionModel: Some(model))
        table.setFilter("two")
        table.selectedRow = Some(0)
        table.toggleSelectedRow()
        @Expect(model.isSelected(2))
        @Expect(table.isSelected(2))
        @Expect(table.selectedRowIndices(), [2])
        model.clear()
        @Expect(!table.isSelected(2))
        @Expect(table.selectedRowIndices().size, 0)
    }

    @TestCase
    func virtualProvidersKeepViewportWorkBounded(): Unit {
        for (count in [100, 10000, 100000]) {
            let rows = AuditWidgetRows()
            let area = Rect(0, 0, 30, 8)
            let table = VirtualTable([TableColumn("N")], count, { index => rows.row(index) })
            let actual = Buffer(area)
            table.render(area, actual)
            @Expect(rows.calls, 7)
            @Expect(auditWidgetRow(actual, 1).startsWith("row-0"))
            let source = AuditWidgetSource(count: count)
            let view = VirtualTranscriptView(source)
            let transcript = Buffer(area)
            view.render(area, transcript)
            @Expect(source.calls > 0 && source.calls <= 24)
            @Expect(transcript.diff(Buffer(area)).size > 0)
            let before = source.calls
            view.render(area, Buffer(area))
            @Expect(source.calls, before)
        }
    }
}
