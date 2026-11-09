package cjtui_api_example

// 应用需要直接声明 core、markdown_adapter 和 markdown 依赖；markdown 版本应与适配器一致。
import core.*
import markdown_adapter.*
import markdown.core.{Markdown}

main(): Int64 {
    let text = "# Tasks\n\n## Build\n\nReady"
    let ast = Markdown.parse(text)
    let theme = documentThemeFromTheme(Theme())
    let doc = markdownDocument(text, theme: theme)
    let fromAst = markdownAstToDocument(ast)
    let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\nkeywords task\nend")
    let presentation = markdownAstToPresentation(ast, syntax: Some(config))
    let outline = markdownOutline(ast)
    if (doc.lines.size == 0 || fromAst.lines.size == 0 || presentation.document.lines.size == 0 ||
        outline.size != 1 || outline[0].level != 1 || outline[0].title != "Tasks" ||
        outline[0].children.size != 1 || outline[0].children[0].sourceOffset <= outline[0].sourceOffset) {
        throw IllegalStateException("markdown conversion failed")
    }
    let manual = OutlineNode(1, "Manual", -1, children: [])
    let index = markdownPreviewIndex(doc, 20)
    let manualIndex = MarkdownPreviewIndex([0, 5])
    if (manual.sourceOffset != 0 || index.renderedLineCount() == 0 ||
        index.sourceOffsetForRenderedLine(0).isNone() || manualIndex.renderedLineForSourceOffset(6) != 1) {
        throw IllegalStateException("markdown index failed")
    }
    let buffer = Buffer(Rect(0, 0, 40, 4))
    let view = ThemedMarkdownView(text, syntax: Some(config))
    view.render(buffer.area, buffer)
    view.setText("Updated")
    view.render(buffer.area, buffer)
    if (buffer.getCell(0, 0).symbol != "U" || view.handleKey(KeyEvent(KeyCode.Down), 40, 4)) {
        throw IllegalStateException("markdown view failed")
    }
    _ = view.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), buffer.area)
    _ = presentation.decorations
    return 0
}
