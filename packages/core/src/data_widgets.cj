package core

import std.collection.*
import std.fs.*
import std.sort.*

/** 管理零起始的分页索引。
 */
public class Paginator {
    /** 当前页索引。
     */
    public var page: Int64
    /** 每页项目数。
     */
    public var pageSize: Int64
    /** 项目总数。
     */
    public var total: Int64

    /** 创建分页状态。
     * @param page 初始页，限制到可用范围
     * @param pageSize 每页项目数，至少为一
     * @param total 项目总数，负值按零处理
     */
    public init(page!: Int64 = 0, pageSize!: Int64 = 10, total!: Int64 = 0) {
        this.pageSize = max(1, pageSize)
        this.total = max(0, total)
        let pages = if (this.total <= 0) { 0 } else { (this.total - 1) / this.pageSize + 1 }
        this.page = clamp(page, 0, max(0, pages - 1))
    }

    /** 计算页数。
     * @return 总数非正时为零。
     */
    public func pageCount(): Int64 {
        if (total <= 0) { return 0 }
        (total - 1) / pageSize + 1
    }

    /** 计算当前页起始索引。
     * @return 页索引乘每页大小。
     */
    public func offset(): Int64 {
        page * pageSize
    }

    /** 移动到下一页并限制在末页。
     */
    public func next(): Unit {
        page = min(max(0, pageCount() - 1), page + 1)
    }

    /** 移动到上一页并限制在首页。
     */
    public func previous(): Unit {
        page = max(0, page - 1)
    }

    /** 处理左右、翻页、首页和末页按键。
     * @param key 键盘事件
     * @return 支持的按键返回 true。
     */
    public func handle(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.PageDown | KeyCode.Right =>
                next()
                true
            case KeyCode.PageUp | KeyCode.Left =>
                previous()
                true
            case KeyCode.Home =>
                page = 0
                true
            case KeyCode.End =>
                page = max(0, pageCount() - 1)
                true
            case _ => false
        }
    }
}

/** 表格列标题、宽度和对齐方式。
 */
public class TableColumn {
    /** 列标题。
     */
    public let title: String
    /** 列宽。
     */
    public var width: Int64
    /** 文本对齐方式。
     */
    public let align: TextAlign

    /** 创建列配置。
     * @param title 列标题
     * @param width 列宽，构造时至少为一
     * @param align 文本对齐方式
     */
    public init(title: String, width!: Int64 = 10, align!: TextAlign = TextAlign.Left) {
        this.title = title
        this.width = max(1, width)
        this.align = align
    }
}

/** 表格数据的显示状态。
 */
public enum TableStatus {
    /** 显示数据。
     */
    | Ready
    /** 显示空状态。
     */
    | Empty
    /** 显示加载状态。
     */
    | Loading
    /** 显示错误信息。
     * @param _0 错误信息文本
     */
    | Error(String)
}

public class VirtualTable <: Widget {
    private let columns: Array<TableColumn>
    private let rowCount: Int64
    private let rowAt: (Int64) -> Array<String>
    public var offset: Int64
    public var selectedRow: ?Int64
    public var selectedColumn: Int64
    public var columnOffset: Int64
    public var frozenColumns: Int64 = 0
    public var sortColumn: ?Int64 = None
    public var sortDescending: Bool = false
    public var filterText: String = ""
    public var stickyHeader: Bool = true
    public var status: TableStatus = TableStatus.Ready
    public var emptyText: String = "No rows"
    public var loadingText: String = "Loading"
    private let selectedRows = ArrayList<Int64>()
    private let rowCache = HashMap<Int64, Array<String>>()
    private let cacheOrder = ArrayList<Int64>()
    private let cacheCapacity: Int64
    private let dataModel: ?PagedTableModel
    private var cachedVisibleIndices: ?Array<Int64> = None
    private var cachedVisibleFilterText: String = ""
    private var cachedVisibleSortColumn: ?Int64 = None
    private var cachedVisibleSortDescending: Bool = false
    private let block: ?Block
    private let style: ?Style
    private let selectedStyle: ?Style
    private let cellStyle: ?Style
    private let statusStyle: ?Style
    private let selectionModel: ?SelectionModel
    private let scrollState: ?ScrollState
    private let sortState: ?SortState
    private let filterState: ?FilterState

    public init(
        columns: Array<TableColumn>,
        rowCount: Int64,
        rowAt: (Int64) -> Array<String>,
        offset!: Int64 = 0,
        selectedRow!: ?Int64 = None,
        selectedColumn!: Int64 = 0,
        columnOffset!: Int64 = 0,
        block!: ?Block = None,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        cellStyle!: ?Style = None,
        statusStyle!: ?Style = None,
        selectionModel!: ?SelectionModel = None,
        scrollState!: ?ScrollState = None,
        sortState!: ?SortState = None,
        filterState!: ?FilterState = None,
        dataModel!: ?PagedTableModel = None,
        cacheCapacity!: Int64 = 1024
    ) {
        this.columns = columns
        this.rowCount = max(0, rowCount)
        this.rowAt = rowAt
        this.offset = max(0, offset)
        this.selectedRow = selectedRow
        this.selectedColumn = max(0, selectedColumn)
        this.columnOffset = max(0, columnOffset)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.cellStyle = cellStyle
        this.statusStyle = statusStyle
        this.selectionModel = selectionModel
        this.scrollState = scrollState
        this.sortState = sortState
        this.filterState = filterState
        if (dataModel.isSome() && (sortState.isSome() || filterState.isSome() || selectionModel.isSome())) {
            throw IllegalArgumentException("PagedTableModel owns query and ID selection; legacy bindings cannot be combined")
        }
        this.dataModel = dataModel
        this.cacheCapacity = max(1, cacheCapacity)
    }

    public init(columns: Array<TableColumn>, model: PagedTableModel, block!: ?Block = None) {
        this(columns, 0, { _ => Array<String>() }, block: block, dataModel: Some(model))
    }

    public func handle(mouse: MouseEvent, area: Rect): Bool {
        syncExternalState()
        let target = contentArea(area)
        if (!widgetHitTest(mouse, target)) { return false }
        ensureColumnVisible(target.width)
        let headers: Int64 = if (stickyHeader) { 1 } else { 0 }
        let scroll = mouseScrollDelta(mouse)
        if (scroll != 0) {
            offset = boundedDataMove(offset, scroll * 3, max(0, visibleRowCount() - max(1, target.height - headers)))
            if (let Some(state) <- scrollState) { state.offset = offset }
            return true
        }
        match ((mouse.kind, mouse.button)) { case (MouseKind.Down, MouseButton.Left) => (); case _ => return false }
        var column: Int64 = -1
        var x = target.x
        for (i in 0..columns.size) {
            if (i >= frozenColumns && i < max(columnOffset, frozenColumns)) { continue }
            let width = min(columns[i].width, max(0, target.right - x))
            if (mouse.x >= x && mouse.x < x + width) { column = i; break }
            if (width >= target.right - x) { break }
            x += width + 1
        }
        if (column < 0) { return false }
        if (headers > 0 && mouse.y == target.y) {
            sortBy(column, descending: sortColumn == Some(column) && !sortDescending)
            return true
        }
        let body = Rect(target.x, target.y + headers, target.width, max(0, target.height - headers))
        if (let Some(row) <- widgetRowAt(mouse, body, offset, visibleRowCount())) {
            selectedRow = Some(row); selectedColumn = column
            if (let Some(model) <- dataModel) { model.selectIndex(row) }
            if (mouse.modifiers.ctrl) { toggleSelectedRow() }
            return true
        }
        false
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        syncExternalState()
        if (let Some(b) <- block) { b.render(area, buffer) }
        let target = contentArea(area)
        if (target.width <= 0 || target.height <= 0) { return }
        buffer.withCanvasClip(target) { => renderRows(target, buffer) }
    }

    private func contentArea(area: Rect): Rect {
        match (block) {
            case Some(value) => value.inner(area)
            case None => area
        }
    }

    private func renderRows(target: Rect, buffer: Buffer): Unit {
        ensureColumnVisible(target.width)
        let headerRows = if (stickyHeader) { Int64(1) } else { Int64(0) }
        let palette = buffer.resolveTheme(None)
        if (stickyHeader) {
            let header = match (palette) { case Some(theme) => theme.heading; case None => Style(fg: Color.Yellow, modifier: Modifier.strong()) }
            let surface = TableHeaderSurface(Rect(target.x, target.y, target.width, 1), buffer)
            renderColumns(target.x, target.y, target.right, columnTitles(), buffer, header, None,
                header: true, headerSurface: Some(surface))
            surface.restoreWideRepairs(buffer)
        }
        if (renderStatus(target, buffer, headerRows)) { return }
        let limit = max(0, target.height - headerRows)
        for (row in 0..limit) {
            let index = offset + row
            match (sourceIndexAtVisible(index)) {
                case Some(sourceIndex) =>
                    var active = match (selectedRow) {
                        case Some(v) => v == index
                        case None => false
                    } || isSelected(sourceIndex)
                    if (let Some(model) <- dataModel) {
                        if (let Some(value) <- model.row(index)) {
                            active = model.selectedId() == Some(value.id) || model.isSelected(value.id)
                        } else {
                            let pageStatus = model.statusAt(index)
                            let message = match (pageStatus) { case TableStatus.Error(error) => error; case _ => loadingText }
                            let failed = match (pageStatus) { case TableStatus.Error(_) => true; case _ => false }
                            renderStatusText(Rect(target.x, target.y + headerRows + row, target.width, 1), buffer,
                                message, pagedStatusStyle(failed, buffer, palette))
                            continue
                        }
                    }
                    let rowY = target.y + headerRows + row
                    let rowSurface: ?TableHeaderSurface = if (!active && style.isNone()) {
                        Some(TableHeaderSurface(Rect(target.x, rowY, target.width, 1), buffer))
                    } else { None }
                    renderColumns(
                        target.x,
                        rowY,
                        target.right,
                        cachedRow(sourceIndex),
                        buffer,
                        if (active) { tableStyle(selectedStyle, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White), palette) }
                        else { tableStyle(style, ThemeRole.Normal, Style.default(), palette) },
                        if (active) { selectedColumn } else { None },
                        headerSurface: rowSurface
                    )
                    if (let Some(surface) <- rowSurface) { surface.restoreWideRepairs(buffer) }
                case None => return
            }
        }
    }

    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        syncExternalState()
        let current = match (selectedRow) {
            case Some(v) => v
            case None => 0
        }
        let total = visibleRowCount()
        let handled = match (key.code) {
            case KeyCode.Up =>
                selectedRow = Some(max(0, current - 1))
                ensureSelectedVisible(viewportHeight)
                true
            case KeyCode.Down =>
                selectedRow = Some(min(max(0, total - 1), current + 1))
                ensureSelectedVisible(viewportHeight)
                true
            case KeyCode.PageUp =>
                selectedRow = Some(max(0, current - max(1, viewportHeight)))
                ensureSelectedVisible(viewportHeight)
                true
            case KeyCode.PageDown =>
                selectedRow = Some(boundedDataMove(current, max(1, viewportHeight), max(0, total - 1)))
                ensureSelectedVisible(viewportHeight)
                true
            case KeyCode.Left =>
                selectedColumn = max(0, selectedColumn - 1)
                columnOffset = min(columnOffset, selectedColumn)
                true
            case KeyCode.Right =>
                selectedColumn = min(max(0, columns.size - 1), selectedColumn + 1)
                if (selectedColumn < columns.size) { columnOffset = min(columnOffset, selectedColumn) }
                true
            case KeyCode.Home =>
                selectedRow = Some(0)
                offset = 0
                true
            case KeyCode.End =>
                selectedRow = Some(max(0, total - 1))
                ensureSelectedVisible(viewportHeight)
                true
            case KeyCode.Char(r' ') =>
                toggleSelectedRow()
                true
            case _ => false
        }
        if (handled) {
            if (let Some(model) <- dataModel) {
                if (selectedRow != model.selectedIndex()) {
                    if (let Some(index) <- selectedRow) { model.selectIndex(index) }
                }
            }
            match (scrollState) {
                case Some(state) => state.offset = offset
                case None => ()
            }
        }
        handled
    }

    public func handleWithDirty(key: KeyEvent, area: Rect): ?DirtyRects {
        let content = contentArea(area)
        if (content.width <= 0 || content.height <= 0) { return None }
        let headerRows = if (stickyHeader) { Int64(1) } else { Int64(0) }
        let dataRows = max(0, content.height - headerRows)
        if (dataRows <= 0) { return None }

        syncExternalState()
        let beforeOffset = offset
        let beforeSelected = selectedRow
        let beforeColumnOffset = columnOffset
        if (!handle(key, dataRows)) { return None }
        ensureColumnVisible(content.width)
        if (beforeColumnOffset != columnOffset) {
            let dirty = DirtyRects()
            dirty.add(content)
            return Some(dirty)
        }
        if (beforeOffset != offset) { return Some(dirtyBody(area)) }
        Some(dirtySelectionChange(area, beforeSelected, selectedRow))
    }

    public func dirtyHeader(area: Rect): DirtyRects {
        let dirty = DirtyRects()
        let content = contentArea(area)
        if (content.width > 0 && content.height > 0 && stickyHeader) {
            dirty.add(Rect(content.x, content.y, content.width, 1))
        }
        dirty
    }

    public func dirtyBody(area: Rect): DirtyRects {
        let dirty = DirtyRects()
        let content = contentArea(area)
        if (content.width <= 0 || content.height <= 0) { return dirty }
        let headerRows = if (stickyHeader) { Int64(1) } else { Int64(0) }
        dirty.add(Rect(content.x, content.y + headerRows, content.width, max(0, content.height - headerRows)))
        dirty
    }

    public func dirtyRows(area: Rect, rows: Array<Int64>): DirtyRects {
        let dirty = DirtyRects()
        let content = contentArea(area)
        if (content.width <= 0 || content.height <= 0) { return dirty }
        let headerRows = if (stickyHeader) { Int64(1) } else { Int64(0) }
        for (row in rows) {
            addVirtualTableRowDirty(dirty, content, Some(row), offset, headerRows)
        }
        if (dirty.isEmpty()) { dirty.add(content) }
        dirty
    }

    public func dirtySelectionChange(area: Rect, before: ?Int64, after: ?Int64): DirtyRects {
        let rows = ArrayList<Int64>()
        match (before) {
            case Some(row) => rows.add(row)
            case None => ()
        }
        match (after) {
            case Some(row) => rows.add(row)
            case None => ()
        }
        dirtyRows(area, rows.toArray())
    }

    public func dirtyStatus(area: Rect): DirtyRects {
        dirtyBody(area)
    }

    public func clearCachedRows(): Unit {
        if (let Some(model) <- dataModel) { model.invalidate() }
        clearRowCache()
    }

    public func cachedRowCount(): Int64 {
        if (let Some(model) <- dataModel) { return model.cachedRowCount() }
        rowCache.size
    }

    public func sortBy(column: Int64, descending!: Bool = false): Unit {
        syncExternalState()
        let sortedColumn = clamp(column, 0, max(0, columns.size - 1))
        sortColumn = Some(sortedColumn)
        sortDescending = descending
        if (let Some(model) <- dataModel) { _ = model.setQuery(TableQuery(filter: filterText, sortColumn: sortColumn, descending: descending)) }
        offset = 0
        match (scrollState) {
            case Some(state) => state.offset = 0
            case None => ()
        }
        match (sortState) {
            case Some(state) => state.set(sortedColumn, descending: descending)
            case None => ()
        }
        clearRowCache()
    }

    public func clearSort(): Unit {
        syncExternalState()
        sortColumn = None
        sortDescending = false
        if (let Some(model) <- dataModel) { _ = model.setQuery(TableQuery(filter: filterText)) }
        match (sortState) {
            case Some(state) => state.clear()
            case None => ()
        }
        clearRowCache()
    }

    public func resizeColumn(column: Int64, width: Int64): Bool {
        if (column < 0 || column >= columns.size) { return false }
        columns[column].width = max(1, width)
        true
    }

    public func setFrozenColumns(count: Int64): Unit {
        frozenColumns = clamp(count, 0, columns.size)
    }

    public func setFilter(text: String): Unit {
        syncExternalState()
        filterText = text
        if (let Some(model) <- dataModel) { _ = model.setQuery(TableQuery(filter: text, sortColumn: sortColumn, descending: sortDescending)) }
        offset = 0
        selectedRow = None
        match (filterState) {
            case Some(state) => state.set(text)
            case None => ()
        }
        match (scrollState) {
            case Some(state) => state.offset = 0
            case None => ()
        }
        clearRowCache()
    }

    public func setStatus(status: TableStatus): Unit {
        this.status = status
    }

    public func toggleSelectedRow(): Unit {
        if (let Some(model) <- dataModel) {
            if (let Some(id) <- model.selectedId()) { model.toggle(id) }
            return
        }
        match (selectedRow) {
            case Some(row) =>
                match (sourceIndexAtVisible(row)) {
                    case Some(sourceIndex) =>
                        match (selectionModel) {
                            case Some(model) =>
                                model.toggle(sourceIndex)
                                return
                            case None => ()
                        }
                        if (isSelected(sourceIndex)) {
                            removeSelected(sourceIndex)
                        } else {
                            selectedRows.add(sourceIndex)
                        }
                    case None => return
                }
            case None => ()
        }
    }

    public func isSelected(row: Int64): Bool {
        match (selectionModel) {
            case Some(model) => return model.isSelected(row)
            case None => ()
        }
        for (selected in selectedRows) {
            if (selected == row) { return true }
        }
        false
    }

    public func selectedRowIndices(): Array<Int64> {
        match (selectionModel) {
            case Some(model) => model.selectedIndices()
            case None => selectedRows.toArray()
        }
    }

    private func columnTitles(): Array<String> {
        let titles = ArrayList<String>()
        for (i in 0..columns.size) {
            titles.add(columns[i].title)
        }
        titles.toArray()
    }

    private func renderColumns(x: Int64, y: Int64, right: Int64, values: Array<String>, buffer: Buffer, style: Style,
        activeColumn: ?Int64, header!: Bool = false, headerSurface!: ?TableHeaderSurface = None): Unit {
        var cx = x
        let activeStyle = if (activeColumn.isSome()) {
            tableStyle(cellStyle, ThemeRole.Focused, Style(fg: Color.Black, bg: Color.Cyan), buffer.resolveTheme(None))
        } else { Style.default() }
        let limit = min(values.size, columns.size)
        let frozen = min(frozenColumns, limit)
        for (i in 0..frozen) {
            if (cx >= right) { return }
            cx = renderColumnCell(cx, y, right, i, values, buffer, style, activeColumn, activeStyle, header, headerSurface)
        }
        for (i in max(columnOffset, frozen)..limit) {
            if (cx >= right) { return }
            cx = renderColumnCell(cx, y, right, i, values, buffer, style, activeColumn, activeStyle, header, headerSurface)
        }
    }

    private func renderColumnCell(
        cx: Int64,
        y: Int64,
        right: Int64,
        i: Int64,
        values: Array<String>,
        buffer: Buffer,
        style: Style,
        activeColumn: ?Int64,
        activeStyle: Style,
        header: Bool,
        headerSurface: ?TableHeaderSurface
    ): Int64 {
            let column = columns[i]
            let width = min(max(0, column.width), max(0, right - cx))
            let sorted = header && sortColumn == Some(i)
            let text = if (!sorted || width <= 0) {
                clippedWithEllipsis(values[i], width, buffer)
            } else {
                let direction = if (sortDescending) { "v" } else { "^" }
                if (width == 1) { direction }
                else if (width == 2) { clippedWithEllipsis(values[i], 1, buffer) + direction }
                else { clippedWithEllipsis(values[i], width - 2, buffer) + " " + direction }
            }
            let cellArea = Rect(cx, y, width, 1)
            let rowStyle = match (activeColumn) {
                case Some(col) => if (col == i) { activeStyle } else { style }
                case None => style
            }
            if (text != values[i] && displayWidth(text, options: buffer.textWidthOptions()) < width) {
                match (headerSurface) {
                    case Some(surface) => tableWriteOnExistingBackground(cx, y, repeat(" ", width), width,
                        rowStyle, buffer, surface)
                    case None => buffer.fillRect(cellArea, style: rowStyle)
                }
            }
            let textX = alignedX(cellArea, displayWidthFast(text, options: buffer.textWidthOptions()), column.align)
            match (headerSurface) {
                case Some(surface) => tableWriteOnExistingBackground(textX, y, text, right - textX,
                    rowStyle, buffer, surface)
                case None => buffer.setString(textX, y, text, style: rowStyle)
            }
            if (width >= right - cx) { right } else { cx + width + 1 }
    }

    private func ensureSelectedVisible(viewportHeight: Int64): Unit {
        let total = visibleRowCount()
        match (selectedRow) {
            case Some(row) =>
                if (row < offset) {
                    offset = row
                } else if (viewportHeight > 0 && row >= offset + viewportHeight) {
                    offset = row - viewportHeight + 1
                }
                offset = clamp(offset, 0, max(0, total - viewportHeight))
            case None => ()
        }
    }

    private func ensureColumnVisible(width: Int64): Unit {
        if (columns.size == 0) { return }
        selectedColumn = clamp(selectedColumn, 0, columns.size - 1)
        let frozen = clamp(frozenColumns, 0, columns.size)
        if (selectedColumn < frozen) { return }
        columnOffset = clamp(columnOffset, frozen, selectedColumn)

        // Frozen cells occupy the viewport before the scrolling columns.
        // Subtract bounded widths instead of summing potentially large widths.
        var remaining = max(0, width)
        for (i in 0..frozen) {
            remaining -= min(remaining, max(0, columns[i].width))
            if (remaining > 0) { remaining-- }
        }
        remaining -= min(remaining, max(0, columns[selectedColumn].width))
        var start = selectedColumn
        while (start > columnOffset) {
            let previousWidth = max(0, columns[start - 1].width)
            if (previousWidth >= remaining) { break }
            remaining -= previousWidth + 1
            start--
        }
        columnOffset = start
    }

    private func visibleIndices(): Array<Int64> {
        let filterKey = filterText
        let sortColumnKey = sortColumn
        let descendingKey = sortDescending
        match (cachedVisibleIndices) {
            case Some(indices) =>
                if (cachedVisibleFilterText == filterKey &&
                    cachedVisibleSortColumn == sortColumnKey &&
                    cachedVisibleSortDescending == descendingKey) {
                    return indices
                }
            case None => ()
        }

        let rows = ArrayList<Int64>()
        for (i in 0..rowCount) {
            if (filterKey.isEmpty() || matchesFilter(i)) { rows.add(i) }
        }
        match (sortColumnKey) {
            case Some(column) =>
                sort(
                    rows,
                    lessThan: { left, right =>
                        compareStrings(valueAt(left, column), valueAt(right, column)) < 0
                    },
                    stable: true,
                    descending: descendingKey
                )
            case None => ()
        }

        let indices = rows.toArray()
        cachedVisibleFilterText = filterKey
        cachedVisibleSortColumn = sortColumnKey
        cachedVisibleSortDescending = descendingKey
        cachedVisibleIndices = Some(indices)
        indices
    }

    private func usesDerivedRows(): Bool {
        if (!filterText.isEmpty()) { return true }
        match (sortColumn) {
            case Some(_) => true
            case None => false
        }
    }

    private func visibleRowCount(): Int64 {
        if (let Some(model) <- dataModel) { return model.totalRows() }
        if (!usesDerivedRows()) { return rowCount }
        visibleIndices().size
    }

    private func sourceIndexAtVisible(index: Int64): ?Int64 {
        if (let Some(model) <- dataModel) { return if (index >= 0 && index < model.totalRows()) { Some(index) } else { None } }
        if (index < 0) { return None }
        if (!usesDerivedRows()) {
            if (index >= rowCount) { return None }
            return Some(index)
        }
        let indices = visibleIndices()
        if (index >= indices.size) { return None }
        Some(indices[index])
    }

    private func matchesFilter(index: Int64): Bool {
        if (filterText.isEmpty()) { return true }
        for (cell in cachedRow(index)) {
            if (cell.contains(filterText)) { return true }
        }
        false
    }

    private func valueAt(row: Int64, column: Int64): String {
        let values = cachedRow(row)
        if (column >= 0 && column < values.size) { values[column] } else { "" }
    }

    private func cachedRow(index: Int64): Array<String> {
        if (let Some(model) <- dataModel) { return match (model.row(index)) { case Some(row) => row.cells; case None => [] } }
        match (rowCache.get(index)) {
            case Some(row) => return row
            case None => ()
        }
        let row = rowAt(index)
        rowCache.add(index, row)
        cacheOrder.add(index)
        while (cacheOrder.size > cacheCapacity) { rowCache.remove(cacheOrder.remove(at: 0)) }
        row
    }

    private func clearRowCache(): Unit {
        rowCache.clear()
        cacheOrder.clear()
        cachedVisibleIndices = None
    }

    private func renderStatus(area: Rect, buffer: Buffer, headerRows: Int64): Bool {
        let y = area.y + headerRows
        if (y >= area.bottom) { return true }
        let palette = buffer.resolveTheme(None)
        let statusPaint = tableStyle(statusStyle, ThemeRole.Disabled, Style(fg: Color.Indexed(8)), palette)
        match (status) {
            case TableStatus.Ready =>
                if (visibleRowCount() == 0) {
                    renderStatusText(Rect(area.x, y, area.width, 1), buffer, emptyText, statusPaint)
                    return true
                }
                false
            case TableStatus.Empty =>
                renderStatusText(Rect(area.x, y, area.width, 1), buffer, emptyText, statusPaint)
                true
            case TableStatus.Loading =>
                renderStatusText(Rect(area.x, y, area.width, 1), buffer, loadingText, statusPaint)
                true
            case TableStatus.Error(message) =>
                let errorPaint = tableStyle(statusStyle, ThemeRole.Error, Style(fg: Color.Red).patch(statusPaint), palette)
                renderStatusText(Rect(area.x, y, area.width, 1), buffer, message, errorPaint)
                true
        }
    }

    private func pagedStatusStyle(failed: Bool, buffer: Buffer, palette: ?Theme): Style {
        let loading = tableStyle(statusStyle, ThemeRole.Disabled, Style(fg: Color.Indexed(8)), palette)
        if (!failed || statusStyle.isSome()) { return loading }
        var error = tableStyle(None, ThemeRole.Error, Style(fg: Color.Red), palette)
        let caps = buffer.capabilities()
        let visibleError = adaptStyleForCapabilities(error, caps)
        let visibleLoading = adaptStyleForCapabilities(loading, caps)
        if (!caps.trueColor &&
            Style(fg: visibleError.fg, modifier: visibleError.modifier) ==
                Style(fg: visibleLoading.fg, modifier: visibleLoading.modifier)) {
            var modifier = error.modifier
            if (!modifier.underline) { modifier.underline = true }
            else if (!modifier.reversed) { modifier.reversed = true }
            else if (!modifier.bold) { modifier.bold = true }
            else if (!modifier.italic) { modifier.italic = true }
            else { modifier.underline = false }
            error = error.withModifier(modifier)
        }
        error
    }

    // Omitted status style uses the foreground role over the actual surface;
    // explicit status styles retain the existing theme merge and paint behavior.
    private func renderStatusText(area: Rect, buffer: Buffer, text: String, paint: Style): Unit {
        let visible = truncate(text, area.width, options: buffer.textWidthOptions())
        if (statusStyle.isNone()) {
            let surface = TableHeaderSurface(area, buffer)
            tableWriteOnExistingBackground(area.x, area.y, visible, area.width, paint, buffer, surface)
            surface.restoreWideRepairs(buffer)
        } else {
            buffer.setString(area.x, area.y, visible, style: paint)
        }
    }

    private func syncExternalState(): Unit {
        match (scrollState) { case Some(state) => offset = state.offset; case None => () }
        if (let Some(model) <- dataModel) {
            let query = model.query()
            filterText = query.filter; sortColumn = query.sortColumn; sortDescending = query.descending
            selectedRow = model.selectedIndex()
            if (model.hasTotal()) { offset = clamp(offset, 0, max(0, model.totalRows() - 1)) }
            status = model.statusAt(offset)
            if (let Some(state) <- scrollState) { state.offset = offset }
        }
        match (sortState) {
            case Some(state) =>
                sortColumn = state.column
                sortDescending = state.descending
            case None => ()
        }
        match (filterState) {
            case Some(state) => filterText = state.query
            case None => ()
        }
    }

    private func removeSelected(row: Int64): Unit {
        for (i in 0..selectedRows.size) {
            if (selectedRows[i] == row) {
                selectedRows.remove(at: i)
                return
            }
        }
    }
}

func addVirtualTableRowDirty(dirty: DirtyRects, area: Rect, selected: ?Int64, offset: Int64, headerRows: Int64): Unit {
    match (selected) {
        case Some(index) =>
            let row = index - offset + headerRows
            if (row >= headerRows && row < area.height) {
                dirty.add(Rect(area.x, area.y + row, area.width, 1))
            }
        case None => ()
    }
}

/** 可展开的树节点。
 */
public class TreeNode {
    /** 节点标识。
     */
    public let id: String
    /** 显示标签。
     */
    public let label: String
    /** 是否展开子节点。
     */
    public var expanded: Bool
    private let children: ArrayList<TreeNode>

    /** 创建节点。
     * @param id 节点标识
     * @param label 显示标签
     * @param expanded 初始展开状态
     * @param children 初始子节点
     */
    public init(id: String, label: String, expanded!: Bool = false, children!: Array<TreeNode> = []) {
        this.id = id
        this.label = label
        this.expanded = expanded
        this.children = ArrayList<TreeNode>()
        for (child in children) {
            this.children.add(child)
        }
    }

    /** 追加子节点。
     * @param child 子节点
     */
    public func add(child: TreeNode): Unit {
        children.add(child)
    }

    /** 获取当前子节点数组。
     * @return 按插入顺序排列的子节点。
     */
    public func childNodes(): Array<TreeNode> {
        children.toArray()
    }
}

/** 显示普通节点或惰性模型的树视图。
 */
public class Tree <: Widget {
    private let roots: Array<TreeNode>
    private let dataModel: ?LazyTreeModel
    private var stableId: ?String = None
    private var rememberedIndex: Int64 = -1
    /** 当前可见行索引。
     */
    public var selected: Int64
    /** 视口起始行索引。
     */
    public var offset: Int64
    private let block: ?Block
    private let style: Style
    private let selectedStyle: ?Style
    private let focusedStyle: ?Style
    private var focused: Bool
    private var theme: ?Theme
    private var renderedTheme: ?Theme = None

    /** 创建树视图。
     * @param roots 普通树根节点
     * @param selected 初始选中行，负值按零处理
     * @param offset 初始起始行，负值按零处理
     * @param block 可选外框
     * @param style 基础样式
     * @param selectedStyle 可选选中样式
     * @param dataModel 可选惰性树模型
     * @param focused 是否聚焦
     * @param focusedStyle 可选聚焦样式
     * @param theme 可选语义主题
     */
    public init(
        roots: Array<TreeNode>,
        selected!: Int64 = 0,
        offset!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: ?Style = None,
        dataModel!: ?LazyTreeModel = None,
        focused!: Bool = false,
        focusedStyle!: ?Style = None,
        theme!: ?Theme = None
    ) {
        this.roots = roots
        this.dataModel = dataModel
        this.selected = max(0, selected)
        this.offset = max(0, offset)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.focusedStyle = focusedStyle
        this.focused = focused
        this.theme = theme
    }

    /** 创建惰性模型树。
     * @param model 惰性树模型
     * @param block 可选外框
     * @param focused 是否聚焦
     * @param theme 可选语义主题
     */
    public init(model: LazyTreeModel, block!: ?Block = None, focused!: Bool = false, theme!: ?Theme = None) {
        this([], block: block, dataModel: Some(model), focused: focused, theme: theme)
        if (model.selectedId().isNone()) { _ = model.selectIndex(0) }
    }

    /** 设置聚焦状态。
     * @param value 是否聚焦
     */
    public func setFocused(value: Bool): Unit { focused = value }

    /** 设置或清除语义主题。
     * @param value 主题；None 表示清除
     */
    public func setTheme(value: ?Theme): Unit { theme = value }

    /** 按上次绘制的区块几何处理鼠标；自身主题优先。
     * @param mouse 鼠标事件
     * @param area 树的区域
     * @return 处理了鼠标事件时为 true。
     */
    public func handle(mouse: MouseEvent, area: Rect): Bool {
        handleMouseWithTheme(mouse, area, None)
    }

    /** 使用可选父主题计算命中区域；树和区块显式主题优先。
     * @param mouse 鼠标事件
     * @param area 树的区域
     * @param theme 可选应用或父主题
     * @return 处理了鼠标事件时为 true。
     */
    public func handle(mouse: MouseEvent, area: Rect, theme!: ?Theme): Bool {
        handleMouseWithTheme(mouse, area, theme)
    }

    private func handleMouseWithTheme(mouse: MouseEvent, area: Rect, layoutTheme: ?Theme): Bool {
        let target = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        if (!widgetHitTest(mouse, target)) { return false }
        let total = match (dataModel) { case Some(model) => model.visibleCount(); case None => visibleRows().size }
        let delta = mouseScrollDelta(mouse)
        if (delta != 0) { offset = boundedDataMove(offset, delta * 3, max(0, total - max(1, target.height))); return true }
        match ((mouse.kind, mouse.button)) { case (MouseKind.Down, MouseButton.Left) => (); case _ => return false }
        if (let Some(index) <- widgetRowAt(mouse, target, offset, total)) {
            selected = index
            var depth: Int64 = 0
            if (let Some(model) <- dataModel) {
                _ = model.selectIndex(index)
                if (let Some(row) <- model.rowAt(index)) { depth = row.depth }
            } else {
                let rows = visibleRows()
                stableId = Some(rows[index][0].id); rememberedIndex = index; depth = rows[index][1]
            }
            let disclosureOffset = treeDisclosureOffset(target.width, depth)
            let disclosureWidth: Int64 = if (target.width >= 5) { 2 } else { 1 }
            if (disclosureOffset >= 0 && mouse.x >= target.x + disclosureOffset &&
                mouse.x < target.x + disclosureOffset + disclosureWidth) { toggleSelected() }
            return true
        }
        false
    }

    /** 切换当前节点的展开状态。
     */
    public func toggleSelected(): Unit {
        if (let Some(model) <- dataModel) { _ = model.toggleSelected(); return }
        let nodes = visibleNodes()
        if (selected >= 0 && selected < nodes.size) {
            nodes[selected].expanded = !nodes[selected].expanded
        }
    }

    /** 获取当前选择的节点标识。
     * @return 当前标识或 None。
     */
    public func selectedId(): ?String {
        if (let Some(model) <- dataModel) { return model.selectedId() }
        _ = visibleRows()
        stableId
    }

    /** 按标识选择可见节点。
     * @param id 节点标识
     * @return 找到并选择时为 true。
     */
    public func selectById(id: String): Bool {
        if (let Some(model) <- dataModel) {
            let found = model.selectById(id)
            if (let Some(index) <- model.selectedIndex()) { selected = index }
            return found
        }
        let nodes = visibleNodes()
        for (i in 0..nodes.size) {
            if (nodes[i].id == id) {
                selected = i
                stableId = Some(id); rememberedIndex = i
                return true
            }
        }
        false
    }

    /** 在普通树的所有节点中查找；惰性树调用会抛出异常。
     * @param id 节点标识
     * @return 找到的节点或 None。
     */
    public func findById(id: String): ?TreeNode {
        if (dataModel.isSome()) { throw IllegalStateException("Use LazyTreeModel.findById for provider nodes") }
        for (root in roots) {
            match (findTreeNode(root, id)) {
                case Some(node) => return Some(node)
                case None => ()
            }
        }
        None
    }

    /** 递归展开普通树；惰性树调用会抛出异常。
     */
    public func expandAll(): Unit {
        if (dataModel.isSome()) { throw IllegalStateException("Lazy trees expand explicit IDs; expandAll would enumerate the source") }
        for (root in roots) {
            setExpandedRecursive(root, true)
        }
    }

    /** 收起所有节点并重置滚动位置。
     */
    public func collapseAll(): Unit {
        if (let Some(model) <- dataModel) { model.collapseAll(); offset = 0; return }
        for (root in roots) {
            setExpandedRecursive(root, false)
        }
        selected = 0
        offset = 0
    }

    /** 处理树导航和展开按键。
     * @param key 键盘事件
     * @param viewportHeight 可见行数
     * @return 支持的按键返回 true。
     */
    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        if (let Some(model) <- dataModel) {
            let current = match (model.selectedIndex()) { case Some(index) => index; case None => 0 }
            let total = model.visibleCount()
            var next = current
            match (key.code) {
                case KeyCode.Up => next = max(0, current - 1)
                case KeyCode.Down => next = min(max(0, total - 1), current + 1)
                case KeyCode.PageUp => next = max(0, current - max(1, viewportHeight))
                case KeyCode.PageDown => next = boundedDataMove(current, max(1, viewportHeight), max(0, total - 1))
                case KeyCode.Home => next = 0
                case KeyCode.End => next = max(0, total - 1)
                case KeyCode.Left => collapseSelected(); return true
                case KeyCode.Right => expandSelected(); return true
                case KeyCode.Enter | KeyCode.Char(r' ') => toggleSelected(); return true
                case _ => return false
            }
            _ = model.selectIndex(next); selected = next; ensureVisible(total, max(1, viewportHeight))
            return true
        }
        let total = visibleNodes().size
        match (key.code) {
            case KeyCode.Up => selected = max(0, selected - 1); ensureVisible(total, viewportHeight); true
            case KeyCode.Down => selected = min(max(0, total - 1), selected + 1); ensureVisible(total, viewportHeight); true
            case KeyCode.Left => collapseSelected(); true
            case KeyCode.Right => expandSelected(); true
            case KeyCode.Enter | KeyCode.Char(r' ') => toggleSelected(); true
            case _ => false
        }
    }

    /** 展开当前节点。
     */
    public func expandSelected(): Unit {
        if (let Some(model) <- dataModel) {
            if (let Some(id) <- model.selectedId()) { _ = model.setExpanded(id, true) }
            return
        }
        let nodes = visibleNodes()
        if (selected >= 0 && selected < nodes.size) {
            nodes[selected].expanded = true
        }
    }

    /** 收起当前节点。
     */
    public func collapseSelected(): Unit {
        if (let Some(model) <- dataModel) {
            if (let Some(id) <- model.selectedId()) { _ = model.setExpanded(id, false) }
            return
        }
        let nodes = visibleNodes()
        if (selected >= 0 && selected < nodes.size) {
            nodes[selected].expanded = false
        }
    }

    /** 在区域内绘制树。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            let content = [area]
            buffer.withParentTheme(theme) { =>
                content[0] = b.renderInner(area, buffer)
            }
            target = content[0]
        }
        let visualTheme = buffer.resolveTheme(theme)
        if (let Some(model) <- dataModel) {
            for (row in model.rows(offset, target.height)) {
                let marker = if (row.node.childCount > 0) { if (row.expanded) { "- " } else { "+ " } } else { "  " }
                renderTreeRow(buffer, target, target.y + row.index - offset, row.depth, marker, row.node.label,
                    model.selectedId() == Some(row.node.id), visualTheme)
            }
            if (let Some(index) <- model.selectedIndex()) { selected = index }
            return
        }
        let nodes = visibleRows()
        for (row in 0..target.height) {
            let index = offset + row
            if (index >= nodes.size) { return }
            let (node, depth) = nodes[index]
            let marker = if (node.childNodes().size > 0) { if (node.expanded) { "- " } else { "+ " } } else { "  " }
            renderTreeRow(buffer, target, target.y + row, depth, marker, node.label, index == selected, visualTheme)
        }
    }

    private func renderTreeRow(buffer: Buffer, area: Rect, y: Int64, depth: Int64,
        disclosure: String, label: String, selected: Bool, theme: ?Theme): Unit {
        let palette = match (theme) { case Some(value) => value; case None => Theme.default() }
        let rowStyle = if (!selected) {
            themeRoleStyle(style, ThemeRole.Normal, theme)
        } else if (focused) {
            match (focusedStyle) {
                case Some(value) => value
                case None => match (selectedStyle) {
                    case Some(value) => value.withModifier(combineModifiers(value.modifier, palette.focused.modifier))
                    case None => palette.focused
                }
            }
        } else {
            match (selectedStyle) { case Some(value) => value; case None => palette.selected }
        }
        let canvas = Canvas(buffer, area)
        if (selected) { canvas.fillRect(Rect(area.x, y, area.width, 1), rowStyle) }
        let marker = if (!buffer.capabilities().unicode) { "*" }
            else { match (palette.iconSet) { case IconSet.Ascii => "*"; case IconSet.NerdFont => "\u{F111}"; case IconSet.Unicode => "●" } }
        // Disclosure hit testing uses a one-cell marker column. If a terminal
        // treats the selected symbol as wide, use its single-cell fallback so
        // selected and unselected rows keep the same layout and hit targets.
        let safeMarker = if (displayWidth(marker, options: buffer.textWidthOptions()) == 1) { marker } else { "*" }
        let selectedMark = if (selected) { safeMarker } else { " " }
        let prefix = if (area.width <= 1) { "" }
            else if (area.width == 2) { disclosure[0..1] }
            else if (area.width == 3) { selectedMark + disclosure[0..1] }
            else if (area.width == 4) { selectedMark + " " + disclosure[0..1] }
            else { selectedMark + " " + repeat("  ", min(depth, max(0, (area.width - 5) / 2))) + disclosure }
        let labelWidth = max(0, area.width - displayWidth(prefix, options: buffer.textWidthOptions()))
        let visibleLabel = clippedWithEllipsis(label, labelWidth, buffer)
        let visibleWidth = displayWidth(visibleLabel, options: buffer.textWidthOptions())
        if (!selected && visibleLabel != label && visibleWidth < labelWidth) {
            let labelStart = area.x + displayWidth(prefix, options: buffer.textWidthOptions())
            canvas.fillRect(Rect(labelStart + visibleWidth, y, labelWidth - visibleWidth, 1), rowStyle)
        }
        canvas.drawText(area.x, y, prefix + visibleLabel, rowStyle)
    }

    private func ensureVisible(total: Int64, viewportHeight: Int64): Unit {
        if (selected < offset) {
            offset = selected
        } else if (selected - offset >= viewportHeight) {
            offset = selected - viewportHeight + 1
        }
        offset = clamp(offset, 0, max(0, total - viewportHeight))
    }

    private func visibleNodes(): Array<TreeNode> {
        let rows = visibleRows()
        let nodes = ArrayList<TreeNode>()
        for ((node, _) in rows) {
            nodes.add(node)
        }
        nodes.toArray()
    }

    private func visibleRows(): Array<(TreeNode, Int64)> {
        let rows = ArrayList<(TreeNode, Int64)>()
        for (node in roots) {
            collectTreeRows(node, 0, rows)
        }
        if (selected != rememberedIndex) {
            stableId = if (selected >= 0 && selected < rows.size) { Some(rows[selected][0].id) } else { None }
        } else if (let Some(id) <- stableId) {
            selected = -1
            for (i in 0..rows.size) { if (rows[i][0].id == id) { selected = i; break } }
        }
        rememberedIndex = selected
        rows.toArray()
    }
}

// Reserve at least one column for a node label; hit testing shares this geometry.
func treeDisclosureOffset(width: Int64, depth: Int64): Int64 {
    if (width <= 1) { return -1 }
    if (width == 2) { return 0 }
    if (width == 3) { return 1 }
    if (width == 4) { return 2 }
    2 + min(depth, max(0, (width - 5) / 2)) * 2
}

private func tableStyle(style: ?Style, role: ThemeRole, fallback: Style, theme: ?Theme): Style {
    match (theme) {
        case Some(value) => themeRoleStyle(match (style) { case Some(custom) => custom; case None => Style.default() }, role, Some(value))
        case None => match (style) { case Some(custom) => custom; case None => fallback }
    }
}

func collectTreeRows(node: TreeNode, depth: Int64, rows: ArrayList<(TreeNode, Int64)>): Unit {
    rows.add((node, depth))
    if (node.expanded) {
        for (child in node.childNodes()) {
            collectTreeRows(child, depth + 1, rows)
        }
    }
}

func findTreeNode(node: TreeNode, id: String): ?TreeNode {
    if (node.id == id) { return Some(node) }
    for (child in node.childNodes()) {
        match (findTreeNode(child, id)) {
            case Some(found) => return Some(found)
            case None => ()
        }
    }
    None
}

func setExpandedRecursive(node: TreeNode, expanded: Bool): Unit {
    node.expanded = expanded
    for (child in node.childNodes()) {
        setExpandedRecursive(child, expanded)
    }
}

func compareStrings(left: String, right: String): Int64 {
    let a = unsafe { left.rawData() }
    let b = unsafe { right.rawData() }
    let limit = min(a.size, b.size)
    for (i in 0..limit) {
        if (a[i] < b[i]) { return -1 }
        if (a[i] > b[i]) { return 1 }
    }
    if (a.size < b.size) { return -1 }
    if (a.size > b.size) { return 1 }
    0
}

public class FilePicker <: Widget {
    public var path: String
    private let extension: String
    private let state = ListState(selected: Some(0))
    private var entries: Array<String> = []
    public var searchText: String = ""
    public var showHidden: Bool = false

    public init(path!: String = ".", extension!: String = "", showHidden!: Bool = false) {
        this.path = path
        this.extension = extension
        this.showHidden = showHidden
        refresh()
    }

    public func refresh(): Unit {
        let dirs = ArrayList<String>()
        let files = ArrayList<String>()
        try {
            for (entry in Directory.readFrom(path)) {
                let name = entry.name
                if (!showHidden && name.startsWith(".")) { continue }
                if (!searchText.isEmpty() && !name.contains(searchText)) { continue }
                let childPath = joinPath(path, name)
                if (isDirectory(childPath)) {
                    insertSorted(dirs, name)
                } else if (extension.isEmpty() || name.endsWith(extension)) {
                    insertSorted(files, name)
                }
            }
        } catch (_) {}
        dirs.add("..", at: 0) // The parent action must precede every sorted directory name.
        for (file in files) {
            dirs.add(file)
        }
        entries = dirs.toArray()
    }

    public func selectedEntry(): ?String {
        match (state.selected) {
            case Some(index) =>
                if (index >= 0 && index < entries.size) { Some(entries[index]) } else { None }
            case None => None
        }
    }

    public func selectedPath(): ?String {
        match (selectedEntry()) {
            case Some(entry) => Some(if (entry == "..") { parentPath(path) } else { joinPath(path, entry) })
            case None => None
        }
    }

    public func chooseSelected(): ?String {
        selectedPath()
    }

    public func setSearch(text: String): Unit {
        searchText = text
        state.select(Some(0))
        state.offset = 0
        refresh()
    }

    public func toggleHidden(): Unit {
        showHidden = !showHidden
        refresh()
    }

    public func selectedInfo(): ?FileEntryInfo {
        match (selectedEntry()) {
            case Some(entry) =>
                let fullPath = if (entry == "..") { parentPath(path) } else { joinPath(path, entry) }
                Some(FileEntryInfo(entry, fullPath, isDirectory(fullPath)))
            case None => None
        }
    }

    public func enterSelected(): Bool {
        match (selectedPath()) {
            case Some(nextPath) =>
                if (isDirectory(nextPath)) {
                    path = nextPath
                    state.select(Some(0))
                    state.offset = 0
                    refresh()
                    return true
                }
                false
            case None => false
        }
    }

    public func parent(): Bool {
        let nextPath = parentPath(path)
        if (nextPath == path) { return false }
        path = nextPath
        state.select(Some(0))
        state.offset = 0
        refresh()
        true
    }

    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        match (key.code) {
            case KeyCode.Up =>
                state.move(-1, entries.size, viewportHeight: viewportHeight)
                true
            case KeyCode.Down =>
                state.move(1, entries.size, viewportHeight: viewportHeight)
                true
            case KeyCode.PageUp =>
                state.move(-max(1, viewportHeight), entries.size, viewportHeight: viewportHeight)
                true
            case KeyCode.PageDown =>
                state.move(max(1, viewportHeight), entries.size, viewportHeight: viewportHeight)
                true
            case KeyCode.Home =>
                state.select(Some(0))
                state.scrollToVisible(entries.size, viewportHeight)
                true
            case KeyCode.End =>
                state.select(Some(max(0, entries.size - 1)))
                state.scrollToVisible(entries.size, viewportHeight)
                true
            case KeyCode.Enter =>
                enterSelected()
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        List(entries, state: Some(state), block: Block(title: path)).render(area, buffer)
    }
}

public class FileEntryInfo {
    public let name: String
    public let path: String
    public let isDir: Bool

    public init(name: String, path: String, isDir: Bool) {
        this.name = name
        this.path = path
        this.isDir = isDir
    }
}

func insertSorted(items: ArrayList<String>, value: String): Unit {
    var index: Int64 = 0
    while (index < items.size && compareStrings(items[index], value) <= 0) {
        index++
    }
    items.add(value)
    var i = items.size - 1
    while (i > index) {
        items[i] = items[i - 1]
        i--
    }
    items[index] = value
}

func joinPath(base: String, name: String): String {
    if (base.isEmpty() || base == ".") { return name }
    if (base.endsWith("/")) { base + name } else { base + "/" + name }
}

func parentPath(path: String): String {
    if (path.isEmpty() || path == ".") { return ".." }
    if (path == "/") { return path }
    var end = path.size
    while (end > 1 && path[end - 1] == b'/') { end-- }
    let trimmed = path[..end]
    if (trimmed == ".") { return ".." }
    if (trimmed == ".." || trimmed.endsWith("/..")) { return trimmed + "/.." }
    if (trimmed == "/.") { return "/" }
    if (trimmed.endsWith("/.")) { return parentPath(trimmed[..trimmed.size - 2]) }
    var i = end - 1
    while (i >= 0) {
        if (path[i] == b'/') {
            if (i == 0) { return "/" }
            return path[..i]
        }
        i--
    }
    "."
}

func isDirectory(path: String): Bool {
    try {
        _ = Directory.readFrom(path)
        true
    } catch (_) {
        false
    }
}

func boundedDataMove(value: Int64, delta: Int64, upper: Int64): Int64 {
    let current = clamp(value, 0, upper)
    if (delta >= 0) { current + min(delta, upper - current) }
    else { current - min(-delta, current) }
}
