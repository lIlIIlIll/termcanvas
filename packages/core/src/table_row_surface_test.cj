package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TableRowSurfaceTest {
    @TestCase
    func virtualDefaultRowsPreservePerCellBackgroundAndSelectedCellStyle(): Unit {
        let area = Rect(0, 0, 8, 3)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setCell(1, 1, Cell(" ", style: Style(bg: Color.Magenta)))
        let theme = Theme(normal: Style(fg: Color.Green, bg: Color.Red))
        buffer.setTheme(theme)
        let activeCell = Style(fg: Color.White, bg: Color.Yellow)
        VirtualTable([TableColumn("Name", width: 4)], 2, { i => if (i == 0) { ["AB"] } else { ["CD"] } },
            selectedRow: Some(1), cellStyle: activeCell).render(area, buffer)
        @Expect(buffer.getCell(0, 1).symbol, "A")
        @Expect(buffer.getCell(1, 1).symbol, "B")
        @Expect(buffer.getCell(0, 1).style, theme.normal.withBg(Color.Blue))
        @Expect(buffer.getCell(1, 1).style, theme.normal.withBg(Color.Magenta))
        @Expect(Style(fg: buffer.getCell(0, 2).style.fg, bg: buffer.getCell(0, 2).style.bg), activeCell)
        @Expect(buffer.getCell(0, 2).style.modifier.underline)
    }

    @TestCase
    func virtualExplicitStyleStillControlsUnselectedCellBackground(): Unit {
        let area = Rect(0, 0, 5, 2)
        for (background in [Color.Red, Color.Reset]) {
            let buffer = Buffer(area)
            buffer.fill(area, style: Style(bg: Color.Blue))
            let explicit = Style(fg: Color.Green, bg: background)
            VirtualTable([TableColumn("H")], 1, { _ => ["x"] }, style: explicit).render(area, buffer)
            @Expect(buffer.getCell(0, 1).style, explicit)
            @Expect(Style(bg: buffer.getCell(1, 1).style.bg), Style(bg: Color.Blue))
        }
    }

    @TestCase
    func virtualDefaultRowKeepsBackgroundAcrossOldWideCellsAndOverrides(): Unit {
        let area = Rect(0, 0, 5, 2)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setString(0, 1, "界", style: Style(bg: Color.Blue))
        let table = VirtualTable([TableColumn("H", width: 3)], 1, { _ => ["AB"] })
        table.render(area, buffer)
        for (x in 0..2) { @Expect(Style(bg: buffer.getCell(x, 1).style.bg), Style(bg: Color.Blue)) }
        StyledWidget(table, override: StyleOverride(bg: Color.Reset)).render(area, buffer)
        for (x in 0..2) { @Expect(Style(bg: buffer.getCell(x, 1).style.bg), Style(bg: Color.Reset)) }
    }
    @TestCase
    func tableDefaultRowsPreserveSurfaceAndFocusedSelection(): Unit {
        let area = Rect(0, 0, 8, 4)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setCell(3, 3, Cell(" ", style: Style(bg: Color.Magenta)))
        let theme = Theme(normal: Style(fg: Color.Green, bg: Color.Red))
        buffer.setTheme(theme)
        let selected = Style(fg: Color.White, bg: Color.Yellow)
        Table(["H"], [["one"], ["AB"]], widths: [4], state: TableState(selectedRow: Some(0)),
            selectedStyle: selected, focused: true).render(area, buffer)
        @Expect(buffer.getCell(2, 3).symbol, "A")
        @Expect(buffer.getCell(3, 3).symbol, "B")
        @Expect(buffer.getCell(2, 3).style, theme.normal.withBg(Color.Blue))
        @Expect(buffer.getCell(3, 3).style, theme.normal.withBg(Color.Magenta))
        @Expect(Style(bg: buffer.getCell(0, 2).style.bg), Style(bg: Color.Yellow))
        @Expect(buffer.getCell(2, 2).style.modifier.underline)
    }

    @TestCase
    func tableExplicitResetRetainsLegacyThemeMerge(): Unit {
        let area = Rect(0, 0, 5, 3)
        let explicit = Style(fg: Color.Green, bg: Color.Reset)
        let plain = Buffer(area)
        plain.fill(area, style: Style(bg: Color.Blue))
        Table(["H"], [["x"]], style: explicit).render(area, plain)
        @Expect(plain.getCell(0, 2).style, explicit)
        let themed = Buffer(area)
        themed.fill(area, style: Style(bg: Color.Blue))
        themed.setTheme(Theme(normal: Style(fg: Color.White, bg: Color.Magenta)))
        Table(["H"], [["x"]], style: explicit).render(area, themed)
        @Expect(themed.getCell(0, 2).style, Style(fg: Color.Green, bg: Color.Magenta))
        let colored = Buffer(area)
        colored.fill(area, style: Style(bg: Color.Blue))
        Table(["H"], [["x"]], style: Style(bg: Color.Red)).render(area, colored)
        @Expect(Style(bg: colored.getCell(0, 2).style.bg), Style(bg: Color.Red))
    }

    @TestCase
    func tableDefaultRowPreservesOldWideCellsAndScopedOverride(): Unit {
        let area = Rect(0, 0, 5, 3)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setString(0, 2, "界", style: Style(bg: Color.Blue))
        let table = Table(["H"], [["AB"]], widths: [3])
        table.render(area, buffer)
        for (x in 0..5) { @Expect(Style(bg: buffer.getCell(x, 2).style.bg), Style(bg: Color.Blue)) }
        StyledWidget(table, override: StyleOverride(bg: Color.Reset)).render(area, buffer)
        for (x in 0..5) { @Expect(Style(bg: buffer.getCell(x, 2).style.bg), Style(bg: Color.Reset)) }
    }

    @TestCase
    func virtualExplicitResetRetainsThemeMerge(): Unit {
        let area = Rect(0, 0, 5, 2)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setTheme(Theme(normal: Style(fg: Color.White, bg: Color.Magenta)))
        VirtualTable([TableColumn("H")], 1, { _ => ["x"] },
            style: Style(fg: Color.Green, bg: Color.Reset)).render(area, buffer)
        @Expect(buffer.getCell(0, 1).style, Style(fg: Color.Green, bg: Color.Magenta))
    }
}
