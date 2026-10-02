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
        let text = truncate(label, target.width)
        let x = alignedX(target, displayWidth(text), TextAlign.Center)
        buffer.setString(x, target.y, text, style: rowStyle)
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
            let rowStyle = if (disabled) {
                themedDisabled(disabledStyle, theme)
            } else if (active) {
                themedSelected(selectedStyle, theme)
            } else if (focused) {
                themedFocused(focusedStyle, theme)
            } else {
                themedNormal(style, theme)
            }
            buffer.setString(target.x, target.y + i, truncate(mark + items[index], target.width), style: rowStyle)
        }
    }
}

public class Select <: Widget {
    private let items: Array<String>
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

    public func selectedValue(): ?String {
        if (selected >= 0 && selected < items.size) { Some(items[selected]) } else { None }
    }

    public func handle(key: KeyEvent): ?String {
        if (!open) {
            match (key.code) {
                case KeyCode.Enter | KeyCode.Char(r' ') =>
                    open = true
                    None
                case _ => None
            }
        } else {
            if (let Some(index) <- selectionNavigation(key, selected, items.size, viewportHeight)) {
                selected = index
                return None
            }
            match (key.code) {
                case KeyCode.Esc =>
                    open = false
                    None
                case KeyCode.Up =>
                    selected = max(0, selected - 1)
                    None
                case KeyCode.Down =>
                    selected = min(max(0, items.size - 1), selected + 1)
                    None
                case KeyCode.Enter | KeyCode.Char(r' ') =>
                    open = false
                    selectedValue()
                case _ => None
            }
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): ?String {
        if (!widgetHitTest(mouse, area)) { return None }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                if (mouse.y == area.y) { open = !open; return None }
            case _ => ()
        }
        if (!open) { return None }
        let target = Rect(area.x, area.y + 1, area.width, max(0, area.height - 1))
        offset = selectionViewportOffset(offset, selected, items.size, target.height)
        if (let Some(index) <- selectionMouse(mouse, target, offset, items.size, selected)) {
            selected = index
            if (mouseScrollDelta(mouse) == 0) { open = false; return selectedValue() }
        }
        None
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let current = match (selectedValue()) {
            case Some(value) => value
            case None => placeholder
        }
        let mark = if (open) { "v " } else { "> " }
        buffer.setString(area.x, area.y, truncate(mark + current, area.width), style: style)
        if (open && area.height > 1) {
            viewportHeight = max(1, area.height - 1)
            let select = Select(items, selected: selected, style: style, selectedStyle: selectedStyle)
            select.offset = offset
            select.render(Rect(area.x, area.y + 1, area.width, area.height - 1), buffer)
            selected = select.selected
            offset = select.offset
        }
    }
}

public class ColorPicker <: Widget {
    private let colors: Array<Color>
    public var selected: Int64

    public init(colors!: Array<Color> = [Color.Red, Color.Green, Color.Yellow, Color.Blue, Color.Magenta, Color.Cyan], selected!: Int64 = 0) {
        this.colors = colors
        this.selected = clamp(selected, 0, max(0, colors.size - 1))
    }

    public func selectedColor(): ?Color {
        if (selected >= 0 && selected < colors.size) { Some(colors[selected]) } else { None }
    }

    public func handle(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.Left => selected = max(0, selected - 1); true
            case KeyCode.Right => selected = min(max(0, colors.size - 1), selected + 1); true
            case _ => false
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): Bool {
        if (!widgetHitTest(mouse, area) || mouse.y != area.y) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                let column = mouse.x - area.x
                let index = column / 3
                if (column % 3 == 2 || index >= colors.size) { return false }
                selected = index
                true
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        var x = area.x
        for (i in 0..colors.size) {
            if (x >= area.right) { return }
            let style = if (i == selected) { Style(fg: Color.Black, bg: colors[i]) } else { Style(fg: colors[i]) }
            _ = buffer.writeStringClipped(x, area.y, "##", maxWidth: area.right - x, style: style)
            x += 3
        }
    }
}

public class MultiSelect <: Widget {
    private let items: Array<String>
    private let selectedItems = ArrayList<Int64>()
    public var cursor: Int64
    public var offset: Int64 = 0
    private var viewportHeight: Int64 = 1
    private let style: Style
    private let selectedStyle: Style

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

    public init(year!: Int64 = 2026, month!: Int64 = 1, day!: Int64 = 1) {
        this.year = max(1, year)
        this.month = clamp(month, 1, 12)
        this.day = clamp(day, 1, datePickerDaysInMonth(this.year, this.month))
    }

    public func value(): String { "${year}-${pad2(month)}-${pad2(day)}" }

    public func handle(key: KeyEvent): Bool {
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
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.setString(area.x, area.y, truncate(value(), area.width), style: Style(fg: Color.Cyan))
    }
}

func datePickerDaysInMonth(year: Int64, month: Int64): Int64 {
    match (month) {
        case 2 => if (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)) { 29 } else { 28 }
        case 4 | 6 | 9 | 11 => 30
        case _ => 31
    }
}
