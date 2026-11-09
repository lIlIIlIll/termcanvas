package core

import std.collection.*

/** 选择模型维护选中集合的方式。 */
public enum SelectionMode {
    /** 禁止通过 select 和 toggle 修改选中集合。 */
    | NoSelection
    /** 最多保存一个选中项。 */
    | Single
    /** 可保存多个选中项。 */
    | Multiple
}

/** 维护当前索引和选中索引集合；移动当前索引不会自动修改选中集合。 */
public class SelectionModel {
    /** 选中集合的操作模式。 */
    public let mode: SelectionMode
    /** 当前索引；可与选中集合独立变化。 */
    public var current: ?Int64
    private let selected = ArrayList<Int64>()

    /** 创建选择模型；非禁选模式下会把初始索引加入选中集合，负值按零加入。
     * @param mode 选择模式
     * @param current 初始当前索引
     */
    public init(mode!: SelectionMode = SelectionMode.Single, current!: ?Int64 = None) {
        this.mode = mode
        this.current = current
        match (current) {
            case Some(index) =>
                if (!isNoneSelection(mode)) { selected.add(max(0, index)) }
            case None => ()
        }
    }

    /** 清除当前索引和选中集合。 */
    public func clear(): Unit {
        current = None
        while (selected.size > 0) {
            selected.remove(at: 0)
        }
    }

    /** 选择索引；单选时替换原集合，多选时追加，禁选时不操作。
     * @param index 索引，负值按零处理
     */
    public func select(index: Int64): Unit {
        if (isNoneSelection(mode)) { return }
        let value = max(0, index)
        current = Some(value)
        if (isSingleSelection(mode)) {
            while (selected.size > 0) { selected.remove(at: 0) }
            selected.add(value)
        } else if (!isSelected(value)) {
            selected.add(value)
        }
    }

    /** 切换多选项；单选时等同于选择，禁选时不操作。
     * @param index 索引，负值按零处理
     */
    public func toggle(index: Int64): Unit {
        if (isNoneSelection(mode)) { return }
        let value = max(0, index)
        if (isSingleSelection(mode)) {
            select(value)
            return
        }
        var i: Int64 = 0
        while (i < selected.size) {
            if (selected[i] == value) {
                selected.remove(at: i)
                current = Some(value)
                return
            }
            i++
        }
        selected.add(value)
        current = Some(value)
    }

    /** 移动当前索引并限制到有效范围，总数为正时不更改选中集合；总数非正时清除状态。
     * @param delta 移动量
     * @param total 可用项总数
     * @return 移动后的索引；总数非正时为 None
     */
    public func move(delta: Int64, total: Int64): ?Int64 {
        if (total <= 0) {
            clear()
            return None
        }
        let base = match (current) {
            case Some(value) => value
            case None => if (delta >= 0) { -1 } else { total }
        }
        let next = clamp(base + delta, 0, total - 1)
        current = Some(next)
        Some(next)
    }

    /** 检查索引是否位于选中集合。
     * @param index 待检查索引
     * @return 已选中时为 true
     */
    public func isSelected(index: Int64): Bool {
        for (value in selected) {
            if (value == index) { return true }
        }
        false
    }

    /** 取得选中索引数组的副本。
     * @return 按加入顺序排列的选中索引
     */
    public func selectedIndices(): Array<Int64> {
        selected.toArray()
    }
}

/** 维护列表或文本视图的滚动偏移。 */
public class ScrollState {
    /** 首个可见项的索引；调用方可直接修改。 */
    public var offset: Int64

    /** 创建滚动状态；负偏移按零处理。
     * @param offset 初始偏移
     */
    public init(offset!: Int64 = 0) {
        this.offset = max(0, offset)
    }

    /** 按增量滚动并限制到可用范围。
     * @param delta 滚动量
     * @param total 项目总数
     * @param viewport 可见项目数
     */
    public func scroll(delta: Int64, total: Int64, viewport: Int64): Unit {
        offset = clamp(offset + delta, 0, max(0, total - max(0, viewport)))
    }

    /** 将偏移设置为目标索引并限制到可用范围。
     * @param index 目标偏移
     * @param total 项目总数
     * @param viewport 可见项目数
     */
    public func scrollTo(index: Int64, total: Int64, viewport: Int64): Unit {
        offset = clamp(index, 0, max(0, total - max(0, viewport)))
    }

    /** 调整偏移以显示指定索引；总数或视口非正时偏移置零。
     * @param index 要显示的索引
     * @param total 项目总数
     * @param viewport 可见项目数
     */
    public func ensureVisible(index: Int64, total: Int64, viewport: Int64): Unit {
        if (total <= 0 || viewport <= 0) {
            offset = 0
            return
        }
        let current = clamp(index, 0, total - 1)
        if (current < offset) {
            offset = current
        } else if (current >= offset + viewport) {
            offset = current - viewport + 1
        }
        offset = clamp(offset, 0, max(0, total - viewport))
    }

    /** 处理方向、翻页、Home 和 End 按键。
     * @param key 输入按键
     * @param total 项目总数
     * @param viewport 可见项目数
     * @return 按键受支持时为 true
     */
    public func handle(key: KeyEvent, total: Int64, viewport: Int64): Bool {
        match (key.code) {
            case KeyCode.Up => scroll(-1, total, viewport); true
            case KeyCode.Down => scroll(1, total, viewport); true
            case KeyCode.PageUp => scroll(-max(1, viewport), total, viewport); true
            case KeyCode.PageDown => scroll(max(1, viewport), total, viewport); true
            case KeyCode.Home => offset = 0; true
            case KeyCode.End => offset = max(0, total - max(0, viewport)); true
            case _ => false
        }
    }
}

/** 维护排序列和排序方向。 */
public class SortState {
    /** 当前排序列；None 表示未设置。 */
    public var column: ?Int64
    /** 是否降序。 */
    public var descending: Bool

    /** 创建排序状态。
     * @param column 可选的排序列
     * @param descending 是否降序
     */
    public init(column!: ?Int64 = None, descending!: Bool = false) {
        this.column = column
        this.descending = descending
    }

    /** 设置排序列和方向；负列索引按零处理。
     * @param column 排序列
     * @param descending 是否降序
     */
    public func set(column: Int64, descending!: Bool = false): Unit {
        this.column = Some(max(0, column))
        this.descending = descending
    }

    /** 清除排序列并重置为升序。 */
    public func clear(): Unit {
        column = None
        descending = false
    }

    /** 切换当前列的方向；切换到其他列时使用升序。
     * @param column 要切换的列
     */
    public func toggle(column: Int64): Unit {
        match (this.column) {
            case Some(current) =>
                if (current == column) {
                    descending = !descending
                } else {
                    set(column)
                }
            case None => set(column)
        }
    }
}

/** 维护区分大小写的子串过滤条件。 */
public class FilterState {
    /** 过滤查询文本。 */
    public var query: String
    /** 是否启用过滤。 */
    public var active: Bool

    /** 创建过滤状态；非空查询会启用过滤。
     * @param query 查询文本
     * @param active 是否启用过滤
     */
    public init(query!: String = "", active!: Bool = false) {
        this.query = query
        this.active = active || !query.isEmpty()
    }

    /** 设置查询；非空时启用，空时停用。
     * @param query 查询文本
     */
    public func set(query: String): Unit {
        this.query = query
        this.active = !query.isEmpty()
    }

    /** 清空查询并停用过滤。 */
    public func clear(): Unit {
        query = ""
        active = false
    }

    /** 检查文本是否满足当前查询；未启用或查询为空时总是匹配。
     * @param text 待检查文本
     * @return 满足过滤条件时为 true
     */
    public func matches(text: String): Bool {
        !active || query.isEmpty() || text.contains(query)
    }
}

func isNoneSelection(mode: SelectionMode): Bool {
    match (mode) {
        case SelectionMode.NoSelection => true
        case _ => false
    }
}

func isSingleSelection(mode: SelectionMode): Bool {
    match (mode) {
        case SelectionMode.Single => true
        case _ => false
    }
}
