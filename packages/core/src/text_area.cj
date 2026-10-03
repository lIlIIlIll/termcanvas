package core

import std.collection.*

class TextAreaSnapshot {
    let modelRevision: Int64
    let cursor: Int64
    let scroll: Int64
    let selectionStart: ?Int64
    let selectionEnd: ?Int64
    let extraCarets: Array<TextAreaCaret>

    init(modelRevision: Int64, cursor: Int64, scroll: Int64, selectionStart: ?Int64, selectionEnd: ?Int64, extraCarets: Array<TextAreaCaret>) {
        this.modelRevision = modelRevision
        this.cursor = cursor
        this.scroll = scroll
        this.selectionStart = selectionStart
        this.selectionEnd = selectionEnd
        this.extraCarets = extraCarets
    }
}

class TextAreaEdit {
    let start: Int64
    let end: Int64
    let text: String

    init(start: Int64, end: Int64, text: String) {
        this.start = start
        this.end = max(start, end)
        this.text = text
    }
}

public class TextAreaCaret {
    public let offset: Int64
    public let anchor: ?Int64

    public init(offset: Int64, anchor!: ?Int64 = None) {
        this.offset = max(0, offset)
        this.anchor = anchor
    }
}

public class TextCompletionRequest {
    public let requestId: String
    public let revision: Int64
    public let value: String
    public let cursor: Int64
    public let prefixStart: Int64
    public let prefixEnd: Int64
    public let prefix: String
    public let line: Int64
    public let column: Int64

    public init(requestId: String, revision: Int64, value: String, cursor: Int64, prefixStart: Int64, prefixEnd: Int64, prefix: String, line: Int64, column: Int64) {
        this.requestId = requestId
        this.revision = revision
        this.value = value
        this.cursor = cursor
        this.prefixStart = prefixStart
        this.prefixEnd = prefixEnd
        this.prefix = prefix
        this.line = line
        this.column = column
    }
}

public class TextCompletionItem {
    public let label: String
    public let insertText: String
    public let detail: String

    public init(label: String, insertText!: String = "", detail!: String = "") {
        this.label = label
        this.insertText = if (insertText.isEmpty()) { label } else { insertText }
        this.detail = detail
    }
}

public class TextCompletionResult {
    public let requestId: String
    public let revision: Int64
    public let replaceStart: Int64
    public let replaceEnd: Int64
    public let items: Array<TextCompletionItem>

    public init(requestId: String, revision: Int64, replaceStart: Int64, replaceEnd: Int64, items: Array<TextCompletionItem>) {
        this.requestId = requestId
        this.revision = revision
        this.replaceStart = max(0, replaceStart)
        this.replaceEnd = max(this.replaceStart, replaceEnd)
        this.items = items
    }
}

public class TextDecoration {
    public let start: Int64
    public let end: Int64
    public let style: Style

    public init(start: Int64, end: Int64, style: Style) {
        this.start = max(0, start)
        this.end = max(this.start, end)
        this.style = style
    }
}

public type HighlightSpan = TextDecoration

public class LineHighlight {
    public let line: Int64
    public let spans: Array<TextDecoration>

    public init(line: Int64, spans: Array<TextDecoration>) {
        this.line = max(0, line)
        this.spans = spans
    }
}

public class MarkdownHighlightCache {
    private var cachedText: String = ""
    private var cachedSpans: Array<TextDecoration> = []
    private var cachedLines: Array<LineHighlight> = []
    private var recomputes: Int64 = 0

    public init() {}

    public func highlights(text: String): Array<TextDecoration> {
        if (text == cachedText) { return cachedSpans }
        cachedText = text
        cachedSpans = markdownDecorations(text)
        cachedLines = markdownLineHighlights(text)
        recomputes++
        cachedSpans
    }

    public func lineHighlights(text: String): Array<LineHighlight> {
        if (text != cachedText) { _ = highlights(text) }
        cachedLines
    }

    public func visibleHighlights(text: String, firstLine!: Int64 = 0, lineCount!: Int64 = 40): Array<TextDecoration> {
        let lines = lineHighlights(text)
        let offsets = lineStartOffsets(text)
        let out = ArrayList<TextDecoration>()
        let startLine = clamp(firstLine, 0, max(0, lines.size - 1))
        let endLine = min(lines.size, startLine + max(0, lineCount))
        for (lineIndex in startLine..endLine) {
            let lineOffset = offsets[lineIndex]
            for (span in lines[lineIndex].spans) {
                out.add(TextDecoration(lineOffset + span.start, lineOffset + span.end, span.style))
            }
        }
        out.toArray()
    }

    public func recomputeCount(): Int64 {
        recomputes
    }

    public func invalidate(): Unit {
        cachedText = ""
        cachedSpans = []
        cachedLines = []
    }
}

public class TextArea <: Widget {
    private let textModelValue: EditableTextModel
    // Explicit whole-document access remains convenient for small inputs.
    // Editing, movement and viewport rendering use the indexed model directly.
    public mut prop value: String {
        get() { textModelValue.text() }
        set(next) {
            synchronizeValue()
            pushUndoSnapshot()
            replaceModelRange(0, textModelValue.byteLength(), next)
            cursor = textModelValue.clampOffset(cursor)
            markEdited()
            clearRedo()
        }
    }
    public prop textModel: EditableTextModel { get() { textModelValue } }
    public var horizontalScroll: Int64 = 0
    private var viewportHeight: Int64 = 1
    private var viewportWidth: Int64 = 0
    private var preferredColumn: ?Int64 = None
    private var verticalColumns: Array<Int64> = []
    private var verticalOffsets: Array<Int64> = []
    public var cursor: Int64
    public var scroll: Int64
    public var selectionStart: ?Int64 = None
    public var selectionEnd: ?Int64 = None
    private let block: ?Block
    private let style: Style
    private let selectedStyle: Style
    private let placeholder: String
    private let placeholderStyle: Style
    private let lineNumbers: Bool
    private let lineNumberStyle: Style
    private let foldState: ?DocumentViewState
    public var readOnly: Bool
    public var markdownEditing: Bool
    private var decorationProviders: Array<TextDecorationProvider> = []
    private let decorationLayerNames = ArrayList<String>()
    private let decorationStores = ArrayList<TextDecorationStore>()
    private var decorations: Array<TextDecoration>
    private let undoStack = ArrayList<TextAreaSnapshot>()
    private let redoStack = ArrayList<TextAreaSnapshot>()
    private var undoGroupSnapshot: ?TextAreaSnapshot = None
    internal var vimEditorAttached: Bool = false
    private var extraCarets: Array<TextAreaCaret> = []
    private var dragAnchor: ?Int64 = None
    private var revision: Int64 = 0
    private var completionRequestId: String = ""
    private var completionRevision: Int64 = -1
    private var completionReplaceStart: Int64 = 0
    private var completionReplaceEnd: Int64 = 0
    private var completionItems: Array<TextCompletionItem> = []
    private var completionIndex: Int64 = 0
    private var completionOpen: Bool = false
    private var cachedLineRevision: Int64 = -1
    private var cachedVisibleLines: Array<Int64> = []
    private var cachedFoldRevision: Int64 = -1
    private var cachedLineRebuilds: Int64 = 0

    public init(
        value!: String = "",
        model!: ?EditableTextModel = None,
        cursor!: Int64 = 0,
        scroll!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        placeholder!: String = "",
        placeholderStyle!: Style = Style(fg: Color.Indexed(8)),
        lineNumbers!: Bool = false,
        lineNumberStyle!: Style = Style(fg: Color.Indexed(8)),
        foldState!: ?DocumentViewState = None,
        readOnly!: Bool = false,
        markdownEditing!: Bool = false,
        decorations!: Array<TextDecoration> = []
    ) {
        this.textModelValue = match (model) {
            case Some(source) => source
            case None => PieceTableTextModel(text: value)
        }
        this.revision = textModelValue.revision()
        this.cursor = textModelValue.clampOffset(cursor)
        this.scroll = max(0, scroll)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.placeholder = placeholder
        this.placeholderStyle = placeholderStyle
        this.lineNumbers = lineNumbers
        this.lineNumberStyle = lineNumberStyle
        this.foldState = foldState
        this.readOnly = readOnly
        this.markdownEditing = markdownEditing
        this.decorations = decorations
    }

    public func handle(key: KeyEvent): Bool {
        synchronizeValue()
        if (completionOpen && handleCompletionKey(key)) { return true }
        match (key.code) {
            case Char(r) =>
                if (key.modifiers.ctrl && r == r'a') {
                    verticalColumns = []
                    invalidateCompletionRequest()
                    cursor = lineStartForOffset(cursor)
                    clearSelection()
                    true
                } else if (key.modifiers.ctrl && r == r'b') {
                    verticalColumns = []
                    invalidateCompletionRequest()
                    cursor = previousOffset(cursor)
                    clearSelection()
                    true
                } else if (key.modifiers.ctrl && r == r'e') {
                    verticalColumns = []
                    invalidateCompletionRequest()
                    cursor = lineEndForOffset(cursor)
                    clearSelection()
                    true
                } else if (key.modifiers.ctrl && r == r'f') {
                    verticalColumns = []
                    invalidateCompletionRequest()
                    cursor = nextOffset(cursor)
                    clearSelection()
                    true
                } else if (key.modifiers.ctrl && r == r'k') {
                    if (readOnly) { false } else { deleteToLineEnd(); true }
                } else if (key.modifiers.ctrl && r == r'u') {
                    if (readOnly) { false } else { deleteToLineStart(); true }
                } else if (key.modifiers.ctrl && r == r'w') {
                    if (readOnly) { false } else { deletePreviousWord(); true }
                } else if (key.modifiers.ctrl && r == r'z') {
                    if (readOnly) { false } else { _ = undo(); true }
                } else if (key.modifiers.ctrl && r == r'y') {
                    if (readOnly) { false } else { _ = redo(); true }
                } else if (key.modifiers.ctrl) {
                    false
                } else if (!readOnly) {
                    replaceSelectionOrInsert(match (key.text) {
                        case Some(text) => text
                        case None => runeToString(r)
                    })
                    true
                } else {
                    false
                }
            case Enter =>
                if (readOnly) { false } else {
                    if (markdownEditing && finishEmptyMarkdownListItem()) {
                        true
                    } else {
                        replaceSelectionOrInsert(if (markdownEditing) { markdownEnterText() } else { "\n" })
                        true
                    }
                }
            case Backspace =>
                if (readOnly) { return false }
                if (extraCarets.size > 0) { applyCaretsBackspace() }
                else if (hasSelection()) { deleteSelection() } else { backspace() }
                true
            case Delete =>
                if (readOnly) { return false }
                if (extraCarets.size > 0) { applyCaretsDeleteForward() }
                else if (hasSelection()) { deleteSelection() } else { deleteForward() }
                true
            case Tab =>
                if (readOnly) { false } else { indentSelectedLines(); true }
            case BackTab =>
                if (readOnly) { false } else { outdentSelectedLines(); true }
            case Left | Right | Up | Down | PageUp | PageDown | Home | End =>
                navigateCarets(key)
                true
            case _ => false
        }
    }

    public func handleWithDirty(key: KeyEvent, area: Rect): ?DirtyRects {
        let beforeRevision = editRevision()
        let beforePosition = cursorPosition(area)
        let beforeScroll = scroll
        let beforeSelection = hasSelection() || extraCarets.size > 0
        let beforeCompletion = completionOpen
        if (!handle(key)) { return None }
        let afterPosition = cursorPosition(area)
        let dirty = DirtyRects()
        let pageMove = match (key.code) {
            case KeyCode.PageUp | KeyCode.PageDown => true
            case _ => false
        }
        if (beforeScroll != scroll || revision != beforeRevision || pageMove ||
            beforeSelection || hasSelection() || beforeCompletion || completionOpen) {
            dirty.add(area)
            return Some(dirty)
        }
        dirty.add(Rect(area.x, beforePosition.y, area.width, 1))
        dirty.add(Rect(area.x, afterPosition.y, area.width, 1))
        Some(dirty)
    }

    public func handleVimNavigation(key: KeyEvent): Bool {
        match (key.code) {
            case Char(r'h') => handle(KeyEvent(KeyCode.Left, modifiers: key.modifiers))
            case Char(r'j') => handle(KeyEvent(KeyCode.Down, modifiers: key.modifiers))
            case Char(r'k') => handle(KeyEvent(KeyCode.Up, modifiers: key.modifiers))
            case Char(r'l') => handle(KeyEvent(KeyCode.Right, modifiers: key.modifiers))
            case Char(r'w') =>
                moveWordRight()
                true
            case Char(r'b') =>
                moveWordLeft()
                true
            case Char(r'0') => handle(KeyEvent(KeyCode.Home, modifiers: key.modifiers))
            case Char(r'$') => handle(KeyEvent(KeyCode.End, modifiers: key.modifiers))
            case Char(r'G') => handle(KeyEvent(KeyCode.End, modifiers: KeyModifier(ctrl: true)))
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        synchronizeValue()
        var target = area
        if (let Some(b) <- block) { b.render(area, buffer); target = b.inner(area) }
        if (target.width <= 0 || target.height <= 0) { return }
        let gutter = min(target.width, gutterWidth())
        let textTarget = Rect(target.x + gutter, target.y, max(0, target.width - gutter), target.height)
        viewportHeight = max(1, textTarget.height)
        viewportWidth = textTarget.width
        ensureCursorVisible(textTarget.height)
        ensureHorizontalVisible(textTarget.width)
        if (textModelValue.byteLength() == 0 && !placeholder.isEmpty()) {
            buffer.writeStringClipped(textTarget.x, textTarget.y, placeholder, maxWidth: textTarget.width, style: placeholderStyle)
            renderCompletion(area, textTarget, buffer)
            return
        }
        for (row in 0..textTarget.height) {
            let visibleIndex = row + scroll
            if (visibleIndex >= visibleLineCount()) { break }
            let lineIndex = visibleLineAt(visibleIndex)
            let line = textModelValue.line(lineIndex)
            if (lineNumbers) {
                buffer.writeStringClipped(target.x, target.y + row, "${lineIndex + 1} ", maxWidth: gutter, style: lineNumberStyle)
            }
            renderLine(textTarget.x, textTarget.y + row, textTarget.width, lineIndex, line, buffer)
            if (lineHasFoldMarker(lineIndex) && textTarget.width > 0) {
                let markerX = max(textTarget.x, min(textTarget.right - 3, textTarget.x + displayWidth(line) - horizontalScroll + 1))
                buffer.writeStringClipped(markerX, textTarget.y + row, "...", maxWidth: textTarget.right - markerX, style: lineNumberStyle)
            }
        }
        renderCompletion(area, textTarget, buffer)
    }

    public func cursorPosition(area: Rect): Position {
        synchronizeValue()
        let target = textViewport(area)
        viewportHeight = max(1, target.height)
        viewportWidth = target.width
        ensureCursorVisible(target.height)
        ensureHorizontalVisible(target.width)
        let row = visibleRowForLine(lineForOffset(cursor))
        let col = columnForOffset(cursor)
        Position(target.x + clamp(col - horizontalScroll, 0, max(0, target.width - 1)),
            target.y + clamp(row - scroll, 0, max(0, target.height - 1)))
    }

    public func cursorPositions(area: Rect): Array<Position> {
        let out = ArrayList<Position>()
        out.add(cursorPosition(area))
        let target = textViewport(area)
        for (caret in extraCarets) {
            let offset = textModelValue.clampOffset(caret.offset)
            if (lineOffsetHidden(lineStartForOffset(offset))) { continue }
            let row = visibleRowForLine(lineForOffset(offset)) - scroll
            let col = columnForOffset(offset) - horizontalScroll
            if (row < 0 || row >= target.height || col < 0 || col >= target.width) { continue }
            out.add(Position(target.x + col, target.y + row))
        }
        out.toArray()
    }

    public func select(start: Int64, end: Int64): Unit {
        selectionStart = Some(textModelValue.clampOffset(start))
        selectionEnd = Some(textModelValue.clampOffset(end))
    }

    public func clearSelection(): Unit {
        selectionStart = None
        selectionEnd = None
    }

    public func hasSelection(): Bool {
        match ((selectionStart, selectionEnd)) {
            case (Some(a), Some(b)) => a != b
            case _ => false
        }
    }

    public func selectedText(): String {
        synchronizeValue()
        match (selectionBounds()) {
            case Some((start, end)) => textModelValue.slice(start, end)
            case None => ""
        }
    }

    public func selectedRange(): ?(Int64, Int64) {
        synchronizeValue()
        selectionBounds()
    }

    public func carets(): Array<TextAreaCaret> {
        let out = ArrayList<TextAreaCaret>()
        out.add(primaryCaret())
        for (caret in extraCarets) { out.add(caret) }
        out.toArray()
    }

    public func setCarets(carets: Array<TextAreaCaret>): Unit {
        verticalColumns = []
        preferredColumn = None
        if (carets.size == 0) {
            cursor = textModelValue.clampOffset(cursor)
            clearSelection()
            extraCarets = []
            return
        }
        applyPrimaryCaret(carets[0])
        let extras = ArrayList<TextAreaCaret>()
        for (i in 1..carets.size) {
            extras.add(normalizedCaret(carets[i]))
        }
        extraCarets = extras.toArray()
    }

    public func addCaret(caret: TextAreaCaret): Unit {
        verticalColumns = []
        preferredColumn = None
        let extras = ArrayList<TextAreaCaret>()
        for (item in extraCarets) { extras.add(item) }
        extras.add(normalizedCaret(caret))
        extraCarets = extras.toArray()
    }

    public func clearExtraCarets(): Unit {
        extraCarets = []
    }

    public func selectedTexts(): Array<String> {
        synchronizeValue()
        let out = ArrayList<String>()
        for (caret in carets()) {
            match (caretRange(caret)) {
                case Some((start, end)) => out.add(textModelValue.slice(start, end))
                case None => ()
            }
        }
        out.toArray()
    }

    public func copySelectionTo(clipboard: Clipboard): Bool {
        if (!hasSelection()) { return false }
        clipboard.writeText(selectedText()).isSuccess()
    }

    public func cutSelectionTo(clipboard: Clipboard): Bool {
        if (readOnly) { return false }
        if (!copySelectionTo(clipboard)) { return false }
        deleteSelection()
        true
    }

    public func pasteFrom(clipboard: Clipboard): Unit {
        let result = clipboard.readText()
        if (result.isSuccess()) { paste(result.text) }
    }

    public func deleteSelection(): Unit {
        if (readOnly) { return }
        if (!hasSelection()) { return }
        pushUndoSnapshot()
        deleteSelectionRaw()
        markEdited()
        clearRedo()
    }

    public func paste(text: String): Unit {
        if (readOnly) { return }
        synchronizeValue()
        replaceSelectionOrInsert(text)
    }

    public func setDecorations(decorations: Array<TextDecoration>): Unit {
        this.decorations = decorations
    }

    public func setDecorationProviders(providers: Array<TextDecorationProvider>): Unit {
        decorationProviders = providers
    }

    public func applyDecorationUpdate(layer: String, update: TextDecorationUpdate): Bool {
        synchronizeValue()
        if (update.revision != revision || update.end > textModelValue.byteLength()) { return false }
        for (i in 0..decorationLayerNames.size) {
            if (decorationLayerNames[i] == layer) { return decorationStores[i].apply(update) }
        }
        let store = TextDecorationStore(revision: revision)
        decorationLayerNames.add(layer)
        decorationStores.add(store)
        store.apply(update)
    }

    public func clearDecorationLayer(layer: String): Bool {
        for (i in 0..decorationLayerNames.size) {
            if (decorationLayerNames[i] == layer) {
                decorationLayerNames.remove(at: i)
                decorationStores.remove(at: i)
                return true
            }
        }
        false
    }

    private func notifyDecorationEdit(edit: TextEditDelta): Unit {
        for (store in decorationStores) { store.onEdit(edit) }
        for (provider in decorationProviders) { provider.onEdit(edit) }
    }

    private func resetDecorationStores(): Unit {
        for (store in decorationStores) { store.reset(textModelValue.revision()) }
    }

    public func setValue(value: String, cursor!: Int64 = -1): Unit {
        textModelValue.replace(0, textModelValue.byteLength(), value)
        this.cursor = if (cursor < 0) { textModelValue.byteLength() } else { textModelValue.clampOffset(cursor) }
        scroll = 0
        horizontalScroll = 0
        clearSelection()
        clearExtraCarets()
        resetDecorationStores()
        markEdited()
        clearHistory()
    }

    public func editRevision(): Int64 {
        synchronizeValue()
        revision
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        synchronizeValue()
        match (mouse.button) {
            case MouseButton.Left => ()
            case _ => return false
        }
        match (mouse.kind) {
            case MouseKind.Down =>
                match (offsetForMouse(mouse, area)) {
                    case Some(offset) =>
                        invalidateCompletionRequest()
                        if (mouse.modifiers.alt) {
                            addCaret(TextAreaCaret(offset))
                            verticalColumns = []
                            preferredColumn = None
                            return true
                        }
                        let anchor = if (mouse.modifiers.shift) {
                            match (selectionStart) { case Some(start) => start; case None => cursor }
                        } else { offset }
                        cursor = offset
                        verticalColumns = []
                        preferredColumn = None
                        if (mouse.modifiers.shift) { select(anchor, offset) } else { clearSelection() }
                        clearExtraCarets()
                        dragAnchor = Some(anchor)
                        true
                    case None => false
                }
            case MouseKind.Drag =>
                match (offsetForMouse(mouse, area)) {
                    case Some(offset) =>
                        invalidateCompletionRequest()
                        let anchor = match (dragAnchor) {
                            case Some(value) => value
                            case None => cursor
                        }
                        cursor = offset
                        select(anchor, offset)
                        true
                    case None => false
                }
            case MouseKind.Up =>
                dragAnchor = None
                true
            case _ => false
        }
    }

    public func beginCompletion(requestId: String): TextCompletionRequest {
        synchronizeValue()
        _ = cancelCompletion()
        let source = value
        let start = completionPrefixStart(source, cursor)
        let line = lineForOffset(cursor)
        let column = displayWidth(textModelValue.slice(lineStartForOffset(cursor), cursor))
        completionRequestId = requestId
        completionRevision = revision
        completionReplaceStart = start
        completionReplaceEnd = cursor
        TextCompletionRequest(requestId, revision, source, cursor, start, cursor, textModelValue.slice(start, cursor), line, column)
    }

    public func completionCommand(requestId: String, provider: (TextCompletionRequest) -> TextCompletionResult): Command {
        let request = beginCompletion(requestId)
        Command.AsyncTask(requestId, { => Event.TextCompletion(requestId, provider(request)) })
    }

    public func handleCompletionEvent(event: Event): Bool {
        match (event) {
            case Event.TextCompletion(_, result) => applyCompletionResult(result)
            case Event.AsyncCompleted(_, inner) =>
                match (inner) {
                    case Event.TextCompletion(_, result) => applyCompletionResult(result)
                    case _ => false
                }
            case _ => false
        }
    }

    public func completionVisible(): Bool {
        synchronizeValue()
        completionOpen
    }

    public func cancelCompletion(): Bool {
        let wasOpen = completionOpen
        completionOpen = false
        completionItems = []
        completionIndex = 0
        completionRequestId = ""
        completionRevision = -1
        wasOpen
    }

    internal func invalidateCompletionRequest(): Unit {
        _ = cancelCompletion()
    }

    public func completionRows(maximum!: Int64 = 5): Int64 {
        synchronizeValue()
        if (!completionOpen) { return 0 }
        min(max(0, maximum), completionItems.size)
    }

    public func renderCompletionOverlay(area: Rect, buffer: Buffer): Unit {
        synchronizeValue()
        var target = area
        if (let Some(b) <- block) { target = b.inner(area) }
        let gutter = if (lineNumbers) { min(6, max(3, decimalDigits(lineCount()) + 1)) } else { 0 }
        let textTarget = Rect(target.x + gutter, target.y, max(0, target.width - gutter), target.height)
        renderCompletion(area, textTarget, buffer)
    }

    public func clearHistory(): Unit {
        undoGroupSnapshot = None
        textModelValue.clearHistory()
        while (undoStack.size > 0) { undoStack.remove(at: 0) }
        clearRedo()
    }

    internal func beginUndoGroup(): Unit {
        synchronizeValue()
        if (let None <- undoGroupSnapshot) {
            undoGroupSnapshot = Some(snapshot())
            textModelValue.beginUndoGroup()
        }
    }

    internal func endUndoGroup(): Unit {
        synchronizeValue()
        let initial = undoGroupSnapshot
        undoGroupSnapshot = None
        if (let Some(item) <- initial) {
            textModelValue.endUndoGroup()
            if (textModelValue.revision() != item.modelRevision) {
                undoStack.add(item)
                clearRedo()
            }
        }
    }

    public func undo(): Bool {
        endUndoGroup()
        synchronizeValue()
        let before = snapshot()
        if (!textModelValue.undo()) { return false }
        redoStack.add(before)
        let previous = if (undoStack.size > 0) { undoStack.remove(at: undoStack.size - 1) } else { before }
        restoreSnapshot(previous)
        true
    }

    public func redo(): Bool {
        endUndoGroup()
        synchronizeValue()
        let before = snapshot()
        if (!textModelValue.redo()) { return false }
        undoStack.add(before)
        let next = if (redoStack.size > 0) { redoStack.remove(at: redoStack.size - 1) } else { before }
        restoreSnapshot(next)
        true
    }

    private func deleteSelectionRaw(): Unit {
        match (selectionBounds()) {
            case Some((start, end)) =>
                replaceModelRange(start, end, "")
                cursor = start
                clearSelection()
            case None => ()
        }
    }

    public func findNext(needle: String): ?Int64 {
        synchronizeValue()
        let idx = stringIndexOf(value, needle, cursor)
        if (idx >= 0) {
            cursor = idx
            select(idx, idx + needle.size)
            return Some(idx)
        }
        None
    }

    public func findPrevious(needle: String): ?Int64 {
        synchronizeValue()
        let idx = stringLastIndexOf(value, needle, cursor)
        if (idx >= 0) {
            cursor = idx
            select(idx, idx + needle.size)
            return Some(idx)
        }
        None
    }

    public func moveWordLeft(): Unit {
        cursor = wordOffset(cursor, false)
        clearSelection()
    }

    public func moveWordRight(): Unit {
        cursor = wordOffset(cursor, true)
        clearSelection()
    }

    private func insert(text: String): Unit {
        replaceModelRange(cursor, cursor, text)
        cursor += text.size
    }

    private func replaceSelectionOrInsert(text: String): Unit {
        if (extraCarets.size > 0) { applyCaretsEdit(text); return }
        let bounds = match (selectionBounds()) { case Some(range) => range; case None => (cursor, cursor) }
        if (bounds[0] == bounds[1] && text.isEmpty()) { return }
        if (bounds[1] - bounds[0] == text.size && textModelValue.slice(bounds[0], bounds[1]) == text) {
            cursor = bounds[0] + text.size
            clearSelection()
            return
        }
        pushUndoSnapshot()
        replaceModelRange(bounds[0], bounds[1], text)
        cursor = bounds[0] + text.size
        clearSelection()
        markEdited()
        clearRedo()
    }

    private func backspace(): Unit {
        if (extraCarets.size > 0) {
            applyCaretsBackspace()
            return
        }
        if (cursor <= 0) { return }
        pushUndoSnapshot()
        let prev = previousOffset(cursor)
        replaceModelRange(prev, cursor, "")
        cursor = prev
        markEdited()
        clearRedo()
    }

    private func deleteForward(): Unit {
        if (extraCarets.size > 0) {
            applyCaretsDeleteForward()
            return
        }
        if (cursor >= textModelValue.byteLength()) { return }
        pushUndoSnapshot()
        let next = nextOffset(cursor)
        replaceModelRange(cursor, next, "")
        markEdited()
        clearRedo()
    }

    private func deleteToLineStart(): Unit {
        if (hasSelection()) {
            deleteSelection()
            return
        }
        deleteRange(lineStartForOffset(cursor), cursor)
    }

    private func deleteToLineEnd(): Unit {
        if (hasSelection()) {
            deleteSelection()
            return
        }
        deleteRange(cursor, lineEndForOffset(cursor))
    }

    private func deletePreviousWord(): Unit {
        if (hasSelection()) {
            deleteSelection()
            return
        }
        deleteRange(wordOffset(cursor, false), cursor)
    }

    private func deleteRange(start: Int64, end: Int64): Unit {
        let from = textModelValue.clampOffset(min(start, end))
        let to = textModelValue.clampOffset(max(start, end))
        if (from == to) { return }
        pushUndoSnapshot()
        replaceModelRange(from, to, "")
        cursor = from
        clearSelection()
        clearExtraCarets()
        markEdited()
        clearRedo()
    }

    private func snapshot(): TextAreaSnapshot {
        TextAreaSnapshot(textModelValue.revision(), cursor, scroll, selectionStart, selectionEnd, extraCarets)
    }

    private func pushUndoSnapshot(): Unit {
        synchronizeValue()
        if (let None <- undoGroupSnapshot) { undoStack.add(snapshot()) }
    }

    private func restoreSnapshot(item: TextAreaSnapshot): Unit {
        resetDecorationStores()
        cursor = textModelValue.clampOffset(item.cursor)
        scroll = max(0, item.scroll)
        selectionStart = item.selectionStart
        selectionEnd = item.selectionEnd
        extraCarets = item.extraCarets
        markEdited()
    }

    private func clearRedo(): Unit {
        if (let Some(_) <- undoGroupSnapshot) { return }
        while (redoStack.size > 0) { redoStack.remove(at: 0) }
    }

    private func moveVertical(delta: Int64): Unit {
        let col = match (preferredColumn) { case Some(value) => value; case None => columnForOffset(cursor) }
        preferredColumn = Some(col)
        cursor = verticalOffset(cursor, delta, col)
    }

    private func columnForOffset(offset: Int64): Int64 {
        displayWidth(textModelValue.slice(lineStartForOffset(offset), offset))
    }

    internal func previousOffset(offset: Int64): Int64 {
        let pos = textModelValue.clampOffset(offset)
        if (pos <= 0) { return 0 }
        if (pos >= 2 && textModelValue.slice(pos - 2, pos) == "\r\n") { return pos - 2 }
        let index = lineForOffset(pos)
        let start = textModelValue.lineStart(index)
        if (pos == start) { return pos - 1 }
        start + previousGraphemeOffset(textModelValue.line(index), pos - start)
    }

    internal func nextOffset(offset: Int64): Int64 {
        let pos = textModelValue.clampOffset(offset)
        if (pos >= textModelValue.byteLength()) { return textModelValue.byteLength() }
        if (textModelValue.slice(pos, min(pos + 2, textModelValue.byteLength())) == "\r\n") { return pos + 2 }
        let index = lineForOffset(pos)
        let start = textModelValue.lineStart(index)
        let line = textModelValue.line(index)
        if (pos - start >= line.size) { return min(textModelValue.byteLength(), pos + 1) }
        start + nextGraphemeOffset(line, pos - start)
    }

    private func wordOffset(offset: Int64, right: Bool): Int64 {
        indexedWordOffset(textModelValue, offset, right)
    }

    private func verticalOffset(offset: Int64, delta: Int64, column: Int64): Int64 {
        let row = visibleRowForLine(lineForOffset(offset))
        let next = clamp(row + delta, 0, max(0, visibleLineCount() - 1))
        offsetAtCachedLineColumn(visibleLineAt(next), column)
    }

    private func navigateCarets(key: KeyEvent): Unit {
        let original = carets()
        let isVertical = match (key.code) {
            case KeyCode.Up | KeyCode.Down | KeyCode.PageUp | KeyCode.PageDown => true
            case _ => false
        }
        var continuesVertical = verticalColumns.size == original.size && verticalOffsets.size == original.size
        if (continuesVertical) {
            for (i in 0..original.size) {
                if (original[i].offset != verticalOffsets[i]) { continuesVertical = false; break }
            }
        }
        if (isVertical && !continuesVertical) {
            let columns = ArrayList<Int64>()
            for (caret in original) { columns.add(columnForOffset(caret.offset)) }
            verticalColumns = columns.toArray()
        } else if (!isVertical) { verticalColumns = []; preferredColumn = None }
        let next = ArrayList<TextAreaCaret>()
        for (i in 0..original.size) {
            let caret = normalizedCaret(original[i])
            var target = caret.offset
            let range = caretRange(caret)
            match (key.code) {
                case KeyCode.Left =>
                    if (!key.modifiers.shift && !key.modifiers.ctrl && range.isSome()) {
                        if (let Some((start, _)) <- range) { target = start }
                    } else { target = if (key.modifiers.ctrl) { wordOffset(target, false) } else { previousOffset(target) } }
                case KeyCode.Right =>
                    if (!key.modifiers.shift && !key.modifiers.ctrl && range.isSome()) {
                        if (let Some((_, end)) <- range) { target = end }
                    } else { target = if (key.modifiers.ctrl) { wordOffset(target, true) } else { nextOffset(target) } }
                case KeyCode.Up => target = verticalOffset(target, -1, verticalColumns[i])
                case KeyCode.Down => target = verticalOffset(target, 1, verticalColumns[i])
                case KeyCode.PageUp => target = verticalOffset(target, -viewportHeight, verticalColumns[i])
                case KeyCode.PageDown => target = verticalOffset(target, viewportHeight, verticalColumns[i])
                case KeyCode.Home => target = if (key.modifiers.ctrl) { 0 } else { lineStartForOffset(target) }
                case KeyCode.End => target = if (key.modifiers.ctrl) { textModelValue.byteLength() } else { lineEndForOffset(target) }
                case _ => ()
            }
            let anchor: ?Int64 = if (key.modifiers.shift) {
                match (caret.anchor) { case Some(value) => Some(value); case None => Some(caret.offset) }
            } else { None }
            next.add(TextAreaCaret(target, anchor: anchor))
        }
        let retainedColumns = verticalColumns
        setCarets(next.toArray())
        if (isVertical) {
            verticalColumns = retainedColumns
            let offsets = ArrayList<Int64>()
            for (caret in next) { offsets.add(caret.offset) }
            verticalOffsets = offsets.toArray()
        } else { verticalOffsets = [] }
        invalidateCompletionRequest()
    }

    private func gutterWidth(): Int64 {
        if (lineNumbers) { min(6, max(3, decimalDigits(lineCount()) + 1)) } else { 0 }
    }

    private func textViewport(area: Rect): Rect {
        let target = match (block) { case Some(value) => value.inner(area); case None => area }
        let gutter = min(target.width, gutterWidth())
        Rect(target.x + gutter, target.y, max(0, target.width - gutter), target.height)
    }

    private func ensureHorizontalVisible(width: Int64): Unit {
        horizontalScroll = max(0, horizontalScroll)
        if (width <= 0) { return }
        let column = columnForOffset(cursor)
        if (column < horizontalScroll) { horizontalScroll = column }
        else if (column >= horizontalScroll + width) { horizontalScroll = column - width + 1 }
    }

    private func ensureCursorVisible(height: Int64): Unit {
        let line = visibleRowForLine(lineForOffset(cursor))
        if (line < scroll) {
            scroll = line
        } else if (height > 0 && line >= scroll + height) {
            scroll = line - height + 1
        }
    }

    private func selectionBounds(): ?(Int64, Int64) {
        match ((selectionStart, selectionEnd)) {
            case (Some(a), Some(b)) =>
                if (a == b) { None } else if (a < b) { Some((a, b)) } else { Some((b, a)) }
            case _ => None
        }
    }

    private func primaryCaret(): TextAreaCaret {
        match ((selectionStart, selectionEnd)) {
            case (Some(anchor), Some(end)) =>
                if (anchor == end) { TextAreaCaret(cursor) } else { TextAreaCaret(end, anchor: Some(anchor)) }
            case _ => TextAreaCaret(cursor)
        }
    }

    private func normalizedCaret(caret: TextAreaCaret): TextAreaCaret {
        TextAreaCaret(textModelValue.clampOffset(caret.offset), anchor: match (caret.anchor) {
            case Some(anchor) => Some(textModelValue.clampOffset(anchor))
            case None => None
        })
    }

    private func applyPrimaryCaret(caret: TextAreaCaret): Unit {
        let normalized = normalizedCaret(caret)
        cursor = normalized.offset
        match (normalized.anchor) {
            case Some(anchor) => select(anchor, normalized.offset)
            case None => clearSelection()
        }
    }

    private func caretRange(caret: TextAreaCaret): ?(Int64, Int64) {
        let normalized = normalizedCaret(caret)
        match (normalized.anchor) {
            case Some(anchor) =>
                if (anchor == normalized.offset) {
                    None
                } else if (anchor < normalized.offset) {
                    Some((anchor, normalized.offset))
                } else {
                    Some((normalized.offset, anchor))
                }
            case None => None
        }
    }

    private func markEdited(): Unit {
        if (undoGroupSnapshot.isNone() && undoStack.size > 0 &&
            undoStack[undoStack.size - 1].modelRevision == textModelValue.revision()) {
            undoStack.remove(at: undoStack.size - 1)
        }
        revision = textModelValue.revision()
        preferredColumn = None
        verticalColumns = []
        invalidateLineCache()
        invalidateCompletionRequest()
    }

    private func synchronizeValue(): Unit {
        cursor = textModelValue.clampOffset(cursor)
        selectionStart = match (selectionStart) {
            case Some(offset) => Some(textModelValue.clampOffset(offset))
            case None => None
        }
        selectionEnd = match (selectionEnd) {
            case Some(offset) => Some(textModelValue.clampOffset(offset))
            case None => None
        }
        if (revision == textModelValue.revision()) { return }
        undoStack.clear()
        redoStack.clear()
        undoGroupSnapshot = None
        resetDecorationStores()
        markEdited()
    }

    private func replaceModelRange(start: Int64, end: Int64, text: String): Unit {
        let before = textModelValue.revision()
        textModelValue.replace(start, end, text)
        if (textModelValue.revision() != before) {
            notifyDecorationEdit(TextEditDelta(start, end, text.size, before, textModelValue.revision()))
        }
    }

    private func applyCaretsEdit(text: String): Unit {
        let edits = ArrayList<TextAreaEdit>()
        let nextCarets = ArrayList<TextAreaCaret>()
        for (caret in carets()) {
            match (caretRange(caret)) {
                case Some((start, end)) =>
                    edits.add(TextAreaEdit(start, end, text))
                    nextCarets.add(TextAreaCaret(start))
                case None =>
                    let offset = textModelValue.clampOffset(caret.offset)
                    edits.add(TextAreaEdit(offset, offset, text))
                    nextCarets.add(TextAreaCaret(offset))
            }
        }
        applyEdits(edits.toArray(), nextCarets.toArray())
    }

    private func applyCaretsBackspace(): Unit {
        let edits = ArrayList<TextAreaEdit>()
        let nextCarets = ArrayList<TextAreaCaret>()
        for (caret in carets()) {
            match (caretRange(caret)) {
                case Some((start, end)) =>
                    edits.add(TextAreaEdit(start, end, ""))
                    nextCarets.add(TextAreaCaret(start))
                case None =>
                    let offset = textModelValue.clampOffset(caret.offset)
                    if (offset > 0) {
                        let prev = previousOffset(offset)
                        edits.add(TextAreaEdit(prev, offset, ""))
                        nextCarets.add(TextAreaCaret(prev))
                    } else {
                        nextCarets.add(TextAreaCaret(offset))
                    }
            }
        }
        applyEdits(edits.toArray(), nextCarets.toArray())
    }

    private func applyCaretsDeleteForward(): Unit {
        let edits = ArrayList<TextAreaEdit>()
        let nextCarets = ArrayList<TextAreaCaret>()
        for (caret in carets()) {
            match (caretRange(caret)) {
                case Some((start, end)) =>
                    edits.add(TextAreaEdit(start, end, ""))
                    nextCarets.add(TextAreaCaret(start))
                case None =>
                    let offset = textModelValue.clampOffset(caret.offset)
                    if (offset < textModelValue.byteLength()) {
                        let next = nextOffset(offset)
                        edits.add(TextAreaEdit(offset, next, ""))
                    }
                    nextCarets.add(TextAreaCaret(offset))
            }
        }
        applyEdits(edits.toArray(), nextCarets.toArray())
    }

    private func applyEdits(items: Array<TextAreaEdit>, nextCarets: Array<TextAreaCaret>): Unit {
        if (items.size == 0) { return }
        pushUndoSnapshot()
        let applied = normalizeEditsDescending(items)
        textModelValue.beginUndoGroup()
        for (edit in applied) { replaceModelRange(edit.start, edit.end, edit.text) }
        textModelValue.endUndoGroup()
        setCarets(transformCaretsAfterEdits(nextCarets, applied))
        coalesceEditedCarets()
        markEdited()
        clearRedo()
    }

    private func transformCaretsAfterEdits(carets: Array<TextAreaCaret>, edits: Array<TextAreaEdit>): Array<TextAreaCaret> {
        let out = ArrayList<TextAreaCaret>()
        for (caret in carets) {
            out.add(TextAreaCaret(transformOffsetAfterEdits(caret.offset, edits), anchor: match (caret.anchor) {
                case Some(anchor) => Some(transformOffsetAfterEdits(anchor, edits))
                case None => None
            }))
        }
        out.toArray()
    }

    private func coalesceEditedCarets(): Unit {
        let out = ArrayList<TextAreaCaret>()
        out.add(primaryCaret())
        // setCarets has already clamped offsets to the new text. Keep the
        // first (primary) caret when edits join multiple caret positions.
        // The undo snapshot retains the original selection state.
        for (caret in extraCarets) {
            var duplicate = false
            for (existing in out) {
                if (existing.offset == caret.offset && existing.anchor == caret.anchor) {
                    duplicate = true
                    break
                }
            }
            if (!duplicate) { out.add(caret) }
        }
        out.remove(at: 0)
        extraCarets = out.toArray()
    }

    private func transformOffsetAfterEdits(offset: Int64, edits: Array<TextAreaEdit>): Int64 {
        var next = offset
        for (edit in edits) {
            if (offset >= edit.end) {
                next += edit.text.size - (edit.end - edit.start)
            } else if (offset >= edit.start) {
                next += edit.start + edit.text.size - offset
            }
        }
        max(0, next)
    }

    private func normalizeEditsDescending(items: Array<TextAreaEdit>): Array<TextAreaEdit> {
        let out = ArrayList<TextAreaEdit>()
        // Each batch uses the same replacement text. Overlapping selections
        // therefore replace their union once; adjacent nonempty replacements
        // retain separate insertion ends. Same-point inserts happen once.
        for (item in sortEditsDescending(items)) {
            var merged = item
            while (out.size > 0) {
                let right = out[out.size - 1]
                let shared = merged.end > right.start || merged.start == right.start
                let adjacentDeletes = merged.text.isEmpty() && right.text.isEmpty() && merged.end == right.start
                if (!shared && !adjacentDeletes) { break }
                merged = TextAreaEdit(merged.start, max(merged.end, right.end), merged.text)
                out.remove(at: out.size - 1)
            }
            out.add(merged)
        }
        out.toArray()
    }

    private func sortEditsDescending(items: Array<TextAreaEdit>): Array<TextAreaEdit> {
        let out = ArrayList<TextAreaEdit>()
        for (item in items) {
            var inserted = false
            for (i in 0..out.size) {
                if (item.start > out[i].start) {
                    out.add(item, at: i)
                    inserted = true
                    break
                }
            }
            if (!inserted) { out.add(item) }
        }
        out.toArray()
    }

    private func mergeRangesAscending(items: Array<TextAreaEdit>): Array<TextAreaEdit> {
        let sorted = ArrayList<TextAreaEdit>()
        for (item in items) {
            var inserted = false
            for (i in 0..sorted.size) {
                if (item.start < sorted[i].start) {
                    sorted.add(item, at: i)
                    inserted = true
                    break
                }
            }
            if (!inserted) { sorted.add(item) }
        }
        let merged = ArrayList<TextAreaEdit>()
        for (item in sorted) {
            if (merged.size == 0) {
                merged.add(item)
            } else {
                let last = merged[merged.size - 1]
                if (item.start <= last.end) {
                    merged.remove(at: merged.size - 1)
                    merged.add(TextAreaEdit(last.start, max(last.end, item.end), ""))
                } else {
                    merged.add(item)
                }
            }
        }
        merged.toArray()
    }

    private func invalidateLineCache(): Unit {
        cachedLineRevision = -1
        cachedVisibleLines = []
    }

    private func ensureLineCache(): Unit {
        if (cachedLineRevision == revision) { return }
        cachedLineRebuilds++
        cachedLineRevision = revision
        cachedVisibleLines = []
    }

    private func lineCount(): Int64 { ensureLineCache(); textModelValue.lineCount() }
    private func lineForOffset(offset: Int64): Int64 { ensureLineCache(); textModelValue.lineForOffset(offset) }
    internal func lineStartForOffset(offset: Int64): Int64 { textModelValue.lineStart(lineForOffset(offset)) }
    internal func lineEndForOffset(offset: Int64): Int64 {
        let line = lineForOffset(offset)
        if (line + 1 < textModelValue.lineCount()) { textModelValue.lineStart(line + 1) - 1 }
        else { textModelValue.byteLength() }
    }
    private func offsetAtCachedLineColumn(line: Int64, column: Int64): Int64 {
        let index = clamp(line, 0, max(0, textModelValue.lineCount() - 1))
        textModelValue.lineStart(index) + offsetAtLineColumn(textModelValue.line(index), 0, column)
    }
    public func lineCacheRebuildCount(): Int64 { cachedLineRebuilds }

    private func hasFolds(): Bool {
        match (foldState) { case Some(state) => state.folds().size > 0; case None => false }
    }
    private func visibleLineCount(): Int64 {
        if (hasFolds()) { visibleLineIndexes().size } else { lineCount() }
    }
    private func visibleLineAt(index: Int64): Int64 {
        if (hasFolds()) { visibleLineIndexes()[index] } else { index }
    }
    private func visibleLineIndexes(): Array<Int64> {
        ensureLineCache()
        let foldRevision = match (foldState) { case Some(state) => state.foldRevision(); case None => 0 }
        if (cachedFoldRevision != foldRevision) { cachedFoldRevision = foldRevision; cachedVisibleLines = [] }
        if (cachedVisibleLines.size > 0) { return cachedVisibleLines }
        let out = ArrayList<Int64>()
        for (i in 0..textModelValue.lineCount()) {
            if (!lineOffsetHidden(textModelValue.lineStart(i))) { out.add(i) }
        }
        if (out.size == 0) { out.add(0) }
        cachedVisibleLines = out.toArray()
        cachedVisibleLines
    }

    private func lineOffsetHidden(offset: Int64): Bool {
        match (foldState) {
            case Some(state) =>
                for (range in state.folds()) {
                    if (range.startOffset < offset && offset <= range.endOffset) { return true }
                }
                false
            case None => false
        }
    }

    private func lineHasFoldMarker(lineIndex: Int64): Bool {
        if (lineIndex < 0 || lineIndex >= textModelValue.lineCount()) { return false }
        let offset = textModelValue.lineStart(lineIndex)
        match (foldState) {
            case Some(state) =>
                for (range in state.folds()) {
                    if (range.startOffset <= offset && offset <= range.endOffset) { return true }
                }
                false
            case None => false
        }
    }

    private func visibleRowForLine(line: Int64): Int64 {
        if (!hasFolds()) { return clamp(line, 0, max(0, lineCount() - 1)) }
        let visible = visibleLineIndexes()
        var low: Int64 = 0
        var high = visible.size
        while (low < high) {
            let middle = low + (high - low) / 2
            if (visible[middle] <= line) { low = middle + 1 } else { high = middle }
        }
        max(0, low - 1)
    }

    private func offsetForMouse(mouse: MouseEvent, area: Rect): ?Int64 {
        let outer = match (block) { case Some(value) => value.inner(area); case None => area }
        let target = textViewport(area)
        if (target.width <= 0 || target.height <= 0) { return None }
        if (mouse.x < outer.x || mouse.x >= outer.right || mouse.y < target.y || mouse.y >= target.bottom) { return None }
        let index = scroll + mouse.y - target.y
        if (index < 0 || index >= visibleLineCount()) { return None }
        let line = visibleLineAt(index)
        let column = if (mouse.x < target.x) { 0 } else { horizontalScroll + mouse.x - target.x }
        Some(offsetAtCachedLineColumn(line, column))
    }

    private func applyCompletionResult(result: TextCompletionResult): Bool {
        synchronizeValue()
        if (completionRevision < 0 || result.requestId != completionRequestId ||
            result.revision != completionRevision || result.revision != revision) { return false }
        completionItems = result.items
        completionReplaceStart = textModelValue.clampOffset(result.replaceStart)
        completionReplaceEnd = textModelValue.clampOffset(result.replaceEnd)
        completionIndex = 0
        completionOpen = result.items.size > 0
        completionOpen
    }

    private func handleCompletionKey(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.Up =>
                completionIndex = max(0, completionIndex - 1)
                true
            case KeyCode.Down =>
                completionIndex = min(max(0, completionItems.size - 1), completionIndex + 1)
                true
            case KeyCode.Esc =>
                _ = cancelCompletion()
                true
            case KeyCode.Enter =>
                if (readOnly) { false } else { acceptCompletion(); true }
            case KeyCode.Tab =>
                if (readOnly) { false } else { acceptCompletion(); true }
            case _ => false
        }
    }

    private func acceptCompletion(): Unit {
        if (readOnly || !completionOpen || completionItems.size == 0) { return }
        let item = completionItems[completionIndex]
        pushUndoSnapshot()
        let start = clamp(completionReplaceStart, 0, textModelValue.byteLength())
        let end = clamp(completionReplaceEnd, start, textModelValue.byteLength())
        replaceModelRange(start, end, item.insertText)
        cursor = start + item.insertText.size
        clearSelection()
        clearExtraCarets()
        markEdited()
        clearRedo()
    }

    private func renderCompletion(outer: Rect, area: Rect, buffer: Buffer): Unit {
        if (!completionOpen || completionItems.size == 0 || area.width <= 0 || area.height <= 0) { return }
        let pos = cursorPosition(outer)
        let startY = min(area.y + area.height - 1, pos.y + 1)
        let maxRows = min(5, area.y + area.height - startY)
        let visibleRows = min(maxRows, completionItems.size)
        var itemStart = max(0, completionIndex - visibleRows / 2)
        if (itemStart + visibleRows > completionItems.size) {
            itemStart = max(0, completionItems.size - visibleRows)
        }
        for (row in 0..visibleRows) {
            let itemIndex = itemStart + row
            let item = completionItems[itemIndex]
            let prefix = if (itemIndex == completionIndex) { "> " } else { "  " }
            let text = if (item.detail.isEmpty()) { prefix + item.label } else { prefix + item.label + " " + item.detail }
            let popupStyle = if (itemIndex == completionIndex) { selectedStyle } else { Style(fg: Color.Cyan) }
            buffer.setString(pos.x, startY + row, truncate(text, max(0, area.x + area.width - pos.x)), style: popupStyle)
        }
    }

    private func renderLine(x: Int64, y: Int64, width: Int64, lineIndex: Int64, line: String, buffer: Buffer): Unit {
        if (width <= 0) { return }
        let start = textModelValue.lineStart(lineIndex)
        let styled = lineDecorations(line, start)
        let ranges = selectionRangesForLine(start, line.size)
        buffer.withCanvasClip(Rect(x, y, width, 1)) { =>
            var column: Int64 = 0
            var offset: Int64 = 0
            buffer.fill(Rect(x, y, width, 1), style: style)
            for (span in styled) {
                for (cluster in graphemeClusters(span.text)) {
                    if (column >= horizontalScroll + width) { break }
                    if (column >= horizontalScroll && column + cluster.width <= horizontalScroll + width) {
                        var cellStyle = span.style
                        let from = offset + cluster.startOffset
                        let to = offset + cluster.endOffset
                        for (range in ranges) {
                            if (range.start < to && range.end > from) { cellStyle = cellStyle.patch(selectedStyle); break }
                        }
                        buffer.writeStringClipped(x + column - horizontalScroll, y, cluster.text,
                            maxWidth: horizontalScroll + width - column, style: cellStyle)
                    }
                    column += cluster.width
                }
                offset += span.text.size
            }
        }
    }

    private func selectionRangesForLine(lineStartOffset: Int64, lineSize: Int64): Array<TextAreaEdit> {
        let ranges = ArrayList<TextAreaEdit>()
        for (caret in carets()) {
            match (caretRange(caret)) {
                case Some((selStart, selEnd)) =>
                    let start = clamp(selStart - lineStartOffset, 0, lineSize)
                    let end = clamp(selEnd - lineStartOffset, 0, lineSize)
                    if (end > 0 && start < lineSize && start < end) {
                        ranges.add(TextAreaEdit(start, end, ""))
                    }
                case None => ()
            }
        }
        mergeRangesAscending(ranges.toArray())
    }

    private func lineDecorations(line: String, lineStartOffset: Int64): Array<RichSpan> {
        if (line.isEmpty()) { return [RichSpan("", style: style)] }
        let allMarkers = ArrayList<TextDecoration>()
        if (markdownEditing && decorations.size == 0) { allMarkers.add(all: markdownLineDecorations(line, lineStartOffset)) }
        allMarkers.add(all: decorationsForLine(lineStartOffset, line.size))
        let markers = allMarkers.toArray()
        let spans = ArrayList<RichSpan>()
        var runStart: Int64 = 0
        var currentStyle = style
        var hasCurrent = false
        // A decoration that intersects a grapheme styles that whole grapheme;
        // splitting at rune boundaries can break combining and ZWJ sequences.
        for (cluster in graphemeClusters(line)) {
            let offset = cluster.startOffset
            var nextStyle = style
            let absStart = lineStartOffset + offset
            let absEnd = lineStartOffset + cluster.endOffset
            for (decoration in markers) {
                if (decoration.end > absStart && decoration.start < absEnd) {
                    nextStyle = nextStyle.patch(decoration.style)
                }
            }
            if (!hasCurrent) {
                runStart = offset
                currentStyle = nextStyle
                hasCurrent = true
            } else if (nextStyle != currentStyle) {
                spans.add(RichSpan(line[runStart..offset], style: currentStyle))
                runStart = offset
                currentStyle = nextStyle
            }
        }
        if (hasCurrent) { spans.add(RichSpan(line[runStart..line.size], style: currentStyle)) }
        spans.toArray()
    }

    private func decorationsForLine(lineStartOffset: Int64, lineSize: Int64): Array<TextDecoration> {
        let out = ArrayList<TextDecoration>()
        let lineEnd = lineStartOffset + lineSize
        for (decoration in decorations) {
            if (decoration.end > lineStartOffset && decoration.start < lineEnd) { out.add(decoration) }
        }
        for (provider in decorationProviders) {
            if (provider.revision() == revision) { out.add(all: provider.query(lineStartOffset, lineEnd)) }
        }
        for (store in decorationStores) {
            if (store.revision() == revision) { out.add(all: store.query(lineStartOffset, lineEnd)) }
        }
        out.toArray()
    }

    private func markdownLineDecorations(line: String, lineStartOffset: Int64): Array<TextDecoration> {
        markdownDecorationsForLine(line, lineStartOffset)
    }

    private func markdownEnterText(): String {
        let start = lineStartForOffset(cursor)
        let end = lineEndForOffset(cursor)
        let line = textModelValue.slice(start, end)
        let indent = line[..leadingSpacesLocal(line)]
        let markerEnd = markdownListMarkerEnd(line)
        if (markerEnd > 0) {
            let marker = continuationMarker(line)
            if (trimAsciiSpacesLocal(line[markerEnd..]).isEmpty()) {
                return "\n" + indent
            }
            return "\n" + indent + marker
        }
        if (trimAsciiSpacesLocal(line).startsWith(">")) {
            return "\n" + indent + "> "
        }
        "\n" + indent
    }

    private func finishEmptyMarkdownListItem(): Bool {
        let start = lineStartForOffset(cursor)
        let end = lineEndForOffset(cursor)
        let line = textModelValue.slice(start, end)
        let markerEnd = markdownListMarkerEnd(line)
        if (markerEnd <= 0 || !trimAsciiSpacesLocal(line[markerEnd..]).isEmpty()) { return false }
        let indent = line[..leadingSpacesLocal(line)]
        pushUndoSnapshot()
        replaceModelRange(start, end, indent)
        cursor = start + indent.size
        clearSelection()
        markEdited()
        clearRedo()
        true
    }

    private func indentCurrentLine(): Unit {
        let start = lineStartForOffset(cursor)
        cursor = start
        select(start, start)
        paste("  ")
    }

    private func outdentCurrentLine(): Unit {
        let start = lineStartForOffset(cursor)
        let remove = if (start + 2 <= textModelValue.byteLength() && textModelValue.slice(start, start + 2) == "  ") { 2 } else if (start < textModelValue.byteLength() && textModelValue.slice(start, start + 1) == " ") { 1 } else { 0 }
        if (remove <= 0) { return }
        cursor = start
        select(start, start + remove)
        paste("")
    }

    private func indentSelectedLines(): Unit {
        match (selectionBounds()) {
            case Some((start, end)) => replaceLineRangeIndent(start, end, true)
            case None => indentCurrentLine()
        }
    }

    private func outdentSelectedLines(): Unit {
        match (selectionBounds()) {
            case Some((start, end)) => replaceLineRangeIndent(start, end, false)
            case None => outdentCurrentLine()
        }
    }

    private func replaceLineRangeIndent(start: Int64, end: Int64, indent: Bool): Unit {
        let rangeStart = lineStartForOffset(start)
        let rangeEnd = lineEndForOffset(end)
        let lines = splitLines(textModelValue.slice(rangeStart, rangeEnd))
        var next = ""
        for (i in 0..lines.size) {
            if (i > 0) { next += "\n" }
            if (indent) {
                next += "  " + lines[i]
            } else if (lines[i].startsWith("  ")) {
                next += lines[i][2..]
            } else if (lines[i].startsWith(" ")) {
                next += lines[i][1..]
            } else {
                next += lines[i]
            }
        }
        cursor = rangeStart
        select(rangeStart, rangeEnd)
        paste(next)
        select(rangeStart, rangeStart + next.size)
    }
}

func renderDecoratedLine(buffer: Buffer, x: Int64, y: Int64, width: Int64, spans: Array<RichSpan>): Unit {
    var cx = x
    let right = x + width
    for (span in spans) {
        if (cx >= right) { return }
        let part = truncate(span.text, right - cx)
        buffer.setString(cx, y, part, style: span.style)
        cx += displayWidth(part)
    }
}

func sliceRichSpans(spans: Array<RichSpan>, start: Int64, end: Int64, patch: ?Style): Array<RichSpan> {
    let out = ArrayList<RichSpan>()
    var offset: Int64 = 0
    for (span in spans) {
        let spanStart = offset
        let spanEnd = offset + span.text.size
        if (spanEnd > start && spanStart < end) {
            let localStart = clamp(start - spanStart, 0, span.text.size)
            let localEnd = clamp(end - spanStart, localStart, span.text.size)
            let nextStyle = match (patch) {
                case Some(style) => span.style.patch(style)
                case None => span.style
            }
            out.add(RichSpan(span.text[localStart..localEnd], style: nextStyle, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
        }
        offset = spanEnd
    }
    out.toArray()
}

func leadingSpacesLocal(text: String): Int64 {
    var i: Int64 = 0
    while (i < text.size && (text[i] == b' ' || text[i] == b'\t')) { i++ }
    i
}

func trimAsciiSpacesLocal(text: String): String {
    var start: Int64 = 0
    var end = text.size
    while (start < end && (text[start] == b' ' || text[start] == b'\t')) { start++ }
    while (end > start && (text[end - 1] == b' ' || text[end - 1] == b'\t')) { end-- }
    text[start..end]
}

func markdownListMarkerEnd(line: String): Int64 {
    let start = leadingSpacesLocal(line)
    if (start + 2 <= line.size && (line[start] == b'-' || line[start] == b'*' || line[start] == b'+') && line[start + 1] == b' ') {
        return start + 2
    }
    var i = start
    while (i < line.size && line[i] >= b'0' && line[i] <= b'9') { i++ }
    if (i > start && i + 1 < line.size && line[i] == b'.' && line[i + 1] == b' ') {
        return i + 2
    }
    0
}

func continuationMarker(line: String): String {
    let start = leadingSpacesLocal(line)
    let end = markdownListMarkerEnd(line)
    if (end <= start) { return "" }
    if (line[start] >= b'0' && line[start] <= b'9') {
        // Continue decimal markers directly, including those beyond Int64.
        // Normalize leading zeroes as the previous numeric conversion did.
        let numberEnd = end - 2
        var numberStart = start
        while (numberStart + 1 < numberEnd && line[numberStart] == b'0') { numberStart++ }
        var carry = numberEnd - 1
        while (carry >= numberStart && line[carry] == b'9') { carry-- }
        if (carry < numberStart) { return "1" + repeat("0", numberEnd - numberStart) + ". " }
        let incremented = runeToString(Rune(UInt32(line[carry]) + 1u32))
        return line[numberStart..carry] + incremented + repeat("0", numberEnd - carry - 1) + ". "
    }
    let marker = line[start..end]
    if (hasTaskMarkerAfterListMarker(line, end)) {
        return marker + "[ ] "
    }
    marker
}

func hasTaskMarkerAfterListMarker(line: String, offset: Int64): Bool {
    offset + 4 <= line.size &&
        line[offset] == b'[' &&
        (line[offset + 1] == b' ' || line[offset + 1] == b'x' || line[offset + 1] == b'X') &&
        line[offset + 2] == b']' &&
        line[offset + 3] == b' '
}

func addInlineMarkerDecorations(out: ArrayList<TextDecoration>, line: String, lineStartOffset: Int64, marker: String, style: Style): Unit {
    var start = findStringFromLocal(line, marker, 0)
    while (start >= 0) {
        let end = findStringFromLocal(line, marker, start + marker.size)
        if (end < 0) { return }
        out.add(TextDecoration(lineStartOffset + start, lineStartOffset + end + marker.size, style))
        start = findStringFromLocal(line, marker, end + marker.size)
    }
}

func findStringFromLocal(text: String, needle: String, start: Int64): Int64 {
    var i = start
    while (i + needle.size <= text.size) {
        if (matchesAsciiNeedleAt(text, needle, i)) { return i }
        i++
    }
    -1
}

func matchesAsciiNeedleAt(text: String, needle: String, offset: Int64): Bool {
    if (offset < 0 || offset + needle.size > text.size) { return false }
    for (i in 0..needle.size) {
        if (text[offset + i] != needle[i]) { return false }
    }
    true
}

func isMarkdownFenceLine(line: String, start: Int64): Bool {
    matchesAsciiNeedleAt(line, "```", start) || matchesAsciiNeedleAt(line, "~~~", start)
}

public func markdownDecorations(text: String): Array<TextDecoration> {
    let out = ArrayList<TextDecoration>()
    let lines = splitLines(text)
    var offset: Int64 = 0
    var inFence = false
    for (lineIndex in 0..lines.size) {
        let line = lines[lineIndex]
        let trimmed = leadingSpacesLocal(line)
        if (isMarkdownFenceLine(line, trimmed)) {
            out.add(TextDecoration(offset + trimmed, offset + line.size, Style(fg: Color.Magenta)))
            inFence = !inFence
        } else if (inFence) {
            out.add(TextDecoration(offset, offset + line.size, Style(fg: Color.Magenta)))
        } else {
            for (decoration in markdownDecorationsForLine(line, offset)) {
                out.add(decoration)
            }
        }
        offset += line.size + 1
    }
    out.toArray()
}

public func markdownLineHighlights(text: String): Array<LineHighlight> {
    let out = ArrayList<LineHighlight>()
    let lines = splitLines(text)
    var inFence = false
    for (lineIndex in 0..lines.size) {
        let line = lines[lineIndex]
        let trimmed = leadingSpacesLocal(line)
        let spans = ArrayList<TextDecoration>()
        if (isMarkdownFenceLine(line, trimmed)) {
            spans.add(TextDecoration(trimmed, line.size, Style(fg: Color.Magenta)))
            inFence = !inFence
        } else if (inFence) {
            spans.add(TextDecoration(0, line.size, Style(fg: Color.Magenta)))
        } else {
            for (decoration in markdownDecorationsForLine(line, 0)) {
                spans.add(decoration)
            }
        }
        out.add(LineHighlight(lineIndex, spans.toArray()))
    }
    out.toArray()
}

func lineStartOffsets(text: String): Array<Int64> {
    let offsets = ArrayList<Int64>()
    offsets.add(0)
    var i: Int64 = 0
    while (i < text.size) {
        if (text[i] == b'\n') { offsets.add(i + 1) }
        i++
    }
    offsets.toArray()
}

func completionPrefixStart(text: String, cursor: Int64): Int64 {
    var pos = clampToRuneBoundary(text, cursor)
    while (pos > 0) {
        let prev = previousRuneOffset(text, pos)
        if (!isCompletionWordByte(text[prev])) { return pos }
        pos = prev
    }
    pos
}

func isCompletionWordByte(ch: Byte): Bool {
    (ch >= b'a' && ch <= b'z') ||
        (ch >= b'A' && ch <= b'Z') ||
        (ch >= b'0' && ch <= b'9') ||
        ch == b'_'
}

func markdownDecorationsForLine(line: String, lineStartOffset: Int64): Array<TextDecoration> {
    let out = ArrayList<TextDecoration>()
    let trimmedStart = leadingSpacesLocal(line)
    if (isMarkdownFenceLine(line, trimmedStart)) {
        out.add(TextDecoration(lineStartOffset + trimmedStart, lineStartOffset + line.size, Style(fg: Color.Magenta)))
        return out.toArray()
    }
    if (trimmedStart < line.size && line[trimmedStart] == b'#') {
        out.add(TextDecoration(lineStartOffset + trimmedStart, lineStartOffset + line.size, Style(fg: Color.Yellow, modifier: Modifier.strong())))
        return out.toArray()
    }
    if (trimmedStart < line.size && line[trimmedStart] == b'>') {
        out.add(TextDecoration(lineStartOffset + trimmedStart, lineStartOffset + line.size, Style(fg: Color.Green)))
    }
    if (line.contains("|")) {
        out.add(TextDecoration(lineStartOffset, lineStartOffset + line.size, Style(fg: Color.Cyan)))
    }
    let markerEnd = markdownListMarkerEnd(line)
    if (markerEnd > 0) {
        let markerStyle = Style(fg: Color.Cyan)
        out.add(TextDecoration(lineStartOffset + trimmedStart, lineStartOffset + markerEnd, markerStyle))
        if (matchesAsciiNeedleAt(line, "[ ]", markerEnd) ||
            matchesAsciiNeedleAt(line, "[x]", markerEnd) ||
            matchesAsciiNeedleAt(line, "[X]", markerEnd)) {
            out.add(TextDecoration(lineStartOffset + markerEnd, lineStartOffset + markerEnd + 3, Style(fg: Color.Yellow)))
        }
    }
    addInlineMarkerDecorations(out, line, lineStartOffset, "**", Style(fg: Color.White, modifier: Modifier.strong()))
    addInlineMarkerDecorations(out, line, lineStartOffset, "*", Style(fg: Color.White, modifier: italicModifier()))
    addInlineMarkerDecorations(out, line, lineStartOffset, "~~", Style(fg: Color.Indexed(8)))
    addInlineMarkerDecorations(out, line, lineStartOffset, "`", Style(fg: Color.Magenta))
    addLinkDecorations(out, line, lineStartOffset)
    addInlineMarkerDecorations(out, line, lineStartOffset, "***", Style(fg: Color.White, modifier: strongItalicModifier()))
    out.toArray()
}

func addLinkDecorations(out: ArrayList<TextDecoration>, line: String, lineStartOffset: Int64): Unit {
    var start = findStringFromLocal(line, "[", 0)
    while (start >= 0) {
        let close = findStringFromLocal(line, "](", start + 1)
        if (close < 0) { return }
        let end = findStringFromLocal(line, ")", close + 2)
        if (end < 0) { return }
        out.add(TextDecoration(lineStartOffset + start, lineStartOffset + end + 1, Style(fg: Color.Blue)))
        start = findStringFromLocal(line, "[", end + 1)
    }
}

func italicModifier(): Modifier {
    var modifier = Modifier.none()
    modifier.italic = true
    modifier
}

func strongItalicModifier(): Modifier {
    var modifier = Modifier.strong()
    modifier.italic = true
    modifier
}

public class MarkdownEditorBehavior {
    private let highlighter = MarkdownHighlightCache()

    public init() {}

    public func applyHighlights(area: TextArea): Unit {
        area.setDecorations(highlighter.highlights(area.value))
    }

    public func invalidate(): Unit {
        highlighter.invalidate()
    }

    public func handle(area: TextArea, key: KeyEvent): Bool {
        if (area.readOnly) { return area.handle(key) }
        area.markdownEditing = true
        match (key.code) {
            case KeyCode.Enter =>
                handleMarkdownEnter(area)
            case KeyCode.Tab | KeyCode.BackTab =>
                area.handle(key)
            case KeyCode.Char(r'*') =>
                if (area.hasSelection()) { return wrapSelection(area, "*", "*") }
                if (previousByteIs(area, b'*')) { return closeRepeatedMarker(area, "**") }
                area.handle(key)
            case KeyCode.Char(r'`') =>
                if (area.hasSelection()) { return wrapSelection(area, "`", "`") }
                insertPair(area, "`", "`")
            case KeyCode.Char(r'[') =>
                if (area.hasSelection()) { return wrapSelectionAsLink(area) }
                insertPair(area, "[", "]")
            case KeyCode.Char(r'(') =>
                if (area.hasSelection()) { return wrapSelection(area, "(", ")") }
                insertPair(area, "(", ")")
            case KeyCode.Char(r'~') =>
                if (area.hasSelection()) { return wrapSelection(area, "~~", "~~") }
                if (previousByteIs(area, b'~')) { return closeRepeatedMarker(area, "~~") }
                area.handle(key)
            case KeyCode.Char(r']') =>
                skipClosingDelimiter(area, "]")
            case KeyCode.Char(r')') =>
                skipClosingDelimiter(area, ")")
            case _ => area.handle(key)
        }
    }

    public func toggleBold(area: TextArea): Bool {
        if (area.readOnly) { return false }
        wrapSelectionOrWord(area, "**", "**")
    }

    public func toggleItalic(area: TextArea): Bool {
        if (area.readOnly) { return false }
        wrapSelectionOrWord(area, "*", "*")
    }

    public func toggleCode(area: TextArea): Bool {
        if (area.readOnly) { return false }
        wrapSelectionOrWord(area, "`", "`")
    }

    public func insertLink(area: TextArea, url!: String = "https://example.com"): Bool {
        if (area.readOnly) { return false }
        if (area.hasSelection()) {
            wrapSelection(area, "[", "](${url})")
        } else {
            area.paste("[text](${url})")
            true
        }
    }

    public func insertImage(area: TextArea, url!: String = "image.png", alt!: String = "alt"): Bool {
        if (area.readOnly) { return false }
        if (area.hasSelection()) {
            match (area.selectedRange()) {
                case Some((start, end)) =>
                    let text = area.value[start..end]
                    area.paste("![" + text + "](${url})")
                    area.cursor = start + text.size + 4 + url.size
                    area.clearSelection()
                    true
                case None => false
            }
        } else {
            area.paste("![" + alt + "](${url})")
            true
        }
    }

    public func insertReferenceLink(area: TextArea, id!: String = "ref"): Bool {
        if (area.readOnly) { return false }
        if (area.hasSelection()) {
            wrapSelection(area, "[", "][${id}]")
        } else {
            area.paste("[text][${id}]")
            true
        }
    }

    public func insertReferenceDefinition(area: TextArea, id!: String = "ref", url!: String = "https://example.com", title!: String = ""): Bool {
        if (area.readOnly) { return false }
        let suffix = if (title.isEmpty()) { "" } else { " \"${title}\"" }
        area.paste("[${id}]: ${url}${suffix}\n")
        true
    }

    public func insertFrontmatter(area: TextArea, title!: String = "Untitled"): Bool {
        if (area.readOnly) { return false }
        let oldCursor = area.cursor
        let prefix = "---\ntitle: ${title}\n---\n\n"
        area.cursor = 0
        area.select(0, 0)
        area.paste(prefix)
        area.cursor = oldCursor + prefix.size
        true
    }

    public func insertTable(area: TextArea): Bool {
        if (area.readOnly) { return false }
        area.paste("| Name | Value |\n| --- | --- |\n| item | value |\n")
        true
    }

    public func insertCodeFence(area: TextArea, language!: String = ""): Bool {
        if (area.readOnly) { return false }
        area.paste("```" + language + "\n\n```\n")
        true
    }
}

public class MarkdownTextEditor <: Widget {
    public let area: TextArea
    public let behavior: MarkdownEditorBehavior

    public init(value!: String = "", block!: ?Block = None, lineNumbers!: Bool = true) {
        area = TextArea(value: value, block: block, lineNumbers: lineNumbers, markdownEditing: true)
        behavior = MarkdownEditorBehavior()
    }

    public func handle(key: KeyEvent): Bool {
        behavior.handle(area, key)
    }

    public func render(areaRect: Rect, buffer: Buffer): Unit {
        behavior.applyHighlights(area)
        area.render(areaRect, buffer)
    }
}
