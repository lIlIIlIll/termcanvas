package core

import std.unittest.*
import std.unittest.testmacro.*

class Audit20261003ThrowingTranscriptSource <: VirtualTranscriptSource {
    var revisionValue: Int64 = 0
    var failNext: Bool = false
    var calls: Int64 = 0

    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "item" }
    public func revision(_: Int64): Int64 { revisionValue }
    public func document(_: Int64, _: Int64, _: String): Document {
        calls++
        if (failNext) {
            failNext = false
            throw Exception("transient document failure")
        }
        Document.plain(if (revisionValue == 0) { "old" } else { "new" })
    }
}

@Test
class Audit20261003RenderTest {
    @TestCase
    func minRoundingRemainderDoesNotEnlargeFixedOrMaximumChunks(): Unit {
        let fixed = Layout.horizontal([
            Constraint.Min(0), Constraint.Min(0), Constraint.Length(2)
        ]).split(Rect(0, 0, 5, 1))
        @Expect(fixed[0].width, 1)
        @Expect(fixed[1].width, 2)
        @Expect(fixed[2].width, 2)
        let capped = Layout.vertical([
            Constraint.Min(0), Constraint.Min(0), Constraint.Max(0)
        ]).split(Rect(2, 3, 1, 3))
        @Expect(capped[0].height, 1)
        @Expect(capped[1].height, 2)
        @Expect(capped[2].height, 0)
    }

    @TestCase
    func layoutCacheRetriesAfterComputeFailure(): Unit {
        let cache = LayoutCache()
        let oldArea = Rect(0, 0, 2, 1)
        let newArea = Rect(0, 0, 3, 1)
        _ = cache.get(oldArea, { area => [area] })
        var failed = false
        try {
            _ = cache.get(newArea, { _ => throw Exception("transient layout failure") })
        } catch (_: Exception) {
            failed = true
        }
        @Expect(failed)
        @Expect(cache.get(newArea, { area => [area] })[0], newArea)
    }

    @TestCase
    func transcriptRetriesFailedRevisionMaterialization(): Unit {
        let source = Audit20261003ThrowingTranscriptSource()
        let view = VirtualTranscriptView(source)
        let area = Rect(0, 0, 5, 3)
        view.render(area, Buffer(area))
        source.revisionValue++
        source.failNext = true
        var failed = false
        try {
            view.render(area, Buffer(area))
        } catch (_: Exception) {
            failed = true
        }
        @Expect(failed)
        let buffer = Buffer(area)
        view.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "n")
        @Expect(source.calls, 3)
    }

    @TestCase
    func dirtyRectUnionRevisitsEarlierRectangles(): Unit {
        let dirty = DirtyRects([
            Rect(0, 0, 1, 1),
            Rect(0, 1, 2, 1),
            Rect(1, 0, 1, 2)
        ])
        @Expect(dirty.rects().size, 1)
        @Expect(dirty.cellCount(), 4)
        @Expect(dirty.rects()[0], Rect(0, 0, 2, 2))
    }

    @TestCase
    func blitPreservesRequestedSourceToDestinationTranslation(): Unit {
        let source = Buffer(Rect(2, 2, 2, 2))
        source.setString(2, 2, "AB")
        source.setString(2, 3, "CD")
        for (unchecked in [false, true]) {
            let target = Buffer(Rect(0, 0, 5, 5))
            target.fill(target.area, Cell("."))
            if (unchecked) {
                target.blitFromUnchecked(source, Rect(1, 1, 3, 3), 0, 0)
            } else {
                target.blitFrom(source, Rect(1, 1, 3, 3), 0, 0)
            }
            @Expect(target.getCell(0, 0).symbol, ".")
            @Expect(target.getCell(1, 1).symbol, "A")
            @Expect(target.getCell(2, 1).symbol, "B")
            @Expect(target.getCell(1, 2).symbol, "C")
            @Expect(target.getCell(2, 2).symbol, "D")
        }
    }

    @TestCase
    func textWidgetsDoNotRepairWideCellsOutsideTheirArea(): Unit {
        let widgets: Array<Widget> = [
            Paragraph("x"),
            Input(value: "x"),
            Tabs(["x"]),
            StatusBar(left: "x"),
            Viewport(["x"])
        ]
        for (widget in widgets) {
            let buffer = Buffer(Rect(0, 0, 6, 1))
            buffer.setString(0, 0, "界")
            buffer.setString(4, 0, "界")
            let left = buffer.getCell(0, 0)
            let right = buffer.getCell(5, 0)
            widget.render(Rect(1, 0, 4, 1), buffer)
            @Expect(buffer.getCell(0, 0), left)
            @Expect(buffer.getCell(5, 0), right)
        }
    }

}
