package cjtui_data_browser

import core.*

class DataBrowser {
    let root = TreeNode("root", "workspace", expanded: true, children: [
        TreeNode("src", "src", expanded: true, children: [TreeNode("widgets", "widgets.cj"), TreeNode("app", "app.cj")]),
        TreeNode("examples", "examples", children: [TreeNode("taskpad", "taskpad"), TreeNode("arcade", "arcade")])
    ])
    let tree = Tree([root], block: Block(title: "Tree"))
    let focus = FocusManager()
    let menuBar = MenuBar(["Tree", "Rows", "Files"], selected: 1)
    let table = VirtualTable(
        [TableColumn("ID", width: 6), TableColumn("Name", width: 18), TableColumn("State", width: 10)],
        120,
        { row => ["${row}", "record-${row}", if (row % 3 == 0) { "ready" } else { "pending" }] },
        selectedRow: Some(2),
        selectedColumn: 1,
        block: Block(title: "VirtualTable")
    )
    let picker = FilePicker(path: ".", extension: ".cj")
    let dialog = FileDialog(path: ".", extension: ".cj", title: "Open file")
    var showDialog = false
    var status = "Tab changes panel; arrows navigate; / filters; f opens dialog"
    var treeArea = Rect(0, 0, 1, 1)
    var tableArea = Rect(0, 0, 1, 1)
    var pickerArea = Rect(0, 0, 1, 1)
    var dialogArea = Rect(0, 0, 1, 1)

    init() {
        focus.add("tree")
        focus.add("rows")
        focus.add("files")
        _ = focus.focus("rows")
    }

    func update(event: Event): ControlFlow {
        match (event) {
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
                    case KeyCode.Char(r'h') =>
                        if (focus.isFocused("files")) { picker.toggleHidden() }
                    case _ => routeFocusedKey(key)
                }
            case _ => ()
        }
        ControlFlow.Continue
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
        frame.renderWidget(StatusBar(left: "focus: ${focusedPanel} | ${status}", right: "offset ${table.offset}/120", style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

main(): Int64 {
    let app = DataBrowser()
    App(rawMode: true, alternateScreen: true, hideCursor: true).run(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
