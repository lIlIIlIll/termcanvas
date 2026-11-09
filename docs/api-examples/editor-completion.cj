package cjtui_api_example

import core.*

main(): Int64 {
    let editor = TextArea(value: "hel")
    editor.cursor = 3
    let request = editor.beginCompletion("suggest")
    let candidate = TextCompletionItem("hello", detail: "Greeting")
    let result = TextCompletionResult(request.requestId, request.revision, request.prefixStart,
        request.prefixEnd, [candidate])
    if (request.value != "hel" || request.cursor != 3 || request.prefix != "hel" || request.line != 0 ||
        request.column != 3 || candidate.insertText != "hello" || candidate.detail != "Greeting" ||
        !editor.handleCompletionEvent(Event.TextCompletion("suggest", result))) {
        throw IllegalStateException("completion request failed")
    }
    let mark: HighlightSpan = TextDecoration(0, 2, Style.default())
    let caret = TextAreaCaret(2, anchor: Some(0))
    let lines = markdownLineHighlights("# Title")
    let cache = MarkdownHighlightCache()
    if (mark.start != 0 || mark.end != 2 || caret.offset != 2 || caret.anchor.getOrThrow() != 0 ||
        markdownDecorations("# Title").size == 0 || lines[0].line != 0 || lines[0].spans.size == 0 ||
        cache.highlights("# Title").size == 0 || cache.lineHighlights("# Title").size != 1 ||
        cache.visibleHighlights("# Title").size == 0 || cache.recomputeCount() != 1) {
        throw IllegalStateException("editor decorations failed")
    }
    cache.invalidate()
    return 0
}
