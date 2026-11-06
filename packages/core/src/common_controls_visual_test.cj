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
        @Expect(buffer.getCell(0, 1).style.modifier.underline)
        @Expect(buffer.getCell(2, 1).style.modifier.underline)
        @Expect(!buffer.getCell(1, 1).style.modifier.underline)
        @Expect(!buffer.getCell(11, 1).style.modifier.underline)
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        let table = Table(["Name"], [["item"]], state: Some(TableState(selectedRow: Some(0))), focused: true)
        table.render(area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "*")
        @Expect(buffer.getCell(0, 2).style.modifier.underline)
        @Expect(buffer.getCell(2, 2).style.modifier.underline)
        @Expect(!buffer.getCell(1, 2).style.modifier.underline)
        @Expect(!buffer.getCell(11, 2).style.modifier.underline)
    }

    @TestCase
    func selectionPaddingPreservesColorsAndOtherExplicitModifiers(): Unit {
        var modifier = Modifier.none()
        modifier.underline = true
        modifier.italic = true
        let custom = Style(fg: Color.Yellow, bg: Color.Blue, modifier: modifier)
        var paddingModifier = modifier
        paddingModifier.underline = false
        let padding = custom.withModifier(paddingModifier)
        let area = Rect(2, 1, 12, 4)
        let listBuffer = Buffer(Rect(0, 0, 16, 6))
        List(["one"], selected: 0, selectedStyle: custom).render(area, listBuffer)
        @Expect(listBuffer.getCell(2, 1).style, custom)
        @Expect(listBuffer.getCell(4, 1).style, custom)
        @Expect(listBuffer.getCell(3, 1).style, padding)
        @Expect(listBuffer.getCell(13, 1).style, padding)
        let tableBuffer = Buffer(Rect(0, 0, 16, 6))
        Table(["Name", "State"], [["one", "ok"]], widths: [4, 4],
            state: TableState(selectedRow: 0), selectedStyle: custom).render(area, tableBuffer)
        @Expect(tableBuffer.getCell(2, 3).style, custom)
        @Expect(tableBuffer.getCell(4, 3).style, custom)
        @Expect(tableBuffer.getCell(3, 3).style, padding)
        @Expect(tableBuffer.getCell(8, 3).style, padding)
        @Expect(tableBuffer.getCell(13, 3).style, padding)
    }

    @TestCase
    func focusedListKeepsTreeIndentationFreeOfUnderline(): Unit {
        var modifier = Modifier.none()
        modifier.italic = true
        let custom = Style(fg: Color.Yellow, bg: Color.Blue, modifier: modifier)
        let area = Rect(2, 1, 20, 1)
        let buffer = Buffer(Rect(0, 0, 25, 3))
        List(["  ▾  tasks.csv"], selected: 0, selectedStyle: custom, focused: true).render(area, buffer)
        @Expect(buffer.getCell(6, 1).symbol, "▾")
        @Expect(buffer.getCell(6, 1).style.modifier.underline)
        @Expect(buffer.getCell(9, 1).symbol, "t")
        @Expect(buffer.getCell(9, 1).style.modifier.underline)
        for (x in [3, 4, 5, 7, 8, 18, 21]) {
            @Expect(!buffer.getCell(x, 1).style.modifier.underline)
            @Expect(buffer.getCell(x, 1).style.modifier.bold)
            @Expect(buffer.getCell(x, 1).style.modifier.italic)
            @Expect(buffer.getCell(x, 1).style, custom.withModifier(buffer.getCell(x, 1).style.modifier))
        }
        @Expect(buffer.getCell(1, 1), Cell(" "))
        @Expect(buffer.getCell(22, 1), Cell(" "))
    }

    @TestCase
    func focusedListSpacingHonorsAsciiAndWideGraphemes(): Unit {
        let area = Rect(1, 1, 10, 1)
        let buffer = Buffer(Rect(0, 0, 13, 3))
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        List([" >  界 x"], selected: 0, focused: true).render(area, buffer)
        @Expect(buffer.getCell(1, 1).symbol, "*")
        @Expect(buffer.getCell(4, 1).symbol, ">")
        @Expect(buffer.getCell(4, 1).style.modifier.underline)
        @Expect(buffer.getCell(7, 1).symbol, "界")
        @Expect(buffer.getCell(7, 1).style.modifier.underline)
        @Expect(buffer.getCell(10, 1).symbol, "x")
        @Expect(buffer.getCell(10, 1).style.modifier.underline)
        for (x in [2, 3, 5, 6, 9]) { @Expect(!buffer.getCell(x, 1).style.modifier.underline) }
        let narrow = Buffer(Rect(0, 0, 5, 1))
        List(["界"], selected: 0, focused: true).render(Rect(1, 0, 3, 1), narrow)
        @Expect(narrow.getCell(3, 0).symbol, " ")
        @Expect(!narrow.getCell(3, 0).style.modifier.underline)
        let unicodeSpaces = Buffer(Rect(0, 0, 10, 1))
        List(["\u{3000}x\u{00A0}y"], selected: 0, focused: true).render(unicodeSpaces.area, unicodeSpaces)
        @Expect(!unicodeSpaces.getCell(2, 0).style.modifier.underline)
        @Expect(!unicodeSpaces.getCell(3, 0).style.modifier.underline)
        @Expect(unicodeSpaces.getCell(4, 0).symbol, "x")
        @Expect(unicodeSpaces.getCell(4, 0).style.modifier.underline)
        @Expect(!unicodeSpaces.getCell(5, 0).style.modifier.underline)
        @Expect(unicodeSpaces.getCell(6, 0).symbol, "y")
        @Expect(unicodeSpaces.getCell(6, 0).style.modifier.underline)
    }
}
