package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class SupplementaryWidthRegressionTest {
    @TestCase
    func supplementaryIdeographsAreWideUnderBothPolicies(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        for (r in [r'\u{20000}', r'\u{2A6DF}', r'\u{2A700}', r'\u{2EBF0}',
                   r'\u{2F800}', r'\u{2FA1D}', r'\u{2FFFD}', r'\u{30000}',
                   r'\u{31350}', r'\u{3FFFD}']) {
            @Expect(displayWidth(r), 2)
            @Expect(displayWidth(r, options: wide), 2)
        }
    }

    @TestCase
    func supplementaryWidthDoesNotLeakAcrossPlaneBoundaries(): Unit {
        for (r in [r'\u{1FFFF}', r'\u{2FFFE}', r'\u{2FFFF}',
                   r'\u{3FFFE}', r'\u{3FFFF}', r'\u{40000}']) {
            @Expect(displayWidth(r), 1)
        }
        @Expect(displayWidth(r'\u{E0100}'), 0)
        @Expect(displayWidth(r'\u{E01EF}'), 0)
        @Expect(displayWidth("ASCII"), 5)
        @Expect(displayWidth("界"), 2)
    }

    @TestCase
    func ideographicVariationSequenceRemainsOneWideCluster(): Unit {
        let text = "\u{20000}\u{E0100}"
        let clusters = graphemeClusters(text)
        @Expect(clusters.size, 1)
        @Expect(clusters[0].text, text)
        @Expect(clusters[0].width, 2)
        @Expect(displayWidth(text), 2)
        @Expect(graphemeDisplayWidth(text), 2)
        @Expect(graphemePrefix(text, 1), "")
        @Expect(graphemePrefix(text, 2), text)
    }

    @TestCase
    func prefixAndWrapUseSupplementaryDisplayColumns(): Unit {
        let text = "A\u{20000}B"
        @Expect(displayWidth(text), 4)
        @Expect(graphemePrefix(text, 2), "A")
        @Expect(graphemePrefix(text, 3), "A\u{20000}")
        let lines = wrapText(text, 3, WrapMode.Character)
        @Assert(lines.size, 2)
        @Expect(lines[0], "A\u{20000}")
        @Expect(lines[1], "B")
    }

    @TestCase
    func canvasPlacesFollowingTextAfterTheWideContinuation(): Unit {
        let buffer = Buffer(Rect(0, 0, 5, 1))
        let canvas = Canvas(buffer, buffer.area)
        canvas.drawText(0, 0, "\u{20000}x", Style.default())
        @Expect(buffer.getCell(0, 0).symbol, "\u{20000}")
        @Expect(buffer.getCell(2, 0).symbol, "x")
        let narrow = Buffer(Rect(0, 0, 1, 1))
        Canvas(narrow, narrow.area).drawText(0, 0, "\u{20000}", Style.default())
        @Expect(narrow.getCell(0, 0).symbol, " ")
    }

    @TestCase
    func diffClearsTheOldWideContinuationAndTrailingCell(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 6, 2))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "\u{20000}x", Style.default())
        }
        @Expect(backend.assertCell(2, 0, "x"))
        let metrics = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "ax", Style.default())
        }
        @Expect(!metrics.fullRedraw)
        @Expect(backend.assertCell(0, 0, "a"))
        @Expect(backend.assertCell(1, 0, "x"))
        @Expect(backend.assertCell(2, 0, " "))
    }
}

