package core

import std.unittest.*
import std.unittest.testmacro.*

// A changing indexed provider exercises stable identity independently of its
// current path. Rows may disappear between a path lookup and node lookup.
class RevisionTreeSource <: TreeDataSource {
    var missing: Bool = false
    var swapped: Bool = false
    public func rootCount(): Int64 { 3 }
    public func pathForId(id: String): ?Array<Int64> {
        match (id) {
            case "a" => Some([0])
            case "b" => Some([1])
            case "c" => Some([2])
            case "a0" => Some([0, 0])
            case "a1" => Some([0, 1])
            case "leaf" => Some([0, 0, 0])
            case "b0" => Some([1, 0])
            case "empty-path" => Some([])
            case "negative" => Some([-1])
            case "past-end" => Some([3])
            case _ => None
        }
    }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (missing || path.isEmpty()) { return None }
        if (path.size == 1) {
            if (path[0] == 0) { return Some(LazyTreeNode(if (swapped) { "replacement" } else { "a" }, "A", childCount: 2)) }
            if (path[0] == 1) { return Some(LazyTreeNode("b", "B", childCount: 1)) }
            if (path[0] == 2) { return Some(LazyTreeNode("c", "C")) }
        }
        if (path.size == 2 && path[0] == 0) {
            if (path[1] == 0) { return Some(LazyTreeNode("a0", "A0", childCount: 1)) }
            if (path[1] == 1) { return Some(LazyTreeNode("a1", "A1")) }
        }
        if (path.size == 2 && path[0] == 1 && path[1] == 0) { return Some(LazyTreeNode("b0", "B0")) }
        if (path.size == 3 && path[0] == 0 && path[1] == 0 && path[2] == 0) { return Some(LazyTreeNode("leaf", "Leaf")) }
        None
    }
}

@Test
class DataSourceBoundaryTest {
    @TestCase
    func rejectedPagesCanBeRetriedWithoutPublishingPartialRows(): Unit {
        let model = PagedTableModel(pageSize: 2, maxPages: 1)
        let invalid = [
            TablePage([], -1), TablePage([], 2),
            TablePage([TableDataRow("", ["empty id"]), TableDataRow("b", ["b"])], 2)
        ]
        for (page in invalid) {
            let request = model.requestViewport(0, 2, retry: true)[0]
            @Expect(model.isPending(request))
            @Expect(!model.accept(request, page))
            @Expect(!model.isPending(request))
            @Expect(!model.hasTotal())
            @Expect(model.cachedRowCount(), 0)
            @Expect(model.requestViewport(0, 2).isEmpty())
            match (model.statusAt(0)) { case TableStatus.Error(_) => (); case _ => @Expect(false) }
        }
        let request = model.requestViewport(0, 2, retry: true)[0]
        @Expect(model.accept(request, dataPage(request, 2)))
        @Expect(!model.accept(request, dataPage(request, 2)))
        @Expect(!model.fail(request, "late error"))
        match (model.statusAt(0)) { case TableStatus.Ready => (); case _ => @Expect(false) }
        @Expect(model.row(-1).isNone())
        @Expect(model.row(2).isNone())
    }

    @TestCase
    func emptyAndExtremeViewportsStayBounded(): Unit {
        let model = PagedTableModel(pageSize: 0, maxPages: 0)
        @Expect(model.pageSize, 1)
        @Expect(model.maxPages, 1)
        let first = model.requestViewport(-10, 0)[0]
        @Expect(first.offset, 0)
        @Expect(model.requestViewport(0, 1).isEmpty())
        @Expect(model.accept(first, TablePage([], 0)))
        match (model.statusAt(0)) { case TableStatus.Empty => (); case _ => @Expect(false) }
        @Expect(model.requestViewport(0, Int64.Max).isEmpty())
        model.invalidate()
        let last = model.requestViewport(Int64.Max, Int64.Max)[0]
        @Expect(last.offset, Int64.Max)
        @Expect(model.pendingPageCount(), 1)
        @Expect(model.accept(last, TablePage([], Int64.Max)))
        @Expect(model.cachedRowCount(), 0)
    }

    @TestCase
    func selectionBeforeLoadAndRefreshIsResolvedByIdentity(): Unit {
        let model = PagedTableModel(pageSize: 2, maxPages: 2)
        model.selectIndex(1)
        @Expect(model.selectedIndex(), Some(1))
        @Expect(model.selectedId().isNone())
        let requests = model.requestViewport(0, 4)
        @Expect(model.accept(requests[0], dataPage(requests[0], 4)))
        @Expect(model.selectedId(), Some("id-1"))
        @Expect(model.accept(requests[1], dataPage(requests[1], 4)))
        model.selectId("id-3")
        @Expect(model.selectedIndex(), Some(3))
        model.toggle("id-3")
        @Expect(model.selectedIds().size, 1)
        model.toggle("id-3")
        @Expect(model.selectedIds().isEmpty())
        model.selectId("not-loaded")
        @Expect(model.selectedIndex().isNone())
        @Expect(model.selectedId(), Some("not-loaded"))
        model.selectIndex(-1)
        @Expect(model.selectedId().isNone())
        model.selectIndex(4)
        @Expect(model.selectedIndex().isNone())
        let revision = model.revision()
        @Expect(!model.setQuery(TableQuery()))
        @Expect(model.revision(), revision)
        model.invalidate()
        model.selectIndex(100)
        let fresh = model.requestViewport(0, 2)[0]
        @Expect(model.accept(fresh, dataPage(fresh, 1)))
        @Expect(model.selectedIndex().isNone())
    }

    @TestCase
    func viewportDepartureForgetsErrorsAndRejectsSupersededWork(): Unit {
        let model = PagedTableModel(pageSize: 2, maxPages: 2)
        let requests = model.requestViewport(0, 4)
        @Expect(model.fail(requests[0], "offline"))
        let moved = model.requestViewport(10, 2)
        @Expect(!model.isPending(requests[1]))
        @Expect(!model.accept(requests[1], dataPage(requests[1], 20)))
        match (model.statusAt(0)) { case TableStatus.Loading => (); case _ => @Expect(false) }
        @Expect(model.accept(moved[0], dataPage(moved[0], 20)))
        @Expect(model.requestViewport(0, 2).size, 1)
        @Expect(model.cachedPageCount(), 1)
    }

    @TestCase
    func nestedLazyBranchesOrderCollapseAndRefreshPreserveSelection(): Unit {
        let tree = LazyTreeModel(RevisionTreeSource())
        @Expect(tree.selectedIndex().isNone())
        @Expect(!tree.toggleSelected())
        @Expect(!tree.setExpanded("a0", true))
        @Expect(tree.setExpanded("b", true))
        @Expect(tree.setExpanded("a", true))
        @Expect(tree.setExpanded("a0", true))
        @Expect(tree.visibleCount(), 7)
        let expected = ["a", "a0", "leaf", "a1", "b", "b0", "c"]
        let rows = tree.rows(-1, 20)
        @Expect(rows.size, expected.size)
        for (i in 0..expected.size) {
            @Expect(rows[i].node.id, expected[i])
            @Expect(tree.selectById(expected[i]))
            @Expect(tree.selectedIndex(), Some(i))
        }
        @Expect(tree.selectIndex(2))
        @Expect(tree.selectedId(), Some("leaf"))
        @Expect(tree.setExpanded("a", false))
        @Expect(tree.selectedIndex().isNone())
        @Expect(tree.selectedId(), Some("leaf"))
        @Expect(tree.setExpanded("a", true))
        @Expect(tree.setExpanded("a0", true))
        @Expect(tree.selectedIndex(), Some(2))
        tree.collapseAll()
        @Expect(tree.visibleCount(), 3)
        @Expect(tree.selectById("b"))
        @Expect(tree.toggleSelected())
        @Expect(tree.visibleCount(), 4)
        tree.refresh()
        @Expect(tree.visibleCount(), 3)
        @Expect(tree.selectedId(), Some("b"))
        @Expect(tree.selectedIndex(), Some(1))
    }

    @TestCase
    func lazyMissingAndInvalidPathsNeverCreatePhantomSelections(): Unit {
        let source = RevisionTreeSource()
        let tree = LazyTreeModel(source)
        for (id in ["unknown", "empty-path", "negative", "past-end"]) {
            @Expect(!tree.selectById(id))
            @Expect(!tree.setExpanded(id, true))
        }
        @Expect(tree.rowAt(-1).isNone())
        @Expect(tree.rowAt(3).isNone())
        @Expect(!tree.selectIndex(3))
        @Expect(tree.rows(0, 0).isEmpty())
        @Expect(tree.setExpanded("c", true))
        @Expect(tree.setExpanded("c", false))
        @Expect(tree.setExpanded("a", true))
        @Expect(tree.setExpanded("a", true))
        @Expect(tree.visibleCount(), 5)
        @Expect(tree.findById("leaf").isSome())
        @Expect(tree.findById("unknown").isNone())
        source.missing = true
        @Expect(tree.findById("a").isNone())
        @Expect(tree.rows(0, 5).isEmpty())
        @Expect(!tree.setExpanded("b", true))
        @Expect(!tree.selectById("a"))
        source.missing = false
        source.swapped = true
        @Expect(tree.findById("a").isNone())
        @Expect(!tree.selectById("a"))
        @Expect(!tree.setExpanded("a", true))
    }
}
