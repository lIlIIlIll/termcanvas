package cjtui_api_example

import core.*

main(): Int64 {
    let heading = Style(fg: Color.Cyan)
    let theme: MarkdownTheme = DocumentTheme(heading1: Some(heading))
    let document: MarkdownDocument = Document.plain("One\nTwo")
    if (theme.headingStyle(1) != heading || document.lines.size != 2) { throw IllegalStateException("document theme failed") }
    let state = DocumentViewState(scroll: 1, cursorSourceOffset: Some(3), selectedLinkIndex: 2, searchMatchIndex: 1)
    state.setFolded(2, 6, true)
    if (state.scroll != 1 || state.cursorSourceOffset.getOrThrow() != 3 || state.selectedLinkIndex != 2 ||
        state.searchMatchIndex != 1 || !state.isFolded(2, 6) || state.folds().size != 1) {
        throw IllegalStateException("document state failed")
    }
    if (state.toggleFold(2, 6) || state.isFolded(2, 6)) { throw IllegalStateException("fold toggle failed") }
    state.setFolded(0, 4, true)
    state.clearFolds()
    if (state.folds().size != 0) { throw IllegalStateException("fold clear failed") }
    return 0
}
