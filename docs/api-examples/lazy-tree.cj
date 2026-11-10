package cjtui_api_example

import core.*

class ProjectTree <: TreeDataSource {
    public func rootCount(): Int64 { 1 }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (path.size == 1 && path[0] == 0) { return Some(LazyTreeNode("project", "Project", childCount: 1)) }
        if (path.size == 2 && path[0] == 0 && path[1] == 0) { return Some(LazyTreeNode("task", "Build")) }
        None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "project") { return Some([Int64(0)]) }
        if (id == "task") { return Some([Int64(0), Int64(0)]) }
        None
    }
}

main(): Int64 {
    let source: TreeDataSource = ProjectTree()
    let model = LazyTreeModel(source)
    if (source.rootCount() != 1 || source.nodeAt([Int64(0)]).isNone() || source.pathForId("task").isNone() ||
        model.visibleCount() != 1 || !model.selectById("project") || !model.toggleSelected()) {
        throw IllegalStateException("tree expansion failed")
    }
    let row = model.rowAt(1).getOrThrow()
    if (model.visibleCount() != 2 || row.node.id != "task" || row.node.label != "Build" ||
        row.node.childCount != 0 || row.depth != 1 || row.expanded || row.index != 1 ||
        model.rows(0, 2).size != 2 || !model.selectIndex(1) ||
        model.selectedId().getOrThrow() != "task" || model.selectedIndex().getOrThrow() != 1 ||
        model.findById("project").isNone()) { throw IllegalStateException("incorrect tree rows") }
    if (!model.setExpanded("project", false) || model.visibleCount() != 1) {
        throw IllegalStateException("tree collapse failed")
    }
    model.collapseAll()
    model.refresh()
    if (model.visibleCount() != 1) { throw IllegalStateException("tree refresh failed") }
    return 0
}
