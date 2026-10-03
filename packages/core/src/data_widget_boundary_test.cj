package core

import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DataWidgetBoundaryTest {
    @TestCase
    func emptyTablesAndHeaderlessMouseInputKeepNavigationWithinBounds(): Unit {
        let empty = VirtualTable([], 0, {_ => Array<String>()})
        for (key in [KeyCode.Up, KeyCode.Down, KeyCode.PageUp, KeyCode.PageDown, KeyCode.Left, KeyCode.Right, KeyCode.Home, KeyCode.End, KeyCode.Char(r' ')]) {
            @Expect(empty.handle(KeyEvent(key), 0))
            @Expect(empty.selectedColumn, 0)
            @Expect(empty.offset, 0)
        }
        let rect = Rect(0, 0, 10, 3)
        empty.render(rect, Buffer(rect))
        @Expect(!empty.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), rect))
        let scroll = ScrollState()
        let table = VirtualTable([TableColumn("value")], 5, {i => ["${i}"]}, scrollState: Some(scroll))
        table.stickyHeader = false
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), rect))
        @Expect(table.selectedRow, Some(0))
        @Expect(table.sortColumn.isNone())
        @Expect(table.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 0, 0), rect))
        @Expect(scroll.offset, 2)
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Home), rect).isSome())
        @Expect(table.dirtyRows(rect, [0]).rects(), [Rect(0, 0, 10, 1)])
    }

    @TestCase
    func pagedModelsRejectEveryConflictingLegacyOwner(): Unit {
        var rejected = 0
        try { _ = VirtualTable([], 0, {_ => Array<String>()}, dataModel: Some(PagedTableModel()), sortState: Some(SortState())) }
        catch (_: IllegalArgumentException) { rejected++ }
        try { _ = VirtualTable([], 0, {_ => Array<String>()}, dataModel: Some(PagedTableModel()), filterState: Some(FilterState())) }
        catch (_: IllegalArgumentException) { rejected++ }
        try { _ = VirtualTable([], 0, {_ => Array<String>()}, dataModel: Some(PagedTableModel()), selectionModel: Some(SelectionModel())) }
        catch (_: IllegalArgumentException) { rejected++ }
        @Expect(rejected, 3)
    }

    @TestCase
    func filePickerRefreshDoesNotInventAnEntryForAStaleSelection(): Unit {
        let picker = FilePicker(path: "tests/fixtures/file_picker")
        @Expect(picker.handle(KeyEvent(KeyCode.End), 3))
        @Expect(picker.selectedEntry().isSome())
        picker.searchText = "termcanvas-no-matching-file"
        picker.refresh()
        @Expect(picker.selectedEntry().isNone())
        @Expect(picker.selectedPath().isNone())
        @Expect(picker.selectedInfo().isNone())
        @Expect(!picker.enterSelected())
        picker.setSearch("")
        @Expect(picker.selectedEntry(), Some(".."))
    }

    @TestCase
    func paginatorClampsEmptyAndPartialLastPagesAcrossNavigation(): Unit {
        let empty = Paginator(page: 8, pageSize: 0, total: -1)
        @Expect(empty.pageCount(), 0)
        @Expect(empty.pageSize, 1)
        for (key in [KeyCode.Right, KeyCode.PageDown, KeyCode.End, KeyCode.Left, KeyCode.PageUp, KeyCode.Home]) {
            @Expect(empty.handle(KeyEvent(key)))
            @Expect(empty.offset(), 0)
        }
        @Expect(!empty.handle(KeyEvent(KeyCode.Esc)))
        let pages = Paginator(page: 99, pageSize: 3, total: 7)
        @Expect(pages.pageCount(), 3)
        @Expect(pages.offset(), 6)
        pages.next()
        @Expect(pages.offset(), 6)
        pages.previous()
        @Expect(pages.offset(), 3)
        @Expect(pages.handle(KeyEvent(KeyCode.Home)))
        pages.previous()
        @Expect(pages.offset(), 0)
    }

    @TestCase
    func legacyTreeNavigationPreservesSelectionAndScrollAtBothEnds(): Unit {
        let branch = TreeNode("branch", "branch", children: [TreeNode("leaf", "leaf")])
        let tree = Tree([branch, TreeNode("tail", "tail")])
        @Expect(tree.handle(KeyEvent(KeyCode.Right), 1))
        @Expect(branch.expanded)
        @Expect(tree.handle(KeyEvent(KeyCode.Down), 1))
        @Expect(tree.selectedId(), Some("leaf"))
        @Expect(tree.offset, 1)
        @Expect(tree.handle(KeyEvent(KeyCode.Down), 1))
        @Expect(tree.selectedId(), Some("tail"))
        @Expect(tree.offset, 2)
        @Expect(tree.handle(KeyEvent(KeyCode.Up), 1))
        @Expect(tree.selectedId(), Some("leaf"))
        @Expect(tree.offset, 1)
        @Expect(tree.handle(KeyEvent(KeyCode.Up), 1))
        @Expect(tree.handle(KeyEvent(KeyCode.Left), 1))
        @Expect(!branch.expanded)
        @Expect(tree.handle(KeyEvent(KeyCode.Enter), 1))
        @Expect(branch.expanded)
        @Expect(tree.handle(KeyEvent(KeyCode.Char(r' ')), 1))
        @Expect(!branch.expanded)
        @Expect(!tree.handle(KeyEvent(KeyCode.Esc), 1))
        tree.expandAll()
        @Expect(tree.findById("leaf").isSome())
        @Expect(tree.findById("missing").isNone())
        @Expect(!tree.selectById("missing"))
        let rect = Rect(0, 0, 15, 5)
        tree.render(rect, Buffer(rect))
        tree.collapseAll()
        @Expect(tree.offset, 0)
        @Expect(tree.selectedId(), Some("branch"))
        let empty = Tree([])
        empty.toggleSelected(); empty.expandSelected(); empty.collapseSelected()
        @Expect(empty.selectedId().isNone())
        @Expect(!empty.selectById("missing"))
        empty.render(Rect(0, 0, 0, 0), Buffer(Rect(0, 0, 0, 0)))
    }

    @TestCase
    func lazyTreeKeyboardRoutesEveryNavigationOperationThroughStableIds(): Unit {
        let source = RevisionTreeSource()
        let model = LazyTreeModel(source)
        let tree = Tree(model)
        @Expect(tree.selectedId(), Some("a"))
        @Expect(tree.handle(KeyEvent(KeyCode.Right), 2))
        @Expect(model.visibleCount(), 5)
        @Expect(tree.handle(KeyEvent(KeyCode.Down), 2))
        @Expect(tree.selectedId(), Some("a0"))
        @Expect(tree.handle(KeyEvent(KeyCode.Right), 2))
        @Expect(model.visibleCount(), 6)
        @Expect(tree.handle(KeyEvent(KeyCode.PageDown), 2))
        @Expect(tree.selectedId(), Some("a1"))
        @Expect(tree.handle(KeyEvent(KeyCode.PageUp), 2))
        @Expect(tree.selectedId(), Some("a0"))
        @Expect(tree.handle(KeyEvent(KeyCode.Left), 2))
        @Expect(model.visibleCount(), 5)
        @Expect(tree.handle(KeyEvent(KeyCode.Up), 2))
        @Expect(tree.selectedId(), Some("a"))
        @Expect(tree.handle(KeyEvent(KeyCode.End), 2))
        @Expect(tree.selectedId(), Some("c"))
        @Expect(tree.offset, 3)
        @Expect(tree.handle(KeyEvent(KeyCode.Home), 2))
        @Expect(tree.offset, 0)
        @Expect(tree.handle(KeyEvent(KeyCode.Enter), 2))
        @Expect(model.visibleCount(), 3)
        @Expect(tree.handle(KeyEvent(KeyCode.Char(r' ')), 2))
        @Expect(model.visibleCount(), 5)
        @Expect(!tree.handle(KeyEvent(KeyCode.Esc), 2))
        @Expect(tree.selectById("b"))
        @Expect(tree.selected, 3)
        @Expect(!tree.selectById("missing"))
        var forbidden = 0
        try { tree.expandAll() } catch (_: IllegalStateException) { forbidden++ }
        try { _ = tree.findById("b") } catch (_: IllegalStateException) { forbidden++ }
        @Expect(forbidden, 2)
        tree.collapseAll()
        @Expect(model.visibleCount(), 3)
        @Expect(tree.offset, 0)
        let rect = Rect(0, 0, 15, 6)
        tree.render(rect, Buffer(rect))
    }

    @TestCase
    func treeMouseSeparatesDisclosureLabelAndWheelActions(): Unit {
        let root = TreeNode("root", "root", children: [TreeNode("child", "child")])
        let tree = Tree([root, TreeNode("second", "second"), TreeNode("third", "third")])
        let rect = Rect(2, 2, 12, 2)
        @Expect(!tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 2), rect))
        @Expect(!tree.handle(MouseEvent(MouseKind.Up, MouseButton.Left, 4, 2), rect))
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 2), rect))
        @Expect(!root.expanded)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 2), rect))
        @Expect(root.expanded)
        @Expect(tree.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 4, 2), rect))
        @Expect(tree.offset, 2)
        @Expect(tree.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 4, 2), rect))
        @Expect(tree.offset, 0)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 7, 3), rect))
        @Expect(tree.selectedId(), Some("child"))
        let lazy = Tree(LazyTreeModel(RevisionTreeSource()), block: Block())
        let framed = Rect(0, 0, 12, 5)
        @Expect(!lazy.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), framed))
        @Expect(lazy.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), framed))
        lazy.render(framed, Buffer(framed))
        @Expect(lazy.selectedId(), Some("a"))
    }

    @TestCase
    func tableLocalMultiSelectionSurvivesSortAndTogglesOffBySourceIdentity(): Unit {
        let rows = [["b", "two"], ["a", "one"], ["c", "three"]]
        let table = VirtualTable([TableColumn("key"), TableColumn("value")], 3, {i => rows[i]})
        table.toggleSelectedRow()
        @Expect(table.selectedRowIndices().isEmpty())
        table.selectedRow = Some(0); table.toggleSelectedRow()
        table.selectedRow = Some(2); table.toggleSelectedRow()
        @Expect(table.selectedRowIndices(), [0, 2])
        table.selectedRow = Some(2); table.toggleSelectedRow()
        @Expect(table.selectedRowIndices(), [0])
        @Expect(!table.isSelected(2))
        table.sortBy(0)
        table.selectedRow = Some(1); table.toggleSelectedRow()
        @Expect(table.selectedRowIndices().isEmpty())
        table.selectedRow = Some(-1); table.toggleSelectedRow()
        table.selectedRow = Some(100); table.toggleSelectedRow()
        @Expect(table.selectedRowIndices().isEmpty())
        table.clearSort()
        table.setFilter("no-match")
        table.selectedRow = Some(0); table.toggleSelectedRow()
        @Expect(table.selectedRowIndices().isEmpty())
    }

    @TestCase
    func tableDirtyRegionsCoverStatusScrollingAndEmptyViewports(): Unit {
        let table = VirtualTable([TableColumn("A", width: 3), TableColumn("B", width: 3), TableColumn("C", width: 3)], 10, {i => ["${i}", "b", "c"]})
        let rect = Rect(0, 0, 5, 3)
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Esc), rect).isNone())
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Down), Rect(0, 0, 0, 3)).isNone())
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Down), Rect(0, 0, 5, 1)).isNone())
        @Expect(table.dirtyHeader(Rect(0, 0, 0, 3)).isEmpty())
        @Expect(table.dirtyBody(Rect(0, 0, 5, 0)).isEmpty())
        @Expect(table.dirtyRows(Rect(0, 0, 0, 3), [0]).isEmpty())
        @Expect(table.dirtySelectionChange(rect, None, None).rects(), [rect])
        @Expect(table.dirtyRows(rect, [-1, 99]).rects(), [rect])
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.End), rect).isSome())
        @Expect(table.offset, 8)
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Home), rect).isSome())
        @Expect(table.offset, 0)
        @Expect(table.handleWithDirty(KeyEvent(KeyCode.Right), rect).getOrThrow().rects(), [rect])
        table.stickyHeader = false
        @Expect(table.dirtyHeader(rect).isEmpty())
        @Expect(table.dirtyBody(rect).rects(), [rect])
        @Expect(table.dirtyStatus(rect).rects(), [rect])
    }

    @TestCase
    func tableMouseHeaderBodyGapsAndFrozenColumnsRemainDistinct(): Unit {
        let table = VirtualTable([TableColumn("A", width: 2), TableColumn("B", width: 2), TableColumn("C", width: 2)], 8, {i => ["${i}", "b", "c"]})
        let rect = Rect(0, 0, 12, 4)
        @Expect(!table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, -1, 0), rect))
        @Expect(!table.handle(MouseEvent(MouseKind.Up, MouseButton.Left, 1, 1), rect))
        @Expect(!table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 1), rect))
        @Expect(!table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 11, 1), rect))
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 0), rect))
        @Expect(table.sortColumn, Some(1))
        @Expect(!table.sortDescending)
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 0), rect))
        @Expect(table.sortDescending)
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 1, modifiers: KeyModifier(ctrl: true)), rect))
        @Expect(table.selectedColumn, 1)
        @Expect(table.selectedRowIndices().size, 1)
        @Expect(table.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 1, 2), rect))
        @Expect(table.offset, 3)
        @Expect(table.handle(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 1, 2), rect))
        @Expect(table.offset, 0)
        table.setFrozenColumns(1)
        table.selectedColumn = 2; table.columnOffset = 2
        let narrow = Rect(0, 0, 5, 3)
        table.render(narrow, Buffer(narrow))
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 1), narrow))
        @Expect(table.selectedColumn, 2)
        @Expect(!table.resizeColumn(-1, 1))
        @Expect(!table.resizeColumn(3, 1))
        @Expect(table.resizeColumn(1, 0))
    }

    @TestCase
    func tableStatusAndShortRowsRenderWithoutReadingMissingCells(): Unit {
        let table = VirtualTable([TableColumn("A", width: 2), TableColumn("B", width: 2), TableColumn("C", width: 2)], 2, {_ => ["a"]}, selectedRow: Some(0))
        let rect = Rect(0, 0, 12, 4)
        table.selectedColumn = 2
        table.render(rect, Buffer(rect))
        @Expect(table.columnOffset, 0)
        table.setFrozenColumns(3)
        table.render(Rect(0, 0, 1, 2), Buffer(Rect(0, 0, 1, 2)))
        table.setFrozenColumns(0)
        for ((status, first) in [(TableStatus.Empty, "N"), (TableStatus.Loading, "L"), (TableStatus.Error("Failed"), "F")]) {
            table.setStatus(status)
            let buffer = Buffer(rect)
            table.render(rect, buffer)
            @Expect(buffer.getCell(0, 1).symbol, first)
        }
        table.setStatus(TableStatus.Ready)
        table.setFilter("missing")
        let filtered = Buffer(rect)
        table.render(rect, filtered)
        @Expect(filtered.getCell(0, 1).symbol, "N")
        table.render(Rect(0, 0, 12, 1), Buffer(Rect(0, 0, 12, 1)))
        let empty = VirtualTable([], 0, {_ => Array<String>()}, block: Block())
        empty.render(Rect(0, 0, 1, 1), Buffer(Rect(0, 0, 1, 1)))
        @Expect(!empty.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), rect))
    }

    @TestCase
    func tableBindingsPublishSortFilterSelectionAndScrollChanges(): Unit {
        let sort = SortState()
        let filter = FilterState()
        let scroll = ScrollState(offset: 4)
        let selected = SelectionModel(mode: SelectionMode.Multiple)
        let table = VirtualTable([TableColumn("name")], 6, {i => ["row${i}"]},
            sortState: Some(sort), filterState: Some(filter), scrollState: Some(scroll), selectionModel: Some(selected))
        table.sortBy(10, descending: true)
        @Expect(sort.column, Some(0)); @Expect(sort.descending); @Expect(scroll.offset, 0)
        table.clearSort()
        @Expect(sort.column.isNone())
        table.setFilter("row")
        @Expect(filter.query, "row")
        table.selectedRow = Some(2); table.toggleSelectedRow()
        @Expect(selected.isSelected(2)); @Expect(table.isSelected(2))
        @Expect(table.selectedRowIndices(), [2])
        @Expect(table.handle(KeyEvent(KeyCode.End), 2))
        @Expect(scroll.offset, 4)
        @Expect(table.handle(KeyEvent(KeyCode.PageUp), 2))
        @Expect(table.selectedRow, Some(3))
        @Expect(table.handle(KeyEvent(KeyCode.Left), 2))
        @Expect(table.handle(KeyEvent(KeyCode.Right), 2))
    }

    @TestCase
    func pagedTableShowsLoadingAndFailedHolesWithoutFabricatingRows(): Unit {
        let model = PagedTableModel(pageSize: 1)
        let first = model.requestViewport(0, 1)[0]
        @Expect(model.accept(first, TablePage([TableDataRow("one", ["one"])], 3)))
        let pending = model.requestViewport(1, 1)[0]
        @Expect(model.fail(pending, "failed page"))
        let table = VirtualTable([TableColumn("name", width: 12)], model)
        let rect = Rect(0, 0, 12, 4)
        let buffer = Buffer(rect)
        table.render(rect, buffer)
        @Expect(buffer.getCell(0, 1).symbol, "o")
        @Expect(buffer.getCell(0, 2).symbol, "f")
        @Expect(buffer.getCell(0, 3).symbol, "L")
        @Expect(table.handle(KeyEvent(KeyCode.Home), 3))
        table.toggleSelectedRow()
        @Expect(model.isSelected("one"))
        @Expect(table.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 1), rect))
        @Expect(model.selectedId(), Some("one"))
        table.clearCachedRows()
        @Expect(table.cachedRowCount(), 0)
        table.toggleSelectedRow()
        table.sortBy(0); @Expect(model.query().sortColumn, Some(0))
        table.clearSort(); @Expect(model.query().sortColumn.isNone())
        table.setFilter("abc"); @Expect(model.query().filter, "abc")
    }

    @TestCase
    func filePickerNavigationAndLexicalParentEdgesStayPredictable(): Unit {
        // Exercise lexical roots without enumerating the host's root drive.
        for ((path, expected) in [("/", "/"), ("/.", "/"), ("x/.", "."), ("x/./", "."), ("x/..", "x/../.."), ("x///", "."), (".", ".."), ("", "..")]) {
            @Expect(parentPath(path), expected)
        }
        let marker = File.createTemp(getTempDirectory())
        let markerPath = marker.info.path.toString().replace("\\", "/")
        marker.close()
        let base = markerPath + "-picker"
        try {
            Directory.create(base)
            Directory.create(base + "/$first")
            Directory.create(base + "/x")
            File.writeTo(base + "/note.txt", "fixture".toArray())
            let picker = FilePicker(path: base, showHidden: true)
            @Expect(picker.selectedEntry(), Some(".."))
            @Expect(picker.handle(KeyEvent(KeyCode.Down), 2))
            @Expect(picker.selectedEntry(), Some("$first"))
            @Expect(picker.selectedPath(), Some(base + "/$first"))
            @Expect(picker.handle(KeyEvent(KeyCode.Enter), 2))
            @Expect(picker.path, base + "/$first")
            @Expect(picker.selectedPath(), Some(base))
            @Expect(picker.parent())
            @Expect(picker.path, base)
            @Expect(picker.handle(KeyEvent(KeyCode.End), 2))
            @Expect(picker.selectedEntry(), Some("note.txt"))
            @Expect(picker.handle(KeyEvent(KeyCode.Up), 2))
            @Expect(picker.selectedEntry(), Some("x"))
            @Expect(picker.handle(KeyEvent(KeyCode.PageUp), 2))
            @Expect(picker.selectedEntry(), Some(".."))
            @Expect(picker.handle(KeyEvent(KeyCode.PageDown), 2))
            @Expect(picker.selectedEntry(), Some("x"))
            @Expect(picker.handle(KeyEvent(KeyCode.Home), 2))
            @Expect(picker.selectedEntry(), Some(".."))
            @Expect(picker.selectedInfo().getOrThrow().isDir)
            @Expect(!picker.handle(KeyEvent(KeyCode.Esc), 2))
            // Enter on the parent item stays inside the owned fixture.
            let child = FilePicker(path: base + "/x")
            @Expect(child.handle(KeyEvent(KeyCode.Enter), 2))
            @Expect(child.path, base)
            for ((suffix, expected) in [("/x/.", base), ("/x/./", base), ("/x/..", base + "/x/../.."), ("/x///", base)]) {
                let lexical = FilePicker(path: base + suffix)
                @Expect(lexical.selectedPath(), Some(expected))
                @Expect(lexical.parent())
                @Expect(lexical.path, expected)
            }
            child.path = "/"
            @Expect(!child.parent())
            @Expect(child.path, "/")
        } finally {
            _ = removeIfExists(base + "/note.txt")
            _ = removeIfExists(base + "/$first")
            _ = removeIfExists(base + "/x")
            _ = removeIfExists(base)
            _ = removeIfExists(markerPath)
        }
    }
}
