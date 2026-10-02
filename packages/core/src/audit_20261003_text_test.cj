package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003TextTest {
    @TestCase
    func wordRightFromWhitespaceStopsAtNextWord(): Unit {
        let buffer = TextBuffer(text: "one two")
        @Expect(buffer.wordRight(TextPosition(0, 3)), TextPosition(0, 4))
        @Expect(buffer.wordRight(TextPosition(0, 2)), TextPosition(0, 4))
        @Expect(buffer.wordRight(TextPosition(0, 4)), TextPosition(0, 7))
        let area = TextArea(value: "one two", cursor: 3)
        @Expect(area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, 4)
        let vimArea = TextArea(value: "one two", cursor: 3)
        let vim = VimEditorBehavior(vimArea)
        @Expect(vim.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'w')))))
        @Expect(vimArea.cursor, 4)
    }

    @TestCase
    func orderedListContinuationDoesNotOverflow(): Unit {
        for ((number, next) in [
            ("9223372036854775807", "9223372036854775808"),
            ("999999999999999999999999999999", "1000000000000000000000000000000"),
            ("009", "10")
        ]) {
            let value = number + ". item"
            let area = TextArea(value: value, cursor: value.size, markdownEditing: true)
            @Expect(area.handle(KeyEvent(KeyCode.Enter)))
            @Expect(area.value, value + "\n" + next + ". ")
            @Expect(area.undo())
            @Expect(area.value, value)
        }
    }

    @TestCase
    func overflowingDocumentSourceOffsetsAreIgnored(): Unit {
        let missing: ?Int64 = None
        let invalid = "999999999999999999999999999999:1000000000000000000000000000000"
        let view = DocumentView(Document([
            DocumentLine(DocumentLineKind.Paragraph, [RichSpan("text", sourceRange: Some(invalid))])
        ]))
        @Expect(view.sourceOffsetForRenderedLine(20, 0), missing)
        @Expect(view.renderedLineForSourceOffset(20, 1), 0)
        @Expect(parseSourceOffset("9223372036854775807:9223372036854775807"), Some(Int64.Max))
        @Expect(parseSourceEndOffset("0:9223372036854775808"), missing)
    }

    @TestCase
    func canceledPendingCompletionCannotReopen(): Unit {
        let area = TextArea(value: "ab", cursor: 2)
        let request = area.beginCompletion("pending")
        @Expect(!area.cancelCompletion())
        let result = TextCompletionResult(request.requestId, request.revision, 0, 2, [TextCompletionItem("abc")])
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("pending", result)))
        @Expect(!area.completionVisible())
    }

    @TestCase
    func escapeDismissalRejectsRepeatedCompletionResults(): Unit {
        let area = TextArea(value: "ab", cursor: 2)
        let request = area.beginCompletion("visible")
        let result = TextCompletionResult(request.requestId, request.revision, 0, 2, [TextCompletionItem("abc")])
        @Expect(area.handleCompletionEvent(Event.TextCompletion("visible", result)))
        @Expect(area.handle(KeyEvent(KeyCode.Esc)))
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("visible", result)))
        @Expect(!area.completionVisible())
    }

    @TestCase
    func startingCompletionHidesPreviousResults(): Unit {
        let area = TextArea(value: "ab", cursor: 2)
        let first = area.beginCompletion("first")
        let result = TextCompletionResult(first.requestId, first.revision, 0, 2, [TextCompletionItem("abc")])
        @Expect(area.handleCompletionEvent(Event.TextCompletion("first", result)))
        _ = area.beginCompletion("second")
        @Expect(!area.completionVisible())
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("first", result)))
    }

    @TestCase
    func noOpTextBufferEditsPreserveRedo(): Unit {
        for (operation in 0..6) {
            let buffer = TextBuffer(text: "abc")
            _ = buffer.insert(TextPosition(0, 3), "d")
            @Expect(buffer.undo())
            match (operation) {
                case 0 => _ = buffer.insert(TextPosition(0, 1), "")
                case 1 => _ = buffer.deleteRange(TextRange(TextPosition(0, 1), TextPosition(0, 1)))
                case 2 => _ = buffer.deleteBackward(TextPosition(0, 0))
                case 3 => _ = buffer.deleteForward(TextPosition(0, 3))
                case 4 => _ = buffer.replace(TextRange(TextPosition(0, 0), TextPosition(0, 3)), "abc")
                case _ => @Expect(buffer.replaceAll("a", "a"), 1)
            }
            @Expect(!buffer.undo())
            @Expect(buffer.redo())
            @Expect(buffer.text(), "abcd")
        }
    }

    @TestCase
    func markdownReadonlyCommandsKeepCursorAndSelectionValid(): Unit {
        let behavior = MarkdownEditorBehavior()
        let area = TextArea(value: "abc", cursor: 3, readOnly: true)
        @Expect(!behavior.handle(area, KeyEvent(KeyCode.Char(r'['))))
        @Expect(area.cursor, 3)
        @Expect(!behavior.insertFrontmatter(area))
        @Expect(area.cursor, 3)
        @Expect(!behavior.toggleBold(area))
        @Expect(!area.hasSelection())
        @Expect(area.value, "abc")
        let position = area.cursorPosition(Rect(0, 0, 10, 1))
        @Expect(position.x, 3)
        @Expect(position.y, 0)
        @Expect(behavior.handle(area, KeyEvent(KeyCode.Left)))
        @Expect(area.cursor, 2)
    }
}
