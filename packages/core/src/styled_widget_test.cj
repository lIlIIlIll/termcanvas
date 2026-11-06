package core

import std.unittest.*
import std.unittest.testmacro.*

private class StyledPathsWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        let sourceStyle = Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong())
        buffer.fill(area, Cell(".", style: sourceStyle))
        buffer.setCell(area.x, area.y, Cell("A", style: sourceStyle))
        buffer.setString(area.x + 1, area.y, "界", style: sourceStyle)
        let source = Buffer(Rect(0, 0, 2, 1))
        source.setString(0, 0, "界", style: sourceStyle)
        buffer.blitFrom(source, source.area, area.x + 3, area.y)
        let surface = Surface(Rect(area.x, area.y + 1, 2, 1))
        surface.bufferView().setString(area.x, area.y + 1, "OK", style: sourceStyle)
        Canvas(buffer, area).composite(surface)
        buffer.setString(area.right, area.y, "outside", style: sourceStyle)
    }
}

private class StyledNestedWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        let base = Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong())
        buffer.setString(area.x, area.y, "a", style: base)
        StyledWidget(StyledSingleWidget(), override: StyleOverride(fg: Color.Red, bold: true))
            .render(Rect(area.x + 1, area.y, 1, 1), buffer)
        buffer.setString(area.x + 2, area.y, "c", style: base)
    }
}

private class StyledSingleWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.setString(area.x, area.y, "b", style: Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong()))
    }
}

private class StyledThrowWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.clear(style: Style(bg: Color.Blue))
        throw Exception("expected")
    }
}

private class StyledMediaWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.addMedia(MediaPlacement("image", MediaSource("source", "example.test/image"), area))
    }
}

private class StyledRowWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.setString(area.x, area.y, "XXXXXX", style: Style(fg: Color.Red, bg: Color.Blue))
    }
}

@Test
class StyledWidgetTest {
    @TestCase
    func stylesEveryWritePathAndClipsWithoutRepaintingUntouchedCells(): Unit {
        let buffer = Buffer(Rect(0, 0, 12, 4))
        let old = Cell("#", style: Style(bg: Color.Yellow))
        buffer.fill(buffer.area, old)
        let target = Rect(1, 1, 8, 2)
        StyledWidget(StyledPathsWidget(), override: StyleOverride(bg: Color.Reset, bold: false)).render(target, buffer)
        let expected = Style(fg: Color.Green)
        @Expect(buffer.getCell(1, 1), Cell("A", style: expected))
        @Expect(buffer.getCell(2, 1), Cell("界", style: expected, kind: CellKind.WideLead))
        @Expect(buffer.getCell(3, 1), Cell("", style: expected, kind: CellKind.WideCont))
        @Expect(buffer.getCell(4, 1), Cell("界", style: expected, kind: CellKind.WideLead))
        @Expect(buffer.getCell(5, 1), Cell("", style: expected, kind: CellKind.WideCont))
        @Expect(buffer.getCell(1, 2), Cell("O", style: expected))
        @Expect(buffer.getCell(2, 2), Cell("K", style: expected))
        @Expect(buffer.getCell(8, 1), Cell(".", style: expected))
        @Expect(buffer.getCell(9, 1), old)
        @Expect(buffer.getCell(0, 0), old)
    }

    @TestCase
    func nestedOverridesArePerFieldAndRestoreOuterScope(): Unit {
        let buffer = Buffer(Rect(0, 0, 4, 1))
        let wrapped = StyledWidget(StyledNestedWidget(), override: StyleOverride(bg: Color.Reset, bold: false))
        wrapped.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Green))
        @Expect(buffer.getCell(1, 0).style, Style(fg: Color.Red, modifier: Modifier.strong()))
        @Expect(buffer.getCell(2, 0).style, Style(fg: Color.Green))
        StyledSingleWidget().render(Rect(3, 0, 1, 1), buffer)
        @Expect(buffer.getCell(3, 0).style, Style(fg: Color.Green, bg: Color.Blue, modifier: Modifier.strong()))
    }

    @TestCase
    func exceptionRestoresBothStyleAndClipAndClearStaysInsideArea(): Unit {
        let buffer = Buffer(Rect(0, 0, 6, 1))
        buffer.fill(buffer.area, Cell("#"))
        let bad = StyledWidget(StyledThrowWidget(), override: StyleOverride(bg: Color.Reset))
        @ExpectThrows[Exception](bad.render(Rect(1, 0, 3, 1), buffer))
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(1, 0), Cell(" "))
        @Expect(buffer.getCell(4, 0).symbol, "#")
        buffer.setString(5, 0, "x", style: Style(bg: Color.Blue))
        @Expect(buffer.getCell(5, 0), Cell("x", style: Style(bg: Color.Blue)))
    }

    @TestCase
    func mediaPlacementsRemainUnmodified(): Unit {
        let buffer = Buffer(Rect(0, 0, 5, 1))
        StyledWidget(StyledMediaWidget(), override: StyleOverride(bg: Color.Reset)).render(buffer.area, buffer)
        @Expect(buffer.mediaPlacements().size, 1)
        @Expect(buffer.mediaPlacements()[0].id, "image")
        @Expect(buffer.mediaPlacements()[0].area, buffer.area)
    }

    @TestCase
    func terminalDirtyRegionDoesNotRestyleOtherCells(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 6, 1))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => frame.fill(frame.area, Style(bg: Color.Yellow)) }
        _ = terminal.draw({ frame => frame.renderWidget(
            StyledWidget(StyledRowWidget(), override: StyleOverride(bg: Color.Reset)), frame.area) },
            dirtyRects: DirtyRects([Rect(2, 0, 2, 1)]))
        // Terminal expands each dirty edge by one cell for wide-glyph safety.
        @Expect(backend.assertCell(0, 0, " ", style: Style(bg: Color.Yellow)))
        @Expect(backend.assertCell(1, 0, "X", style: Style(fg: Color.Red)))
        @Expect(backend.assertCell(2, 0, "X", style: Style(fg: Color.Red)))
        @Expect(backend.assertCell(3, 0, "X", style: Style(fg: Color.Red)))
        @Expect(backend.assertCell(4, 0, "X", style: Style(fg: Color.Red)))
        @Expect(backend.assertCell(5, 0, " ", style: Style(bg: Color.Yellow)))
    }
}
