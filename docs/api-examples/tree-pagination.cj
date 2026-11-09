package cjtui_api_example

import core.*

main(): Int64 {
    let column = TableColumn("Name", width: 12)
    let state = TableStatus.Loading
    let table = VirtualTable([column], 0, { _ => Array<String>() })
    table.status = state
    table.render(Rect(0, 0, 40, 4), Buffer(Rect(0, 0, 40, 4)))
    if (column.width != 12 || column.title != "Name") { throw IllegalStateException("column failed") }
    let pages = Paginator(pageSize: 10, total: 21)
    _ = pages.handle(KeyEvent(KeyCode.End))
    if (pages.pageCount() != 3 || pages.offset() != 20) { throw IllegalStateException("pagination failed") }
    pages.previous()
    if (pages.page != 1) { throw IllegalStateException("previous page failed") }
    let child = TreeNode("child", "Source")
    let root = TreeNode("root", "Project", expanded: true)
    root.add(child)
    let tree = Tree([root])
    let buffer = Buffer(Rect(0, 0, 40, 8))
    tree.render(Rect(0, 0, 40, 8), buffer)
    if (!tree.selectById("child") || tree.selectedId() != Some("child") || root.childNodes().size != 1) {
        throw IllegalStateException("tree selection failed")
    }
    tree.collapseAll()
    if (root.expanded || tree.selectById("child")) { throw IllegalStateException("tree collapse failed") }
    tree.expandAll()
    if (!tree.selectById("child")) { throw IllegalStateException("tree expand failed") }
    return 0
}
