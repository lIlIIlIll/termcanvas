package core

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

func round2RegionUnchanged(before: Buffer, after: Buffer, painted: Rect): Bool {
    for (y in before.area.y..before.area.bottom) {
        for (x in before.area.x..before.area.right) {
            if ((x < painted.x || x >= painted.right || y < painted.y || y >= painted.bottom) &&
                before.getCell(x, y) != after.getCell(x, y)) { return false }
        }
    }
    true
}

class Round2Widget <: Widget {
    let index: Int64
    init(index: Int64) { this.index = index }
    public func render(area: Rect, buffer: Buffer): Unit {
        match (index) {
            case 0 => List(["x"]).render(area, buffer)
            case 1 => Table(["x"], [["y"]], widths: [1]).render(area, buffer)
            case 2 => VirtualTable([TableColumn("x", width: 1)], 1, { _ => ["y"] }).render(area, buffer)
            case 3 => ColorPicker(colors: [Color.Red]).render(area, buffer)
            case _ => Block(BlockOptions(border: BorderSet(horizontal: "=", vertical: "!"))).render(area, buffer)
        }
    }
}

func round2Widget(index: Int64): Widget { Round2Widget(index) }

class Round2PaddingSource <: VirtualTranscriptSource {
    let widths = ArrayList<Int64>()
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "padding" }
    public func revision(_: Int64): Int64 { 0 }
    public func document(_: Int64, width: Int64, _: String): Document {
        widths.add(width)
        Document.plain("x")
    }
}

@Test
class TermCanvasRound2WidgetsTest {
    @TestCase
    func rw01ChartScalesLargeIntegersExactly(): Unit {
        let cases: Array<(Int64, Int64, Int64)> = [
            (2, 4, 2),
            (4611686018427387904, Int64.Max, 2),
            (4611686018427387903, Int64.Max, 1),
            (Int64.Max - 1, Int64.Max, 3),
            (Int64.Max, Int64.Max, 4),
            (Int64.Max, 4, 4),
            (0, Int64.Max, 1),
            (Int64.Min, Int64.Max, 1)
        ]
        for ((value, maximum, expected) in cases) {
            let area = Rect(2, 3, 1, 4)
            let buffer = Buffer(Rect(0, 0, 6, 8))
            let before = buffer.copy()
            TimeSeriesChart([value], maxValue: maximum).render(area, buffer)
            for (row in 0..4) {
                @Expect(buffer.getCell(2, 3 + row).symbol, if (row >= 4 - expected) { "#" } else { " " })
            }
            @Expect(round2RegionUnchanged(before, buffer, area))
        }
    }

    @TestCase
    func rw01ChartKeepsSmallRatiosAndAutomaticRange(): Unit {
        for (height in 1..9) {
            for (value in 0..32) {
                let area = Rect(0, 0, 1, height)
                let buffer = Buffer(area)
                TimeSeriesChart([value], maxValue: 31).render(area, buffer)
                var filled: Int64 = 0
                for (y in 0..height) { if (buffer.getCell(0, y).symbol == "#") { filled++ } }
                @Expect(filled, max(1, value * height / 31))
            }
        }
        let area = Rect(0, 0, 2, 4)
        let buffer = Buffer(area)
        TimeSeriesChart([4611686018427387904, Int64.Max]).render(area, buffer)
        @Expect(buffer.getCell(0, 1).symbol, " ")
        @Expect(buffer.getCell(0, 2).symbol, "#")
        @Expect(buffer.getCell(1, 0).symbol, "#")
    }

    @TestCase
    func rw02DirectWidgetsPreserveWideGlyphsAcrossBothEdges(): Unit {
        for (kind in 0..5) {
            for (leftEdge in [true, false]) {
                for (scoped in [false, true]) {
                    let buffer = Buffer(Rect(5, 7, 7, 3))
                    let glyphX = if (leftEdge) { Int64(5) } else { Int64(6) }
                    buffer.setString(glyphX, 7, "界")
                    let before = buffer.copy()
                    let area = Rect(6, 7, 1, 3)
                    let widget = round2Widget(kind)
                    if (scoped) { Canvas(buffer, area).render(widget, area) }
                    else { widget.render(area, buffer) }
                    @Expect(round2RegionUnchanged(before, buffer, area))
                    @Expect(buffer.getCell(glyphX, 7), before.getCell(glyphX, 7))
                    @Expect(buffer.getCell(glyphX + 1, 7), before.getCell(glyphX + 1, 7))
                    buffer.setString(5, 9, "!")
                    @Expect(buffer.getCell(5, 9).symbol, "!")
                }
            }
        }
    }

    @TestCase
    func rw02FullRegionsRemainWritableAndEmptyRegionsDoNothing(): Unit {
        for (kind in 0..5) {
            let buffer = Buffer(Rect(5, 7, 5, 3))
            buffer.setString(5, 7, "界")
            let before = buffer.copy()
            round2Widget(kind).render(Rect(6, 7, 0, 3), buffer)
            round2Widget(kind).render(Rect(5, 7, 3, 0), buffer)
            @Expect(round2RegionUnchanged(before, buffer, Rect(0, 0, 0, 0)))
            round2Widget(kind).render(buffer.area, buffer)
            @Expect(buffer.getCell(5, 7) != before.getCell(5, 7))
        }
        let buffer = Buffer(Rect(0, 0, 5, 3))
        buffer.setString(0, 0, "界")
        let before = buffer.copy()
        _ = Block().renderInner(Rect(1, 0, 1, 3), buffer)
        @Expect(buffer.getCell(0, 0), before.getCell(0, 0))
        @Expect(buffer.getCell(1, 0), before.getCell(1, 0))
    }

    @TestCase
    func rw02NestedClipAndExceptionalRenderRestoreTheirScope(): Unit {
        let buffer = Buffer(Rect(0, 0, 6, 3))
        buffer.setString(0, 0, "界")
        let before = buffer.copy()
        let area = Rect(1, 0, 1, 3)
        Canvas(buffer, area).render(round2Widget(0), buffer.area)
        @Expect(round2RegionUnchanged(before, buffer, area))
        let broken = VirtualTable([TableColumn("x")], 1, { _ => throw Exception("expected provider failure") })
        @ExpectThrows(broken.render(Rect(2, 0, 2, 3), buffer))
        buffer.setString(0, 2, "!")
        @Expect(buffer.getCell(0, 2).symbol, "!")
    }

    @TestCase
    func rw03HighlightsKeepCombiningClustersForEveryWrapMode(): Unit {
        let accent = "A\u{0301}"
        for (wrap in [WrapMode.NoWrap, WrapMode.Character, WrapMode.Word]) {
            for (width in [Int64(1), 3]) {
                for (query in ["A", "\u{0301}", accent, "\u{0301}B"]) {
                    let area = Rect(0, 0, width, 4)
                    let plain = Buffer(area)
                    let highlighted = Buffer(area)
                    DocumentView(Document.plain(accent + "B"), wrap: wrap).render(area, plain)
                    DocumentView(Document.plain(accent + "B"), wrap: wrap,
                        highlights: [DocumentHighlight(query, style: Style(fg: Color.Red))]).render(area, highlighted)
                    for (y in 0..area.height) {
                        for (x in 0..area.width) {
                            @Expect(highlighted.getCell(x, y).symbol, plain.getCell(x, y).symbol)
                        }
                    }
                    @Expect(highlighted.getCell(0, 0).symbol, accent)
                    @Expect(highlighted.getCell(0, 0).style, Style(fg: Color.Red))
                }
            }
        }
    }

    @TestCase
    func rw03HighlightPreservesJoinedEmojiFlagsAndMetadata(): Unit {
        let cases: Array<(String, String)> = [
            ("\u{1F469}\u{200D}\u{1F4BB}", "\u{1F4BB}"),
            ("\u{1F1E8}\u{1F1F3}", "\u{1F1F3}")
        ]
        for ((cluster, query) in cases) {
            let document = Document([DocumentLine(DocumentLineKind.Paragraph, [
                RichSpan(cluster + "B", style: Style(fg: Color.Blue),
                    linkUrl: Some("https://example.test/item"), sourceRange: Some("10:30"))
            ])])
            let view = DocumentView(document, wrap: WrapMode.Character,
                highlights: [DocumentHighlight(query, style: Style(bg: Color.Yellow))])
            let buffer = Buffer(Rect(0, 0, 2, 3))
            view.render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 0).symbol, cluster)
            @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Blue, bg: Color.Yellow))
            @Expect(buffer.getCell(0, 1).symbol, "B")
            @Expect(buffer.getCell(0, 1).style, Style(fg: Color.Blue))
            @Expect(view.sourceOffsetForRenderedLine(2, 0), Some(Int64(10)))
            @Expect(view.linkAtRenderedLine(2, 0), Some("https://example.test/item"))
        }
    }

    @TestCase
    func rw04PaletteConsumesParsedAssociatedText(): Unit {
        let palette = CommandPalette([MenuItem("AåA\u{0301}", action: "chosen")])
        let input = Input()
        let editor = TextArea()
        for (sequence in ["\u{1B}[97;2;65u", "\u{1B}[0;;229u", "\u{1B}[0;;65:769u"]) {
            for (event in EventParser().push(unsafe { sequence.rawData() })) {
                match (event) {
                    case Event.KeyDown(key) =>
                        _ = palette.handle(key)
                        _ = input.handle(key)
                        _ = editor.handle(key)
                    case _ => ()
                }
            }
        }
        @Expect(palette.query, "AåA\u{0301}")
        @Expect(palette.query, input.value)
        @Expect(palette.query, editor.value)
        @Expect(palette.handle(KeyEvent(KeyCode.Enter, text: Some("ignored"))), Some("chosen"))
        @Expect(palette.query, "AåA\u{0301}")
    }

    @TestCase
    func rw04PaletteRetainsCodeBasedEditingAndFallback(): Unit {
        let palette = CommandPalette([MenuItem("ab", action: "chosen")])
        _ = palette.handle(KeyEvent(KeyCode.Char(r'a')))
        _ = palette.handle(KeyEvent(KeyCode.Char(r'x'), text: Some("b")))
        @Expect(palette.query, "ab")
        _ = palette.handle(KeyEvent(KeyCode.Backspace, text: Some("ignored")))
        @Expect(palette.query, "a")
        _ = palette.handle(KeyEvent(KeyCode.Esc, text: Some("ignored")))
        @Expect(palette.query, "a")
    }

    @TestCase
    func rw05ExhaustedHorizontalPaddingSuppressesBodyInsideBothCardModes(): Unit {
        let paddings = [Spacing(left: 4), Spacing(left: 6), Spacing(right: 4),
            Spacing(left: 2, right: 2), Spacing(left: Int64.Max, right: Int64.Max)]
        for (fullFrame in [false, true]) {
            for (padding in paddings) {
                let source = Round2PaddingSource()
                let view = VirtualTranscriptView(source, state: VirtualTranscriptState(followBottom: false))
                view.setCardChrome(fullFrame)
                view.setCardTheme(TranscriptCardTheme(fullFrame: fullFrame, fillBackground: true,
                    contentPadding: padding))
                let buffer = Buffer(Rect(0, 0, 12, 8))
                buffer.fill(buffer.area, Cell("."))
                let before = buffer.copy()
                let area = Rect(1, 1, 4, 6)
                view.render(area, buffer)
                @Expect(round2RegionUnchanged(before, buffer, area))
                for (y in 0..buffer.area.height) {
                    for (x in 0..buffer.area.width) { @Expect(buffer.getCell(x, y).symbol != "x") }
                }
                @Assert(source.widths.size > 0)
                @Expect(source.widths[0], 1)
            }
        }
    }

    @TestCase
    func rw05PaddingControlAndThemeUpdatesKeepBodyInItsViewport(): Unit {
        let source = Round2PaddingSource()
        let state = VirtualTranscriptState(followBottom: false)
        let view = VirtualTranscriptView(source, state: state)
        let area = Rect(1, 1, 4, 3)
        for (left in [Int64(1), 6, 1]) {
            view.setCardTheme(TranscriptCardTheme(fillBackground: true,
                contentPadding: Spacing(left: left, top: 1, bottom: 1)))
            let buffer = Buffer(Rect(0, 0, 12, 6))
            let before = buffer.copy()
            view.render(area, buffer)
            @Expect(round2RegionUnchanged(before, buffer, area))
            @Expect(buffer.getCell(2, 2).symbol, if (left == 1) { "x" } else { " " })
        }
        @Expect(source.widths.toArray(), [3, 1, 3])
    }
}
