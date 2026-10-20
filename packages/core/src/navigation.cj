package core

import std.collection.*

private func horizontalFirstVisible(
    items: Array<String>,
    selected: Int64,
    width: Int64,
    selectedPrefix: String,
    selectedSuffix: String,
    regularPrefix: String,
    regularSuffix: String,
    separatorWidth: Int64
): Int64 {
    if (items.isEmpty()) { return 0 }
    let current = clamp(selected, 0, items.size - 1)
    if (width <= 0) { return current }
    let selectedText = selectedPrefix + items[current] + selectedSuffix
    var used = displayWidth(selectedText)
    if (used > width) { return current }
    var first = current
    while (first > 0) {
        let previousText = regularPrefix + items[first - 1] + regularSuffix
        let previousWidth = displayWidth(previousText) + separatorWidth
        if (previousWidth > width - used) { break }
        used += previousWidth
        first--
    }
    first
}

/** 按顺序在一行绘制标签标题，以不同样式标示当前选中项；左右方向键可切换选中项。
 */
public class Tabs <: Widget {
    private let titles: Array<String>
    /** 当前选中标签的索引，从 0 开始，可直接修改；构造、键盘、鼠标及绘制操作会先将其限制在标题索引范围内，空标题列表中为 0。
     */
    public var selected: Int64
    private let style: Style
    private let selectedStyle: Style
    private var theme: ?Theme = None

    private var focused: Bool = false
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

    /** 设置标签栏使用的语义主题；只有 selectedStyle 为 Style.default() 时才应用 normal/selected 角色；None 清除主题。
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    /** 左右方向键在非空标签列表中切换选中项并返回 true；按键前先限制公开索引，空列表或其他按键返回 false。
     */
    public func handle(key: KeyEvent): Bool {
        normalizeSelected()
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
        normalizeSelected()
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

    /** 在区域首行绘制当前视口内的标签；选中标签使用选中样式，聚焦时再加粗并下划线，绘制前限制公开索引。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        normalizeSelected()
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || titles.isEmpty()) { return }
        var x = area.x
        let first = ensureSelectionVisible(area.width)
        let useTheme = selectedStyle == Style.default()
        for (i in first..titles.size) {
            if (x >= area.right) { return }
            let full = " " + titles[i] + " "
            let text = truncate(full, area.right - x)
            let visibleWidth = displayWidth(text)
            var itemStyle = if (useTheme) {
                if (i == selected) { themedSelected(selectedStyle, theme) } else { themedNormal(style, theme) }
            } else {
                if (i == selected) { selectedStyle } else { style }
            }
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

    private func normalizeSelected(): Unit {
        if (titles.isEmpty()) {
            selected = 0
        } else {
            selected = clamp(selected, 0, titles.size - 1)
        }
    }

    private func ensureSelectionVisible(width: Int64): Int64 {
        normalizeSelected()
        horizontalFirstVisible(titles, selected, width, " ", " ", " ", " ", 0)
    }
}

/** 在一行绘制可切换的分段值；键盘切换有界，鼠标只命中可见段文本。
 */
public class SegmentedControl <: Widget {
    private let items: Array<String>
    /** 当前选中项的索引；非空列表的操作、值查询和绘制会先限制到有效范围，空列表中为 0。
     */
    public var selected: Int64
    private let style: Style
    private let selectedStyle: Style
    private let disabledStyle: Style
    private var focused: Bool
    private var disabled: Bool
    private var theme: ?Theme

    /** 保存分段值与绘制状态；构造时将选中索引限制到有效范围，选中样式默认使用语义主题角色。
     */
    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style.default(),
        disabledStyle!: Style = Style(fg: Color.Indexed(8)),
        focused!: Bool = false,
        disabled!: Bool = false,
        theme!: ?Theme = None
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
        this.disabledStyle = disabledStyle
        this.focused = focused
        this.disabled = disabled
        this.theme = theme
    }

    /** 返回当前选中值；空列表返回 None，查询前会限制可公开修改的索引。
     */
    public func selectedValue(): ?String {
        normalizeSelected()
        if (items.isEmpty()) { return None }
        Some(items[selected])
    }

    /** 设置聚焦、禁用状态和语义主题；禁用时拒绝键盘与鼠标输入。
     */
    public func setVisualState(
        focused!: Bool = false,
        disabled!: Bool = false,
        theme!: ?Theme = None
    ): Unit {
        this.focused = focused
        this.disabled = disabled
        this.theme = theme
    }

    /** 非空且启用时，Left/Right 有界移动，Home/End 跳到首尾；识别的按键即使停在边界也返回 true。
     */
    public func handle(key: KeyEvent): Bool {
        normalizeSelected()
        if (disabled || items.isEmpty()) { return false }
        match (key.code) {
            case KeyCode.Left =>
                selected = max(0, selected - 1)
                true
            case KeyCode.Right =>
                selected = min(items.size - 1, selected + 1)
                true
            case KeyCode.Home =>
                selected = 0
                true
            case KeyCode.End =>
                selected = items.size - 1
                true
            case _ => false
        }
    }

    /** 左键按下只选中首行可见段的文本单元格；段间空格、不可见位置及禁用状态不改变选中项。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        normalizeSelected()
        if (disabled || !widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                var x = area.x
                let first = firstVisible(area.width)
                for (index in first..items.size) {
                    if (x >= area.right) { return false }
                    let fullText = segmentText(index)
                    let fullWidth = displayWidth(fullText)
                    let visibleText = truncate(fullText, area.right - x)
                    let visibleWidth = displayWidth(visibleText)
                    if (mouse.x >= x && mouse.x - x < visibleWidth) {
                        selected = index
                        return true
                    }
                    x += visibleWidth
                    if (visibleWidth < fullWidth) { return false }
                    if (index + 1 < items.size && x < area.right) { x += 1 }
                }
                false
            case _ => false
        }
    }

    /** 绘制一行分段值；选中段用方括号，其他段两侧留空，间隔空格不属于任何段。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        normalizeSelected()
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.withCanvasClip(Rect(area.x, area.y, area.width, 1)) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let useTheme = selectedStyle == Style.default()
        let rowStyle = if (disabled) {
            themeRoleStyle(disabledStyle, ThemeRole.Disabled, theme)
        } else if (useTheme) {
            themedNormal(style, theme)
        } else {
            style
        }
        buffer.fillRect(Rect(area.x, area.y, area.width, 1), style: rowStyle)
        if (items.isEmpty()) { return }
        var x = area.x
        let first = firstVisible(area.width)
        for (index in first..items.size) {
            if (x >= area.right) { return }
            let fullText = segmentText(index)
            let text = truncate(fullText, area.right - x)
            let visibleWidth = displayWidth(text)
            buffer.setString(x, area.y, text, style: segmentStyle(index, useTheme))
            let fullWidth = displayWidth(fullText)
            x += visibleWidth
            if (visibleWidth < fullWidth) { return }
            if (index + 1 < items.size && x < area.right) { x += 1 }
        }
    }

    private func segmentText(index: Int64): String {
        if (index == selected) { "[" + items[index] + "]" } else { " " + items[index] + " " }
    }

    private func segmentStyle(index: Int64, useTheme: Bool): Style {
        if (disabled) { return themeRoleStyle(disabledStyle, ThemeRole.Disabled, theme) }
        let isSelected = index == selected
        var resolved = if (useTheme) {
            if (isSelected) { themedSelected(selectedStyle, theme) } else { themedNormal(style, theme) }
        } else {
            if (isSelected) { selectedStyle } else { style }
        }
        if (isSelected && focused) {
            var modifier = resolved.modifier
            modifier.bold = true
            modifier.underline = true
            resolved = addFocusedModifiers(resolved.withModifier(modifier), Style.default(), theme)
        }
        resolved
    }

    private func normalizeSelected(): Unit {
        if (items.isEmpty()) {
            selected = 0
        } else {
            selected = clamp(selected, 0, items.size - 1)
        }
    }

    private func firstVisible(width: Int64): Int64 {
        horizontalFirstVisible(items, selected, width, "[", "]", " ", " ", 1)
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
