package cjtui_showcase_data

import core.*
import std.collection.ArrayList

class DataRow {
    let id: String
    var name: String
    var status: String
    init(id: String, name: String, status: String) {
        this.id = id
        this.name = name
        this.status = status
    }
}

class VirtualNode {
    let id: Int64
    let parent: Int64
    var name: String
    let folder: Bool
    var deleted = false
    let rows = ArrayList<DataRow>()
    init(id: Int64, parent: Int64, name: String, folder: Bool) {
        this.id = id
        this.parent = parent
        this.name = name
        this.folder = folder
    }
}

class DataShowcase {
    let nodes = ArrayList<VirtualNode>()
    let treeState = ListState(selected: Some(2))
    let tableState = TableState(selectedRow: Some(0))
    let input = Input()
    let theme = Theme.indigo()
    var unicode = true
    var treeFocused = false
    var inputMode = ""
    var filter = ""
    var descending = false
    var status = "Memory only: changes reset on exit"
    var nextId: Int64 = 0
    var viewport: Int64 = 12

    init() {
        let root = addNode(-1, "workspace", true)
        let projects = addNode(root.id, "projects", true)
        let tasks = addNode(projects.id, "tasks.csv", false)
        tasks.rows.add(DataRow("T-101", "Ship dashboard", "In review"))
        tasks.rows.add(DataRow("T-102", "Design tokens", "In progress"))
        tasks.rows.add(DataRow("T-103", "Keyboard audit", "Ready"))
        tasks.rows.add(DataRow("T-104", "Release notes", "Planned"))
        tasks.rows.add(DataRow("T-105", "Accessibility review", "In progress"))
        tasks.rows.add(DataRow("T-106", "API integration", "Ready"))
        tasks.rows.add(DataRow("T-107", "Build pipeline", "In review"))
        tasks.rows.add(DataRow("T-108", "Cache invalidation", "Planned"))
        tasks.rows.add(DataRow("T-109", "Component gallery", "Ready"))
        tasks.rows.add(DataRow("T-110", "Input validation", "In progress"))
        tasks.rows.add(DataRow("T-111", "Layout polish", "In review"))
        tasks.rows.add(DataRow("T-112", "Responsive layout", "Planned"))
        let metrics = addNode(projects.id, "metrics.csv", false)
        metrics.rows.add(DataRow("M-01", "Build duration", "Healthy"))
        metrics.rows.add(DataRow("M-02", "Error rate", "Watch"))
        let archive = addNode(root.id, "archive", true)
        let completed = addNode(archive.id, "completed.csv", false)
        completed.rows.add(DataRow("A-01", "Prototype", "Done"))
    }

    private func addNode(parent: Int64, name: String, folder: Bool): VirtualNode {
        let node = VirtualNode(nextId, parent, name, folder)
        nextId++
        nodes.add(node)
        node
    }

    private func appendChildren(parent: Int64, depth: Int64, result: ArrayList<VirtualNode>, labels: ArrayList<String>): Unit {
        for (node in nodes) {
            if (!node.deleted && node.parent == parent) {
                var indent = ""
                for (_ in 0..depth) { indent += "  " }
                labels.add(indent + (if (node.folder) { if (unicode) { "▾ " } else { "+ " } } else { "  " }) + node.name)
                result.add(node)
                if (node.folder) { appendChildren(node.id, depth + 1, result, labels) }
            }
        }
    }

    func visibleNodes(): Array<VirtualNode> {
        let result = ArrayList<VirtualNode>()
        appendChildren(-1, 0, result, ArrayList<String>())
        result.toArray()
    }

    func treeLabels(): Array<String> {
        let result = ArrayList<VirtualNode>()
        let labels = ArrayList<String>()
        appendChildren(-1, 0, result, labels)
        labels.toArray()
    }

    func selectedNode(): VirtualNode {
        let visible = visibleNodes()
        let index = match (treeState.selected) { case Some(value) => value; case None => 0 }
        visible[max(0, min(index, visible.size - 1))]
    }

    func visibleRows(): Array<DataRow> {
        let node = selectedNode()
        let rows = ArrayList<DataRow>()
        if (!node.folder) {
            for (row in node.rows) {
                if (filter.isEmpty() || row.id.contains(filter) || row.name.contains(filter) || row.status.contains(filter)) {
                    rows.add(row)
                }
            }
        }
        // Stable insertion sort makes the ordering independent of display state.
        var i: Int64 = 1
        while (i < rows.size) {
            var j = i
            while (j > 0 && (if (descending) { rows[j].name > rows[j - 1].name } else { rows[j].name < rows[j - 1].name })) {
                let previous = rows[j - 1]
                rows[j - 1] = rows[j]
                rows[j] = previous
                j--
            }
            i++
        }
        rows.toArray()
    }

    private func selectedRow(): ?DataRow {
        let rows = visibleRows()
        let index = match (tableState.selectedRow) { case Some(value) => value; case None => -1 }
        if (index < 0 || index >= rows.size) { None } else { Some(rows[index]) }
    }

    // Selection belongs to a record, not its current position in the sorted view.
    private func restoreRowSelection(id: ?String, selectFirst!: Bool = false): Bool {
        let rows = visibleRows()
        if (let Some(wanted) <- id) {
            for (index in 0..rows.size) {
                if (rows[index].id == wanted) {
                    tableState.select(Some(index))
                    tableState.scrollToVisible(rows.size, max(1, viewport - 2))
                    return true
                }
            }
        }
        tableState.select(if (selectFirst && rows.size > 0) { Some(0) } else { None })
        tableState.offset = 0
        false
    }

    private func selectedRowId(): ?String {
        match (selectedRow()) { case Some(row) => Some(row.id); case None => None }
    }

    private func path(node: VirtualNode): String {
        if (node.parent < 0) { return node.name }
        for (parent in nodes) {
            if (parent.id == node.parent && !parent.deleted) { return path(parent) + "/" + node.name }
        }
        node.name
    }

    private func startInput(mode: String): Unit {
        input.clear()
        inputMode = mode
        input.setVisualState(focused: true, theme: Some(theme))
    }

    private func isDuplicate(parent: Int64, name: String, exceptId: Int64): Bool {
        for (node in nodes) {
            if (!node.deleted && node.parent == parent && node.name == name && node.id != exceptId) { return true }
        }
        false
    }

    private func deleteNode(id: Int64): Unit {
        for (node in nodes) {
            if (!node.deleted && node.parent == id) { deleteNode(node.id) }
        }
        for (node in nodes) { if (node.id == id) { node.deleted = true } }
    }

    private func submitInput(): Unit {
        let text = input.value.trimAscii()
        let node = selectedNode()
        match (inputMode) {
            case "filter" =>
                let previous = selectedRowId()
                filter = text
                let retained = restoreRowSelection(previous, selectFirst: true)
                let label = if (filter.isEmpty()) { "Filter cleared" } else { "Filter: ${filter}" }
                status = if (previous.isSome() && !retained) { label + " | previous row hidden" } else { label }
            case "edit" =>
                if (text.isEmpty()) { status = "Name cannot be empty" }
                else if (let Some(row) <- selectedRow()) {
                    row.name = text
                    let retained = restoreRowSelection(Some(row.id), selectFirst: true)
                    status = if (retained) { "Row name updated in memory" } else { "Row updated; hidden by filter" }
                }
            case "file" | "folder" =>
                let parent = if (node.folder) { node.id } else { node.parent }
                if (text.isEmpty() || text.contains("/")) { status = "Enter a non-empty name without /" }
                else if (isDuplicate(parent, text, -1)) { status = "A sibling already has that name" }
                else {
                    _ = addNode(parent, text, inputMode == "folder")
                    status = "Created ${text} in memory"
                }
            case "rename" =>
                if (node.parent < 0) { status = "Workspace cannot be renamed" }
                else if (text.isEmpty() || text.contains("/")) { status = "Enter a non-empty name without /" }
                else if (isDuplicate(node.parent, text, node.id)) { status = "A sibling already has that name" }
                else { node.name = text; status = "Renamed in memory" }
            case _ => ()
        }
        inputMode = ""
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                if (inputMode != "") {
                    match (key.code) {
                        case KeyCode.CtrlC => return UpdateResult.exit()
                        case KeyCode.Esc => inputMode = ""; status = "Cancelled"; return UpdateResult.next()
                        case KeyCode.Enter => submitInput(); return UpdateResult.next()
                        case _ => _ = input.handle(key); return UpdateResult.next()
                    }
                }
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                    case KeyCode.Tab => treeFocused = !treeFocused
                    case KeyCode.Up => move(-1)
                    case KeyCode.Down => move(1)
                    case KeyCode.Char(r'/') => startInput("filter")
                    case KeyCode.Char(r's') =>
                        let previous = selectedRowId()
                        descending = !descending
                        _ = restoreRowSelection(previous)
                        status = if (descending) { "Sorted by name descending" } else { "Sorted by name ascending" }
                    case KeyCode.Char(r'e') => if (selectedRow().isSome()) { startInput("edit") } else { status = "Select a row to edit its name" }
                    case KeyCode.Enter =>
                        if (!treeFocused) {
                            if (let Some(row) <- selectedRow()) { status = "${row.id}  |  ${row.name}  |  ${row.status}" }
                            else { status = "Select a row for details" }
                        }
                    case KeyCode.Char(r'f') => if (treeFocused) { startInput("file") }
                    case KeyCode.Char(r'n') => if (treeFocused) { startInput("folder") }
                    case KeyCode.Char(r'r') => if (treeFocused) { startInput("rename") }
                    case KeyCode.Char(r'd') =>
                        if (treeFocused) {
                            let node = selectedNode()
                            if (node.parent < 0) { status = "Workspace cannot be deleted" }
                            else {
                                let previous = match (treeState.selected) { case Some(value) => value; case None => 0 }
                                deleteNode(node.id)
                                treeState.select(Some(min(previous, visibleNodes().size - 1)))
                                tableState.select(Some(0))
                                status = "Deleted ${node.name} and its descendants in memory"
                            }
                        }
                    case _ => ()
                }
                UpdateResult.next()
            case Event.Paste(text) =>
                if (inputMode != "") { input.paste(singleLine(text)) }
                UpdateResult.next()
            case Event.Capabilities(value) => unicode = value.unicode; UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    private func singleLine(text: String): String {
        var result = ""
        for (rune in text.runes()) {
            let code = UInt32(rune)
            if (rune == r'\n' || rune == r'\r' || rune == r'\t') {
                result += " "
            } else if (code >= 32 && (code < 127 || code >= 160)) {
                result += rune.toString()
            }
        }
        result
    }

    private func move(delta: Int64): Unit {
        if (treeFocused) {
            treeState.move(delta, visibleNodes().size, viewportHeight: viewport)
            tableState.select(Some(0))
            tableState.offset = 0
        } else {
            tableState.move(delta, visibleRows().size, viewportHeight: max(1, viewport - 2))
        }
    }

    func render(frame: Frame): Unit {
        let full = frame.area
        let width = min(Int64(120), full.width)
        let a = Rect(full.x + max(0, (full.width - width) / 2), full.y, width, full.height)
        let canvas = frame.canvas(area: a)
        frame.fill(full, theme.canvas)
        let muted = theme.secondary
        let title = theme.accent
        let separator = if (unicode) { "  ·  " } else { "  |  " }
        let arrows = if (unicode) { "↑↓" } else { "Up/Down" }
        let focusLabel = if (treeFocused) { "FILES" } else { "ROWS" }
        canvas.drawText(a.x + 1, a.y + 1, "TERMCANVAS  /  DATA EXPLORER  /  ${focusLabel}", title)
        canvas.drawText(a.x + 1, a.y + 2, "IN-MEMORY DEMO" + separator + "no files are read or written", muted)
        let node = selectedNode()
        let rows = visibleRows()
        let filterLabel = if (filter.isEmpty()) { "all" } else { filter }
        let sortLabel = if (descending) { "Z-A" } else { "A-Z" }
        canvas.drawText(a.x + 1, a.y + 4,
            "${path(node)}  |  ${rows.size}/${node.rows.size} rows  |  filter: ${filterLabel}  |  name: ${sortLabel}", muted)
        let panelY = a.y + 6
        let contentHeight = max(9, max(visibleNodes().size + 2, rows.size + 4))
        let panelHeight = max(0, min(max(0, a.height - 15), contentHeight))
        viewport = max(1, panelHeight - 2)
        let treeWidth = max(24, min(30, (a.width - 3) * 28 / 100))
        let treeArea = Rect(a.x + 1, panelY, treeWidth, panelHeight)
        let availableTableWidth = max(0, a.width - treeWidth - 3)
        let activeMarker = if (unicode) { "›" } else { ">" }
        let markerWidth = displayWidth(activeMarker + " ", options: frame.textWidthOptions()) + 1
        var nameWidth: Int64 = 12
        for (row in rows) { nameWidth = max(nameWidth, displayWidth(row.name, options: frame.textWidthOptions()) + 1) }
        nameWidth = min(min(30, nameWidth), max(0, availableTableWidth - 27 - markerWidth))
        // Borders, horizontal padding, two column gaps, ID/status, and marker.
        let tableWidth = min(availableTableWidth, nameWidth + 27 + markerWidth)
        let roomy = a.width >= 100 && availableTableWidth - tableWidth >= 28
        let tableArea = Rect(treeArea.right + 1, panelY, tableWidth, panelHeight)
        treeState.scrollToVisible(visibleNodes().size, viewport)
        let rowCapacity = max(0, panelHeight - 4)
        tableState.scrollToVisible(rows.size, rowCapacity)
        let firstVisible = if (rowCapacity == 0 || rows.size == 0) { Int64(0) } else { tableState.offset + 1 }
        let lastVisible = if (rowCapacity == 0 || rows.size == 0) { Int64(0) } else { min(rows.size, tableState.offset + rowCapacity) }
        let cells = ArrayList<Array<String>>()
        for (row in rows) { cells.add([row.id, row.name, row.status]) }
        let inactiveSelection = theme.surface
        let treeMarker = activeMarker
        let rowMarker = activeMarker + " "
        frame.renderWidget(List(treeLabels(), state: Some(treeState), focused: treeFocused, theme: Some(theme),
            selectionMarker: Some(treeMarker), selectedStyle: Some(if (treeFocused) { theme.selected } else { inactiveSelection }),
            block: Block(BlockOptions(title: " FILES ", theme: Some(theme), state: if (treeFocused) { BoxState.Focused } else { BoxState.Normal }))), treeArea)
        frame.renderWidget(Table(["ID", "NAME *", "STATUS"], cells.toArray(), widths: [9, nameWidth, 12],
            state: Some(tableState), focused: !treeFocused, theme: Some(theme),
            selectionMarker: Some(rowMarker), selectedStyle: Some(if (treeFocused) { inactiveSelection } else { theme.selected }),
            headerStyle: theme.secondary,
            block: Block(BlockOptions(title: " ROWS ${firstVisible}-${lastVisible}/${rows.size} ", theme: Some(theme), padding: Spacing.symmetric(horizontal: 1),
                state: if (treeFocused) { BoxState.Normal } else { BoxState.Focused }))), tableArea)
        let detailArea = if (roomy) {
            Rect(tableArea.right + 2, panelY, max(0, a.right - tableArea.right - 3), panelHeight)
        } else {
            Rect(a.x + 1, panelY + panelHeight + 1, max(0, a.width - 2), 2)
        }
        let detailCanvas = frame.canvas(area: detailArea)
        let detailY = detailArea.y
        let detailX = detailArea.x
        if (node.folder) {
            detailCanvas.drawText(detailX, detailY, "FOLDER  ${path(node)}", theme.heading)
            detailCanvas.drawText(detailX, detailY + 1, "Select a data file to browse its rows.", muted)
        } else if (let Some(row) <- selectedRow()) {
            if (roomy) {
                detailCanvas.drawText(detailX, detailY, "SELECTED RECORD", theme.heading)
                detailCanvas.drawText(detailX, detailY + 1, "${row.id}  /  ${row.name}", theme.normal)
                detailCanvas.drawText(detailX, detailY + 2, "Status: ${row.status}", muted)
                detailCanvas.drawText(detailX, detailY + 3, "NAME * is editable", muted)
                detailCanvas.drawText(detailX, detailY + 5, "CURRENT RESULTS", theme.heading)
                let statuses = ArrayList<String>()
                let counts = ArrayList<Int64>()
                for (entry in rows) {
                    var found: Int64 = -1
                    for (index in 0..statuses.size) {
                        if (statuses[index] == entry.status) { found = index; break }
                    }
                    if (found < 0) { statuses.add(entry.status); counts.add(1) }
                    else { counts[found]++ }
                }
                let summaryCount = min(statuses.size, max(0, detailArea.height - 6))
                for (index in 0..summaryCount) {
                    detailCanvas.drawText(detailX, detailY + 6 + index, "${statuses[index]}  ${counts[index]}", muted)
                }
            } else {
                detailCanvas.drawText(detailX, detailY, "SELECTED  ${row.id}  /  ${row.name}", theme.heading)
                detailCanvas.drawText(detailX, detailY + 1, "Status: ${row.status}  |  NAME * is editable", muted)
            }
        } else {
            detailCanvas.drawText(detailX, detailY, "NO ROW SELECTED", theme.heading)
            detailCanvas.drawText(detailX, detailY + 1, "Change the filter or select a file with rows.", muted)
        }
        let footer = a.y + max(0, a.height - 4)
        canvas.drawText(a.x + 1, footer, status, muted)
        if (inputMode != "") {
            canvas.drawText(a.x + 1, footer + 1, "${inputMode}: ", title)
            let inputArea = Rect(a.x + 12, footer + 1, max(0, a.width - 14), 1)
            frame.renderWidget(input, inputArea)
            if (inputArea.width > 0 && inputArea.y < a.bottom) { frame.setCursor(input.cursorPosition(inputArea, options: frame.textWidthOptions())) }
            canvas.drawText(a.x + 1, footer + 2, "Enter apply" + separator + "Esc cancel", muted)
        } else {
            canvas.drawText(a.x + 1, footer + 1, "Tab focus  ${arrows} select  q quit", muted)
            if (treeFocused) {
                canvas.drawText(a.x + 1, footer + 2, "Files: f new file  n new folder  r rename  d delete", muted)
            } else {
                canvas.drawText(a.x + 1, footer + 2, "Rows: / filter  s sort  e edit  Enter details", muted)
            }
        }
    }
}

main(): Int64 {
    let app = DataShowcase()
    App(bracketedPaste: true, hideCursor: true).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
