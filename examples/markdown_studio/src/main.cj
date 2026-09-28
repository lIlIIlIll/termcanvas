package markdown_studio

import core.*
import markdown.core.{Markdown, MarkdownProfile}
import markdown_adapter.*
import std.collection.*
import std.fs.{File, OpenMode, FSException}
import std.console.Console

class MarkdownStudio {
    let editor = TextArea(
        value: "# Release Notes\n\n- [x] Rewrite examples\n- [ ] Run release gate\n\n```cj\nmain(): Int64 { 0 }\n```\n",
        block: Block(title: "Markdown"),
        lineNumbers: true,
        markdownEditing: true
    )
    let behavior = MarkdownEditorBehavior()
    private var vimBehavior: ?VimEditorBehavior = None
    private var vimRequestIndex: Int64 = 0
    private var renderedRevision: Int64 = -1
    private let syntax: ?SyntaxHighlightConfig
    let toasts = ToastManager()
    var mode = "edit"
    var status = "edit"
    let previewState = DocumentViewState()
    var previewWidth: Int64 = 20
    var previewHeight: Int64 = 10
    var doc = markdownDocument("")
    var outline = ["Release Notes"]

    init(vim!: Bool = false, syntax!: ?SyntaxHighlightConfig = None) {
        this.syntax = syntax
        if (vim) {
            vimBehavior = Some(VimEditorBehavior(editor, insertHandler: { target, key => behavior.handle(target, key) }))
        } else {
            editor.setCarets([TextAreaCaret(0), TextAreaCaret(16)])
        }
        refresh()
    }

    func update(event: Event): UpdateResult {
        if (let Some(vim) <- vimBehavior) { return updateVim(event, vim) }
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
                    case KeyCode.Char(r'c') => return requestCompletion("md")
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

    private func requestCompletion(requestId: String): UpdateResult {
        let request = editor.beginCompletion(requestId)
        UpdateResult.withCommand(Command.Emit(Event.TextCompletion(requestId, TextCompletionResult(
            request.requestId, request.revision, request.prefixStart, request.prefixEnd,
            [TextCompletionItem("release"), TextCompletionItem("rollback"), TextCompletionItem("runtime")]
        ))))
    }

    private func updateVim(event: Event, vim: VimEditorBehavior): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => updateVimKey(key, event, vim, false)
            case Event.KeyRepeat(key) => updateVimKey(key, event, vim, true)
            case Event.Paste(_) | Event.FocusOut | Event.TextCompletion(_, _) | Event.AsyncCompleted(_, _) =>
                if (mode == "edit") {
                    if (vim.handle(event)) { refresh() }
                }
                UpdateResult.next()
            case Event.Tick(_) =>
                toasts.tick()
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }
    private func updateVimKey(key: KeyEvent, event: Event, vim: VimEditorBehavior, repeated: Bool): UpdateResult {
        match (key.code) {
            case KeyCode.CtrlC =>
                vim.deactivate()
                return UpdateResult.exit()
            case KeyCode.F(2) =>
                if (repeated) { return UpdateResult.next() }
                if (mode == "edit") {
                    vim.deactivate()
                    mode = "preview"
                } else { mode = "edit" }
                return UpdateResult.next()
            case KeyCode.F(3) =>
                if (!repeated && mode == "edit") {
                    if (let VimMode.Insert <- vim.mode) {
                        vimRequestIndex++
                        return requestCompletion("md-vim-${vimRequestIndex}")
                    }
                }
                return UpdateResult.next()
            case _ => ()
        }
        if (mode == "preview") {
            _ = DocumentView(doc, state: previewState).handleKey(key, previewWidth, previewHeight)
        } else if (vim.handle(event)) { refresh() }
        UpdateResult.next()
    }


    private func refresh(): Unit {
        let revision = editor.editRevision()
        if (revision == renderedRevision) { return }
        let parsed = Markdown.parse(editor.value, profile: MarkdownProfile.gfm())
        let presentation = markdownAstToPresentation(parsed, syntax: syntax)
        doc = presentation.document
        editor.setDecorations(presentation.decorations)
        outline = outlineLines(markdownOutline(parsed))
        renderedRevision = revision
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
        let vimStatus = match (vimBehavior) {
            case Some(vim) =>
                if (mode == "preview") { "PREVIEW" }
                else { match (vim.mode) { case VimMode.Normal => "NORMAL"; case VimMode.Insert => "INSERT" } }
            case None => status
        }
        let help = if (let Some(_) <- vimBehavior) {
            "markdown_studio  i insert  Esc normal  F2 preview/editor  F3 complete  Ctrl-C quit"
        } else { "markdown_studio  Esc commands: e edit  p preview  b bold  c complete  q quit" }
        frame.renderWidget(StatusBar(left: help, right: vimStatus, style: Style(fg: Color.White, bg: Color.Black)), rows[2])
        if (mode == "edit") {
            frame.setCursor(editor.cursorPosition(cols[0]))
            if (let Some(vim) <- vimBehavior) {
                match (vim.mode) {
                    case VimMode.Normal => frame.setCursorShape(CursorShape.Block)
                    case VimMode.Insert => frame.setCursorShape(CursorShape.Bar)
                }
            }
        }
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

func studioOptions(args: Array<String>): (Bool, ?String) {
    var vim = false
    var config: ?String = None
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--vim") { vim = true }
        else if (arg == "--syntax-config" || arg.startsWith("--syntax-config=")) {
            if (config.isSome()) { throw IllegalArgumentException("duplicate --syntax-config") }
            var path = ""
            if (arg == "--syntax-config") {
                i++
                if (i >= args.size || args[i].startsWith("--")) {
                    throw IllegalArgumentException("missing --syntax-config path")
                }
                path = args[i]
            } else { path = arg[16..arg.size] }
            if (path.isEmpty()) { throw IllegalArgumentException("empty --syntax-config path") }
            config = Some(path)
        } else { throw IllegalArgumentException("unknown argument") }
        i++
    }
    (vim, config)
}

func studioReadBytes(path: String): Array<Byte> {
    let contents = ArrayList<Byte>()
    let file = File(path, OpenMode.Read)
    try {
        let chunk = Array<Byte>(4096, repeat: 0)
        while (true) {
            let n = file.read(chunk)
            if (n == 0) { break }
            if (contents.size + n > 256 * 1024) {
                throw IllegalArgumentException("syntax config line 1: configuration exceeds 256 KiB")
            }
            for (i in 0..n) { contents.add(chunk[i]) }
        }
    } finally { file.close() }
    contents.toArray()
}

func studioReadConfig(path: String): String {
    let bytes = studioReadBytes(path)
    try { String.fromUtf8(bytes) }
    catch (_: IllegalArgumentException) { throw IllegalArgumentException("syntax config: invalid UTF-8") }
}

main(args: Array<String>): Int64 {
    let (useVim, configPath) = try { studioOptions(args) }
    catch (error: IllegalArgumentException) {
        Console.stdErr.writeln("markdown_studio: " + error.message)
        Console.stdErr.writeln("usage: markdown_studio [--vim] [--syntax-config PATH|--syntax-config=PATH]")
        return 2
    }
    var syntax: ?SyntaxHighlightConfig = None
    if (let Some(path) <- configPath) {
        try {
            syntax = Some(parseSyntaxHighlightConfig(studioReadConfig(path)))
        } catch (_: FSException) {
            Console.stdErr.writeln("markdown_studio: cannot read syntax configuration")
            return 2
        } catch (error: IllegalArgumentException) {
            Console.stdErr.writeln("markdown_studio: " + error.message)
            return 2
        }
    }
    let app = MarkdownStudio(vim: useVim, syntax: syntax)
    App(targetFps: 8, hideCursor: false).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
