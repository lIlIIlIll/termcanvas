package core

import std.collection.*

// Text offsets and line starts are UTF-8 byte offsets. LF separates lines;
// a trailing LF adds an empty line. Edits clamp backward to rune boundaries.
// slice/replace normalize reversed ranges. line returns "" for invalid rows;
// lineStart clamps negative rows to 0 and rows past the last to byteLength.
// revision changes on an effective edit or history traversal, not a no-op.
/** 按 UTF-8 字节偏移访问文本的模型。LF 分隔行，末尾 LF 后包含空行；编辑和切片的端点会回退到字符边界。 */
public interface TextModel {
    /** 返回 UTF-8 字节长度。
     * @return 文本字节数
     */
    func byteLength(): Int64
    /** 返回行数；空文本也有一行。
     * @return 行数
     */
    func lineCount(): Int64
    /** 读取不含行分隔符的一行；越界时返回空字符串。
     * @param index 零起始行号
     * @return 行文本
     */
    func line(index: Int64): String
    /** 获取一行的起始字节偏移；行号越界时限制到文本两端。
     * @param index 零起始行号
     * @return 全文 UTF-8 字节偏移
     */
    func lineStart(index: Int64): Int64
    /** 获取给定全文字节偏移所在行。
     * @param offset 全文 UTF-8 字节偏移
     * @return 零起始行号
     */
    func lineForOffset(offset: Int64): Int64
    /** 读取两个字节偏移之间的文本；反向端点会交换。
     * @param start 一个 UTF-8 字节端点
     * @param end 另一个 UTF-8 字节端点
     * @return 半开范围内的文本
     */
    func slice(start: Int64, end: Int64): String
    /** 替换两个字节偏移之间的文本；反向端点会交换。
     * @param start 一个 UTF-8 字节端点
     * @param end 另一个 UTF-8 字节端点
     * @param text 替换文本
     */
    func replace(start: Int64, end: Int64, text: String): Unit
    /** 获取完整文本。
     * @return 当前文本
     */
    func text(): String
    /** 获取当前修订号；有效编辑或历史操作会改变修订号。
     * @return 当前修订号
     */
    func revision(): Int64
    // Instrumentation is optional for application-supplied text models.
    /** 返回工作计数快照；默认实现返回零值。
     * @return 模型计数器
     */
    func metrics(): TextModelMetrics { TextModelMetrics() }
    // Override this fallback to keep boundary checks local for large models.
    /** 将字节偏移限制在文本范围内并回退到字符边界。
     * @param offset 全文 UTF-8 字节偏移
     * @return 有效字节偏移
     */
    func clampOffset(offset: Int64): Int64 { clampToRuneBoundary(text(), offset) }
}

/** 支持分组撤销、重做和清除历史的文本模型。 */
public interface EditableTextModel <: TextModel {
    // Nested groups commit at the outermost end. undo/redo seal an open group.
    /** 开始撤销分组；可嵌套。 */
    func beginUndoGroup(): Unit
    /** 结束一层撤销分组；最外层结束时提交分组。 */
    func endUndoGroup(): Unit
    /** 撤销最近编辑或分组，并结束打开的分组。
     * @return 撤销成功时为 true
     */
    func undo(): Bool
    /** 重做最近撤销的编辑或分组，并结束打开的分组。
     * @return 重做成功时为 true
     */
    func redo(): Bool
    /** 清除撤销和重做历史。 */
    func clearHistory(): Unit
}

// Deterministic work counters: take two snapshots to inspect a local operation.
// Counters are cumulative, except pieceCount/treeHeight (current-tree gauges).
// bytesScanned counts input indexing and byte comparisons; bytesCopied counts
// bytes emitted into requested output, not allocator-internal copies or
// retained immutable source views.
/** 文本模型的工作计数快照；除片段数和树高外，其余字段为累计值。 */
public struct TextModelMetrics {
    /** 访问的树节点次数。 */
    public let nodeVisits: Int64
    /** 建立索引和比较时扫描的字节数。 */
    public let bytesScanned: Int64
    /** 输出结果时复制的字节数，不含分配器内部复制。 */
    public let bytesCopied: Int64
    /** 请求完整文本的次数。 */
    public let materializations: Int64
    /** 当前文本树的片段数量。 */
    public let pieceCount: Int64
    /** 当前文本树的高度。 */
    public let treeHeight: Int64

    /** 创建计数快照。
     * @param nodeVisits 访问节点次数
     * @param bytesScanned 扫描字节数
     * @param bytesCopied 输出复制字节数
     * @param materializations 完整文本请求次数
     * @param pieceCount 当前片段数
     * @param treeHeight 当前树高
     */
    public init(nodeVisits!: Int64 = 0, bytesScanned!: Int64 = 0, bytesCopied!: Int64 = 0,
        materializations!: Int64 = 0, pieceCount!: Int64 = 0, treeHeight!: Int64 = 0) {
        this.nodeVisits = nodeVisits
        this.bytesScanned = bytesScanned
        this.bytesCopied = bytesCopied
        this.materializations = materializations
        this.pieceCount = pieceCount
        this.treeHeight = treeHeight
    }
}

// Immutable storage is indexed once. Piece splits retain this storage and
// binary-search its LF positions, including when the original is one huge
// piece. They never rescan or copy the original text.
class PieceTextSource {
    let value: String
    let newlines: Array<Int64>

    init(value: String) {
        this.value = value
        let offsets = ArrayList<Int64>()
        let bytes = unsafe { value.rawData() }
        for (offset in 0..bytes.size) {
            if (bytes[offset] == 10u8) { offsets.add(offset) }
        }
        newlines = offsets.toArray()
    }

    func newlineIndex(offset: Int64): Int64 {
        var lower: Int64 = 0
        var upper = newlines.size
        while (lower < upper) {
            let middle = lower + (upper - lower) / 2
            if (newlines[middle] < offset) { lower = middle + 1 } else { upper = middle }
        }
        lower
    }
}

struct PieceTextSpan {
    let source: PieceTextSource
    let start: Int64
    let end: Int64
    let firstNewline: Int64
    let afterNewline: Int64

    init(source: PieceTextSource, start: Int64, end: Int64) {
        this.source = source
        this.start = start
        this.end = end
        firstNewline = source.newlineIndex(start)
        afterNewline = source.newlineIndex(end)
    }
}

// Every internal node has exactly two nonempty children. Nodes and spans
// never mutate: undo/redo retain a root, sharing untouched subtrees.
class PieceTextNode {
    let span: ?PieceTextSpan
    let left: ?PieceTextNode
    let right: ?PieceTextNode
    let bytes: Int64
    let lineBreaks: Int64
    let pieces: Int64
    let height: Int64

    init(span: PieceTextSpan) {
        this.span = Some(span)
        left = None
        right = None
        bytes = span.end - span.start
        lineBreaks = span.afterNewline - span.firstNewline
        pieces = 1
        height = 1
    }

    init(left: PieceTextNode, right: PieceTextNode) {
        span = None
        this.left = Some(left)
        this.right = Some(right)
        bytes = left.bytes + right.bytes
        lineBreaks = left.lineBreaks + right.lineBreaks
        pieces = left.pieces + right.pieces
        height = 1 + max(left.height, right.height)
    }
}

// A persistent AVL piece rope. Loading/indexing costs O(N); editing k bytes
// costs O(k + log P + log L) with P pieces and L newlines in a source. Line
// lookup traverses O(log P) nodes; a partial piece prefix uses O(log L).
// Producing text/slices costs the requested output plus visited pieces.
// Histories retain roots and O(log P) new path nodes per edit, not whole-text
// snapshots. Source storage stays alive while any current/history piece uses
// it; clearHistory releases history roots (it does not compact live sources).
/** 基于持久片段树的可编辑文本模型，支持增量编辑和历史记录。 */
public class PieceTableTextModel <: EditableTextModel {
    private var root: ?PieceTextNode = None
    private let undoRoots = ArrayList<?PieceTextNode>()
    private let redoRoots = ArrayList<?PieceTextNode>()
    private var groupDepth: Int64 = 0
    private var groupRoot: ?PieceTextNode = None
    private var groupChanged: Bool = false
    private var generation: Int64 = 0
    private var visited: Int64 = 0
    private var scanned: Int64 = 0
    private var copied: Int64 = 0
    private var flattened: Int64 = 0

    /** 以给定文本创建模型。
     * @param text 初始文本
     */
    public init(text!: String = "") {
        if (!text.isEmpty()) {
            let source = PieceTextSource(text)
            root = Some(PieceTextNode(PieceTextSpan(source, 0, text.size)))
            scanned = text.size
        }
    }

    /** 返回 UTF-8 字节长度。
     * @return 文本字节数
     */
    public func byteLength(): Int64 {
        match (root) { case Some(node) => node.bytes; case None => 0 }
    }

    /** 返回行数；空文本也有一行。
     * @return 行数
     */
    public func lineCount(): Int64 {
        match (root) { case Some(node) => node.lineBreaks + 1; case None => 1 }
    }

    /** 读取不含行分隔符的一行；越界时返回空字符串。
     * @param index 零起始行号
     * @return 行文本
     */
    public func line(index: Int64): String {
        if (index < 0 || index >= lineCount()) { return "" }
        let start = lineStart(index)
        let end = if (index + 1 < lineCount()) { lineStart(index + 1) - 1 } else { byteLength() }
        rangeText(start, end)
    }

    /** 获取一行的起始字节偏移；行号越界时限制到文本两端。
     * @param index 零起始行号
     * @return 全文 UTF-8 字节偏移
     */
    public func lineStart(index: Int64): Int64 {
        if (index <= 0) { return 0 }
        if (index >= lineCount()) { return byteLength() }
        newlineOffset(root.getOrThrow(), index - 1) + 1
    }

    /** 获取给定全文字节偏移所在行。
     * @param offset 全文 UTF-8 字节偏移
     * @return 零起始行号
     */
    public func lineForOffset(offset: Int64): Int64 {
        let position = clamp(offset, 0, byteLength())
        match (root) {
            case Some(node) => prefixLineBreaks(node, position)
            case None => 0
        }
    }

    /** 将字节偏移限制在文本范围内并回退到字符边界。
     * @param offset 全文 UTF-8 字节偏移
     * @return 有效字节偏移
     */
    public func clampOffset(offset: Int64): Int64 {
        var position = clamp(offset, 0, byteLength())
        if (position == byteLength()) { return position }
        while (position > 0) {
            let byte = byteAt(root.getOrThrow(), position)
            scanned++
            if ((byte & 0xC0u8) != 0x80u8) { break }
            position--
        }
        position
    }

    /** 读取两个字节偏移之间的文本；反向端点会交换。
     * @param start 一个 UTF-8 字节端点
     * @param end 另一个 UTF-8 字节端点
     * @return 半开范围内的文本
     */
    public func slice(start: Int64, end: Int64): String {
        let first = clampOffset(min(start, end))
        let last = clampOffset(max(start, end))
        rangeText(first, last)
    }

    /** 替换两个字节偏移之间的文本；反向端点会交换。
     * @param start 一个 UTF-8 字节端点
     * @param end 另一个 UTF-8 字节端点
     * @param text 替换文本
     */
    public func replace(start: Int64, end: Int64, text: String): Unit {
        let first = clampOffset(min(start, end))
        let last = clampOffset(max(start, end))
        if (last - first == text.size) {
            if (text.isEmpty()) { return }
            if (matches(root.getOrThrow(), first, last, text, 0)) { return }
        }
        let before = root
        let (left, tail) = split(root, first)
        let (_, right) = split(tail, last - first)
        var inserted: ?PieceTextNode = None
        if (!text.isEmpty()) {
            let source = PieceTextSource(text)
            scanned += text.size
            inserted = Some(PieceTextNode(PieceTextSpan(source, 0, text.size)))
        }
        root = concatenate(concatenate(left, inserted), right)
        if (groupDepth == 0) { undoRoots.add(before) } else { groupChanged = true }
        redoRoots.clear()
        generation++
    }

    /** 获取完整文本。
     * @return 当前文本
     */
    public func text(): String {
        flattened++
        rangeText(0, byteLength())
    }

    /** 获取当前修订号；有效编辑或历史操作会改变修订号。
     * @return 当前修订号
     */
    public func revision(): Int64 { generation }

    /** 返回当前模型工作计数和树状态快照。
     * @return 模型计数器
     */
    public func metrics(): TextModelMetrics {
        let (pieces, height) = match (root) {
            case Some(node) => (node.pieces, node.height)
            case None => (0, 0)
        }
        TextModelMetrics(nodeVisits: visited, bytesScanned: scanned, bytesCopied: copied,
            materializations: flattened, pieceCount: pieces, treeHeight: height)
    }

    /** 开始撤销分组；可嵌套。 */
    public func beginUndoGroup(): Unit {
        if (groupDepth == 0) {
            groupRoot = root
            groupChanged = false
        }
        groupDepth++
    }

    /** 结束一层撤销分组；最外层结束时提交分组。 */
    public func endUndoGroup(): Unit {
        if (groupDepth == 0) { return }
        groupDepth--
        if (groupDepth == 0) { sealGroup() }
    }

    /** 撤销最近编辑或分组，并结束打开的分组。
     * @return 撤销成功时为 true
     */
    public func undo(): Bool {
        sealGroup()
        if (undoRoots.isEmpty()) { return false }
        redoRoots.add(root)
        root = undoRoots.remove(at: undoRoots.size - 1)
        generation++
        true
    }

    /** 重做最近撤销的编辑或分组，并结束打开的分组。
     * @return 重做成功时为 true
     */
    public func redo(): Bool {
        sealGroup()
        if (redoRoots.isEmpty()) { return false }
        undoRoots.add(root)
        root = redoRoots.remove(at: redoRoots.size - 1)
        generation++
        true
    }

    /** 清除撤销和重做历史。 */
    public func clearHistory(): Unit {
        undoRoots.clear()
        redoRoots.clear()
        groupDepth = 0
        groupRoot = None
        groupChanged = false
    }

    private func sealGroup(): Unit {
        if (groupChanged) { undoRoots.add(groupRoot) }
        groupDepth = 0
        groupRoot = None
        groupChanged = false
    }

    private func byteAt(node: PieceTextNode, offset: Int64): UInt8 {
        visited++
        match (node.span) {
            case Some(span) =>
                let bytes = unsafe { span.source.value.rawData() }
                bytes[span.start + offset]
            case None =>
                let left = node.left.getOrThrow()
                if (offset < left.bytes) { byteAt(left, offset) }
                else { byteAt(node.right.getOrThrow(), offset - left.bytes) }
        }
    }

    private func newlineOffset(node: PieceTextNode, index: Int64): Int64 {
        visited++
        match (node.span) {
            case Some(span) => span.source.newlines[span.firstNewline + index] - span.start
            case None =>
                let left = node.left.getOrThrow()
                if (index < left.lineBreaks) { newlineOffset(left, index) }
                else { left.bytes + newlineOffset(node.right.getOrThrow(), index - left.lineBreaks) }
        }
    }

    private func prefixLineBreaks(node: PieceTextNode, offset: Int64): Int64 {
        visited++
        if (offset <= 0) { return 0 }
        if (offset >= node.bytes) { return node.lineBreaks }
        match (node.span) {
            case Some(span) => span.source.newlineIndex(span.start + offset) - span.firstNewline
            case None =>
                let left = node.left.getOrThrow()
                if (offset <= left.bytes) { prefixLineBreaks(left, offset) }
                else { left.lineBreaks + prefixLineBreaks(node.right.getOrThrow(), offset - left.bytes) }
        }
    }

    private func rangeText(start: Int64, end: Int64): String {
        if (start >= end) { return "" }
        let builder = StringBuilder()
        appendRange(root.getOrThrow(), start, end, builder)
        builder.toString()
    }

    private func appendRange(node: PieceTextNode, start: Int64, end: Int64, builder: StringBuilder): Unit {
        visited++
        match (node.span) {
            case Some(span) =>
                builder.append(span.source.value[(span.start + start)..(span.start + end)])
                copied += end - start
            case None =>
                let left = node.left.getOrThrow()
                if (start < left.bytes) { appendRange(left, start, min(end, left.bytes), builder) }
                if (end > left.bytes) {
                    appendRange(node.right.getOrThrow(), max(0, start - left.bytes), end - left.bytes, builder)
                }
        }
    }

    // Compare without materializing the deleted range. A no-op edit keeps
    // revision, undo and redo unchanged and allocates no tree nodes.
    private func matches(node: PieceTextNode, start: Int64, end: Int64, expected: String, expectedStart: Int64): Bool {
        visited++
        match (node.span) {
            case Some(span) =>
                let source = unsafe { span.source.value.rawData() }
                let target = unsafe { expected.rawData() }
                for (index in 0..(end - start)) {
                    scanned++
                    if (source[span.start + start + index] != target[expectedStart + index]) { return false }
                }
                true
            case None =>
                let left = node.left.getOrThrow()
                let leftLength = max(0, min(end, left.bytes) - start)
                if (leftLength > 0 && !matches(left, start, start + leftLength, expected, expectedStart)) { return false }
                if (end > left.bytes) {
                    return matches(node.right.getOrThrow(), max(0, start - left.bytes), end - left.bytes,
                        expected, expectedStart + leftLength)
                }
                true
        }
    }

    private func split(tree: ?PieceTextNode, offset: Int64): (?PieceTextNode, ?PieceTextNode) {
        match (tree) {
            case None => (None, None)
            case Some(node) =>
                visited++
                if (offset <= 0) { return (None, tree) }
                if (offset >= node.bytes) { return (tree, None) }
                match (node.span) {
                    case Some(span) =>
                        let middle = span.start + offset
                        (Some(PieceTextNode(PieceTextSpan(span.source, span.start, middle))),
                            Some(PieceTextNode(PieceTextSpan(span.source, middle, span.end))))
                    case None =>
                        let left = node.left.getOrThrow()
                        if (offset < left.bytes) {
                            let (before, after) = split(node.left, offset)
                            (before, concatenate(after, node.right))
                        } else if (offset > left.bytes) {
                            let (before, after) = split(node.right, offset - left.bytes)
                            (concatenate(node.left, before), after)
                        } else {
                            (node.left, node.right)
                        }
                }
        }
    }

    private func concatenate(left: ?PieceTextNode, right: ?PieceTextNode): ?PieceTextNode {
        match ((left, right)) {
            case (None, _) => right
            case (_, None) => left
            case (Some(a), Some(b)) => Some(joinNodes(a, b))
        }
    }

    private func joinNodes(left: PieceTextNode, right: PieceTextNode): PieceTextNode {
        visited++
        if (left.height > right.height + 1) {
            return balance(left.left.getOrThrow(), joinNodes(left.right.getOrThrow(), right))
        }
        if (right.height > left.height + 1) {
            return balance(joinNodes(left, right.left.getOrThrow()), right.right.getOrThrow())
        }
        PieceTextNode(left, right)
    }

    private func balance(left: PieceTextNode, right: PieceTextNode): PieceTextNode {
        visited++
        if (left.height > right.height + 1) {
            let a = left.left.getOrThrow()
            let b = left.right.getOrThrow()
            if (a.height >= b.height) { return PieceTextNode(a, PieceTextNode(b, right)) }
            return PieceTextNode(PieceTextNode(a, b.left.getOrThrow()), PieceTextNode(b.right.getOrThrow(), right))
        }
        if (right.height > left.height + 1) {
            let b = right.left.getOrThrow()
            let c = right.right.getOrThrow()
            if (c.height >= b.height) { return PieceTextNode(PieceTextNode(left, b), c) }
            return PieceTextNode(PieceTextNode(left, b.left.getOrThrow()), PieceTextNode(b.right.getOrThrow(), c))
        }
        PieceTextNode(left, right)
    }
}
