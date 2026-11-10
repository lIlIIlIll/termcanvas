package core

import std.collection.*

/** 可通过键盘或鼠标激活的按钮。 */
public class Button <: Widget {
    private let label: String
    private let focused: Bool
    private let disabled: Bool
    private let block: ?Block
    private let style: Style
    private let focusedStyle: ?Style
    private let disabledStyle: ?Style
    private let theme: ?Theme
    private var renderedTheme: ?Theme = None
    private var ghost: Bool = false

    /** 保存按钮文字、状态和样式配置，供绘制时使用。主题下空样式采用凸起表面及可见边界；指定具体样式优先。无主题时保持原有外观。
     * @param label 标签文本
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param style 普通样式
     * @param focusedStyle 聚焦样式
     * @param disabledStyle 禁用样式
     * @param theme 可选的语义主题
     * @param block 可选边框
     */
    public init(
        label: String,
        focused!: Bool = false,
        disabled!: Bool = false,
        block!: ?Block = None,
        style!: Style = Style.default(),
        focusedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
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

    /** 控制空样式按钮是否使用无边界的主题 normal 样式；具体样式不受影响。
     * @param value 是否使用无边界样式
     */
    public func setGhost(value: Bool): Unit { ghost = value }

    /** 启用时处理回车或空格激活。
     * @param key 按键事件
     * @return 激活按钮时为 true
     */
    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) { case KeyCode.Enter | KeyCode.Char(r' ') => true; case _ => false }
    }

    /** 使用已有主题信息计算可点击区域并处理左键按下。
     * @param mouse 鼠标事件
     * @param area 按钮区域
     * @return 激活按钮时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool { handleMouse(mouse, area, layoutTheme: None) }

    /** 使用布局主题计算可点击区域并处理左键按下。
     * @param mouse 鼠标事件
     * @param area 按钮区域
     * @param layoutTheme 可选的布局主题
     * @return 激活按钮时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): Bool {
        if (disabled || !widgetHitTest(mouse, controlBlockArea(area, block, theme, layoutTheme, renderedTheme))) { return false }
        match ((mouse.kind, mouse.button)) { case (MouseKind.Down, MouseButton.Left) => true; case _ => false }
    }

    /** 在可选区块内部居中绘制按钮标签，并将整个可点击的内部区域填充为对应状态样式。下划线仅应用于标签，不应用于填充空白。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let activeTheme = buffer.resolveTheme(theme)
        var labelStyle = if (disabled) {
            match (disabledStyle) {
                case Some(value) => value
                case None => match (activeTheme) {
                    case Some(value) => value.disabled
                    case None => Style(fg: Color.Indexed(8))
                }
            }
        } else if (focused) {
            match (focusedStyle) {
                case Some(value) => value
                case None => match (activeTheme) {
                    case Some(value) => value.focused
                    case None => Style(fg: Color.Black, bg: Color.White)
                }
            }
        } else {
            if (!ghost && style == Style.default()) {
                match (activeTheme) { case Some(value) => value.raisedSurface; case None => style }
            } else {
                themedNormal(style, activeTheme)
            }
        }
        // Keep the built-in focus and disabled cues, while respecting all
        // explicitly supplied label styles.
        if (disabled && disabledStyle.isNone()) {
            var modifier = labelStyle.modifier
            modifier.italic = true
            labelStyle = labelStyle.withModifier(modifier)
        } else if (!disabled && focused && focusedStyle.isNone()) {
            var modifier = labelStyle.modifier
            modifier.bold = true
            modifier.underline = true
            labelStyle = labelStyle.withModifier(modifier)
        }
        var fillModifier = labelStyle.modifier
        fillModifier.underline = false
        buffer.fillRect(target, style: labelStyle.withModifier(fillModifier))
        let textWidth = if (displayWidth(label, options: buffer.textWidthOptions()) <= target.width - 2) { target.width - 2 } else { target.width }
        let text = truncate(label, textWidth, options: buffer.textWidthOptions())
        let textColumns = displayWidth(text, options: buffer.textWidthOptions())
        let x = alignedX(target, textColumns, TextAlign.Center)
        let y = target.y + (target.height - 1) / 2
        if (!ghost && style == Style.default() && activeTheme.isSome() && x > target.x && x + textColumns < target.right) {
            let boundaryStyle = labelStyle.withModifier(fillModifier)
            buffer.setString(x - 1, y, "[", style: boundaryStyle)
            buffer.setString(x + textColumns, y, "]", style: boundaryStyle)
        }
        buffer.setString(x, y, text, style: labelStyle)
    }
}

/** 显示并切换布尔选中状态的复选框。 */
public class Checkbox <: Widget {
    /** 当前选中状态。 */
    public var checked: Bool
    private let label: String
    private let focused: Bool
    private let disabled: Bool
    private let style: Style
    private let focusedStyle: ?Style
    private let disabledStyle: ?Style
    private let theme: ?Theme

    /** 创建复选框。
     * @param label 标签文本
     * @param checked 初始选中状态
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param style 普通样式
     * @param focusedStyle 聚焦样式
     * @param disabledStyle 禁用样式
     * @param theme 可选的语义主题
     */
    public init(
        label: String,
        checked!: Bool = false,
        focused!: Bool = false,
        disabled!: Bool = false,
        style!: Style = Style.default(),
        focusedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
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

    /** 启用时使用空格或回车切换选中状态。
     * @param key 按键事件
     * @return 处理按键时为 true
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

    /** 启用时在区域内左键按下可切换状态。
     * @param mouse 鼠标事件
     * @param area 交互区域
     * @return 切换状态时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (disabled || !widgetHitTest(mouse, area)) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) => checked = !checked; true
            case _ => false
        }
    }

    /** 在区域首行绘制选中标记和标签。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let mark = if (checked) { "[x] " } else { "[ ] " }
        let rowStyle = formVisualStyle(style, focusedStyle, disabledStyle, focused, disabled, buffer.resolveTheme(theme))
        buffer.setString(area.x, area.y, truncate(mark + label, area.width, options: buffer.textWidthOptions()), style: rowStyle)
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
    private let focusedStyle: ?Style
    private let disabledStyle: ?Style
    private var theme: ?Theme

    /** 保存标签、初始开关状态及绘制状态和样式。
     * @param label 标签文本
     * @param checked 初始选中状态
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param style 普通样式
     * @param focusedStyle 聚焦样式
     * @param disabledStyle 禁用样式
     * @param theme 可选的语义主题
     */
    public init(
        label: String,
        checked!: Bool = false,
        focused!: Bool = false,
        disabled!: Bool = false,
        style!: Style = Style.default(),
        focusedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
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
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param theme 可选的语义主题
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
     * @param key 按键事件
     * @return 切换状态时为 true
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
     * @param mouse 鼠标事件
     * @param area 交互区域
     * @return 切换状态时为 true
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
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let state = if (checked) { "on" } else { "off" }
        let text = if (label.isEmpty()) { "[${state}]" } else { "${label} [${state}]" }
        let rowStyle = formVisualStyle(style, focusedStyle, disabledStyle, focused, disabled, buffer.resolveTheme(theme))
        buffer.fillRect(Rect(area.x, area.y, area.width, 1), style: rowStyle)
        buffer.setString(area.x, area.y, truncate(text, area.width, options: buffer.textWidthOptions()), style: rowStyle)
    }
}

// Default focus and disabled roles follow the inherited theme. Explicit
// legacy styles patch the corresponding theme role, retaining unset fields.
private func formVisualStyle(style: Style, focusedStyle: ?Style, disabledStyle: ?Style,
    focused: Bool, disabled: Bool, theme: ?Theme): Style {
    if (disabled) {
        return match (disabledStyle) {
            case Some(value) => themedDisabled(value, theme)
            case None => match (theme) { case Some(value) => value.disabled; case None => Style(fg: Color.Indexed(8)) }
        }
    }
    if (focused) {
        return match (focusedStyle) {
            case Some(value) => themedFocused(value, theme)
            case None => match (theme) { case Some(value) => value.focused; case None => Style(fg: Color.Black, bg: Color.White) }
        }
    }
    themedNormal(style, theme)
}

/** 按行显示单选项，支持键盘导航和鼠标选择。 */
public class RadioGroup <: Widget {
    /** 选中项索引；绘制时限制在有效范围内。 */
    public var selected: Int64
    /** 首个可见选项的索引。 */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let items: Array<String>
    private let focused: Bool
    private let disabled: Bool
    private let block: ?Block
    private let style: Style
    private let focusedStyle: ?Style
    private let selectedStyle: ?Style
    private let disabledStyle: ?Style
    private let theme: ?Theme
    private var renderedTheme: ?Theme = None

    /** 创建单选组。
     * @param items 选项文本
     * @param selected 初始选中索引
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param block 可选边框
     * @param style 普通样式
     * @param focusedStyle 聚焦样式
     * @param selectedStyle 选中样式
     * @param disabledStyle 禁用样式
     * @param theme 可选语义主题
     */
    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        focused!: Bool = false,
        disabled!: Bool = false,
        block!: ?Block = None,
        style!: Style = Style.default(),
        focusedStyle!: ?Style = None,
        selectedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
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

    /** 处理方向、首尾、翻页及确认按键；禁用或没有选项时返回 false。
     * @param key 按键事件
     * @return 识别到按键时为 true
     */
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

    /** 使用已有主题信息计算交互区域并处理鼠标事件。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 处理鼠标事件时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool { handleMouse(mouse, area, layoutTheme: None) }

    /** 处理鼠标选择或滚轮，并使用布局主题计算可见区域。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @param layoutTheme 可选布局主题
     * @return 处理鼠标事件时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): Bool {
        if (disabled) { return false }
        let target = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            return true
        }
        false
    }

    /** 绘制可见选项并使选中项保持可见。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        viewportHeight = max(1, target.height)
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        let rows = min(target.height, items.size - offset)
        let activeTheme = buffer.resolveTheme(theme)
        let defaultFocused = if (activeTheme.isSome()) { Style.default() } else { Style(fg: Color.Cyan) }
        let defaultSelected = if (activeTheme.isSome()) { Style.default() } else { Style(fg: Color.Black, bg: Color.White) }
        let defaultDisabled = if (activeTheme.isSome()) { Style.default() } else { Style(fg: Color.Indexed(8)) }
        let focusedValue = match (focusedStyle) { case Some(value) => value; case None => defaultFocused }
        let selectedValue = match (selectedStyle) { case Some(value) => value; case None => defaultSelected }
        let disabledValue = match (disabledStyle) { case Some(value) => value; case None => defaultDisabled }
        for (i in 0..rows) {
            let index = offset + i
            let active = index == selected
            let mark = if (active) { "(*) " } else { "( ) " }
            let rowStyle = resolvedSemanticStateStyle(
                style,
                focusedValue,
                selectedValue,
                disabledValue,
                Style.default(),
                focused,
                active,
                disabled,
                false,
                activeTheme
            )
            buffer.setString(target.x, target.y + i, truncate(mark + items[index], target.width, options: buffer.textWidthOptions()), style: rowStyle)
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
    /** 首个可见选项的索引。 */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let block: ?Block
    private var renderedTheme: ?Theme = None
    private let style: Style
    private let selectedStyle: ?Style

    /** 创建选项列表。
     * @param items 选项文本
     * @param selected 初始选中索引
     * @param block 可选边框
     * @param style 普通样式
     * @param selectedStyle 选中样式
     */
    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: ?Style = None
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
    }

    /** 获取当前选中项文本；无效索引返回 None。
     * @return 选中项文本
     */
    public func selectedValue(): ?String {
        if (selected >= 0 && selected < items.size) { Some(items[selected]) } else { None }
    }

    /** 导航按键移动选中项；回车或空格确认当前项。
     * @param key 按键事件
     * @return 确认的选项；导航或未处理时为 None
     */
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

    /** 使用已有主题信息计算交互区域并处理鼠标事件。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 点击选项时返回其文本；滚轮或未命中时为 None
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?String { handleMouse(mouse, area, layoutTheme: None) }

    /** 处理鼠标选择或滚轮，并使用布局主题计算可见区域。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @param layoutTheme 可选布局主题
     * @return 点击选项时返回其文本；滚轮或未命中时为 None
     */
    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): ?String {
        let target = controlBlockArea(area, block, Option<Theme>.None, layoutTheme, renderedTheme)
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            if (mouseScrollDelta(mouse) == 0) { return selectedValue() }
        }
        None
    }

    /** 绘制可见选项并使选中项保持可见。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
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
                truncate(items[index], target.width, options: buffer.textWidthOptions()),
                style: if (index == selected) { listSelectionStyle(selectedStyle, buffer.resolveTheme(None)) } else { themedNormal(style, buffer.resolveTheme(None)) }
            )
        }
    }
}

/** 可展开的单选列表，支持可选的选择事务。 */
public class Dropdown <: Widget {
    private let items: Array<String>
    /** 当前选项索引；交互和绘制时限制到有效范围。 */
    public var selected: Int64
    /** 展开列表的首个可见选项索引。 */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    /** 列表是否展开。 */
    public var open: Bool
    private let placeholder: String
    private let style: Style
    private let selectedStyle: ?Style
    private var focused: Bool = false
    private var disabled: Bool = false
    private var theme: ?Theme = None
    private var transactionalSelection: Bool = false
    private var transactionActive: Bool = false
    private var originalSelection: Int64 = 0

    /** 创建下拉列表。
     * @param items 选项文本
     * @param selected 初始索引
     * @param open 是否初始展开
     * @param placeholder 没有有效选项时显示的文本
     * @param style 普通样式
     * @param selectedStyle 选中项样式
     */
    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        open!: Bool = false,
        placeholder!: String = "Select",
        style!: Style = Style.default(),
        selectedStyle!: ?Style = None
    ) {
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.open = open
        this.placeholder = placeholder
        this.style = style
        this.selectedStyle = selectedStyle
    }

    /** 设置聚焦、禁用状态和语义主题；禁用时拒绝键盘与鼠标输入。省略 selectedStyle 或显式传入 Style.default() 时使用主题选中角色，其余显式选中样式保持优先。
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param theme 可选的语义主题
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
     * @param enabled 是否启用事务选择
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

    private func resolvedHeaderStyle(theme: ?Theme): Style {
        if (disabled) { return themedDisabled(style, theme) }
        if (focused) { return themedFocused(style, theme) }
        themedNormal(style, theme)
    }

    private func resolvedListStyle(theme: ?Theme): Style {
        if (disabled) { return themedDisabled(style, theme) }
        themedNormal(style, theme)
    }

    private func resolvedSelectedRowStyle(theme: ?Theme): Style {
        let explicit = match (selectedStyle) { case Some(value) => value; case None => Style.default() }
        if (disabled) { return themedDisabled(explicit, theme) }
        let base = match (selectedStyle) {
            case Some(value) => if (value == Style.default()) { themedSelected(value, theme) } else { value }
            case None => match (theme) {
                case Some(value) => value.selected
                case None => Style(fg: Color.Black, bg: Color.White)
            }
        }
        if (focused) { addFocusedModifiers(base, Style.default(), theme) } else { base }
    }

    /** 获取当前选项文本。
     * @return 索引有效时的选项，否则为 None
     */
    public func selectedValue(): ?String {
        if (selected >= 0 && selected < items.size) { Some(items[selected]) } else { None }
    }

    /** 关闭时按回车或空格会展开；默认非事务模式下 Esc 关闭但保留预览索引。启用事务模式后，导航仅预览，回车或空格提交，Esc 恢复展开前索引。
     * @param key 按键事件
     * @return 提交的选项；其他情况为 None
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
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 点击提交的选项；其他情况为 None
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


    /** 绘制标题和可选的展开列表。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
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
        buffer.setString(area.x, area.y, truncate(mark + current, area.width, options: buffer.textWidthOptions()), style: resolvedHeaderStyle(buffer.resolveTheme(theme)))
        if (open) {
            let target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
            let select = Select(
                items,
                selected: selected,
                style: resolvedListStyle(buffer.resolveTheme(theme)),
                selectedStyle: resolvedSelectedRowStyle(buffer.resolveTheme(theme))
            )
            select.offset = offset
            buffer.withParentTheme(theme) { => select.render(target, buffer) }
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
     * @param colors 候选颜色
     * @param selected 初始选中索引
     */
    public init(colors!: Array<Color> = [Color.Red, Color.Green, Color.Yellow, Color.Blue, Color.Magenta, Color.Cyan], selected!: Int64 = 0) {
        this.colors = colors
        this.selected = clamp(selected, 0, max(0, colors.size - 1))
    }

    /** 设置聚焦、禁用状态和语义主题；禁用时拒绝键盘与鼠标输入。
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param theme 可选的语义主题
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
     * @return 当前颜色，或 None
     */
    public func selectedColor(): ?Color {
        if (selected >= 0 && selected < colors.size) { Some(colors[selected]) } else { None }
    }

    /** 左右键在边界处停留，Home/End 选择首尾颜色；支持的按键先规范化索引。禁用、空候选数组或不支持的按键返回 false 且不修改状态。
     * @param key 按键事件
     * @return 处理按键时为 true
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
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 选中色块时为 true
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
     * @param area 绘制区域
     * @param buffer 目标缓冲区
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

    private func swatchStyle(index: Int64, theme: ?Theme): Style {
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
            _ = buffer.writeStringClipped(x, area.y, "##", maxWidth: area.right - x, style: swatchStyle(index, buffer.resolveTheme(theme)))
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
                style: swatchStyle(trailingIndex, buffer.resolveTheme(theme))
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
    /** 首个可见条目的索引。 */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let style: ?Style
    private let selectedStyle: ?Style
    private let theme: ?Theme

    /** 保存条目与两种绘制样式，将光标限制在 0 到最后一个条目索引之间，并按传入顺序保存有效且不重复的初始选中索引。省略样式时使用主题角色，显式样式优先。
     * @param items 条目文本
     * @param cursor 初始光标索引
     * @param selected 初始选中索引
     * @param style 普通样式
     * @param selectedStyle 光标行样式
     * @param theme 可选语义主题
     */
    public init(items: Array<String>, cursor!: Int64 = 0, selected!: Array<Int64> = [], style!: ?Style = None,
        selectedStyle!: ?Style = None, theme!: ?Theme = None) {
        this.items = items
        this.cursor = clamp(cursor, 0, max(0, items.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
        this.theme = theme
        for (index in selected) {
            if (index >= 0 && index < items.size && !containsIndex(selectedItems, index)) {
                selectedItems.add(index)
            }
        }
    }

    /** 按选中顺序获取条目索引。
     * @return 已选索引数组
     */
    public func selectedIndices(): Array<Int64> { selectedItems.toArray() }

    /** 切换光标条目的选中状态；光标无效时不操作。 */
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

    /** 使用导航键移动光标，使用回车或空格切换当前条目。
     * @param key 按键事件
     * @return 识别到按键时为 true
     */
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

    /** 鼠标点击切换对应条目，滚轮移动光标。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 处理鼠标事件时为 true
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        offset = selectionViewportOffset(offset, cursor, items.size, area.height)
        if (let Some(index) <- selectionMouse(mouse, area, offset, items.size, cursor)) {
            cursor = index
            if (mouseScrollDelta(mouse) == 0) { toggle() }
            return true
        }
        false
    }

    /** 绘制可见条目及选中标记，并保持光标可见。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        viewportHeight = max(1, area.height)
        cursor = clamp(cursor, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, cursor, items.size, area.height)
        let activeTheme = buffer.resolveTheme(theme)
        let normal = match (style) {
            case Some(value) => value
            case None => match (activeTheme) { case Some(value) => value.normal; case None => Style.default() }
        }
        let active = match (selectedStyle) {
            case Some(value) => value
            case None => match (activeTheme) { case Some(value) => value.selected; case None => Style(fg: Color.Black, bg: Color.White) }
        }
        for (row in 0..min(area.height, items.size - offset)) {
            let index = offset + row
            let checked = containsIndex(selectedItems, index)
            let mark = if (checked) { "[x] " } else { "[ ] " }
            buffer.setString(area.x, area.y + row, truncate(mark + items[index], area.width, options: buffer.textWidthOptions()), style: if (index == cursor) { active } else { normal })
        }
    }
}

/** 显示并通过键盘调整年月日。 */
public class DatePicker <: Widget {
    /** 年份；支持的键盘操作会将其规范化为至少 1。 */
    public var year: Int64
    /** 月份；支持的键盘操作会将其规范化到 1 到 12。 */
    public var month: Int64
    /** 日期；支持的键盘操作会限制到对应月份的有效范围。 */
    public var day: Int64
    private var focused: Bool
    private var disabled: Bool
    private let style: Style
    private var theme: ?Theme

    /** 创建日期选择器，并将日期限制到有效范围。
     * @param year 年份，至少为 1
     * @param month 月份，限制为 1 到 12
     * @param day 日期，限制到月份有效范围
     * @param style 日期样式
     * @param theme 可选语义主题
     */
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
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param theme 可选的语义主题
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

    /** 将当前字段格式化为年-月-日文本；不会先规范化直接修改的字段。
     * @return 格式化的日期
     */
    public func value(): String { "${year}-${pad2(month)}-${pad2(day)}" }

    /** 左右键调整日，上下键调整月，PageUp/PageDown 调整年；支持的操作先校正公开日期字段。禁用或不支持的按键返回 false 且不修改状态。
     * @param key 按键事件
     * @return 识别到日期调整按键时为 true
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
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let rowStyle = resolvedStateStyle(style, style, style, focused, disabled, buffer.resolveTheme(theme))
        buffer.withCanvasClip(area) { =>
            buffer.setString(area.x, area.y, truncate(value(), area.width, options: buffer.textWidthOptions()), style: rowStyle)
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
