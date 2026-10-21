package core

import std.collection.*

public class Button <: Widget {
    private let label: String
    private let focused: Bool
    private let disabled: Bool
    private let block: ?Block
    private let style: Style
    private let focusedStyle: Style
    private let disabledStyle: Style
    private let theme: ?Theme

    public init(
        label: String,
        focused!: Bool = false,
        disabled!: Bool = false,
        block!: ?Block = None,
        style!: Style = Style.default(),
        focusedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style(fg: Color.Indexed(8)),
        theme!: ?Theme = None
    ) {
        this.label = label
        this.focused = focused
        this.disabled = disabled
        this.block = block
        this.style = style
        this.focusedStyle = focusedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
    }

    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) { case KeyCode.Enter | KeyCode.Char(r' ') => true; case _ => false }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled || !widgetHitTest(mouse, widgetInnerArea(area, block))) { return false }
        match ((mouse.kind, mouse.button)) { case (MouseKind.Down, MouseButton.Left) => true; case _ => false }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let rowStyle = resolvedStateStyle(style, focusedStyle, disabledStyle, focused, disabled, theme)
        buffer.fillRect(target, style: rowStyle)
        let text = truncate(label, target.width)
        let x = alignedX(target, displayWidth(text), TextAlign.Center)
        let y = target.y + (target.height - 1) / 2
        buffer.setString(x, y, text, style: rowStyle)
    }
}

public class Checkbox <: Widget {
    public var checked: Bool
    private let label: String
    private let focused: Bool
    private let disabled: Bool
    private let style: Style
    private let focusedStyle: Style
    private let disabledStyle: Style
    private let theme: ?Theme

    public init(
        label: String,
        checked!: Bool = false,
        focused!: Bool = false,
        disabled!: Bool = false,
        style!: Style = Style.default(),
        focusedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style(fg: Color.Indexed(8)),
        theme!: ?Theme = None
    ) {
        this.label = label
        this.checked = checked
        this.focused = focused
        this.disabled = disabled
        this.style = style
        this.focusedStyle = focusedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
    }

    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) {
            case KeyCode.Char(r' ') | KeyCode.Enter =>
                checked = !checked
                true
            case _ => false
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled || !widgetHitTest(mouse, area)) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) => checked = !checked; true
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let mark = if (checked) { "[x] " } else { "[ ] " }
        let rowStyle = resolvedStateStyle(style, focusedStyle, disabledStyle, focused, disabled, theme)
        buffer.setString(area.x, area.y, truncate(mark + label, area.width), style: rowStyle)
    }
}

/** 在首行显示“标签 [off/on]”状态；标签为空时只显示状态文字。
 */
public class Switch <: Widget {
    /** 当前开关状态；绘制时显示对应状态，可通过按键或鼠标操作切换。
     */
    public var checked: Bool
    private let label: String
    private var focused: Bool
    private var disabled: Bool
    private let style: Style
    private let focusedStyle: Style
    private let disabledStyle: Style
    private var theme: ?Theme

    /** 保存标签、初始开关状态及绘制状态和样式。
     */
    public init(
        label: String,
        checked!: Bool = false,
        focused!: Bool = false,
        disabled!: Bool = false,
        style!: Style = Style.default(),
        focusedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style(fg: Color.Indexed(8)),
        theme!: ?Theme = None
    ) {
        this.label = label
        this.checked = checked
        this.focused = focused
        this.disabled = disabled
        this.style = style
        this.focusedStyle = focusedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
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

    /** 未禁用时，空格或回车翻转状态并返回 true；禁用或其他按键时返回 false。
     */
    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) {
            case KeyCode.Char(r' ') | KeyCode.Enter =>
                checked = !checked
                true
            case _ => false
        }
    }

    /** 左键在首行按下时切换一次；其他鼠标事件、行、区域外点击及禁用状态不改变 checked。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled || area.width <= 0 || area.height <= 0) { return false }
        if (!widgetHitTest(mouse, Rect(area.x, area.y, area.width, 1))) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) => checked = !checked; true
            case _ => false
        }
    }

    /** 在非空区域首行绘制 label [off] 或 label [on]；空标签只绘制状态文字，并按区域宽度截断。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let state = if (checked) { "on" } else { "off" }
        let text = if (label.isEmpty()) { "[${state}]" } else { "${label} [${state}]" }
        let rowStyle = resolvedStateStyle(style, focusedStyle, disabledStyle, focused, disabled, theme)
        buffer.fillRect(Rect(area.x, area.y, area.width, 1), style: rowStyle)
        buffer.setString(area.x, area.y, truncate(text, area.width), style: rowStyle)
    }
}

public class RadioGroup <: Widget {
    public var selected: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let items: Array<String>
    private let focused: Bool
    private let disabled: Bool
    private let block: ?Block
    private let style: Style
    private let focusedStyle: Style
    private let selectedStyle: Style
    private let disabledStyle: Style
    private let theme: ?Theme

    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        focused!: Bool = false,
        disabled!: Bool = false,
        block!: ?Block = None,
        style!: Style = Style.default(),
        focusedStyle!: Style = Style(fg: Color.Cyan),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style(fg: Color.Indexed(8)),
        theme!: ?Theme = None
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.focused = focused
        this.disabled = disabled
        this.block = block
        this.style = style
        this.focusedStyle = focusedStyle
        this.selectedStyle = selectedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
    }

    public func handle(key: KeyEvent): Bool {
        if (disabled || items.size == 0) { return false }
        if (let Some(index) <- selectionNavigation(key, selected, items.size, viewportHeight)) {
            selected = index
            return true
        }
        match (key.code) {
            case KeyCode.Up =>
                selected = max(0, selected - 1)
                true
            case KeyCode.Down =>
                selected = min(items.size - 1, selected + 1)
                true
            case KeyCode.Char(r' ') | KeyCode.Enter => true
            case _ => false
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled) { return false }
        let target = widgetInnerArea(area, block)
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            return true
        }
        false
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        viewportHeight = max(1, target.height)
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        let rows = min(target.height, items.size - offset)
        for (i in 0..rows) {
            let index = offset + i
            let active = index == selected
            let mark = if (active) { "(*) " } else { "( ) " }
            let rowStyle = resolvedSemanticStateStyle(
                style,
                focusedStyle,
                selectedStyle,
                disabledStyle,
                Style.default(),
                focused,
                active,
                disabled,
                false,
                theme
            )
            buffer.setString(target.x, target.y + i, truncate(mark + items[index], target.width), style: rowStyle)
        }
    }
}

/** 按行绘制选项，当前索引对应的行使用选中样式；可通过按键移动索引并取得选项文字。
 */
public class Select <: Widget {
    private let items: Array<String>
    /** 当前选项的索引；在有效范围内时可用于获取选项文字，并决定绘制时哪一行使用选中样式。
     */
    public var selected: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let block: ?Block
    private let style: Style
    private let selectedStyle: Style

    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
    }

    public func selectedValue(): ?String {
        if (selected >= 0 && selected < items.size) { Some(items[selected]) } else { None }
    }

    public func handle(key: KeyEvent): ?String {
        if (items.size == 0) { return None }
        if (let Some(index) <- selectionNavigation(key, selected, items.size, viewportHeight)) {
            selected = index
            return None
        }
        match (key.code) {
            case KeyCode.Up =>
                selected = max(0, selected - 1)
                None
            case KeyCode.Down =>
                selected = min(items.size - 1, selected + 1)
                None
            case KeyCode.Home =>
                selected = 0
                None
            case KeyCode.End =>
                selected = items.size - 1
                None
            case KeyCode.Enter | KeyCode.Char(r' ') => selectedValue()
            case _ => None
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        let target = widgetInnerArea(area, block)
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            if (mouseScrollDelta(mouse) == 0) { return selectedValue() }
        }
        None
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        viewportHeight = max(1, target.height)
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        for (row in 0..min(target.height, items.size - offset)) {
            let index = offset + row
            buffer.setString(
                target.x,
                target.y + row,
                truncate(items[index], target.width),
                style: if (index == selected) { selectedStyle } else { style }
            )
        }
    }
}

public class Dropdown <: Widget {
    private let items: Array<String>
    public var selected: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    public var open: Bool
    private let placeholder: String
    private let style: Style
    private let selectedStyle: Style
    private var focused: Bool = false
    private var disabled: Bool = false
    private var theme: ?Theme = None
    private var transactionalSelection: Bool = false
    private var transactionActive: Bool = false
    private var originalSelection: Int64 = 0

    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        open!: Bool = false,
        placeholder!: String = "Select",
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.open = open
        this.placeholder = placeholder
        this.style = style
        this.selectedStyle = selectedStyle
    }

    /** 设置聚焦、禁用状态和语义主题；禁用时拒绝键盘与鼠标输入。selectedStyle 显式设为 Style.default() 时使用主题选中角色，其余显式选中样式保持优先。
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

    /** 启用后，展开时保存原选项；导航和滚轮仅预览，Enter、空格及可见选项点击提交，Esc、标题折叠和 cancelSelection() 恢复。默认关闭以保留旧行为；关闭事务模式会取消进行中的事务。
     */
    public func setTransactionalSelection(enabled!: Bool): Unit {
        if (transactionalSelection == enabled) { return }
        if (enabled) {
            transactionalSelection = true
            observeTransactionState()
        } else {
            observeTransactionState()
            cancelSelection()
            transactionalSelection = false
        }
    }

    /** 取消展开选择；事务模式恢复展开前索引，非事务模式保留当前索引，并关闭列表。应用可用于处理区域外点击、焦点丢失、重置或页面关闭。
     */
    public func cancelSelection(): Unit {
        if (transactionActive) {
            selected = clamp(originalSelection, 0, max(0, items.size - 1))
            transactionActive = false
        }
        open = false
        normalizeSelection()
    }

    private func beginSelectionTransaction(): Unit {
        if (!transactionalSelection || !open || transactionActive) { return }
        normalizeSelection()
        originalSelection = selected
        transactionActive = true
    }

    private func observeTransactionState(): Unit {
        if (!transactionalSelection) { return }
        if (open) {
            beginSelectionTransaction()
        } else if (transactionActive) {
            cancelSelection()
        }
    }

    private func normalizeSelection(): Unit {
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, viewportHeight)
    }

    private func commitSelection(): ?String {
        transactionActive = false
        open = false
        selectedValue()
    }

    private func resolvedHeaderStyle(): Style {
        if (disabled) { return themedDisabled(style, theme) }
        if (focused) { return themedFocused(style, theme) }
        themedNormal(style, theme)
    }

    private func resolvedListStyle(): Style {
        if (disabled) { return themedDisabled(style, theme) }
        themedNormal(style, theme)
    }

    private func resolvedSelectedRowStyle(): Style {
        if (disabled) { return themedDisabled(selectedStyle, theme) }
        let base = if (selectedStyle == Style.default()) {
            themedSelected(selectedStyle, theme)
        } else {
            selectedStyle
        }
        if (focused) { addFocusedModifiers(base, Style.default(), theme) } else { base }
    }

    public func selectedValue(): ?String {
        if (selected >= 0 && selected < items.size) { Some(items[selected]) } else { None }
    }

    /** 关闭时按回车或空格会展开；默认非事务模式下 Esc 关闭但保留预览索引。启用事务模式后，导航仅预览，回车或空格提交，Esc 恢复展开前索引。
     */
    public func handle(key: KeyEvent): ?String {
        observeTransactionState()
        if (disabled) { return None }
        if (!open) {
            match (key.code) {
                case KeyCode.Enter | KeyCode.Char(r' ') =>
                    normalizeSelection()
                    open = true
                    beginSelectionTransaction()
                    None
                case _ => None
            }
        } else {
            normalizeSelection()
            if (let Some(index) <- selectionNavigation(key, selected, items.size, viewportHeight)) {
                selected = index
                normalizeSelection()
                return None
            }
            match (key.code) {
                case KeyCode.Esc =>
                    cancelSelection()
                    None
                case KeyCode.Enter | KeyCode.Char(r' ') => commitSelection()
                case _ => None
            }
        }
    }

    /** 标题点击切换展开状态；事务模式下可见选项点击提交，滚轮只预览当前选项。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        if (open) { viewportHeight = max(0, area.height - 1) }
        observeTransactionState()
        if (disabled || !widgetHitTest(mouse, area)) { return None }
        normalizeSelection()
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                if (mouse.y == area.y) {
                    if (open) {
                        cancelSelection()
                    } else {
                        open = true
                        viewportHeight = max(0, area.height - 1)
                        beginSelectionTransaction()
                    }
                    return None
                }
            case _ => ()
        }
        if (!open) { return None }
        let target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
        viewportHeight = target.height
        normalizeSelection()
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            normalizeSelection()
            if (mouseScrollDelta(mouse) == 0) { return commitSelection() }
        }
        None
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        if (open) { viewportHeight = max(0, area.height - 1) }
        observeTransactionState()
        normalizeSelection()
        let current = match (selectedValue()) {
            case Some(value) => value
            case None => placeholder
        }
        let mark = if (open) { "v " } else { "> " }
        buffer.setString(area.x, area.y, truncate(mark + current, area.width), style: resolvedHeaderStyle())
        if (open) {
            let target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
            let select = Select(
                items,
                selected: selected,
                style: resolvedListStyle(),
                selectedStyle: resolvedSelectedRowStyle()
            )
            select.offset = offset
            select.render(target, buffer)
            selected = select.selected
            offset = select.offset
        }
    }
}

/** 显示颜色候选项的实验性控件；支持左右键及 Home/End 选择、窄区域可见窗口、鼠标选择、主题对比色与聚焦标记。
 */
public class ColorPicker <: Widget {
    private let colors: Array<Color>
    private var focused: Bool = false
    private var disabled: Bool = false
    private var theme: ?Theme = None
    /** 当前颜色在候选数组中的索引；构造时限制在有效范围内，候选数组为空时为 0。直接赋值的无效索引会在支持的键盘操作或绘制时规范化。
     */
    public var selected: Int64

    /** 保存候选颜色并限制初始索引；空候选数组的索引为 0，且不会产生选中颜色。
     */
    public init(colors!: Array<Color> = [Color.Red, Color.Green, Color.Yellow, Color.Blue, Color.Magenta, Color.Cyan], selected!: Int64 = 0) {
        this.colors = colors
        this.selected = clamp(selected, 0, max(0, colors.size - 1))
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

    /** 当前索引有效时返回对应颜色；空候选数组或直接赋值的无效索引返回 None。
     */
    public func selectedColor(): ?Color {
        if (selected >= 0 && selected < colors.size) { Some(colors[selected]) } else { None }
    }

    /** 左右键在边界处停留，Home/End 选择首尾颜色；支持的按键先规范化索引。禁用、空候选数组或不支持的按键返回 false 且不修改状态。
     */
    public func handle(key: KeyEvent): Bool {
        if (disabled || colors.size == 0) { return false }
        match (key.code) {
            case KeyCode.Left =>
                normalizeSelection()
                selected = max(0, selected - 1)
                true
            case KeyCode.Right =>
                normalizeSelection()
                selected = min(colors.size - 1, selected + 1)
                true
            case KeyCode.Home =>
                normalizeSelection()
                selected = 0
                true
            case KeyCode.End =>
                normalizeSelection()
                selected = colors.size - 1
                true
            case _ => false
        }
    }

    /** 左键按下仅选择当前可见且两格完整的色块；间隔、释放、区域外、禁用或空候选数组均不修改状态。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled || colors.size == 0 || !widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                let (start, visibleCount) = visibleWindow(area)
                let column = mouse.x - area.x
                let slot = column / 3
                if (column % 3 == 2 || slot >= visibleCount || slot * 3 + 1 >= area.width) { return false }
                let index = start + slot
                if (index >= colors.size) { return false }
                selected = index
                true
            case _ => false
        }
    }

    /** 在指定区域裁剪绘制颜色候选项；规范化索引并保持选中色块在可见窗口内。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func normalizeSelection(): Unit {
        if (colors.size > 0) { selected = clamp(selected, 0, colors.size - 1) }
    }

    private func visibleWindow(area: Rect): (Int64, Int64) {
        if (colors.size == 0 || area.width <= 0) { return (0, 0) }
        let capacity = max(1, area.width / 3 + (if (area.width % 3 == 2) { 1 } else { 0 }))
        let visibleCount = min(colors.size, capacity)
        let normalized = clamp(selected, 0, colors.size - 1)
        let start = clamp(normalized - visibleCount + 1, 0, colors.size - visibleCount)
        (start, visibleCount)
    }

    private func swatchStyle(index: Int64): Style {
        let color = colors[index]
        if (index != selected) { return Style(fg: color) }
        let foreground = match (color) {
            case Color.Reset =>
                match (theme) {
                    case Some(value) => value.normal.fg
                    case None => Color.Reset
                }
            case _ => colorPickerContrastForeground(color)
        }
        var modifier = Modifier.none()
        if (focused && !disabled) {
            modifier.bold = true
            modifier.underline = true
        }
        Style(fg: foreground, bg: color, modifier: modifier)
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (colors.size == 0) { return }
        normalizeSelection()
        if (area.width <= 0 || area.height <= 0) { return }
        let (start, visibleCount) = visibleWindow(area)
        var slot: Int64 = 0
        while (slot < visibleCount) {
            let index = start + slot
            let x = area.x + slot * 3
            _ = buffer.writeStringClipped(x, area.y, "##", maxWidth: area.right - x, style: swatchStyle(index))
            slot++
        }
        let trailingIndex = start + visibleCount
        let trailingX = area.x + visibleCount * 3
        if (trailingIndex < colors.size && trailingX < area.right) {
            _ = buffer.writeStringClipped(
                trailingX,
                area.y,
                "##",
                maxWidth: area.right - trailingX,
                style: swatchStyle(trailingIndex)
            )
        }
    }
}
private func colorPickerContrastForeground(color: Color): Color {
    let (r, g, b) = colorRgbComponents(color)
    let luminance = r * 2126 + g * 7152 + b * 722
    if (luminance > 1_400_000) { Color.Black } else { Color.White }
}

/** 按行显示可多选的文本项，以勾选标记表示选中状态，并用单独的样式显示光标所在行。
 */
public class MultiSelect <: Widget {
    private let items: Array<String>
    private let selectedItems = ArrayList<Int64>()
    /** 当前指向的条目索引，用于切换该项的选中状态，并决定绘制时哪一行使用光标样式。
     */
    public var cursor: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let style: Style
    private let selectedStyle: Style

    /** 保存条目与两种绘制样式，将光标限制在 0 到最后一个条目索引之间，并按传入顺序保存初始选中索引；不校验这些选中索引。
     */
    public init(items: Array<String>, cursor!: Int64 = 0, selected!: Array<Int64> = [], style!: Style = Style.default(), selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)) {
        this.items = items
        this.cursor = clamp(cursor, 0, max(0, items.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
        for (index in selected) {
            if (index >= 0 && index < items.size && !containsIndex(selectedItems, index)) {
                selectedItems.add(index)
            }
        }
    }

    public func selectedIndices(): Array<Int64> { selectedItems.toArray() }

    public func toggle(): Unit {
        if (cursor < 0 || cursor >= items.size) { return }
        for (i in 0..selectedItems.size) {
            if (selectedItems[i] == cursor) {
                selectedItems.remove(at: i)
                return
            }
        }
        selectedItems.add(cursor)
    }

    public func handle(key: KeyEvent): Bool {
        if (let Some(index) <- selectionNavigation(key, cursor, items.size, viewportHeight)) {
            cursor = index
            return true
        }
        match (key.code) {
            case KeyCode.Up => cursor = max(0, cursor - 1); true
            case KeyCode.Down => cursor = min(max(0, items.size - 1), cursor + 1); true
            case KeyCode.Char(r' ') | KeyCode.Enter => toggle(); true
            case _ => false
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        offset = selectionViewportOffset(offset, cursor, items.size, area.height)
        if (let Some(index) <- selectionMouse(mouse, area, offset, items.size, cursor)) {
            cursor = index
            if (mouseScrollDelta(mouse) == 0) { toggle() }
            return true
        }
        false
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        viewportHeight = max(1, area.height)
        cursor = clamp(cursor, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, cursor, items.size, area.height)
        for (row in 0..min(area.height, items.size - offset)) {
            let index = offset + row
            let checked = containsIndex(selectedItems, index)
            let mark = if (checked) { "[x] " } else { "[ ] " }
            buffer.setString(area.x, area.y + row, truncate(mark + items[index], area.width), style: if (index == cursor) { selectedStyle } else { style })
        }
    }
}

public class DatePicker <: Widget {
    public var year: Int64
    public var month: Int64
    public var day: Int64
    private var focused: Bool
    private var disabled: Bool
    private let style: Style
    private var theme: ?Theme

    public init(
        year!: Int64 = 2026,
        month!: Int64 = 1,
        day!: Int64 = 1,
        style!: Style = Style(fg: Color.Cyan),
        theme!: ?Theme = None
    ) {
        this.year = max(1, year)
        this.month = clamp(month, 1, 12)
        this.day = clamp(day, 1, datePickerDaysInMonth(this.year, this.month))
        this.focused = false
        this.disabled = false
        this.style = style
        this.theme = theme
    }

    /** 设置聚焦、禁用状态及语义主题；禁用时拒绝日期键盘操作。
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

    private func normalizeDate(): Unit {
        year = max(1, year)
        month = clamp(month, 1, 12)
        day = clamp(day, 1, datePickerDaysInMonth(year, month))
    }

    public func value(): String { "${year}-${pad2(month)}-${pad2(day)}" }

    /** 左右键调整日，上下键调整月，PageUp/PageDown 调整年；支持的操作先校正公开日期字段。禁用或不支持的按键返回 false 且不修改状态。
     */
    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) {
            case KeyCode.Left | KeyCode.Right | KeyCode.Up | KeyCode.Down | KeyCode.PageUp | KeyCode.PageDown =>
                normalizeDate()
                match (key.code) {
                    case KeyCode.Left => day = max(1, day - 1); true
                    case KeyCode.Right => day = min(datePickerDaysInMonth(year, month), day + 1); true
                    case KeyCode.Up =>
                        month = min(12, month + 1)
                        day = min(day, datePickerDaysInMonth(year, month))
                        true
                    case KeyCode.Down =>
                        month = max(1, month - 1)
                        day = min(day, datePickerDaysInMonth(year, month))
                        true
                    case KeyCode.PageUp =>
                        if (year < Int64.Max) { year += 1 }
                        day = min(day, datePickerDaysInMonth(year, month))
                        true
                    case KeyCode.PageDown =>
                        if (year > 1) { year -= 1 }
                        day = min(day, datePickerDaysInMonth(year, month))
                        true
                    case _ => false
                }
            case _ => false
        }
    }

    /** 在非空区域首行绘制截断后的日期文本；样式按视觉状态和主题解析，默认保持青色前景。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let rowStyle = resolvedStateStyle(style, style, style, focused, disabled, theme)
        buffer.withCanvasClip(area) { =>
            buffer.setString(area.x, area.y, truncate(value(), area.width), style: rowStyle)
        }
    }
}

func datePickerDaysInMonth(year: Int64, month: Int64): Int64 {
    match (month) {
        case 2 => if (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)) { 29 } else { 28 }
        case 4 | 6 | 9 | 11 => 30
        case _ => 31
    }
}
