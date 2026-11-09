package cjtui_api_example

import core.*

main(): Int64 {
    let area = TextArea(value: "ab", cursor: 1)
    let editor = VimEditorBehavior(area, insertHandler: { target, key => target.handle(key) })
    match (editor.mode) {
        case VimMode.Normal => ()
        case _ => throw IllegalStateException("incorrect initial mode")
    }
    if (!editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'i'))))) { throw IllegalStateException("insert mode failed") }
    match (editor.mode) {
        case VimMode.Insert => ()
        case _ => throw IllegalStateException("incorrect insert mode")
    }
    _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
    _ = editor.handle(Event.KeyDown(KeyEvent(KeyCode.Esc)))
    if (area.value != "axb") { throw IllegalStateException("insert failed") }
    editor.deactivate()
    return 0
}
