package markdown_studio

import core.*
import markdown_adapter.parseSyntaxHighlightConfig
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
        let backend = TestBackend(area: Rect(0, 0, 110, 30))
        _ = Terminal(backend).draw { frame => app.render(frame) }
        @Expect(!backend.output().contains("\u{1B}[2 q"))
        @Expect(!backend.output().contains("\u{1B}[6 q"))
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
        @Expect(app.editor.completionVisible())
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

    @TestCase
    func vimOptInKeepsEditorPreviewAndCompletionOwnership(): Unit {
        let app = MarkdownStudio(vim: true)
        let backend = TestBackend(area: Rect(0, 0, 110, 30))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("NORMAL"))
        @Expect(backend.output().contains("\u{1B}[2 q"))
        backend.clearOutput()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'i'))))
        _ = app.update(Event.Paste("# Vim\n"))
        @Expect(app.outline[0], "# Vim")
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("INSERT"))
        @Expect(backend.snapshot().contains("# Vim"))
        @Expect(backend.output().contains("\u{1B}[6 q"))
        backend.clearOutput()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.output().contains("\u{1B}[2 q"))
        backend.clearOutput()
        let beforeMove = app.editor.cursor
        let beforeText = app.editor.value
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'h'))))
        @Expect(app.editor.cursor <= beforeMove)
        @Expect(app.editor.value, beforeText)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        app.previewHeight = 2
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.previewState.scroll, 1)
        @Expect(app.editor.value, beforeText)
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("PREVIEW"))
        @Expect(backend.output().contains("\u{1B}[0 q"))
        backend.clearOutput()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("NORMAL"))
        @Expect(backend.output().contains("\u{1B}[2 q"))
        backend.clearOutput()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'i'))))
        let result = app.update(Event.KeyDown(KeyEvent(KeyCode.F(3))))
        match (result.command) {
            case Command.Emit(event) =>
                _ = app.update(event)
                @Expect(app.editor.completionVisible())
            case _ => @Expect(false)
        }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(!app.editor.completionVisible())
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("INSERT"))
        @Expect(backend.output().contains("\u{1B}[6 q"))
        let exit = app.update(Event.KeyDown(KeyEvent(KeyCode.CtrlC)))
        match (exit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
    @TestCase
    func changingLanguageAndDeletingBlockReplacesBothRenderedPalettes(): Unit {
        let app = MarkdownStudio()
        app.editor.setValue("```cj\nlet x = 1\n```")
        app.editor.setCarets([TextAreaCaret(0)])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        let source = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 40, 4))
        DocumentView(app.doc).render(preview.area, preview)
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        @Expect(source.getCell(4, 2).style, keyword)
        @Expect(preview.getCell(0, 0).style, keyword)

        app.editor.setValue("```go\nlet x = 1\n```")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        let unknown = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(unknown.area, unknown)
        let unknownPreview = Buffer(Rect(0, 0, 40, 4))
        DocumentView(app.doc).render(unknownPreview.area, unknownPreview)
        @Expect(unknown.getCell(4, 2).symbol, "l")
        @Expect(unknown.getCell(4, 2).style, DocumentTheme().code)
        @Expect(unknownPreview.getCell(0, 0).style, DocumentTheme().code)

        app.editor.setValue("```json\n{\"a\": true}\n```")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        let json = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(json.area, json)
        let jsonPreview = Buffer(Rect(0, 0, 40, 4))
        DocumentView(app.doc).render(jsonPreview.area, jsonPreview)
        @Expect(json.getCell(5, 2).style, Style(fg: Color.Cyan))
        @Expect(jsonPreview.getCell(1, 0).style, Style(fg: Color.Cyan))

        app.editor.setValue("")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        app.editor.setValue("# Outside")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        let outside = Buffer(Rect(0, 0, 40, 4))
        app.editor.render(outside.area, outside)
        @Expect(outside.getCell(4, 1).style, keyword)
        let after = Buffer(Rect(0, 0, 40, 2))
        DocumentView(app.doc).render(after.area, after)
        @Expect(after.getCell(0, 0).style, DocumentTheme().headingStyle(1))
    }

    @TestCase
    func vimPasteUndoAndRedoReplaceCodeColorsWithoutModeRegression(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword cyan bold\nend")
        let app = MarkdownStudio(vim: true, syntax: Some(config))
        app.editor.setValue("")
        app.editor.setCarets([TextAreaCaret(0)])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'i'))))
        _ = app.update(Event.Paste("```wf\ntask\n```"))
        let first = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(first.area, first)
        let keyword = Style(fg: Color.Cyan, modifier: Modifier.strong())
        @Expect(first.getCell(4, 2).style, keyword)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'u'))))
        @Expect(app.editor.value, "")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'), modifiers: KeyModifier(ctrl: true))))
        @Expect(app.editor.value, "```wf\ntask\n```")
        let restored = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(restored.area, restored)
        @Expect(restored.getCell(4, 2).style, keyword)
        let preview = Buffer(Rect(0, 0, 40, 4))
        DocumentView(app.doc).render(preview.area, preview)
        @Expect(preview.getCell(0, 0).style, keyword)
    }
    @TestCase
    func acceptingCompletionRefreshesCodeColorsInEditorAndPreview(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword cyan bold\nend")
        let app = MarkdownStudio(syntax: Some(config))
        app.editor.setValue("```wf\nta\n```", cursor: 8)
        let request = app.editor.beginCompletion("md")
        _ = app.update(Event.TextCompletion("md", TextCompletionResult(
            request.requestId, request.revision, request.prefixStart, request.prefixEnd,
            [TextCompletionItem("task")]
        )))
        @Expect(app.editor.completionVisible())
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.editor.value, "```wf\ntask\n```")
        let source = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 40, 3))
        DocumentView(app.doc).render(preview.area, preview)
        let keyword = Style(fg: Color.Cyan, modifier: Modifier.strong())
        @Expect(source.getCell(4, 2).style, keyword)
        @Expect(preview.getCell(0, 0).style, keyword)
    }
    @TestCase
    func configuredStudioRefreshesBothSurfacesAfterPasteHistoryAndLanguageSwitch(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword magenta bold\nend")
        let app = MarkdownStudio(syntax: Some(config))
        app.editor.setValue("")
        app.editor.setCarets([TextAreaCaret(0)])
        _ = app.update(Event.Paste("```wf\ntask\n```"))
        let color = Style(fg: Color.Magenta, modifier: Modifier.strong())
        let source = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 40, 3))
        DocumentView(app.doc).render(preview.area, preview)
        @Expect(source.getCell(4, 2).style, color)
        @Expect(preview.getCell(0, 0).style, color)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'z'), modifiers: KeyModifier(ctrl: true))))
        @Expect(app.editor.value, "")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'y'), modifiers: KeyModifier(ctrl: true))))
        let restored = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(restored.area, restored)
        @Expect(restored.getCell(4, 2).style, color)
        app.editor.setValue("```unknown\ntask\n```")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        let unknown = Buffer(Rect(0, 0, 40, 8))
        app.editor.render(unknown.area, unknown)
        let plain = Buffer(Rect(0, 0, 40, 3))
        DocumentView(app.doc).render(plain.area, plain)
        @Expect(unknown.getCell(4, 2).style, DocumentTheme().code)
        @Expect(plain.getCell(0, 0).style, DocumentTheme().code)
    }
}
