package cjtui_data_browser

import core.*
import std.collection.*

class DataBrowser {
    let treeModel = LazyTreeModel(BrowserTreeSource())
    let tree: Tree
    let focus = FocusManager()
    let menuBar = MenuBar(["Tree", "Rows", "Files"], selected: 1)
    let model = PagedTableModel(pageSize: 64, maxPages: 4)
    let source = BrowserRows()
    let table: VirtualTable
    private let completions = BrowserPageMailbox()
    private let active = HashMap<String, TablePageRequest>()
    private var retry = false
    let picker = FilePicker(path: ".", extension: ".cj")
    let dialog = FileDialog(path: ".", extension: ".cj", title: "Open file")
    var showDialog = false
    var status = "Tab panels; / filter; s sort; e error; r retry; f files"
    var treeArea = Rect(0, 0, 1, 1)
    var tableArea = Rect(0, 0, 1, 1)
    var pickerArea = Rect(0, 0, 1, 1)
    var dialogArea = Rect(0, 0, 1, 1)

    init() {
        _ = treeModel.setExpanded("root", true)
        tree = Tree(treeModel, block: Block(title: "Tree"))
        table = VirtualTable([TableColumn("ID", width: 8), TableColumn("Name", width: 18), TableColumn("State", width: 10)], model,
            block: Block(title: "VirtualTable"))
        model.selectIndex(2)
        table.selectedColumn = 1
        focus.add("tree")
        focus.add("rows")
        focus.add("files")
        _ = focus.focus("rows")
    }

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.AsyncCompleted(id, Event.DataReady(_, requestId)) =>
                let result = completions.take(requestId)
                if (let Some(request) <- active.get(id)) {
                    if (request.requestId == requestId) {
                        active.remove(id)
                        if (let Some(value) <- result) {
                            if (let Some(page) <- value.page) { _ = model.accept(request, page) }
                            else { _ = model.fail(request, value.error) }
                        } else { _ = model.fail(request, "Page completion queue was full; press r to retry") }
                    }
                }
            case Event.AsyncFailed(id, message) =>
                if (let Some(request) <- active.get(id)) { _ = model.fail(request, message); active.remove(id) }
            case Event.AsyncCancelled(id) =>
                if (let Some(request) <- active.get(id)) { _ = model.fail(request, "Request cancelled; r retries"); active.remove(id) }
            case Event.Mouse(mouse) =>
                if (!showDialog) {
                    if (widgetHitTest(mouse, tableArea)) { _ = focus.focus("rows"); _ = table.handle(mouse, tableArea) }
                    else if (widgetHitTest(mouse, treeArea)) { _ = focus.focus("tree"); _ = tree.handle(mouse, treeArea) }
                }
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return ControlFlow.Exit
                    case KeyCode.Char(r'f') =>
                        showDialog = !showDialog
                        return ControlFlow.Continue
                    case KeyCode.Esc =>
                        if (showDialog) {
                            showDialog = false
                            return ControlFlow.Continue
                        }
                    case _ => ()
                }
                if (showDialog) {
                    _ = dialog.handle(key, dialogViewportHeight())
                    return ControlFlow.Continue
                }
                if (focus.handle(key)) { return ControlFlow.Continue }
                match (key.code) {
                    case KeyCode.Char(r'/') =>
                        if (focus.isFocused("rows")) {
                            if (table.filterText.isEmpty()) {
                                table.setFilter("ready")
                                status = "filter: ready"
                            } else {
                                table.setFilter("")
                                status = "filter: all"
                            }
                        }
                    case KeyCode.Char(r's') =>
                        if (focus.isFocused("rows")) { table.sortBy(0, descending: !table.sortDescending); status = "external sort" }
                    case KeyCode.Char(r'e') =>
                        if (focus.isFocused("rows")) { table.setFilter("!error"); status = "provider error demo; / clears filter" }
                    case KeyCode.Char(r'r') => retry = true
                    case KeyCode.Char(r'h') =>
                        if (focus.isFocused("files")) { picker.toggleHidden() }
                    case _ => routeFocusedKey(key)
                }
            case _ => ()
        }
        ControlFlow.Continue
    }

    func updateWithCommands(event: Event): UpdateResult {
        let flow = update(event)
        match (flow) { case ControlFlow.Exit => return UpdateResult.exit(); case _ => () }
        let requests = model.requestViewport(table.offset, tableViewportHeight(), retry: retry)
        retry = false
        let commands = ArrayList<Command>()
        let obsolete = ArrayList<String>()
        for ((id, request) in active) { if (!model.isPending(request)) { obsolete.add(id) } }
        for (id in obsolete) { active.remove(id); commands.add(Command.CancelAsync(id)) }
        for (request in requests) {
            let id = "table-page-${request.requestId}"
            active.add(id, request)
            commands.add(Command.AsyncTask(id, { =>
                let result = try { BrowserPageResult(request.requestId, Some(source.load(request)), "") }
                    catch (error: Exception) { BrowserPageResult(request.requestId, Option<TablePage>.None, error.message) }
                completions.put(result)
                Event.DataReady("table", request.requestId)
            }))
        }
        let allowed = ArrayList<Int64>()
        for ((_, request) in active) { allowed.add(request.requestId) }
        completions.retain(allowed.toArray())
        UpdateResult(command: Command.Batch(commands.toArray()))
    }

    private func routeFocusedKey(key: KeyEvent): Unit {
        match (focus.current()) {
            case Some("tree") => _ = tree.handle(key, treeViewportHeight())
            case Some("rows") => _ = table.handle(key, tableViewportHeight())
            case Some("files") => _ = picker.handle(key, pickerViewportHeight())
            case _ => ()
        }
    }

    private func treeViewportHeight(): Int64 {
        max(1, Block(title: "Tree").inner(treeArea).height)
    }

    private func tableViewportHeight(): Int64 {
        let headerRows = if (table.stickyHeader) { Int64(1) } else { Int64(0) }
        max(1, Block(title: "VirtualTable").inner(tableArea).height - headerRows)
    }

    private func pickerViewportHeight(): Int64 {
        max(1, Block(title: picker.path).inner(pickerArea).height)
    }

    private func dialogViewportHeight(): Int64 {
        max(1, Block(title: dialog.picker.path).inner(dialogArea).height)
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(12), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        menuBar.selected = match (focus.current()) {
            case Some("tree") => 0
            case Some("rows") => 1
            case Some("files") => 2
            case _ => 0
        }
        let focusedPanel = match (focus.current()) {
            case Some("tree") => "Tree"
            case Some("rows") => "Rows"
            case Some("files") => "Files"
            case _ => "None"
        }
        frame.renderWidget(menuBar, rows[0])
        let cols = Layout.horizontal([Constraint.Percent(28), Constraint.Percent(42), Constraint.Min(20)]).withGap(1).split(rows[1])
        treeArea = cols[0]
        tableArea = cols[1]
        pickerArea = cols[2]
        dialogArea = Rect(frame.area.x + 6, frame.area.y + 3, max(30, frame.area.width - 12), max(10, frame.area.height - 6))
        frame.renderWidget(tree, treeArea)
        frame.renderWidget(table, tableArea)
        frame.renderWidget(picker, pickerArea)
        if (showDialog) { frame.renderWidget(dialog, dialogArea) }
        frame.renderWidget(StatusBar(left: "focus: ${focusedPanel} | ${status}", right: "offset ${table.offset}/${model.totalRows()} cache ${model.cachedPageCount()}", style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

main(): Int64 {
    let app = DataBrowser()
    App(rawMode: true, alternateScreen: true, hideCursor: true, mouse: true, tickEvery: Some(100 * Duration.millisecond)).runWithCommands(
        { frame => app.render(frame) },
        { event => app.updateWithCommands(event) }
    )
    0
}
