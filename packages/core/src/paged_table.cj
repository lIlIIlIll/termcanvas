package core

import std.collection.*

public class TableDataRow {
    public let id: String
    public let cells: Array<String>
    public init(id: String, cells: Array<String>) {
        this.id = id
        this.cells = Array<String>(cells.size, { i => cells[i] })
    }
}

public struct TableQuery {
    public let filter: String
    public let sortColumn: ?Int64
    public let descending: Bool
    public init(filter!: String = "", sortColumn!: ?Int64 = None, descending!: Bool = false) {
        this.filter = filter
        this.sortColumn = sortColumn
        this.descending = descending
    }
}

public class TablePageRequest {
    public let revision: Int64
    public let requestId: Int64
    public let offset: Int64
    public let limit: Int64
    public let query: TableQuery
    init(revision: Int64, requestId: Int64, offset: Int64, limit: Int64, query: TableQuery) {
        this.revision = revision; this.requestId = requestId
        this.offset = offset; this.limit = limit; this.query = query
    }
}

public class TablePage {
    public let rows: Array<TableDataRow>
    public let totalRows: Int64
    public init(rows: Array<TableDataRow>, totalRows: Int64) {
        this.rows = rows
        this.totalRows = totalRows
    }
}

// Execute load through the application's existing async command/resource path.
// The provider applies sorting/filtering before returning an indexed page.
public interface TableDataSource {
    func load(request: TablePageRequest): TablePage
}

// Application-owned state. Rendering never starts requests or accepts results.
public class PagedTableModel {
    public let pageSize: Int64
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

    public init(pageSize!: Int64 = 128, maxPages!: Int64 = 8) {
        this.pageSize = max(1, pageSize)
        this.maxPages = max(1, maxPages)
    }
    public func query(): TableQuery { queryValue }
    public func revision(): Int64 { revisionValue }
    public func totalRows(): Int64 { totalValue }
    public func hasTotal(): Bool { knownTotal }
    public func cachedPageCount(): Int64 { pages.size }
    public func pendingPageCount(): Int64 { pending.size }
    public func cachedRowCount(): Int64 {
        var count: Int64 = 0
        for ((_, rows) in pages) { count += rows.size }
        count
    }
    public func selectedId(): ?String { focusId }
    public func selectedIndex(): ?Int64 { focusIndex }
    public func selectedIds(): Array<String> {
        let out = ArrayList<String>()
        for ((id, _) in selected) { out.add(id) }
        out.toArray()
    }
    public func isSelected(id: String): Bool { selected.contains(id) }
    public func toggle(id: String): Unit {
        if (selected.contains(id)) { selected.remove(id) } else { selected.add(id, true) }
    }
    public func selectIndex(index: Int64): Unit {
        if (index < 0 || (knownTotal && index >= totalValue)) { focusIndex = None; focusId = None; return }
        focusIndex = Some(index)
        focusId = match (row(index)) { case Some(value) => Some(value.id); case None => None }
    }
    public func selectId(id: String): Unit {
        focusId = Some(id)
        focusIndex = None
        for ((start, rows) in pages) {
            for (i in 0..rows.size) { if (rows[i].id == id) { focusIndex = Some(start + i); return } }
        }
    }
    public func setQuery(query: TableQuery): Bool {
        if (query.filter == queryValue.filter && query.sortColumn == queryValue.sortColumn && query.descending == queryValue.descending) { return false }
        queryValue = query
        invalidate()
        true
    }
    public func invalidate(): Unit {
        revisionValue++
        pages.clear(); order.clear(); pending.clear(); failures.clear()
        totalValue = 0; knownTotal = false; focusIndex = None
    }
    public func row(index: Int64): ?TableDataRow {
        if (index < 0 || (knownTotal && index >= totalValue)) { return None }
        let start = index / pageSize * pageSize
        if (let Some(rows) <- pages.get(start)) {
            if (index - start < rows.size) { return Some(rows[index - start]) }
        }
        None
    }
    public func statusAt(index: Int64): TableStatus {
        if (knownTotal && totalValue == 0) { return TableStatus.Empty }
        if (row(index).isSome()) { return TableStatus.Ready }
        let start = max(0, index) / pageSize * pageSize
        if (let Some(message) <- failures.get(start)) { return TableStatus.Error(message) }
        TableStatus.Loading
    }
    // Returns only missing pages intersecting the viewport, bounded by maxPages.
    // Call from update, then dispatch each request through an async resource.
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
    public func fail(request: TablePageRequest, message: String): Bool {
        if (!current(request)) { return false }
        pending.remove(request.offset); failures.add(request.offset, message)
        true
    }
    public func isPending(request: TablePageRequest): Bool { current(request) }
    private func current(request: TablePageRequest): Bool {
        request.revision == revisionValue && pending.get(request.offset) == Some(request.requestId)
    }
}
