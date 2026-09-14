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
            @Expect(displayWidth(runeToString(r)), 2)
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
        @Expect(truncate(text, 2), "A")
        @Expect(truncate(text, 3), "A\u{20000}")
        let lines = wrapText(text, 3, WrapMode.Character)
        @Expect(lines.size, 2)
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

@Test
class DirtyRectsAuditRegressionTest {
    @TestCase
    func expandedUnionRevisitsEarlierRectangles(): Unit {
        let a = Rect(0, 0, 1, 1)
        let b = Rect(2, 0, 1, 2)
        let c = Rect(0, 1, 3, 1)
        for (order in [[a, b, c], [a, c, b], [b, a, c],
                      [b, c, a], [c, a, b], [c, b, a]]) {
            let dirty = DirtyRects(order)
            @Expect(dirty.rects().size, 1)
            @Expect(dirty.cellCount(), 6)
            @Expect(dirty.covers(Rect(0, 0, 3, 2)))
        }
    }

    @TestCase
    func sparseInvalidationsHaveABoundedRectangleCount(): Unit {
        let dirty = DirtyRects()
        for (i in 0..MAX_DIRTY_RECTS) {
            dirty.add(Rect(i * 3, 0, 1, 1))
        }
        @Expect(dirty.rects().size, MAX_DIRTY_RECTS)
        @Expect(dirty.cellCount(), MAX_DIRTY_RECTS)
        dirty.add(Rect(MAX_DIRTY_RECTS * 3, 0, 1, 1))
        @Expect(dirty.rects().size, 1)
        for (i in (MAX_DIRTY_RECTS + 1)..4096) {
            dirty.add(Rect(i * 3, 0, 1, 1))
            @Expect(dirty.rects().size, 1)
        }
        @Expect(dirty.covers(Rect(0, 0, 4095 * 3 + 1, 1)))
        @Expect(!dirty.intersectsCell(0, 1))
        @Expect(!dirty.intersectsCell(4095 * 3 + 1, 0))
    }

    @TestCase
    func copyPreservesCoalescingWithoutAliasingTheOriginal(): Unit {
        let original = DirtyRects()
        for (i in 0..(MAX_DIRTY_RECTS + 1)) {
            original.add(Rect(i * 3, 0, 1, 1))
        }
        let copied = original.copy()
        copied.add(Rect(1000, 2, 1, 1))
        @Expect(copied.rects().size, 1)
        @Expect(copied.intersectsCell(1000, 2))
        @Expect(!original.intersectsCell(1000, 2))
        @Expect(original.cellCount(), MAX_DIRTY_RECTS * 3 + 1)
    }

    @TestCase
    func clearRestoresFineGrainedTrackingAndEmptyAddsAreIgnored(): Unit {
        let dirty = DirtyRects()
        for (i in 0..(MAX_DIRTY_RECTS + 1)) {
            dirty.add(Rect(i * 3, 0, 1, 1))
        }
        dirty.add(Rect(-100, -100, 0, 1))
        @Expect(dirty.rects()[0].x, 0)
        dirty.clear()
        @Expect(dirty.isEmpty())
        @Expect(dirty.cellCount(), 0)
        dirty.add(Rect(0, 0, 1, 1))
        dirty.add(Rect(3, 0, 1, 1))
        @Expect(dirty.rects().size, 2)
        @Expect(!dirty.intersectsCell(1, 0))
        let copied = dirty.copy()
        copied.addAll(copied)
        @Expect(copied.rects().size, 2)
        @Expect(copied.cellCount(), 2)
        @Expect(dirty.rects().size, 2)
    }

    @TestCase
    func coalescedPartialPaintMatchesFullPaintAndPreservesOtherRows(): Unit {
        let viewport = Rect(0, 0, 210, 3)
        let partialBackend = TestBackend(area: viewport)
        let partial = Terminal(partialBackend, renderMode: RenderMode.Diff)
        _ = partial.draw { frame => paintFragmentedAuditFrame(frame, false) }
        let dirty = DirtyRects()
        for (i in 0..65) { dirty.add(Rect(i * 3, 1, 1, 1)) }
        @Expect(dirty.rects().size, 1)
        let metrics = partial.draw({ frame =>
            paintFragmentedAuditFrame(frame, true)
        }, dirtyRects: Some(dirty))
        let fullBackend = TestBackend(area: viewport)
        let full = Terminal(fullBackend, renderMode: RenderMode.Diff)
        _ = full.draw { frame => paintFragmentedAuditFrame(frame, true) }
        @Expect(partialBackend.snapshot(), fullBackend.snapshot())
        @Expect(partialBackend.assertCell(1, 1, "."))
        @Expect(partialBackend.assertCell(209, 1, "."))
        @Expect(partialBackend.assertCell(0, 0, "h"))
        @Expect(partialBackend.assertCell(0, 2, "f"))
        @Expect(!metrics.fullRedraw)
        @Expect(metrics.copiedCells <= dirty.cellCount() + 2)
        @Expect(metrics.dirtyCells, 65)
    }
}

func paintFragmentedAuditFrame(frame: Frame, changed: Bool): Unit {
    frame.canvas().drawText(0, 0, "header", Style.default())
    for (x in 0..frame.area.width) {
        let symbol = if (changed && x <= 192 && x % 3 == 0) { "X" } else { "." }
        frame.canvas().drawText(x, 1, symbol, Style.default())
    }
    frame.canvas().drawText(0, 2, "footer", Style.default())
}
