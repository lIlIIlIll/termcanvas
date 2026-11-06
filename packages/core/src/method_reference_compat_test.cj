package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class MethodReferenceCompatTest {
    @TestCase
    func oldMethodReferencesRemainCallable(): Unit {
        let area = Rect(0, 0, 10, 4)
        let top = MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0)
        let input = Input()
        let listState = ListState()
        let list = List(["one"], state: listState)
        let tableState = TableState()
        let table = Table(["name"], [["one"]], state: tableState)
        let button = Button("run")
        let radio = RadioGroup(["one"])
        let select = Select(["one"])
        let inputMouse: (MouseEvent, Rect) -> Bool = input.handleMouse
        let listMouse: (MouseEvent, Rect) -> Bool = list.handleMouse
        let tableMouse: (MouseEvent, Rect) -> Bool = table.handleMouse
        let buttonMouse: (MouseEvent, Rect) -> Bool = button.handleMouse
        let radioMouse: (MouseEvent, Rect) -> Bool = radio.handleMouse
        let selectMouse: (MouseEvent, Rect) -> ?String = select.handleMouse
        let dirty: (KeyEvent, Rect) -> ?DirtyRects = input.handleWithDirty
        let cursor: (Rect) -> Position = input.cursorPosition
        @Expect(inputMouse(top, area))
        @Expect(listMouse(top, area))
        @Expect(listState.selected, Some(0))
        @Expect(tableMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), area))
        @Expect(tableState.selectedRow, Some(0))
        @Expect(buttonMouse(top, area))
        @Expect(radioMouse(top, area))
        @Expect(selectMouse(top, area), Some("one"))
        @Expect(dirty(KeyEvent(KeyCode.Char(r'x')), area).isSome())
        @Expect(input.value, "x")
        @Expect(cursor(area).y, 0)
    }

    @TestCase
    func newExplicitLayoutThemeStillControlsFirstEventGeometry(): Unit {
        let area = Rect(0, 0, 10, 4)
        let top = MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0)
        let theme = Theme(borderKind: BorderKind.NoBorder)
        @Expect(Button("run", block: Block()).handleMouse(top, area, layoutTheme: theme))
        @Expect(RadioGroup(["one"], block: Block()).handleMouse(top, area, layoutTheme: theme))
        @Expect(Select(["one"], block: Block()).handleMouse(top, area, layoutTheme: theme), Some("one"))
        let listState = ListState()
        @Expect(List(["one"], state: listState, block: Block()).handleMouse(top, area, layoutTheme: theme))
        @Expect(listState.selected, Some(0))
        let tableState = TableState()
        @Expect(Table(["name"], [["one"]], state: tableState, block: Block()).handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), area, layoutTheme: theme))
        @Expect(tableState.selectedRow, Some(0))
        let input = Input(block: Block())
        @Expect(input.handleMouse(top, area, layoutTheme: theme))
        @Expect(input.cursorPosition(area, layoutTheme: theme).x, 0)
        @Expect(input.cursorPosition(area, options: TextWidthOptions(), layoutTheme: theme).y, 0)
        @Expect(input.handleWithDirty(KeyEvent(KeyCode.Char(r'x')), area, layoutTheme: theme).isSome())
    }
}
