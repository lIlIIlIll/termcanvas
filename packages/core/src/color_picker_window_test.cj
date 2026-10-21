package core

import std.unittest.*
import std.unittest.testmacro.*

func colorPickerFirstCellStyle(color: Color, focused!: Bool = false, theme!: ?Theme = None): Style {
    let picker = ColorPicker(colors: [color])
    picker.setVisualState(focused: focused, theme: theme)
    let buffer = Buffer(Rect(0, 0, 2, 1))
    picker.render(buffer.area, buffer)
    buffer.getCell(0, 0).style
}

func colorPickerWindowColors(): Array<Color> {
    [Color.Red, Color.Green, Color.Yellow, Color.Blue, Color.Magenta, Color.Cyan,
        Color.White, Color.Black, Color.Indexed(16), Color.Indexed(255), Color.Reset, Color.Rgb(0, 0, 0)]
}

@Test
class ColorPickerWindowTest {
    @TestCase
    func emptyPaletteHasNoSelectionInteractionOrRendering(): Unit {
        let picker = ColorPicker(colors: [])
        let area = Rect(2, 1, 4, 1)
        let buffer = Buffer(Rect(0, 0, 8, 3))
        buffer.setString(0, 1, "abcdefgh")
        let expected = Buffer(Rect(0, 0, 8, 3))
        expected.setString(0, 1, "abcdefgh")

        @Expect(picker.selectedColor().isNone())
        @Expect(!picker.handle(KeyEvent(KeyCode.Home)))
        @Expect(!picker.handle(KeyEvent(KeyCode.End)))
        @Expect(!picker.handle(KeyEvent(KeyCode.Left)))
        @Expect(!picker.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 1), area))
        picker.render(area, buffer)
        @Expect(buffer.diff(expected).size, 0)
        @Expect(picker.selected, 0)
    }

    @TestCase
    func homeEndAndHorizontalMovementClampWithoutCycling(): Unit {
        let picker = ColorPicker(colors: [Color.Red, Color.Green, Color.Blue], selected: 1)
        let homeHandled = picker.handle(KeyEvent(KeyCode.Home))
        @Expect(homeHandled)
        @Expect(picker.selected, 0)
        let leftHandled = picker.handle(KeyEvent(KeyCode.Left))
        @Expect(leftHandled)
        @Expect(picker.selected, 0)
        let endHandled = picker.handle(KeyEvent(KeyCode.End))
        @Expect(endHandled)
        @Expect(picker.selected, 2)
        let rightHandled = picker.handle(KeyEvent(KeyCode.Right))
        @Expect(rightHandled)
        @Expect(picker.selected, 2)

        picker.selected = -7
        let normalizeAndMoveRightHandled = picker.handle(KeyEvent(KeyCode.Right))
        @Expect(normalizeAndMoveRightHandled)
        @Expect(picker.selected, 1)
        picker.selected = 99
        @Expect(picker.selectedColor().isNone())
        let normalizeAndMoveHomeHandled = picker.handle(KeyEvent(KeyCode.Home))
        @Expect(normalizeAndMoveHomeHandled)
        @Expect(picker.selected, 0)
        let unsupportedKeyHandled = picker.handle(KeyEvent(KeyCode.Char(r'?')))
        @Expect(!unsupportedKeyHandled)
        @Expect(picker.selected, 0)
    }

    @TestCase
    func selectedSwatchesUseIntegerContrastAndThemeForegroundForReset(): Unit {
        @Expect(colorPickerFirstCellStyle(Color.Black), Style(fg: Color.White, bg: Color.Black))
        @Expect(colorPickerFirstCellStyle(Color.White), Style(fg: Color.Black, bg: Color.White))
        @Expect(colorPickerFirstCellStyle(Color.Red), Style(fg: Color.White, bg: Color.Red))
        @Expect(colorPickerFirstCellStyle(Color.Green), Style(fg: Color.Black, bg: Color.Green))
        @Expect(colorPickerFirstCellStyle(Color.Indexed(8)), Style(fg: Color.White, bg: Color.Indexed(8)))
        @Expect(colorPickerFirstCellStyle(Color.Indexed(15)), Style(fg: Color.Black, bg: Color.Indexed(15)))
        @Expect(colorPickerFirstCellStyle(Color.Rgb(0, 0, 0)), Style(fg: Color.White, bg: Color.Rgb(0, 0, 0)))
        @Expect(colorPickerFirstCellStyle(Color.Rgb(255, 255, 255)),
            Style(fg: Color.Black, bg: Color.Rgb(255, 255, 255)))

        let theme = Theme(normal: Style(fg: Color.Magenta, bg: Color.Black))
        let themedReset = colorPickerFirstCellStyle(Color.Reset, theme: Some(theme))
        @Expect(themedReset, Style(fg: Color.Magenta, bg: Color.Reset))
        @Expect(colorPickerFirstCellStyle(Color.Reset), Style.default())
    }

    @TestCase
    func focusedSelectedSwatchAddsBoldAndUnderline(): Unit {
        let focused = colorPickerFirstCellStyle(Color.Black, focused: true)
        @Expect(Style(fg: focused.fg, bg: focused.bg), Style(fg: Color.White, bg: Color.Black))
        @Expect(focused.modifier.bold)
        @Expect(focused.modifier.underline)
        @Expect(!colorPickerFirstCellStyle(Color.Black).modifier.bold)
        @Expect(!colorPickerFirstCellStyle(Color.Black).modifier.underline)
    }

    @TestCase
    func visibleWindowTracksEndAcrossNarrowWideNarrowAndMapsMouseIndices(): Unit {
        let colors = colorPickerWindowColors()
        let picker = ColorPicker(colors: colors)
        let endHandled = picker.handle(KeyEvent(KeyCode.End))
        @Expect(endHandled)
        @Expect(colors.size, 12)
        @Expect(picker.selected, 11)
        @Expect(picker.selected, colors.size - 1)

        let narrow = Rect(2, 1, 3, 1)
        let wide = Rect(2, 1, 12, 1)
        let buffer = Buffer(Rect(0, 0, 20, 3))
        for (y in 0..3) { buffer.setString(0, y, "....................") }
        picker.render(narrow, buffer)
        @Expect(buffer.getCell(narrow.x, narrow.y).style,
            Style(fg: Color.White, bg: Color.Rgb(0, 0, 0)))
        @Expect(buffer.getCell(narrow.x - 1, narrow.y).symbol, ".")
        @Expect(buffer.getCell(narrow.right, narrow.y).symbol, ".")

        picker.render(wide, buffer)
        @Expect(picker.selected, colors.size - 1)
        @Expect(buffer.getCell(wide.x + 9, wide.y).style,
            Style(fg: Color.White, bg: Color.Rgb(0, 0, 0)))
        picker.render(narrow, buffer)
        @Expect(picker.selected, colors.size - 1)
        @Expect(buffer.getCell(narrow.x, narrow.y).style,
            Style(fg: Color.White, bg: Color.Rgb(0, 0, 0)))

        let selectedByFirstClick = picker.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, wide.x + 3, wide.y), wide)
        @Expect(selectedByFirstClick)
        @Expect(picker.selected, 9)
        let secondCellPicker = ColorPicker(colors: colors, selected: 11)
        let selectedBySecondCell = secondCellPicker.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, wide.x + 4, wide.y), wide)
        @Expect(selectedBySecondCell)
        @Expect(secondCellPicker.selected, 9)
        match (picker.selectedColor()) {
            case Some(color) => @Expect(Style(fg: color), Style(fg: Color.Indexed(255)))
            case None => @Expect(false)
        }
        let gapClickHandled = picker.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, wide.x + 2, wide.y), wide)
        @Expect(!gapClickHandled)
        @Expect(picker.selected, 9)
        let releasedClickHandled = picker.handleMouse(
            MouseEvent(MouseKind.Up, MouseButton.Left, wide.x, wide.y), wide)
        @Expect(!releasedClickHandled)
        let outsideClickHandled = picker.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, wide.right, wide.y), wide)
        @Expect(!outsideClickHandled)
        let otherRowClickHandled = picker.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, wide.x, wide.bottom), wide)
        @Expect(!otherRowClickHandled)
        @Expect(picker.selected, 9)

        picker.selected = 99
        @Expect(!picker.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, wide.x + 2, wide.y), wide))
        @Expect(picker.selected, 99)
        picker.render(wide, buffer)
        @Expect(picker.selected, colors.size - 1)
        match (picker.selectedColor()) {
            case Some(color) => @Expect(Style(fg: color), Style(fg: Color.Rgb(0, 0, 0)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func disabledStateRejectsKeysAndMouseWithoutNormalizingSelection(): Unit {
        let picker = ColorPicker(colors: [Color.Red, Color.Green, Color.Blue], selected: 1)
        picker.selected = -5
        picker.setVisualState(disabled: true)
        let area = Rect(0, 0, 9, 1)
        @Expect(!picker.handle(KeyEvent(KeyCode.Home)))
        @Expect(!picker.handle(KeyEvent(KeyCode.Left)))
        @Expect(!picker.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 0), area))
        @Expect(picker.selected, -5)
    }

    @TestCase
    func oneColumnRenderClipsAndRenderNormalizesAnInvalidSelection(): Unit {
        let picker = ColorPicker(colors: [Color.Red, Color.Black])
        picker.selected = 99
        let area = Rect(2, 1, 1, 1)
        let buffer = Buffer(Rect(0, 0, 8, 3))
        for (y in 0..3) { buffer.setString(0, y, "........") }
        picker.render(area, buffer)
        @Expect(picker.selected, 1)
        @Expect(buffer.getCell(1, 1).symbol, ".")
        @Expect(buffer.getCell(2, 1).symbol, "#")
        @Expect(buffer.getCell(3, 1).symbol, ".")
        @Expect(
            Style(fg: buffer.getCell(2, 1).style.fg, bg: buffer.getCell(2, 1).style.bg),
            Style(fg: Color.White, bg: Color.Black)
        )
        @Expect(!picker.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x, area.y), area))
        @Expect(picker.selected, 1)
    }

    @TestCase
    func zeroAreaRenderNormalizesSelectionWithoutChangingBuffer(): Unit {
        let picker = ColorPicker(colors: [Color.Red, Color.Green, Color.Blue])
        picker.selected = -4
        let area = Rect(2, 1, 0, 1)
        let buffer = Buffer(Rect(0, 0, 8, 3))
        buffer.setString(0, 1, "abcdefgh")
        let expected = Buffer(Rect(0, 0, 8, 3))
        expected.setString(0, 1, "abcdefgh")
        picker.render(area, buffer)
        @Expect(picker.selected, 0)
        @Expect(buffer.diff(expected).size, 0)
    }
}
