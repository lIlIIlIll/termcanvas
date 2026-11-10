package core

import std.collection.*
import std.unicode.*

/** 菜单或命令面板中的动作项。
 */
public class MenuItem {
    /** 显示文本。
     */
    public let label: String
    /** 触发时返回的动作标识。
     */
    public let action: String
    /** 是否允许触发。
     */
    public let enabled: Bool

    /** 创建动作项；动作标识为空时使用显示文本。
     * @param label 显示文本
     * @param action 可选动作标识
     * @param enabled 是否允许触发
     */
    public init(label: String, action!: String = "", enabled!: Bool = true) {
        this.label = label
        this.action = if (action.isEmpty()) { label } else { action }
        this.enabled = enabled
    }
}

/** 纵向菜单，返回被触发项目的动作标识。
 */
public class Menu <: Widget {
    private let title: String
    private let items: Array<MenuItem>
    /** 当前选中索引。
     */
    public var selected: Int64
    /** 列表起始索引。
     */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let block: ?Block
    private let style: ?Style
    private let selectedStyle: ?Style
    private let disabledStyle: ?Style
    private let theme: ?Theme

    /** 创建控件。
     * @param title 标题
     * @param items 菜单项
     * @param selected 初始选中索引
     * @param block 可选外框
     * @param style 普通项样式
     * @param selectedStyle 选中项样式
     * @param disabledStyle 禁用项样式
     * @param theme 可选语义主题
     */
    public init(
        title: String,
        items: Array<MenuItem>,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
        theme!: ?Theme = None
    ) {
        this.title = title
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
    }

    /** 处理键盘导航和动作触发。
     * @param key 键盘事件
     * @return 触发启用项时返回动作标识，否则返回 None。
     */
    public func handle(key: KeyEvent): ?String {
        if (items.isEmpty()) { return None }
        selected = clamp(selected, 0, items.size - 1)
        if (let Some(index) <- selectionNavigation(key, selected, items.size, viewportHeight)) {
            selected = index
            return None
        }
        match (key.code) {
            case KeyCode.Enter | KeyCode.Char(r' ') =>
                if (items[selected].enabled) { Some(items[selected].action) } else { None }
            case _ => None
        }
    }

    /** 处理鼠标选择和动作触发。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 触发启用项时返回动作标识，否则返回 None。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        var target = widgetInnerArea(area, block)
        if (block.isNone() && !title.isEmpty()) {
            target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
        }
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            if (mouseScrollDelta(mouse) == 0 && items[index].enabled) { return Some(items[index].action) }
        }
        None
    }

    /** 在区域内绘制控件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let theme = buffer.resolveTheme(this.theme)
        let normal = widgetRoleStyle(style, theme, ThemeRole.Normal, Style.default())
        let highlight = widgetRoleStyle(selectedStyle, theme, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White))
        let disabled = widgetRoleStyle(disabledStyle, theme, ThemeRole.Disabled, Style(fg: Color.Indexed(8)))
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(this.theme) { => b.render(area, buffer) }
            target = b.inner(area)
        } else if (!title.isEmpty()) {
            buffer.setString(area.x, area.y, truncate(title, area.width, options: buffer.textWidthOptions()), style: normal)
            target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
        }
        viewportHeight = max(1, target.height)
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        for (row in 0..min(target.height, items.size - offset)) {
            let index = offset + row
            let item = items[index]
            let rowStyle = if (!item.enabled) {
                disabled
            } else if (index == this.selected) {
                highlight
            } else {
                normal
            }
            buffer.setString(target.x, target.y + row, truncate(item.label, target.width, options: buffer.textWidthOptions()), style: rowStyle)
        }
    }
}

/** 横向菜单标签栏。
 */
public class MenuBar <: Widget {
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private let menus: Array<String>
    /** 当前选中索引。
     */
    public var selected: Int64
    private let style: ?Style
    private let selectedStyle: ?Style
    private let theme: ?Theme

    /** 创建控件。
     * @param menus 标签文本
     * @param selected 初始选中索引
     * @param style 普通标签样式
     * @param selectedStyle 选中标签样式
     * @param theme 可选语义主题
     */
    public init(
        menus: Array<String>,
        selected!: Int64 = 0,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        theme!: ?Theme = None
    ) {
        this.menus = menus
        this.selected = clamp(selected, 0, max(0, menus.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
        this.theme = theme
    }

    /** 处理左右及首页、末页按键。
     * @param key 键盘事件
     * @return 支持且存在标签时为 true。
     */
    public func handle(key: KeyEvent): Bool {
        if (menus.size == 0) { return false }
        match (key.code) {
            case KeyCode.Left =>
                selected = max(0, selected - 1)
                true
            case KeyCode.Right =>
                selected = min(menus.size - 1, selected + 1)
                true
            case KeyCode.Home =>
                selected = 0
                true
            case KeyCode.End =>
                selected = menus.size - 1
                true
            case _ => false
        }
    }

    /** 处理首行标签的鼠标选择。
     * @param mouse 鼠标事件
     * @param area 菜单栏区域
     * @return 选中标签时为 true。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (!widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                var x = area.x
                for (i in 0..menus.size) {
                    let width = displayWidth(" " + menus[i] + " ", options: textWidthOptionsValue)
                    if (mouse.x >= x && mouse.x - x < width) { selected = i; return true }
                    x += width
                }
                false
            case _ => false
        }
    }

    /** 在区域内绘制控件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        textWidthOptionsValue = buffer.textWidthOptions()
        if (area.width <= 0 || area.height <= 0) { return }
        let theme = buffer.resolveTheme(this.theme)
        let normal = widgetRoleStyle(style, theme, ThemeRole.Normal, Style.default())
        let selectedStyle = widgetRoleStyle(this.selectedStyle, theme, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White))
        var x = area.x
        for (i in 0..menus.size) {
            if (x >= area.right) { return }
            let label = " " + menus[i] + " "
            let rowStyle = if (i == selected) { selectedStyle } else { normal }
            buffer.setString(x, area.y, truncate(label, area.right - x, options: textWidthOptionsValue), style: rowStyle)
            x += displayWidth(label, options: textWidthOptionsValue)
        }
    }
}

/** 支持文本过滤的命令选择面板。
 */
public class CommandPalette <: Widget {
    private let items: Array<MenuItem>
    /** 当前过滤文本。
     */
    public var query: String
    /** 当前选中索引。
     */
    public var selected: Int64
    /** 列表起始索引。
     */
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private var lastQuery: String = ""
    private let block: ?Block
    private let style: ?Style
    private let selectedStyle: ?Style
    private let disabledStyle: ?Style
    private var theme: ?Theme = None
    private let caseSensitive: Bool

    /** 创建控件。
     * @param items 命令项
     * @param query 初始查询文本
     * @param selected 初始选中索引
     * @param block 可选外框
     * @param style 普通项样式
     * @param selectedStyle 选中项样式
     * @param disabledStyle 禁用项样式
     * @param theme 可选语义主题
     * @param caseSensitive 过滤时是否区分大小写
     */
    public init(
        items: Array<MenuItem>,
        query!: String = "",
        selected!: Int64 = 0,
        block!: ?Block = Some(Block(title: "Command")),
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        disabledStyle!: ?Style = None,
        theme!: ?Theme = None,
        caseSensitive!: Bool = true
    ) {
        this.items = items
        this.query = query
        this.lastQuery = query
        this.selected = max(0, selected)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.disabledStyle = disabledStyle
        this.theme = theme
        this.caseSensitive = caseSensitive
        clampSelection()
    }
    /** 设置或清除语义主题。
     * @param theme 主题；None 表示清除
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    /** 将文本追加到查询并同步过滤结果。
     * @param text 要追加的文本
     */
    public func paste(text: String): Unit {
        query += text
        _ = synchronizeQuery()
    }

    /** 处理键盘导航和动作触发。
     * @param key 键盘事件
     * @return 触发启用项时返回动作标识，否则返回 None。
     */
    public func handle(key: KeyEvent): ?String {
        let rows = synchronizeQuery()
        if (let Some(index) <- selectionNavigation(key, selected, rows.size, viewportHeight)) {
            selected = index
            return None
        }
        match (key.code) {
            case KeyCode.Char(r) =>
                query += match (key.text) { case Some(text) => text; case None => runeToString(r) }
                selected = 0
                None
            case KeyCode.Backspace =>
                if (!query.isEmpty()) { query = query[..previousRuneOffset(query, query.size)] }
                selected = 0
                None
            case KeyCode.Up =>
                selected = max(0, selected - 1)
                None
            case KeyCode.Down =>
                selected = min(max(0, rows.size - 1), selected + 1)
                None
            case KeyCode.Enter =>
                if (selected >= 0 && selected < rows.size && rows[selected].enabled) {
                    Some(rows[selected].action)
                } else {
                    None
                }
            case _ => None
        }
    }

    /** 处理鼠标选择和动作触发。
     * @param mouse 鼠标事件
     * @param area 控件区域
     * @return 触发启用项时返回动作标识，否则返回 None。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        let rows = synchronizeQuery()
        let inner = widgetInnerArea(area, block)
        let target = Rect(inner.x, inner.y + 1, inner.width, max(0, inner.height - 1))
        offset = selectionViewportOffset(offset, selected, rows.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, rows.size, selected)) {
            selected = index
            if (mouseScrollDelta(mouse) == 0 && rows[index].enabled) { return Some(rows[index].action) }
        }
        None
    }

    private func synchronizeQuery(): Array<MenuItem> {
        if (lastQuery != query) {
            selected = 0
            offset = 0
            lastQuery = query
        }
        let rows = filtered()
        selected = clamp(selected, 0, max(0, rows.size - 1))
        rows
    }

    /** 在区域内绘制控件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let rows = synchronizeQuery()
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let renderTheme = buffer.resolveTheme(theme)
        let normalRowStyle = resolvedNormalStyle(renderTheme)
        buffer.fillLine(target.y, target.x, target.width, style: normalRowStyle)
        buffer.setString(target.x, target.y, truncate("> " + query, target.width, options: buffer.textWidthOptions()), style: normalRowStyle)
        let contentHeight = max(0, target.height - 1)
        viewportHeight = max(1, contentHeight)
        offset = selectionViewportOffset(offset, selected, rows.size, contentHeight)
        for (row in 0..contentHeight) {
            let y = target.y + 1 + row
            if (rows.isEmpty() && row == 0) {
                let emptyStyle = resolvedDisabledStyle(renderTheme)
                buffer.fillLine(y, target.x, target.width, style: emptyStyle)
                buffer.setString(target.x, y, truncate("No matches", target.width, options: buffer.textWidthOptions()), style: emptyStyle)
            } else if (row < rows.size - offset) {
                let index = offset + row
                let item = rows[index]
                let rowStyle = resolvedRowStyle(item, index, renderTheme)
                buffer.fillLine(y, target.x, target.width, style: rowStyle)
                buffer.setString(target.x, y, truncate(item.label, target.width, options: buffer.textWidthOptions()), style: rowStyle)
            } else {
                buffer.fillLine(y, target.x, target.width, style: normalRowStyle)
            }
        }
    }

    private func clampSelection(): Unit {
        selected = clamp(selected, 0, max(0, filtered().size - 1))
    }
    private func resolvedNormalStyle(theme: ?Theme): Style {
        widgetRoleStyle(style, theme, ThemeRole.Normal, Style.default())
    }

    private func resolvedSelectedStyle(theme: ?Theme): Style {
        match (selectedStyle) {
            case Some(value) => if (value == Style.default() && theme.isSome()) { themedSelected(value, theme) } else { value }
            case None => widgetRoleStyle(Option<Style>.None, theme, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White))
        }
    }

    private func resolvedDisabledStyle(theme: ?Theme): Style {
        widgetRoleStyle(disabledStyle, theme, ThemeRole.Disabled, Style(fg: Color.Indexed(8)))
    }

    private func resolvedRowStyle(item: MenuItem, index: Int64, theme: ?Theme): Style {
        if (!item.enabled) {
            resolvedDisabledStyle(theme)
        } else if (index == selected) {
            resolvedSelectedStyle(theme)
        } else {
            resolvedNormalStyle(theme)
        }
    }

    private func filtered(): Array<MenuItem> {
        if (query.isEmpty()) { return items }
        let searchQuery = if (caseSensitive) { query } else { query.toLower() }
        let rows = ArrayList<MenuItem>()
        for (item in items) {
            let matches = if (caseSensitive) {
                item.label.contains(query) || item.action.contains(query)
            } else {
                item.label.toLower().contains(searchQuery) || item.action.toLower().contains(searchQuery)
            }
            if (matches) { rows.add(item) }
        }
        rows.toArray()
    }
}

/** 通知的语义类别。
 */
public enum ToastKind {
    /** 成功。
     */
    | Success
    /** 警告。
     */
    | Warning
    /** 错误。
     */
    | Error
    /** 信息。
     */
    | Info
}

/** 具有存活 tick 数的通知。
 */
public class Toast {
    /** 通知文本。
     */
    public let message: String
    /** 剩余 tick 数，构造时负值按零处理。
     */
    public let ttl: Int64
    /** 通知样式。
     */
    public let style: Style
    /** 可选语义类别。
     */
    public let kind: ?ToastKind

    /** 创建普通通知。
     * @param message 通知文本
     * @param ttl 存活 tick 数，负值按零处理
     * @param style 通知样式
     */
    public init(message: String, ttl!: Int64 = 3, style!: Style = Style(fg: Color.Black, bg: Color.Yellow)) {
        this.message = message
        this.ttl = max(0, ttl)
        this.style = style
        this.kind = None
    }

    /** 创建可带语义类别的通知。
     * @param message 通知文本
     * @param kind 可选语义类别
     * @param ttl 存活 tick 数，负值按零处理
     * @param style 修补语义样式的样式
     */
    public init(
        message: String,
        kind!: ?ToastKind,
        ttl!: Int64 = 3,
        style!: Style = Style.default()
    ) {
        this.message = message
        this.ttl = max(0, ttl)
        this.style = style
        this.kind = kind
    }
}

/** 保存、更新和绘制通知队列。
 */
public class ToastManager <: Widget {
    private let toasts = ArrayList<Toast>()
    private let maxToasts: ?Int64
    private var theme: ?Theme

    /** 创建通知管理器。
     * @param toasts 初始通知，已过期项会被忽略
     * @param maxToasts 可选数量上限；超限保留较新的通知
     * @param theme 可选语义主题
     */
    public init(
        toasts!: Array<Toast> = [],
        maxToasts!: ?Int64 = None,
        theme!: ?Theme = None
    ) {
        this.maxToasts = match (maxToasts) {
            case Some(limit) => Some(max(0, limit))
            case None => None
        }
        this.theme = theme

        if (let Some(limit) <- this.maxToasts) {
            if (limit > 0) {
                var liveCount: Int64 = 0
                for (toast in toasts) {
                    if (toast.ttl > 0) { liveCount++ }
                }
                var skipped = max(0, liveCount - limit)
                for (toast in toasts) {
                    if (toast.ttl > 0) {
                        if (skipped > 0) {
                            skipped--
                        } else {
                            this.toasts.add(toast)
                        }
                    }
                }
            }
        } else {
            for (toast in toasts) {
                if (toast.ttl > 0) { this.toasts.add(toast) }
            }
        }
    }

    /** 追加未过期通知；达到上限时移除最旧通知。
     * @param toast 通知
     */
    public func push(toast: Toast): Unit {
        if (toast.ttl <= 0) { return }
        if (let Some(limit) <- maxToasts) {
            if (limit == 0) { return }
            if (toasts.size >= limit) { toasts.remove(at: 0) }
        }
        toasts.add(toast)
    }

    /** 获取当前通知数。
     * @return 通知数。
     */
    public func count(): Int64 {
        toasts.size
    }

    /** 设置或清除主题。
     * @param theme 主题；None 表示清除
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    /** 将所有通知的剩余 tick 数减一并移除过期项。
     */
    public func tick(): Unit {
        var writeIndex: Int64 = 0
        let originalCount = toasts.size
        for (readIndex in 0..originalCount) {
            let toast = toasts[readIndex]
            if (toast.ttl > 1) {
                toasts[writeIndex] = Toast(
                    toast.message,
                    kind: toast.kind,
                    ttl: toast.ttl - 1,
                    style: toast.style
                )
                writeIndex++
            }
        }
        while (toasts.size > writeIndex) {
            toasts.remove(at: toasts.size - 1)
        }
    }

    /** 按可用高度绘制最新通知。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let rows = min(area.height, toasts.size)
        for (i in 0..rows) {
            let toast = toasts[toasts.size - rows + i]
            let y = area.y + i
            let style = resolvedStyle(toast, buffer.resolveTheme(theme))
            let text = match (toast.kind) {
                case Some(kind) => marker(kind) + " " + toast.message
                case None => toast.message
            }
            buffer.fillLine(y, area.x, area.width, style: style)
            buffer.setString(area.x, y, truncate(text, area.width, options: buffer.textWidthOptions()), style: style)
        }
    }

    private func resolvedStyle(toast: Toast, theme: ?Theme): Style {
        match ((toast.kind, theme)) {
            case (Some(kind), Some(currentTheme)) => semanticStyle(currentTheme, kind).patch(toast.style)
            case (Some(_), None) => Style(fg: Color.Black, bg: Color.Yellow).patch(toast.style)
            case _ => toast.style
        }
    }

    private func semanticStyle(currentTheme: Theme, kind: ToastKind): Style {
        match (kind) {
            case ToastKind.Success => currentTheme.success
            case ToastKind.Warning => currentTheme.warning
            case ToastKind.Error => currentTheme.error
            case ToastKind.Info => currentTheme.info
        }
    }

    private func marker(kind: ToastKind): String {
        match (kind) {
            case ToastKind.Success => "+"
            case ToastKind.Warning => "!"
            case ToastKind.Error => "x"
            case ToastKind.Info => "i"
        }
    }
}

/** 按指定帧显示“|”“/”“-”“\”之一，并可在其后显示标签；绘制本身不推进帧。
 */
public class Spinner <: Widget {
    private let label: String
    private let frame: Int64
    private let style: ?Style
    private let theme: ?Theme

    /** 创建旋转指示符。
     * @param label 可选标签
     * @param frame 帧序号，负值按零处理
     * @param style 可选样式
     * @param theme 可选语义主题
     */
    public init(label!: String = "", frame!: Int64 = 0, style!: ?Style = None, theme!: ?Theme = None) {
        this.label = label
        this.frame = max(0, frame)
        this.style = style
        this.theme = theme
    }

    /** 在区域左上角绘制指定帧和标签；绘制不会推进帧。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let frames = ["|", "/", "-", "\\"]
        let text = frames[frame % frames.size] + if (label.isEmpty()) { "" } else { " " + label }
        let resolved = widgetRoleStyle(style, buffer.resolveTheme(theme), ThemeRole.Accent, Style(fg: Color.Cyan))
        buffer.setString(area.x, area.y, truncate(text, area.width, options: buffer.textWidthOptions()), style: resolved)
    }
}

/** 带标题、正文和按钮的居中对话框。
 */
public class Dialog <: Widget {
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private let title: String
    private let body: String
    private let buttons: Array<String>
    /** 当前按钮索引。
     */
    public var selected: Int64
    private let width: Int64
    private let height: Int64
    private let style: ?Style
    private let selectedStyle: ?Style
    private var theme: ?Theme = None
    private var renderedTheme: ?Theme = None

    /** 创建对话框。
     * @param title 标题
     * @param body 正文
     * @param buttons 按钮文本
     * @param selected 初始按钮索引
     * @param width 目标宽度，至少为四
     * @param height 目标高度，至少为四
     * @param style 可选正文样式
     * @param selectedStyle 可选选中样式
     * @param theme 可选语义主题
     */
    public init(
        title!: String = "",
        body!: String = "",
        buttons!: Array<String> = ["OK"],
        selected!: Int64 = 0,
        width!: Int64 = 40,
        height!: Int64 = 7,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        theme!: ?Theme = None
    ) {
        this.title = title
        this.body = body
        this.buttons = buttons
        this.selected = clamp(selected, 0, max(0, buttons.size - 1))
        this.width = max(4, width)
        this.height = max(4, height)
        this.style = style
        this.selectedStyle = selectedStyle
        this.theme = theme
    }
    /** 设置或清除主题。
     * @param theme 主题；None 表示清除
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    /** 处理左右键及回车。
     * @param key 键盘事件
     * @return 回车且存在按钮时返回选中按钮文本，否则返回 None。
     */
    public func handle(key: KeyEvent): ?String {
        normalizeSelected()
        match (key.code) {
            case KeyCode.Left =>
                selected = max(0, selected - 1)
                None
            case KeyCode.Right =>
                selected = min(max(0, buttons.size - 1), selected + 1)
                None
            case KeyCode.Enter =>
                if (buttons.size > 0) { Some(buttons[selected]) } else { None }
            case _ => None
        }
    }

    /** 处理鼠标点击按钮。
     * @param mouse 鼠标事件
     * @param area 对话框所在区域
     * @return 命中按钮时返回文本，否则返回 None。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        normalizeSelected()
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) => ()
            case _ => return None
        }
        let actualWidth = min(width, area.width)
        let actualHeight = min(height, area.height)
        let outer = Rect(area.x + max(0, (area.width - actualWidth) / 2),
            area.y + max(0, (area.height - actualHeight) / 2), actualWidth, actualHeight)
        let inner = controlBlockArea(outer, Some(Block(title: title)), theme, None, renderedTheme)
        if (!widgetHitTest(mouse, inner) || mouse.y != outer.bottom - 2) { return None }
        var x = inner.x
        for (i in 0..buttons.size) {
            let width = displayWidth("[" + buttons[i] + "]", options: textWidthOptionsValue)
            if (mouse.x >= x && mouse.x - x < width) { selected = i; return Some(buttons[i]) }
            x += width + 1
        }
        None
    }

    /** 在区域内居中绘制对话框。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        textWidthOptionsValue = buffer.textWidthOptions()
        renderedTheme = buffer.resolveTheme(None)
        normalizeSelected()
        let actualWidth = min(width, area.width)
        let actualHeight = min(height, area.height)
        if (actualWidth <= 0 || actualHeight <= 0) { return }
        let x = area.x + max(0, (area.width - actualWidth) / 2)
        let y = area.y + max(0, (area.height - actualHeight) / 2)
        let dialogArea = Rect(x, y, actualWidth, actualHeight)
        let renderTheme = buffer.resolveTheme(theme)
        let renderStyle = widgetRoleStyle(style, renderTheme, ThemeRole.Normal, Style.default())
        let renderSelectedStyle = match (selectedStyle) {
            case Some(value) => if (value == Style.default() && renderTheme.isSome()) { themedSelected(value, renderTheme) } else { value }
            case None => widgetRoleStyle(Option<Style>.None, renderTheme, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White))
        }
        let block = Block(title: title, style: renderStyle)
        buffer.withParentTheme(theme) { => block.render(dialogArea, buffer) }
        let inner = block.inner(dialogArea)
        if (inner.width <= 0 || inner.height <= 0) { return }
        buffer.withParentTheme(theme) { =>
            Paragraph(body, wrap: WrapMode.Word, style: renderStyle).render(Rect(inner.x, inner.y, inner.width, max(0, inner.height - 1)), buffer)
        }
        var bx = inner.x
        let by = dialogArea.bottom - 2
        if (by < inner.y || by >= inner.bottom) { return }
        for (i in 0..buttons.size) {
            if (bx >= inner.right) { return }
            let label = "[" + buttons[i] + "]"
            buffer.setString(bx, by, truncate(label, inner.right - bx, options: textWidthOptionsValue), style: if (i == selected) { renderSelectedStyle } else { renderStyle })
            bx += displayWidth(label, options: textWidthOptionsValue) + 1
        }
    }
    private func normalizeSelected(): Unit {
        selected = clamp(selected, 0, max(0, buttons.size - 1))
    }
}

/** 带 No 和 Yes 选项的确认对话框。
 */
public class ConfirmDialog <: Widget {
    private let dialog: Dialog
    /** 当前是否选择 Yes。
     */
    public var confirmed: Bool = false

    /** 创建确认对话框。
     * @param message 提示文本
     * @param style 可选样式
     * @param selectedStyle 可选选中样式
     * @param theme 可选主题
     */
    public init(
        message: String,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        theme!: ?Theme = None
    ) {
        this.dialog = Dialog(
            title: "Confirm",
            body: message,
            buttons: ["No", "Yes"],
            style: style,
            selectedStyle: selectedStyle,
            theme: theme
        )
    }

    /** 设置或清除主题。
     * @param theme 主题；None 表示清除
     */
    public func setTheme(theme: ?Theme): Unit {
        dialog.setTheme(theme)
    }

    /** 处理方向键、y、n、回车和 Escape。
     * @param key 键盘事件
     * @return 确认或取消时返回布尔值，其他按键返回 None。
     */
    public func handle(key: KeyEvent): ?Bool {
        dialog.selected = if (confirmed) { 1 } else { 0 }
        match (key.code) {
            case KeyCode.Left =>
                _ = dialog.handle(key)
                confirmed = dialog.selected == 1
                None
            case KeyCode.Right =>
                _ = dialog.handle(key)
                confirmed = dialog.selected == 1
                None
            case KeyCode.Char(r'y') => confirmed = true; Some(true)
            case KeyCode.Enter => Some(confirmed)
            case KeyCode.Char(r'n') | KeyCode.Esc => confirmed = false; Some(false)
            case _ => None
        }
    }

    /** 处理鼠标点击 No 或 Yes。
     * @param mouse 鼠标事件
     * @param area 对话框所在区域
     * @return 命中时返回选择结果，否则返回 None。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?Bool {
        dialog.selected = if (confirmed) { 1 } else { 0 }
        match (dialog.handleMouse(mouse, area)) {
            case Some("No") => confirmed = false; Some(false)
            case Some("Yes") => confirmed = true; Some(true)
            case _ => None
        }
    }

    /** 绘制当前确认选择。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        dialog.selected = if (confirmed) { 1 } else { 0 }
        dialog.render(area, buffer)
    }
}
