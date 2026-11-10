package core

import std.collection.*

/** 惰性树节点的稳定身份、标签和子节点数量。 */
public class LazyTreeNode {
    /** 节点的稳定身份。 */
    public let id: String
    /** 节点的显示标签。 */
    public let label: String
    /** 直接子节点数量。 */
    public let childCount: Int64
    /** 创建节点；负子节点数置零。
     * @param id 节点的稳定身份
     * @param label 显示标签
     * @param childCount 直接子节点数量
     */
    public init(id: String, label: String, childCount!: Int64 = 0) {
        this.id = id; this.label = label; this.childCount = max(0, childCount)
    }
}

// Indexed children and an ID-to-path lookup keep large sibling sets lazy.
// Paths contain zero-based child indexes from the root. IDs must be stable.
/** 提供按索引路径访问的惰性树。路径从根开始，每级使用从零开始的子节点索引；节点 ID 应保持稳定。 */
public interface TreeDataSource {
    /** 返回根节点数量。
     * @return 根节点数
     */
    func rootCount(): Int64
    /** 按索引路径读取节点。
     * @param path 从根节点开始的索引路径
     * @return 节点存在时返回节点，否则返回 None
     */
    func nodeAt(path: Array<Int64>): ?LazyTreeNode
    /** 查找节点 ID 对应的索引路径。
     * @param id 节点稳定身份
     * @return 找到时返回路径，否则返回 None
     */
    func pathForId(id: String): ?Array<Int64>
}

/** 惰性树中的一个可见行及其显示位置。 */
public class LazyTreeRow {
    /** 行对应的节点。 */
    public let node: LazyTreeNode
    /** 节点深度；根节点为零。 */
    public let depth: Int64
    /** 节点是否有已展开的子分支。 */
    public let expanded: Bool
    /** 从零开始的可见行索引。 */
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
/** 维护惰性树的展开分支和按 ID 保存的选择；只读取请求的可见节点。 */
public class LazyTreeModel {
    private let source: TreeDataSource
    private var root: LazyTreeBranch
    private var selection: ?String = None
    /** 使用数据源创建模型，初始时所有分支折叠。
     * @param source 惰性树数据源
     */
    public init(source: TreeDataSource) {
        this.source = source
        root = LazyTreeBranch([], source.rootCount())
    }
    /** 返回当前可见行总数。
     * @return 可见行数
     */
    public func visibleCount(): Int64 { root.visibleCount() }
    /** 获取已保存的选择 ID，即使该节点当前被折叠隐藏也会保留。
     * @return 已选择的节点 ID，未选择时为 None
     */
    public func selectedId(): ?String { selection }
    /** 通过数据源查找节点并核对其 ID，不要求节点可见。
     * @param id 节点身份
     * @return 找到匹配节点时返回节点，否则返回 None
     */
    public func findById(id: String): ?LazyTreeNode {
        if (let Some(path) <- source.pathForId(id)) {
            if (let Some(node) <- source.nodeAt(path)) { if (node.id == id) { return Some(node) } }
        }
        None
    }
    /** 获取选择节点的当前可见行索引。
     * @return 选择可见时返回索引，否则返回 None
     */
    public func selectedIndex(): ?Int64 {
        if (let Some(id) <- selection) {
            if (let Some(path) <- source.pathForId(id)) { return indexForPath(path) }
        }
        None
    }
    /** 按 ID 选择当前可见的节点；失败时保留现有选择。
     * @param id 节点身份
     * @return 选择成功时为 true
     */
    public func selectById(id: String): Bool {
        if (findById(id).isNone()) { return false }
        if (let Some(path) <- source.pathForId(id)) {
            if (indexForPath(path).isSome()) { selection = Some(id); return true }
        }
        false
    }
    /** 按可见行索引选择节点；失败时保留现有选择。
     * @param index 从零开始的可见行索引
     * @return 选择成功时为 true
     */
    public func selectIndex(index: Int64): Bool {
        if (let Some(row) <- rowAt(index)) { selection = Some(row.node.id); return true }
        false
    }
    /** 读取指定可见行。
     * @param index 从零开始的可见行索引
     * @return 存在时返回行，否则返回 None
     */
    public func rowAt(index: Int64): ?LazyTreeRow {
        if (index < 0 || index >= visibleCount()) { return None }
        findRow(root, index, index)
    }
    /** 读取可见行窗口；负偏移和高度按零处理。
     * @param offset 起始可见行索引
     * @param height 最多读取的行数
     * @return 按可见顺序排列的行
     */
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
    /** 设置可见节点的展开状态；叶节点或已处于目标状态时也可成功。
     * @param id 节点身份
     * @param expanded 是否展开
     * @return 找到有效节点并处理请求时为 true
     */
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
    /** 切换当前可见选择节点的展开状态。
     * @return 存在有效可见选择并处理请求时为 true
     */
    public func toggleSelected(): Bool {
        if (let Some(index) <- selectedIndex()) {
            if (let Some(row) <- rowAt(index)) { return setExpanded(row.node.id, !row.expanded) }
        }
        false
    }
    /** 折叠全部根分支，保留选择 ID。 */
    public func collapseAll(): Unit { root.children.clear() }
    // After a provider revision, discard stale indexed branches while keeping ID selection.
    /** 重新读取根节点数量并丢弃展开分支，保留选择 ID。 */
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
