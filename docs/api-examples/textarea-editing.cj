package cjtui_api_example

import core.*

main(): Int64 {
    let editor = TextArea(value: "hello world", cursor: 0)
    let buffer = Buffer(Rect(0, 0, 30, 3))
    editor.setTextWidthOptions(TextWidthOptions())
    editor.render(buffer.area, buffer)
    if (editor.value != "hello world" || editor.textModel.byteLength() != 11 || editor.cursor != 0 ||
        editor.scroll != 0 || editor.horizontalScroll != 0 || editor.readOnly || editor.markdownEditing) {
        throw IllegalStateException("textarea initialization failed")
    }
    editor.select(0, 5)
    if (!editor.hasSelection() || editor.selectedText() != "hello" || editor.selectedRange().isNone() ||
        editor.selectedTexts().size != 1 || editor.selectionStart.isNone() || editor.selectionEnd.isNone()) {
        throw IllegalStateException("selection failed")
    }
    let clipboard = MemoryClipboard()
    if (!editor.copySelectionTo(clipboard) || !editor.cutSelectionTo(clipboard) || !editor.undo() || !editor.redo()) {
        throw IllegalStateException("clipboard or history failed")
    }
    editor.pasteFrom(clipboard)
    editor.select(0, 1)
    editor.deleteSelection()
    editor.paste("H")
    editor.setValue("one two", cursor: 0)
    let revision = editor.editRevision()
    if (editor.findNext("two").getOrThrow() != 4) { throw IllegalStateException("search failed") }
    editor.moveWordLeft()
    editor.moveWordRight()
    _ = editor.findPrevious("one")
    editor.clearSelection()
    editor.setCarets([TextAreaCaret(0)])
    editor.addCaret(TextAreaCaret(2))
    if (editor.carets().size != 2 || editor.cursorPositions(buffer.area).size < 1 || editor.editRevision() != revision) {
        throw IllegalStateException("caret state failed")
    }
    editor.clearExtraCarets()
    _ = editor.cursorPosition(buffer.area, options: TextWidthOptions())
    _ = editor.cursorPosition(buffer.area)
    _ = editor.handleVimNavigation(KeyEvent(KeyCode.Char(r'l')))
    _ = editor.handleWithDirty(KeyEvent(KeyCode.Right), buffer.area)
    _ = editor.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), buffer.area)
    _ = editor.handle(KeyEvent(KeyCode.Char(r'!')))
    editor.clearHistory()
    return 0
}
