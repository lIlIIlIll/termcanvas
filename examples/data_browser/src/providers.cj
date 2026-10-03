package cjtui_data_browser

import core.*
import std.convert.*
import std.collection.*
import std.sync.*

// A deterministic stand-in for an indexed remote database: no full row scan.
class BrowserRows <: TableDataSource {
    public func load(request: TablePageRequest): TablePage {
        sleep(25 * Duration.millisecond)
        if (request.query.filter == "!error") { throw IllegalStateException("Provider unavailable (demo); / resets, r retries") }
        let filtered = request.query.filter == "ready"
        let total: Int64 = if (filtered) { 333334 } else { 1000000 }
        let count = min(request.limit, max(0, total - request.offset))
        TablePage(Array<TableDataRow>(count, { i =>
            let visible = request.offset + i
            let ordinal = if (request.query.descending) { total - 1 - visible } else { visible }
            let row = if (filtered) { ordinal * 3 } else if (request.query.sortColumn == Some(2)) {
                if (ordinal < 666666) { ordinal + ordinal / 2 + 1 } else { (ordinal - 666666) * 3 }
            } else { ordinal }
            TableDataRow("record-${row}", ["${row}", "record-${row}", if (row % 3 == 0) { "ready" } else { "pending" }])
        }), total)
    }
}

class BrowserTreeSource <: TreeDataSource {
    public func rootCount(): Int64 { 1 }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (path.size == 1 && path[0] == 0) { return Some(LazyTreeNode("root", "workspace (1M entries)", childCount: 1000000)) }
        if (path.size == 2 && path[0] == 0 && path[1] >= 0 && path[1] < 1000000) {
            return Some(LazyTreeNode("entry-${path[1]}", "entry-${path[1]}"))
        }
        None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "root") { return Some([0]) }
        if (id.startsWith("entry-")) { try { return Some([0, Int64.parse(id[6..])]) } catch (_) { return None } }
        None
    }
}

class BrowserPageResult {
    let requestId: Int64
    let page: ?TablePage
    let error: String
    init(requestId: Int64, page: ?TablePage, error: String) { this.requestId = requestId; this.page = page; this.error = error }
}

// Transport only: workers publish immutable page snapshots under a mutex.
// The App update callback alone applies results to the canonical model.
class BrowserPageMailbox {
    private let lock = Mutex()
    private let values = HashMap<Int64, BrowserPageResult>()
    private let allowed = HashMap<Int64, Bool>()
    func put(value: BrowserPageResult): Unit {
        lock.lock()
        try {
            if (allowed.contains(value.requestId) && values.size < 16) { values.add(value.requestId, value) }
        } finally { lock.unlock() }
    }
    func retain(ids: Array<Int64>): Unit {
        lock.lock()
        try {
            allowed.clear()
            for (id in ids) { allowed.add(id, true) }
            let obsolete = ArrayList<Int64>()
            for ((id, _) in values) { if (!allowed.contains(id)) { obsolete.add(id) } }
            for (id in obsolete) { values.remove(id) }
        } finally { lock.unlock() }
    }
    func take(id: Int64): ?BrowserPageResult {
        lock.lock()
        try {
            let result = values.get(id)
            values.remove(id)
            result
        } finally { lock.unlock() }
    }
}
