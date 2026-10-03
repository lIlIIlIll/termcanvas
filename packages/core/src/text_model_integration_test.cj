package core

import std.unittest.*
import std.unittest.testmacro.*

class VisibleRangeDecorationProbe <: TextDecorationProvider {
    let generation: Int64
    var calls: Int64 = 0
    var queriedBytes: Int64 = 0
    init(revision: Int64) { generation = revision }
    public func revision(): Int64 { generation }
    public func query(start: Int64, end: Int64): Array<TextDecoration> {
        calls++
        queriedBytes += end - start
        [TextDecoration(start, end, Style(fg: Color.Cyan))]
    }
}

@Test
class TextModelIntegrationTest {
    @TestCase
    func wordNavigationCopiesEachVisitedLineOnce(): Unit {
        let word = repeat("a", 2048)
        let model = PieceTableTextModel(text: word + "\n  x")
        let area = TextArea(model: Some(model))
        let before = model.metrics()
        _ = area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(ctrl: true)))
        @Expect(area.cursor, word.size + 3)
        _ = area.handle(KeyEvent(KeyCode.Left, modifiers: KeyModifier(ctrl: true)))
        @Expect(area.cursor, 0)
        let after = model.metrics()
        @Expect(after.materializations, before.materializations)
        @Expect(after.bytesCopied - before.bytesCopied < word.size * 8)
        let buffer = TextBuffer(model: Some(model))
        let beforeBuffer = model.metrics()
        @Expect(buffer.wordRight(TextPosition(0, 0)), TextPosition(1, 2))
        @Expect(buffer.wordLeft(TextPosition(1, 2)), TextPosition(0, 0))
        @Expect(model.metrics().materializations, beforeBuffer.materializations)
    }

    @TestCase
    func decorationBoundariesPreserveCombiningAndJoinedGraphemes(): Unit {
        let value = "e\u{301}👩‍💻x"
        let area = TextArea(value: value)
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(area.editRevision(), 0, value.size,
            [TextDecoration(1, 3, Style(fg: Color.Cyan)), TextDecoration(7, 10, Style(fg: Color.Green))])))
        let rect = Rect(0, 0, 10, 1)
        let buffer = Buffer(rect)
        area.render(rect, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "e\u{301}")
        @Expect(buffer.getCell(1, 0).symbol, "👩‍💻")
        @Expect(buffer.getCell(3, 0).symbol, "x")
        @Expect(colorEquals(buffer.getCell(0, 0).style.fg, Color.Cyan))
        @Expect(colorEquals(buffer.getCell(1, 0).style.fg, Color.Green))
    }

    @TestCase
    func mouseAndExtraCaretsUseTheScrolledUnicodeColumns(): Unit {
        let value = "0界2界4界6界8"
        let area = TextArea(value: value, cursor: value.size)
        area.addCaret(TextAreaCaret(0))
        let rect = Rect(2, 3, 6, 2)
        area.render(rect, Buffer(rect))
        @Expect(area.cursorPositions(rect).size, 1)
        @Expect(area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3), rect))
        @Expect(area.cursor, 12)
        @Expect(area.handleMouse(MouseEvent(MouseKind.Drag, MouseButton.Left, 5, 3), rect))
        @Expect(area.selectedText(), "6")
        @Expect(area.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 5, 3), rect))
        @Expect(!area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 8, 3), rect))
    }

    @TestCase
    func shiftClickExtendsAndAltClickAddsAnEditableCaret(): Unit {
        let area = TextArea(value: "abcdef", cursor: 1)
        let rect = Rect(0, 0, 10, 1)
        area.render(rect, Buffer(rect))
        let request = area.beginCompletion("before-mouse")
        _ = area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 0, modifiers: KeyModifier(shift: true)), rect)
        @Expect(area.selectedText(), "bc")
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("before-mouse",
            TextCompletionResult(request.requestId, request.revision, 0, 1, [TextCompletionItem("stale")]))))
        _ = area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 0, modifiers: KeyModifier(alt: true)), rect)
        @Expect(area.carets().size, 2)
        area.paste("X")
        @Expect(area.value, "aXdeXf")
        @Expect(area.undo())
        @Expect(area.value, "abcdef")
    }

    @TestCase
    func realEditorEditRenderAndUndoDoNotMaterializeTheDocument(): Unit {
        for (count in [1000, 100000]) {
            let model = PieceTableTextModel(text: repeat("0123456789\n", count))
            let offset = model.lineStart(count / 2) + 4
            let area = TextArea(model: Some(model), cursor: offset)
            let rect = Rect(0, 0, 20, 8)
            area.render(rect, Buffer(rect))
            let before = model.metrics()
            _ = area.handle(KeyEvent(KeyCode.Char(r'x')))
            area.render(rect, Buffer(rect))
            let after = model.metrics()
            @Expect(after.materializations, before.materializations)
            @Expect(after.bytesScanned - before.bytesScanned < 128)
            @Expect(after.bytesCopied - before.bytesCopied < 4096)
            @Expect(model.slice(offset, offset + 2), "x4")
            @Expect(area.undo())
            @Expect(model.slice(offset, offset + 1), "4")
            @Expect(area.redo())
            @Expect(model.slice(offset, offset + 2), "x4")
            @Expect(model.metrics().materializations, before.materializations)
        }
    }

    @TestCase
    func vimAndTextBufferUseTheInjectedIncrementalModel(): Unit {
        let model = PieceTableTextModel(text: repeat("abc\n", 10000))
        let area = TextArea(model: Some(model), cursor: model.lineStart(5000))
        let before = model.metrics()
        let vim = VimEditorBehavior(area)
        _ = vim.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'i'))))
        _ = vim.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        _ = vim.handle(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(model.metrics().materializations, before.materializations)
        @Expect(model.slice(model.lineStart(5000), model.lineStart(5000) + 4), "xabc")
        @Expect(area.undo())
        let buffer = TextBuffer(model: Some(model))
        _ = buffer.insert(TextPosition(5000, 0), "y")
        @Expect(model.line(5000), "yabc")
        @Expect(buffer.undo())
        @Expect(model.line(5000), "abc")
    }

    @TestCase
    func multiCaretNavigationAndEditsRemainOneUndoTransaction(): Unit {
        let area = TextArea(value: "abc\ndef")
        area.setCarets([TextAreaCaret(1), TextAreaCaret(5)])
        _ = area.handle(KeyEvent(KeyCode.Right, modifiers: KeyModifier(shift: true)))
        @Expect(area.selectedTexts(), ["b", "e"])
        area.paste("界")
        @Expect(area.value, "a界c\nd界f")
        @Expect(area.undo())
        @Expect(area.value, "abc\ndef")
        @Expect(area.selectedTexts(), ["b", "e"])
        @Expect(area.redo())
        @Expect(area.value, "a界c\nd界f")
    }

    @TestCase
    func decorationRangesSurviveUnrelatedEditsAndRejectStaleResults(): Unit {
        let area = TextArea(value: "aaaa\nbbbb\ncccc")
        let store = TextDecorationStore(revision: area.editRevision())
        @Expect(store.apply(TextDecorationUpdate(area.editRevision(), 0, 4, [TextDecoration(0, 4, Style(fg: Color.Red))])))
        @Expect(store.apply(TextDecorationUpdate(area.editRevision(), 5, 9, [TextDecoration(5, 9, Style(fg: Color.Green))])))
        area.setDecorationProviders([store])
        let oldRevision = area.editRevision()
        area.cursor = 2
        area.paste("x")
        @Expect(store.cachedRanges(), 1)
        @Expect(store.invalidatedRanges(), 1)
        let remaining = store.query(6, 10)
        @Expect(remaining.size, 1)
        @Expect(remaining[0].start, 6)
        @Expect(remaining[0].end, 10)
        @Expect(!store.apply(TextDecorationUpdate(oldRevision, 0, 4, [])))
        @Expect(!area.applyDecorationUpdate("syntax", TextDecorationUpdate(oldRevision, 0, 4, [])))
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(area.editRevision(), 0, 5, [TextDecoration(0, 5, Style(fg: Color.Red))])))
        let rect = Rect(0, 0, 10, 3)
        let buffer = Buffer(rect)
        area.render(rect, buffer)
        @Expect(colorEquals(buffer.getCell(0, 0).style.fg, Color.Red))
        @Expect(colorEquals(buffer.getCell(0, 1).style.fg, Color.Green))
    }

    @TestCase
    func providersQueryOnlyVisibleRangesAndSelectionIsTheFinalLayer(): Unit {
        let model = PieceTableTextModel(text: repeat("abcd\n", 10000))
        let area = TextArea(model: Some(model), cursor: model.lineStart(5000))
        let provider = VisibleRangeDecorationProbe(area.editRevision())
        area.setDecorationProviders([provider])
        let offset = model.lineStart(5000)
        @Expect(area.applyDecorationUpdate("search", TextDecorationUpdate(area.editRevision(), offset, offset + 4,
            [TextDecoration(offset, offset + 4, Style(bg: Color.Yellow))])))
        area.select(offset + 1, offset + 2)
        let rect = Rect(0, 0, 10, 4)
        let buffer = Buffer(rect)
        area.render(rect, buffer)
        @Expect(provider.calls, 4)
        @Expect(provider.queriedBytes, 16)
        let row = area.cursorPosition(rect).y
        @Expect(buffer.getCell(0, row).style, Style(fg: Color.Cyan, bg: Color.Yellow))
        @Expect(buffer.getCell(1, row).style, Style(fg: Color.Black, bg: Color.White))
        area.clearSelection()
        area.paste("x")
        let fresh = Buffer(rect)
        area.render(rect, fresh)
        // Providers with the previous revision cannot repaint new text.
        @Expect(provider.calls, 4)
        @Expect(fresh.getCell(0, row).style, Style.default())
    }
}
