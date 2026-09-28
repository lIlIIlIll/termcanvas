package core

import std.unittest.*
import std.unittest.testmacro.*

private func vimKey(editor: VimEditorBehavior, rune: Rune): Bool {
    editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(rune))))
}

private func vimEsc(editor: VimEditorBehavior): Unit {
    _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Esc)))
}

private func vimIsInsert(editor: VimEditorBehavior): Bool {
    match (editor.mode) {
        case VimMode.Insert => true
        case VimMode.Normal => false
    }
}

@Test
class VimEditorTests {
    @TestCase
    func insertTransactionUndoRedoAndDefaultArea(): Unit {
        let plain = TextArea(value: "ab", cursor: 1)
        @Expect(plain.handle(KeyEvent(KeyCode.Char(r'h'))))
        @Expect(plain.value, "ahb")

        let area = TextArea(value: "ab", cursor: 1)
        let editor = VimEditorBehavior(area)
        @Expect(vimKey(editor, r'h'))
        @Expect(area.cursor, 0)
        @Expect(area.value, "ab")
        _ = vimKey(editor, r'i')
        for (r in [r'x', r'y', r'z']) { _ = vimKey(editor, r) }
        vimEsc(editor)
        @Expect(!vimIsInsert(editor))
        @Expect(area.value, "xyzab")
        _ = vimKey(editor, r'u')
        @Expect(area.value, "ab")
        _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'), modifiers: KeyModifier(ctrl: true))))
        @Expect(area.value, "xyzab")
        _ = vimKey(editor, r'u')
        _ = vimKey(editor, r'i')
        vimEsc(editor)
        _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'), modifiers: KeyModifier(ctrl: true))))
        @Expect(area.value, "xyzab")
    }

    @TestCase
    func graphemesAndLastLineDeletion(): Unit {
        let area = TextArea(value: "中e\u{0301}😀\n尾")
        let editor = VimEditorBehavior(area)
        _ = vimKey(editor, r'l')
        @Expect(area.cursor, "中".size)
        _ = vimKey(editor, r'x')
        @Expect(area.value, "中😀\n尾")
        _ = vimKey(editor, r'$')
        let atEnd = area.cursor
        _ = vimKey(editor, r'l')
        @Expect(area.cursor, atEnd)
        let lines = TextArea(value: "a\nb", cursor: 2)
        let lineEditor = VimEditorBehavior(lines)
        _ = vimKey(lineEditor, r'd')
        _ = vimKey(lineEditor, r'd')
        @Expect(lines.value, "a")
        _ = vimKey(lineEditor, r'u')
        @Expect(lines.value, "a\nb")
        let empty = TextArea()
        let emptyEditor = VimEditorBehavior(empty)
        _ = vimKey(emptyEditor, r'x')
        _ = vimKey(emptyEditor, r'd')
        _ = vimKey(emptyEditor, r'd')
        _ = vimKey(emptyEditor, r'u')
        @Expect(empty.value, "")
        @Expect(!empty.undo())
    }

    @TestCase
    func prefixesRepeatsFocusAndIndependentAreas(): Unit {
        let first = TextArea(value: "one\ntwo", cursor: 4)
        let second = TextArea(value: "abc")
        let a = VimEditorBehavior(first)
        let b = VimEditorBehavior(second)
        _ = vimKey(a, r'g')
        @Expect(first.cursor, 4)
        _ = vimKey(b, r'g')
        vimEsc(a)
        _ = vimKey(a, r'g')
        @Expect(first.cursor, 4)
        _ = vimKey(b, r'g')
        @Expect(second.cursor, 0)
        _ = vimKey(a, r'g')
        @Expect(first.cursor, 0)
        _ = vimKey(a, r'd')
        _ = a.handle(Event.KeyRepeat(KeyEvent(KeyCode.Char(r'd'), nativeRepeat: true)))
        @Expect(first.value, "one\ntwo")
        @Expect(!a.handle(Event.KeyUp(KeyEvent(KeyCode.Char(r'd')))))
        @Expect(!a.handle(Event.KeyHeld(KeyEvent(KeyCode.Char(r'd')))))
        _ = vimKey(a, r'd')
        @Expect(first.value, "two")
        _ = vimKey(a, r'd')
        @Expect(!a.handle(Event.FocusOut))
        _ = vimKey(a, r'd')
        @Expect(first.value, "two")
        _ = vimKey(a, r'9')
        _ = vimKey(a, r'Q')
        @Expect(first.value, "two")
        let pending = TextArea(value: "one two", cursor: 4)
        let pendingEditor = VimEditorBehavior(pending)
        _ = vimKey(pendingEditor, r'g')
        @Expect(pendingEditor.handle(Event.KeyDown(KeyEvent(KeyCode.Left))))
        @Expect(pending.cursor, 4)
        _ = vimKey(pendingEditor, r'g')
        _ = vimKey(pendingEditor, r'g')
        @Expect(pending.cursor, 0)
    }

    @TestCase
    func insertionEntrancesAndOpenedLineUndo(): Unit {
        let area = TextArea(value: "  ab\ncd", cursor: 2)
        let editor = VimEditorBehavior(area)
        _ = vimKey(editor, r'I')
        @Expect(area.cursor, 2)
        vimEsc(editor)
        _ = vimKey(editor, r'A')
        @Expect(area.cursor, 4)
        vimEsc(editor)
        _ = vimKey(editor, r'a')
        @Expect(area.cursor, 4)
        vimEsc(editor)
        _ = vimKey(editor, r'o')
        _ = vimKey(editor, r'X')
        vimEsc(editor)
        @Expect(area.value, "  ab\nX\ncd")
        _ = vimKey(editor, r'u')
        @Expect(area.value, "  ab\ncd")
        _ = vimKey(editor, r'O')
        _ = vimKey(editor, r'Y')
        vimEsc(editor)
        @Expect(area.value, "Y\n  ab\ncd")
        _ = vimKey(editor, r'u')
        @Expect(area.value, "  ab\ncd")
    }

    @TestCase
    func pasteLiteralAndReadOnlyHistory(): Unit {
        let area = TextArea(value: "ab")
        let editor = VimEditorBehavior(area)
        @Expect(editor.handle(Event.Paste("dd")))
        @Expect(area.value, "addb")
        _ = vimKey(editor, r'a')
        _ = editor.handle(Event.Paste("\n\u{1B}literal"))
        vimEsc(editor)
        @Expect(area.value, "add\n\u{1B}literalb")
        _ = vimKey(editor, r'u')
        @Expect(area.value, "addb")
        area.readOnly = true
        _ = vimKey(editor, r'x')
        _ = vimKey(editor, r'd')
        _ = vimKey(editor, r'd')
        _ = editor.handle(Event.Paste("changed"))
        _ = vimKey(editor, r'u')
        _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'), modifiers: KeyModifier(ctrl: true))))
        @Expect(area.value, "addb")
        _ = vimKey(editor, r'l')
        @Expect(area.cursor > 0)
    }

    @TestCase
    func completionCancellationAndKittyText(): Unit {
        let area = TextArea(value: "a", cursor: 1)
        let editor = VimEditorBehavior(area)
        _ = vimKey(editor, r'i')
        let request = area.beginCompletion("completion")
        let result = TextCompletionResult("completion", request.revision, 0, 1, [TextCompletionItem("alpha")])
        @Expect(editor.handle(Event.TextCompletion("completion", result)))
        @Expect(area.completionVisible())
        vimEsc(editor)
        @Expect(vimIsInsert(editor))
        @Expect(!area.completionVisible())
        vimEsc(editor)
        @Expect(!vimIsInsert(editor))
        _ = vimKey(editor, r'a')
        @Expect(!editor.handle(Event.TextCompletion("completion", result)))
        @Expect(!area.completionVisible())
        let parser = EventParser()
        let bytes = unsafe { "\u{1B}[97;2;65u\u{1B}[0;;229:769u".rawData() }
        for (event in parser.push(bytes)) { _ = editor.handle(event) }
        @Expect(area.value, "aAå\u{0301}")
        vimEsc(editor)
        let nav = TextArea(value: "ab\ncd")
        let normal = VimEditorBehavior(nav)
        _ = normal.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'g'), modifiers: KeyModifier(shift: true))))
        @Expect(nav.cursor, 3)
        _ = normal.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'4'), modifiers: KeyModifier(shift: true))))
        @Expect(nav.cursor, 4)
        @Expect(normal.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'g'), text: Some("gg")))))
        @Expect(nav.value, "ab\ncd")
    }

    @TestCase
    func markdownHandlerRunsOnceAndExceptionsCommitEdits(): Unit {
        let area = TextArea()
        let markdown = MarkdownEditorBehavior()
        let editor = VimEditorBehavior(area, insertHandler: { target, key => markdown.handle(target, key) })
        _ = vimKey(editor, r'i')
        _ = vimKey(editor, r'[')
        @Expect(area.value, "[]")
        vimEsc(editor)
        _ = vimKey(editor, r'u')
        @Expect(area.value, "")
        let broken = TextArea()
        let failing = VimEditorBehavior(broken, insertHandler: { target, _ =>
            target.paste("written")
            throw Exception("handler failed")
        })
        _ = vimKey(failing, r'i')
        @ExpectThrows[Exception](vimKey(failing, r'z'))
        @Expect(!vimIsInsert(failing))
        @Expect(broken.value, "written")
        _ = vimKey(failing, r'u')
        @Expect(broken.value, "")
    }
}
