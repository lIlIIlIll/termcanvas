package core

import std.unittest.*
import std.unittest.testmacro.*

private class StyledRepairProbe <: Widget {
    private let x: Int64
    init(x: Int64) { this.x = x }
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.setString(x, area.y, "x", style: Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong()))
    }
}

@Test
class StyledWideRepairTest {
    @TestCase
    func repairingEitherHalfAppliesOverridesToTheBlank(): Unit {
        let area = Rect(0, 0, 5, 1)
        let original = Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong())
        let left = Buffer(area)
        left.setString(1, 0, "界", style: original)
        StyledWidget(StyledRepairProbe(2), override: StyleOverride(bg: Color.Reset, bold: false)).render(area, left)
        @Expect(left.getCell(1, 0), Cell(" ", style: Style(fg: Color.Green)))
        @Expect(left.getCell(2, 0), Cell("x", style: Style(fg: Color.Green)))

        let right = Buffer(area)
        right.setString(1, 0, "界", style: original)
        StyledWidget(StyledRepairProbe(1), override: StyleOverride(bg: Color.Red, bold: false)).render(area, right)
        @Expect(right.getCell(1, 0), Cell("x", style: Style(fg: Color.Green, bg: Color.Red)))
        @Expect(right.getCell(2, 0), Cell(" ", style: Style(bg: Color.Red)))
    }

    @TestCase
    func clippedRepairLeavesBothWideCellsUntouched(): Unit {
        let original = Style(fg: Color.Green, bg: Color.Blue)
        for (x in [Int64(1), Int64(2)]) {
            let buffer = Buffer(Rect(0, 0, 5, 1))
            buffer.setString(1, 0, "界", style: original)
            let before = buffer.copy()
            StyledWidget(StyledRepairProbe(x), override: StyleOverride(bg: Color.Reset))
                .render(Rect(x, 0, 1, 1), buffer)
            @Expect(buffer.getCell(1, 0), before.getCell(1, 0))
            @Expect(buffer.getCell(2, 0), before.getCell(2, 0))
        }
    }

    @TestCase
    func dirtyFrameRepairsWideCellWithoutPaintingOutsideDamage(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 7, 1))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => frame.fill(frame.area, Style(bg: Color.Yellow)) }
        _ = terminal.draw({ frame =>
            frame.canvas().drawText(2, 0, "界", Style(fg: Color.Green, bg: Color.Blue))
            frame.renderWidget(StyledWidget(StyledRepairProbe(2), override: StyleOverride(bg: Color.Red)), frame.area)
        }, dirtyRects: DirtyRects([Rect(2, 0, 1, 1)]))
        @Expect(backend.assertCell(0, 0, " ", style: Style(bg: Color.Yellow)))
        @Expect(backend.assertCell(2, 0, "x", style: Style(fg: Color.Green, bg: Color.Red, modifier: Modifier.strong())))
        @Expect(backend.assertCell(3, 0, " ", style: Style(bg: Color.Red)))
        @Expect(backend.assertCell(4, 0, " ", style: Style(bg: Color.Yellow)))
    }
}
