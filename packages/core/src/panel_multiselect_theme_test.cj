package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PanelMultiSelectThemeTest {
    @TestCase
    func multiSelectInheritsAndRespectsExplicitStyles(): Unit {
        let appTheme = Theme(normal: Style(fg: Color.Yellow, bg: Color.Blue),
            selected: Style(fg: Color.Green, bg: Color.White))
        let buffer = Buffer(Rect(0, 0, 12, 3))
        buffer.setTheme(appTheme)
        MultiSelect(["one", "two"], cursor: 0, selected: [1]).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, appTheme.selected)
        @Expect(buffer.getCell(0, 1).style, appTheme.normal)
        @Expect(buffer.getCell(1, 0).symbol, " ")
        @Expect(buffer.getCell(1, 1).symbol, "x")
        MultiSelect(["one", "two"], style: Style.default(), selectedStyle: Style(fg: Color.Red))
            .render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
        @Expect(buffer.getCell(0, 1).style, Style.default())
        let plain = Buffer(Rect(0, 0, 12, 2))
        MultiSelect(["one", "two"]).render(plain.area, plain)
        @Expect(plain.getCell(0, 0).style, Style(fg: Color.Black, bg: Color.White))
        @Expect(plain.getCell(0, 1).style, Style.default())
    }

    @TestCase
    func panelThemeReachesChildAndDoesNotLeakToSibling(): Unit {
        let appTheme = Theme(normal: Style(fg: Color.Red, bg: Color.White), borderKind: BorderKind.NoBorder)
        let local = Theme(normal: Style(fg: Color.Green, bg: Color.Blue), borderKind: BorderKind.Ascii)
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setTheme(appTheme)
        Panel(BlockOptions(theme: local), child: Paragraph("text")).render(Rect(0, 0, 12, 3), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
        @Expect(buffer.getCell(1, 1).style, local.normal)
        Paragraph("sibling").render(Rect(0, 3, 12, 1), buffer)
        @Expect(buffer.getCell(0, 3).style, appTheme.normal)
    }

    @TestCase
    func nestedPanelsAndChildThemeUseNearestExplicitTheme(): Unit {
        let appTheme = Theme(normal: Style(fg: Color.Red), borderKind: BorderKind.NoBorder)
        let outer = Theme(normal: Style(fg: Color.Green), borderKind: BorderKind.Ascii)
        let inner = Theme(normal: Style(fg: Color.Blue), borderKind: BorderKind.NoBorder)
        let childTheme = Theme(normal: Style(fg: Color.Magenta), selected: Style(bg: Color.Cyan))
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setTheme(appTheme)
        let child = MultiSelect(["one", "two"], theme: childTheme)
        let nested = Panel(BlockOptions(theme: inner), child: child)
        Panel(BlockOptions(theme: outer), child: nested).render(buffer.area, buffer)
        @Expect(buffer.getCell(1, 1).style, childTheme.selected)
        @Expect(buffer.getCell(1, 2).style, childTheme.normal)
    }
}
