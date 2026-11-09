package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ButtonFocusVisualTest {
    @TestCase
    func themedFocusUnderlinesOnlyTheLabel(): Unit {
        let focused = Style(fg: Color.Yellow, bg: Color.Blue)
        let theme = Theme(focused: focused)
        let area = Rect(2, 1, 10, 3)
        let buffer = Buffer(Rect(0, 0, 15, 5))
        Button("OK", focused: true, theme: theme).render(area, buffer)
        var focusModifier = focused.modifier
        focusModifier.bold = true
        focusModifier.underline = true
        let labelStyle = focused.withModifier(focusModifier)
        @Expect(buffer.getCell(6, 2).symbol, "O")
        @Expect(buffer.getCell(6, 2).style, labelStyle)
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                if (!(y == 2 && (x == 6 || x == 7))) {
                    @Expect(!buffer.getCell(x, y).style.modifier.underline)
                    @Expect(buffer.getCell(x, y).style, focused.withModifier(Modifier.strong()))
                }
            }
        }
    }

    @TestCase
    func explicitFocusedStyleOverridesThemeIncludingLegacyColors(): Unit {
        let theme = Theme(focused: Style(fg: Color.Yellow, bg: Color.Blue))
        let explicit = Style(fg: Color.Black, bg: Color.White)
        let buffer = Buffer(Rect(0, 0, 6, 1))
        Button("OK", focused: true, focusedStyle: explicit, theme: theme).render(buffer.area, buffer)
        @Expect(buffer.getCell(2, 0).style, explicit)
        @Expect(buffer.getCell(0, 0).style, explicit)
        let defaulted = Buffer(Rect(0, 0, 6, 1))
        Button("OK", focused: true).render(defaulted.area, defaulted)
        var expected = explicit.modifier
        expected.bold = true
        expected.underline = true
        @Expect(defaulted.getCell(2, 0).style, explicit.withModifier(expected))
        @Expect(!defaulted.getCell(0, 0).style.modifier.underline)
    }

    @TestCase
    func explicitUnderlineIsRestrictedToLabelAndDisabledWins(): Unit {
        var underline = Modifier()
        underline.underline = true
        let custom = Style(fg: Color.Green, bg: Color.Blue, modifier: underline)
        let buffer = Buffer(Rect(0, 0, 8, 3))
        Button("OK", focused: true, focusedStyle: custom).render(buffer.area, buffer)
        @Expect(buffer.getCell(3, 1).style, custom)
        @Expect(!buffer.getCell(0, 0).style.modifier.underline)
        let disabled = Style(fg: Color.Red)
        let theme = Theme(focused: Style(bg: Color.Blue), disabled: disabled)
        let disabledBuffer = Buffer(Rect(0, 0, 8, 1))
        Button("OK", focused: true, disabled: true, theme: theme).render(disabledBuffer.area, disabledBuffer)
        @Expect(disabledBuffer.getCell(3, 0).style.modifier.italic)
        @Expect(!disabledBuffer.getCell(3, 0).style.modifier.underline)
        @Expect(disabledBuffer.getCell(3, 0).style, disabled.withModifier(disabledBuffer.getCell(3, 0).style.modifier))
    }
}
