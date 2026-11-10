package cjtui_api_example

import core.*

main(): Int64 {
    let table = PieceTableTextModel(text: "A界\nB")
    let model: EditableTextModel = table
    if (model.byteLength() != 6 || model.lineCount() != 2 || model.line(0) != "A界" ||
        model.lineStart(1) != 5 || model.lineForOffset(5) != 1 || model.clampOffset(2) != 1 ||
        model.slice(4, 1) != "界" || model.text() != "A界\nB") {
        throw IllegalStateException("incorrect text model")
    }
    model.beginUndoGroup()
    model.replace(0, 1, "X")
    model.endUndoGroup()
    if (model.revision() != 1 || !model.undo() || !model.redo() || model.text() != "X界\nB") {
        throw IllegalStateException("text history failed")
    }
    let metrics = model.metrics()
    let zero = TextModelMetrics()
    if (metrics.nodeVisits < 0 || metrics.bytesScanned < 0 || metrics.bytesCopied < 0 ||
        metrics.materializations < 1 || metrics.pieceCount < 1 || metrics.treeHeight < 1 ||
        zero.nodeVisits != 0) { throw IllegalStateException("incorrect model metrics") }
    model.clearHistory()
    if (model.undo()) { throw IllegalStateException("history was not cleared") }
    return 0
}
