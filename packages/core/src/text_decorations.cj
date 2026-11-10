package core

import std.collection.*

// All ranges are half-open UTF-8 byte offsets in a specific model revision.
/** 一次文本编辑及其前后修订号；范围为编辑前文本的半开 UTF-8 字节区间。 */
public struct TextEditDelta {
    /** 编辑起始字节偏移。 */
    public let start: Int64
    /** 编辑结束字节偏移，不包含该位置。 */
    public let end: Int64
    /** 插入文本的 UTF-8 字节数。 */
    public let insertedBytes: Int64
    /** 编辑前的修订号。 */
    public let beforeRevision: Int64
    /** 编辑后的修订号。 */
    public let afterRevision: Int64
    /** 保存编辑范围和修订号；调用方负责保证输入与实际编辑一致。
     * @param start 编辑起始字节偏移
     * @param end 编辑结束字节偏移，不包含该位置
     * @param insertedBytes 插入的 UTF-8 字节数
     * @param beforeRevision 编辑前修订号
     * @param afterRevision 编辑后修订号
     */
    public init(start: Int64, end: Int64, insertedBytes: Int64, beforeRevision: Int64, afterRevision: Int64) {
        this.start = start
        this.end = end
        this.insertedBytes = insertedBytes
        this.beforeRevision = beforeRevision
        this.afterRevision = afterRevision
    }
}

/** 按文档修订号和半开 UTF-8 字节区间提供文本装饰。 */
public interface TextDecorationProvider {
    /** 返回装饰数据所属的修订号。
     * @return 当前修订号
     */
    func revision(): Int64
    /** 查询与指定半开字节区间相交的装饰。
     * @param start 起始字节偏移
     * @param end 结束字节偏移，不包含该位置
     * @return 相关装饰
     */
    func query(start: Int64, end: Int64): Array<TextDecoration>
    /** 接收文本编辑通知；默认实现不执行操作。
     * @param edit 编辑范围及修订变化
     */
    func onEdit(edit: TextEditDelta): Unit {}
}

/** 某个修订号下一个半开字节区间的装饰更新。 */
public class TextDecorationUpdate {
    /** 装饰结果对应的修订号。 */
    public let revision: Int64
    /** 更新范围起始字节偏移。 */
    public let start: Int64
    /** 更新范围结束字节偏移，不包含该位置。 */
    public let end: Int64
    /** 更新范围中的装饰。 */
    public let spans: Array<TextDecoration>
    /** 创建装饰更新；起始偏移限制为非负，结束偏移不小于起始偏移。
     * @param revision 装饰结果对应的修订号
     * @param start 起始字节偏移
     * @param end 结束字节偏移，不包含该位置
     * @param spans 更新范围内的装饰
     */
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
/** 按范围缓存文本装饰；编辑会平移后续范围并使相交范围失效。 */
public class TextDecorationStore <: TextDecorationProvider {
    private var currentRevision: Int64
    private var chunks = ArrayList<DecorationChunk>()
    private var invalidations: Int64 = 0
    private var queries: Int64 = 0
    /** 创建空缓存。
     * @param revision 初始修订号
     */
    public init(revision!: Int64 = 0) { currentRevision = revision }
    /** 获取缓存当前修订号。
     * @return 当前修订号
     */
    public func revision(): Int64 { currentRevision }
    /** 获取缓存范围的数量。
     * @return 当前缓存的范围数
     */
    public func cachedRanges(): Int64 { chunks.size }
    /** 获取被替换、编辑或重置失效的范围累计数量。
     * @return 累计失效范围数
     */
    public func invalidatedRanges(): Int64 { invalidations }
    /** 获取查询调用的累计次数，包括空区间查询。
     * @return 累计查询次数
     */
    public func queryCount(): Int64 { queries }

    /** 应用同一修订号的范围更新，替换与其相交的整个缓存范围；空范围不改变缓存。
     * @param update 待应用的装饰更新
     * @return 修订号匹配时为 true，否则不修改缓存并返回 false
     */
    public func apply(update: TextDecorationUpdate): Bool {
        if (update.revision != currentRevision) { return false }
        // A half-open empty range overlaps no cached bytes. In particular,
        // a parser reporting an empty line must not evict its enclosing block.
        if (update.start == update.end) { return true }
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

    /** 查询与指定区间相交的装饰；结果按缓存范围裁剪，不按查询区间裁剪。
     * @param start 起始字节偏移
     * @param end 结束字节偏移，不包含该位置
     * @return 相交的装饰；空区间返回空数组
     */
    public func query(start: Int64, end: Int64): Array<TextDecoration> {
        queries++
        if (end <= start) { return [] }
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

    /** 应用编辑并更新修订号；旧修订号不匹配时清空缓存，相交范围失效，后续范围按字节差平移。
     * @param edit 编辑范围及修订变化
     */
    public func onEdit(edit: TextEditDelta): Unit {
        if (edit.beforeRevision != currentRevision) { reset(edit.afterRevision); return }
        if (edit.start == edit.end && edit.insertedBytes == 0) {
            currentRevision = edit.afterRevision
            return
        }
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

    /** 清空缓存并设置修订号，保留累计统计。
     * @param revision 新的修订号
     */
    public func reset(revision: Int64): Unit {
        invalidations += chunks.size
        chunks.clear()
        currentRevision = revision
    }
}
