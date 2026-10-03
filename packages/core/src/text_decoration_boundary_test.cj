package core

import std.unittest.*
import std.unittest.testmacro.*

class UnavailableTextClipboard <: Clipboard {
    public func getText(): String { throw Exception("clipboard read unavailable") }
    public func setText(_: String): Unit { throw Exception("clipboard write unavailable") }
}

@Test
class TextDecorationBoundaryTest {
    @TestCase
    func emptyHalfOpenRangesNeitherMatchNorInvalidateCachedDecorations(): Unit {
        let store = TextDecorationStore(revision: 4)
        @Expect(store.apply(TextDecorationUpdate(4, 0, 10, [TextDecoration(0, 10, Style(fg: Color.Red))])))
        @Expect(store.query(5, 5).size, 0)
        @Expect(store.query(7, 3).size, 0)
        @Expect(store.query(10, 11).size, 0)
        @Expect(store.query(-1, 0).size, 0)
        @Expect(store.apply(TextDecorationUpdate(4, 5, 5, [])))
        @Expect(store.apply(TextDecorationUpdate(4, 10, 10, [])))
        @Expect(!store.apply(TextDecorationUpdate(3, 5, 5, [])))
        @Expect(store.cachedRanges(), 1)
        @Expect(store.invalidatedRanges(), 0)
        store.onEdit(TextEditDelta(5, 5, 0, 4, 5))
        @Expect(store.revision(), 5)
        @Expect(store.cachedRanges(), 1)
        @Expect(store.invalidatedRanges(), 0)
        @Expect(store.query(4, 6).size, 1)
        @Expect(store.queryCount(), 5)
    }

    @TestCase
    func overlappingParserUpdatesReplaceWholeChunksAndClipTheirSpans(): Unit {
        let store = TextDecorationStore()
        @Expect(store.apply(TextDecorationUpdate(0, 20, 30, [TextDecoration(18, 40, Style(fg: Color.Green))])))
        @Expect(store.apply(TextDecorationUpdate(0, 0, 10, [TextDecoration(0, 10, Style(fg: Color.Red))])))
        @Expect(store.apply(TextDecorationUpdate(0, 10, 20, [TextDecoration(10, 20, Style(fg: Color.Blue))])))
        @Expect(store.cachedRanges(), 3)
        @Expect(store.invalidatedRanges(), 0)
        @Expect(store.apply(TextDecorationUpdate(0, 5, 15, [
            TextDecoration(0, 40, Style(fg: Color.Cyan)),
            TextDecoration(25, 30, Style(fg: Color.Yellow)),
            TextDecoration(7, 7, Style(fg: Color.White))
        ])))
        @Expect(store.cachedRanges(), 2)
        @Expect(store.invalidatedRanges(), 2)
        let spans = store.query(0, 40)
        @Assert(spans.size, 2)
        @Expect(spans[0].start, 5)
        @Expect(spans[0].end, 15)
        @Expect(spans[0].style, Style(fg: Color.Cyan))
        @Expect(spans[1].start, 20)
        @Expect(spans[1].end, 30)
        @Expect(store.query(15, 20).size, 0)
        @Expect(store.query(30, 50).size, 0)
    }

    @TestCase
    func byteEditsShiftLaterChunksAndRevisionGapsDiscardUnverifiableRanges(): Unit {
        let store = TextDecorationStore(revision: 1)
        for (start in [Int64(0), 10, 20]) {
            @Expect(store.apply(TextDecorationUpdate(1, start, start + 5, [TextDecoration(start, start + 5, Style(fg: Color.Red))])))
        }
        // Insertion at a chunk boundary leaves the preceding chunk intact.
        store.onEdit(TextEditDelta(5, 5, 3, 1, 2))
        let shifted = store.query(0, 40)
        @Assert(shifted.size, 3)
        @Expect(shifted[0].start, 0)
        @Expect(shifted[1].start, 13)
        @Expect(shifted[2].start, 23)
        // Replacement invalidates the intersected chunk and translates only
        // the suffix, including every span's previously accumulated shift.
        store.onEdit(TextEditDelta(14, 16, 1, 2, 3))
        let after = store.query(0, 40)
        @Assert(after.size, 2)
        @Expect(after[0].end, 5)
        @Expect(after[1].start, 22)
        @Expect(after[1].end, 27)
        @Expect(store.invalidatedRanges(), 1)
        store.onEdit(TextEditDelta(0, 0, 1, 99, 100))
        @Expect(store.revision(), 100)
        @Expect(store.cachedRanges(), 0)
        @Expect(store.invalidatedRanges(), 3)
        @Expect(!store.apply(TextDecorationUpdate(3, 0, 1, [])))
        @Expect(store.apply(TextDecorationUpdate(100, 0, 1, [])))
        store.reset(101)
        @Expect(store.cachedRanges(), 0)
        @Expect(store.invalidatedRanges(), 4)
    }

    @TestCase
    func namedLayersReplaceInPlaceAndCanBeRemovedIndependently(): Unit {
        let area = TextArea(value: "abcd")
        let revision = area.editRevision()
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(revision, 0, 4, [TextDecoration(0, 4, Style(fg: Color.Red))])))
        @Expect(area.applyDecorationUpdate("search", TextDecorationUpdate(revision, 1, 3, [TextDecoration(1, 3, Style(bg: Color.Yellow))])))
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(revision, 0, 4, [TextDecoration(0, 4, Style(fg: Color.Green))])))
        @Expect(!area.applyDecorationUpdate("outside", TextDecorationUpdate(revision, 0, 5, [])))
        @Expect(!area.clearDecorationLayer("outside"))
        let rect = Rect(0, 0, 8, 1)
        let before = Buffer(rect)
        area.render(rect, before)
        @Expect(before.getCell(1, 0).style, Style(fg: Color.Green, bg: Color.Yellow))
        @Expect(area.clearDecorationLayer("syntax"))
        @Expect(!area.clearDecorationLayer("syntax"))
        let after = Buffer(rect)
        area.render(rect, after)
        @Expect(after.getCell(0, 0).style, Style.default())
        @Expect(after.getCell(1, 0).style, Style(bg: Color.Yellow))
        @Expect(area.clearDecorationLayer("search"))
    }

    @TestCase
    func documentLoadAndHistoryMovementInvalidateOwnedHighlightLayers(): Unit {
        let area = TextArea(value: "abcd", cursor: 4)
        let rect = Rect(0, 0, 10, 1)
        area.paste("x")
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(area.editRevision(), 0, 4, [TextDecoration(0, 4, Style(fg: Color.Red))])))
        @Expect(area.undo())
        let undone = Buffer(rect)
        area.render(rect, undone)
        @Expect(undone.getCell(0, 0).style, Style.default())
        @Expect(area.redo())
        area.select(0, 2)
        area.addCaret(TextAreaCaret(5))
        area.horizontalScroll = 3
        area.scroll = 2
        @Expect(area.applyDecorationUpdate("syntax", TextDecorationUpdate(area.editRevision(), 0, 4, [TextDecoration(0, 4, Style(fg: Color.Red))])))
        area.setValue("界z", cursor: 1)
        @Expect(area.value, "界z")
        @Expect(area.cursor, 0)
        @Expect(area.scroll, 0)
        @Expect(area.horizontalScroll, 0)
        @Expect(!area.hasSelection())
        @Expect(area.carets().size, 1)
        @Expect(!area.undo())
        @Expect(!area.redo())
        let loaded = Buffer(rect)
        area.render(rect, loaded)
        @Expect(loaded.getCell(0, 0).style, Style.default())
        area.setValue("end")
        @Expect(area.cursor, 3)
    }

    @TestCase
    func clipboardFailuresPreserveSelectionAndReadonlyCutNeverWrites(): Unit {
        let area = TextArea(value: "a界b")
        let unavailable = UnavailableTextClipboard()
        @Expect(!area.copySelectionTo(unavailable))
        @Expect(!area.cutSelectionTo(unavailable))
        area.select(1, 4)
        @Expect(!area.copySelectionTo(unavailable))
        @Expect(!area.cutSelectionTo(unavailable))
        area.pasteFrom(unavailable)
        @Expect(area.value, "a界b")
        @Expect(area.selectedText(), "界")
        let memory = MemoryClipboard(text: "preserve")
        area.readOnly = true
        @Expect(!area.cutSelectionTo(memory))
        @Expect(memory.getText(), "preserve")
        area.pasteFrom(memory)
        area.deleteSelection()
        @Expect(area.selectedText(), "界")
        area.readOnly = false
        @Expect(area.cutSelectionTo(memory))
        @Expect(memory.getText(), "界")
        @Expect(area.value, "ab")
        @Expect(area.undo())
        @Expect(area.value, "a界b")
    }

    @TestCase
    func caretsClampUnicodeOffsetsAndEmptyCaretsClearOnlyExtraSelections(): Unit {
        let area = TextArea(value: "a界b", cursor: 5)
        area.setCarets([TextAreaCaret(2, anchor: Some(Int64(5))), TextAreaCaret(100, anchor: Some(Int64(4)))])
        @Expect(area.cursor, 1)
        @Expect(area.selectedTexts(), ["界b", "b"])
        @Expect(area.carets()[1].offset, 5)
        area.setCarets([])
        @Expect(area.cursor, 1)
        @Expect(area.carets().size, 1)
        @Expect(!area.hasSelection())
        area.addCaret(TextAreaCaret(-1, anchor: Some(Int64(-5))))
        @Expect(area.carets()[1].offset, 0)
        @Expect(area.selectedTexts().size, 0)
        area.clearExtraCarets()
        @Expect(area.carets().size, 1)
    }

    @TestCase
    func completionNavigationClampsAndReadonlyCannotAccept(): Unit {
        let area = TextArea(value: "ab", cursor: 2, readOnly: true)
        @Expect(area.completionRows(), 0)
        @Expect(!area.handleCompletionEvent(Event.Message("unrelated")))
        @Expect(!area.handleCompletionEvent(Event.AsyncCompleted("other", Event.Message("unrelated"))))
        let request = area.beginCompletion("choices")
        let result = TextCompletionResult(request.requestId, request.revision, 0, 2, [
            TextCompletionItem("first", insertText: "A", detail: "alpha"),
            TextCompletionItem("second", insertText: "B")
        ])
        @Expect(area.handleCompletionEvent(Event.AsyncCompleted("choices", Event.TextCompletion("choices", result))))
        @Expect(area.completionRows(maximum: -1), 0)
        @Expect(area.completionRows(maximum: 1), 1)
        @Expect(area.completionRows(maximum: 100), 2)
        @Expect(area.handle(KeyEvent(KeyCode.Up)))
        @Expect(area.handle(KeyEvent(KeyCode.Down)))
        @Expect(area.handle(KeyEvent(KeyCode.Down)))
        @Expect(!area.handle(KeyEvent(KeyCode.Enter)))
        @Expect(!area.handle(KeyEvent(KeyCode.Tab)))
        @Expect(area.value, "ab")
        @Expect(area.completionVisible())
        let empty = Rect(0, 0, 0, 0)
        area.renderCompletionOverlay(empty, Buffer(empty))
        let rect = Rect(0, 0, 12, 3)
        area.renderCompletionOverlay(rect, Buffer(rect))
        area.readOnly = false
        @Expect(area.handle(KeyEvent(KeyCode.Tab)))
        @Expect(area.value, "B")
        @Expect(!area.completionVisible())
        @Expect(area.undo())
        @Expect(area.value, "ab")
    }

    @TestCase
    func emptyAndStaleCompletionResultsCannotResurrectCancelledRequests(): Unit {
        let area = TextArea(value: "ab", cursor: 2)
        let request = area.beginCompletion("pending")
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("wrong", TextCompletionResult("wrong", request.revision, 0, 2, [TextCompletionItem("x")]))))
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("pending", TextCompletionResult("pending", request.revision + 1, 0, 2, [TextCompletionItem("x")]))))
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("pending", TextCompletionResult("pending", request.revision, 0, 2, []))))
        @Expect(!area.cancelCompletion())
        @Expect(!area.handleCompletionEvent(Event.TextCompletion("pending", TextCompletionResult("pending", request.revision, 0, 2, [TextCompletionItem("x")]))))
        @Expect(area.value, "ab")
    }
}
