package diff

import core.*
import std.collection.*

public enum DiffLineKind {
    | Context
    | Add
    | Delete
    | Header
}

public class DiffLine {
    public let kind: DiffLineKind
    public let text: String
    public let oldLine: ?Int64
    public let newLine: ?Int64

    public init(kind: DiffLineKind, text: String, oldLine!: ?Int64 = None, newLine!: ?Int64 = None) {
        this.kind = kind
        this.text = text
        this.oldLine = oldLine
        this.newLine = newLine
    }
}

public class DiffHunk {
    public let header: String
    public let lines: Array<DiffLine>
    public var collapsed: Bool

    public init(header: String, lines!: Array<DiffLine> = [], collapsed!: Bool = false) {
        this.header = header
        this.lines = lines
        this.collapsed = collapsed
    }
}

public class DiffFile {
    public let oldPath: String
    public let newPath: String
    public let hunks: Array<DiffHunk>

    public init(oldPath: String, newPath: String, hunks!: Array<DiffHunk> = []) {
        this.oldPath = oldPath
        this.newPath = newPath
        this.hunks = hunks
    }

    public func addedLines(): Int64 {
        countLines(DiffLineKind.Add)
    }

    public func deletedLines(): Int64 {
        countLines(DiffLineKind.Delete)
    }

    private func countLines(kind: DiffLineKind): Int64 {
        var count: Int64 = 0
        for (hunk in hunks) {
            for (line in hunk.lines) {
                if (sameDiffKind(line.kind, kind)) { count++ }
            }
        }
        count
    }
}

public class DiffDocument {
    public let files: Array<DiffFile>

    public init(files: Array<DiffFile>) {
        this.files = files
    }

    public func addedLines(): Int64 {
        var count: Int64 = 0
        for (file in files) { count += file.addedLines() }
        count
    }

    public func deletedLines(): Int64 {
        var count: Int64 = 0
        for (file in files) { count += file.deletedLines() }
        count
    }
}

public func parseUnifiedDiff(text: String): DiffDocument {
    let files = ArrayList<DiffFile>()
    var oldPath = ""
    var newPath = ""
    let hunks = ArrayList<DiffHunk>()
    var currentLines = ArrayList<DiffLine>()
    var currentHeader = ""
    var oldLine: Int64 = 0
    var newLine: Int64 = 0
    var oldRemaining: Int64 = 0
    var newRemaining: Int64 = 0

    for (line in splitDiffLines(text)) {
        if (line.startsWith("diff --git ")) {
            flushHunk(hunks, currentHeader, currentLines)
            currentLines = ArrayList<DiffLine>()
            currentHeader = ""
            flushFile(files, oldPath, newPath, hunks)
            oldPath = ""
            newPath = ""
            oldRemaining = 0
            newRemaining = 0
        } else if (line.startsWith("@@")) {
            flushHunk(hunks, currentHeader, currentLines)
            currentLines = ArrayList<DiffLine>()
            currentHeader = line
            let (oldStart, newStart) = parseHunkHeader(line)
            oldLine = oldStart
            newLine = newStart
            oldRemaining = hunkRangeCount(line, b'-')
            newRemaining = hunkRangeCount(line, b'+')
        } else if (line.startsWith("\\ No newline at end of file")) {
            // This annotates the preceding source line and consumes no line numbers.
            continue
        } else if (!currentHeader.isEmpty() && (oldRemaining > 0 || newRemaining > 0)) {
            if (line.startsWith("+")) {
                currentLines.add(DiffLine(DiffLineKind.Add, line, newLine: Some(newLine)))
                newLine++
                newRemaining = max(0, newRemaining - 1)
            } else if (line.startsWith("-")) {
                currentLines.add(DiffLine(DiffLineKind.Delete, line, oldLine: Some(oldLine)))
                oldLine++
                oldRemaining = max(0, oldRemaining - 1)
            } else if (line.startsWith(" ")) {
                currentLines.add(DiffLine(DiffLineKind.Context, line, oldLine: Some(oldLine), newLine: Some(newLine)))
                oldLine++
                newLine++
                oldRemaining = max(0, oldRemaining - 1)
                newRemaining = max(0, newRemaining - 1)
            }
        } else if (line.startsWith("--- ")) {
            flushHunk(hunks, currentHeader, currentLines)
            currentLines = ArrayList<DiffLine>()
            currentHeader = ""
            if (hunks.size > 0 || !newPath.isEmpty()) { flushFile(files, oldPath, newPath, hunks) }
            oldPath = stripDiffPath(line[4..])
            newPath = ""
        } else if (line.startsWith("+++ ")) {
            newPath = stripDiffPath(line[4..])
        }
    }
    flushHunk(hunks, currentHeader, currentLines)
    flushFile(files, oldPath, newPath, hunks)
    DiffDocument(files.toArray())
}

/** 差异视图各语义角色的逐属性覆盖。未指定的属性继承对应主题样式；
 * `Some(Color.Reset)` 可显式恢复终端默认颜色。
 */
public struct DiffViewStyles {
    public let summary: StyleOverride
    public let hunk: StyleOverride
    public let context: StyleOverride
    public let add: StyleOverride
    public let delete: StyleOverride
    public let header: StyleOverride

    public init(summary!: StyleOverride = StyleOverride(), hunk!: StyleOverride = StyleOverride(),
        context!: StyleOverride = StyleOverride(), add!: StyleOverride = StyleOverride(),
        delete!: StyleOverride = StyleOverride(), header!: StyleOverride = StyleOverride()) {
        this.summary = summary
        this.hunk = hunk
        this.context = context
        this.add = add
        this.delete = delete
        this.header = header
    }
}

public class DiffView <: Widget {
    private let document: DiffDocument
    // render normalizes this index to the available file range (negative => 0).
    public var selectedFile: Int64
    public var selectedLine: Int64
    /** 差异内容的显示偏移量，按显示行跳过区块标题及差异行；并排模式的配对行算一行。构造时传入的负值按 0 保存。
     */
    public var offset: Int64
    private let block: ?Block
    private let sideBySide: Bool
    private let theme: ?Theme
    private let styles: DiffViewStyles

    /** 以指定文档创建差异视图，保存显示选项，并将文件索引、行索引和偏移量的负值置为 0。
     * 指定主题时内容区铺设 surface 背景，各角色继承对应语义样式；styles 可逐项覆盖文本样式，包括显式清除背景。
     * 未指定主题时继承缓冲区上下文主题；无上下文主题时保留传统配色。外围区块的显式主题优先。
     */
    public init(document: DiffDocument, selectedFile!: Int64 = 0, selectedLine!: Int64 = 0, offset!: Int64 = 0,
        block!: ?Block = None, sideBySide!: Bool = false, theme!: ?Theme = None,
        styles!: DiffViewStyles = DiffViewStyles()) {
        this.document = document
        this.selectedFile = max(0, selectedFile)
        this.selectedLine = max(0, selectedLine)
        this.offset = max(0, offset)
        this.block = block
        this.sideBySide = sideBySide
        this.theme = theme
        this.styles = styles
    }

    /** 将选中文件的路径及增删行数绘制到目标区域，并按偏移量绘制区块标题和未折叠的差异行；有外围区块时先绘制区块并使用其内部区域。区域无可用宽高或文档无文件时不绘制差异内容；有主题时空内容区仍铺设 surface 背景。渲染时会修正选中文件索引。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let canvas = Canvas(buffer, target)
        let resolvedTheme = buffer.resolveTheme(theme)
        if (let Some(t) <- resolvedTheme) { canvas.fillRect(target, t.surface) }
        if (document.files.size == 0) { return }
        selectedFile = max(0, min(selectedFile, document.files.size - 1))
        let file = document.files[selectedFile]
        var y = target.y
        let summary = "${file.newPath}  +${file.addedLines()} -${file.deletedLines()}"
        canvas.drawText(target.x, y, truncateDiff(summary, target.width, canvas.textWidthOptions()), summaryStyle(resolvedTheme))
        y++
        var rendered: Int64 = 0
        for (hunk in file.hunks) {
            if (rendered >= offset && y < target.bottom) {
                canvas.drawText(target.x, y, truncateDiff(hunk.header, target.width, canvas.textWidthOptions()), hunkStyle(resolvedTheme))
                y++
            }
            rendered++
            if (!hunk.collapsed) {
                // A single visible column uses the unified layout.
                if (sideBySide && target.width >= 2) {
                    for (row in sideBySideRows(hunk.lines)) {
                        if (rendered >= offset && y < target.bottom) {
                            renderSideBySideRow(target, y, row, canvas, resolvedTheme)
                            y++
                        }
                        rendered++
                    }
                } else {
                    for (line in hunk.lines) {
                        if (rendered >= offset && y < target.bottom) {
                            let prefix = formatLineNumber(line.oldLine) + " " + formatLineNumber(line.newLine) + " "
                            canvas.drawText(target.x, y, truncateDiff(prefix + line.text, target.width, canvas.textWidthOptions()), diffLineStyle(line.kind, resolvedTheme))
                            y++
                        }
                        rendered++
                    }
                }
            }
        }
    }

    private func renderSideBySideRow(area: Rect, y: Int64, row: DiffSideRow, canvas: Canvas, resolvedTheme: ?Theme): Unit {
        let leftWidth = area.width / 2
        let rightWidth = area.width - leftWidth
        // The absent side and trailing cells must not retain an older frame.
        if (resolvedTheme.isNone()) { canvas.fillRect(Rect(area.x, y, area.width, 1), Style.default()) }
        if (let Some(line) <- row.oldLine) {
            let marker = if (sameDiffKind(line.kind, DiffLineKind.Delete)) { "-" } else { " " }
            let text = marker + formatLineNumber(line.oldLine) + " " + stripSign(line.text)
            canvas.drawText(area.x, y, truncateDiff(text, leftWidth, canvas.textWidthOptions()), diffLineStyle(line.kind, resolvedTheme))
        }
        if (let Some(line) <- row.newLine) {
            let marker = if (sameDiffKind(line.kind, DiffLineKind.Add)) { "+" } else { " " }
            let text = marker + formatLineNumber(line.newLine) + " " + stripSign(line.text)
            canvas.drawText(area.x + leftWidth, y, truncateDiff(text, rightWidth, canvas.textWidthOptions()), diffLineStyle(line.kind, resolvedTheme))
        }
    }

    private func summaryStyle(resolvedTheme: ?Theme): Style {
        let base = match (resolvedTheme) {
            case Some(t) => t.accent.withBg(t.surface.bg)
            case None => Style(fg: Color.Cyan)
        }
        styles.summary.apply(base)
    }

    private func hunkStyle(resolvedTheme: ?Theme): Style {
        let base = match (resolvedTheme) {
            case Some(t) => t.info.withBg(t.surface.bg)
            case None => Style(fg: Color.Magenta)
        }
        styles.hunk.apply(base)
    }

    private func diffLineStyle(kind: DiffLineKind, resolvedTheme: ?Theme): Style {
        let base = match (resolvedTheme) {
            case Some(t) => match (kind) {
                case DiffLineKind.Context => t.normal.withBg(t.surface.bg)
                case DiffLineKind.Add => t.success.withBg(t.surface.bg)
                case DiffLineKind.Delete => t.error.withBg(t.surface.bg)
                case DiffLineKind.Header => t.heading.withBg(t.surface.bg)
            }
            case None => legacyDiffLineStyle(kind)
        }
        match (kind) {
            case DiffLineKind.Context => styles.context.apply(base)
            case DiffLineKind.Add => styles.add.apply(base)
            case DiffLineKind.Delete => styles.delete.apply(base)
            case DiffLineKind.Header => styles.header.apply(base)
        }
    }
}

// Pair only contiguous change blocks within a hunk, preserving order within
// each side. Context and headers separate blocks and appear on both sides.
private class DiffSideRow {
    let oldLine: ?DiffLine
    let newLine: ?DiffLine
    init(oldLine: ?DiffLine, newLine: ?DiffLine) {
        this.oldLine = oldLine
        this.newLine = newLine
    }
}

private func sideBySideRows(lines: Array<DiffLine>): Array<DiffSideRow> {
    let rows = ArrayList<DiffSideRow>()
    var index: Int64 = 0
    while (index < lines.size) {
        let line = lines[index]
        if (!sameDiffKind(line.kind, DiffLineKind.Add) && !sameDiffKind(line.kind, DiffLineKind.Delete)) {
            rows.add(DiffSideRow(Some(line), Some(line)))
            index++
            continue
        }
        let removed = ArrayList<DiffLine>()
        let added = ArrayList<DiffLine>()
        while (index < lines.size) {
            let change = lines[index]
            if (sameDiffKind(change.kind, DiffLineKind.Delete)) {
                removed.add(change)
            } else if (sameDiffKind(change.kind, DiffLineKind.Add)) {
                added.add(change)
            } else {
                break
            }
            index++
        }
        for (row in 0..max(removed.size, added.size)) {
            let left: ?DiffLine = if (row < removed.size) { Some(removed[row]) } else { None }
            let right: ?DiffLine = if (row < added.size) { Some(added[row]) } else { None }
            rows.add(DiffSideRow(left, right))
        }
    }
    rows.toArray()
}

func sameDiffKind(left: DiffLineKind, right: DiffLineKind): Bool {
    match (left) {
        case DiffLineKind.Context =>
            match (right) {
                case DiffLineKind.Context => true
                case _ => false
            }
        case DiffLineKind.Add =>
            match (right) {
                case DiffLineKind.Add => true
                case _ => false
            }
        case DiffLineKind.Delete =>
            match (right) {
                case DiffLineKind.Delete => true
                case _ => false
            }
        case DiffLineKind.Header =>
            match (right) {
                case DiffLineKind.Header => true
                case _ => false
            }
    }
}

func formatLineNumber(value: ?Int64): String {
    match (value) {
        case Some(line) => padLeft("${line}", 4)
        case None => "    "
    }
}

func stripSign(text: String): String {
    if (text.startsWith("+") || text.startsWith("-") || text.startsWith(" ")) {
        text[1..]
    } else {
        text
    }
}

func padLeft(text: String, width: Int64): String {
    if (text.size >= width) { return text }
    repeatDiff(" ", width - text.size) + text
}

func repeatDiff(text: String, count: Int64): String {
    var out = ""
    for (_ in 0..max(0, count)) { out += text }
    out
}

func flushHunk(hunks: ArrayList<DiffHunk>, header: String, lines: ArrayList<DiffLine>): Unit {
    if (!header.isEmpty()) {
        hunks.add(DiffHunk(header, lines: lines.toArray()))
    }
}

func flushFile(files: ArrayList<DiffFile>, oldPath: String, newPath: String, hunks: ArrayList<DiffHunk>): Unit {
    if (!oldPath.isEmpty() || !newPath.isEmpty() || hunks.size > 0) {
        files.add(DiffFile(oldPath, newPath, hunks: hunks.toArray()))
        while (hunks.size > 0) { hunks.remove(at: 0) }
    }
}

func stripDiffPath(path: String): String {
    // Traditional unified diff separates a path and its timestamp with a tab.
    // Spaces remain part of the path.
    var end = path.size
    for (i in 0..path.size) { if (path[i] == b'\t') { end = i; break } }
    let name = path[..end]
    if (name.startsWith("a/") || name.startsWith("b/")) { name[2..] } else { name }
}

func parseHunkHeader(header: String): (Int64, Int64) {
    let oldMarker = findDiff(header, "-")
    let newMarker = findDiff(header, "+")
    let oldStart = if (oldMarker >= 0) { parseNumberAt(header, oldMarker + 1) } else { 0 }
    let newStart = if (newMarker >= 0) { parseNumberAt(header, newMarker + 1) } else { 0 }
    (oldStart, newStart)
}

func hunkRangeCount(header: String, sign: Byte): Int64 {
    var i: Int64 = 0
    while (i < header.size && header[i] != sign) { i++ }
    if (i == header.size) { return 0 }
    i++
    while (i < header.size && header[i] >= b'0' && header[i] <= b'9') { i++ }
    if (i < header.size && header[i] == b',') { parseNumberAt(header, i + 1) } else { 1 }
}

func parseNumberAt(text: String, start: Int64): Int64 {
    var value: Int64 = 0
    var i = start
    while (i < text.size && text[i] >= b'0' && text[i] <= b'9') {
        value = value * 10 + Int64(text[i] - b'0')
        i++
    }
    value
}

func findDiff(text: String, needle: String): Int64 {
    var i: Int64 = 0
    while (i + needle.size <= text.size) {
        if (text[i..i + needle.size] == needle) { return i }
        i++
    }
    -1
}

func splitDiffLines(text: String): Array<String> {
    let out = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < text.size) {
        if (text[i] == b'\n') {
            var end = i
            if (end > start && text[end - 1] == b'\r') { end-- }
            out.add(text[start..end])
            start = i + 1
        }
        i++
    }
    if (start < text.size) {
        out.add(text[start..])
    }
    out.toArray()
}

func legacyDiffLineStyle(kind: DiffLineKind): Style {
    match (kind) {
        case DiffLineKind.Add => Style(fg: Color.Green)
        case DiffLineKind.Delete => Style(fg: Color.Red)
        case DiffLineKind.Header => Style(fg: Color.Magenta)
        case DiffLineKind.Context => Style.default()
    }
}

func truncateDiff(text: String, width: Int64, options: TextWidthOptions): String {
    graphemePrefix(text, max(0, width), options: options)
}
