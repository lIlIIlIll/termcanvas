package terminal

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalExtensionTest {
    @TestCase
    func screenCroppingCopiesOnlyCompleteWideGlyphs(): Unit {
        let screen = TerminalScreen(cols: 3, rows: 1)
        screen.feed("\u{1B}[31ma中")
        let red = Style(fg: Color.Red)
        let sentinel = Cell("Z", style: Style(bg: Color.Blue))
        for (width in 1..4) {
            let target = Buffer(Rect(0, 0, 5, 1))
            target.fill(target.area, sentinel)
            // Repainting an existing wide pair must also preserve the lead.
            for (_ in 0..2) { screen.render(Rect(1, 0, width, 1), target) }
            @Expect(target.getCell(0, 0), sentinel)
            @Expect(target.getCell(1, 0), Cell("a", style: red))
            if (width == 2) { @Expect(target.getCell(2, 0), Cell(" ", style: red)) }
            if (width == 3) {
                @Expect(target.getCell(2, 0), Cell("中", style: red, kind: CellKind.WideLead))
                @Expect(target.getCell(3, 0), Cell("", style: red, kind: CellKind.WideCont))
            }
            @Expect(target.getCell(1 + width, 0), sentinel)
        }
    }

    @TestCase
    func screenPhysicalEdgesDoNotCopyPartialWideGlyphs(): Unit {
        let screen = TerminalScreen(cols: 3, rows: 1)
        screen.feed("\u{1B}[31m中a")
        let red = Style(fg: Color.Red)
        let sentinel = Cell("Z", style: Style(bg: Color.Blue))
        let left = Buffer(Rect(0, 0, 3, 1))
        left.fill(left.area, sentinel)
        screen.render(Rect(-1, 0, 3, 1), left)
        @Expect(left.getCell(0, 0), Cell(" ", style: red))
        @Expect(left.getCell(1, 0), Cell("a", style: red))
        @Expect(left.getCell(2, 0), sentinel)
        let right = Buffer(Rect(0, 0, 3, 1))
        right.fill(right.area, sentinel)
        screen.render(Rect(2, 0, 3, 1), right)
        @Expect(right.getCell(0, 0), sentinel)
        @Expect(right.getCell(1, 0), sentinel)
        @Expect(right.getCell(2, 0), Cell(" ", style: red))

        let transcript = TerminalTranscript(cols: 3, rows: 1)
        transcript.append("\u{1B}[31m中a")
        let narrowView = Buffer(Rect(0, 0, 3, 1))
        narrowView.fill(narrowView.area, sentinel)
        TerminalView(transcript, search: "中").render(Rect(0, 0, 1, 1), narrowView)
        @Expect(narrowView.getCell(0, 0), Cell(" ", style: red))
        @Expect(narrowView.getCell(1, 0), sentinel)
    }

    @TestCase
    func fragmentedControlsStayBoundedAndKeepTheirState(): Unit {
        @Expect(parseAnsi("\u{1B}").size, 0)
        @Expect(parseAnsi("\u{1B}]0;title\u{7}").size, 0)
        let screen = TerminalScreen(cols: 8, rows: 2)
        screen.feed("\u{1B}")
        screen.feed("[31")
        screen.feed("mX\u{1B}]0;title")
        screen.feed("\u{1B}")
        screen.feed("\\Y")
        @Expect(screen.cell(0, 0), Cell("X", style: Style(fg: Color.Red)))
        @Expect(screen.cell(1, 0), Cell("Y", style: Style(fg: Color.Red)))
        var longParameter = ""
        for (_ in 0..5000) { longParameter += "9" }
        screen.feed("\u{1B}[" + longParameter + "mZ")
        @Expect(screen.cell(2, 0).symbol, "Z")
    }

    @TestCase
    func fullRowsDelayWrappingUntilTheNextPrintableCharacter(): Unit {
        let screen = TerminalScreen(cols: 3, rows: 3)
        screen.feed("abc\nX")
        @Expect(screen.cell(0, 1).symbol, "X")
        @Expect(screen.cell(0, 2).symbol, " ")
        let wrapped = TerminalScreen(cols: 3, rows: 2)
        wrapped.feed("abc")
        wrapped.feed("d")
        @Expect(wrapped.cell(0, 1).symbol, "d")
        let carriage = TerminalScreen(cols: 3, rows: 2)
        carriage.feed("abc\rZ")
        @Expect(carriage.cell(0, 0).symbol, "Z")
        @Expect(carriage.cell(0, 1).symbol, " ")
    }

    @TestCase
    func unicodeSearchUsesScreenColumnsAndPreservesWideCells(): Unit {
        let transcript = TerminalTranscript(cols: 8, rows: 2)
        transcript.append("中x中")
        let ascii = Buffer(Rect(0, 0, 8, 2))
        TerminalView(transcript, search: "x").render(ascii.area, ascii)
        @Expect(ascii.getCell(2, 0), Cell("x", style: Style(bg: Color.Yellow)))
        let wide = Buffer(Rect(0, 0, 8, 2))
        TerminalView(transcript, search: "中").render(wide.area, wide)
        @Expect(wide.getCell(0, 0), Cell("中", style: Style(bg: Color.Yellow), kind: CellKind.WideLead))
        @Expect(wide.getCell(1, 0), Cell("", style: Style(bg: Color.Yellow), kind: CellKind.WideCont))
        @Expect(wide.getCell(3, 0), Cell("中", style: Style(bg: Color.Yellow), kind: CellKind.WideLead))
    }

    @TestCase
    func parsesSgrAndTextTokens(): Unit {
        let tokens = parseAnsi("a\u{1B}[31mb")
        @Expect(tokens.size, 3)
        match (tokens[1].kind) {
            case AnsiTokenKind.Sgr => @Expect(true)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func screenHandlesColorCarriageReturnAndErase(): Unit {
        let screen = TerminalScreen(cols: 10, rows: 3)
        screen.feed("abc\r\u{1B}[31mZ\u{1B}[0m\nnext")
        @Expect(screen.cell(0, 0).symbol, "Z")
        @Expect(screen.cell(0, 0).style, Style(fg: Color.Red))
        @Expect(screen.cell(0, 1).symbol, "n")

        screen.feed("\u{1B}[2J")
        @Expect(screen.cell(0, 0).symbol, " ")
        @Expect(screen.cell(0, 1).symbol, " ")
    }

    @TestCase
    func transcriptAndViewRenderVisibleScreen(): Unit {
        let transcript = TerminalTranscript(cols: 12, rows: 3)
        transcript.append("hello\nworld")
        @Expect(transcript.chunkCount(), 1)

        let buffer = Buffer(Rect(0, 0, 12, 3))
        TerminalView(transcript).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "h")
        @Expect(buffer.getCell(0, 1).symbol, "w")
    }

    @TestCase
    func transcriptTrimsChunksAndViewHighlightsSearch(): Unit {
        let transcript = TerminalTranscript(cols: 16, rows: 3, maxChunks: 2)
        transcript.append("first\n")
        transcript.append("second\n")
        transcript.append("third")
        @Expect(transcript.chunkCount(), 2)

        let buffer = Buffer(Rect(0, 0, 16, 3))
        TerminalView(transcript, search: "third").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "t")
        match (buffer.getCell(0, 2).style.bg) {
            case Color.Yellow => @Expect(true)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func screenHandlesBrightAndBackgroundColors(): Unit {
        let screen = TerminalScreen(cols: 12, rows: 2)
        screen.feed("\u{1B}[92;44mX")
        @Expect(screen.cell(0, 0).style, Style(fg: Color.Indexed(10), bg: Color.Blue))
        screen.feed("\u{1B}[39;49mY")
        @Expect(screen.cell(1, 0).style, Style.default())
    }
}
