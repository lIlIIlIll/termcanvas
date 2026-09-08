package markdown_studio

import core.*
import cj_markdown.{parseMarkdown}
import markdown.*
import std.collection.*

class MarkdownStudio {
    let editor = TextArea(
        value: "# Release Notes\n\n- [x] Rewrite examples\n- [ ] Run release gate\n\n```cj\nmain(): Int64 { 0 }\n```\n",
        block: Block(title: "Markdown"),
        lineNumbers: true,
        markdownEditing: true
    )
    let behavior = MarkdownEditorBehavior()
    let toasts = ToastManager()
    var mode = "edit"
    var status = "edit"
    let previewState = DocumentViewState()
    var previewWidth: Int64 = 20
    var previewHeight: Int64 = 10
    var doc = markdownDocument("")
    var outline = ["Release Notes"]

    init() {
        editor.setCarets([TextAreaCaret(0), TextAreaCaret(16)])
        refresh()
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC => return UpdateResult.exit()
                    case KeyCode.Esc => mode = "normal"; status = "normal"; return UpdateResult.next()
                    case _ => ()
                }
                if (mode == "edit") {
                    _ = behavior.handle(editor, key)
                    refresh()
                    return UpdateResult.next()
                }
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                    case KeyCode.Esc => mode = "normal"; status = "normal"; return UpdateResult.next()
                    case KeyCode.Char(r'e') => mode = "edit"; status = "edit"; return UpdateResult.next()
                    case KeyCode.Char(r'p') => mode = "preview"; status = "preview"; return UpdateResult.next()
                    case KeyCode.Char(r'b') =>
                        _ = behavior.toggleBold(editor)
                        refresh()
                        return UpdateResult.next()
                    case KeyCode.Char(r'c') =>
                        let request = editor.beginCompletion("md")
                        return UpdateResult.withCommand(Command.Emit(Event.TextCompletion("md", TextCompletionResult(
                            request.requestId,
                            request.revision,
                            request.prefixStart,
                            request.prefixEnd,
                            [TextCompletionItem("release"), TextCompletionItem("rollback"), TextCompletionItem("runtime")]
                        ))))
                    case _ =>
                        if (mode == "edit") {
                            _ = behavior.handle(editor, key)
                            refresh()
                        } else if (mode == "preview") {
                            let view = DocumentView(doc, state: previewState)
                            _ = view.handleKey(key, previewWidth, previewHeight)
                        }
                        return UpdateResult.next()
                }
            case Event.Paste(text) =>
                if (mode == "edit") {
                    editor.paste(text)
                    refresh()
                    status = "edit"
                }
                UpdateResult.next()
            case Event.TextCompletion(_, _) =>
                _ = editor.handleCompletionEvent(event)
                refresh()
                status = "completion"
                UpdateResult.next()
            case Event.Tick(_) =>
                toasts.tick()
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    private func refresh(): Unit {
        let ast = parseMarkdown(editor.value)
        doc = markdownAstToDocument(ast)
        let nodes = markdownOutline(ast)
        outline = outlineLines(nodes)
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(10), Constraint.Length(2)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        frame.renderWidget(MenuBar(["Edit", "Preview", "Outline"], selected: if (mode == "preview") { 1 } else { 0 }), rows[0])
        let cols = Layout.horizontal([Constraint.Percent(45), Constraint.Percent(40), Constraint.Min(14)]).withGap(1).split(rows[1])
        frame.renderWidget(editor, cols[0])
        let previewBlock = Block(title: "Preview")
        let previewArea = previewBlock.inner(cols[1])
        previewWidth = max(1, previewArea.width)
        previewHeight = max(1, previewArea.height)
        frame.renderWidget(DocumentView(doc, block: previewBlock, state: previewState), cols[1])
        frame.renderWidget(LogView(outline, block: Block(title: "Outline")), cols[2])
        frame.renderWidget(StatusBar(left: "markdown_studio  Esc commands: e edit  p preview  b bold  c complete  q quit", right: status, style: Style(fg: Color.White, bg: Color.Black)), rows[2])
        if (mode == "edit") { frame.setCursor(editor.cursorPosition(cols[0])) }
    }
}

func outlineLines(nodes: Array<OutlineNode>): Array<String> {
    if (nodes.size == 0) { return ["(no headings)"] }
    let out = ArrayList<String>()
    for (node in nodes) {
        out.add(repeatText("#", node.level) + " " + node.title)
    }
    out.toArray()
}

func repeatText(text: String, count: Int64): String {
    var out = ""
    var i: Int64 = 0
    while (i < count) { out += text; i++ }
    out
}

main(): Int64 {
    let app = MarkdownStudio()
    App(targetFps: 8, hideCursor: false).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
