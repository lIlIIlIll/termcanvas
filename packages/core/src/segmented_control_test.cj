package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class SegmentedControlT013Test {
    @TestCase
    func keyboardBoundsHomeEndAndPublicSelectionNormalization(): Unit {
        let control = SegmentedControl(["Alpha", "Beta"], selected: 1)
        @Expect(control.handle(KeyEvent(KeyCode.Right)), true)
        @Expect(control.selected, 1)
        @Expect(control.handle(KeyEvent(KeyCode.Right)), true)
        @Expect(control.selected, 1)
        @Expect(control.handle(KeyEvent(KeyCode.Left)), true)
        @Expect(control.selected, 0)
        @Expect(control.handle(KeyEvent(KeyCode.Left)), true)
        @Expect(control.selected, 0)
        @Expect(control.handle(KeyEvent(KeyCode.End)), true)
        @Expect(control.selected, 1)
        @Expect(control.handle(KeyEvent(KeyCode.Home)), true)
        @Expect(control.selected, 0)

        control.selected = -9
        @Expect(control.handle(KeyEvent(KeyCode.Right)), true)
        @Expect(control.selected, 1)
        control.selected = 90
        @Expect(control.selectedValue(), Some("Beta"))
        @Expect(control.selected, 1)

        let empty = SegmentedControl([])
        @Expect(empty.handle(KeyEvent(KeyCode.Right)), false)
        @Expect(empty.handle(KeyEvent(KeyCode.Home)), false)
        @Expect(empty.selected, 0)
        @Expect(empty.selectedValue().isNone(), true)
    }

    @TestCase
    func visibleSegmentMouseHitsActualIndexAndIgnoresSeparator(): Unit {
        let control = SegmentedControl(["A", "B", "C", "D"], selected: 3)
        let area = Rect(2, 2, 8, 3)
        let buffer = renderBoundaryWideSentinels()
        control.render(area, buffer)

        @Expect(buffer.getCell(area.x + 1, area.y).symbol, "C")
        @Expect(buffer.getCell(area.x + 3, area.y).symbol, " ")
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x + 5, area.y), area), true)
        @Expect(control.selected, 3)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x + 3, area.y), area), false)
        @Expect(control.selected, 3)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x + 1, area.y), area), true)
        @Expect(control.selected, 2)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x + 7, area.y), area), false)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, area.x + 1, area.y), area), false)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, area.x + 1, area.y), area), false)
        @Expect(control.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x + 1, area.y + 1), area), false)
    }

    @TestCase
    func selectedWideGlyphStaysVisibleWithoutWritingOutsideClip(): Unit {
        let control = SegmentedControl(["界界", "Next"])
        let area = Rect(2, 2, 3, 1)
        let buffer = renderBoundaryWideSentinels()
        control.render(area, buffer)

        @Expect(buffer.getCell(area.x, area.y).symbol, "[")
        @Expect(buffer.getCell(area.x + 1, area.y).symbol, "界")
        @Expect(buffer.getCell(area.right, area.y).symbol, "s")
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)
    }

    @TestCase
    func emptyAndDisabledControlsStayBlankAndRejectInput(): Unit {
        let area = Rect(2, 4, 6, 1)
        let empty = SegmentedControl([], selected: 8)
        let buffer = renderBoundaryWideSentinels()
        empty.render(area, buffer)
        @Expect(empty.selected, 0)
        @Expect(empty.handle(KeyEvent(KeyCode.End)), false)
        @Expect(empty.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x, area.y), area), false)
        for (column in area.x..area.right) {
            @Expect(buffer.getCell(column, area.y).symbol, " ")
        }
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)

        let theme = semanticTheme(dark: false, accent: Color.Cyan)
        let disabled = SegmentedControl(["One", "Two"], selected: 1, disabledStyle: Style.default())
        disabled.setVisualState(disabled: true, theme: Some(theme))
        @Expect(disabled.handle(KeyEvent(KeyCode.Left)), false)
        @Expect(disabled.handle(KeyEvent(KeyCode.Home)), false)
        @Expect(disabled.selected, 1)
        @Expect(disabled.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x, area.y), area), false)
        disabled.render(area, buffer)
        @Expect(buffer.getCell(area.x, area.y).style, theme.disabled)
    }

    @TestCase
    func themeRolesAndFocusedSelectionAreRendered(): Unit {
        let theme = semanticTheme(dark: false, accent: Color.Cyan)
        let control = SegmentedControl(["A", "B"], selected: 1, disabledStyle: Style.default())
        control.setVisualState(focused: true, theme: Some(theme))
        let area = Rect(2, 2, 10, 1)
        let buffer = renderBoundaryWideSentinels()
        control.render(area, buffer)

        var expectedModifier = theme.selected.modifier
        expectedModifier.bold = true
        expectedModifier.underline = true
        @Expect(buffer.getCell(area.x + 4, area.y).style, theme.selected.withModifier(expectedModifier))
        @Expect(buffer.getCell(area.x + 1, area.y).style, theme.normal)
    }
}
