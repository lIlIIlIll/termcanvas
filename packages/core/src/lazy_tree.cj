package core

import std.collection.*

public class LazyTreeNode {
    public let id: String
    public let label: String
    public let childCount: Int64
    public init(id: String, label: String, childCount!: Int64 = 0) {
        this.id = id; this.label = label; this.childCount = max(0, childCount)
    }
}

// Indexed children and an ID-to-path lookup keep large sibling sets lazy.
// Paths contain zero-based child indexes from the root. IDs must be stable.
public interface TreeDataSource {
    func rootCount(): Int64
    func nodeAt(path: Array<Int64>): ?LazyTreeNode
    func pathForId(id: String): ?Array<Int64>
}

public class LazyTreeRow {
    public let node: LazyTreeNode
    public let depth: Int64
    public let expanded: Bool
    public let index: Int64
    init(node: LazyTreeNode, depth: Int64, expanded: Bool, index: Int64) {
        this.node = node; this.depth = depth; this.expanded = expanded; this.index = index
    }
}

class LazyTreeBranch {
    let path: Array<Int64>
    let count: Int64
    let children = ArrayList<LazyTreeBranch>()
    init(path: Array<Int64>, count: Int64) { this.path = Array<Int64>(path.size, { i => path[i] }); this.count = max(0, count) }
    func visibleCount(): Int64 {
        var total = count
        for (child in children) { total = lazyTreeAdd(total, child.visibleCount()) }
        total
    }
}

// Own this model in application state. Only expanded branches are retained;
// rendering a million collapsed siblings reads only the visible node records.
public class LazyTreeModel {
    private let source: TreeDataSource
    private var root: LazyTreeBranch
    private var selection: ?String = None
    public init(source: TreeDataSource) {
        this.source = source
        root = LazyTreeBranch([], source.rootCount())
    }
    public func visibleCount(): Int64 { root.visibleCount() }
    public func selectedId(): ?String { selection }
    public func findById(id: String): ?LazyTreeNode {
        if (let Some(path) <- source.pathForId(id)) {
            if (let Some(node) <- source.nodeAt(path)) { if (node.id == id) { return Some(node) } }
        }
        None
    }
    public func selectedIndex(): ?Int64 {
        if (let Some(id) <- selection) {
            if (let Some(path) <- source.pathForId(id)) { return indexForPath(path) }
        }
        None
    }
    public func selectById(id: String): Bool {
        if (findById(id).isNone()) { return false }
        if (let Some(path) <- source.pathForId(id)) {
            if (indexForPath(path).isSome()) { selection = Some(id); return true }
        }
        false
    }
    public func selectIndex(index: Int64): Bool {
        if (let Some(row) <- rowAt(index)) { selection = Some(row.node.id); return true }
        false
    }
    public func rowAt(index: Int64): ?LazyTreeRow {
        if (index < 0 || index >= visibleCount()) { return None }
        findRow(root, index, index)
    }
    public func rows(offset: Int64, height: Int64): Array<LazyTreeRow> {
        let out = ArrayList<LazyTreeRow>()
        var index = max(0, offset)
        let total = visibleCount()
        while (index < total && out.size < max(0, height)) {
            if (let Some(row) <- rowAt(index)) { out.add(row) } else { break }
            index++
        }
        out.toArray()
    }
    public func setExpanded(id: String, expanded: Bool): Bool {
        let path = match (source.pathForId(id)) { case Some(value) => value; case None => return false }
        if (path.size == 0) { return false }
        var parent = root
        for (depth in 0..path.size - 1) {
            let next = childBranch(parent, path[depth])
            parent = match (next) { case Some(value) => value; case None => return false }
        }
        let index = path[path.size - 1]
        if (index < 0 || index >= parent.count) { return false }
        let node = match (source.nodeAt(path)) { case Some(value) => value; case None => return false }
        if (node.id != id) { return false }
        for (i in 0..parent.children.size) {
            if (parent.children[i].path[path.size - 1] == index) {
                if (!expanded) { parent.children.remove(at: i) }
                return true
            }
        }
        if (!expanded) { return true }
        if (node.childCount == 0) { return true }
        let branch = LazyTreeBranch(path, node.childCount)
        var at = parent.children.size
        parent.children.add(branch)
        while (at > 0 && parent.children[at - 1].path[path.size - 1] > index) {
            parent.children[at] = parent.children[at - 1]; at--
        }
        parent.children[at] = branch
        true
    }
    public func toggleSelected(): Bool {
        if (let Some(index) <- selectedIndex()) {
            if (let Some(row) <- rowAt(index)) { return setExpanded(row.node.id, !row.expanded) }
        }
        false
    }
    public func collapseAll(): Unit { root.children.clear() }
    // After a provider revision, discard stale indexed branches while keeping ID selection.
    public func refresh(): Unit { root = LazyTreeBranch([], source.rootCount()) }
    private func childBranch(parent: LazyTreeBranch, index: Int64): ?LazyTreeBranch {
        for (child in parent.children) { if (child.path[child.path.size - 1] == index) { return Some(child) } }
        None
    }
    private func makePath(parent: LazyTreeBranch, index: Int64): Array<Int64> {
        Array<Int64>(parent.path.size + 1, { i => if (i == parent.path.size) { index } else { parent.path[i] } })
    }
    private func leafRow(parent: LazyTreeBranch, childIndex: Int64, absolute: Int64): ?LazyTreeRow {
        let path = makePath(parent, childIndex)
        if (let Some(node) <- source.nodeAt(path)) {
            return Some(LazyTreeRow(node, parent.path.size, childBranch(parent, childIndex).isSome(), absolute))
        }
        None
    }
    private func findRow(parent: LazyTreeBranch, relative: Int64, absolute: Int64): ?LazyTreeRow {
        var remaining = relative
        var childIndex: Int64 = 0
        for (branch in parent.children) {
            let index = branch.path[branch.path.size - 1]
            let run = index - childIndex
            if (remaining < run) { return leafRow(parent, childIndex + remaining, absolute) }
            remaining -= run
            if (remaining == 0) { return leafRow(parent, index, absolute) }
            remaining--
            let descendants = branch.visibleCount()
            if (remaining < descendants) { return findRow(branch, remaining, absolute) }
            remaining -= descendants
            childIndex = index + 1
        }
        if (remaining < parent.count - childIndex) { return leafRow(parent, childIndex + remaining, absolute) }
        None
    }
    private func indexForPath(path: Array<Int64>): ?Int64 {
        if (path.size == 0) { return None }
        var parent = root
        var result: Int64 = 0
        for (depth in 0..path.size) {
            let index = path[depth]
            if (index < 0 || index >= parent.count) { return None }
            if (result > Int64.Max - index) { return None }
            result += index
            for (child in parent.children) {
                if (child.path[depth] < index) {
                    let count = child.visibleCount()
                    if (result > Int64.Max - count) { return None }
                    result += count
                }
            }
            if (depth + 1 < path.size) {
                parent = match (childBranch(parent, index)) { case Some(value) => value; case None => return None }
                if (result == Int64.Max) { return None }
                result++
            }
        }
        if (result >= visibleCount()) { None } else { Some(result) }
    }
}

func lazyTreeAdd(left: Int64, right: Int64): Int64 {
    if (left > Int64.Max - right) { Int64.Max } else { left + right }
}
