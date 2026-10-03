package markdown_studio

import core.*
import markdown.core.{Markdown, MarkdownProfile}
import markdown_adapter.*
import std.collection.*
import std.fs.{File, OpenMode, FSException}
import std.console.Console

class MarkdownStudio {
    let editor: TextArea
    let behavior = MarkdownEditorBehavior()
    private var vimBehavior: ?VimEditorBehavior = None
    private var vimRequestIndex: Int64 = 0
    private var renderedRevision: Int64 = -1
    private let syntax: ?SyntaxHighlightConfig
    private let clipboard: Clipboard
    private let fileSession: ?StudioFileSession
    private var savedRevision: Int64 = 0
    private var discardArmed: Bool = false
    private var discardRevision: Int64 = -1
    let toasts = ToastManager()
    var mode = "edit"
    var status = "edit"
    let previewState = DocumentViewState()
    var previewWidth: Int64 = 20
    var previewHeight: Int64 = 10
    var doc = markdownDocument("")
    var outline = ["Release Notes"]

    init(vim!: Bool = false, syntax!: ?SyntaxHighlightConfig = None,
        filePath!: ?String = None, clipboard!: Clipboard = detectClipboard(),
        writer!: StudioFileWriter = NativeStudioFileWriter()) {
        this.syntax = syntax
        this.clipboard = clipboard
        fileSession = match (filePath) { case Some(path) => Some(StudioFileSession(path, writer)); case None => None }
        let initial = match (fileSession) {
            case Some(file) => file.loadedText()
            case None => "# Release Notes\n\n- [x] Rewrite examples\n- [ ] Run release gate\n\n```cj\nmain(): Int64 { 0 }\n```\n"
        }
        let title = match (fileSession) { case Some(file) => file.path.fileName; case None => "Markdown" }
        editor = TextArea(value: initial, block: Block(title: title), lineNumbers: true, markdownEditing: true)
        if (vim) {
            vimBehavior = Some(VimEditorBehavior(editor, insertHandler: { target, key => behavior.handle(target, key) }))
        } else if (fileSession.isNone()) {
            editor.setCarets([TextAreaCaret(0), TextAreaCaret(16)])
        }
        savedRevision = editor.editRevision()
        refresh()
    }

    func saveFile(): Bool {
        match (fileSession) {
            case None => status = "no file path; open markdown_studio PATH to save"; false
            case Some(file) =>
                try {
                    file.save(editor.value)
                    savedRevision = editor.editRevision()
                    discardArmed = false
                    status = file.path.fileName + ": saved"
                    true
                } catch (error: Exception) {
                    status = "save failed: " + error.message
                    false
                }
        }
    }

    func isDirty(): Bool { fileSession.isSome() && editor.editRevision() != savedRevision }

    private func requestExit(discard!: Bool = false): UpdateResult {
        if (isDirty() && !discard) {
            status = "unsaved changes; Ctrl-S save, Ctrl-Q twice discard"
            return UpdateResult.next()
        }
        if (let Some(vim) <- vimBehavior) { vim.deactivate() }
        UpdateResult.exit()
    }

    private func clipboardAction(action: String): Unit {
        if (action != "copy" && mode != "edit") {
            status = "clipboard: enter edit mode first"
            return
        }
        if (action != "paste" && !editor.hasSelection()) {
            status = "clipboard: no selection"
            return
        }
        if (action == "cut" && editor.readOnly) { status = "clipboard: editor is read-only"; return }
        let result = if (action == "paste") { clipboard.readText() } else { clipboard.writeText(editor.selectedText()) }
        if (result.isSuccess()) {
            if (action == "paste") { editor.paste(result.text) }
            else if (action == "cut") { editor.deleteSelection() }
            refresh()
        }
        status = "clipboard " + result.backend + ": " +
            if (result.message.isEmpty()) { if (result.isSuccess()) { action + " complete" } else { action + " failed" } }
            else { result.message }
    }

    private func globalKey(key: KeyEvent, repeated: Bool): ?UpdateResult {
        let discardKey = key.modifiers.ctrl && !key.modifiers.alt &&
            match (key.code) { case KeyCode.Char(r'q') | KeyCode.Char(r'Q') => true; case _ => false }
        if (!discardKey) { discardArmed = false }
        if (key.modifiers.ctrl && !key.modifiers.alt) {
            match (key.code) {
                case KeyCode.Char(r's') | KeyCode.Char(r'S') =>
                    if (!repeated) { _ = saveFile() }
                    return Some(UpdateResult.next())
                case KeyCode.Char(r'q') | KeyCode.Char(r'Q') =>
                    if (repeated) { return Some(UpdateResult.next()) }
                    if (!isDirty() || (discardArmed && discardRevision == editor.editRevision())) {
                        return Some(requestExit(discard: true))
                    }
                    discardArmed = true
                    discardRevision = editor.editRevision()
                    status = "unsaved changes; press Ctrl-Q again to discard"
                    return Some(UpdateResult.next())
                case KeyCode.Char(r'x') | KeyCode.Char(r'X') =>
                    if (!repeated) { clipboardAction("cut") }
                    return Some(UpdateResult.next())
                case KeyCode.Char(r'v') | KeyCode.Char(r'V') =>
                    if (!repeated) { clipboardAction("paste") }
                    return Some(UpdateResult.next())
                case KeyCode.Char(r'c') | KeyCode.Char(r'C') =>
                    if (key.modifiers.shift) {
                        if (!repeated) { clipboardAction("copy") }
                        return Some(UpdateResult.next())
                    }
                case _ => ()
            }
        }
        match (key.code) {
            case KeyCode.CtrlC =>
                if (key.modifiers.shift) {
                    if (!repeated) { clipboardAction("copy") }
                    Some(UpdateResult.next())
                } else { Some(requestExit()) }
            case KeyCode.F(4) => if (!repeated) { _ = saveFile() }; Some(UpdateResult.next())
            case KeyCode.F(5) => if (!repeated) { clipboardAction("copy") }; Some(UpdateResult.next())
            case KeyCode.F(6) => if (!repeated) { clipboardAction("cut") }; Some(UpdateResult.next())
            case KeyCode.F(7) => if (!repeated) { clipboardAction("paste") }; Some(UpdateResult.next())
            case _ => discardArmed = false; None
        }
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => if (let Some(result) <- globalKey(key, false)) { return result }
            case Event.KeyRepeat(key) => if (let Some(result) <- globalKey(key, true)) { return result }
            case Event.Paste(_) => discardArmed = false
            case _ => ()
        }
        if (let Some(vim) <- vimBehavior) { return updateVim(event, vim) }
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC => return requestExit()
                    case KeyCode.Esc => mode = "normal"; status = "normal"; return UpdateResult.next()
                    case _ => ()
                }
                if (mode == "edit") {
                    _ = behavior.handle(editor, key)
                    refresh()
                    return UpdateResult.next()
                }
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return requestExit()
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
                return requestExit()
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
        discardArmed = false
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
            "i insert  Esc normal  F2 preview/editor  F3 complete"
        } else { "Esc commands: e edit  p preview  b bold  c complete  q quit" }
        let capabilities = clipboard.capabilities()
        let clipboardLabel = capabilities.backend + if (!capabilities.canRead) { " (no paste)" } else { "" }
        let fileLabel = match (fileSession) { case Some(file) => file.path.fileName + if (isDirty()) { " *" } else { "" }; case None => "demo" }
        frame.renderWidget(StatusBar(left: "F4/Ctrl-S save  F5 copy  F6 cut  F7 paste", right: fileLabel + " | " + vimStatus,
            style: Style(fg: Color.White, bg: Color.Black)), Rect(rows[2].x, rows[2].y, rows[2].width, min(1, rows[2].height)))
        if (rows[2].height > 1) {
            let message = if (status == "edit" || status == "normal" || status == "preview") { help } else { status }
            frame.renderWidget(StatusBar(left: message, right: "clipboard: " + clipboardLabel,
                style: Style(fg: Color.White, bg: Color.Black)), Rect(rows[2].x, rows[2].y + 1, rows[2].width, 1))
        }
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

func studioOptions(args: Array<String>): (Bool, ?String, ?String, Bool) {
    var vim = false
    var config: ?String = None
    var file: ?String = None
    var osc52 = false
    var pathsOnly = false
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (!pathsOnly && arg == "--") { pathsOnly = true }
        else if (!pathsOnly && arg == "--vim") { vim = true }
        else if (!pathsOnly && arg == "--osc52") { osc52 = true }
        else if (!pathsOnly && (arg == "--syntax-config" || arg.startsWith("--syntax-config="))) {
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
        } else if (!pathsOnly && arg.startsWith("-")) {
            throw IllegalArgumentException("unknown option: " + arg)
        } else {
            if (arg.isEmpty()) { throw IllegalArgumentException("empty file path") }
            if (file.isSome()) { throw IllegalArgumentException("only one document path is supported") }
            file = Some(arg)
        }
        i++
    }
    (vim, config, file, osc52)
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
    let (useVim, configPath, filePath, allowOsc52) = try { studioOptions(args) }
    catch (error: IllegalArgumentException) {
        Console.stdErr.writeln("markdown_studio: " + error.message)
        Console.stdErr.writeln("usage: markdown_studio [--vim] [--syntax-config PATH] [--osc52] [--] [FILE]")
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
    let emitter: ?(String) -> Unit = if (allowOsc52) {
        Some({ sequence: String => Console.stdOut.write(sequence); Console.stdOut.flush() })
    } else { None }
    let app = try {
        MarkdownStudio(vim: useVim, syntax: syntax, filePath: filePath, clipboard: detectClipboard(osc52Emitter: emitter))
    } catch (error: Exception) {
        Console.stdErr.writeln("markdown_studio: cannot open document: " + error.message)
        return 2
    }
    App(targetFps: 8, hideCursor: false).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
