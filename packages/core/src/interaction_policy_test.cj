package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class InteractionPolicyTest {
    @TestCase
    func controlsHitOnlyTheirContentAndRespectDisabledState(): Unit {
        let area = Rect(2, 2, 12, 4)
        let border = MouseEvent(MouseKind.Down, MouseButton.Left, 2, 2)
        let inside = MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3)
        let button = Button("save", block: Some(Block()))
        @Expect(!button.handleMouse(border, area))
        @Expect(button.handleMouse(inside, area))
        @Expect(!Button("save", disabled: true).handleMouse(inside, area))
        let checkbox = Checkbox("enabled", checked: false)
        @Expect(checkbox.handleMouse(inside, area))
        @Expect(checkbox.checked)
        @Expect(!checkbox.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 3, 3), area))
        @Expect(checkbox.checked)
        let input = Input(value: "界a", block: Some(Block()))
        @Expect(!input.handleMouse(border, area))
        @Expect(input.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 3), area))
        @Expect(input.cursor, 3)
    }

    @TestCase
    func scrolledSelectionMouseReturnsOriginalValues(): Unit {
        let area = Rect(2, 2, 12, 4)
        let selector = Select(["zero", "one", "two", "three", "four"], selected: 4, block: Some(Block()))
        selector.render(area, Buffer(Rect(0, 0, 20, 8)))
        @Expect(selector.offset, 3)
        @Expect(selector.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3), area), Some("three"))
        @Expect(selector.selected, 3)
        @Expect(selector.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 3, 3), area).isNone())
        @Expect(selector.selected, 2)
        @Expect(selector.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 2), area).isNone())
        @Expect(selector.selected, 2)
        let dropdown = Dropdown(["one", "two", "three"])
        @Expect(dropdown.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), Rect(0, 0, 10, 3)).isNone())
        @Expect(dropdown.open)
        @Expect(dropdown.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 2), Rect(0, 0, 10, 3)), Some("two"))
        @Expect(!dropdown.open)
    }

    @TestCase
    func listAndTableShareTheirApplicationOwnedSelection(): Unit {
        let listState = ListState()
        let list = List(["a", "b", "c"], state: Some(listState))
        @Expect(list.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 1), Rect(0, 0, 10, 2)))
        @Expect(listState.selected, Some(1))
        let tableState = TableState()
        let table = Table(["name"], [["a"], ["b"], ["c"]], state: Some(tableState))
        @Expect(!table.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), Rect(0, 0, 10, 4)))
        @Expect(table.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 3), Rect(0, 0, 10, 4)))
        @Expect(tableState.selectedRow, Some(1))
        @Expect(table.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 0, 3), Rect(0, 0, 10, 4)))
        @Expect(tableState.selectedRow, Some(2))
        @Expect(tableState.offset, 1)
    }

    @TestCase
    func scrollbarOwnsDragUntilReleaseOutsideItsRegion(): Unit {
        let capture = PointerCapture()
        let first = ScrollState()
        let second = ScrollState()
        let area = Rect(0, 0, 10, 10)
        let bar = Scrollbar(100, viewport: 10)
        @Expect(bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 9, 0), area, first, capture, "first"))
        @Expect(capture.owns("first"))
        @Expect(!bar.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 9, 0), area, second, capture, "second"))
        @Expect(bar.handleMouse(MouseEvent(MouseKind.Drag, MouseButton.Left, 40, 40), area, first, capture, "first"))
        @Expect(first.offset, 90)
        @Expect(second.offset, 0)
        @Expect(!capture.release("second", MouseEvent(MouseKind.Up, MouseButton.None, 40, 40)))
        @Expect(bar.handleMouse(MouseEvent(MouseKind.Up, MouseButton.None, 40, 40), area, first, capture, "first"))
        @Expect(capture.activeOwner().isNone())
        @Expect(capture.begin("second", MouseEvent(MouseKind.Down, MouseButton.Left, 9, 0), area))
        capture.cancel()
        @Expect(capture.activeOwner().isNone())
    }

    @TestCase
    func modalLayersIsolateShortcutsTabAndRestorePreviousFocus(): Unit {
        let focus = FocusManager()
        focus.add("name")
        focus.add("notes")
        @Expect(focus.focus("notes"))
        let scopes = ModalFocusState(focus, keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.F(2))], "background")]))
        @Expect(scopes.open("save", ["cancel", "confirm"], keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.Enter)], "save")])))
        @Expect(scopes.actionFor(KeyEvent(KeyCode.F(2))).isNone())
        @Expect(scopes.actionFor(KeyEvent(KeyCode.Enter)), Some("save"))
        @Expect(scopes.handle(KeyEvent(KeyCode.Tab)))
        @Expect(scopes.focus().current(), Some("confirm"))
        @Expect(scopes.open("help", ["close"]))
        @Expect(scopes.handle(KeyEvent(KeyCode.Esc)))
        @Expect(scopes.active(), Some("save"))
        @Expect(scopes.focus().current(), Some("confirm"))
        @Expect(scopes.handle(KeyEvent(KeyCode.Tab, modifiers: KeyModifier(shift: true))))
        @Expect(scopes.focus().current(), Some("cancel"))
        @Expect(focus.focus("name"))
        @Expect(scopes.close(), Some("save"))
        @Expect(scopes.focus().current(), Some("notes"))
        @Expect(scopes.actionFor(KeyEvent(KeyCode.F(2))), Some("background"))
        @Expect(!scopes.handle(KeyEvent(KeyCode.Esc)))
    }

    @TestCase
    func modalCloseUsesRemainingValidBaseFocus(): Unit {
        let focus = FocusManager()
        focus.add("removed")
        focus.add("remaining")
        let scopes = ModalFocusState(focus)
        @Expect(scopes.open("modal", []))
        @Expect(scopes.handle(KeyEvent(KeyCode.Tab)))
        focus.remove("removed")
        _ = scopes.close()
        @Expect(scopes.focus().current(), Some("remaining"))
        @Expect(!scopes.open("", []))
        @Expect(scopes.open("same", []))
        @Expect(!scopes.open("same", []))
    }
}
