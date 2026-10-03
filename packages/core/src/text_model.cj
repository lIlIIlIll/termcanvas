package core

import std.collection.*

// Text offsets and line starts are UTF-8 byte offsets. LF separates lines;
// a trailing LF adds an empty line. Edits clamp backward to rune boundaries.
// slice/replace normalize reversed ranges. line returns "" for invalid rows;
// lineStart clamps negative rows to 0 and rows past the last to byteLength.
// revision changes on an effective edit or history traversal, not a no-op.
public interface TextModel {
    func byteLength(): Int64
    func lineCount(): Int64
    func line(index: Int64): String
    func lineStart(index: Int64): Int64
    func lineForOffset(offset: Int64): Int64
    func slice(start: Int64, end: Int64): String
    func replace(start: Int64, end: Int64, text: String): Unit
    func text(): String
    func revision(): Int64
    // Instrumentation is optional for application-supplied text models.
    func metrics(): TextModelMetrics { TextModelMetrics() }
    // Override this fallback to keep boundary checks local for large models.
    func clampOffset(offset: Int64): Int64 { clampToRuneBoundary(text(), offset) }
}

public interface EditableTextModel <: TextModel {
    // Nested groups commit at the outermost end. undo/redo seal an open group.
    func beginUndoGroup(): Unit
    func endUndoGroup(): Unit
    func undo(): Bool
    func redo(): Bool
    func clearHistory(): Unit
}

// Deterministic work counters: take two snapshots to inspect a local operation.
// Counters are cumulative, except pieceCount/treeHeight (current-tree gauges).
// bytesScanned counts input indexing and byte comparisons; bytesCopied counts
// bytes emitted into requested output, not allocator-internal copies or
// retained immutable source views.
public struct TextModelMetrics {
    public let nodeVisits: Int64
    public let bytesScanned: Int64
    public let bytesCopied: Int64
    public let materializations: Int64
    public let pieceCount: Int64
    public let treeHeight: Int64

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

    public init(text!: String = "") {
        if (!text.isEmpty()) {
            let source = PieceTextSource(text)
            root = Some(PieceTextNode(PieceTextSpan(source, 0, text.size)))
            scanned = text.size
        }
    }

    public func byteLength(): Int64 {
        match (root) { case Some(node) => node.bytes; case None => 0 }
    }

    public func lineCount(): Int64 {
        match (root) { case Some(node) => node.lineBreaks + 1; case None => 1 }
    }

    public func line(index: Int64): String {
        if (index < 0 || index >= lineCount()) { return "" }
        let start = lineStart(index)
        let end = if (index + 1 < lineCount()) { lineStart(index + 1) - 1 } else { byteLength() }
        rangeText(start, end)
    }

    public func lineStart(index: Int64): Int64 {
        if (index <= 0) { return 0 }
        if (index >= lineCount()) { return byteLength() }
        newlineOffset(root.getOrThrow(), index - 1) + 1
    }

    public func lineForOffset(offset: Int64): Int64 {
        let position = clamp(offset, 0, byteLength())
        match (root) {
            case Some(node) => prefixLineBreaks(node, position)
            case None => 0
        }
    }

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

    public func slice(start: Int64, end: Int64): String {
        let first = clampOffset(min(start, end))
        let last = clampOffset(max(start, end))
        rangeText(first, last)
    }

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

    public func text(): String {
        flattened++
        rangeText(0, byteLength())
    }

    public func revision(): Int64 { generation }

    public func metrics(): TextModelMetrics {
        let (pieces, height) = match (root) {
            case Some(node) => (node.pieces, node.height)
            case None => (0, 0)
        }
        TextModelMetrics(nodeVisits: visited, bytesScanned: scanned, bytesCopied: copied,
            materializations: flattened, pieceCount: pieces, treeHeight: height)
    }

    public func beginUndoGroup(): Unit {
        if (groupDepth == 0) {
            groupRoot = root
            groupChanged = false
        }
        groupDepth++
    }

    public func endUndoGroup(): Unit {
        if (groupDepth == 0) { return }
        groupDepth--
        if (groupDepth == 0) { sealGroup() }
    }

    public func undo(): Bool {
        sealGroup()
        if (undoRoots.isEmpty()) { return false }
        redoRoots.add(root)
        root = undoRoots.remove(at: undoRoots.size - 1)
        generation++
        true
    }

    public func redo(): Bool {
        sealGroup()
        if (redoRoots.isEmpty()) { return false }
        undoRoots.add(root)
        root = redoRoots.remove(at: redoRoots.size - 1)
        generation++
        true
    }

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
