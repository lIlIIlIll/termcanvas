package core

import std.collection.*

public struct TextPosition <: Equatable<TextPosition> {
    public let line: Int64
    public let column: Int64

    public init(line: Int64, column: Int64) {
        this.line = max(0, line)
        this.column = max(0, column)
    }

    public operator func ==(other: TextPosition): Bool {
        line == other.line && column == other.column
    }
}

public struct TextRange {
    public let start: TextPosition
    public let end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        if (compareTextPosition(start, end) <= 0) {
            this.start = start
            this.end = end
        } else {
            this.start = end
            this.end = start
        }
    }

    public func isEmpty(): Bool {
        start == end
    }
}

// Line/column compatibility facade over the same incremental model TextArea uses.
public class TextBuffer {
    private let modelValue: EditableTextModel
    public init(text!: String = "", model!: ?EditableTextModel = None) {
        modelValue = match (model) { case Some(source) => source; case None => PieceTableTextModel(text: text) }
    }
    public prop textModel: EditableTextModel { get() { modelValue } }
    public func setText(text: String): Unit {
        modelValue.replace(0, modelValue.byteLength(), text)
        modelValue.clearHistory()
    }
    public func text(): String { modelValue.text() }
    public func lineCount(): Int64 { modelValue.lineCount() }
    public func line(index: Int64): String {
        if (index < 0 || index >= lineCount()) { "" } else { modelValue.line(index) }
    }
    public func insert(position: TextPosition, text: String): TextPosition {
        let start = positionToOffset(position)
        modelValue.replace(start, start, text)
        offsetToPosition(start + text.size)
    }
    public func replace(range: TextRange, text: String): TextPosition {
        let start = positionToOffset(range.start)
        let end = positionToOffset(range.end)
        modelValue.replace(start, end, text)
        offsetToPosition(min(start, end) + text.size)
    }
    public func deleteRange(range: TextRange): TextPosition { replace(range, "") }
    public func slice(range: TextRange): String {
        modelValue.slice(positionToOffset(range.start), positionToOffset(range.end))
    }
    public func clampPosition(position: TextPosition): TextPosition {
        let index = clamp(position.line, 0, lineCount() - 1)
        let start = modelValue.lineStart(index)
        let end = if (index + 1 < lineCount()) { modelValue.lineStart(index + 1) - 1 } else { modelValue.byteLength() }
        let column = min(position.column, end - start)
        TextPosition(index, modelValue.clampOffset(start + column) - start)
    }
    public func positionToOffset(position: TextPosition): Int64 {
        let pos = clampPosition(position)
        modelValue.lineStart(pos.line) + pos.column
    }
    public func offsetToPosition(offset: Int64): TextPosition {
        let pos = modelValue.clampOffset(offset)
        let index = modelValue.lineForOffset(pos)
        TextPosition(index, pos - modelValue.lineStart(index))
    }
    public func deleteBackward(position: TextPosition): TextPosition {
        let pos = clampPosition(position)
        let offset = positionToOffset(pos)
        if (offset == 0) { return pos }
        let previous = if (pos.column == 0) { offset - 1 } else {
            modelValue.lineStart(pos.line) + previousGraphemeOffset(line(pos.line), pos.column)
        }
        modelValue.replace(previous, offset, "")
        offsetToPosition(previous)
    }
    public func deleteForward(position: TextPosition): TextPosition {
        let pos = clampPosition(position)
        let offset = positionToOffset(pos)
        if (offset >= modelValue.byteLength()) { return pos }
        let current = line(pos.line)
        let next = if (pos.column >= current.size) { offset + 1 } else {
            modelValue.lineStart(pos.line) + nextGraphemeOffset(current, pos.column)
        }
        modelValue.replace(offset, next, "")
        pos
    }
    public func beginUndoGroup(): Unit { modelValue.beginUndoGroup() }
    public func endUndoGroup(): Unit { modelValue.endUndoGroup() }
    public func undo(): Bool { modelValue.undo() }
    public func redo(): Bool { modelValue.redo() }
    public func wordLeft(position: TextPosition): TextPosition {
        offsetToPosition(indexedWordOffset(modelValue, positionToOffset(position), false))
    }
    public func wordRight(position: TextPosition): TextPosition {
        offsetToPosition(indexedWordOffset(modelValue, positionToOffset(position), true))
    }
    public func find(needle: String, start!: TextPosition = TextPosition(0, 0)): ?TextPosition {
        if (needle.isEmpty()) { return None }
        let index = stringIndexOf(text(), needle, positionToOffset(start))
        if (index < 0) { None } else { Some(offsetToPosition(index)) }
    }
    public func findPrevious(needle: String, start!: TextPosition = TextPosition(Int64.Max, Int64.Max)): ?TextPosition {
        if (needle.isEmpty()) { return None }
        let index = stringLastIndexOf(text(), needle, positionToOffset(start))
        if (index < 0) { None } else { Some(offsetToPosition(index)) }
    }
    public func findAll(needle: String): Array<TextRange> {
        if (needle.isEmpty()) { return [] }
        let source = text()
        let ranges = ArrayList<TextRange>()
        var start: Int64 = 0
        while (start <= source.size) {
            let index = stringIndexOf(source, needle, start)
            if (index < 0) { break }
            ranges.add(TextRange(offsetToPosition(index), offsetToPosition(index + needle.size)))
            start = index + needle.size
        }
        ranges.toArray()
    }
    public func replaceAll(needle: String, replacement: String): Int64 {
        if (needle.isEmpty()) { return 0 }
        let source = text()
        let builder = StringBuilder()
        var offset: Int64 = 0
        var count: Int64 = 0
        while (true) {
            let index = stringIndexOf(source, needle, offset)
            if (index < 0) { break }
            builder.append(source[offset..index])
            builder.append(replacement)
            offset = index + needle.size
            count++
        }
        if (count == 0) { return 0 }
        builder.append(source[offset..])
        modelValue.replace(0, modelValue.byteLength(), builder.toString())
        count
    }
}

// Word traversal materializes each visited line once. Walking by repeatedly
// asking the model for the next grapheme would copy a long line per character.
func indexedWordOffset(model: TextModel, offset: Int64, right: Bool): Int64 {
    let position = model.clampOffset(offset)
    var lineIndex = model.lineForOffset(position)
    var local = position - model.lineStart(lineIndex)
    var skippingSpace = false
    if (right) {
        while (lineIndex < model.lineCount()) {
            let start = model.lineStart(lineIndex)
            for (cluster in graphemeClusters(model.line(lineIndex))) {
                if (cluster.endOffset <= local) { continue }
                let space = isAsciiSpace(runeAt(cluster.text, 0))
                if (skippingSpace && !space) { return start + cluster.startOffset }
                if (space) { skippingSpace = true }
            }
            // The line separator is whitespace even for an empty line.
            skippingSpace = true
            lineIndex++
            local = 0
        }
        return model.byteLength()
    }
    var foundWord = false
    var result = position
    while (lineIndex >= 0) {
        let start = model.lineStart(lineIndex)
        let clusters = graphemeClusters(model.line(lineIndex))
        var index = clusters.size - 1
        while (index >= 0) {
            let cluster = clusters[index]
            index--
            if (cluster.startOffset >= local) { continue }
            let space = isAsciiSpace(runeAt(cluster.text, 0))
            if (space && foundWord) { return result }
            if (!space) { foundWord = true; result = start + cluster.startOffset }
        }
        if (foundWord) { return result }
        lineIndex--
        local = Int64.Max
    }
    0
}

func compareTextPosition(a: TextPosition, b: TextPosition): Int64 {
    if (a.line < b.line) { return -1 }
    if (a.line > b.line) { return 1 }
    if (a.column < b.column) { return -1 }
    if (a.column > b.column) { return 1 }
    0
}

func stringIndexOf(text: String, needle: String, start: Int64): Int64 {
    let hay = unsafe { text.rawData() }
    let ned = unsafe { needle.rawData() }
    if (ned.size == 0) { return start }
    var i = clamp(start, 0, text.size)
    while (i + ned.size <= hay.size) {
        var ok = true
        for (j in 0..ned.size) {
            if (hay[i + j] != ned[j]) { ok = false }
        }
        if (ok) { return i }
        i++
    }
    -1
}

func stringLastIndexOf(text: String, needle: String, end: Int64): Int64 {
    let hay = unsafe { text.rawData() }
    let ned = unsafe { needle.rawData() }
    if (ned.size == 0) { return end }
    var i = min(clamp(end, 0, text.size), text.size - ned.size)
    while (i >= 0) {
        var ok = true
        for (j in 0..ned.size) {
            if (hay[i + j] != ned[j]) { ok = false }
        }
        if (ok) { return i }
        i--
    }
    -1
}

func previousWordOffset(text: String, offset: Int64): Int64 {
    var pos = previousRuneOffset(text, offset)
    while (pos > 0 && isAsciiSpace(runeAt(text, pos))) {
        pos = previousRuneOffset(text, pos)
    }
    while (pos > 0) {
        let prev = previousRuneOffset(text, pos)
        if (isAsciiSpace(runeAt(text, prev))) { return pos }
        pos = prev
    }
    0
}

func nextWordOffset(text: String, offset: Int64): Int64 {
    var pos = clampToRuneBoundary(text, offset)
    while (pos < text.size && !isAsciiSpace(runeAt(text, pos))) {
        pos = nextRuneOffset(text, pos)
    }
    while (pos < text.size && isAsciiSpace(runeAt(text, pos))) {
        pos = nextRuneOffset(text, pos)
    }
    pos
}

func runeAt(text: String, offset: Int64): Rune {
    if (text.isEmpty()) { return r'\0' }
    let target = clampToRuneBoundary(text, offset)
    let bytes = unsafe { text.rawData() }
    let (r, _) = Rune.fromUtf8(bytes, target)
    r
}

func isAsciiSpace(r: Rune): Bool {
    r == r' ' || r == r'\t' || r == r'\n' || r == r'\r'
}
