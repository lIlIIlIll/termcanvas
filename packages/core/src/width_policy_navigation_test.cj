package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TextAreaWidthNavigationTest {
    @TestCase
    func changingWidthPolicyResetsVerticalColumn(): Unit {
        let editor = TextArea(value: "·a\n·a\n·abc", cursor: "·a".size)
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        @Expect(editor.cursor, "·a\n·a".size)
        editor.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        @Expect(editor.cursor, "·a\n·a\n·a".size)
    }
    @TestCase
    func unchangedWidthPolicyKeepsVerticalColumnAcrossShortLines(): Unit {
        let editor = TextArea(value: "abcd\nx\nabcd", cursor: "abcd".size)
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        editor.setTextWidthOptions(TextWidthOptions())
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        @Expect(editor.cursor, "abcd\nx\nabcd".size)
    }

    @TestCase
    func changingWidthPolicyResetsColumnsForAllCarets(): Unit {
        let editor = TextArea(value: "·a·b\n·a·b\n·a·b")
        editor.setCarets([TextAreaCaret("·".size), TextAreaCaret("·a·".size)])
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        editor.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        @Expect(editor.handle(KeyEvent(KeyCode.Down)))
        let carets = editor.carets()
        @Assert(carets.size, 2)
        @Expect(carets[0].offset, "·a·b\n·a·b\n·".size)
        @Expect(carets[1].offset, "·a·b\n·a·b\n·a·".size)
    }
}
