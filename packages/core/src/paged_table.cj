package core

import std.collection.*

/** 表格中的稳定标识和单元格数据。
 */
public class TableDataRow {
    /** 行标识。
     */
    public let id: String
    /** 单元格文本。
     */
    public let cells: Array<String>
    /** 创建数据对象。
     * @param id 行标识
     * @param cells 单元格文本；构造时复制数组
     */
    public init(id: String, cells: Array<String>) {
        this.id = id
        this.cells = Array<String>(cells.size, { i => cells[i] })
    }
}

/** 由数据源执行的过滤和排序条件。
 */
public struct TableQuery {
    /** 过滤文本。
     */
    public let filter: String
    /** 排序列索引；None 表示无排序列。
     */
    public let sortColumn: ?Int64
    /** 是否降序。
     */
    public let descending: Bool
    /** 创建数据对象。
     * @param filter 过滤文本
     * @param sortColumn 可选排序列
     * @param descending 是否降序
     */
    public init(filter!: String = "", sortColumn!: ?Int64 = None, descending!: Bool = false) {
        this.filter = filter
        this.sortColumn = sortColumn
        this.descending = descending
    }
}

/** 模型生成的一次分页读取请求。
 */
public class TablePageRequest {
    /** 模型修订号。
     */
    public let revision: Int64
    /** 请求序号。
     */
    public let requestId: Int64
    /** 页面起始行索引。
     */
    public let offset: Int64
    /** 请求的最大行数。
     */
    public let limit: Int64
    /** 请求对应的查询条件。
     */
    public let query: TableQuery
    init(revision: Int64, requestId: Int64, offset: Int64, limit: Int64, query: TableQuery) {
        this.revision = revision; this.requestId = requestId
        this.offset = offset; this.limit = limit; this.query = query
    }
}

/** 数据源返回的页面与总行数。
 */
public class TablePage {
    /** 页面行数据。
     */
    public let rows: Array<TableDataRow>
    /** 查询结果总行数。
     */
    public let totalRows: Int64
    /** 创建数据对象。
     * @param rows 页面数据
     * @param totalRows 查询结果总行数
     */
    public init(rows: Array<TableDataRow>, totalRows: Int64) {
        this.rows = rows
        this.totalRows = totalRows
    }
}

// Execute load through the application's existing async command/resource path.
// The provider applies sorting/filtering before returning an indexed page.
/** 按请求加载已过滤、排序的数据页面；应用负责调度读取。
 */
public interface TableDataSource {
    /** 加载请求指定的页面。
     * @param request 分页请求
     * @return 页面及总行数。
     */
    func load(request: TablePageRequest): TablePage
}

// Application-owned state. Rendering never starts requests or accepts results.
/** 管理分页请求、缓存和按标识保存的选择；应用负责执行请求及提交结果。
 */
public class PagedTableModel {
    /** 每页最大行数，至少为一。
     */
    public let pageSize: Int64
    /** 缓存和单次视口请求的最大页数，至少为一。
     */
    public let maxPages: Int64
    private var queryValue = TableQuery()
    private var revisionValue: Int64 = 0
    private var serial: Int64 = 0
    private var totalValue: Int64 = 0
    private var knownTotal = false
    private let pages = HashMap<Int64, Array<TableDataRow>>()
    private let order = ArrayList<Int64>()
    private let pending = HashMap<Int64, Int64>()
    private let failures = HashMap<Int64, String>()
    private let selected = HashMap<String, Bool>()
    private var focusId: ?String = None
    private var focusIndex: ?Int64 = None

    /** 创建分页模型。
     * @param pageSize 每页行数，小于一时按一处理
     * @param maxPages 最大页数，小于一时按一处理
     */
    public init(pageSize!: Int64 = 128, maxPages!: Int64 = 8) {
        this.pageSize = max(1, pageSize)
        this.maxPages = max(1, maxPages)
    }
    /** 获取当前查询条件。
     * @return 查询条件。
     */
    public func query(): TableQuery { queryValue }
    /** 获取当前修订号。
     * @return 修订号。
     */
    public func revision(): Int64 { revisionValue }
    /** 获取最近一次接受结果提供的总行数。
     * @return 总行数；尚未得知时为零，可用 hasTotal 区分。
     */
    public func totalRows(): Int64 { totalValue }
    /** 查询总行数是否已知。
     * @return 已知时为 true。
     */
    public func hasTotal(): Bool { knownTotal }
    /** 获取缓存页数。
     * @return 缓存页数。
     */
    public func cachedPageCount(): Int64 { pages.size }
    /** 获取待处理请求数。
     * @return 待处理页数。
     */
    public func pendingPageCount(): Int64 { pending.size }
    /** 获取缓存中的总行数。
     * @return 缓存行数。
     */
    public func cachedRowCount(): Int64 {
        var count: Int64 = 0
        for ((_, rows) in pages) { count += rows.size }
        count
    }
    /** 获取焦点行标识。
     * @return 焦点标识或 None。
     */
    public func selectedId(): ?String { focusId }
    /** 获取焦点行索引。
     * @return 焦点索引或 None。
     */
    public func selectedIndex(): ?Int64 { focusIndex }
    /** 获取多选行标识；顺序未指定。
     * @return 已选标识数组。
     */
    public func selectedIds(): Array<String> {
        let out = ArrayList<String>()
        for ((id, _) in selected) { out.add(id) }
        out.toArray()
    }
    /** 查询标识的多选状态。
     * @param id 行标识
     * @return 已选时为 true。
     */
    public func isSelected(id: String): Bool { selected.contains(id) }
    /** 切换标识的多选状态。
     * @param id 行标识
     */
    public func toggle(id: String): Unit {
        if (selected.contains(id)) { selected.remove(id) } else { selected.add(id, true) }
    }
    /** 按行索引设置焦点；已缓存时同步焦点标识。
     * @param index 行索引；无效时清除焦点
     */
    public func selectIndex(index: Int64): Unit {
        if (index < 0 || (knownTotal && index >= totalValue)) { focusIndex = None; focusId = None; return }
        focusIndex = Some(index)
        focusId = match (row(index)) { case Some(value) => Some(value.id); case None => None }
    }
    /** 按标识设置焦点；命中缓存时同步焦点索引。
     * @param id 行标识
     */
    public func selectId(id: String): Unit {
        focusId = Some(id)
        focusIndex = None
        for ((start, rows) in pages) {
            for (i in 0..rows.size) { if (rows[i].id == id) { focusIndex = Some(start + i); return } }
        }
    }
    /** 更新查询；条件变化时使缓存和待处理请求失效。
     * @param query 新查询条件
     * @return 条件发生变化时为 true。
     */
    public func setQuery(query: TableQuery): Bool {
        if (query.filter == queryValue.filter && query.sortColumn == queryValue.sortColumn && query.descending == queryValue.descending) { return false }
        queryValue = query
        invalidate()
        true
    }
    /** 递增修订号并清除页面、待处理请求、错误及已知总数；保留焦点标识和多选标识。
     */
    public func invalidate(): Unit {
        revisionValue++
        pages.clear(); order.clear(); pending.clear(); failures.clear()
        totalValue = 0; knownTotal = false; focusIndex = None
    }
    /** 读取缓存行。
     * @param index 行索引
     * @return 已缓存且有效时返回行，否则返回 None。
     */
    public func row(index: Int64): ?TableDataRow {
        if (index < 0 || (knownTotal && index >= totalValue)) { return None }
        let start = index / pageSize * pageSize
        if (let Some(rows) <- pages.get(start)) {
            if (index - start < rows.size) { return Some(rows[index - start]) }
        }
        None
    }
    /** 查询行所在页面的状态。
     * @param index 行索引
     * @return 空、就绪、错误或加载状态。
     */
    public func statusAt(index: Int64): TableStatus {
        if (knownTotal && totalValue == 0) { return TableStatus.Empty }
        if (row(index).isSome()) { return TableStatus.Ready }
        let start = max(0, index) / pageSize * pageSize
        if (let Some(message) <- failures.get(start)) { return TableStatus.Error(message) }
        TableStatus.Loading
    }
    // Returns only missing pages intersecting the viewport, bounded by maxPages.
    // Call from update, then dispatch each request through an async resource.
    /** 为视口缺失页创建请求，并移除视口外待处理请求。
     * @param offset 视口起始行，负值按零处理
     * @param height 视口高度，至少按一行计算
     * @param retry 是否重新请求失败页
     * @return 新请求数组，数量不超过 maxPages。
     */
    public func requestViewport(offset: Int64, height: Int64, retry!: Bool = false): Array<TablePageRequest> {
        let out = ArrayList<TablePageRequest>()
        let start = max(0, offset) / pageSize * pageSize
        let span = max(1, height)
        let last = if (max(0, offset) > Int64.Max - (span - 1)) { Int64.Max } else { max(0, offset) + span - 1 }
        let wanted = ArrayList<Int64>()
        var position = start
        while (position <= last && wanted.size < maxPages && (!knownTotal || position < totalValue)) {
            wanted.add(position)
            if (position > Int64.Max - pageSize) { break }
            position += pageSize
        }
        let obsolete = ArrayList<Int64>()
        for ((position, _) in pending) {
            var keep = false
            for (value in wanted) { if (value == position) { keep = true; break } }
            if (!keep) { obsolete.add(position) }
        }
        for (value in obsolete) { pending.remove(value) }
        // Errors belong to the active viewport and cannot accumulate indefinitely.
        let oldFailures = ArrayList<Int64>()
        for ((position, _) in failures) {
            var keep = false
            for (value in wanted) { if (value == position) { keep = true; break } }
            if (!keep) { oldFailures.add(position) }
        }
        for (value in oldFailures) { failures.remove(value) }
        for (position in wanted) {
            if (pages.contains(position) || pending.contains(position) || (!retry && failures.contains(position))) { continue }
            failures.remove(position)
            serial++
            pending.add(position, serial)
            out.add(TablePageRequest(revisionValue, serial, position, pageSize, queryValue))
        }
        out.toArray()
    }
    /** 接受当前请求的有效页面，并校验总数、页长和页面内行标识。
     * @param request 模型生成的待处理请求
     * @param page 数据源返回的页面
     * @return 结果有效且已接受时为 true；过期或无效结果为 false。
     */
    public func accept(request: TablePageRequest, page: TablePage): Bool {
        if (!current(request)) { return false }
        if (knownTotal && page.totalRows != totalValue) {
            _ = fail(request, "Source total changed; invalidate the model before reloading")
            return false
        }
        let expected = if (page.totalRows <= request.offset) { Int64(0) } else { min(request.limit, page.totalRows - request.offset) }
        if (page.totalRows < 0 || page.rows.size != expected) { _ = fail(request, "Invalid page size or total"); return false }
        let ids = HashMap<String, Bool>()
        for (row in page.rows) {
            if (row.id.isEmpty() || ids.contains(row.id)) { _ = fail(request, "Empty or duplicate row ID"); return false }
            ids.add(row.id, true)
        }
        let copy = Array<TableDataRow>(page.rows.size, { i => TableDataRow(page.rows[i].id, page.rows[i].cells) })
        pending.remove(request.offset); failures.remove(request.offset)
        totalValue = page.totalRows; knownTotal = true
        if (let Some(index) <- focusIndex) { if (index >= totalValue) { focusIndex = None } }
        pages.add(request.offset, copy); order.add(request.offset)
        while (order.size > maxPages) { pages.remove(order.remove(at: 0)) }
        for (i in 0..copy.size) {
            if (focusId == Some(copy[i].id)) { focusIndex = Some(request.offset + i) }
            else if (focusId.isNone() && focusIndex == Some(request.offset + i)) { focusId = Some(copy[i].id) }
        }
        true
    }
    /** 将当前请求标记为失败。
     * @param request 模型生成的待处理请求
     * @param message 错误信息
     * @return 请求仍有效并已标记时为 true。
     */
    public func fail(request: TablePageRequest, message: String): Bool {
        if (!current(request)) { return false }
        pending.remove(request.offset); failures.add(request.offset, message)
        true
    }
    /** 查询请求是否仍属于当前修订及视口。
     * @param request 分页请求
     * @return 请求仍待处理时为 true。
     */
    public func isPending(request: TablePageRequest): Bool { current(request) }
    private func current(request: TablePageRequest): Bool {
        request.revision == revisionValue && pending.get(request.offset) == Some(request.requestId)
    }
}
