package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class StatusScrollbarVisualTest {
    @TestCase
    func statusBarShowsOmissionAndSeparatesSidesAtNonzeroOrigin(): Unit {
        let buffer = Buffer(Rect(0, 0, 30, 3))
        buffer.fill(buffer.area, Cell("!"))
        let area = Rect(3, 1, 20, 1)
        StatusBar(left: "Terminal focus lost", right: "LOCAL DEMO").render(area, buffer)
        @Expect(buffer.getCell(2, 1).symbol, "!")
        @Expect(buffer.getCell(3, 1).symbol, "T")
        @Expect(buffer.getCell(11, 1).symbol, "…")
        @Expect(buffer.getCell(12, 1).symbol, " ")
        @Expect(buffer.getCell(13, 1).symbol, "L")
        @Expect(buffer.getCell(22, 1).symbol, "O")
        @Expect(buffer.getCell(23, 1).symbol, "!")
    }

    @TestCase
    func statusBarRespectsGraphemesAndCurrentWidthPolicy(): Unit {
        let area = Rect(2, 1, 8, 1)
        let buffer = Buffer(Rect(0, 0, 12, 3))
        StatusBar(left: "e\u{301}界👩\u{200D}💻XYZ", right: "R").render(area, buffer)
        @Expect(buffer.getCell(2, 1).symbol, "e\u{301}")
        @Expect(buffer.getCell(3, 1).symbol, "界")
        @Expect(buffer.getCell(5, 1).symbol, "👩\u{200D}💻")
        @Expect(buffer.getCell(7, 1).symbol, "…")
        @Expect(buffer.getCell(8, 1).symbol, " ")
        @Expect(buffer.getCell(9, 1).symbol, "R")
        let wide = Buffer(Rect(0, 0, 12, 3))
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        StatusBar(left: "·界long", right: "R").render(area, wide)
        @Expect(wide.getCell(2, 1).symbol, "·")
        @Expect(wide.getCell(4, 1).symbol, "界")
        @Expect(wide.getCell(7, 1).symbol, ".")
        @Expect(wide.getCell(8, 1).symbol, " ")
        @Expect(wide.getCell(9, 1).symbol, "R")
        let ascii = Buffer(Rect(0, 0, 12, 3))
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        StatusBar(left: "abcdefgh", right: "R").render(area, ascii)
        @Expect(ascii.getCell(7, 1).symbol, ".")
        @Expect(ascii.getCell(8, 1).symbol, " ")
    }

    @TestCase
    func statusBarHandlesTinyBudgetsAndPreservesProgress(): Unit {
        let tiny = Buffer(Rect(0, 0, 5, 2))
        StatusBar(left: "left", right: "right").render(Rect(1, 0, 3, 1), tiny)
        @Expect(tiny.getCell(1, 0).symbol, "…")
        @Expect(tiny.getCell(2, 0).symbol, " ")
        @Expect(tiny.getCell(3, 0).symbol, "…")
        StatusBar(left: "left", right: "right").render(Rect(1, 1, 1, 1), tiny)
        @Expect(tiny.getCell(1, 1).symbol, "…")
        let progress = Buffer(Rect(0, 0, 32, 1))
        StatusBar(left: "navigation", right: "ready", progress: StatusBarProgress(5, total: 10, width: 10)).render(progress.area, progress)
        @Expect(progress.getCell(16, 0).symbol, ">")
        @Expect(progress.getCell(20, 0).symbol, "5")
        @Expect(progress.getCell(25, 0).symbol, "%")
        @Expect(progress.getCell(27, 0).symbol, "r")
    }

    @TestCase
    func singleLineScrollbarShowsDirectionAndSafeFallbacks(): Unit {
        let area = Rect(2, 1, 3, 1)
        let buffer = Buffer(Rect(0, 0, 7, 3))
        buffer.fill(buffer.area, Cell("!"))
        Scrollbar(10, offset: 0, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "↓")
        @Expect(buffer.getCell(3, 1).symbol, "!")
        @Expect(buffer.getCell(5, 1).symbol, "!")
        Scrollbar(10, offset: 4, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "↕")
        Scrollbar(10, offset: 9, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "↑")
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        Scrollbar(10, offset: 0, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "v")
        Scrollbar(10, offset: 4, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, ":")
        Scrollbar(10, offset: 9, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "^")
        buffer.setCapabilities(TerminalCapabilities(unicode: true))
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        Scrollbar(10, offset: 0, viewport: 1).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "v")
        let noOverflow = Buffer(Rect(0, 0, 7, 3))
        Scrollbar(1, viewport: 1).render(area, noOverflow)
        @Expect(noOverflow.getCell(4, 1).symbol, " ")
    }

    @TestCase
    func multiLineScrollbarUsesSingleColumnUnicodeOrAscii(): Unit {
        let area = Rect(0, 0, 1, 5)
        let buffer = Buffer(area)
        let bar = Scrollbar(10, offset: 0, viewport: 2)
        bar.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "┃")
        @Expect(buffer.getCell(0, 4).symbol, "│")
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        bar.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(0, 4).symbol, "|")
        buffer.setCapabilities(TerminalCapabilities(unicode: true))
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        bar.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(0, 4).symbol, "|")
    }
}
