package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TableHeaderSurfaceTest {
    @TestCase
    func defaultTableHeaderUsesHeadingAndKeepsEachSurfaceBackground(): Unit {
        let area = Rect(0, 0, 12, 4)
        let theme = Theme(heading: Style(fg: Color.Green, bg: Color.Red, modifier: Modifier.strong()))
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setCell(5, 0, Cell(" ", style: Style(bg: Color.Magenta)))
        buffer.setCell(3, 1, Cell(" ", style: Style(bg: Color.Magenta)))
        buffer.setTheme(theme)
        Table(["Name", "State"], [["one", "ok"]], widths: [4, 5]).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "N")
        @Expect(buffer.getCell(5, 0).symbol, "S")
        @Expect(buffer.getCell(0, 0).style, theme.heading.withBg(Color.Blue))
        @Expect(buffer.getCell(5, 0).style, theme.heading.withBg(Color.Magenta))
        @Expect(buffer.getCell(0, 1).style, theme.heading.withBg(Color.Blue))
        @Expect(buffer.getCell(3, 1).style, theme.heading.withBg(Color.Magenta))
    }

    @TestCase
    func defaultHeaderKeepsSurfaceWithoutThemeAndWithWideGlyphs(): Unit {
        let area = Rect(0, 0, 6, 2)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        Table(["界long"], [], widths: [4]).render(area, buffer)
        let expected = Style(fg: Color.Yellow, bg: Color.Blue, modifier: Modifier.strong())
        @Expect(buffer.getCell(0, 0).symbol, "界")
        @Expect(match (buffer.getCell(0, 0).kind) { case CellKind.WideLead => true; case _ => false }, true)
        @Expect(match (buffer.getCell(1, 0).kind) { case CellKind.WideCont => true; case _ => false }, true)
        @Expect(buffer.getCell(0, 0).style, expected)
        @Expect(buffer.getCell(1, 0).style, expected)
        @Expect(buffer.getCell(3, 0).symbol, "…")
        @Expect(buffer.getCell(3, 0).style, expected)
        @Expect(buffer.getCell(0, 1).style, expected)
    }

    @TestCase
    func explicitTableHeaderKeepsSpecifiedColorOrReset(): Unit {
        let area = Rect(0, 0, 8, 3)
        for (background in [Color.Red, Color.Reset]) {
            let buffer = Buffer(area)
            buffer.fill(area, style: Style(bg: Color.Blue))
            buffer.setTheme(Theme(heading: Style(fg: Color.Green, bg: Color.Magenta)))
            let explicit = Style(fg: Color.Yellow, bg: background)
            Table(["Name"], [["one"]], headerStyle: explicit).render(area, buffer)
            @Expect(buffer.getCell(0, 0).style, explicit)
            @Expect(buffer.getCell(0, 1).style, explicit)
        }
    }

    @TestCase
    func virtualTableHeaderKeepsSurfaceThroughTruncationAndSort(): Unit {
        let area = Rect(0, 0, 8, 3)
        let theme = Theme(heading: Style(fg: Color.Green, bg: Color.Red))
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setTheme(theme)
        let table = VirtualTable([TableColumn("A界BC", width: 4)], 1, { _ => ["row"] })
        table.sortBy(0)
        table.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "A")
        for (x in 0..4) { @Expect(buffer.getCell(x, 0).style, theme.heading.withBg(Color.Blue)) }
        @Expect(buffer.getCell(4, 0).style, Style(bg: Color.Blue))
    }

    @TestCase
    func oldWideGlyphsDoNotEraseBackgroundAcrossHeaderCellsOrGaps(): Unit {
        let area = Rect(0, 0, 8, 3)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setString(2, 0, "界", style: Style(bg: Color.Blue))
        buffer.setString(0, 1, "界", style: Style(bg: Color.Blue))
        buffer.setCell(4, 0, Cell(" ", style: Style(bg: Color.Magenta)))
        Table(["ABX", "Z"], [], widths: [3, 1]).render(area, buffer)
        @Expect(buffer.getCell(2, 0).symbol, "X")
        @Expect(buffer.getCell(3, 0).symbol, " ")
        @Expect(Style(bg: buffer.getCell(2, 0).style.bg), Style(bg: Color.Blue))
        @Expect(Style(bg: buffer.getCell(3, 0).style.bg), Style(bg: Color.Blue))
        @Expect(Style(bg: buffer.getCell(4, 0).style.bg), Style(bg: Color.Magenta))
        @Expect(Style(bg: buffer.getCell(0, 1).style.bg), Style(bg: Color.Blue))
        @Expect(Style(bg: buffer.getCell(1, 1).style.bg), Style(bg: Color.Blue))
    }

    @TestCase
    func virtualHeaderAndClippedBoundaryKeepOldWideBackgrounds(): Unit {
        let area = Rect(0, 0, 8, 3)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setString(0, 0, "界", style: Style(bg: Color.Blue))
        VirtualTable([TableColumn("AB", width: 3)], 0, { _ => Array<String>() }).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "A")
        @Expect(buffer.getCell(1, 0).symbol, "B")
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Blue))
        @Expect(Style(bg: buffer.getCell(1, 0).style.bg), Style(bg: Color.Blue))

        let clipped = Buffer(area)
        clipped.fill(area, style: Style(bg: Color.Blue))
        clipped.setString(0, 0, "界", style: Style(bg: Color.Blue))
        let beforeLeft = clipped.getCell(0, 0)
        let beforeRight = clipped.getCell(1, 0)
        Table(["AB"], []).render(Rect(1, 0, 4, 2), clipped)
        @Expect(clipped.getCell(0, 0), beforeLeft)
        @Expect(clipped.getCell(1, 0), beforeRight)
        @Expect(clipped.getCell(2, 0).symbol, "B")
        @Expect(Style(bg: clipped.getCell(2, 0).style.bg), Style(bg: Color.Blue))
    }
}
