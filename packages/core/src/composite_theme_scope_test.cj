package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class CompositeThemeScopeTest {
    @TestCase
    func paragraphUsesApplicationNormalUnlessStyleExplicit(): Unit {
        let appTheme = Theme(normal: Style(fg: Color.Red, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 10, 3))
        buffer.setTheme(appTheme)
        Paragraph("a").render(Rect(0, 0, 10, 1), buffer)
        Paragraph("b", style: Style.default()).render(Rect(0, 1, 10, 1), buffer)
        Paragraph("c", style: Style(fg: Color.Green)).render(Rect(0, 2, 10, 1), buffer)
        @Expect(buffer.getCell(0, 0).style, appTheme.normal)
        @Expect(buffer.getCell(0, 1).style, Style.default())
        @Expect(buffer.getCell(0, 2).style, Style(fg: Color.Green))
        let plain = Buffer(Rect(0, 0, 4, 1))
        Paragraph("a").render(plain.area, plain)
        @Expect(plain.getCell(0, 0).style, Style.default())
    }

    @TestCase
    func dropdownChildUsesParentThemeWithoutGlobalModifierLeak(): Unit {
        let appTheme = Theme(normal: Style(fg: Color.Red, bg: Color.White, modifier: Modifier.strong()))
        let local = Theme(normal: Style(fg: Color.Green, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setTheme(appTheme)
        let dropdown = Dropdown(["one", "two"], open: true)
        dropdown.setVisualState(theme: local)
        dropdown.render(Rect(0, 0, 12, 3), buffer)
        @Expect(buffer.getCell(0, 2).style, local.normal)
        Paragraph("sibling").render(Rect(0, 3, 12, 1), buffer)
        @Expect(buffer.getCell(0, 3).style, appTheme.normal)
    }

    @TestCase
    func parentThemeReachesNestedBlockButChildOverrideWins(): Unit {
        let appTheme = Theme(borderKind: BorderKind.NoBorder, normal: Style(fg: Color.Green))
        let parent = Theme(borderKind: BorderKind.Ascii, border: Style(fg: Color.Red))
        let child = Theme(borderKind: BorderKind.NoBorder, canvas: Style(bg: Color.Blue))
        let area = Rect(0, 0, 10, 3)
        let buffer = Buffer(Rect(0, 0, 10, 4))
        buffer.setTheme(appTheme)
        let parentBlock = Block()
        Button("OK", theme: parent, block: parentBlock).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
        @Expect(buffer.getCell(0, 0).style, parent.border)
        @Expect(parentBlock.inner(area), Rect(1, 1, 8, 1))
        let explicitBlock = Block(BlockOptions(theme: child))
        Button("OK", theme: parent, block: explicitBlock).render(area, buffer)
        @Expect(explicitBlock.inner(area), area)
        @Expect(buffer.getCell(0, 0).symbol, " ")
        Paragraph("S").render(Rect(0, 3, 10, 1), buffer)
        @Expect(buffer.getCell(0, 3).style, appTheme.normal)
    }

    @TestCase
    func formAndDataBlocksUseTheirComponentThemeForGeometry(): Unit {
        let appTheme = Theme(borderKind: BorderKind.NoBorder)
        let parent = Theme(borderKind: BorderKind.Ascii)
        let area = Rect(0, 0, 12, 4)
        let buffer = Buffer(area)
        buffer.setTheme(appTheme)
        let radioBlock = Block()
        RadioGroup(["one"], block: radioBlock, theme: parent).render(area, buffer)
        @Expect(radioBlock.inner(area), Rect(1, 1, 10, 2))
        @Expect(buffer.getCell(0, 0).symbol, "+")
        let listBlock = Block()
        List(["one"], block: listBlock, theme: parent).render(area, buffer)
        @Expect(listBlock.inner(area), Rect(1, 1, 10, 2))
        let tableBlock = Block()
        Table(["name"], [["one"]], block: tableBlock, theme: parent).render(area, buffer)
        @Expect(tableBlock.inner(area), Rect(1, 1, 10, 2))
        let inputBlock = Block()
        let input = Input(value: "one", block: inputBlock)
        input.setVisualState(theme: parent)
        input.render(area, buffer)
        @Expect(inputBlock.inner(area), Rect(1, 1, 10, 2))
        @Expect(input.cursorPosition(area).x, 1)
    }
}
