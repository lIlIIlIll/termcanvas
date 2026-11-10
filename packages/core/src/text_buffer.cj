package core

import std.collection.*

/** 文本中的零起始行号与行内 UTF-8 字节列。 */
public struct TextPosition <: Equatable<TextPosition> {
    /** 零起始行号。 */
    public let line: Int64
    /** 行内 UTF-8 字节偏移。 */
    public let column: Int64

    /** 创建位置；负行号或列号按零处理。
     * @param line 零起始行号
     * @param column 行内 UTF-8 字节列
     */
    public init(line: Int64, column: Int64) {
        this.line = max(0, line)
        this.column = max(0, column)
    }

    /** 比较行号与字节列。
     * @param other 待比较位置
     * @return 行和列均相同时为 true
     */
    public operator func ==(other: TextPosition): Bool {
        line == other.line && column == other.column
    }
}

/** 两个文本位置之间的范围，构造时按位置顺序排列端点。 */
public struct TextRange {
    /** 范围起点。 */
    public let start: TextPosition
    /** 范围终点，不包含该位置。 */
    public let end: TextPosition

    /** 创建范围，必要时交换端点。
     * @param start 一个端点
     * @param end 另一个端点
     */
    public init(start: TextPosition, end: TextPosition) {
        if (compareTextPosition(start, end) <= 0) {
            this.start = start
            this.end = end
        } else {
            this.start = end
            this.end = start
        }
    }

    /** 检查起点和终点是否相同。
     * @return 范围为空时为 true
     */
    public func isEmpty(): Bool {
        start == end
    }
}

// Line/column compatibility facade over the same incremental model TextArea uses.
/** 按行和 UTF-8 字节列操作可编辑文本模型的接口。 */
public class TextBuffer {
    private let modelValue: EditableTextModel
    /** 创建缓冲区；提供模型时使用该模型，否则以文本创建新模型。
     * @param text 新模型的初始文本
     * @param model 可选的现有编辑模型
     */
    public init(text!: String = "", model!: ?EditableTextModel = None) {
        modelValue = match (model) { case Some(source) => source; case None => PieceTableTextModel(text: text) }
    }
    /** 缓冲区使用的底层可编辑模型。 */
    public prop textModel: EditableTextModel { get() { modelValue } }
    /** 替换全部文本并清除撤销历史。
     * @param text 新文本
     */
    public func setText(text: String): Unit {
        modelValue.replace(0, modelValue.byteLength(), text)
        modelValue.clearHistory()
    }
    /** 获取完整文本。
     * @return 当前文本
     */
    public func text(): String { modelValue.text() }
    /** 获取文本行数。
     * @return 当前行数
     */
    public func lineCount(): Int64 { modelValue.lineCount() }
    /** 获取一行文本。
     * @param index 零起始行号
     * @return 该行文本；行号越界时为空字符串
     */
    public func line(index: Int64): String {
        if (index < 0 || index >= lineCount()) { "" } else { modelValue.line(index) }
    }
    /** 在有效化后的位置插入文本。
     * @param position 插入位置
     * @param text 要插入的文本
     * @return 插入内容之后的位置
     */
    public func insert(position: TextPosition, text: String): TextPosition {
        let start = positionToOffset(position)
        modelValue.replace(start, start, text)
        offsetToPosition(start + text.size)
    }
    /** 替换范围内的文本。
     * @param range 要替换的半开范围
     * @param text 替换文本
     * @return 替换文本之后的位置
     */
    public func replace(range: TextRange, text: String): TextPosition {
        let start = positionToOffset(range.start)
        let end = positionToOffset(range.end)
        modelValue.replace(start, end, text)
        offsetToPosition(min(start, end) + text.size)
    }
    /** 删除范围内的文本。
     * @param range 要删除的半开范围
     * @return 删除后的位置
     */
    public func deleteRange(range: TextRange): TextPosition { replace(range, "") }
    /** 读取范围内的文本。
     * @param range 要读取的半开范围
     * @return 范围内的文本
     */
    public func slice(range: TextRange): String {
        modelValue.slice(positionToOffset(range.start), positionToOffset(range.end))
    }
    /** 将位置限制到有效行、行内范围及模型字符边界。
     * @param position 原位置
     * @return 有效位置
     */
    public func clampPosition(position: TextPosition): TextPosition {
        let index = clamp(position.line, 0, lineCount() - 1)
        let start = modelValue.lineStart(index)
        let end = if (index + 1 < lineCount()) { modelValue.lineStart(index + 1) - 1 } else { modelValue.byteLength() }
        let column = min(position.column, end - start)
        TextPosition(index, modelValue.clampOffset(start + column) - start)
    }
    /** 将行列位置转换为全文 UTF-8 字节偏移。
     * @param position 行和字节列
     * @return 有效化后的全文字节偏移
     */
    public func positionToOffset(position: TextPosition): Int64 {
        let pos = clampPosition(position)
        modelValue.lineStart(pos.line) + pos.column
    }
    /** 将全文 UTF-8 字节偏移转换为行列位置。
     * @param offset 全文字节偏移
     * @return 有效化后的行和字节列
     */
    public func offsetToPosition(offset: Int64): TextPosition {
        let pos = modelValue.clampOffset(offset)
        let index = modelValue.lineForOffset(pos)
        TextPosition(index, pos - modelValue.lineStart(index))
    }
    /** 删除位置之前的一个字素簇；在行首删除前面的换行。
     * @param position 删除位置
     * @return 删除后的位置
     */
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
    /** 删除位置之后的一个字素簇；在行尾删除后面的换行。
     * @param position 删除位置
     * @return 删除后的位置
     */
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
    /** 开始一个底层模型撤销分组。 */
    public func beginUndoGroup(): Unit { modelValue.beginUndoGroup() }
    /** 结束一个底层模型撤销分组。 */
    public func endUndoGroup(): Unit { modelValue.endUndoGroup() }
    /** 撤销一次编辑或一个编辑组。
     * @return 撤销成功时为 true
     */
    public func undo(): Bool { modelValue.undo() }
    /** 重做已撤销的编辑或编辑组。
     * @return 重做成功时为 true
     */
    public func redo(): Bool { modelValue.redo() }
    /** 向左移动到单词起点；以空格、制表符、回车和换行分隔单词。
     * @param position 起始位置
     * @return 目标位置
     */
    public func wordLeft(position: TextPosition): TextPosition {
        offsetToPosition(indexedWordOffset(modelValue, positionToOffset(position), false))
    }
    /** 向右移动到下一个单词起点；以空格、制表符、回车和换行分隔单词。
     * @param position 起始位置
     * @return 目标位置
     */
    public func wordRight(position: TextPosition): TextPosition {
        offsetToPosition(indexedWordOffset(modelValue, positionToOffset(position), true))
    }
    /** 从指定位置向后查找文本；空查找串不匹配。
     * @param needle 要查找的文本
     * @param start 查找起点
     * @return 找到时返回起始位置，否则返回 None
     */
    public func find(needle: String, start!: TextPosition = TextPosition(0, 0)): ?TextPosition {
        if (needle.isEmpty()) { return None }
        let index = stringIndexOf(text(), needle, positionToOffset(start))
        if (index < 0) { None } else { Some(offsetToPosition(index)) }
    }
    /** 从指定位置向前查找文本；空查找串不匹配。
     * @param needle 要查找的文本
     * @param start 查找起点
     * @return 找到时返回起始位置，否则返回 None
     */
    public func findPrevious(needle: String, start!: TextPosition = TextPosition(Int64.Max, Int64.Max)): ?TextPosition {
        if (needle.isEmpty()) { return None }
        let index = stringLastIndexOf(text(), needle, positionToOffset(start))
        if (index < 0) { None } else { Some(offsetToPosition(index)) }
    }
    /** 查找所有不重叠匹配；空查找串返回空数组。
     * @param needle 要查找的文本
     * @return 按顺序排列的匹配范围
     */
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
    /** 替换所有不重叠匹配；空查找串不会修改文本。
     * @param needle 要查找的文本
     * @param replacement 替换文本
     * @return 替换次数
     */
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
