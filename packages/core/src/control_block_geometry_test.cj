package core
import std.unittest.*
import std.unittest.testmacro.*

@Test
class ControlBlockGeometryTest {
    @TestCase
    func firstEventWithExplicitBorderlessTheme(): Unit {
        let theme = Theme(borderKind: BorderKind.NoBorder)
        let area = Rect(0, 0, 10, 4)
        let top = MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0)
        @Expect(Button("OK", block: Block(), theme: theme).handleMouse(top, area))
        @Expect(RadioGroup(["one"], block: Block(), theme: theme).handleMouse(top, area))
        let state = ListState()
        @Expect(List(["one"], block: Block(), state: state, theme: theme).handleMouse(top, area))
        @Expect(state.selected, Some(0))
        let tableState = TableState()
        @Expect(Table(["h"], [["one"]], block: Block(), state: tableState, theme: theme).handleMouse(
            MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), area))
        @Expect(tableState.selectedRow, Some(0))
        let input = Input(value: "hello", block: Block())
        input.setVisualState(theme: theme)
        @Expect(input.handleMouse(top, area))
        @Expect(input.cursorPosition(area).x, 0)
        @Expect(input.cursorPosition(area).y, 0)
    }
    @TestCase
    func sharedBlockMustNotChangePriorButtonHitGeometry(): Unit {
        let shared = Block()
        let area = Rect(0, 0, 10, 3)
        let first = Button("one", block: shared, theme: Theme(borderKind: BorderKind.Ascii))
        let second = Button("two", block: shared, theme: Theme(borderKind: BorderKind.NoBorder))
        let buffer = Buffer(Rect(0, 0, 10, 6))
        first.render(area, buffer)
        @Expect(!first.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
        second.render(Rect(0, 3, 10, 3), buffer)
        @Expect(!first.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
    }
    @TestCase
    func sharedBlockMustNotChangePriorInputCursor(): Unit {
        let shared = Block()
        let area = Rect(0, 0, 10, 3)
        let first = Input(value: "hello", block: shared)
        first.setVisualState(theme: Theme(borderKind: BorderKind.Ascii))
        let second = Input(value: "world", block: shared)
        second.setVisualState(theme: Theme(borderKind: BorderKind.NoBorder))
        let buffer = Buffer(Rect(0, 0, 10, 6))
        first.render(area, buffer)
        @Expect(first.cursorPosition(area).x, 1)
        @Expect(first.cursorPosition(area).y, 1)
        second.render(Rect(0, 3, 10, 3), buffer)
        @Expect(first.cursorPosition(area).x, 1)
        @Expect(first.cursorPosition(area).y, 1)
    }

    @TestCase
    func appThemeCanBeProvidedBeforeFirstDrawAndChildBlockOverrides(): Unit {
        let theme = Theme(borderKind: BorderKind.NoBorder)
        let area = Rect(0, 0, 10, 4)
        let top = MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0)
        @Expect(Button("ok", block: Block()).handleMouse(top, area, layoutTheme: theme))
        @Expect(RadioGroup(["one"], block: Block()).handleMouse(top, area, layoutTheme: theme))
        let input = Input(value: "hi", block: Block())
        @Expect(input.handleMouse(top, area, layoutTheme: theme))
        @Expect(input.cursorPosition(area, layoutTheme: theme).x, 0)
        @Expect(input.cursorPosition(area, layoutTheme: theme).y, 0)
        let framed = Block(BlockOptions(theme: Theme(borderKind: BorderKind.Ascii)))
        @Expect(!Button("ok", block: framed, theme: theme).handleMouse(top, area))
        let selector = Select(["one"], block: Block())
        @Expect(selector.handleMouse(top, area, layoutTheme: theme), Some("one"))
    }

}
