package core

import std.collection.*

// All ranges are half-open UTF-8 byte offsets in a specific model revision.
public struct TextEditDelta {
    public let start: Int64
    public let end: Int64
    public let insertedBytes: Int64
    public let beforeRevision: Int64
    public let afterRevision: Int64
    public init(start: Int64, end: Int64, insertedBytes: Int64, beforeRevision: Int64, afterRevision: Int64) {
        this.start = start
        this.end = end
        this.insertedBytes = insertedBytes
        this.beforeRevision = beforeRevision
        this.afterRevision = afterRevision
    }
}

public interface TextDecorationProvider {
    func revision(): Int64
    func query(start: Int64, end: Int64): Array<TextDecoration>
    func onEdit(edit: TextEditDelta): Unit {}
}

public class TextDecorationUpdate {
    public let revision: Int64
    public let start: Int64
    public let end: Int64
    public let spans: Array<TextDecoration>
    public init(revision: Int64, start: Int64, end: Int64, spans: Array<TextDecoration>) {
        this.revision = revision
        this.start = max(0, start)
        this.end = max(this.start, end)
        this.spans = spans
    }
}

class DecorationChunk {
    var start: Int64
    var end: Int64
    var shift: Int64 = 0
    let spans: Array<TextDecoration>
    init(update: TextDecorationUpdate) {
        start = update.start
        end = update.end
        spans = update.spans
    }
}

// A range cache, suitable for line-sized or syntax-block-sized results.
// Overlapping results replace that cache range. Unaffected chunks survive
// edits; offsets after an edit are translated without re-running a provider.
// The parser decides how far a lexical-state change needs re-highlighting.
public class TextDecorationStore <: TextDecorationProvider {
    private var currentRevision: Int64
    private var chunks = ArrayList<DecorationChunk>()
    private var invalidations: Int64 = 0
    private var queries: Int64 = 0
    public init(revision!: Int64 = 0) { currentRevision = revision }
    public func revision(): Int64 { currentRevision }
    public func cachedRanges(): Int64 { chunks.size }
    public func invalidatedRanges(): Int64 { invalidations }
    public func queryCount(): Int64 { queries }

    public func apply(update: TextDecorationUpdate): Bool {
        if (update.revision != currentRevision) { return false }
        let next = ArrayList<DecorationChunk>()
        var added = false
        for (chunk in chunks) {
            if (!added && chunk.start >= update.start) { next.add(DecorationChunk(update)); added = true }
            if (chunk.end <= update.start || chunk.start >= update.end) { next.add(chunk) }
            else { invalidations++ }
        }
        if (!added) { next.add(DecorationChunk(update)) }
        chunks = next
        true
    }

    public func query(start: Int64, end: Int64): Array<TextDecoration> {
        queries++
        let out = ArrayList<TextDecoration>()
        var low: Int64 = 0
        var high = chunks.size
        while (low < high) {
            let middle = low + (high - low) / 2
            if (chunks[middle].end <= start) { low = middle + 1 } else { high = middle }
        }
        var index = low
        while (index < chunks.size && chunks[index].start < end) {
            let chunk = chunks[index]
            for (span in chunk.spans) {
                let from = max(chunk.start, span.start + chunk.shift)
                let to = min(chunk.end, span.end + chunk.shift)
                if (from < end && to > start && from < to) { out.add(TextDecoration(from, to, span.style)) }
            }
            index++
        }
        out.toArray()
    }

    public func onEdit(edit: TextEditDelta): Unit {
        if (edit.beforeRevision != currentRevision) { reset(edit.afterRevision); return }
        let next = ArrayList<DecorationChunk>()
        let delta = edit.insertedBytes - (edit.end - edit.start)
        for (chunk in chunks) {
            if (chunk.end <= edit.start) { next.add(chunk) }
            else if (chunk.start >= edit.end) {
                chunk.start += delta
                chunk.end += delta
                chunk.shift += delta
                next.add(chunk)
            } else { invalidations++ }
        }
        chunks = next
        currentRevision = edit.afterRevision
    }

    public func reset(revision: Int64): Unit {
        invalidations += chunks.size
        chunks.clear()
        currentRevision = revision
    }
}
