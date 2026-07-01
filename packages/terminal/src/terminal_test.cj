package terminal

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalExtensionTest {
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
