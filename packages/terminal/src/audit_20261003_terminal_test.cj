package terminal

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003TerminalTest {
    @TestCase
    func graphemeClustersSurviveBothWholeAndFragmentedFeeds(): Unit {
        for (fragmented in [false, true]) {
            let screen = TerminalScreen(cols: 8, rows: 2)
            if (fragmented) {
                for (part in ["e", "\u{301}", "👩", "‍", "💻", "x"]) { screen.feed(part) }
            } else { screen.feed("e\u{301}👩‍💻x") }
            @Expect(screen.cell(0, 0).symbol, "e\u{301}")
            @Expect(screen.cell(1, 0).symbol, "👩‍💻")
            @Expect(screen.cell(2, 0).symbol, "")
            @Expect(screen.cell(3, 0).symbol, "x")
        }
        let full = TerminalScreen(cols: 2, rows: 2)
        full.feed("ae")
        full.feed("\u{301}x")
        @Expect(full.cell(1, 0).symbol, "e\u{301}")
        @Expect(full.cell(0, 1).symbol, "x")

        let growing = TerminalScreen(cols: 2, rows: 3)
        growing.feed("a🇺")
        growing.feed("🇸")
        @Expect(growing.lineText(0), "a ")
        @Expect(growing.cell(0, 1).symbol, "🇺🇸")
        growing.feed("x")
        @Expect(growing.cell(0, 2).symbol, "x")

        let moved = TerminalScreen(cols: 3, rows: 1)
        moved.feed("e\r\u{301}x")
        @Expect(moved.cell(0, 0).symbol, "x")
    }

    @TestCase
    func eraseLineHonorsAllModesAndKeepsCursor(): Unit {
        for ((mode, expected) in [(0, "ab   "), (1, "   de"), (2, "     ")]) {
            let screen = TerminalScreen(cols: 5, rows: 1)
            screen.feed("abcde\u{1B}[1;3H\u{1B}[${mode}K")
            @Expect(screen.lineText(0), expected)
            screen.feed("X")
            @Expect(screen.cell(2, 0).symbol, "X")
        }
    }

    @TestCase
    func eraseDisplayHonorsModesWithoutHomingCursor(): Unit {
        for ((mode, first, second) in [(0, "abc", "d  "), (1, "   ", "  f"), (2, "   ", "   ")]) {
            let screen = TerminalScreen(cols: 3, rows: 2)
            screen.feed("abc\ndef\u{1B}[2;2H\u{1B}[${mode}J")
            @Expect(screen.lineText(0), first)
            @Expect(screen.lineText(1), second)
            screen.feed("X")
            @Expect(screen.cell(1, 1).symbol, "X")
        }
    }

    @TestCase
    func cursorPositionDefaultsEachMissingParameterIndependently(): Unit {
        let screen = TerminalScreen(cols: 3, rows: 4)
        screen.feed("\u{1B}[3HX")
        @Expect(screen.cell(0, 2).symbol, "X")
        screen.feed("\u{1B}[4;HY")
        @Expect(screen.cell(0, 3).symbol, "Y")
        screen.feed("\u{1B}[;2HZ")
        @Expect(screen.cell(1, 0).symbol, "Z")
    }
}
