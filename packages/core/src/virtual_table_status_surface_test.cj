package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class VirtualTableStatusSurfaceTest {
    @TestCase
    func defaultStatusesKeepEachUnderlyingBackgroundAndSemanticForeground(): Unit {
        let theme = Theme(disabled: Style(fg: Color.White, bg: Color.Red),
            error: Style(fg: Color.Yellow, bg: Color.Red))
        for ((status, first, foreground) in [(TableStatus.Empty, "N", Color.White),
            (TableStatus.Loading, "L", Color.White), (TableStatus.Error("error"), "e", Color.Yellow)]) {
            let area = Rect(0, 0, 12, 3)
            let buffer = Buffer(area)
            buffer.fill(area, style: Style(bg: Color.Blue))
            buffer.setCell(1, 1, Cell(" ", style: Style(bg: Color.Magenta)))
            buffer.setTheme(theme)
            let table = VirtualTable([TableColumn("H")], 0, { _ => Array<String>() })
            table.setStatus(status)
            table.render(area, buffer)
            @Expect(buffer.getCell(0, 1).symbol, first)
            @Expect(buffer.getCell(0, 1).style, Style(fg: foreground, bg: Color.Blue))
            @Expect(buffer.getCell(1, 1).style, Style(fg: foreground, bg: Color.Magenta))
            @Expect(Style(bg: buffer.getCell(11, 1).style.bg), Style(bg: Color.Blue))
        }
        let filtered = Buffer(Rect(0, 0, 12, 2))
        filtered.fill(filtered.area, style: Style(bg: Color.Blue))
        let table = VirtualTable([TableColumn("H")], 1, { _ => ["data"] })
        table.setFilter("missing")
        table.render(filtered.area, filtered)
        @Expect(filtered.getCell(0, 1).symbol, "N")
        @Expect(Style(bg: filtered.getCell(0, 1).style.bg), Style(bg: Color.Blue))
    }

    @TestCase
    func explicitStatusStyleRetainsThemedAndUnthemedSemantics(): Unit {
        let area = Rect(0, 0, 8, 2)
        for (withTheme in [false, true]) {
            for (background in [Color.Red, Color.Reset]) {
                let buffer = Buffer(area)
                buffer.fill(area, style: Style(bg: Color.Blue))
                if (withTheme) { buffer.setTheme(Theme(disabled: Style(fg: Color.White, bg: Color.Magenta))) }
                let table = VirtualTable([TableColumn("H")], 0, { _ => Array<String>() },
                    statusStyle: Style(fg: Color.Green, bg: background))
                table.setStatus(TableStatus.Loading)
                table.render(area, buffer)
                let expected = match (background) {
                    case Color.Reset => if (withTheme) { Color.Magenta } else { Color.Reset }
                    case _ => background
                }
                @Expect(buffer.getCell(0, 1).style, Style(fg: Color.Green, bg: expected))
            }
        }
    }

    @TestCase
    func pagedMissingAndFailedRowsPreserveSurface(): Unit {
        let model = PagedTableModel(pageSize: 1)
        let first = model.requestViewport(0, 1)[0]
        @Assert(model.accept(first, TablePage([TableDataRow("one", ["one"])], 3)))
        let failed = model.requestViewport(1, 1)[0]
        @Assert(model.fail(failed, "failed page"))
        let area = Rect(0, 0, 12, 4)
        let buffer = Buffer(area)
        buffer.fill(area, style: Style(bg: Color.Blue))
        buffer.setCell(1, 2, Cell(" ", style: Style(bg: Color.Magenta)))
        buffer.setCell(1, 3, Cell(" ", style: Style(bg: Color.Green)))
        buffer.setTheme(Theme(disabled: Style(fg: Color.White, bg: Color.Red),
            error: Style(fg: Color.Yellow, bg: Color.Red)))
        VirtualTable([TableColumn("name", width: 12)], model).render(area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "f")
        @Expect(buffer.getCell(1, 2).style, Style(fg: Color.Yellow, bg: Color.Magenta))
        @Expect(buffer.getCell(0, 3).symbol, "L")
        @Expect(buffer.getCell(1, 3).style, Style(fg: Color.White, bg: Color.Green))
        let explicit = Buffer(area)
        explicit.fill(area, style: Style(bg: Color.Blue))
        let explicitTable = VirtualTable([TableColumn("name", width: 12)], 0, { _ => Array<String>() },
            dataModel: Some(model), statusStyle: Style(fg: Color.Green, bg: Color.Red))
        explicitTable.render(area, explicit)
        @Expect(explicit.getCell(0, 2).style, Style(fg: Color.Green, bg: Color.Red))
        @Expect(explicit.getCell(0, 3).style, Style(fg: Color.Green, bg: Color.Red))
    }

    @TestCase
    func statusWideRepairClipAndScopedOverride(): Unit {
        let bounds = Rect(0, 0, 8, 3)
        let buffer = Buffer(bounds)
        buffer.fill(bounds, style: Style(bg: Color.Blue))
        buffer.setString(0, 1, "界", style: Style(bg: Color.Blue))
        buffer.setString(2, 1, "界", style: Style(bg: Color.Blue))
        buffer.setCell(4, 1, Cell(" ", style: Style(bg: Color.Magenta)))
        let outside = buffer.getCell(0, 1)
        let straddling = buffer.getCell(1, 1)
        let table = VirtualTable([TableColumn("H")], 0, { _ => Array<String>() })
        table.setStatus(TableStatus.Error("ABCDE"))
        table.render(Rect(1, 0, 4, 2), buffer)
        @Expect(buffer.getCell(0, 1), outside)
        @Expect(buffer.getCell(1, 1), straddling)
        @Expect(buffer.getCell(2, 1).symbol, "B")
        @Expect(Style(bg: buffer.getCell(2, 1).style.bg), Style(bg: Color.Blue))
        @Expect(buffer.getCell(3, 1).symbol, "C")
        @Expect(Style(bg: buffer.getCell(3, 1).style.bg), Style(bg: Color.Blue))
        @Expect(Style(bg: buffer.getCell(4, 1).style.bg), Style(bg: Color.Magenta))
        let overridden = Buffer(bounds)
        overridden.fill(bounds, style: Style(bg: Color.Blue))
        StyledWidget(table, override: StyleOverride(bg: Color.Reset)).render(bounds, overridden)
        @Expect(Style(bg: overridden.getCell(0, 1).style.bg), Style(bg: Color.Reset))
        @Expect(Style(bg: overridden.getCell(7, 1).style.bg), Style(bg: Color.Blue))
    }
}
