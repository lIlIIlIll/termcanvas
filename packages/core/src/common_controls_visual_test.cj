package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class CommonControlsVisualTest {
    @TestCase
    func borderFollowsCapabilitiesUnlessExplicitlyOverridden(): Unit {
        let area = Rect(0, 0, 8, 3)
        let unicode = Buffer(area)
        Block().render(area, unicode)
        @Expect(unicode.getCell(0, 0).symbol, "╭")
        let ascii = Buffer(area)
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        Block().render(area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "+")
        Block(BlockOptions(borderKind: BorderKind.Unicode)).render(area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "┌")
        Block(BlockOptions(border: BorderSet.ascii())).render(area, unicode)
        @Expect(unicode.getCell(0, 0).symbol, "+")
        Block(BlockOptions(border: BorderSet(horizontal: "=", vertical: "!"))).render(area, unicode)
        @Expect(unicode.getCell(1, 0).symbol, "=")
    }

    @TestCase
    func boxThemeRolesAndExplicitStylesRemainDistinct(): Unit {
        let area = Rect(0, 0, 12, 3)
        let theme = Theme(
            canvas: Style(bg: Color.Blue),
            border: Style(fg: Color.Green),
            strongBorder: Style(fg: Color.Red),
            heading: Style(fg: Color.Yellow)
        )
        let buffer = Buffer(area)
        Block(BlockOptions(title: "Box", theme: Some(theme))).render(area, buffer)
        @Expect(buffer.getCell(1, 1).style, theme.canvas)
        @Expect(buffer.getCell(0, 0).style, theme.border)
        @Expect(buffer.getCell(2, 0).style, theme.heading)
        let customBackground = Style(bg: Color.White)
        Block(BlockOptions(title: "Box", theme: Some(theme), state: BoxState.Focused,
            backgroundStyle: customBackground, borderStyle: Style.default())).render(area, buffer)
        @Expect(buffer.getCell(1, 1).style, customBackground)
        @Expect(buffer.getCell(0, 0).style, Style.default())
        Block(BlockOptions(state: BoxState.Focused, theme: Some(theme))).render(area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.strongBorder)
    }

    @TestCase
    func singleLineInputKeepsCursorAndClicksInsideBoundaries(): Unit {
        let area = Rect(0, 0, 6, 1)
        let buffer = Buffer(area)
        let input = Input(value: "abcdef", cursor: 6)
        input.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "[")
        @Expect(buffer.getCell(5, 0).symbol, "]")
        @Expect(input.cursorPosition(area).x, 4)
        @Expect(input.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0), area))
        @Expect(input.cursor, 3)
        let tiny = Rect(0, 0, 1, 1)
        @Expect(input.cursorPosition(tiny).x, 0)
        let unboxed = Input(value: "ab", cursor: 1, showBoundary: false)
        @Expect(unboxed.cursorPosition(area).x, 1)
    }

    @TestCase
    func selectionMarkersFollowIconsAndHonorExplicitCharacters(): Unit {
        let area = Rect(0, 0, 12, 3)
        let asciiTheme = Theme(iconSet: IconSet.Ascii)
        let nerdTheme = Theme(iconSet: IconSet.NerdFont)
        let buffer = Buffer(area)
        List(["one"], selected: 0, theme: asciiTheme).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "*")
        List(["one"], selected: 0, theme: nerdTheme).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "\u{F111}")
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        Table(["Name"], [["one"]], state: TableState(selectedRow: 0), theme: nerdTheme).render(area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "*")
        List(["one"], selected: 0, theme: nerdTheme, selectionMarker: "XY").render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "X")
        @Expect(buffer.getCell(1, 0).symbol, "Y")
        @Expect(buffer.getCell(3, 0).symbol, "o")
        Table(["Name"], [["one"]], state: TableState(selectedRow: 0), selectionMarker: "XY").render(area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "X")
        @Expect(buffer.getCell(1, 2).symbol, "Y")
        @Expect(buffer.getCell(3, 2).symbol, "o")
        let selected = Buffer(area)
        List(["one"], selected: 0).render(area, selected)
        @Expect(selected.getCell(0, 0).style, Theme.default().selected)
        @Expect(selected.getCell(0, 0).style.modifier.bold)
    }

    @TestCase
    func listAndTableSelectionFillTheWholeRowAndShowFocus(): Unit {
        let area = Rect(0, 0, 12, 4)
        let selected = Style(fg: Color.Yellow)
        let buffer = Buffer(area)
        List(["one", "two"], selected: Some(1), selectedStyle: selected, focused: true).render(area, buffer)
        @Expect(buffer.getCell(0, 1).symbol, "●")
        @Expect(buffer.getCell(11, 1).style, selected.withModifier(buffer.getCell(11, 1).style.modifier))
        @Expect(buffer.getCell(11, 1).style.modifier.underline)
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        let table = Table(["Name"], [["item"]], state: Some(TableState(selectedRow: Some(0))), focused: true)
        table.render(area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "*")
        @Expect(buffer.getCell(11, 2).style.modifier.underline)
    }
}
