package cjtui_api_example

import core.*

main(): Int64 {
    let buffer = TextBuffer(text: "hello world\n界")
    let first = TextPosition(0, 0)
    let end = TextPosition(0, 5)
    let range = TextRange(end, first)
    if (range.start != first || range.end != end || range.isEmpty() || first.line != 0 || first.column != 0 ||
        buffer.lineCount() != 2 || buffer.line(1) != "界" || buffer.slice(range) != "hello" ||
        buffer.textModel.byteLength() != 15 || buffer.positionToOffset(TextPosition(1, 0)) != 12 ||
        buffer.offsetToPosition(12) != TextPosition(1, 0) || buffer.clampPosition(TextPosition(1, 2)) != TextPosition(1, 0)) {
        throw IllegalStateException("incorrect text positions")
    }
    if (buffer.wordRight(first) != TextPosition(0, 6) || buffer.wordLeft(TextPosition(0, 11)) != TextPosition(0, 6) ||
        buffer.find("world").getOrThrow() != TextPosition(0, 6) ||
        buffer.findPrevious("hello").getOrThrow() != first || buffer.findAll("l").size != 3) {
        throw IllegalStateException("incorrect text search")
    }
    buffer.beginUndoGroup()
    let inserted = buffer.insert(first, "A")
    let replaced = buffer.replace(TextRange(first, inserted), "B")
    buffer.endUndoGroup()
    if (replaced != TextPosition(0, 1) || !buffer.text().startsWith("B") || !buffer.undo() ||
        !buffer.redo()) { throw IllegalStateException("incorrect undo group") }
    _ = buffer.deleteRange(TextRange(first, TextPosition(0, 1)))
    _ = buffer.deleteBackward(TextPosition(1, 3))
    _ = buffer.deleteForward(TextPosition(0, 0))
    if (buffer.replaceAll("l", "L") != 3) { throw IllegalStateException("replace all failed") }
    buffer.setText("done")
    if (buffer.text() != "done" || !TextRange(first, first).isEmpty()) { throw IllegalStateException("set text failed") }
    return 0
}
