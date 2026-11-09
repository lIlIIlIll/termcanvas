package cjtui_api_example

import core.*

main(): Int64 {
    let editor = TextArea(value: "hel", cursor: 3)
    let decoration = TextDecoration(0, 3, Style.default())
    editor.setDecorations([decoration])
    let store = TextDecorationStore(revision: editor.editRevision())
    editor.setDecorationProviders([store])
    let update = TextDecorationUpdate(editor.editRevision(), 0, 3, [decoration])
    if (!editor.applyDecorationUpdate("syntax", update) || !editor.clearDecorationLayer("syntax")) {
        throw IllegalStateException("decoration update failed")
    }
    let request = editor.beginCompletion("complete")
    let result = TextCompletionResult(request.requestId, request.revision, request.prefixStart, request.prefixEnd,
        [TextCompletionItem("hello")])
    if (!editor.handleCompletionEvent(Event.TextCompletion("complete", result)) || !editor.completionVisible() ||
        editor.completionRows() != 1) { throw IllegalStateException("completion failed") }
    let buffer = Buffer(Rect(0, 0, 20, 4))
    editor.renderCompletionOverlay(buffer.area, buffer)
    if (!editor.cancelCompletion()) { throw IllegalStateException("completion cancellation failed") }
    let command = editor.completionCommand("async", { req =>
        TextCompletionResult(req.requestId, req.revision, req.prefixStart, req.prefixEnd, [])
    })
    match (command) {
        case Command.AsyncTask(_, _) => ()
        case _ => throw IllegalStateException("completion command failed")
    }
    return 0
}
