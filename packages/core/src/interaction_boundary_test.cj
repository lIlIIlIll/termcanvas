package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class InteractionBoundaryTest {
    @TestCase
    func menuTitleBorderAndDisabledRowsCannotActivate(): Unit {
        let items = [MenuItem("disabled", enabled: false), MenuItem("one", action: "run-one"), MenuItem("two")]
        let area = Rect(2, 2, 16, 4)
        let menu = Menu("Tools", items)
        menu.render(area, Buffer(Rect(0, 0, 24, 10)))
        @Expect(menu.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 2), area).isNone())
        @Expect(menu.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3), area).isNone())
        @Expect(menu.handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(menu.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4), area), Some("run-one"))
        @Expect(menu.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 3, 4), area).isNone())
        @Expect(menu.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 3, 4), area).isNone())
        @Expect(menu.selected, 2)
        @Expect(menu.handle(KeyEvent(KeyCode.Char(r' '))), Some("two"))
        let framed = Menu("Tools", items, block: Some(Block()))
        framed.render(area, Buffer(Rect(0, 0, 24, 10)))
        @Expect(framed.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 3), area).isNone())
        @Expect(framed.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4), area), Some("run-one"))
        @Expect(Menu("", []).handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(menu.handle(KeyEvent(KeyCode.F(1))).isNone())
    }

    @TestCase
    func paletteFiltersActionsAndResetsViewportBeforeMouseActivation(): Unit {
        let palette = CommandPalette([MenuItem("first", action: "alpha"), MenuItem("blocked", enabled: false), MenuItem("中文", action: "last")], block: None)
        let area = Rect(0, 0, 16, 3)
        palette.render(area, Buffer(area))
        @Expect(palette.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area).isNone())
        @Expect(palette.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), area).isNone())
        @Expect(palette.selected, 1)
        @Expect(palette.handle(KeyEvent(KeyCode.Enter)).isNone())
        _ = palette.handle(KeyEvent(KeyCode.End))
        palette.render(area, Buffer(area))
        @Expect(palette.offset, 1)
        @Expect(palette.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), area), Some("last"))
        palette.query = "alpha"
        @Expect(palette.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), area), Some("alpha"))
        @Expect(palette.selected, 0)
        @Expect(palette.offset, 0)
        palette.query = "absent"
        @Expect(palette.handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(palette.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 0, 1), area).isNone())
        palette.query = ""
        _ = palette.handle(KeyEvent(KeyCode.Char(r'中'), text: Some("中文")))
        @Expect(palette.handle(KeyEvent(KeyCode.Enter)), Some("last"))
        _ = palette.handle(KeyEvent(KeyCode.Backspace))
        @Expect(palette.query, "中")
        _ = palette.handle(KeyEvent(KeyCode.Backspace))
        _ = palette.handle(KeyEvent(KeyCode.Backspace))
        @Expect(palette.query, "")
        @Expect(palette.handle(KeyEvent(KeyCode.Esc)).isNone())
    }

    @TestCase
    func dropdownOpenCloseScrollAndEmptyStatesKeepTheirContracts(): Unit {
        let area = Rect(1, 1, 10, 3)
        let dropdown = Dropdown(["zero", "one", "two", "three"])
        @Expect(dropdown.handle(KeyEvent(KeyCode.Down)).isNone())
        @Expect(dropdown.selected, 0)
        @Expect(dropdown.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 2), area).isNone())
        @Expect(!dropdown.open)
        _ = dropdown.handle(KeyEvent(KeyCode.Char(r' ')))
        dropdown.render(area, Buffer(Rect(0, 0, 20, 8)))
        _ = dropdown.handle(KeyEvent(KeyCode.PageDown))
        @Expect(dropdown.selected, 2)
        _ = dropdown.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 2, 2), area)
        @Expect(dropdown.selected, 1)
        @Expect(dropdown.open)
        _ = dropdown.handle(KeyEvent(KeyCode.Esc))
        @Expect(!dropdown.open)
        _ = dropdown.handle(KeyEvent(KeyCode.Enter))
        @Expect(dropdown.handle(KeyEvent(KeyCode.Enter)), Some("one"))
        @Expect(!dropdown.open)
        @Expect(dropdown.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 20, 2), area).isNone())
        let empty = Dropdown([], open: true, placeholder: "empty")
        let buffer = Buffer(Rect(0, 0, 12, 2))
        empty.render(buffer.area, buffer)
        @Expect(interactionRow(buffer, 0).startsWith("v empty"))
        @Expect(empty.handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(!empty.open)
    }

    @TestCase
    func radioAndMultiSelectWheelMovesWithoutActivating(): Unit {
        let items = ["a", "b", "c", "d"]
        let area = Rect(0, 0, 12, 2)
        let radio = RadioGroup(items)
        radio.render(area, Buffer(area))
        @Expect(radio.handle(KeyEvent(KeyCode.PageDown)))
        @Expect(radio.selected, 2)
        @Expect(radio.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 1, 1), area))
        @Expect(radio.selected, 1)
        @Expect(!radio.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 1, 1), area))
        @Expect(!radio.handle(KeyEvent(KeyCode.F(1))))
        @Expect(radio.handle(KeyEvent(KeyCode.Enter)))
        @Expect(!RadioGroup(items, disabled: true).handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), area))
        @Expect(!RadioGroup([]).handle(KeyEvent(KeyCode.Down)))
        let multi = MultiSelect(items, selected: [-1, 0, 0, 5])
        @Expect(multi.selectedIndices().size, 1)
        multi.render(area, Buffer(area))
        @Expect(multi.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 1, 1), area))
        @Expect(multi.cursor, 1)
        @Expect(multi.selectedIndices().size, 1)
        @Expect(multi.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), area))
        @Expect(multi.selectedIndices().size, 2)
        @Expect(multi.handle(KeyEvent(KeyCode.Enter)))
        @Expect(multi.selectedIndices().size, 1)
        @Expect(!multi.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, 1, 1), area))
        @Expect(!multi.handle(KeyEvent(KeyCode.F(1))))
        multi.cursor = -1
        multi.toggle()
        @Expect(multi.selectedIndices().size, 1)
        let empty = MultiSelect([])
        empty.toggle()
        @Expect(empty.selectedIndices().isEmpty())
    }

    @TestCase
    func horizontalControlsRespectWideLabelsAndGaps(): Unit {
        let area = Rect(2, 3, 20, 2)
        let bar = MenuBar(["文", "Edit"])
        @Expect(bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 3), area))
        @Expect(bar.selected, 1)
        @Expect(!bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 4), area))
        @Expect(!bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 20, 3), area))
        @Expect(!bar.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 3, 3), area))
        @Expect(!bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 3), area))
        let colors = ColorPicker(colors: [Color.Red, Color.Blue])
        @Expect(colors.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 3), area))
        @Expect(colors.selected, 1)
        @Expect(!colors.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 3), area))
        @Expect(!colors.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 8, 3), area))
        @Expect(!colors.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 4), area))
        @Expect(!colors.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 2, 3), area))
        @Expect(!colors.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 3), area))
    }

    @TestCase
    func pointerCaptureRejectsInvalidStartsAndUnrelatedReleases(): Unit {
        let capture = PointerCapture()
        let area = Rect(2, 3, 8, 5)
        let down = MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4)
        @Expect(!capture.begin("", down, area))
        @Expect(!capture.begin("drag", MouseEvent(MouseKind.Up, MouseButton.Left, 3, 4), area))
        @Expect(!capture.begin("drag", down, Rect(0, 0, 0, 0)))
        @Expect(capture.begin("drag", down, area, value: 17))
        @Expect(capture.origin().x, 3)
        @Expect(capture.origin().y, 4)
        @Expect(capture.initialValue(), 17)
        @Expect(!capture.release("drag", MouseEvent(MouseKind.Up, MouseButton.Right, 3, 4)))
        @Expect(capture.owns("drag"))
        @Expect(capture.release("drag", MouseEvent(MouseKind.Up, MouseButton.Left, -1, -1)))
        @Expect(capture.activeOwner().isNone())
        @Expect(widgetRowAt(down, area, -1, 10).isNone())
        @Expect(widgetRowAt(down, area, 10, 10).isNone())
        @Expect(widgetRowAt(down, area, 9, 10).isNone())
        @Expect(widgetRowAt(down, area, 8, 10), Some(9))
    }
}
