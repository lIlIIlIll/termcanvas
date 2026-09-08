package termcanvas_data_browser

import core.*

class DataBrowser {
    let root = TreeNode("root", "workspace", expanded: true, children: [
        TreeNode("src", "src", expanded: true, children: [TreeNode("widgets", "widgets.cj"), TreeNode("app", "app.cj")]),
        TreeNode("examples", "examples", children: [TreeNode("taskpad", "taskpad"), TreeNode("arcade", "arcade")])
    ])
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
    let pager = Paginator(pageSize: 12, total: 120)
    var showDialog = false
    var status = "arrows move table, / filters, f opens file dialog"

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return ControlFlow.Exit
                    case KeyCode.Char(r'f') => showDialog = !showDialog
                    case KeyCode.Char(r'/') => table.setFilter("ready"); status = "filter: ready"
                    case KeyCode.Char(r'h') => picker.toggleHidden()
                    case KeyCode.PageDown | KeyCode.PageUp | KeyCode.Left | KeyCode.Right =>
                        _ = pager.handle(key)
                        table.offset = pager.offset()
                    case _ =>
                        if (showDialog) {
                            _ = dialog.handle(key, 10)
                        } else {
                            _ = table.handle(key, 10)
                            _ = picker.handle(key, 10)
                        }
                }
            case _ => ()
        }
        ControlFlow.Continue
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(12), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        frame.renderWidget(MenuBar(["Tree", "Rows", "Files"], selected: 1), rows[0])
        let cols = Layout.horizontal([Constraint.Percent(28), Constraint.Percent(42), Constraint.Min(20)]).withGap(1).split(rows[1])
        frame.renderWidget(Tree([root], block: Block(title: "Tree")), cols[0])
        frame.renderWidget(table, cols[1])
        frame.renderWidget(picker, cols[2])
        if (showDialog) {
            frame.renderWidget(dialog, Rect(frame.area.x + 6, frame.area.y + 3, max(30, frame.area.width - 12), max(10, frame.area.height - 6)))
        }
        frame.renderWidget(StatusBar(left: status, right: "page ${pager.page + 1}/${max(1, pager.pageCount())}", style: Style(fg: Color.White, bg: Color.Black)), rows[2])
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
