package core

import std.collection.*
import std.unicode.*

public class MenuItem {
    public let label: String
    public let action: String
    public let enabled: Bool

    public init(label: String, action!: String = "", enabled!: Bool = true) {
        this.label = label
        this.action = if (action.isEmpty()) { label } else { action }
        this.enabled = enabled
    }
}

public class Menu <: Widget {
    private let title: String
    private let items: Array<MenuItem>
    public var selected: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let block: ?Block
    private let style: Style
    private let selectedStyle: Style
    private let disabledStyle: Style

    public init(
        title: String,
        items: Array<MenuItem>,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style(fg: Color.Indexed(8))
    ) {
        this.title = title
        this.items = items
        this.selected = clamp(selected, 0, max(0, items.size - 1))
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.disabledStyle = disabledStyle
    }

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

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        } else if (!title.isEmpty()) {
            buffer.setString(area.x, area.y, truncate(title, area.width), style: style)
            target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
        }
        viewportHeight = max(1, target.height)
        selected = clamp(selected, 0, max(0, items.size - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        for (row in 0..min(target.height, items.size - offset)) {
            let index = offset + row
            let item = items[index]
            let rowStyle = if (!item.enabled) {
                disabledStyle
            } else if (index == selected) {
                selectedStyle
            } else {
                style
            }
            buffer.setString(target.x, target.y + row, truncate(item.label, target.width), style: rowStyle)
        }
    }
}

public class MenuBar <: Widget {
    private let menus: Array<String>
    public var selected: Int64
    private let style: Style
    private let selectedStyle: Style

    public init(
        menus: Array<String>,
        selected!: Int64 = 0,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White)
    ) {
        this.menus = menus
        this.selected = clamp(selected, 0, max(0, menus.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
    }

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

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (!widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                var x = area.x
                for (i in 0..menus.size) {
                    let width = displayWidth(" " + menus[i] + " ")
                    if (mouse.x >= x && mouse.x - x < width) { selected = i; return true }
                    x += width
                }
                false
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        var x = area.x
        for (i in 0..menus.size) {
            if (x >= area.right) { return }
            let label = " " + menus[i] + " "
            let rowStyle = if (i == selected) { selectedStyle } else { style }
            buffer.setString(x, area.y, truncate(label, area.right - x), style: rowStyle)
            x += displayWidth(label)
        }
    }
}

public class CommandPalette <: Widget {
    private let items: Array<MenuItem>
    public var query: String
    public var selected: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private var lastQuery: String = ""
    private let block: ?Block
    private let style: Style
    private let selectedStyle: Style
    private let disabledStyle: Style
    private var theme: ?Theme = None
    private let caseSensitive: Bool

    public init(
        items: Array<MenuItem>,
        query!: String = "",
        selected!: Int64 = 0,
        block!: ?Block = Some(Block(title: "Command")),
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
        disabledStyle!: Style = Style.default(),
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

    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    public func paste(text: String): Unit {
        query += text
        _ = synchronizeQuery()
    }

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

    public func render(area: Rect, buffer: Buffer): Unit {
        let rows = synchronizeQuery()
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let normalRowStyle = resolvedNormalStyle()
        buffer.fillLine(target.y, target.x, target.width, style: normalRowStyle)
        buffer.setString(target.x, target.y, truncate("> " + query, target.width), style: normalRowStyle)
        let contentHeight = max(0, target.height - 1)
        viewportHeight = max(1, contentHeight)
        offset = selectionViewportOffset(offset, selected, rows.size, contentHeight)
        for (row in 0..contentHeight) {
            let y = target.y + 1 + row
            if (rows.isEmpty() && row == 0) {
                let emptyStyle = resolvedDisabledStyle()
                buffer.fillLine(y, target.x, target.width, style: emptyStyle)
                buffer.setString(target.x, y, truncate("No matches", target.width), style: emptyStyle)
            } else if (row < rows.size - offset) {
                let index = offset + row
                let item = rows[index]
                let rowStyle = resolvedRowStyle(item, index)
                buffer.fillLine(y, target.x, target.width, style: rowStyle)
                buffer.setString(target.x, y, truncate(item.label, target.width), style: rowStyle)
            } else {
                buffer.fillLine(y, target.x, target.width, style: normalRowStyle)
            }
        }
    }

    private func clampSelection(): Unit {
        selected = clamp(selected, 0, max(0, filtered().size - 1))
    }

    private func resolvedNormalStyle(): Style {
        themedNormal(style, theme)
    }

    private func resolvedSelectedStyle(): Style {
        if (selectedStyle == Style.default()) { themedSelected(selectedStyle, theme) } else { selectedStyle }
    }

    private func resolvedDisabledStyle(): Style {
        if (theme.isSome() || disabledStyle != Style.default()) {
            themedDisabled(disabledStyle, theme)
        } else {
            Style(fg: Color.Indexed(8))
        }
    }

    private func resolvedRowStyle(item: MenuItem, index: Int64): Style {
        if (!item.enabled) {
            resolvedDisabledStyle()
        } else if (index == selected) {
            resolvedSelectedStyle()
        } else {
            resolvedNormalStyle()
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

public enum ToastKind {
    | Success
    | Warning
    | Error
    | Info
}

public class Toast {
    public let message: String
    public let ttl: Int64
    public let style: Style
    public let kind: ?ToastKind

    public init(message: String, ttl!: Int64 = 3, style!: Style = Style(fg: Color.Black, bg: Color.Yellow)) {
        this.message = message
        this.ttl = max(0, ttl)
        this.style = style
        this.kind = None
    }

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

public class ToastManager <: Widget {
    private let toasts = ArrayList<Toast>()
    private let maxToasts: ?Int64
    private var theme: ?Theme

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

    public func push(toast: Toast): Unit {
        if (toast.ttl <= 0) { return }
        if (let Some(limit) <- maxToasts) {
            if (limit == 0) { return }
            if (toasts.size >= limit) { toasts.remove(at: 0) }
        }
        toasts.add(toast)
    }

    public func count(): Int64 {
        toasts.size
    }

    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

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

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let rows = min(area.height, toasts.size)
        for (i in 0..rows) {
            let toast = toasts[toasts.size - rows + i]
            let y = area.y + i
            let style = resolvedStyle(toast)
            let text = match (toast.kind) {
                case Some(kind) => marker(kind) + " " + toast.message
                case None => toast.message
            }
            buffer.fillLine(y, area.x, area.width, style: style)
            buffer.setString(area.x, y, truncate(text, area.width), style: style)
        }
    }

    private func resolvedStyle(toast: Toast): Style {
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
    private let style: Style

    /** 创建带标签、帧序号和样式的旋转指示符；负帧序号按 0 保存。
     */
    public init(label!: String = "", frame!: Int64 = 0, style!: Style = Style(fg: Color.Cyan)) {
        this.label = label
        this.frame = max(0, frame)
        this.style = style
    }

    /** 在区域左上角绘制由帧序号选出的符号及非空标签，文字按区域宽度截断；宽或高不为正时不绘制。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let frames = ["|", "/", "-", "\\"]
        let text = frames[frame % frames.size] + if (label.isEmpty()) { "" } else { " " + label }
        buffer.setString(area.x, area.y, truncate(text, area.width), style: style)
    }
}

public class Dialog <: Widget {
    private let title: String
    private let body: String
    private let buttons: Array<String>
    public var selected: Int64
    private let width: Int64
    private let height: Int64
    private let style: Style
    private let selectedStyle: Style
    private var theme: ?Theme = None

    public init(
        title!: String = "",
        body!: String = "",
        buttons!: Array<String> = ["OK"],
        selected!: Int64 = 0,
        width!: Int64 = 40,
        height!: Int64 = 7,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
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
    /** 设置对话框使用的语义主题；None 保持未启用主题时的样式。
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

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
        let inner = Block(title: title).inner(outer)
        if (!widgetHitTest(mouse, inner) || mouse.y != outer.bottom - 2) { return None }
        var x = inner.x
        for (i in 0..buttons.size) {
            let width = displayWidth("[" + buttons[i] + "]")
            if (mouse.x >= x && mouse.x - x < width) { selected = i; return Some(buttons[i]) }
            x += width + 1
        }
        None
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        normalizeSelected()
        let actualWidth = min(width, area.width)
        let actualHeight = min(height, area.height)
        if (actualWidth <= 0 || actualHeight <= 0) { return }
        let x = area.x + max(0, (area.width - actualWidth) / 2)
        let y = area.y + max(0, (area.height - actualHeight) / 2)
        let dialogArea = Rect(x, y, actualWidth, actualHeight)
        let renderStyle = themedNormal(style, theme)
        let renderSelectedStyle = if (theme.isSome() && selectedStyle == Style.default()) {
            themedSelected(selectedStyle, theme)
        } else {
            selectedStyle
        }
        let block = Block(title: title, style: renderStyle)
        block.render(dialogArea, buffer)
        let inner = block.inner(dialogArea)
        if (inner.width <= 0 || inner.height <= 0) { return }
        Paragraph(body, wrap: WrapMode.Word, style: renderStyle).render(Rect(inner.x, inner.y, inner.width, max(0, inner.height - 1)), buffer)
        var bx = inner.x
        let by = dialogArea.bottom - 2
        for (i in 0..buttons.size) {
            if (bx >= inner.right) { return }
            let label = "[" + buttons[i] + "]"
            buffer.setString(bx, by, truncate(label, inner.right - bx), style: if (i == selected) { renderSelectedStyle } else { renderStyle })
            bx += displayWidth(label) + 1
        }
    }
    private func normalizeSelected(): Unit {
        selected = clamp(selected, 0, max(0, buttons.size - 1))
    }
}

public class ConfirmDialog <: Widget {
    private let dialog: Dialog
    public var confirmed: Bool = false

    public init(
        message: String,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style(fg: Color.Black, bg: Color.White),
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

    /** 设置确认提示使用的语义主题；None 清除主题。
     */
    public func setTheme(theme: ?Theme): Unit {
        dialog.setTheme(theme)
    }

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

    /** 仅左键按下并命中“No”或“Yes”标签时返回对应布尔结果；其余鼠标事件返回 None。
     */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?Bool {
        dialog.selected = if (confirmed) { 1 } else { 0 }
        match (dialog.handleMouse(mouse, area)) {
            case Some("No") => confirmed = false; Some(false)
            case Some("Yes") => confirmed = true; Some(true)
            case _ => None
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        dialog.selected = if (confirmed) { 1 } else { 0 }
        dialog.render(area, buffer)
    }
}
