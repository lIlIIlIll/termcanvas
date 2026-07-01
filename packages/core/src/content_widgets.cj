package core

import std.collection.*

public enum TranscriptItemKind {
    | Text
    | Code
    | Event
    | Error
    | Progress
    | Detail
}

public enum TranscriptItemStatus {
    | Pending
    | Running
    | Done
    | Failed
    | Cancelled
}

public class TranscriptItem {
    public let id: String
    public let kind: TranscriptItemKind
    public let title: String
    public let body: Document
    public let status: TranscriptItemStatus
    public var collapsed: Bool
    public let timestamp: String
    public let duration: String

    public init(
        id: String,
        kind!: TranscriptItemKind = TranscriptItemKind.Text,
        title!: String = "",
        body!: Document = Document([]),
        status!: TranscriptItemStatus = TranscriptItemStatus.Done,
        collapsed!: Bool = false,
        timestamp!: String = "",
        duration!: String = ""
    ) {
        this.id = id
        this.kind = kind
        this.title = title
        this.body = body
        this.status = status
        this.collapsed = collapsed
        this.timestamp = timestamp
        this.duration = duration
    }
}

public class Transcript {
    private let items = ArrayList<TranscriptItem>()

    public init(items!: Array<TranscriptItem> = []) {
        for (item in items) { this.items.add(item) }
    }

    public func append(item: TranscriptItem): Unit {
        items.add(item)
    }

    public func size(): Int64 {
        items.size
    }

    public func get(index: Int64): ?TranscriptItem {
        if (index < 0 || index >= items.size) { None } else { Some(items[index]) }
    }

    public func toArray(): Array<TranscriptItem> {
        items.toArray()
    }

    public func toggleCollapsed(id: String): Bool {
        for (item in items) {
            if (item.id == id) {
                item.collapsed = !item.collapsed
                return true
            }
        }
        false
    }
}

public class TranscriptView <: Widget {
    private let transcript: Transcript
    public var offset: Int64
    public var selected: Int64
    private let block: ?Block
    private let style: Style
    private let selectedStyle: Style

    public init(
        transcript: Transcript,
        offset!: Int64 = 0,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)
    ) {
        this.transcript = transcript
        this.offset = max(0, offset)
        this.selected = max(0, selected)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
    }

    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        let count = transcript.size()
        match (key.code) {
            case KeyCode.Up =>
                selected = max(0, selected - 1)
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.Down =>
                selected = min(max(0, count - 1), selected + 1)
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.PageUp =>
                selected = max(0, selected - max(1, viewportHeight))
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.PageDown =>
                selected = min(max(0, count - 1), selected + max(1, viewportHeight))
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.Enter | KeyCode.Char(r' ') =>
                match (transcript.get(selected)) {
                    case Some(item) => transcript.toggleCollapsed(item.id)
                    case None => false
                }
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        ensureTranscriptVisible(target.height)
        var y = target.y
        var index = offset
        while (index < transcript.size() && y < target.bottom) {
            match (transcript.get(index)) {
                case Some(item) =>
                    let headerStyle = if (index == selected) { selectedStyle } else { transcriptStatusStyle(item.status, style) }
                    buffer.setString(target.x, y, truncate(transcriptHeader(item), target.width), style: headerStyle)
                    y++
                    if (!item.collapsed && y < target.bottom) {
                        let height = min(target.bottom - y, max(1, item.body.lines.size))
                        DocumentView(item.body).render(Rect(target.x + 2, y, max(0, target.width - 2), height), buffer)
                        y += height
                    }
                case None => ()
            }
            index++
        }
    }

    private func ensureTranscriptVisible(viewportHeight: Int64): Unit {
        if (selected < offset) {
            offset = selected
        } else if (selected >= offset + viewportHeight) {
            offset = selected - viewportHeight + 1
        }
    }
}

public class ComposerSubmit {
    public let text: String
    public init(text: String) {
        this.text = text
    }
}

public class Composer <: Widget {
    public let area: TextArea
    private let history = ArrayList<String>()
    private let slashHints: Array<String>
    private var historyIndex: Int64 = -1
    private let block: ?Block

    public init(value!: String = "", slashHints!: Array<String> = [], block!: ?Block = None) {
        this.area = TextArea(value: value, block: block, placeholder: "message")
        this.slashHints = slashHints
        this.block = block
    }

    public func handle(key: KeyEvent): ?ComposerSubmit {
        match (key.code) {
            case KeyCode.Enter =>
                if (key.modifiers.shift || key.modifiers.alt) {
                    _ = area.handle(key)
                    None
                } else {
                    submit()
                }
            case KeyCode.Up =>
                if (area.value.isEmpty() && history.size > 0) {
                    historyIndex = if (historyIndex < 0) { history.size - 1 } else { max(0, historyIndex - 1) }
                    area.setValue(history[historyIndex])
                    area.cursor = area.value.size
                    None
                } else {
                    _ = area.handle(key)
                    None
                }
            case KeyCode.Down =>
                if (historyIndex >= 0 && history.size > 0) {
                    historyIndex = min(history.size - 1, historyIndex + 1)
                    area.setValue(history[historyIndex])
                    area.cursor = area.value.size
                    None
                } else {
                    _ = area.handle(key)
                    None
                }
            case _ =>
                _ = area.handle(key)
                None
        }
    }

    public func paste(text: String, collapseThreshold!: Int64 = 2000): Bool {
        if (text.size > collapseThreshold) {
            area.paste("[pasted ${text.size} bytes]")
        } else {
            area.paste(text)
        }
        true
    }

    public func currentSlashHints(): Array<String> {
        if (!area.value.startsWith("/")) { return [] }
        let out = ArrayList<String>()
        for (hint in slashHints) {
            if (hint.startsWith(area.value)) { out.add(hint) }
        }
        out.toArray()
    }

    public func render(areaRect: Rect, buffer: Buffer): Unit {
        area.render(areaRect, buffer)
        let hints = currentSlashHints()
        if (hints.size > 0 && areaRect.height > 1) {
            buffer.setString(areaRect.x + 1, areaRect.bottom - 1, truncate(join(hints, "  "), max(0, areaRect.width - 2)), style: Style(fg: Color.Indexed(8)))
        }
    }

    private func submit(): ?ComposerSubmit {
        let text = trimAsciiSpacesLocal(area.value)
        if (text.isEmpty()) { return None }
        history.add(text)
        historyIndex = -1
        area.setValue("")
        Some(ComposerSubmit(text))
    }
}

public class ActivityStep {
    public let title: String
    public let status: TranscriptItemStatus
    public let detail: String
    public let duration: String

    public init(title: String, status!: TranscriptItemStatus = TranscriptItemStatus.Pending, detail!: String = "", duration!: String = "") {
        this.title = title
        this.status = status
        this.detail = detail
        this.duration = duration
    }
}

public class ActivityTimeline <: Widget {
    private let steps: Array<ActivityStep>
    private let block: ?Block

    public init(steps: Array<ActivityStep>, block!: ?Block = None) {
        this.steps = steps
        this.block = block
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        let rows = min(target.height, steps.size)
        for (i in 0..rows) {
            let step = steps[i]
            let suffix = if (step.duration.isEmpty()) { "" } else { " " + step.duration }
            let detail = if (step.detail.isEmpty()) { "" } else { " - " + step.detail }
            buffer.setString(target.x, target.y + i, truncate(statusMark(step.status) + " " + step.title + detail + suffix, target.width), style: transcriptStatusStyle(step.status, Style.default()))
        }
    }
}

public class RequestDialog <: Widget {
    private let title: String
    private let body: String
    private let detail: Document
    private let risk: String
    private let buttons: Array<String>
    public var selected: Int64

    public init(title!: String = "Request", body!: String = "", detail!: Document = Document([]), risk!: String = "", buttons!: Array<String> = ["Cancel", "Confirm"], selected!: Int64 = 0) {
        this.title = title
        this.body = body
        this.detail = detail
        this.risk = risk
        this.buttons = buttons
        this.selected = clamp(selected, 0, max(0, buttons.size - 1))
    }

    public func handle(key: KeyEvent): ?String {
        let dialog = Dialog(title: title, body: body, buttons: buttons, selected: selected)
        match (dialog.handle(key)) {
            case Some(action) =>
                selected = dialog.selected
                Some(action)
            case None =>
                selected = dialog.selected
                None
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        Dialog(title: title, body: if (risk.isEmpty()) { body } else { risk + "\n" + body }, buttons: buttons, selected: selected).render(area, buffer)
        if (detail.lines.size > 0 && area.width > 10 && area.height > 10) {
            let detailArea = Rect(area.x + area.width / 4, area.y + area.height / 2, area.width / 2, max(1, area.height / 3))
            DocumentView(detail).render(detailArea, buffer)
        }
    }
}

public type DecisionDialog = RequestDialog

func transcriptHeader(item: TranscriptItem): String {
    let collapse = if (item.collapsed) { "+ " } else { "- " }
    let title = if (item.title.isEmpty()) { item.id } else { item.title }
    let time = if (item.timestamp.isEmpty()) { "" } else { " " + item.timestamp }
    collapse + statusMark(item.status) + " " + title + time
}

func statusMark(status: TranscriptItemStatus): String {
    match (status) {
        case TranscriptItemStatus.Pending => "?"
        case TranscriptItemStatus.Running => ">"
        case TranscriptItemStatus.Done => "*"
        case TranscriptItemStatus.Failed => "!"
        case TranscriptItemStatus.Cancelled => "x"
    }
}

func transcriptStatusStyle(status: TranscriptItemStatus, base: Style): Style {
    match (status) {
        case TranscriptItemStatus.Pending => base.patch(Style(fg: Color.Indexed(8)))
        case TranscriptItemStatus.Running => base.patch(Style(fg: Color.Cyan))
        case TranscriptItemStatus.Done => base.patch(Style(fg: Color.Green))
        case TranscriptItemStatus.Failed => base.patch(Style(fg: Color.Red))
        case TranscriptItemStatus.Cancelled => base.patch(Style(fg: Color.Yellow))
    }
}

func insertPair(area: TextArea, left: String, right: String): Bool {
    let pos = area.cursor
    area.paste(left + right)
    area.cursor = pos + left.size
    true
}

func handleMarkdownEnter(area: TextArea): Bool {
    area.handle(KeyEvent(KeyCode.Enter))
}

func previousByteIs(area: TextArea, byte: UInt8): Bool {
    area.cursor > 0 && area.cursor <= area.value.size && area.value[area.cursor - 1] == byte
}

func closeRepeatedMarker(area: TextArea, marker: String): Bool {
    let start = area.cursor - 1
    area.select(start, area.cursor)
    area.paste(marker + marker)
    area.cursor = start + marker.size
    true
}

func wrapSelection(area: TextArea, left: String, right: String): Bool {
    match (area.selectedRange()) {
        case Some((start, end)) =>
            let text = area.value[start..end]
            area.paste(left + text + right)
            area.cursor = start + left.size + text.size
            area.clearSelection()
            true
        case None => false
    }
}

func wrapSelectionAsLink(area: TextArea): Bool {
    match (area.selectedRange()) {
        case Some((start, end)) =>
            let text = area.value[start..end]
            area.paste("[" + text + "]()")
            area.cursor = start + text.size + 3
            area.clearSelection()
            true
        case None => false
    }
}

func skipClosingDelimiter(area: TextArea, delimiter: String): Bool {
    if (area.cursor + delimiter.size <= area.value.size && area.value[area.cursor..area.cursor + delimiter.size] == delimiter) {
        area.cursor += delimiter.size
        area.clearSelection()
        return true
    }
    area.paste(delimiter)
    true
}

func wrapSelectionOrWord(area: TextArea, left: String, right: String): Bool {
    if (area.hasSelection()) { return wrapSelection(area, left, right) }
    let start = previousWordOffset(area.value, area.cursor)
    let end = nextWordOffset(area.value, area.cursor)
    area.select(start, end)
    wrapSelection(area, left, right)
}

public class SaveDiagnostic {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        this.path = path
        this.message = message
    }
}

public class EditorBuffer {
    public var path: String
    public var title: String
    public let textArea: TextArea
    public var dirty: Bool
    public var readonly: Bool
    public var lastError: ?SaveDiagnostic

    public init(path!: String = "", title!: String = "Untitled", value!: String = "", readonly!: Bool = false, markdownEditing!: Bool = false) {
        this.path = path
        this.title = title
        this.textArea = TextArea(value: value, readOnly: readonly, markdownEditing: markdownEditing)
        this.dirty = false
        this.readonly = readonly
        this.lastError = None
    }

    public func setReadOnly(readonly: Bool): Unit {
        this.readonly = readonly
        textArea.readOnly = readonly
    }

    public func markSaved(path!: String = ""): Unit {
        if (!path.isEmpty()) { this.path = path }
        dirty = false
        lastError = None
        textArea.clearHistory()
    }

    public func markSaveFailed(message: String): Unit {
        lastError = Some(SaveDiagnostic(path, message))
    }
}

public class BufferSet {
    private let buffers = ArrayList<EditorBuffer>()
    private let recent = ArrayList<String>()
    public var active: Int64 = 0

    public init(buffers!: Array<EditorBuffer> = []) {
        for (buffer in buffers) { this.buffers.add(buffer) }
        active = clamp(active, 0, max(0, this.buffers.size - 1))
    }

    public func size(): Int64 { buffers.size }

    public func activeBuffer(): ?EditorBuffer {
        if (buffers.size == 0) { return None }
        active = clamp(active, 0, buffers.size - 1)
        Some(buffers[active])
    }

    public func add(buffer: EditorBuffer): Int64 {
        buffers.add(buffer)
        active = buffers.size - 1
        remember(buffer.path)
        active
    }

    public func openOrSelect(buffer: EditorBuffer): Int64 {
        if (!buffer.path.isEmpty()) {
            for (i in 0..buffers.size) {
                if (buffers[i].path == buffer.path) {
                    active = i
                    remember(buffer.path)
                    return active
                }
            }
        }
        add(buffer)
    }

    public func close(index: Int64): ?EditorBuffer {
        if (index < 0 || index >= buffers.size) { return None }
        let removed = buffers[index]
        buffers.remove(at: index)
        active = clamp(active, 0, max(0, buffers.size - 1))
        Some(removed)
    }

    public func next(): ?EditorBuffer {
        if (buffers.size == 0) { return None }
        active = (active + 1) % buffers.size
        activeBuffer()
    }

    public func previous(): ?EditorBuffer {
        if (buffers.size == 0) { return None }
        active = (active + buffers.size - 1) % buffers.size
        activeBuffer()
    }

    public func select(index: Int64): ?EditorBuffer {
        if (index < 0 || index >= buffers.size) { return None }
        active = index
        activeBuffer()
    }

    public func remember(path: String): Unit {
        if (path.isEmpty()) { return }
        for (i in 0..recent.size) {
            if (recent[i] == path) {
                recent.remove(at: i)
                break
            }
        }
        recent.add(path)
        while (recent.size > 10) {
            recent.remove(at: 0)
        }
    }

    public func recentFiles(): Array<String> {
        recent.toArray()
    }

    public func tabTitles(): Array<String> {
        let titles = ArrayList<String>()
        for (buffer in buffers) {
            titles.add(if (buffer.dirty) { buffer.title + "*" } else { buffer.title })
        }
        titles.toArray()
    }
}

public class SearchPanel <: Widget {
    public var query: String
    public var matches: Int64
    private let style: Style

    public init(query!: String = "", matches!: Int64 = 0, style!: Style = Style.default()) {
        this.query = query
        this.matches = max(0, matches)
        this.style = style
    }

    public func updateFrom(buffer: TextBuffer): Unit {
        matches = buffer.findAll(query).size
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.setString(area.x, area.y, truncate("find: " + query + " (${matches})", area.width), style: style)
    }
}

public class ReplacePanel <: Widget {
    public var query: String
    public var replacement: String
    public var lastCount: Int64 = 0
    private let style: Style

    public init(query!: String = "", replacement!: String = "", style!: Style = Style.default()) {
        this.query = query
        this.replacement = replacement
        this.style = style
    }

    public func apply(buffer: TextBuffer): Int64 {
        lastCount = buffer.replaceAll(query, replacement)
        lastCount
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.setString(area.x, area.y, truncate("replace: " + query + " -> " + replacement + " (${lastCount})", area.width), style: style)
    }
}

public class TextDocumentView <: Widget {
    private let lineCount: Int64
    private let lineAt: (Int64) -> String
    public var offset: Int64
    private let style: Style

    public init(lineCount: Int64, lineAt: (Int64) -> String, offset!: Int64 = 0, style!: Style = Style.default()) {
        this.lineCount = max(0, lineCount)
        this.lineAt = lineAt
        this.offset = max(0, offset)
        this.style = style
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let start = clamp(offset, 0, max(0, lineCount - area.height))
        for (row in 0..min(area.height, lineCount - start)) {
            buffer.setString(area.x, area.y + row, truncate(lineAt(start + row), area.width), style: style)
        }
    }
}

public class SyntaxRule {
    public let token: String
    public let style: Style
    public init(token: String, style: Style) {
        this.token = token
        this.style = style
    }
}

public class SyntaxHighlighter {
    private let rules = ArrayList<SyntaxRule>()
    public init(rules!: Array<SyntaxRule> = []) {
        for (rule in rules) { this.rules.add(rule) }
    }
    public func add(rule: SyntaxRule): Unit { rules.add(rule) }
    public func styleFor(text: String): Style {
        for (rule in rules) {
            if (text.contains(rule.token)) { return rule.style }
        }
        Style.default()
    }
}

public class SoftWrapView <: Widget {
    private let text: String
    private let style: Style
    public init(text: String, style!: Style = Style.default()) {
        this.text = text
        this.style = style
    }
    public func render(area: Rect, buffer: Buffer): Unit {
        Paragraph(text, wrap: WrapMode.Word, style: style).render(area, buffer)
    }
}

public class TextEditor <: Widget {
    public let area: TextArea
    public let search: SearchPanel
    public let replace: ReplacePanel

    public init(value!: String = "") {
        area = TextArea(value: value, lineNumbers: true)
        search = SearchPanel()
        replace = ReplacePanel()
    }

    public func handle(key: KeyEvent): Bool { area.handle(key) }

    public func render(areaRect: Rect, buffer: Buffer): Unit {
        let rows = Layout.vertical([Constraint.Min(3), Constraint.Length(1), Constraint.Length(1)]).split(areaRect)
        if (rows.size >= 3) {
            area.render(rows[0], buffer)
            search.render(rows[1], buffer)
            replace.render(rows[2], buffer)
        }
    }
}

