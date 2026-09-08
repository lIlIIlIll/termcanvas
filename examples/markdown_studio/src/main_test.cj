package markdown_studio

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class MarkdownStudioRegressionTest {
    @TestCase
    func pasteAndOrdinaryLettersUpdateTheRealEditorAndPreview(): Unit {
        let app = MarkdownStudio()
        app.editor.setValue("")
        app.editor.setCarets([TextAreaCaret(0)])
        _ = app.update(Event.Paste("# 粘贴\n\n正文"))
        @Expect(app.editor.value, "# 粘贴\n\n正文")
        @Expect(app.outline[0], "# 粘贴")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        @Expect(app.editor.value.endsWith("正文q"))
        @Expect(app.mode, "edit")
    }

    @TestCase
    func previewNavigationRetainsScrollBetweenEvents(): Unit {
        let app = MarkdownStudio()
        app.editor.setValue("")
        app.editor.setCarets([TextAreaCaret(0)])
        var text = ""
        for (i in 0..30) { text += "# Heading ${i}\n" }
        _ = app.update(Event.Paste(text))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'p'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.previewState.scroll, 1)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.previewState.scroll, 2)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        @Expect(app.previewState.scroll, 12)
    }
}
