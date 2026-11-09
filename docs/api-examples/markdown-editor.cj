package cjtui_api_example

import core.*

main(): Int64 {
    let editor = MarkdownTextEditor(value: "hello", lineNumbers: false)
    editor.area.select(0, 5)
    if (!editor.behavior.toggleBold(editor.area) || editor.area.value != "**hello**") {
        throw IllegalStateException("bold edit failed")
    }
    let behavior = editor.behavior
    let area = TextArea()
    if (!behavior.insertLink(area, url: "https://example.test") || !behavior.insertImage(area) ||
        !behavior.insertReferenceLink(area) || !behavior.insertReferenceDefinition(area) ||
        !behavior.insertFrontmatter(area) || !behavior.insertTable(area) || !behavior.insertCodeFence(area, language: "cj")) {
        throw IllegalStateException("markdown insertion failed")
    }
    let italic = TextArea(value: "word")
    italic.select(0, 4)
    if (!behavior.toggleItalic(italic)) { throw IllegalStateException("italic failed") }
    let code = TextArea(value: "word")
    code.select(0, 4)
    if (!behavior.toggleCode(code)) { throw IllegalStateException("code failed") }
    _ = behavior.handle(area, KeyEvent(KeyCode.Char(r'x')))
    behavior.applyHighlights(area)
    behavior.invalidate()
    _ = editor.handle(KeyEvent(KeyCode.Right))
    let buffer = Buffer(Rect(0, 0, 30, 3))
    editor.render(buffer.area, buffer)
    return 0
}
