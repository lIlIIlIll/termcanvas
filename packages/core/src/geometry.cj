package core

import std.math.numeric.BigInt

/** 以终端单元格为单位的矩形区域。 */
public struct Rect <: Equatable<Rect> {
    /** 横坐标。 */
    public var x: Int64
    /** 纵坐标。 */
    public var y: Int64
    /** 宽度；构造时负数按零处理，之后可由调用方修改。 */
    public var width: Int64
    /** 高度；构造时负数按零处理，之后可由调用方修改。 */
    public var height: Int64

    /** 创建矩形；负宽度或负高度置为零。
     * @param x 左上角横坐标
     * @param y 左上角纵坐标
     * @param width 宽度
     * @param height 高度
     */
    public init(x: Int64, y: Int64, width: Int64, height: Int64) {
        this.x = x
        this.y = y
        this.width = if (width < 0) { 0 } else { width }
        this.height = if (height < 0) { 0 } else { height }
    }

    /** 比较坐标和尺寸是否逐项相同。
     * @param other 要比较的矩形
     * @return 四个字段均相同时为 true
     */
    public operator func ==(other: Rect): Bool {
        x == other.x && y == other.y && width == other.width && height == other.height
    }

    /** 右侧边界坐标，等于 x 加 width。 */
    public prop right: Int64 { get() { x + width } }
    /** 底部边界坐标，等于 y 加 height。 */
    public prop bottom: Int64 { get() { y + height } }
}

/** 以终端单元格为单位的二维坐标。 */
public struct Position {
    /** 横坐标。 */
    public var x: Int64
    /** 纵坐标。 */
    public var y: Int64
    /** 创建二维坐标。
     * @param x 横坐标
     * @param y 纵坐标
     */
    public init(x: Int64, y: Int64) {
        this.x = x
        this.y = y
    }
}

/** 布局分配空间的方向。 */
public enum Direction {
    /** 沿水平方向分配。 */
    | Horizontal
    /** 沿垂直方向分配。 */
    | Vertical
}

/** 布局在主轴上为一个区域分配空间的约束。 */
public enum Constraint {
    /** 按单元格数量请求固定长度。
     * @param _0 请求的单元格数
     */
    | Length(Int64)
    /** 按可用主轴长度的百分比请求空间，百分比限制在 0 到 100。
     * @param _0 请求的百分比
     */
    | Percent(Int64)
    /** 请求最小长度并参与剩余空间分配；空间不足时结果可能缩小。
     * @param _0 请求的最小长度
     */
    | Min(Int64)
    /** 请求不超过给定长度的剩余空间份额。
     * @param _0 允许的最大长度
     */
    | Max(Int64)
    /** 按分子和分母请求可用空间的比例；分子或分母非正时为零。
     * @param _0 比例分子
     * @param _1 比例分母
     */
    | Ratio(Int64, Int64)
}

/** 约束未占满主轴时，控制区域和额外空间的排列方式。 */
public enum Flex {
    /** 从主轴起点排列。 */
    | Start
    /** 将已使用区域居中。 */
    | Center
    /** 将已使用区域靠近主轴终点。 */
    | End
    /** 把额外空间分配到区域之间。 */
    | SpaceBetween
}

/** 矩形四边的非负间距。 */
public struct Spacing {
    /** 左边距。 */
    public let left: Int64
    /** 右边距。 */
    public let right: Int64
    /** 上边距。 */
    public let top: Int64
    /** 下边距。 */
    public let bottom: Int64

    /** 创建四边间距；每个负值均按零处理。
     * @param left 左边距
     * @param right 右边距
     * @param top 上边距
     * @param bottom 下边距
     */
    public init(left!: Int64 = 0, right!: Int64 = 0, top!: Int64 = 0, bottom!: Int64 = 0) {
        this.left = max(0, left)
        this.right = max(0, right)
        this.top = max(0, top)
        this.bottom = max(0, bottom)
    }

    /** 返回四边均为零的间距。
     * @return 零间距
     */
    public static func zero(): Spacing {
        Spacing()
    }

    /** 为四边设置相同间距。
     * @param value 四边的间距；负数按零处理
     * @return 统一间距
     */
    public static func all(value: Int64): Spacing {
        Spacing(left: value, right: value, top: value, bottom: value)
    }

    /** 分别为左右和上下设置相同间距。
     * @param horizontal 左右间距
     * @param vertical 上下间距
     * @return 对称间距
     */
    public static func symmetric(horizontal!: Int64 = 0, vertical!: Int64 = 0): Spacing {
        Spacing(left: horizontal, right: horizontal, top: vertical, bottom: vertical)
    }

    /** 从区域四边扣除间距；所得负宽高由 Rect 构造器置零。
     * @param area 原区域
     * @return 扣除间距后的区域
     */
    public func inner(area: Rect): Rect {
        Rect(
            area.x + left,
            area.y + top,
            area.width - left - right,
            area.height - top - bottom
        )
    }
}

/** 按方向、约束、间距和剩余空间排列方式拆分矩形。 */
public class Layout {
    private let direction: Direction
    private let constraints: Array<Constraint>
    private let flex: Flex
    private let gap: Int64
    private let margin: Spacing

    /** 创建布局；负间隔按零处理。
     * @param direction 主轴方向
     * @param constraints 各区域的主轴约束
     * @param flex 未占满空间时的排列方式
     * @param gap 相邻区域间距
     * @param margin 外边距
     */
    public init(
        direction: Direction,
        constraints: Array<Constraint>,
        flex!: Flex = Flex.Start,
        gap!: Int64 = 0,
        margin!: Spacing = Spacing.zero()
    ) {
        this.direction = direction
        this.constraints = constraints
        this.flex = flex
        this.gap = max(0, gap)
        this.margin = margin
    }

    /** 创建水平布局。
     * @param constraints 各区域的主轴约束
     * @return 水平布局
     */
    public static func horizontal(constraints: Array<Constraint>): Layout {
        Layout(Direction.Horizontal, constraints)
    }

    /** 创建垂直布局。
     * @param constraints 各区域的主轴约束
     * @return 垂直布局
     */
    public static func vertical(constraints: Array<Constraint>): Layout {
        Layout(Direction.Vertical, constraints)
    }

    /** 返回使用新排列方式的布局。
     * @param flex 未占满空间时的排列方式
     * @return 新布局
     */
    public func withFlex(flex: Flex): Layout {
        Layout(direction, constraints, flex: flex, gap: gap, margin: margin)
    }

    /** 返回使用新间隔的布局；负数按零处理。
     * @param gap 相邻区域间距
     * @return 新布局
     */
    public func withGap(gap: Int64): Layout {
        Layout(direction, constraints, flex: flex, gap: gap, margin: margin)
    }

    /** 返回使用新外边距的布局。
     * @param margin 外边距
     * @return 新布局
     */
    public func withMargin(margin: Spacing): Layout {
        Layout(direction, constraints, flex: flex, gap: gap, margin: margin)
    }

    /** 根据布局配置拆分区域；没有约束时返回空数组。
     * @param area 待拆分区域
     * @return 与约束顺序对应的区域数组
     */
    public func split(area: Rect): Array<Rect> {
        let target = margin.inner(area)
        if (constraints.size == 0) { return [] }
        let total = match (direction) {
            case Horizontal => target.width
            case Vertical => target.height
        }
        let totalGap = gap * max(0, constraints.size - 1)
        let available = max(0, total - totalGap)
        var fixed: Int64 = 0
        var minCount: Int64 = 0
        var lastMin: Int64 = -1
        var maxCount: Int64 = 0
        let sizes = Array<Int64>(constraints.size, repeat: 0)
        for (i in 0..constraints.size) {
            match (constraints[i]) {
                case Length(v) =>
                    sizes[i] = clamp(v, 0, available)
                    fixed += sizes[i]
                case Percent(p) =>
                    sizes[i] = clamp(available * clamp(p, 0, 100) / 100, 0, available)
                    fixed += sizes[i]
                case Min(_) => minCount++; lastMin = i
                case Max(_) => maxCount++
                case Ratio(n, d) =>
                    sizes[i] = if (d <= 0 || n <= 0) { 0 } else { clamp(available * n / d, 0, available) }
                    fixed += sizes[i]
            }
        }

        var remaining = available - fixed
        if (remaining < 0) {
            remaining = 0
        }
        for (i in 0..constraints.size) {
            match (constraints[i]) {
                case Min(v) =>
                    let share = if (minCount <= 0) { 0 } else { remaining / minCount }
                    sizes[i] = max(v, share)
                case Max(v) =>
                    let share = if (maxCount <= 0) { 0 } else { remaining / maxCount }
                    sizes[i] = min(max(0, v), share)
                case _ => ()
            }
        }
        normalizeSizes(sizes, available, lastMin)

        let rects = Array<Rect>(constraints.size, repeat: Rect(area.x, area.y, 0, 0))
        let used = usedSize(sizes) + totalGap
        var flexGap = gap
        var offset: Int64 = flexOffset(total, used)
        match (flex) {
            case Flex.SpaceBetween =>
                if (constraints.size > 1 && used < total) {
                    flexGap = gap + (total - used) / (constraints.size - 1)
                }
            case _ => ()
        }
        for (i in 0..sizes.size) {
            match (direction) {
                case Horizontal =>
                    rects[i] = Rect(target.x + offset, target.y, sizes[i], target.height)
                case Vertical =>
                    rects[i] = Rect(target.x, target.y + offset, target.width, sizes[i])
            }
            offset += sizes[i] + flexGap
        }
        rects
    }

    private func flexOffset(total: Int64, used: Int64): Int64 {
        if (used >= total) { return 0 }
        match (flex) {
            case Flex.Start | Flex.SpaceBetween => 0
            case Flex.Center => (total - used) / 2
            case Flex.End => total - used
        }
    }

    private static func usedSize(sizes: Array<Int64>): Int64 {
        var used: Int64 = 0
        for (size in sizes) {
            used += size
        }
        used
    }

    private static func normalizeSizes(sizes: Array<Int64>, total: Int64, fillIndex: Int64): Unit {
        var used: Int64 = 0
        for (size in sizes) {
            used += size
        }
        var i: Int64 = sizes.size - 1
        while (used > total && i >= 0) {
            let take = min(sizes[i], used - total)
            sizes[i] -= take
            used -= take
            i--
        }
        if (fillIndex >= 0 && used < total) {
            // Only a Min chunk may absorb a remainder. The last chunk can
            // instead be a fixed Length, Ratio, Percent or capped Max.
            sizes[fillIndex] += total - used
        }
    }
}

public struct SizeHint {
    public let minWidth: Int64
    public let minHeight: Int64
    public let preferredWidth: Int64
    public let preferredHeight: Int64
    public let maxWidth: Int64
    public let maxHeight: Int64

    public init(
        minWidth!: Int64 = 0,
        minHeight!: Int64 = 0,
        preferredWidth!: Int64 = 0,
        preferredHeight!: Int64 = 0,
        maxWidth!: Int64 = Int64.Max,
        maxHeight!: Int64 = Int64.Max
    ) {
        this.minWidth = max(0, minWidth)
        this.minHeight = max(0, minHeight)
        this.preferredWidth = max(0, preferredWidth)
        this.preferredHeight = max(0, preferredHeight)
        this.maxWidth = max(0, maxWidth)
        this.maxHeight = max(0, maxHeight)
    }
}

public interface Sizable {
    func sizeHint(): SizeHint
}

public class Grid {
    private let rows: Array<Constraint>
    private let columns: Array<Constraint>
    private let gap: Int64
    private let margin: Spacing

    public init(rows: Array<Constraint>, columns: Array<Constraint>, gap!: Int64 = 0, margin!: Spacing = Spacing.zero()) {
        this.rows = rows
        this.columns = columns
        this.gap = max(0, gap)
        this.margin = margin
    }

    public func split(area: Rect): Array<Array<Rect>> {
        let target = margin.inner(area)
        let rowRects = Layout.vertical(rows).withGap(gap).split(target)
        let out = Array<Array<Rect>>(rowRects.size, repeat: [])
        for (r in 0..rowRects.size) {
            out[r] = Layout.horizontal(columns).withGap(gap).split(rowRects[r])
        }
        out
    }
}

public struct FlexItem {
    public let basis: Int64
    public let grow: Int64
    public let shrink: Int64
    public let minSize: Int64
    public let maxSize: Int64

    public init(
        basis!: Int64 = 0,
        grow!: Int64 = 1,
        shrink!: Int64 = 1,
        minSize!: Int64 = 0,
        maxSize!: Int64 = Int64.Max
    ) {
        this.minSize = max(0, minSize)
        this.maxSize = max(this.minSize, maxSize)
        this.basis = clamp(basis, this.minSize, this.maxSize)
        this.grow = max(0, grow)
        this.shrink = max(0, shrink)
    }

    public static func fromSizeHint(
        hint: SizeHint,
        direction: Direction,
        grow!: Int64 = 1,
        shrink!: Int64 = 1
    ): FlexItem {
        match (direction) {
            case Direction.Horizontal => FlexItem(basis: hint.preferredWidth, minSize: hint.minWidth, maxSize: hint.maxWidth, grow: grow, shrink: shrink)
            case Direction.Vertical => FlexItem(basis: hint.preferredHeight, minSize: hint.minHeight, maxSize: hint.maxHeight, grow: grow, shrink: shrink)
        }
    }
}

public class FlexLayoutResult {
    public let rects: Array<Rect>
    // False when the viewport cannot preserve minima or zero-shrink bases.
    public let constraintsSatisfied: Bool
    public let effectiveGap: Int64

    public init(rects: Array<Rect>, constraintsSatisfied: Bool, effectiveGap: Int64) {
        this.rects = rects
        this.constraintsSatisfied = constraintsSatisfied
        this.effectiveGap = effectiveGap
    }
}

public class FlexLayout {
    private let direction: Direction
    private let items: Array<FlexItem>
    private let gap: Int64

    public init(direction: Direction, items: Array<FlexItem>, gap!: Int64 = 0) {
        this.direction = direction
        this.items = items.clone()
        this.gap = max(0, gap)
    }

    public func split(area: Rect): Array<Rect> { resolve(area).rects }

    public func resolve(area: Rect): FlexLayoutResult {
        if (items.size == 0) { return FlexLayoutResult([], true, 0) }
        // Rect coordinates are Int64. Clip unrepresentable positive extents
        // before adding offsets, including when callers mutate Rect fields.
        let target = Rect(area.x, area.y, flexExtent(area.x, area.width), flexExtent(area.y, area.height))
        let total = match (direction) {
            case Direction.Horizontal => target.width
            case Direction.Vertical => target.height
        }
        let gaps = items.size - 1
        let effectiveGap = if (gaps == 0) { 0 } else { min(gap, total / gaps) }
        let available = total - effectiveGap * gaps
        let budget = BigInt(available)
        let zero = BigInt(0)
        let sizes = Array<Int64>(items.size, { i => items[i].basis })
        let minima = Array<Int64>(items.size, { i => items[i].minSize })
        let maxima = Array<Int64>(items.size, { i => items[i].maxSize })
        let minTotal = flexSum(minima)
        var satisfied = effectiveGap == gap || gaps == 0
        if (minTotal > budget) {
            // No feasible allocation exists. Deterministically compress the
            // minima instead of overflowing or returning offscreen children.
            satisfied = false
            var cumulative = zero
            var assigned: Int64 = 0
            for (i in 0..sizes.size) {
                cumulative += BigInt(minima[i])
                let next = (budget * cumulative / minTotal).toInt64()
                sizes[i] = next - assigned
                assigned = next
            }
        } else {
            let basisTotal = flexSum(sizes)
            if (basisTotal > budget) {
                let weights = Array<BigInt>(items.size, { i => BigInt(items[i].basis) * BigInt(items[i].shrink) })
                let remaining = flexDistribute(sizes, minima, weights, basisTotal - budget, false)
                if (remaining > zero) {
                    // Zero-shrink items cannot all keep their bases in this
                    // viewport. Preserve feasible minima and expose the
                    // degraded allocation to callers through the result.
                    satisfied = false
                    let fallback = Array<BigInt>(items.size, { i => BigInt(sizes[i] - minima[i]) })
                    _ = flexDistribute(sizes, minima, fallback, remaining, false)
                }
            } else if (basisTotal < budget) {
                let weights = Array<BigInt>(items.size, { i => BigInt(items[i].grow) })
                _ = flexDistribute(sizes, maxima, weights, budget - basisTotal, true)
            }
        }
        var offset: Int64 = 0
        let rects = Array<Rect>(items.size, repeat: Rect(target.x, target.y, 0, 0))
        for (i in 0..items.size) {
            rects[i] = match (direction) {
                case Direction.Horizontal => Rect(target.x + offset, target.y, sizes[i], target.height)
                case Direction.Vertical => Rect(target.x, target.y + offset, target.width, sizes[i])
            }
            offset += sizes[i]
            if (i < gaps) { offset += effectiveGap }
        }
        FlexLayoutResult(rects, satisfied, effectiveGap)
    }
}

func flexExtent(origin: Int64, extent: Int64): Int64 {
    let size = max(0, extent)
    if (origin > 0) { min(size, Int64.Max - origin) } else { size }
}

func flexSum(values: Array<Int64>): BigInt {
    var total = BigInt(0)
    for (value in values) { total += BigInt(value) }
    total
}

// Integer cumulative quotas allocate every remainder deterministically.
// A saturated item is removed from the next round, so work is bounded by
// the item count, not by the number of terminal cells or weight magnitude.
func flexDistribute(
    sizes: Array<Int64>,
    limits: Array<Int64>,
    weights: Array<BigInt>,
    amount: BigInt,
    growing: Bool
): BigInt {
    let zero = BigInt(0)
    var remaining = amount
    while (remaining > zero) {
        var totalWeight = zero
        for (i in 0..sizes.size) {
            let capacity = if (growing) { limits[i] - sizes[i] } else { sizes[i] - limits[i] }
            if (capacity > 0) { totalWeight += weights[i] }
        }
        if (totalWeight == zero) { break }
        var cumulative = zero
        var previousQuota = zero
        var changed = zero
        for (i in 0..sizes.size) {
            let capacity = if (growing) { limits[i] - sizes[i] } else { sizes[i] - limits[i] }
            if (capacity <= 0 || weights[i] == zero) { continue }
            cumulative += weights[i]
            let quota = remaining * cumulative / totalWeight
            let share = quota - previousQuota
            previousQuota = quota
            let delta = if (share > BigInt(capacity)) { capacity } else { share.toInt64() }
            if (growing) { sizes[i] += delta } else { sizes[i] -= delta }
            changed += BigInt(delta)
        }
        if (changed == zero) { break }
        remaining -= changed
    }
    remaining
}

public class LayoutCache {
    private var area: Rect = Rect(0, 0, 0, 0)
    private var rects: Array<Rect> = []
    private var valid: Bool = false

    public init() {}

    public func get(area: Rect, compute: (Rect) -> Array<Rect>): Array<Rect> {
        if (valid && this.area == area) {
            return rects
        }
        // Publish the key and value together only after the callback has
        // succeeded; a failed computation must not make old rects a hit.
        let computed = compute(area)
        this.area = area
        rects = computed
        valid = true
        rects
    }

    public func invalidate(): Unit {
        valid = false
    }
}

func sizesToConstraints(sizes: Array<Int64>): Array<Constraint> {
    let out = Array<Constraint>(sizes.size, repeat: Constraint.Length(0))
    for (i in 0..sizes.size) {
        out[i] = Constraint.Length(sizes[i])
    }
    out
}
