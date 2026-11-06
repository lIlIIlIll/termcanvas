package showcase_editor

import core.*
import diff.*
import std.collection.*

let SAMPLE = "package pipeline\n\n// Summarize one simulated build step.\nstruct Step {\n    let name: String\n    let completed: Int64\n    let total: Int64\n}\n\nfunc progress(step: Step): Int64 {\n    if (step.total == 0) { return 0 }\n    step.completed * 100 / step.total\n}\n\nfunc describe(step: Step): String {\n    let percent = progress(step)\n    if (percent >= 100) {\n        return step.name + \": done\"\n    }\n    step.name + \": running (\" + percent.toString() + \"%)\"\n}\n"
let EDITOR_THEME = Theme.indigo()
let EDITOR_BLOCK = Block(BlockOptions(title: " Source / EDITING ", theme: EDITOR_THEME, state: BoxState.Focused))

// Keep terminators so a missing final newline remains a visible change.
func sourceLines(text: String): Array<String> {
    let lines = ArrayList<String>()
    var start: Int64 = 0
    for (i in 0..text.size) {
        if (text[i] == b'\n') {
            lines.add(text[start..i + 1])
            start = i + 1
        }
    }
    if (start < text.size) { lines.add(text[start..]) }
    lines.toArray()
}

func displayLine(line: String): String {
    if (line.endsWith("\n")) { line[..line.size - 1] } else { line + " [no newline]" }
}

class LineMatch {
    let oldIndex: Int64
    let newIndex: Int64
    init(oldIndex: Int64, newIndex: Int64) {
        this.oldIndex = oldIndex
        this.newIndex = newIndex
    }
}

// Hirschberg's LCS split uses two rows, not a full old-by-new table. The
// showcase baseline is fixed and small, so even pasted text only adds linear
// work and storage with respect to the edited document.
func lcsSplit(oldLines: Array<String>, newLines: Array<String>, oldStart: Int64, oldMid: Int64, oldEnd: Int64, newStart: Int64, newEnd: Int64): Int64 {
    let count = newEnd - newStart
    let left = Array<Int64>(count + 1, repeat: 0)
    let right = Array<Int64>(count + 1, repeat: 0)
    for (i in oldStart..oldMid) {
        var diagonal: Int64 = 0
        for (j in 1..count + 1) {
            let previous = left[j]
            left[j] = if (oldLines[i] == newLines[newStart + j - 1]) { diagonal + 1 } else { max(left[j], left[j - 1]) }
            diagonal = previous
        }
    }
    var i = oldEnd
    while (i > oldMid) {
        i--
        var diagonal: Int64 = 0
        var j = count
        while (j > 0) {
            j--
            let previous = right[j]
            right[j] = if (oldLines[i] == newLines[newStart + j]) { diagonal + 1 } else { max(right[j], right[j + 1]) }
            diagonal = previous
        }
    }
    var best: Int64 = -1
    var split: Int64 = 0
    for (j in 0..count + 1) {
        let score = left[j] + right[j]
        if (score > best) { best = score; split = j }
    }
    newStart + split
}

func collectMatches(oldLines: Array<String>, newLines: Array<String>, oldStart: Int64, oldEnd: Int64,
    newStart: Int64, newEnd: Int64, matches: ArrayList<LineMatch>): Unit {
    if (oldStart >= oldEnd || newStart >= newEnd) { return }
    if (oldEnd - oldStart == 1) {
        for (j in newStart..newEnd) {
            if (oldLines[oldStart] == newLines[j]) { matches.add(LineMatch(oldStart, j)); break }
        }
        return
    }
    let oldMid = oldStart + (oldEnd - oldStart) / 2
    let newMid = lcsSplit(oldLines, newLines, oldStart, oldMid, oldEnd, newStart, newEnd)
    collectMatches(oldLines, newLines, oldStart, oldMid, newStart, newMid, matches)
    collectMatches(oldLines, newLines, oldMid, oldEnd, newMid, newEnd, matches)
}

// Preserve all matches in a longest common subsequence, including repeated
// lines and changes in disjoint parts of the document.
func documentDiff(original: String, edited: String): DiffDocument {
    let oldLines = sourceLines(original)
    let newLines = sourceLines(edited)
    let matches = ArrayList<LineMatch>()
    collectMatches(oldLines, newLines, 0, oldLines.size, 0, newLines.size, matches)
    let lines = ArrayList<DiffLine>()
    var oldPos: Int64 = 0
    var newPos: Int64 = 0
    for (item in matches) {
        for (i in oldPos..item.oldIndex) {
            lines.add(DiffLine(DiffLineKind.Delete, "-" + displayLine(oldLines[i]), oldLine: Some(i + 1)))
        }
        for (i in newPos..item.newIndex) {
            lines.add(DiffLine(DiffLineKind.Add, "+" + displayLine(newLines[i]), newLine: Some(i + 1)))
        }
        lines.add(DiffLine(DiffLineKind.Context, " " + displayLine(oldLines[item.oldIndex]), oldLine: Some(item.oldIndex + 1), newLine: Some(item.newIndex + 1)))
        oldPos = item.oldIndex + 1
        newPos = item.newIndex + 1
    }
    for (i in oldPos..oldLines.size) {
        lines.add(DiffLine(DiffLineKind.Delete, "-" + displayLine(oldLines[i]), oldLine: Some(i + 1)))
    }
    for (i in newPos..newLines.size) {
        lines.add(DiffLine(DiffLineKind.Add, "+" + displayLine(newLines[i]), newLine: Some(i + 1)))
    }
    let oldStart = if (oldLines.isEmpty()) { 0 } else { 1 }
    let newStart = if (newLines.isEmpty()) { 0 } else { 1 }
    let header = "@@ -${oldStart},${oldLines.size} +${newStart},${newLines.size} @@"
    DiffDocument([DiffFile("sample.cj", "sample.cj", hunks: [DiffHunk(header, lines: lines.toArray())])])
}

// The side preview deliberately omits unchanged lines; F2 opens the complete
// context. This ensures changes below the first screen are still visible.
func changedLines(document: DiffDocument): DiffDocument {
    let lines = ArrayList<DiffLine>()
    for (line in document.files[0].hunks[0].lines) {
        match (line.kind) {
            case DiffLineKind.Add | DiffLineKind.Delete => lines.add(line)
            case _ => ()
        }
    }
    DiffDocument([DiffFile("sample.cj", "sample.cj", hunks: [DiffHunk("Changed lines", lines: lines.toArray())])])
}

class EditorShowcase {
    let editor = TextArea(value: SAMPLE, lineNumbers: true, style: EDITOR_THEME.surface, block: EDITOR_BLOCK)
    var showingDiff = false
    var offset: Int64 = 0
    var diff = documentDiff(SAMPLE, SAMPLE)
    var preview = changedLines(diff)
    var diffRevision: Int64 = -1
    var textChanged = false
    var editorArea = Rect(0, 0, 0, 0)
    var diffViewport: Int64 = 1

    func refreshDiff(): Unit {
        let revision = editor.editRevision()
        if (diffRevision == revision) { return }
        let value = editor.value
        diff = documentDiff(SAMPLE, value)
        preview = changedLines(diff)
        textChanged = value != SAMPLE
        diffRevision = revision
    }

    // DiffView keeps the file summary fixed and scrolls the hunk header and lines.
    func lastDiffOffset(): Int64 {
        max(0, 1 + diff.files[0].hunks[0].lines.size - max(1, diffViewport - 1))
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => handleKey(key)
            case Event.KeyRepeat(key) => match (key.code) {
                case KeyCode.F(2) => UpdateResult.unchanged()
                case _ => handleKey(key)
            }
            case Event.Paste(text) =>
                if (!showingDiff) { editor.paste(text) }
                UpdateResult.next()
            case Event.Mouse(mouse) =>
                if (!showingDiff) { _ = editor.handleMouse(mouse, editorArea) }
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    func handleKey(key: KeyEvent): UpdateResult {
        match (key.code) {
            case KeyCode.CtrlC => return UpdateResult.exit()
            case KeyCode.F(2) =>
                showingDiff = !showingDiff
                if (showingDiff) { refreshDiff(); offset = 0 }
                return UpdateResult.next()
            case _ => ()
        }
        if (showingDiff) {
            let last = lastDiffOffset()
            match (key.code) {
                case KeyCode.Up => offset = max(0, offset - 1)
                case KeyCode.Down => offset = min(last, offset + 1)
                case KeyCode.PageUp => offset = max(0, offset - 10)
                case KeyCode.PageDown => offset = min(last, offset + 10)
                case KeyCode.Home => offset = 0
                case KeyCode.End => offset = last
                case _ => ()
            }
        } else {
            _ = editor.handle(key)
        }
        UpdateResult.next()
    }

    func render(frame: Frame): Unit {
        let area = frame.area
        frame.fill(area, EDITOR_THEME.canvas)
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Length(1), Constraint.Min(1), Constraint.Length(1), Constraint.Length(1)]).withMargin(Spacing.all(1)).split(area)
        frame.renderWidget(Paragraph("TERMCANVAS  /  EDITOR    sample.cj", style: EDITOR_THEME.accent), rows[0])
        refreshDiff()
        let changed = if (textChanged) { "modified" } else { "unchanged" }
        let currentDiff = diff
        let line = editor.textModel.lineForOffset(editor.cursor)
        let col = graphemeClusters(editor.textModel.slice(editor.textModel.lineStart(line), editor.cursor)).size + 1
        let totalLines = editor.textModel.lineCount()
        if (showingDiff) {
            diffViewport = max(0, rows[2].height - 2)
            offset = min(offset, lastDiffOffset())
            frame.renderWidget(DiffView(diff, offset: offset, theme: EDITOR_THEME, block: Block(BlockOptions(title: " Changes against initial sample / VIEWING ", theme: EDITOR_THEME, state: BoxState.Focused))), rows[2])
        } else {
            editorArea = rows[2]
            if (rows[2].width >= 100) {
                let columns = Layout.horizontal([Constraint.Percent(68), Constraint.Min(25)]).withGap(1).split(rows[2])
                editorArea = columns[0]
                let previewBlock = Block(BlockOptions(title: " Change preview ", theme: EDITOR_THEME))
                let changedCount = currentDiff.addedLines() + currentDiff.deletedLines()
                let previewHeight = if (changedCount == 0) { 11 } else { min(14, max(6, changedCount + 4)) }
                let previewArea = Rect(columns[1].x, columns[1].y, columns[1].width, min(columns[1].height, previewHeight))
                if (currentDiff.addedLines() == 0 && currentDiff.deletedLines() == 0) {
                    frame.renderWidget(Paragraph("No changes yet.\n\nEdit the sample to compare it\nwith the initial text.\n\nF2 opens the full diff.\n\nAll edits are in memory.\nNothing is saved to disk.",
                        block: previewBlock, style: EDITOR_THEME.secondary, wrap: WrapMode.Word), previewArea)
                } else {
                    frame.renderWidget(DiffView(preview, theme: EDITOR_THEME, block: previewBlock), previewArea)
                }
            }
            frame.renderWidget(editor, editorArea)
            frame.setCursor(editor.cursorPosition(editorArea, options: frame.textWidthOptions()))
        }
        // TextArea updates its scroll during render, so derive the range only
        // after rendering, from the same block's actual inner height.
        let height = EDITOR_BLOCK.inner(editorArea).height
        let first = min(totalLines, editor.scroll + 1)
        let last = min(totalLines, editor.scroll + max(0, height))
        let range = if (height > 0) { "${first}-${last}/${totalLines}" } else { "0/${totalLines}" }
        let summary = "${changed}  Ln ${line + 1}:${col}  Lines ${range}  +${currentDiff.addedLines()} -${currentDiff.deletedLines()}"
        frame.renderWidget(Paragraph("${summary}  |  Memory only; resets on exit", style: EDITOR_THEME.secondary), rows[1])
        let help = if (showingDiff) { "F2  back to edit     ↑/↓  scroll     PgUp/PgDn  page" } else { "F2  view changes     Type to edit     Ctrl-Z / Ctrl-Y  undo / redo" }
        frame.renderWidget(Paragraph(help, style: EDITOR_THEME.secondary), rows[3])
        frame.renderWidget(Paragraph("Ctrl-C  quit without saving", style: EDITOR_THEME.accent), rows[4])
    }
}

main(): Int64 {
    let app = EditorShowcase()
    App(hideCursor: false, mouse: true).runWithCommands({ frame => app.render(frame) }, { event => app.update(event) })
    0
}
