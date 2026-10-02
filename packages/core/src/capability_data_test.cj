package core

import std.convert.*

import std.unittest.*
import std.unittest.testmacro.*

class MillionTreeSource <: TreeDataSource {
    var reads: Int64 = 0
    public func rootCount(): Int64 { 1 }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        reads++
        if (path.size == 1 && path[0] == 0) { return Some(LazyTreeNode("root", "Root", childCount: 1000000)) }
        if (path.size == 2 && path[0] == 0 && path[1] >= 0 && path[1] < 1000000) {
            return Some(LazyTreeNode("node-${path[1]}", "Node ${path[1]}"))
        }
        None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "root") { return Some([0]) }
        if (id.startsWith("node-")) {
            try { return Some([0, Int64.parse(id[5..])]) } catch (_) { return None }
        }
        None
    }
}

class ReusedPathTreeSource <: TreeDataSource {
    let scratch: Array<Int64> = [0]
    public func rootCount(): Int64 { 2 }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (path.size == 1) { return Some(LazyTreeNode(if (path[0] == 0) { "first" } else { "second" }, "Root", childCount: 1)) }
        if (path.size == 2) { return Some(LazyTreeNode("child-${path[0]}", "Child")) }
        None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "first" || id == "second") { scratch[0] = if (id == "first") { 0 } else { 1 }; return Some(scratch) }
        None
    }
}

class MaximalTreeSource <: TreeDataSource {
    public func rootCount(): Int64 { Int64.Max }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (path.size == 1) { return Some(LazyTreeNode("root-${path[0]}", "Root", childCount: if (path[0] == 0) { 2 } else { 0 })) }
        if (path.size == 2 && path[0] == 0) { return Some(LazyTreeNode("child-${path[1]}", "Child")) }
        None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "root-0") { return Some([0]) }
        if (id == "last-root") { return Some([Int64.Max - 1]) }
        None
    }
}

func dataPage(request: TablePageRequest, total: Int64): TablePage {
    let count = min(request.limit, max(0, total - request.offset))
    TablePage(Array<TableDataRow>(count, { i =>
        let index = request.offset + i
        TableDataRow("id-${index}", ["row-${index}"])
    }), total)
}

@Test
class CapabilityDataTest {
    @TestCase
    func millionRowsUseOnlyRequestedViewportPagesWithExternalQuery(): Unit {
        let model = PagedTableModel(pageSize: 32, maxPages: 2)
        _ = model.setQuery(TableQuery(filter: "server-filter", sortColumn: Some(0), descending: true))
        let requests = model.requestViewport(900000, 12)
        @Assert(requests.size, 1)
        @Expect(requests[0].offset, 900000)
        @Expect(requests[0].query.filter, "server-filter")
        @Expect(requests[0].query.descending)
        @Expect(model.accept(requests[0], dataPage(requests[0], 1000000)))
        let table = VirtualTable([TableColumn("Name", width: 18)], model)
        table.offset = 900000
        let buffer = Buffer(Rect(0, 0, 20, 13))
        table.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 1).symbol, "r")
        @Expect(model.cachedRowCount(), 32)
        @Expect(model.requestViewport(900000, 12).size, 0)
        for (page in 1..20) {
            let request = model.requestViewport(page * 32, 12)[0]
            @Expect(model.accept(request, dataPage(request, 1000000)))
            @Expect(model.cachedPageCount() <= 2)
        }
        @Expect(model.cachedRowCount(), 64)
    }

    @TestCase
    func stalePagesCannotOverwriteNewQueriesOrSupersedingRequests(): Unit {
        let model = PagedTableModel(pageSize: 4)
        let old = model.requestViewport(0, 4)[0]
        _ = model.setQuery(TableQuery(filter: "new"))
        let fresh = model.requestViewport(0, 4)[0]
        @Expect(!model.accept(old, dataPage(old, 100)))
        @Expect(!model.fail(old, "old failure"))
        @Expect(model.fail(fresh, "network unavailable"))
        match (model.statusAt(0)) { case TableStatus.Error(message) => @Expect(message, "network unavailable"); case _ => @Expect(false) }
        let retry = model.requestViewport(0, 4, retry: true)[0]
        @Expect(!model.accept(fresh, dataPage(fresh, 100)))
        @Expect(model.accept(retry, dataPage(retry, 100)))
        @Expect(model.row(0).getOrThrow().id, "id-0")
        let departed = model.requestViewport(20, 4)[0]
        _ = model.requestViewport(40, 4)
        @Expect(!model.accept(departed, dataPage(departed, 100)))
        @Expect(model.pendingPageCount(), 1)
    }

    @TestCase
    func concurrentPagesRejectTotalDriftUntilExplicitInvalidation(): Unit {
        let model = PagedTableModel(pageSize: 4, maxPages: 2)
        let requests = model.requestViewport(0, 8)
        @Assert(requests.size, 2)
        @Expect(model.accept(requests[1], dataPage(requests[1], 100)))
        @Expect(!model.accept(requests[0], dataPage(requests[0], 4)))
        @Expect(model.totalRows(), 100)
        match (model.statusAt(0)) { case TableStatus.Error(_) => @Expect(true); case _ => @Expect(false) }
        model.invalidate()
        let fresh = model.requestViewport(0, 4)[0]
        @Expect(model.accept(fresh, dataPage(fresh, 4)))
        @Expect(model.totalRows(), 4)
        @Expect(model.row(4).isNone())
        @Expect(model.cachedPageCount(), 1)
    }

    @TestCase
    func malformedPagesAreErrorsAndAcceptedRowsAreSnapshots(): Unit {
        let model = PagedTableModel(pageSize: 2)
        let first = model.requestViewport(0, 2)[0]
        @Expect(!model.accept(first, TablePage([TableDataRow("same", ["A"]), TableDataRow("same", ["B"])], 2)))
        @Expect(!model.hasTotal())
        let retry = model.requestViewport(0, 2, retry: true)[0]
        let page = dataPage(retry, 2)
        @Expect(model.accept(retry, page))
        page.rows[0].cells[0] = "mutated after publication"
        @Expect(model.row(0).getOrThrow().cells[0], "row-0")
    }

    @TestCase
    func lazyExpansionCopiesProviderPathsAndSaturatesUnrepresentableCounts(): Unit {
        let reused = ReusedPathTreeSource()
        let tree = LazyTreeModel(reused)
        @Expect(tree.setExpanded("first", true))
        @Expect(tree.setExpanded("second", true))
        @Expect(tree.rowAt(1).getOrThrow().node.id, "child-0")
        @Expect(tree.rowAt(3).getOrThrow().node.id, "child-1")
        let maximal = LazyTreeModel(MaximalTreeSource())
        @Expect(maximal.setExpanded("root-0", true))
        @Expect(maximal.visibleCount(), Int64.Max)
        @Expect(maximal.rowAt(Int64.Max - 1).getOrThrow().node.id, "root-${Int64.Max - 3}")
        @Expect(!maximal.selectById("last-root"))
        @Expect(maximal.rows(Int64.Max - 2, 10).size, 2)
    }

    @TestCase
    func stableRowSelectionSurvivesSortingAndCacheEviction(): Unit {
        let model = PagedTableModel(pageSize: 2, maxPages: 1)
        let first = model.requestViewport(0, 2)[0]
        _ = model.accept(first, dataPage(first, 20))
        model.selectIndex(1); model.toggle("id-1")
        let next = model.requestViewport(10, 2)[0]
        _ = model.accept(next, dataPage(next, 20))
        @Expect(model.selectedId(), Some("id-1"))
        @Expect(model.isSelected("id-1"))
        let table = VirtualTable([TableColumn("Name")], model)
        _ = table.handle(KeyEvent(KeyCode.Right), 2)
        @Expect(model.selectedId(), Some("id-1"))
        _ = table.handle(KeyEvent(KeyCode.Char(r' ')), 2)
        @Expect(!model.isSelected("id-1"))
        model.toggle("id-1")
        _ = model.setQuery(TableQuery(sortColumn: Some(0), descending: true))
        let sorted = model.requestViewport(0, 2)[0]
        _ = model.accept(sorted, TablePage([TableDataRow("id-1", ["one"]), TableDataRow("id-0", ["zero"])], 20))
        @Expect(model.selectedIndex(), Some(0))
        @Expect(model.selectedId(), Some("id-1"))
        @Expect(model.isSelected("id-1"))
    }

    @TestCase
    func widgetQueryMutationsPreserveTheModelsOtherQueryFields(): Unit {
        let model = PagedTableModel()
        let table = VirtualTable([TableColumn("Name")], model)
        _ = model.setQuery(TableQuery(filter: "canonical"))
        table.sortBy(0, descending: true)
        @Expect(model.query().filter, "canonical")
        table.setFilter("updated")
        @Expect(model.query().sortColumn, Some(0))
        @Expect(model.query().descending)
        table.clearSort()
        @Expect(model.query().filter, "updated")
        @Expect(model.query().sortColumn.isNone())
    }

    @TestCase
    func synchronousRowCacheAndMouseInteractionsRemainBounded(): Unit {
        let table = VirtualTable([TableColumn("A", width: 5)], 1000000, { i => ["${i}"] }, cacheCapacity: 16)
        let buffer = Buffer(Rect(0, 0, 8, 5))
        for (page in 0..20) { table.offset = page * 4; table.render(buffer.area, buffer) }
        @Expect(table.cachedRowCount() <= 16)
        table.offset = 0
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 2), buffer.area))
        @Expect(table.selectedRow, Some(1))
        @Expect(table.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 1, 2), buffer.area))
        @Expect(table.offset, 3)
        @Expect(!table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 20, 2), buffer.area))
    }

    @TestCase
    func millionLazyChildrenReadOnlyViewportAndKeepSelectionById(): Unit {
        let source = MillionTreeSource()
        let model = LazyTreeModel(source)
        @Expect(model.visibleCount(), 1)
        @Expect(source.reads, 0)
        @Expect(model.setExpanded("root", true))
        @Expect(model.visibleCount(), 1000001)
        @Expect(model.selectById("node-999999"))
        let tree = Tree(model)
        tree.offset = 999991
        source.reads = 0
        let buffer = Buffer(Rect(0, 0, 24, 10))
        tree.render(buffer.area, buffer)
        @Expect(source.reads, 10)
        @Expect(model.selectedId(), Some("node-999999"))
        @Expect(model.selectedIndex(), Some(1000000))
        _ = model.setExpanded("root", false)
        @Expect(model.selectedIndex().isNone())
        _ = model.setExpanded("root", true)
        @Expect(model.selectedIndex(), Some(1000000))
    }

    @TestCase
    func eagerTreeMouseAndExpansionKeepRecordSelectionStable(): Unit {
        let root = TreeNode("root", "Root", children: [TreeNode("a", "A"), TreeNode("b", "B")])
        let tree = Tree([root, TreeNode("sibling", "Sibling")])
        @Expect(tree.selectById("sibling"))
        root.expanded = true
        @Expect(tree.selectedId(), Some("sibling"))
        @Expect(tree.selected, 3)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 8, 2), Rect(0, 0, 20, 5)))
        @Expect(tree.selectedId(), Some("b"))
        root.expanded = false
        @Expect(tree.selectedId(), Some("b"))
        @Expect(tree.selected, -1)
        root.expanded = true
        @Expect(tree.selectedId(), Some("b"))
        @Expect(tree.selected, 2)
    }

    @TestCase
    func lazyTreeMouseUsesStableIdsAndExpandsOnlyRequestedBranch(): Unit {
        let source = MillionTreeSource()
        let model = LazyTreeModel(source)
        let tree = Tree(model)
        let area = Rect(0, 0, 24, 8)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
        @Expect(model.visibleCount(), 1000001)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 8, 2), area))
        @Expect(tree.selectedId(), Some("node-1"))
        @Expect(tree.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 8, 2), area))
        @Expect(tree.offset, 3)
        @Expect(source.reads < 10)
    }
}
