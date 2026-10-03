package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TextEditorCapabilityTest {
    @TestCase
    func shiftedNavigationExtendsAndReversesSelection(): Unit {
        let area = TextArea(value: "a界e\u{301} z", cursor: 1)
        _ = area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "界")
        _ = area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "界e\u{301}")
        _ = area.handle(KeyEvent(KeyCode.Left, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "界")
        _ = area.handle(KeyEvent(KeyCode.End, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "界e\u{301} z")
        _ = area.handle(KeyEvent(KeyCode.Home, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "a")
    }

    @TestCase
    func controlShiftNavigationSelectsWords(): Unit {
        let area = TextArea(value: "one two", cursor: 0)
        _ = area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(ctrl: true, shift: true)))
        @Expect(area.selectedText(), "one ")
        _ = area.handle(KeyEvent(KeyCode.End, modifiers: KeyModifier(ctrl: true, shift: true)))
        @Expect(area.selectedText(), "one two")
    }

    @TestCase
    func verticalNavigationRetainsPreferredColumn(): Unit {
        let area = TextArea(value: "abcdef\nx\nabcdef", cursor: 5)
        _ = area.handle(KeyEvent(KeyCode.Down))
        @Expect(area.cursor, 8)
        _ = area.handle(KeyEvent(KeyCode.Down))
        @Expect(area.cursor, 14)
        _ = area.handle(KeyEvent(KeyCode.Left))
        _ = area.handle(KeyEvent(KeyCode.Up))
        _ = area.handle(KeyEvent(KeyCode.Up))
        @Expect(area.cursor, 4)
        _ = area.handle(KeyEvent(KeyCode.Down))
        _ = area.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true)))
        _ = area.handle(KeyEvent(KeyCode.Down))
        @Expect(area.cursor, 9)
        _ = area.handle(KeyEvent(KeyCode.Up))
        area.cursor = 5
        _ = area.handle(KeyEvent(KeyCode.Down))
        _ = area.handle(KeyEvent(KeyCode.Down))
        @Expect(area.cursor, 14)
        let blankLine = TextArea(value: "abcd\n\nabcd", cursor: 3)
        _ = blankLine.handle(KeyEvent(KeyCode.Down))
        _ = blankLine.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true)))
        _ = blankLine.handle(KeyEvent(KeyCode.Down))
        @Expect(blankLine.cursor, 6)
    }

    @TestCase
    func horizontalViewportFollowsTheCaret(): Unit {
        let area = TextArea(value: "0123456789abcdef", cursor: 16)
        let rect = Rect(0, 0, 6, 2)
        let buffer = Buffer(rect)
        area.render(rect, buffer)
        let position = area.cursorPosition(rect)
        @Expect(position.x < rect.right)
        @Expect(buffer.getCell(position.x - 1, 0).symbol, "f")
    }

    @TestCase
    func pageMovementUsesTheRenderedViewportHeight(): Unit {
        let area = TextArea(value: "0\n1\n2\n3\n4\n5\n6\n7", cursor: 0)
        let rect = Rect(0, 0, 5, 3)
        area.render(rect, Buffer(rect))
        _ = area.handle(KeyEvent(KeyCode.PageDown))
        @Expect(area.cursor, 6)
        _ = area.handle(KeyEvent(KeyCode.PageUp, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedText(), "0\n1\n2\n")
    }
}
