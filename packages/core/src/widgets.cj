package core

import std.collection.*

public enum BorderKind {
    | Auto
    | Ascii
    | Unicode
    | Rounded
    /** 双线 Unicode 边框。 */
    | Double
    /** 使用 Unicode 虚线边及直角连接符。 */
    | Dashed
    | NoBorder
}

public enum TitleAlign {
    | Left
    | Center
    | Right
}

public enum BoxState {
    | Normal
    | Focused
    | Active
    | Error
    | Disabled
}

public class BorderSet {
    public let horizontal: String
    public let vertical: String
    public let topLeft: String
    public let topRight: String
    public let bottomLeft: String
    public let bottomRight: String

    public init(
        horizontal!: String = "-",
        vertical!: String = "|",
        topLeft!: String = "+",
        topRight!: String = "+",
        bottomLeft!: String = "+",
        bottomRight!: String = "+"
    ) {
        this.horizontal = horizontal
        this.vertical = vertical
        this.topLeft = topLeft
        this.topRight = topRight
        this.bottomLeft = bottomLeft
        this.bottomRight = bottomRight
    }

    public static func ascii(): BorderSet {
        BorderSet()
    }

    public static func unicode(): BorderSet {
        BorderSet(horizontal: "─", vertical: "│", topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘")
    }

    public static func rounded(): BorderSet {
        BorderSet(horizontal: "─", vertical: "│", topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯")
    }

    public static func doubleLine(): BorderSet {
        BorderSet(horizontal: "═", vertical: "║", topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝")
    }

    public static func dashed(): BorderSet {
        BorderSet(horizontal: "┄", vertical: "┆", topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘")
    }
}

public class BlockOptions {
    public let title: String
    public let borderKind: BorderKind
    public let border: BorderSet
    public let titleAlign: TitleAlign
    public let padding: Spacing
    public let margin: Spacing
    public let backgroundStyle: Style
    public let borderStyle: Style
    public let contentStyle: Style
    public let titleStyle: Style
    let hasBackgroundStyle: Bool
    let hasBorderStyle: Bool
    let hasContentStyle: Bool
    let hasTitleStyle: Bool
    public let state: BoxState
    public let asciiFallback: Bool
    public let theme: ?Theme

    public init(
        title!: String = "",
        borderKind!: BorderKind = BorderKind.Auto,
        border!: BorderSet = BorderSet(horizontal: "", vertical: "", topLeft: "", topRight: "", bottomLeft: "", bottomRight: ""),
        titleAlign!: TitleAlign = TitleAlign.Left,
        padding!: Spacing = Spacing.zero(),
        margin!: Spacing = Spacing.zero(),
        backgroundStyle!: ?Style = None,
        borderStyle!: ?Style = None,
        contentStyle!: ?Style = None,
        titleStyle!: ?Style = None,
        state!: BoxState = BoxState.Normal,
        asciiFallback!: Bool = false,
        theme!: ?Theme = None
    ) {
        this.title = title
        this.borderKind = borderKind
        this.border = border
        this.titleAlign = titleAlign
        this.padding = padding
        this.margin = margin
        this.hasBackgroundStyle = backgroundStyle.isSome()
        this.hasBorderStyle = borderStyle.isSome()
        this.hasContentStyle = contentStyle.isSome()
        this.hasTitleStyle = titleStyle.isSome()
        this.backgroundStyle = match (backgroundStyle) { case Some(value) => value; case None => Style.default() }
        this.borderStyle = match (borderStyle) { case Some(value) => value; case None => Style.default() }
        this.contentStyle = match (contentStyle) { case Some(value) => value; case None => Style.default() }
        this.titleStyle = match (titleStyle) { case Some(value) => value; case None => Style.default() }
        this.state = state
        this.asciiFallback = asciiFallback
        this.theme = theme
    }
}

public class Block <: Widget {
    private let options: BlockOptions
    private var inheritedTheme: ?Theme = None

    public init(title!: String = "", style!: ?Style = None) {
        this.options = BlockOptions(title: title, borderStyle: style, titleStyle: style)
    }

    public init(options: BlockOptions) {
        this.options = options
    }

    // Panel uses the block's explicit theme as the default for its child.
    func explicitTheme(): ?Theme { options.theme }

    /** 根据最近一次绘制时的主题计算内容区域；尚未绘制时使用区块显式主题和默认值。
     */
    public func inner(area: Rect): Rect {
        contentArea(frameArea(area))
    }

    /** 绘制前可显式提供应用主题以计算内容区域；区块自身的显式主题优先。 */
    public func inner(area: Rect, theme!: ?Theme): Rect {
        contentAreaForTheme(frameArea(area), resolveBlockTheme(theme))
    }

    public func renderInner(area: Rect, buffer: Buffer): Rect {
        inheritedTheme = buffer.resolveTheme(None)
        let frame = frameArea(area)
        if (frame.width <= 0 || frame.height <= 0) { return Rect(frame.x, frame.y, 0, 0) }
        buffer.withCanvasClip(frame) { => renderFrame(frame, buffer) }
        contentArea(frame)
    }

    private func renderFrame(frame: Rect, buffer: Buffer): Unit {
        let background = resolvedBoxBackground(buffer)
        if (options.hasBackgroundStyle || background != Style.default()) {
            buffer.fill(frame, style: background)
        }
        if (!isBorderNone(effectiveBorderKind())) {
            renderBorder(frame, buffer)
            renderTitle(frame, buffer)
        }
        let content = contentArea(frame)
        if (content.width > 0 && content.height > 0 && options.hasContentStyle) {
            buffer.fill(content, style: options.contentStyle)
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        _ = renderInner(area, buffer)
    }

    private func frameArea(area: Rect): Rect {
        options.margin.inner(area)
    }

    private func contentArea(frame: Rect): Rect {
        contentAreaForTheme(frame, resolveBlockTheme(inheritedTheme))
    }

    private func contentAreaForTheme(frame: Rect, theme: ?Theme): Rect {
        let borderInset = if (isBorderNone(effectiveBorderKind(theme))) { Int64(0) } else { Int64(1) }
        options.padding.inner(Rect(
            frame.x + borderInset,
            frame.y + borderInset,
            frame.width - borderInset * 2,
            frame.height - borderInset * 2
        ))
    }

    private func renderBorder(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let border = resolvedBorder(buffer)
        let style = resolvedBoxBorder(buffer)
        if (area.height == 1) {
            _ = buffer.writeStringClipped(area.x, area.y, repeat(border.horizontal, area.width), maxWidth: area.width, style: style)
            return
        }
        if (area.width == 1) {
            for (y in area.y..area.bottom) {
                _ = buffer.writeStringClipped(area.x, y, border.vertical, maxWidth: 1, style: style)
            }
            return
        }
        _ = buffer.writeStringClipped(area.x, area.y, repeat(border.horizontal, area.width), maxWidth: area.width, style: style)
        _ = buffer.writeStringClipped(area.x, area.bottom - 1, repeat(border.horizontal, area.width), maxWidth: area.width, style: style)
        if (area.width > 1) {
            for (y in area.y + 1..area.bottom - 1) {
                _ = buffer.writeStringClipped(area.x, y, border.vertical, maxWidth: 1, style: style)
                _ = buffer.writeStringClipped(area.right - 1, y, border.vertical, maxWidth: 1, style: style)
            }
            _ = buffer.writeStringClipped(area.x, area.y, border.topLeft, maxWidth: 1, style: style)
            _ = buffer.writeStringClipped(area.right - 1, area.y, border.topRight, maxWidth: 1, style: style)
            _ = buffer.writeStringClipped(area.x, area.bottom - 1, border.bottomLeft, maxWidth: 1, style: style)
            _ = buffer.writeStringClipped(area.right - 1, area.bottom - 1, border.bottomRight, maxWidth: 1, style: style)
        }
    }

    private func renderTitle(area: Rect, buffer: Buffer): Unit {
        if (options.title.isEmpty() || area.width <= 4) { return }
        let text = truncate(options.title, max(0, area.width - 4), options: buffer.textWidthOptions())
        let width = displayWidthFast(text, options: buffer.textWidthOptions())
        let x = match (options.titleAlign) {
            case TitleAlign.Left => area.x + 2
            case TitleAlign.Center => area.x + max(1, (area.width - width) / 2)
            case TitleAlign.Right => area.right - width - 2
        }
        buffer.setString(max(area.x + 1, min(x, area.right - width - 1)), area.y, text, style: resolvedBoxTitle(buffer))
    }

    private func resolvedBorder(buffer: Buffer): BorderSet {
        if (options.asciiFallback) { return BorderSet.ascii() }
        let border = options.border
        if (!border.horizontal.isEmpty() || !border.vertical.isEmpty() ||
            !border.topLeft.isEmpty() || !border.topRight.isEmpty() ||
            !border.bottomLeft.isEmpty() || !border.bottomRight.isEmpty()) {
            return border
        }
        // Single-cell Unicode borders cannot be represented when ambiguous characters are wide.
        if (usesWideAmbiguous(buffer.textWidthOptions())) { return BorderSet.ascii() }
        // A theme supplies the application default; honor the terminal's
        // Unicode capability unless the component explicitly chose a kind.
        match (options.borderKind) {
            case BorderKind.Auto => if (!buffer.capabilities().unicode) { return BorderSet.ascii() }
            case _ => ()
        }
        match (effectiveBorderKind()) {
            case BorderKind.Auto => if (buffer.capabilities().unicode) { BorderSet.rounded() } else { BorderSet.ascii() }
            case BorderKind.Ascii => BorderSet.ascii()
            case BorderKind.Unicode => BorderSet.unicode()
            case BorderKind.Rounded => BorderSet.rounded()
            case BorderKind.Double => BorderSet.doubleLine()
            case BorderKind.Dashed => BorderSet.dashed()
            case BorderKind.NoBorder => BorderSet.ascii()
        }
    }

    private func resolveBlockTheme(theme: ?Theme): ?Theme {
        match (options.theme) { case Some(value) => Some(value); case None => theme }
    }

    private func effectiveBorderKind(): BorderKind {
        effectiveBorderKind(resolveBlockTheme(inheritedTheme))
    }

    private func effectiveBorderKind(theme: ?Theme): BorderKind {
        match (options.borderKind) {
            case BorderKind.Auto =>
                let border = options.border
                if (!border.horizontal.isEmpty() || !border.vertical.isEmpty() ||
                    !border.topLeft.isEmpty() || !border.topRight.isEmpty() ||
                    !border.bottomLeft.isEmpty() || !border.bottomRight.isEmpty()) {
                    BorderKind.Auto
                } else {
                    match (theme) {
                        case Some(value) => value.borderKind
                        case None => BorderKind.Auto
                    }
                }
            case _ => options.borderKind
        }
    }

    private func resolvedBoxBackground(buffer: Buffer): Style {
        if (options.hasBackgroundStyle) { return options.backgroundStyle }
        match (buffer.resolveTheme(options.theme)) { case Some(theme) => theme.canvas; case None => Style.default() }
    }

    private func resolvedBoxBorder(buffer: Buffer): Style {
        if (options.hasBorderStyle) { return options.borderStyle }
        match (buffer.resolveTheme(options.theme)) {
            case Some(theme) => match (options.state) {
                case BoxState.Normal => theme.border
                case BoxState.Focused | BoxState.Active => theme.strongBorder
                case BoxState.Error => theme.error
                case BoxState.Disabled => theme.disabled
            }
            case None => Style.default()
        }
    }

    private func resolvedBoxTitle(buffer: Buffer): Style {
        if (options.hasTitleStyle) { return options.titleStyle }
        match (buffer.resolveTheme(options.theme)) { case Some(theme) => theme.heading; case None => Style.default() }
    }

}

public class Panel <: Widget {
    private let block: Block
    private let child: ?Widget

    public init(block!: Block = Block(), child!: ?Widget = None) {
        this.block = block
        this.child = child
    }

    public init(options: BlockOptions, child!: ?Widget = None) {
        this.block = Block(options)
        this.child = child
    }

    public func renderInner(area: Rect, buffer: Buffer): Rect {
        let inner = block.renderInner(area, buffer)
        match (child) {
            case Some(w) => buffer.withParentTheme(block.explicitTheme()) { => w.render(inner, buffer) }
            case None => ()
        }
        inner
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        _ = renderInner(area, buffer)
    }
}

public class Paragraph <: Widget {
    private let text: String
    private let block: ?Block
    private let style: ?Style
    private let scroll: Int64
    private let wrap: WrapMode
    private let align: TextAlign

    /** 保存段落文本与绘制设置；负数滚动行数按零处理。省略样式时使用应用主题的正文样式，显式样式优先。
     */
    public init(
        text: String,
        block!: ?Block = None,
        style!: ?Style = None,
        scroll!: Int64 = 0,
        wrap!: WrapMode = WrapMode.Character,
        align!: TextAlign = TextAlign.Left
    ) {
        this.text = text
        this.block = block
        this.style = style
        this.scroll = max(0, scroll)
        this.wrap = wrap
        this.align = align
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
        if (target.width <= 0 || target.height <= 0) { return }
        let normalStyle = match (style) {
            case Some(value) => value
            case None => match (buffer.resolveTheme(None)) { case Some(value) => value.normal; case None => Style.default() }
        }
        let lines = wrapText(text, target.width, wrap, options: buffer.textWidthOptions())
        var row: Int64 = 0
        while (row < target.height && row + scroll < lines.size) {
            let line = lines[row + scroll]
            let x = alignedX(target, displayWidth(line, options: buffer.textWidthOptions()), align)
            buffer.setString(x, target.y + row, truncate(line, target.width, options: buffer.textWidthOptions()), style: normalStyle)
            row++
        }
    }
}

// Event APIs have no Buffer. Prefer a component theme, then an explicitly
// supplied layout theme, then the context from this component's last render.
func controlBlockArea(area: Rect, block: ?Block, componentTheme: ?Theme,
    layoutTheme: ?Theme, renderedTheme: ?Theme): Rect {
    let effective = match (componentTheme) {
        case Some(value) => Some(value)
        case None => match (layoutTheme) { case Some(value) => Some(value); case None => renderedTheme }
    }
    match (block) { case Some(value) => value.inner(area, theme: effective); case None => area }
}

public class List <: Widget {
    private let items: Array<String>
    private let selected: ?Int64
    private let offset: Int64
    private let state: ?ListState
    private let block: ?Block
    private let style: Style
    private let selectedStyle: ?Style
    private let focused: Bool
    private let theme: ?Theme
    private var renderedTheme: ?Theme = None
    private let selectionMarker: ?String

    public init(
        items: Array<String>,
        selected!: ?Int64 = None,
        offset!: Int64 = 0,
        state!: ?ListState = None,
        block!: ?Block = None,
        style!: Style = Style.default(),
        selectedStyle!: ?Style = None,
        focused!: Bool = false,
        theme!: ?Theme = None,
        selectionMarker!: ?String = None
    ) {
        this.items = items
        this.selected = selected
        this.offset = max(0, offset)
        this.state = state
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.focused = focused
        this.theme = theme
        this.selectionMarker = selectionMarker
    }

    /** 绘制前可传入应用布局主题；组件自身的显式主题及区块的显式主题优先。 */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool { handleMouse(mouse, area, layoutTheme: None) }

    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): Bool {
        let target = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        match (state) {
            case Some(value) =>
                let current = match (value.selected) { case Some(index) => index; case None => 0 }
                if (let Some(index) <- selectionMouse(mouse, target, value.offset, items.size, current)) {
                    value.selected = Some(index)
                    value.scrollToVisible(items.size, target.height)
                    return true
                }
            case None => ()
        }
        false
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let content = target
        buffer.withCanvasClip(content) { => renderRows(content, buffer) }
    }

    private func renderRows(target: Rect, buffer: Buffer): Unit {
        let rows = min(target.height, items.size)
        let renderOffset = match (state) {
            case Some(s) => max(0, s.offset)
            case None => offset
        }
        let renderSelected = match (state) {
            case Some(s) => s.selected
            case None => selected
        }
        let activeTheme = buffer.resolveTheme(theme)
        let marker = resolvedSelectionMarker(selectionMarker, activeTheme, buffer.capabilities())
        let markerColumns = min(target.width, displayWidth(marker, options: buffer.textWidthOptions()))
        let gap = if (markerColumns > 0) { Int64(1) } else { Int64(0) }
        for (i in 0..rows) {
            let itemIndex = i + renderOffset
            if (itemIndex >= items.size) { return }
            let active = match (renderSelected) {
                case Some(v) => v == itemIndex
                case None => false
            }
            var rowStyle = if (active) { listSelectionStyle(selectedStyle, activeTheme) } else { themedNormal(style, activeTheme) }
            if (active && focused) {
                var modifier = rowStyle.modifier
                modifier.bold = true
                modifier.underline = true
                rowStyle = rowStyle.withModifier(modifier)
            }
            buffer.fillRect(Rect(target.x, target.y + i, target.width, 1), style: rowFillStyle(rowStyle))
            if (active && markerColumns > 0) {
                if (focused) {
                    writeFocusedListText(target.x, target.y + i, marker, markerColumns, rowStyle, buffer)
                } else {
                    _ = buffer.writeStringClipped(target.x, target.y + i, marker, maxWidth: markerColumns, style: rowStyle)
                }
            }
            let prefixWidth = min(target.width, markerColumns + gap)
            if (active && focused) {
                writeFocusedListText(target.x + prefixWidth, target.y + i, items[itemIndex],
                    target.width - prefixWidth, rowStyle, buffer)
            } else {
                _ = buffer.writeStringClipped(target.x + prefixWidth, target.y + i, items[itemIndex],
                    maxWidth: target.width - prefixWidth, style: rowStyle)
            }
        }
    }
}

// Focus underlines should not join tree glyphs and labels across indentation.
// Preserve each whitespace grapheme and its width; only its underline changes.
func writeFocusedListText(x: Int64, y: Int64, text: String, width: Int64, style: Style, buffer: Buffer): Unit {
    var used: Int64 = 0
    var offset: Int64 = 0
    while (offset < text.size && used < width) {
        let next = nextGraphemeOffset(text, offset)
        let glyph = text[offset..next]
        let glyphWidth = graphemeDisplayWidth(glyph, options: buffer.textWidthOptions())
        offset = next
        if (glyphWidth <= 0) { continue }
        if (glyphWidth > width - used) { break }
        let whitespace = glyph == " " || glyph == "\u{00A0}" || glyph == "\u{3000}"
        let glyphStyle = if (whitespace) { rowFillStyle(style) } else { style }
        _ = buffer.writeStringClipped(x + used, y, glyph, maxWidth: width - used, style: glyphStyle)
        used += glyphWidth
    }
}

public class ListState {
    public var selected: ?Int64
    public var offset: Int64

    public init(selected!: ?Int64 = None, offset!: Int64 = 0) {
        this.selected = selected
        this.offset = max(0, offset)
    }

    public func select(index: ?Int64): Unit {
        selected = index
    }

    public func next(total: Int64): Unit {
        if (total <= 0) {
            selected = None
            offset = 0
            return
        }
        let current = match (selected) {
            case Some(v) => v
            case None => -1
        }
        selected = Some(min(total - 1, current + 1))
    }

    public func move(delta: Int64, total: Int64, viewportHeight!: Int64 = 0): Unit {
        if (total <= 0) {
            selected = None
            offset = 0
            return
        }
        let current = match (selected) {
            case Some(v) => v
            case None => if (delta >= 0) { -1 } else { total }
        }
        selected = Some(clamp(current + delta, 0, total - 1))
        if (viewportHeight > 0) {
            scrollToVisible(total, viewportHeight)
        }
    }

    public func moveWithDirty(delta: Int64, total: Int64, viewportHeight: Int64, area: Rect): DirtyRects {
        let beforeSelected = selected
        let beforeOffset = offset
        move(delta, total, viewportHeight: viewportHeight)
        let dirty = DirtyRects()
        if (beforeOffset != offset) {
            dirty.add(area)
            return dirty
        }
        addListRowDirty(dirty, area, beforeSelected, offset)
        addListRowDirty(dirty, area, selected, offset)
        dirty
    }

    public func previous(total: Int64): Unit {
        if (total <= 0) {
            selected = None
            offset = 0
            return
        }
        let current = match (selected) {
            case Some(v) => v
            case None => total
        }
        selected = Some(max(0, current - 1))
    }

    public func scrollToVisible(total: Int64, viewportHeight: Int64): Unit {
        if (total <= 0 || viewportHeight <= 0) {
            offset = 0
            return
        }
        let current = match (selected) {
            case Some(v) => clamp(v, 0, total - 1)
            case None => 0
        }
        if (current < offset) {
            offset = current
        } else if (current >= offset + viewportHeight) {
            offset = current - viewportHeight + 1
        }
        offset = clamp(offset, 0, max(0, total - viewportHeight))
    }
}

public class Table <: Widget {
    private let headers: Array<String>
    private let rows: Array<Array<String>>
    private let widths: Array<Int64>
    private let state: ?TableState
    private let block: ?Block
    private let style: ?Style
    private let headerStyle: ?Style
    private let selectedStyle: ?Style
    private let focused: Bool
    private let theme: ?Theme
    private var renderedTheme: ?Theme = None
    private let selectionMarker: ?String

    /** 保存表头、数据行、列宽及绘制设置，用于后续表格绘制。
     * 省略 style 时普通数据行保留已有背景；显式样式沿用主题样式合并规则。
     * 省略 headerStyle 时使用主题标题样式，并保留表头与分隔线下方已有的背景；显式样式原样使用，包括重置背景色。
     */
    public init(
        headers: Array<String>,
        rows: Array<Array<String>>,
        widths!: Array<Int64> = [],
        state!: ?TableState = None,
        block!: ?Block = None,
        style!: ?Style = None,
        headerStyle!: ?Style = None,
        selectedStyle!: ?Style = None,
        focused!: Bool = false,
        theme!: ?Theme = None,
        selectionMarker!: ?String = None
    ) {
        this.headers = headers
        this.rows = rows
        this.widths = widths
        this.state = state
        this.block = block
        this.style = style
        this.headerStyle = headerStyle
        this.selectedStyle = selectedStyle
        this.focused = focused
        this.theme = theme
        this.selectionMarker = selectionMarker
    }

    /** 绘制前可传入应用布局主题；组件自身的显式主题及区块的显式主题优先。 */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool { handleMouse(mouse, area, layoutTheme: None) }

    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): Bool {
        let inner = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        let target = Rect(inner.x, inner.y + 2, inner.width, max(0, inner.height - 2))
        match (state) {
            case Some(value) =>
                let current = match (value.selectedRow) { case Some(index) => index; case None => 0 }
                if (let Some(index) <- selectionMouse(mouse, target, value.offset, rows.size, current)) {
                    value.selectedRow = Some(index)
                    value.scrollToVisible(rows.size, target.height)
                    return true
                }
            case None => ()
        }
        false
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let content = target
        buffer.withCanvasClip(content) { => renderRows(content, buffer) }
    }

    private func renderRows(target: Rect, buffer: Buffer): Unit {
        let activeTheme = buffer.resolveTheme(theme)
        let marker = resolvedSelectionMarker(selectionMarker, activeTheme, buffer.capabilities())
        let markerColumns = min(max(0, target.width - 1), displayWidth(marker, options: buffer.textWidthOptions()))
        let markerWidth: Int64 = if (state.isSome() && markerColumns > 0 && markerColumns + 1 < target.width) { markerColumns + 1 } else { 0 }
        let colWidths = resolvedWidths(target.width - markerWidth)
        let headerPaint = match (headerStyle) {
            case Some(explicit) => explicit
            case None => match (activeTheme) {
                case Some(value) => value.heading
                case None => Style(fg: Color.Yellow, modifier: Modifier.strong())
            }
        }
        let headerSurface: ?TableHeaderSurface = if (headerStyle.isNone()) {
            Some(TableHeaderSurface(Rect(target.x, target.y, target.width, min(Int64(2), target.height)), buffer))
        } else { None }
        renderRow(target.x + markerWidth, target.y, target.right, headers, colWidths, headerPaint, buffer,
            headerSurface: headerSurface)
        if (target.height > 1) {
            let line = if (buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { "─" } else { "-" }
            let text = repeat(line, target.width)
            match (headerSurface) {
                case Some(surface) => tableWriteOnExistingBackground(target.x, target.y + 1, text,
                    target.width, headerPaint, buffer, surface)
                case None => buffer.setString(target.x, target.y + 1, text, style: headerPaint)
            }
        }
        if (let Some(surface) <- headerSurface) { surface.restoreWideRepairs(buffer) }
        let rowLimit = min(rows.size, max(0, target.height - 2))
        let renderOffset = match (state) {
            case Some(s) => max(0, s.offset)
            case None => 0
        }
        let renderSelected: ?Int64 = match (state) {
            case Some(s) => s.selectedRow
            case None => None
        }
        for (i in 0..rowLimit) {
            let rowIndex = i + renderOffset
            if (rowIndex >= rows.size) { return }
            let active = match (renderSelected) {
                case Some(v) => v == rowIndex
                case None => false
            }
            let normalStyle = match (style) { case Some(value) => value; case None => Style.default() }
            var rowStyle = if (active) { listSelectionStyle(selectedStyle, activeTheme) } else { themedNormal(normalStyle, activeTheme) }
            if (active && focused) {
                var modifier = rowStyle.modifier
                modifier.bold = true
                modifier.underline = true
                rowStyle = rowStyle.withModifier(modifier)
            }
            let rowY = target.y + 2 + i
            let rowSurface: ?TableHeaderSurface = if (!active && style.isNone()) {
                Some(TableHeaderSurface(Rect(target.x, rowY, target.width, 1), buffer))
            } else { None }
            match (rowSurface) {
                case Some(surface) => tableWriteOnExistingBackground(target.x, rowY, repeat(" ", target.width),
                    target.width, rowFillStyle(rowStyle), buffer, surface)
                case None => buffer.fillRect(Rect(target.x, rowY, target.width, 1), style: rowFillStyle(rowStyle))
            }
            if (active && markerWidth > 0) {
                _ = buffer.writeStringClipped(target.x, rowY, marker, maxWidth: markerWidth - 1, style: rowStyle)
            }
            renderRow(target.x + markerWidth, rowY, target.right, rows[rowIndex], colWidths, rowStyle, buffer,
                headerSurface: rowSurface)
            if (let Some(surface) <- rowSurface) { surface.restoreWideRepairs(buffer) }
        }
    }

    private func resolvedWidths(total: Int64): Array<Int64> {
        if (widths.size > 0) {
            return widths
        }
        let cols = max(1, headers.size)
        let width = max(1, total / cols)
        Array<Int64>(cols, repeat: width)
    }

    private static func renderRow(
        x: Int64,
        y: Int64,
        right: Int64,
        cols: Array<String>,
        widths: Array<Int64>,
        style: Style,
        buffer: Buffer,
        headerSurface!: ?TableHeaderSurface = None
    ): Unit {
        var cx = x
        let limit = min(cols.size, widths.size)
        for (i in 0..limit) {
            if (cx >= right) { return }
            let width = max(0, widths[i])
            let visibleWidth = min(width, right - cx)
            let text = clippedWithEllipsis(cols[i], visibleWidth, buffer)
            let textWidth = displayWidth(text, options: buffer.textWidthOptions())
            if (text != cols[i] && textWidth < visibleWidth) {
                match (headerSurface) {
                    case Some(surface) => tableWriteOnExistingBackground(cx + textWidth, y,
                        repeat(" ", visibleWidth - textWidth), visibleWidth - textWidth, style, buffer, surface)
                    case None => buffer.fillRect(Rect(cx + textWidth, y, visibleWidth - textWidth, 1), style: style)
                }
            }
            match (headerSurface) {
                case Some(surface) => tableWriteOnExistingBackground(cx, y, text, visibleWidth, style, buffer, surface)
                case None => _ = buffer.writeStringClipped(cx, y, text, maxWidth: visibleWidth, style: style)
            }
            cx += width + 1
        }
    }

}

// Snapshot both rows before drawing: writing one half of an old wide glyph can
// repair the other half, so reading live backgrounds while drawing is unsafe.
class TableHeaderSurface {
    private let area: Rect
    private let cells: Array<Cell>

    init(area: Rect, buffer: Buffer) {
        let clipped = intersect(area, buffer.area)
        this.area = clipped
        this.cells = Array<Cell>(clipped.width * clipped.height, { i =>
            buffer.getCell(clipped.x + i % clipped.width, clipped.y + i / clipped.width)
        })
    }

    func background(x: Int64, y: Int64): Color {
        if (x < area.x || x >= area.right || y < area.y || y >= area.bottom) { return Color.Reset }
        cells[(y - area.y) * area.width + x - area.x].style.bg
    }

    func restoreWideRepairs(buffer: Buffer): Unit {
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                let original = cells[(y - area.y) * area.width + x - area.x]
                let wasWide = match (original.kind) { case CellKind.WideLead | CellKind.WideCont => true; case _ => false }
                if (!wasWide) { continue }
                let current = buffer.getCell(x, y)
                let blank = match (current.kind) { case CellKind.Normal => current.symbol == " "; case _ => false }
                if (blank && !colorEquals(current.style.bg, original.style.bg)) {
                    buffer.setCell(x, y, Cell(" ", style: current.style.withBg(original.style.bg)))
                }
            }
        }
    }
}

// A header without an explicit style inherits the captured surface below each glyph.
func tableWriteOnExistingBackground(x: Int64, y: Int64, text: String, maxWidth: Int64,
    style: Style, buffer: Buffer, surface: TableHeaderSurface): Unit {
    var column = x
    var used: Int64 = 0
    for (cluster in graphemeClusters(text, options: buffer.textWidthOptions())) {
        if (cluster.width <= 0) { continue }
        if (cluster.width > maxWidth - used) { break }
        let paint = style.withBg(surface.background(column, y))
        _ = buffer.writeStringClipped(column, y, cluster.text, maxWidth: cluster.width, style: paint)
        column += cluster.width
        used += cluster.width
    }
}

// Keep the truncation marker to one cell even on ASCII or wide-ambiguous terminals.
func clippedWithEllipsis(text: String, width: Int64, buffer: Buffer): String {
    if (width <= 0) { return "" }
    let options = buffer.textWidthOptions()
    let (prefixEnd, _, clipped) = ellipsisScan(text, width, options)
    if (!clipped) { return text }
    let marker = if (buffer.capabilities().unicode && displayWidth("…", options: options) == 1) { "…" } else { "." }
    text[0..prefixEnd] + marker
}

// Return the fitting prefix, consumed byte offset and whether the text overflowed.
func ellipsisScan(text: String, width: Int64, options: TextWidthOptions): (Int64, Int64, Bool) {
    var offset: Int64 = 0
    var used: Int64 = 0
    var prefixEnd: Int64 = 0
    while (offset < text.size) {
        let next = nextGraphemeOffset(text, offset)
        let clusterWidth = graphemeDisplayWidth(text[offset..next], options: options)
        if (clusterWidth > width - used) {
            return (prefixEnd, next, true)
        }
        used += clusterWidth
        offset = next
        if (used <= width - 1) { prefixEnd = offset }
    }
    (prefixEnd, offset, false)
}

// Explicit markers are application-owned. Built-in markers follow both the
// selected icon set and the terminal's Unicode capability.
func resolvedSelectionMarker(marker: ?String, theme: ?Theme, capabilities: TerminalCapabilities): String {
    match (marker) {
        case Some(value) => value
        case None =>
            if (!capabilities.unicode) { return "*" }
            let iconSet = match (theme) { case Some(value) => value.iconSet; case None => IconSet.Unicode }
            match (iconSet) {
                case IconSet.Ascii => "*"
                case IconSet.Unicode => "●"
                case IconSet.NerdFont => "\u{F111}"
            }
    }
}

// Underline is a text decoration: keep all other row style attributes on padding.
func rowFillStyle(style: Style): Style {
    var modifier = style.modifier
    modifier.underline = false
    style.withModifier(modifier)
}

// Preserve explicit selection styles while providing a visible default without a theme.
func listSelectionStyle(style: ?Style, theme: ?Theme): Style {
    match (style) {
        case Some(value) => value
        case None => match (theme) {
            case Some(value) => value.selected
            case None => Theme.default().selected
        }
    }
}

public class TableState {
    public var selectedRow: ?Int64
    public var offset: Int64

    public init(selectedRow!: ?Int64 = None, offset!: Int64 = 0) {
        this.selectedRow = selectedRow
        this.offset = max(0, offset)
    }

    public func select(index: ?Int64): Unit {
        selectedRow = index
    }

    public func next(total: Int64): Unit {
        if (total <= 0) {
            selectedRow = None
            offset = 0
            return
        }
        let current = match (selectedRow) {
            case Some(v) => v
            case None => -1
        }
        selectedRow = Some(min(total - 1, current + 1))
    }

    public func move(delta: Int64, total: Int64, viewportHeight!: Int64 = 0): Unit {
        if (total <= 0) {
            selectedRow = None
            offset = 0
            return
        }
        let current = match (selectedRow) {
            case Some(v) => v
            case None => if (delta >= 0) { -1 } else { total }
        }
        selectedRow = Some(clamp(current + delta, 0, total - 1))
        if (viewportHeight > 0) {
            scrollToVisible(total, viewportHeight)
        }
    }

    public func previous(total: Int64): Unit {
        if (total <= 0) {
            selectedRow = None
            offset = 0
            return
        }
        let current = match (selectedRow) {
            case Some(v) => v
            case None => total
        }
        selectedRow = Some(max(0, current - 1))
    }

    public func scrollToVisible(total: Int64, viewportHeight: Int64): Unit {
        if (total <= 0 || viewportHeight <= 0) {
            offset = 0
            return
        }
        let current = match (selectedRow) {
            case Some(v) => clamp(v, 0, total - 1)
            case None => 0
        }
        if (current < offset) {
            offset = current
        } else if (current >= offset + viewportHeight) {
            offset = current - viewportHeight + 1
        }
        offset = clamp(offset, 0, max(0, total - viewportHeight))
    }
}

public class Scrollbar <: Widget {
    private let total: Int64
    private let offset: Int64
    private let viewport: Int64
    private let style: Style
    private let thumbStyle: Style

    public init(
        total: Int64,
        offset!: Int64 = 0,
        viewport!: Int64 = 0,
        style!: Style = Style(fg: Color.Indexed(8)),
        thumbStyle!: Style = Style(fg: Color.White)
    ) {
        this.total = max(0, total)
        this.offset = max(0, offset)
        this.viewport = max(0, viewport)
        this.style = style
        this.thumbStyle = thumbStyle
    }

    public func handleMouse(mouse: MouseEvent, area: Rect, state: ScrollState, capture: PointerCapture, owner: String): Bool {
        if (capture.release(owner, mouse)) { return true }
        if (area.width <= 0 || area.height <= 0 || total <= viewport || viewport <= 0) { return false }
        let track = Rect(area.right - 1, area.y, 1, area.height)
        let maximum = total - viewport
        let thumbHeight = max(1, scaledChartHeight(min(viewport, total), area.height, total))
        let travel = max(1, area.height - thumbHeight)
        if (capture.owns(owner)) {
            match (mouse.kind) {
                case MouseKind.Drag =>
                    let delta = clamp(mouse.y - capture.origin().y, -travel, travel)
                    let amount = scaledChartHeight(if (delta < 0) { -delta } else { delta }, maximum, travel)
                    state.offset = selectionMove(capture.initialValue(), if (delta < 0) { -amount } else { amount }, maximum + 1)
                    return true
                case _ => return false
            }
        }
        if (!widgetHitTest(mouse, track) || capture.activeOwner().isSome()) { return false }
        let wheel = mouseScrollDelta(mouse)
        if (wheel != 0) {
            state.offset = selectionMove(state.offset, wheel, maximum + 1)
            return true
        }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                let top = area.y + scaledChartHeight(min(max(0, state.offset), maximum), travel, maximum)
                if (mouse.y < top || mouse.y >= top + thumbHeight) {
                    state.offset = scaledChartHeight(clamp(mouse.y - area.y, 0, travel), maximum, travel)
                }
                capture.begin(owner, mouse, track, value: state.offset)
            case _ => false
        }
    }

    /** 在区域最右列绘制轨道和滑块；Unicode 不可用或符号并非单列时回退至 ASCII。单行视口使用方向标记表示还有内容可滚动。区域宽高不大于 0、视口不大于 0 或内容量不超过视口时不写入缓冲区。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || total <= viewport || viewport <= 0) {
            return
        }
        let x = area.right - 1
        if (area.height == 1) {
            let maximum = total - viewport
            let marker = if (offset <= 0) { "↓" } else if (offset >= maximum) { "↑" } else { "↕" }
            let fallback = if (offset <= 0) { "v" } else if (offset >= maximum) { "^" } else { ":" }
            let symbol = if (buffer.capabilities().unicode && displayWidth(marker, options: buffer.textWidthOptions()) == 1) {
                marker
            } else {
                fallback
            }
            _ = buffer.writeStringClipped(x, area.y, symbol, maxWidth: 1, style: thumbStyle)
            return
        }
        let unicodeTrack = "│"
        let unicodeThumb = "┃"
        let useUnicode = buffer.capabilities().unicode &&
            displayWidth(unicodeTrack, options: buffer.textWidthOptions()) == 1 &&
            displayWidth(unicodeThumb, options: buffer.textWidthOptions()) == 1
        let track = if (useUnicode) { unicodeTrack } else { "|" }
        let thumb = if (useUnicode) { unicodeThumb } else { "#" }
        for (y in area.y..area.bottom) {
            buffer.setString(x, y, track, style: style)
        }
        let thumbHeight = max(1, scaledChartHeight(min(viewport, total), area.height, total))
        let maxOffset = max(1, total - viewport)
        let maxThumbTop = max(0, area.height - thumbHeight)
        let thumbTop = area.y + min(maxThumbTop, scaledChartHeight(min(offset, maxOffset), maxThumbTop, maxOffset))
        for (y in thumbTop..min(area.bottom, thumbTop + thumbHeight)) {
            buffer.setString(x, y, thumb, style: thumbStyle)
        }
    }
}

/** 保存可编辑文本及光标位置的单行输入控件，可在文本为空时显示占位文本。
 */
public class Input <: Widget {
    /** 输入控件当前保存的文本内容。
     */
    public var value: String
    /** 当前光标在输入文本中的偏移量；通过构造器设置时会调整到字符边界。
     */
    public var cursor: Int64
    private var viewportOffset: Int64 = 0
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private let block: ?Block
    private let style: Style
    private let placeholder: String
    private let placeholderStyle: ?Style
    private let showBoundary: Bool
    private var focused: Bool = false
    private var disabled: Bool = false
    private var error: Bool = false
    private var theme: ?Theme = None
    private var renderedTheme: ?Theme = None

    /** 建立输入控件并保存文本、边框及显示样式；初始光标位置会调整到文本的字符边界。
     */
    public init(
        value!: String = "",
        cursor!: Int64 = 0,
        block!: ?Block = None,
        style!: Style = Style.default(),
        placeholder!: String = "",
        placeholderStyle!: ?Style = None,
        showBoundary!: Bool = true
    ) {
        this.value = value
        this.cursor = clampToRuneBoundary(value, cursor)
        this.block = block
        this.style = style
        this.placeholder = placeholder
        this.placeholderStyle = placeholderStyle
        this.showBoundary = showBoundary
    }
    /** 设置聚焦、禁用或错误状态及其语义主题；状态优先级为禁用、错误、聚焦，全部关闭时为普通状态。
     */
    public func setVisualState(
        focused!: Bool = false,
        disabled!: Bool = false,
        error!: Bool = false,
        theme!: ?Theme = None
    ): Unit {
        this.focused = focused
        this.disabled = disabled
        this.error = error
        this.theme = theme
    }

    /** 在当前光标处插入文本；非空文本插入前会将光标限制到文本范围及 UTF-8 字符边界；禁用状态或空文本时不改变文本和光标。
     */
    public func paste(text: String): Unit {
        if (disabled || text.isEmpty()) { return }
        cursor = clampToRuneBoundary(value, cursor)
        insert(text)
    }

    /** 按键事件处理字符输入、退格、向前删除及光标移动等操作；已展示的这些按键分支返回 true。
     */
    public func handle(key: KeyEvent): Bool {
        if (disabled) { return false }
        match (key.code) {
            case Char(r) =>
                insert(match (key.text) {
                    case Some(text) => text
                    case None => runeToString(r)
                })
                true
            case Backspace =>
                backspace()
                true
            case Delete =>
                deleteForward()
                true
            case Left =>
                cursor = previousRuneOffset(value, cursor)
                true
            case Right =>
                cursor = nextRuneOffset(value, cursor)
                true
            case Home =>
                cursor = 0
                true
            case End =>
                cursor = value.size
                true
            case _ => false
        }
    }

    public func handleWithDirty(key: KeyEvent, area: Rect): ?DirtyRects { handleWithDirty(key, area, layoutTheme: None) }

    public func handleWithDirty(key: KeyEvent, area: Rect, layoutTheme!: ?Theme): ?DirtyRects {
        let beforeViewport = viewportOffset
        let beforeEmpty = value.isEmpty()
        if (!handle(key)) { return None }
        let dirty = DirtyRects()
        if (beforeViewport != viewportOffset || beforeEmpty != value.isEmpty()) {
            dirty.add(area)
        } else {
            let target = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
            dirty.add(Rect(target.x, target.y, target.width, min(Int64(1), target.height)))
        }
        Some(dirty)
    }

    /** 绘制前可传入应用布局主题；组件自身的显式主题及区块的显式主题优先。 */
    public func handleMouse(mouse: MouseEvent, area: Rect): Bool { handleMouse(mouse, area, layoutTheme: None) }

    public func handleMouse(mouse: MouseEvent, area: Rect, layoutTheme!: ?Theme): Bool {
        if (disabled) { return false }
        let outer = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        if (!widgetHitTest(mouse, outer) || mouse.y != outer.y) { return false }
        let target = inputContentArea(outer)
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Down, MouseButton.Left) =>
                ensureCursorVisible(target.width)
                cursor = viewportOffset + offsetAtLineColumn(value[viewportOffset..], 0, max(0, mouse.x - target.x), options: textWidthOptionsValue)
                true
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        textWidthOptionsValue = buffer.textWidthOptions()
        renderedTheme = buffer.resolveTheme(None)
        var target = area
        if (let Some(b) <- block) {
            buffer.withParentTheme(theme) { => b.render(area, buffer) }
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let activeTheme = buffer.resolveTheme(theme)
        let resolved = visualStyle(activeTheme)
        buffer.fillRect(target, style: rowFillStyle(resolved))
        let content = inputContentArea(target)
        if (showBoundary && block.isNone()) {
            buffer.setString(target.x, target.y, "[", style: resolved)
            if (target.width > 1) { buffer.setString(target.right - 1, target.y, "]", style: resolved) }
        }
        target = content
        if (target.width <= 0) { return }
        if (value.isEmpty() && !placeholder.isEmpty()) {
            let placeholderColor = match (placeholderStyle) {
                case Some(value) => value
                case None => if (error && !disabled) { resolved } else {
                    match (activeTheme) {
                        case Some(value) => value.disabled
                        case None => Style(fg: Color.Indexed(8))
                    }
                }
            }
            let placeholderModifier = combineModifiers(placeholderColor.modifier, resolved.modifier)
            buffer.setString(target.x, target.y, truncate(placeholder, target.width, options: buffer.textWidthOptions()),
                style: placeholderColor.withBg(resolved.bg).withModifier(placeholderModifier))
            return
        }
        ensureCursorVisible(target.width)
        buffer.setString(target.x, target.y, truncate(value[viewportOffset..], target.width, options: buffer.textWidthOptions()), style: resolved)
    }

    private func visualStyle(theme: ?Theme): Style {
        match (theme) {
            case Some(_) =>
                resolvedSemanticStateStyle(
                    style,
                    style,
                    style,
                    style,
                    style,
                    focused,
                    false,
                    disabled,
                    error,
                    theme
                )
            case None =>
                if (disabled) {
                    style.patch(Style(fg: Color.Indexed(8)))
                } else if (error) {
                    style.patch(Style(fg: Color.Red))
                } else if (focused) {
                    var modifier = style.modifier
                    modifier.bold = true
                    style.withModifier(modifier)
                } else {
                    style
                }
        }
    }

    /** 使用指定宽度策略计算光标位置，也将其用于后续的鼠标命中及视口调整。 */
    public func cursorPosition(area: Rect, options!: TextWidthOptions, layoutTheme!: ?Theme = None): Position {
        textWidthOptionsValue = options
        cursorPosition(area, layoutTheme: layoutTheme)
    }

    /** 按内容区域宽度调整文本视口，并返回光标在该区域首行的显示位置；有外围区块时使用其内部区域。绘制前可用 layoutTheme 指定应用主题。
     */
    public func cursorPosition(area: Rect): Position { cursorPosition(area, layoutTheme: None) }

    public func cursorPosition(area: Rect, layoutTheme!: ?Theme): Position {
        var target = controlBlockArea(area, block, theme, layoutTheme, renderedTheme)
        let outer = target
        target = inputContentArea(target)
        if (target.width <= 0) { return Position(outer.x, outer.y) }
        ensureCursorVisible(target.width)
        Position(target.x + min(displayWidth(value[viewportOffset..cursor], options: textWidthOptionsValue), target.width - 1), target.y)
    }

    private func inputContentArea(area: Rect): Rect {
        if (showBoundary && block.isNone()) {
            Rect(area.x + min(Int64(1), max(Int64(0), area.width)), area.y, max(0, area.width - 2), area.height)
        } else {
            area
        }
    }

    public func setValue(value: String, cursor!: Int64 = -1): Unit {
        this.value = value
        this.cursor = if (cursor < 0) { value.size } else { clampToRuneBoundary(value, cursor) }
        viewportOffset = 0
    }

    public func clear(): Unit {
        value = ""
        cursor = 0
        viewportOffset = 0
    }

    public func moveToStart(): Unit {
        cursor = 0
        viewportOffset = 0
    }

    public func moveToEnd(): Unit {
        cursor = value.size
    }

    private func insert(text: String): Unit {
        value = value[..cursor] + text + value[cursor..]
        cursor += text.size
    }

    private func backspace(): Unit {
        if (cursor <= 0) { return }
        let prev = previousRuneOffset(value, cursor)
        value = value[..prev] + value[cursor..]
        cursor = prev
    }

    private func deleteForward(): Unit {
        if (cursor >= value.size) { return }
        let next = nextRuneOffset(value, cursor)
        value = value[..cursor] + value[next..]
    }

    private func ensureCursorVisible(width: Int64): Unit {
        cursor = clampToRuneBoundary(value, cursor)
        viewportOffset = clampToRuneBoundary(value, viewportOffset)
        if (width <= 0 || value.isEmpty()) {
            viewportOffset = 0
            return
        }
        if (cursor < viewportOffset) {
            viewportOffset = cursor
        }
        while (displayWidth(value[viewportOffset..cursor], options: textWidthOptionsValue) >= width && viewportOffset < cursor) {
            viewportOffset = nextRuneOffset(value, viewportOffset)
        }
        if (viewportOffset > value.size) {
            viewportOffset = value.size
        }
    }
}

func addListRowDirty(dirty: DirtyRects, area: Rect, selected: ?Int64, offset: Int64): Unit {
    match (selected) {
        case Some(index) =>
            let row = index - offset
            if (row >= 0 && row < area.height) {
                dirty.add(Rect(area.x, area.y + row, area.width, 1))
            }
        case None => ()
    }
}

public class FileDialog <: Widget {
    public let picker: FilePicker
    private let title: String
    public init(path!: String = ".", extension!: String = "", title!: String = "Files") {
        picker = FilePicker(path: path, extension: extension)
        this.title = title
    }
    public func selectedPath(): ?String { picker.selectedPath() }
    public func handle(key: KeyEvent, viewportHeight: Int64): Bool { picker.handle(key, viewportHeight) }
    public func render(area: Rect, buffer: Buffer): Unit {
        picker.render(area, buffer)
        Block(title: title).render(area, buffer)
    }
}
