package core

import std.collection.*

/** 垂直排列子组件，扣除内边距和间隔后分配高度。 */
public class VBox <: Widget {
    private let children: Array<Widget>
    private let gap: Int64
    private let padding: Spacing

    /** 创建排列容器；负间隔按零处理。
     * @param children 按顺序排列的子组件
     * @param gap 相邻子组件间隔
     * @param padding 容器内边距
     */
    public init(children: Array<Widget>, gap!: Int64 = 0, padding!: Spacing = Spacing.zero()) {
        this.children = children
        this.gap = max(0, gap)
        this.padding = padding
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let inner = padding.inner(area)
        if (children.size == 0 || inner.width <= 0 || inner.height <= 0) { return }
        let gaps = children.size - 1
        let totalGap = if (gaps == 0) { 0 } else if (gap > inner.height / gaps) { inner.height } else { gap * gaps }
        let childHeight = max(0, (inner.height - totalGap) / children.size)
        var y = inner.y
        for (i in 0..children.size) {
            let remaining = inner.bottom - y
            let height = if (i == children.size - 1) { remaining } else { min(childHeight, remaining) }
            children[i].render(Rect(inner.x, y, inner.width, height), buffer)
            if (gap >= remaining - height) { return }
            y += height + gap
        }
    }
}

/** 水平排列子组件，扣除内边距和间隔后分配宽度。 */
public class HBox <: Widget {
    private let children: Array<Widget>
    private let gap: Int64
    private let padding: Spacing

    /** 创建排列容器；负间隔按零处理。
     * @param children 按顺序排列的子组件
     * @param gap 相邻子组件间隔
     * @param padding 容器内边距
     */
    public init(children: Array<Widget>, gap!: Int64 = 0, padding!: Spacing = Spacing.zero()) {
        this.children = children
        this.gap = max(0, gap)
        this.padding = padding
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let inner = padding.inner(area)
        if (children.size == 0 || inner.width <= 0 || inner.height <= 0) { return }
        let gaps = children.size - 1
        let totalGap = if (gaps == 0) { 0 } else if (gap > inner.width / gaps) { inner.width } else { gap * gaps }
        let childWidth = max(0, (inner.width - totalGap) / children.size)
        var x = inner.x
        for (i in 0..children.size) {
            let remaining = inner.right - x
            let width = if (i == children.size - 1) { remaining } else { min(childWidth, remaining) }
            children[i].render(Rect(x, inner.y, width, inner.height), buffer)
            if (gap >= remaining - width) { return }
            x += width + gap
        }
    }
}

/** 按顺序在相同区域绘制子组件，后绘制的内容可覆盖前面的内容。 */
public class Stack <: Widget {
    private let children: Array<Widget>

    /** 创建叠层容器。
     * @param children 按绘制顺序排列的子组件
     */
    public init(children: Array<Widget>) {
        this.children = children
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        for (child in children) {
            child.render(area, buffer)
        }
    }
}

/** 先绘制基础组件，再依次在相同区域绘制覆盖组件。 */
public class Overlay <: Widget {
    private let base: Widget
    private let overlays: Array<Widget>

    /** 创建覆盖容器。
     * @param base 先绘制的基础组件
     * @param overlays 按顺序绘制的覆盖组件
     */
    public init(base: Widget, overlays!: Array<Widget> = []) {
        this.base = base
        this.overlays = overlays
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        base.render(area, buffer)
        for (overlay in overlays) {
            overlay.render(area, buffer)
        }
    }
}

/** 将子组件绘制在扣除内间距后的区域内。 */
public class Padding <: Widget {
    private let child: Widget
    private let spacing: Spacing

    /** 创建间距容器。
     * @param child 要绘制的子组件
     * @param spacing 从四边扣除的间距
     */
    public init(child: Widget, spacing: Spacing) {
        this.child = child
        this.spacing = spacing
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        child.render(spacing.inner(area), buffer)
    }
}

/** 将子组件绘制在扣除外间距后的区域内。 */
public class Margin <: Widget {
    private let child: Widget
    private let spacing: Spacing

    /** 创建间距容器。
     * @param child 要绘制的子组件
     * @param spacing 从四边扣除的间距
     */
    public init(child: Widget, spacing: Spacing) {
        this.child = child
        this.spacing = spacing
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        child.render(spacing.inner(area), buffer)
    }
}

/** 将子组件绘制在指定尺寸的居中区域内。 */
public class Centered <: Widget {
    private let child: Widget
    private let width: Int64
    private let height: Int64

    /** 创建居中容器；请求宽高至少为一。
     * @param child 要绘制的子组件
     * @param width 请求的宽度
     * @param height 请求的高度
     */
    public init(child: Widget, width: Int64, height: Int64) {
        this.child = child
        this.width = max(1, width)
        this.height = max(1, height)
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        child.render(centeredViewport(area, width, height), buffer)
    }
}

/** 依次分配顶部、底部、左侧、右侧和中央区域。 */
public class Dock <: Widget {
    private let top: ?Widget
    private let bottom: ?Widget
    private let left: ?Widget
    private let right: ?Widget
    private let center: ?Widget
    private let topHeight: Int64
    private let bottomHeight: Int64
    private let leftWidth: Int64
    private let rightWidth: Int64

    /** 创建停靠容器；负尺寸按零处理。
     * @param top 顶部组件
     * @param bottom 底部组件
     * @param left 左侧组件
     * @param right 右侧组件
     * @param center 中央组件
     * @param topHeight 顶部请求高度
     * @param bottomHeight 底部请求高度
     * @param leftWidth 左侧请求宽度
     * @param rightWidth 右侧请求宽度
     */
    public init(
        top!: ?Widget = None,
        bottom!: ?Widget = None,
        left!: ?Widget = None,
        right!: ?Widget = None,
        center!: ?Widget = None,
        topHeight!: Int64 = 1,
        bottomHeight!: Int64 = 1,
        leftWidth!: Int64 = 16,
        rightWidth!: Int64 = 16
    ) {
        this.top = top
        this.bottom = bottom
        this.left = left
        this.right = right
        this.center = center
        this.topHeight = max(0, topHeight)
        this.bottomHeight = max(0, bottomHeight)
        this.leftWidth = max(0, leftWidth)
        this.rightWidth = max(0, rightWidth)
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var inner = area
        match (top) {
            case Some(widget) =>
                let h = min(inner.height, topHeight)
                widget.render(Rect(inner.x, inner.y, inner.width, h), buffer)
                inner = Rect(inner.x, inner.y + h, inner.width, inner.height - h)
            case None => ()
        }
        match (bottom) {
            case Some(widget) =>
                let h = min(inner.height, bottomHeight)
                widget.render(Rect(inner.x, inner.bottom - h, inner.width, h), buffer)
                inner = Rect(inner.x, inner.y, inner.width, inner.height - h)
            case None => ()
        }
        match (left) {
            case Some(widget) =>
                let w = min(inner.width, leftWidth)
                widget.render(Rect(inner.x, inner.y, w, inner.height), buffer)
                inner = Rect(inner.x + w, inner.y, inner.width - w, inner.height)
            case None => ()
        }
        match (right) {
            case Some(widget) =>
                let w = min(inner.width, rightWidth)
                widget.render(Rect(inner.right - w, inner.y, w, inner.height), buffer)
                inner = Rect(inner.x, inner.y, inner.width - w, inner.height)
            case None => ()
        }
        match (center) {
            case Some(widget) => widget.render(inner, buffer)
            case None => ()
        }
    }
}

/** 使用滚动状态绘制文本行，并在需要时绘制滚动条。 */
public class Scrollable <: Widget {
    private let lines: Array<String>
    private let state: ScrollState
    private let style: Style
    private let scrollbarStyle: Style

    /** 创建可滚动文本视图。
     * @param lines 按顺序显示的文本行
     * @param state 滚动状态
     * @param style 文本样式
     * @param scrollbarStyle 滚动条样式
     */
    public init(lines: Array<String>, state!: ScrollState = ScrollState(), style!: Style = Style.default(), scrollbarStyle!: Style = Style(fg: Color.Indexed(8))) {
        this.lines = lines
        this.state = state
        this.style = style
        this.scrollbarStyle = scrollbarStyle
    }

    /** 将按键交给滚动状态处理。
     * @param key 输入按键
     * @param viewportHeight 可见区域高度
     * @return 按键被处理时为 true
     */
    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        state.handle(key, lines.size, viewportHeight)
    }

    /** 处理滚动条拖动或区域内鼠标滚轮事件。
     * @param mouse 鼠标事件
     * @param area 视图区域
     * @param capture 指针捕获状态
     * @param owner 此视图的捕获身份
     * @return 事件被处理时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect, capture: PointerCapture, owner: String): Bool {
        if (lines.size > area.height && area.width > 1) {
            if (Scrollbar(lines.size, offset: state.offset, viewport: area.height).handleMouse(mouse, area, state, capture, owner)) { return true }
        } else if (capture.release(owner, mouse)) { return true }
        if (capture.activeOwner().isSome() || !widgetHitTest(mouse, area)) { return false }
        let delta = mouseScrollDelta(mouse)
        if (delta == 0) { return false }
        state.offset = selectionMove(state.offset, delta, max(0, lines.size - area.height) + 1)
        true
    }

    /** 在给定区域内绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let content = if (lines.size > area.height) { Rect(area.x, area.y, max(0, area.width - 1), area.height) } else { area }
        for (row in 0..content.height) {
            let index = state.offset + row
            if (index >= lines.size) { break }
            buffer.setString(content.x, content.y + row, truncate(lines[index], content.width, options: buffer.textWidthOptions()), style: style)
        }
        if (lines.size > area.height && area.width > 1) {
            Scrollbar(lines.size, offset: state.offset, viewport: area.height, style: scrollbarStyle).render(area, buffer)
        }
    }
}
