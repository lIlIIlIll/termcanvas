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

public class DiffView <: Widget {
    private let document: DiffDocument
    // render normalizes this index to the available file range (negative => 0).
    public var selectedFile: Int64
    public var selectedLine: Int64
    public var offset: Int64
    private let block: ?Block
    private let sideBySide: Bool

    public init(document: DiffDocument, selectedFile!: Int64 = 0, selectedLine!: Int64 = 0, offset!: Int64 = 0, block!: ?Block = None, sideBySide!: Bool = false) {
        this.document = document
        this.selectedFile = max(0, selectedFile)
        this.selectedLine = max(0, selectedLine)
        this.offset = max(0, offset)
        this.block = block
        this.sideBySide = sideBySide
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0 || document.files.size == 0) { return }
        let canvas = Canvas(buffer, target)
        selectedFile = max(0, min(selectedFile, document.files.size - 1))
        let file = document.files[selectedFile]
        var y = target.y
        let summary = "${file.newPath}  +${file.addedLines()} -${file.deletedLines()}"
        canvas.drawText(target.x, y, truncateDiff(summary, target.width), Style(fg: Color.Cyan))
        y++
        var rendered: Int64 = 0
        for (hunk in file.hunks) {
            if (rendered >= offset && y < target.bottom) {
                canvas.drawText(target.x, y, truncateDiff(hunk.header, target.width), Style(fg: Color.Magenta))
                y++
            }
            rendered++
            if (!hunk.collapsed) {
                for (line in hunk.lines) {
                    if (rendered >= offset && y < target.bottom) {
                        // A single visible column uses the unified layout.
                        if (sideBySide && target.width >= 2) {
                            renderSideBySideLine(target, y, line, canvas)
                        } else {
                            let prefix = formatLineNumber(line.oldLine) + " " + formatLineNumber(line.newLine) + " "
                            canvas.drawText(target.x, y, truncateDiff(prefix + line.text, target.width), diffLineStyle(line.kind))
                        }
                        y++
                    }
                    rendered++
                }
            }
        }
    }

    private func renderSideBySideLine(area: Rect, y: Int64, line: DiffLine, canvas: Canvas): Unit {
        let leftWidth = area.width / 2
        let rightWidth = area.width - leftWidth
        let oldText = formatLineNumber(line.oldLine) + " " + stripSign(line.text)
        let newText = formatLineNumber(line.newLine) + " " + stripSign(line.text)
        match (line.kind) {
            case DiffLineKind.Delete =>
                canvas.drawText(area.x, y, truncateDiff(oldText, leftWidth), diffLineStyle(line.kind))
            case DiffLineKind.Add =>
                canvas.drawText(area.x + leftWidth, y, truncateDiff(newText, rightWidth), diffLineStyle(line.kind))
            case _ =>
                canvas.drawText(area.x, y, truncateDiff(oldText, leftWidth), diffLineStyle(line.kind))
                canvas.drawText(area.x + leftWidth, y, truncateDiff(newText, rightWidth), diffLineStyle(line.kind))
        }
    }
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
    if (path.startsWith("a/") || path.startsWith("b/")) { path[2..] } else { path }
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

func diffLineStyle(kind: DiffLineKind): Style {
    match (kind) {
        case DiffLineKind.Add => Style(fg: Color.Green)
        case DiffLineKind.Delete => Style(fg: Color.Red)
        case DiffLineKind.Header => Style(fg: Color.Magenta)
        case DiffLineKind.Context => Style.default()
    }
}

func truncateDiff(text: String, width: Int64): String {
    graphemePrefix(text, max(0, width))
}
