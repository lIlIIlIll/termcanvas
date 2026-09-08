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

    @TestCase
    func commandModesCompletionAndRenderingStayOnTheRealEditor(): Unit {
        let app = MarkdownStudio()
        app.editor.setValue("# Heading\n\nbody")
        app.editor.setCarets([TextAreaCaret(app.editor.value.size)])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'b'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'e'))))
        @Expect(app.mode, "edit")
        let completion = app.editor.beginCompletion("md")
        let result = app.update(Event.TextCompletion("md", TextCompletionResult(
            completion.requestId,
            completion.revision,
            completion.prefixStart,
            completion.prefixEnd,
            [TextCompletionItem("release")]
        )))
        @Expect(app.status, "completion")
        match (result.flow) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'p'))))
        @Expect(app.mode, "preview")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        _ = app.update(Event.Tick(TickEvent()))
        let backend = TestBackend(area: Rect(0, 0, 90, 28))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("Preview"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'e'))))
        @Expect(app.mode, "edit")
        let exit = app.update(Event.KeyDown(KeyEvent(KeyCode.CtrlC)))
        match (exit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }

    @TestCase
    func outlineRenderingHandlesEmptyAndNestedHeadings(): Unit {
        @Expect(outlineLines([]), ["(no headings)"])
        let app = MarkdownStudio()
        app.editor.setValue("## A\n### B")
        app.editor.setCarets([TextAreaCaret(app.editor.value.size)])
        _ = app.update(Event.Paste("\n#### C"))
        @Expect(app.outline, ["## A"])
        @Expect(repeatText("x", 0), "")
    }
}
