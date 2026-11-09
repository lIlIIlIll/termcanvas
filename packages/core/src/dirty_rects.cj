package core

import std.collection.*

/** 收集需要重绘的矩形，并合并重叠或整边相邻的区域。合并采用外接矩形，可能包含原区域以外的单元格。 */
public class DirtyRects {
    private let items = ArrayList<Rect>()

    /** 创建空的脏区域集合。 */
    public init() {}

    /** 创建集合并依次添加矩形。
     * @param rects 初始脏区域
     */
    public init(rects: Array<Rect>) {
        addAll(rects)
    }

    /** 创建包含给定区域的集合；空区域不会加入。
     * @param area 待重绘区域
     * @return 新的脏区域集合
     */
    public static func full(area: Rect): DirtyRects {
        let dirty = DirtyRects()
        dirty.add(area)
        dirty
    }

    /** 添加非空矩形并反复合并重叠或整边相邻的区域。
     * @param rect 待添加的区域
     */
    public func add(rect: Rect): Unit {
        if (rect.width <= 0 || rect.height <= 0) { return }
        var merged = rect
        var i: Int64 = 0
        while (i < items.size) {
            let current = items[i]
            if (canMerge(current, merged)) {
                merged = unionRect(current, merged)
                items.remove(at: i)
                // The bounding union can reach rectangles skipped before
                // this merge; revisit them until the union is disjoint.
                i = 0
            } else {
                i++
            }
        }
        items.add(merged)
    }

    /** 依次添加数组中的矩形。
     * @param rects 待添加的区域
     */
    public func addAll(rects: Array<Rect>): Unit {
        for (rect in rects) { add(rect) }
    }

    /** 添加另一个集合的区域快照。
     * @param other 待合并的集合
     */
    public func addAll(other: DirtyRects): Unit {
        addAll(other.rects())
    }

    /** 移除全部脏区域。 */
    public func clear(): Unit {
        while (items.size > 0) {
            items.remove(at: 0)
        }
    }

    /** 检查集合是否为空。
     * @return 没有脏区域时为 true
     */
    public func isEmpty(): Bool {
        items.size == 0
    }

    /** 获取当前矩形数组的副本。
     * @return 已合并的矩形
     */
    public func rects(): Array<Rect> {
        items.toArray()
    }

    /** 复制当前集合。
     * @return 不依赖原集合的副本
     */
    public func copy(): DirtyRects {
        DirtyRects(rects())
    }

    /** 检查是否有单个已存矩形完整包含给定区域；空区域视为已包含。
     * @param area 要检查的区域
     * @return 存在完整包含的矩形或区域为空时为 true
     */
    public func covers(area: Rect): Bool {
        if (area.width <= 0 || area.height <= 0) { return true }
        for (rect in items) {
            if (rect.x <= area.x && rect.y <= area.y && rect.right >= area.right && rect.bottom >= area.bottom) {
                return true
            }
        }
        false
    }

    /** 检查区域是否与任一脏矩形有非空交集。
     * @param area 要检查的区域
     * @return 存在非空交集时为 true
     */
    public func intersects(area: Rect): Bool {
        for (rect in items) {
            let hit = intersect(rect, area)
            if (hit.width > 0 && hit.height > 0) { return true }
        }
        false
    }

    /** 按坐标和尺寸检查非空交集；非正宽或高返回 false。
     * @param x 区域横坐标
     * @param y 区域纵坐标
     * @param width 区域宽度
     * @param height 区域高度
     * @return 与任一脏矩形相交时为 true
     */
    public func intersectsRect(x: Int64, y: Int64, width: Int64, height: Int64): Bool {
        if (width <= 0 || height <= 0) { return false }
        let right = x + width
        let bottom = y + height
        for (rect in items) {
            if (rect.x < right && rect.right > x && rect.y < bottom && rect.bottom > y) {
                return true
            }
        }
        false
    }

    /** 检查指定单元格是否位于任一脏矩形内。
     * @param x 单元格横坐标
     * @param y 单元格纵坐标
     * @return 单元格在脏区域内时为 true
     */
    public func intersectsCell(x: Int64, y: Int64): Bool {
        for (rect in items) {
            if (x >= rect.x && x < rect.right && y >= rect.y && y < rect.bottom) {
                return true
            }
        }
        false
    }

    /** 计算已存外接矩形面积之和。
     * @return 合并后矩形的单元格总数
     */
    public func cellCount(): Int64 {
        var count: Int64 = 0
        for (rect in items) {
            count += rect.width * rect.height
        }
        count
    }
}

func canMerge(left: Rect, right: Rect): Bool {
    let overlap = intersect(left, right)
    if (overlap.width > 0 && overlap.height > 0) { return true }
    if (left.y == right.y && left.height == right.height && (left.right == right.x || right.right == left.x)) { return true }
    if (left.x == right.x && left.width == right.width && (left.bottom == right.y || right.bottom == left.y)) { return true }
    false
}

func unionRect(left: Rect, right: Rect): Rect {
    let x1 = min(left.x, right.x)
    let y1 = min(left.y, right.y)
    let x2 = max(left.right, right.right)
    let y2 = max(left.bottom, right.bottom)
    Rect(x1, y1, x2 - x1, y2 - y1)
}
