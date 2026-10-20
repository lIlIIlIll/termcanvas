package core

import std.unittest.*
import std.unittest.testmacro.*

func switchTestRow(buffer: Buffer, area: Rect): String {
    let row = StringBuilder()
    for (x in area.x..area.right) { row.append(buffer.getCell(x, area.y).symbol) }
    row.toString()
}

@Test
class SwitchWidgetTest {
    @TestCase
    func switchT012KeyboardMouseAndDisabledInputUseBooleanState(): Unit {
        let control = Switch("Auto sync")
        @Expect(control.checked, false)
        @Expect(control.handle(KeyEvent(KeyCode.Char(r' '))), true)
        @Expect(control.checked, true)
        @Expect(control.handle(KeyEvent(KeyCode.Enter)), true)
        @Expect(control.checked, false)
        @Expect(!control.handle(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(control.checked, false)

        let area = Rect(4, 2, 12, 3)
        @Expect(control.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 5, 2), area), true)
        @Expect(control.checked, true)
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Up, MouseButton.Left, 5, 2), area))
        @Expect(control.checked, true)
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Right, 5, 2), area))
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Drag, MouseButton.Left, 5, 2), area))
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 5, 3), area))
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 3, 2), area))
        @Expect(control.checked, true)

        control.setVisualState(disabled: true)
        @Expect(!control.handle(KeyEvent(KeyCode.Char(r' '))))
        @Expect(!control.handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 5, 2), area))
        @Expect(control.checked, true)
    }

    @TestCase
    func switchRendersEmptyLabelAndClipsAtNonZeroOrigin(): Unit {
        let buffer = Buffer(Rect(0, 0, 24, 4))
        let area = Rect(4, 1, 13, 1)
        let control = Switch("Wi-Fi")
        control.render(area, buffer)
        @Expect(switchTestRow(buffer, area), "Wi-Fi [off]  ")
        @Expect(buffer.getCell(3, 1).symbol, " ")
        @Expect(buffer.getCell(17, 1).symbol, " ")

        control.checked = true
        control.render(area, buffer)
        @Expect(switchTestRow(buffer, area), "Wi-Fi [on]   ")

        let emptyArea = Rect(4, 2, 5, 1)
        let empty = Switch("")
        empty.render(emptyArea, buffer)
        @Expect(switchTestRow(buffer, emptyArea), "[off]")
        empty.checked = true
        empty.render(emptyArea, buffer)
        @Expect(switchTestRow(buffer, emptyArea), "[on] ")

        let narrowArea = Rect(8, 3, 2, 1)
        Switch("Wi-Fi", checked: true).render(narrowArea, buffer)
        @Expect(switchTestRow(buffer, narrowArea), "Wi")
        buffer.setString(12, 3, "x")
        Switch("Wi-Fi").render(Rect(12, 3, 0, 1), buffer)
        @Expect(buffer.getCell(12, 3).symbol, "x")
    }

    @TestCase
    func switchThemeRolesPatchExplicitNormalFocusedAndDisabledStyles(): Unit {
        let theme = Theme(
            normal: Style(fg: Color.White, bg: Color.Black),
            focused: Style(fg: Color.Blue, bg: Color.Cyan, modifier: Modifier.strong()),
            disabled: Style(fg: Color.Indexed(8), bg: Color.Red)
        )
        let normalStyle = Style(fg: Color.Yellow)
        let focusedStyle = Style(bg: Color.Magenta)
        let disabledStyle = Style(fg: Color.Green)
        let control = Switch(
            "S",
            style: normalStyle,
            focusedStyle: focusedStyle,
            disabledStyle: disabledStyle
        )
        let area = Rect(2, 1, 8, 1)
        let buffer = Buffer(Rect(0, 0, 12, 3))

        control.setVisualState(theme: Some(theme))
        control.render(area, buffer)
        @Expect(buffer.getCell(area.x, area.y).style, theme.normal.patch(normalStyle))

        control.setVisualState(focused: true, theme: Some(theme))
        control.render(area, buffer)
        @Expect(buffer.getCell(area.x, area.y).style, theme.focused.patch(focusedStyle))

        control.setVisualState(focused: true, disabled: true, theme: Some(theme))
        control.render(area, buffer)
        @Expect(buffer.getCell(area.x, area.y).style, theme.disabled.patch(disabledStyle))

        control.setVisualState()
        control.render(area, buffer)
        @Expect(buffer.getCell(area.x, area.y).style, normalStyle)
    }
}
