package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class EditorContractBoundaryTest {
    @TestCase
    func identicalReplacementAndEmptyPasteDoNotCreateUndoEntries(): Unit {
        let area = TextArea(value: "alpha beta", cursor: 3)
        let revision = area.editRevision()
        area.paste("")
        area.select(0, 5)
        area.paste("alpha")
        @Expect(area.value, "alpha beta")
        @Expect(area.cursor, 5)
        @Expect(!area.hasSelection())
        @Expect(area.editRevision(), revision)
        @Expect(!area.undo())
        @Expect(area.findNext("missing").isNone())
        area.cursor = area.value.size
        @Expect(area.findPrevious("alpha"), Some(0))
        @Expect(area.selectedText(), "alpha")
        @Expect(area.findPrevious("missing").isNone())
        area.clearSelection()
        @Expect(area.selectedText(), "")
    }

    @TestCase
    func readOnlyEditingCommandsRejectMutationAndKeepNavigation(): Unit {
        let area = TextArea(value: "abc\ndef", cursor: 2, readOnly: true)
        for (key in [KeyCode.Enter, KeyCode.Backspace, KeyCode.Delete, KeyCode.Tab, KeyCode.BackTab, KeyCode.Char(r'x')]) {
            @Expect(!area.handle(KeyEvent(key)))
        }
        for (key in [r'k', r'u', r'w', r'z', r'y', r'q']) {
            @Expect(!area.handle(KeyEvent(KeyCode.Char(key), modifiers: KeyModifier(ctrl: true))))
        }
        area.select(0, 2)
        area.deleteSelection()
        area.paste("changed")
        @Expect(area.value, "abc\ndef")
        @Expect(area.handleVimNavigation(KeyEvent(KeyCode.Char(r'h'))))
        @Expect(area.cursor, 0)
        @Expect(area.handleVimNavigation(KeyEvent(KeyCode.Char(r'$'))))
        @Expect(area.cursor, 3)
        @Expect(area.handleVimNavigation(KeyEvent(KeyCode.Char(r'k'))))
        @Expect(area.handleVimNavigation(KeyEvent(KeyCode.Char(r'0'))))
        @Expect(area.cursor, 0)
        @Expect(!area.handleVimNavigation(KeyEvent(KeyCode.F(1))))
    }

    @TestCase
    func controlDeletionUsesSelectionBeforeLineOrWordBoundaries(): Unit {
        for (key in [r'k', r'u', r'w']) {
            let area = TextArea(value: "one two\nthree", cursor: 5)
            area.select(4, 7)
            @Expect(area.handle(KeyEvent(KeyCode.Char(key), modifiers: KeyModifier(ctrl: true))))
            @Expect(area.value, "one \nthree")
            @Expect(area.cursor, 4)
            @Expect(area.undo())
            @Expect(area.value, "one two\nthree")
        }
    }

    @TestCase
    func multicaretDeletionCoalescesOverlappingAndBoundaryRanges(): Unit {
        let area = TextArea(value: "abcdef")
        area.setCarets([TextAreaCaret(6), TextAreaCaret(2), TextAreaCaret(0), TextAreaCaret(2)])
        @Expect(area.handle(KeyEvent(KeyCode.Backspace)))
        @Expect(area.value, "acde")
        @Expect(area.undo())
        @Expect(area.value, "abcdef")
        area.setCarets([TextAreaCaret(5, anchor: Some(2)), TextAreaCaret(3, anchor: Some(1)), TextAreaCaret(6)])
        @Expect(area.handle(KeyEvent(KeyCode.Delete)))
        @Expect(area.value, "af")
        @Expect(area.undo())
        area.setCarets([TextAreaCaret(0), TextAreaCaret(2), TextAreaCaret(6)])
        @Expect(area.handle(KeyEvent(KeyCode.Delete)))
        @Expect(area.value, "bdef")
    }

    @TestCase
    func selectingCaretsCollapseInDirectionAndRenderMergedHighlights(): Unit {
        let area = TextArea(value: "abcdef\nxyz")
        area.setCarets([TextAreaCaret(5, anchor: Some(2)), TextAreaCaret(4, anchor: Some(1))])
        area.render(Rect(0, 0, 8, 2), Buffer(Rect(0, 0, 8, 2)))
        @Expect(area.handle(KeyEvent(KeyCode.Left)))
        @Expect(area.carets()[0].offset, 2)
        @Expect(area.carets()[1].offset, 1)
        area.setCarets([TextAreaCaret(2, anchor: Some(5)), TextAreaCaret(1, anchor: Some(4))])
        @Expect(area.handle(KeyEvent(KeyCode.Right)))
        @Expect(area.carets()[0].offset, 5)
        @Expect(area.carets()[1].offset, 4)
        area.setCarets([])
        @Expect(area.carets().size, 1)
        @Expect(!area.hasSelection())
    }

    @TestCase
    func dirtyNavigationAndMouseEdgesKeepSelectionConsistent(): Unit {
        let area = TextArea(value: "abc\ndef\nghi")
        let rect = Rect(2, 2, 8, 2)
        area.render(rect, Buffer(Rect(0, 0, 12, 8)))
        @Expect(area.handleWithDirty(KeyEvent(KeyCode.PageDown), rect).isSome())
        @Expect(area.handleWithDirty(KeyEvent(KeyCode.PageUp), rect).isSome())
        @Expect(area.handleWithDirty(KeyEvent(KeyCode.F(1)), rect).isNone())
        @Expect(!area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, 3, 2), rect))
        @Expect(!area.handleMouse(MouseEvent(MouseKind.Drag, MouseButton.Left, 0, 0), rect))
        @Expect(!area.handleMouse(MouseEvent(MouseKind.Scroll, MouseButton.Left, 3, 2), rect))
        area.cursor = 0
        @Expect(area.handleMouse(MouseEvent(MouseKind.Drag, MouseButton.Left, 4, 2), rect))
        @Expect(area.selectedText(), "ab")
        @Expect(area.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 4, 2), rect))
    }

    @TestCase
    func markdownCommandsProduceUndoableDocumentsAndRejectReadOnly(): Unit {
        let behavior = MarkdownEditorBehavior()
        let area = TextArea(value: "word", cursor: 2)
        @Expect(behavior.toggleItalic(area))
        @Expect(area.value, "*word*")
        @Expect(area.undo())
        @Expect(behavior.toggleCode(area))
        @Expect(area.value, "`word`")
        area.setValue("word")
        area.select(0, 4)
        @Expect(behavior.insertLink(area, url: "target"))
        @Expect(area.value, "[word](target)")
        area.setValue("")
        @Expect(behavior.insertLink(area, url: "target"))
        @Expect(area.value, "[text](target)")
        area.setValue("")
        @Expect(behavior.insertImage(area, url: "img", alt: "label"))
        @Expect(area.value, "![label](img)")
        area.setValue("")
        @Expect(behavior.insertReferenceLink(area, id: "source"))
        @Expect(area.value, "[text][source]")
        area.setValue("")
        @Expect(behavior.insertTable(area))
        @Expect(area.value.contains("| --- | --- |"))
        area.setValue("")
        @Expect(behavior.insertCodeFence(area, language: "cj"))
        @Expect(area.value, "```cj\n\n```\n")
        area.readOnly = true
        @Expect(!behavior.toggleBold(area))
        @Expect(!behavior.toggleItalic(area))
        @Expect(!behavior.toggleCode(area))
        @Expect(!behavior.insertLink(area))
        @Expect(!behavior.insertImage(area))
        @Expect(!behavior.insertReferenceLink(area))
        @Expect(!behavior.insertReferenceDefinition(area))
        @Expect(!behavior.insertFrontmatter(area))
        @Expect(!behavior.insertTable(area))
        @Expect(!behavior.insertCodeFence(area))
        @Expect(!behavior.handle(area, KeyEvent(KeyCode.Char(r'('))))
    }

    @TestCase
    func markdownPairsClosingDelimitersAndWrapperRender(): Unit {
        let editor = MarkdownTextEditor(lineNumbers: false)
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'('))))
        @Expect(editor.area.value, "()")
        @Expect(editor.area.cursor, 1)
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r')'))))
        @Expect(editor.area.value, "()")
        @Expect(editor.area.cursor, 2)
        editor.area.setValue("")
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'`'))))
        @Expect(editor.area.value, "``")
        editor.area.setValue("")
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'['))))
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r']'))))
        @Expect(editor.area.value, "[]")
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(editor.area.value, "[]x")
        @Expect(editor.handle(KeyEvent(KeyCode.Tab)))
        @Expect(editor.handle(KeyEvent(KeyCode.BackTab)))
        let rect = Rect(0, 0, 20, 3)
        let buffer = Buffer(rect)
        editor.behavior.invalidate()
        editor.render(rect, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "[")
    }

    @TestCase
    func markdownIndentationAndHighlightInvalidationAreStable(): Unit {
        let area = TextArea(value: "  quote", cursor: 7, markdownEditing: true)
        @Expect(area.handle(KeyEvent(KeyCode.Enter)))
        @Expect(area.value, "  quote\n  ")
        area.setValue("  > quote")
        @Expect(area.handle(KeyEvent(KeyCode.Enter)))
        @Expect(area.value, "  > quote\n  > ")
        area.setValue("  two\n one\nzero")
        area.select(0, area.value.size)
        @Expect(area.handle(KeyEvent(KeyCode.BackTab)))
        @Expect(area.value, "two\none\nzero")
        let cache = MarkdownHighlightCache()
        @Expect(cache.highlights("# title").size > 0)
        let count = cache.recomputeCount()
        cache.invalidate()
        @Expect(cache.lineHighlights("# title").size, 1)
        @Expect(cache.recomputeCount(), count + 1)
        @Expect(cache.visibleHighlights("# title", firstLine: -10, lineCount: 0).isEmpty())
    }
}
