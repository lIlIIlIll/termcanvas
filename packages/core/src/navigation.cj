package core

import std.collection.*

/** 按顺序在一行绘制标签标题，以不同样式标示当前选中项；左右方向键可切换选中项。
 */
public class Tabs <: Widget {
    private let titles: Array<String>
    /** 当前选中标签的索引，从 0 开始；构造时会限制在标题索引范围内，此字段也可直接修改。
     */
    public var selected: Int64
    private let style: Style
    private let selectedStyle: Style

    private var focused: Bool = false
    private var firstVisible: Int64 = 0
    /** 保存标签标题和两种绘制样式，并将初始选中索引限制在 0 到最后一个标题索引之间；没有标题时设为 0。
     */
    public init(
        titles: Array<String>,
        selected!: Int64 = 0,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)
    ) {
        this.titles = titles
        this.selected = clamp(selected, 0, max(0, titles.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
    }
    /** 设置当前标签栏是否具有焦点；聚焦时选中标签额外显示粗体和下划线。
     */
    public func setFocused(focused: Bool): Unit {
        this.focused = focused
    }

    /** 左右方向键在非空标签列表中切换选中项并返回 true；空列表或其他按键返回 false。
     */
    public func handle(key: KeyEvent): Bool {
        if (titles.isEmpty()) { return false }
        match (key.code) {
            case KeyCode.Left =>
                selected = max(0, selected - 1)
                true
            case KeyCode.Right =>
                selected = min(titles.size - 1, selected + 1)
                true
            case _ => false
        }
    }

    /** 按当前可见标签的字符单元格命中鼠标；标题截断或窄区域滚动后命中范围与实际显示一致。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (!widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                var x = area.x
                let first = ensureSelectionVisible(area.width)
                for (i in first..titles.size) {
                    if (x >= area.right) { return false }
                    let fullWidth = displayWidth(" " + titles[i] + " ")
                    let visibleWidth = min(fullWidth, area.right - x)
                    if (mouse.x >= x && mouse.x - x < visibleWidth) {
                        selected = i
                        _ = ensureSelectionVisible(area.width)
                        return true
                    }
                    x += visibleWidth
                    if (visibleWidth < fullWidth) { return false }
                }
                false
            case _ => false
        }
    }

    /** 在区域首行绘制当前视口内的标签；选中标签使用选中样式，聚焦时再加粗并下划线，窄区域自动截断并滚动到选中项。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || titles.isEmpty()) { return }
        var x = area.x
        let first = ensureSelectionVisible(area.width)
        for (i in first..titles.size) {
            if (x >= area.right) { return }
            let full = " " + titles[i] + " "
            let text = truncate(full, area.right - x)
            let visibleWidth = displayWidth(text)
            var itemStyle = if (i == selected) { selectedStyle } else { style }
            if (i == selected && focused) {
                var modifier = itemStyle.modifier
                modifier.bold = true
                modifier.underline = true
                itemStyle = itemStyle.withModifier(modifier)
            }
            buffer.setString(x, area.y, text, style: itemStyle)
            let fullWidth = displayWidth(full)
            x += visibleWidth
            if (visibleWidth < fullWidth) { return }
        }
    }

    private func ensureSelectionVisible(width: Int64): Int64 {
        if (titles.isEmpty()) {
            firstVisible = 0
            return 0
        }
        selected = clamp(selected, 0, titles.size - 1)
        if (width <= 0) {
            firstVisible = selected
            return firstVisible
        }
        var first = selected
        var used = displayWidth(" " + titles[selected] + " ")
        if (used > width) {
            firstVisible = selected
            return firstVisible
        }
        while (first > 0) {
            let previousWidth = displayWidth(" " + titles[first - 1] + " ")
            if (previousWidth > width - used) { break }
            used += previousWidth
            first--
        }
        firstVisible = first
        firstVisible
    }
}

public class StatusBarProgress {
    public let value: Int64
    public let total: Int64
    public let width: Int64
    public let label: String
    public let labelMode: ProgressBarLabelMode
    public let style: Style
    public let fillStyle: Style
    public let labelStyle: Style
    public let symbols: ProgressBarSymbols

    public init(
        value: Int64,
        total!: Int64 = 100,
        width!: Int64 = 18,
        label!: String = "",
        labelMode!: ProgressBarLabelMode = ProgressBarLabelMode.Percent,
        style!: Style = Style(fg: Color.Indexed(8), bg: Color.White),
        fillStyle!: Style = Style(fg: Color.Cyan, bg: Color.White),
        labelStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        symbols!: ProgressBarSymbols = ProgressBarSymbols(filled: "=", empty: "-", head: ">", indeterminate: ">")
    ) {
        this.value = max(0, value)
        this.total = max(1, total)
        this.width = max(0, width)
        this.label = label
        this.labelMode = labelMode
        this.style = style
        this.fillStyle = fillStyle
        this.labelStyle = labelStyle
        this.symbols = symbols
    }
}

public class StatusBar <: Widget {
    private let left: String
    private let right: String
    private let style: Style
    private let progress: ?StatusBarProgress

    public init(
        left!: String = "",
        right!: String = "",
        style!: Style = Style(fg: Color.Black, bg: Color.White),
        progress!: ?StatusBarProgress = None
    ) {
        this.left = left
        this.right = right
        this.style = style
        this.progress = progress
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.setString(area.x, area.y, repeat(" ", area.width), style: style)

        let rightText = truncate(right, area.width)
        let rightWidth = displayWidth(rightText)
        let rightX = area.right - rightWidth
        var leftLimit = if (rightWidth > 0) { max(0, rightX - area.x - 1) } else { area.width }
        match (progress) {
            case Some(p) =>
                let gap = if (rightWidth > 0) { 1 } else { 0 }
                let available = max(0, rightX - area.x - gap - 1)
                let progressWidth = min(p.width, available)
                if (progressWidth >= 6) {
                    let progressX = rightX - gap - progressWidth
                    ProgressBar(
                        p.value,
                        total: p.total,
                        label: p.label,
                        style: p.style,
                        fillStyle: p.fillStyle,
                        labelMode: p.labelMode,
                        labelStyle: p.labelStyle,
                        symbols: p.symbols
                    ).render(Rect(progressX, area.y, progressWidth, 1), buffer)
                    leftLimit = max(0, progressX - area.x - 1)
                }
            case None => ()
        }
        buffer.setString(area.x, area.y, truncate(left, leftLimit), style: style)
        if (rightWidth > 0) {
            buffer.setString(rightX, area.y, rightText, style: style)
        }
    }
}

public class Viewport <: Widget {
    private let lines: Array<String>
    public var offset: Int64
    private let block: ?Block
    private let style: Style

    public init(lines: Array<String>, offset!: Int64 = 0, block!: ?Block = None, style!: Style = Style.default()) {
        this.lines = lines
        this.offset = max(0, offset)
        this.block = block
        this.style = style
    }

    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        match (key.code) {
            case KeyCode.Up => scroll(-1, viewportHeight); true
            case KeyCode.Down => scroll(1, viewportHeight); true
            case KeyCode.PageUp => scroll(-viewportHeight, viewportHeight); true
            case KeyCode.PageDown => scroll(viewportHeight, viewportHeight); true
            case KeyCode.Home => offset = 0; true
            case KeyCode.End => offset = max(0, lines.size - viewportHeight); true
            case _ => false
        }
    }

    public func scroll(delta: Int64, viewportHeight: Int64): Unit {
        offset = clamp(offset + delta, 0, max(0, lines.size - max(0, viewportHeight)))
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        for (row in 0..target.height) {
            let index = offset + row
            if (index >= lines.size) { return }
            buffer.setString(target.x, target.y + row, truncate(lines[index], target.width), style: style)
        }
    }
}

// Geometry helpers do not dispatch events. Applications choose the active
// surface before calling a widget, so overlays cannot click through.
public func widgetHitTest(mouse: MouseEvent, area: Rect): Bool {
    area.width > 0 && area.height > 0 && mouse.x >= area.x && mouse.x < area.right &&
        mouse.y >= area.y && mouse.y < area.bottom
}

public func widgetRowAt(mouse: MouseEvent, area: Rect, offset: Int64, total: Int64): ?Int64 {
    if (!widgetHitTest(mouse, area) || offset < 0 || offset >= total) { return None }
    let row = mouse.y - area.y
    if (row >= total - offset) { None } else { Some(offset + row) }
}

public func mouseScrollDelta(mouse: MouseEvent): Int64 {
    match (mouse.kind) {
        case MouseKind.Scroll => match (mouse.button) {
            case MouseButton.WheelUp => -1
            case MouseButton.WheelDown => 1
            case _ => 0
        }
        case _ => 0
    }
}

public class PointerCapture {
    private var owner: ?String = None
    private var start: Position = Position(0, 0)
    private var value: Int64 = 0

    public init() {}

    public func begin(owner: String, mouse: MouseEvent, area: Rect, value!: Int64 = 0): Bool {
        if (owner.isEmpty() || this.owner.isSome() || !widgetHitTest(mouse, area)) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                this.owner = Some(owner)
                start = Position(mouse.x, mouse.y)
                this.value = value
                true
            case _ => false
        }
    }

    public func owns(owner: String): Bool { this.owner == Some(owner) }
    public func activeOwner(): ?String { owner }
    public func origin(): Position { start }
    public func initialValue(): Int64 { value }

    public func release(owner: String, mouse: MouseEvent): Bool {
        if (!owns(owner)) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Up, MouseButton.Left) | (MouseKind.Up, MouseButton.None) => cancel(); true
            case _ => false
        }
    }

    public func cancel(): Unit { owner = None }
}

class ModalFocusLayer {
    let id: String
    let focus = FocusManager()
    let keys: KeyMap
    let returnFocus: ?String
    init(id: String, ids: Array<String>, keys: KeyMap, returnFocus: ?String) {
        this.id = id
        this.keys = keys
        this.returnFocus = returnFocus
        for (value in ids) { focus.add(value) }
    }
}

// Application-owned focus/key policy only: no render tree, callbacks, effects
// or event loop. A lower layer remains untouched while a modal is active.
public class ModalFocusState {
    private let base: FocusManager
    private let baseKeys: KeyMap
    private let layers = ArrayList<ModalFocusLayer>()

    public init(base: FocusManager, keymap!: KeyMap = KeyMap()) {
        this.base = base
        this.baseKeys = keymap
    }

    public func open(id: String, focusIds: Array<String>, keymap!: KeyMap = KeyMap()): Bool {
        if (id.isEmpty()) { return false }
        for (layer in layers) { if (layer.id == id) { return false } }
        layers.add(ModalFocusLayer(id, focusIds, keymap, focus().current()))
        true
    }

    public func active(): ?String {
        if (layers.isEmpty()) { None } else { Some(layers[layers.size - 1].id) }
    }

    public func focus(): FocusManager {
        if (layers.isEmpty()) { base } else { layers[layers.size - 1].focus }
    }

    public func close(): ?String {
        if (layers.isEmpty()) { return None }
        let layer = layers[layers.size - 1]
        layers.remove(at: layers.size - 1)
        match (layer.returnFocus) {
            case Some(id) => _ = focus().focus(id)
            case None => ()
        }
        Some(layer.id)
    }

    public func handle(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.Esc =>
                if (layers.isEmpty()) { false } else { _ = close(); true }
            case _ => focus().handle(key)
        }
    }

    public func actionFor(key: KeyEvent): ?String {
        if (layers.isEmpty()) { baseKeys.actionFor(key) } else { layers[layers.size - 1].keys.actionFor(key) }
    }
}

func selectionViewportOffset(offset: Int64, selected: Int64, total: Int64, height: Int64): Int64 {
    if (total <= 0) { return 0 }
    let index = clamp(selected, 0, total - 1)
    let visible = max(1, height)
    var start = clamp(offset, 0, max(0, total - visible))
    if (index < start) { start = index }
    if (index - start >= visible) { start = index - visible + 1 }
    start
}

func selectionMove(current: Int64, delta: Int64, total: Int64): Int64 {
    if (total <= 0) { return 0 }
    let index = clamp(current, 0, total - 1)
    if (delta >= 0) { index + min(delta, total - 1 - index) }
    else if (delta <= -index) { 0 } else { index + delta }
}

func selectionNavigation(key: KeyEvent, current: Int64, total: Int64, height: Int64): ?Int64 {
    match (key.code) {
        case KeyCode.Up => Some(selectionMove(current, -1, total))
        case KeyCode.Down => Some(selectionMove(current, 1, total))
        case KeyCode.Home => Some(0)
        case KeyCode.End => Some(max(0, total - 1))
        case KeyCode.PageUp => Some(selectionMove(current, -max(1, height), total))
        case KeyCode.PageDown => Some(selectionMove(current, max(1, height), total))
        case _ => None
    }
}

func selectionMouse(mouse: MouseEvent, area: Rect, offset: Int64, total: Int64, selected: Int64): ?Int64 {
    if (!widgetHitTest(mouse, area) || total <= 0) { return None }
    let delta = mouseScrollDelta(mouse)
    if (delta != 0) { return Some(selectionMove(selected, delta, total)) }
    match ((mouse.kind, mouse.button)) {
        case (MouseKind.Down, MouseButton.Left) => widgetRowAt(mouse, area, offset, total)
        case _ => None
    }
}

func widgetInnerArea(area: Rect, block: ?Block): Rect {
    match (block) { case Some(value) => value.inner(area); case None => area }
}
