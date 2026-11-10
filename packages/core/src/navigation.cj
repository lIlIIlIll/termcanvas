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
    separatorWidth: Int64,
    options: TextWidthOptions
): Int64 {
    if (items.isEmpty()) { return 0 }
    let current = clamp(selected, 0, items.size - 1)
    if (width <= 0) { return current }
    let selectedText = selectedPrefix + items[current] + selectedSuffix
    var used = displayWidth(selectedText, options: options)
    if (used > width) { return current }
    var first = current
    while (first > 0) {
        let previousText = regularPrefix + items[first - 1] + regularSuffix
        let previousWidth = displayWidth(previousText, options: options) + separatorWidth
        if (previousWidth > width - used) { break }
        used += previousWidth
        first--
    }
    first
}

/** 按顺序在一行绘制标签标题，以不同样式标示当前选中项；左右方向键可切换选中项。
 */
public class Tabs <: Widget {
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private let titles: Array<String>
    /** 当前选中标签的索引，从 0 开始，可直接修改；构造、键盘、鼠标及绘制操作会先将其限制在标题索引范围内，空标题列表中为 0。
     */
    public var selected: Int64
    private let style: Style
    private let selectedStyle: ?Style
    private var theme: ?Theme = None

    private var focused: Bool = false
    /** 保存标签标题和两种绘制样式，并将初始选中索引限制在 0 到最后一个标题索引之间；没有标题时设为 0。
     * @param titles 标签标题
     * @param selected 初始选中索引
     * @param style 普通标签样式
     * @param selectedStyle 可选的选中标签样式
     */
    public init(
        titles: Array<String>,
        selected!: Int64 = 0,
        style!: Style = Style.default(),
        selectedStyle!: ?Style = None
    ) {
        this.titles = titles
        this.selected = clamp(selected, 0, max(0, titles.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
    }
    /** 设置当前标签栏是否具有焦点；聚焦时选中标签额外显示粗体和下划线。
     * @param focused 是否聚焦
     */
    public func setFocused(focused: Bool): Unit {
        this.focused = focused
    }

    /** 设置标签栏使用的可选语义主题。
     * @param theme 语义主题；None 使用缓冲区主题
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    /** 左右方向键在非空标签列表中切换选中项并返回 true；按键前先限制公开索引，空列表或其他按键返回 false。
     * @param key 按键事件
     * @return 识别到切换按键时为 true
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
     * @param mouse 鼠标事件
     * @param area 标签栏区域
     * @return 命中并选中标签时为 true
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
                    let full = " " + titles[i] + " "
                    let fullWidth = displayWidth(full, options: textWidthOptionsValue)
                    let visibleWidth = displayWidth(truncate(full, area.right - x, options: textWidthOptionsValue), options: textWidthOptionsValue)
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
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        textWidthOptionsValue = buffer.textWidthOptions()
        normalizeSelected()
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || titles.isEmpty()) { return }
        let theme = buffer.resolveTheme(this.theme)
        var x = area.x
        let first = ensureSelectionVisible(area.width)
        for (i in first..titles.size) {
            if (x >= area.right) { return }
            let full = " " + titles[i] + " "
            let text = truncate(full, area.right - x, options: textWidthOptionsValue)
            let visibleWidth = displayWidth(text, options: textWidthOptionsValue)
            var itemStyle = if (i == selected) {
                listSelectionStyle(selectedStyle, theme)
            } else {
                themedNormal(style, theme)
            }
            if (i == selected && focused) {
                var modifier = itemStyle.modifier
                modifier.bold = true
                modifier.underline = true
                itemStyle = itemStyle.withModifier(modifier)
            }
            buffer.setString(x, area.y, text, style: itemStyle)
            let fullWidth = displayWidth(full, options: textWidthOptionsValue)
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
        horizontalFirstVisible(titles, selected, width, " ", " ", " ", " ", 0, textWidthOptionsValue)
    }
}

/** 在一行绘制可切换的分段值；键盘切换有界，鼠标只命中可见段文本。
 */
public class SegmentedControl <: Widget {
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private let items: Array<String>
    /** 当前选中项的索引；非空列表的操作、值查询和绘制会先限制到有效范围，空列表中为 0。
     */
    public var selected: Int64
    private let style: Style
    private let selectedStyle: Style
    private let disabledStyle: ?Style
    private var focused: Bool
    private var disabled: Bool
    private var theme: ?Theme

    /** 保存分段值与绘制状态；构造时将选中索引限制到有效范围，选中样式默认使用语义主题角色。
     * @param items 分段值
     * @param selected 初始选中索引
     * @param style 普通段样式
     * @param selectedStyle 选中段样式
     * @param disabledStyle 禁用样式
     * @param focused 是否聚焦
     * @param disabled 是否禁用
     * @param theme 可选的语义主题
     */
    public init(
        items: Array<String>,
        selected!: Int64 = 0,
        style!: Style = Style.default(),
        selectedStyle!: Style = Style.default(),
        disabledStyle!: ?Style = None,
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
     * @return 选中值；无选项时为 None
     */
    public func selectedValue(): ?String {
        normalizeSelected()
        if (items.isEmpty()) { return None }
        Some(items[selected])
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

    /** 非空且启用时，Left/Right 有界移动，Home/End 跳到首尾；识别的按键即使停在边界也返回 true。
     * @param key 按键事件
     * @return 识别到导航按键时为 true
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
     * @param mouse 鼠标事件
     * @param area 分段控件区域
     * @return 命中并选中分段时为 true
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
                    let fullWidth = displayWidth(fullText, options: textWidthOptionsValue)
                    let visibleText = truncate(fullText, area.right - x, options: textWidthOptionsValue)
                    let visibleWidth = displayWidth(visibleText, options: textWidthOptionsValue)
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
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        textWidthOptionsValue = buffer.textWidthOptions()
        normalizeSelected()
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.withCanvasClip(Rect(area.x, area.y, area.width, 1)) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let theme = buffer.resolveTheme(this.theme)
        let useTheme = selectedStyle == Style.default()
        let rowStyle = if (disabled) {
            resolvedDisabledStyle(theme)
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
            let text = truncate(fullText, area.right - x, options: textWidthOptionsValue)
            let visibleWidth = displayWidth(text, options: textWidthOptionsValue)
            buffer.setString(x, area.y, text, style: segmentStyle(index, useTheme, theme))
            let fullWidth = displayWidth(fullText, options: textWidthOptionsValue)
            x += visibleWidth
            if (visibleWidth < fullWidth) { return }
            if (index + 1 < items.size && x < area.right) { x += 1 }
        }
    }

    private func segmentText(index: Int64): String {
        if (index == selected) { "[" + items[index] + "]" } else { " " + items[index] + " " }
    }

    private func segmentStyle(index: Int64, useTheme: Bool, theme: ?Theme): Style {
        if (disabled) { return resolvedDisabledStyle(theme) }
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

    private func resolvedDisabledStyle(theme: ?Theme): Style {
        let fallback = match (theme) { case Some(_) => Style.default(); case None => Style(fg: Color.Indexed(8)) }
        themeRoleStyle(match (disabledStyle) { case Some(value) => value; case None => fallback }, ThemeRole.Disabled, theme)
    }

    private func normalizeSelected(): Unit {
        if (items.isEmpty()) {
            selected = 0
        } else {
            selected = clamp(selected, 0, items.size - 1)
        }
    }

    private func firstVisible(width: Int64): Int64 {
        horizontalFirstVisible(items, selected, width, "[", "]", " ", " ", 1, textWidthOptionsValue)
    }
}

/** 状态栏内嵌进度条的值、尺寸、样式和符号配置。 */
public class StatusBarProgress {
    /** 当前进度，至少为零。 */
    public let value: Int64
    /** 进度总量，至少为一。 */
    public let total: Int64
    /** 期望进度条宽度，至少为零。 */
    public let width: Int64
    /** 自定义进度标签。 */
    public let label: String
    /** 标签显示模式。 */
    public let labelMode: ProgressBarLabelMode
    /** 未使用应用主题时的默认基础样式；显式设置始终优先。
     */
    public let style: Style
    /** 未使用应用主题时的默认填充样式；显式设置始终优先。
     */
    public let fillStyle: Style
    /** 未使用应用主题时的默认标签样式；显式设置始终优先。
     */
    public let labelStyle: Style
    /** 未使用应用主题时的默认符号；显式设置始终优先。
     */
    public let symbols: ProgressBarSymbols
    private let customStyle: Bool
    private let customFillStyle: Bool
    private let customLabelStyle: Bool
    private let customSymbols: Bool

    /** 保存状态栏进度条的配置；将当前值限制为至少 0、总量限制为至少 1、宽度限制为至少 0。
     * 未显式设置样式或符号时，有应用主题则继承主题，否则使用上述默认值。
     * @param value 当前进度
     * @param total 进度总量
     * @param width 期望宽度
     * @param label 自定义标签
     * @param labelMode 标签显示模式
     * @param style 基础样式
     * @param fillStyle 填充样式
     * @param labelStyle 标签样式
     * @param symbols 进度符号
     */
    public init(
        value: Int64,
        total!: Int64 = 100,
        width!: Int64 = 18,
        label!: String = "",
        labelMode!: ProgressBarLabelMode = ProgressBarLabelMode.Percent,
        style!: ?Style = None,
        fillStyle!: ?Style = None,
        labelStyle!: ?Style = None,
        symbols!: ?ProgressBarSymbols = None
    ) {
        this.value = max(0, value)
        this.total = max(1, total)
        this.width = max(0, width)
        this.label = label
        this.labelMode = labelMode
        this.customStyle = style.isSome()
        this.customFillStyle = fillStyle.isSome()
        this.customLabelStyle = labelStyle.isSome()
        this.customSymbols = symbols.isSome()
        this.style = match (style) { case Some(value) => value; case None => Style(fg: Color.Indexed(8), bg: Color.White) }
        this.fillStyle = match (fillStyle) { case Some(value) => value; case None => Style(fg: Color.Cyan, bg: Color.White) }
        this.labelStyle = match (labelStyle) { case Some(value) => value; case None => Style(fg: Color.Black, bg: Color.White) }
        this.symbols = match (symbols) { case Some(value) => value; case None => ProgressBarSymbols(filled: "=", empty: "-", head: ">", indeterminate: ">") }
    }

    func hasCustomStyle(): Bool { customStyle }
    func hasCustomFillStyle(): Bool { customFillStyle }
    func hasCustomLabelStyle(): Bool { customLabelStyle }
    func hasCustomSymbols(): Bool { customSymbols }
}

/** 在一行内显示左右文本以及可选的进度条。 */
public class StatusBar <: Widget {
    private let left: String
    private let right: String
    private let style: ?Style
    private let progress: ?StatusBarProgress

    /** 创建状态栏。
     * @param left 左侧文本
     * @param right 右对齐文本
     * @param style 可选样式
     * @param progress 可选进度配置
     */
    public init(
        left!: String = "",
        right!: String = "",
        style!: ?Style = None,
        progress!: ?StatusBarProgress = None
    ) {
        this.left = left
        this.right = right
        this.style = style
        this.progress = progress
    }

    /** 宽或高不大于 0 时不绘制；否则在区域首行先填充空格，再绘制左侧及右对齐文字。宽度不足时以省略标记表示未显示内容；两侧均有内容且区域至少三列时保留分隔。配置了进度条且可用宽度至少为 6 时，在两侧文字之间绘制进度条。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let style = match (buffer.resolveTheme(None)) {
            case Some(theme) => match (this.style) { case Some(value) => theme.raisedSurface.patch(value); case None => theme.raisedSurface }
            case None => match (this.style) { case Some(value) => value; case None => Style(fg: Color.Black, bg: Color.White) }
        }
        buffer.setString(area.x, area.y, repeat(" ", area.width), style: style)

        // Reserve room for a left indicator and a separator when both sides
        // have content and the row can accommodate both.
        let rightBudget = if (!left.isEmpty() && !right.isEmpty() && area.width >= 3) { area.width - 2 } else { area.width }
        let rightText = clippedText(right, rightBudget, buffer)
        let rightWidth = displayWidth(rightText, options: buffer.textWidthOptions())
        let rightX = area.right - rightWidth
        var leftLimit = if (rightWidth > 0) { max(0, rightX - area.x - 1) } else { area.width }
        match (progress) {
            case Some(p) =>
                let gap = if (rightWidth > 0) { 1 } else { 0 }
                let available = max(0, rightX - area.x - gap - 1)
                let progressWidth = min(p.width, available)
                if (progressWidth >= 6) {
                    let progressX = rightX - gap - progressWidth
                    let themed = buffer.resolveTheme(None).isSome()
                    let trackStyle: ?Style = if (themed && !p.hasCustomStyle()) { None } else { Some(p.style) }
                    let filledStyle: ?Style = if (themed && !p.hasCustomFillStyle()) { None } else { Some(p.fillStyle) }
                    let progressLabelStyle: ?Style = if (themed && !p.hasCustomLabelStyle()) { None } else { Some(p.labelStyle) }
                    let progressSymbols = if (themed && !p.hasCustomSymbols()) { ProgressBarSymbols.automatic() } else { p.symbols }
                    ProgressBar(
                        p.value,
                        total: p.total,
                        label: p.label,
                        style: trackStyle,
                        fillStyle: filledStyle,
                        labelMode: p.labelMode,
                        labelStyle: progressLabelStyle,
                        symbols: progressSymbols,
                        trackOverride: if (themed && !p.hasCustomStyle()) { StyleOverride(bg: Some(style.bg)) } else { StyleOverride() },
                        fillOverride: if (themed && !p.hasCustomFillStyle()) { StyleOverride(bg: Some(style.bg)) } else { StyleOverride() }
                    ).render(Rect(progressX, area.y, progressWidth, 1), buffer)
                    leftLimit = max(0, progressX - area.x - 1)
                }
            case None => ()
        }
        buffer.setString(area.x, area.y, clippedText(left, leftLimit, buffer), style: style)
        if (rightWidth > 0) {
            buffer.setString(rightX, area.y, rightText, style: style)
        }
    }
    // Reserve one column for a visible omission marker without splitting a
    // grapheme. East Asian ambiguous-wide terminals use a one-cell period.
    private func clippedText(text: String, width: Int64, buffer: Buffer): String {
        if (width <= 0 || text.isEmpty()) { return "" }
        let options = buffer.textWidthOptions()
        if (displayWidth(text, options: options) <= width) { return text }
        let marker = if (buffer.capabilities().unicode && displayWidth("…", options: options) == 1) { "…" } else { "." }
        graphemePrefix(text, width - 1, options: options) + marker
    }

}

/** 显示文本行的一段可滚动视口。 */
public class Viewport <: Widget {
    private let lines: Array<String>
    /** 首个显示行的索引。 */
    public var offset: Int64
    private let block: ?Block
    private let style: Style

    /** 创建文本视口。
     * @param lines 要显示的文本行
     * @param offset 起始行索引，负值按零处理
     * @param block 可选的边框容器
     * @param style 文本样式
     */
    public init(lines: Array<String>, offset!: Int64 = 0, block!: ?Block = None, style!: Style = Style.default()) {
        this.lines = lines
        this.offset = max(0, offset)
        this.block = block
        this.style = style
    }

    /** 处理上下、翻页及首尾导航按键。
     * @param key 按键事件
     * @param viewportHeight 可见行数
     * @return 识别到导航按键时为 true
     */
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

    /** 按行滚动并将偏移限制在可用范围内。
     * @param delta 行数增量
     * @param viewportHeight 可见行数
     */
    public func scroll(delta: Int64, viewportHeight: Int64): Unit {
        offset = clamp(offset + delta, 0, max(0, lines.size - max(0, viewportHeight)))
    }

    /** 将可见行绘制到缓冲区；设置边框时先绘制边框。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withCanvasClip(area) { => renderClipped(area, buffer) }
    }

    private func renderClipped(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        let resolvedStyle = themedNormal(style, buffer.resolveTheme(None))
        for (row in 0..target.height) {
            let index = offset + row
            if (index >= lines.size) { return }
            buffer.setString(target.x, target.y + row, truncate(lines[index], target.width, options: buffer.textWidthOptions()), style: resolvedStyle)
        }
    }
}

// Geometry helpers do not dispatch events. Applications choose the active
// surface before calling a widget, so overlays cannot click through.
/** 判断鼠标坐标是否位于非空区域内；不检查事件种类。
 * @param mouse 鼠标事件
 * @param area 命中区域
 * @return 坐标位于区域内时为 true
 */
public func widgetHitTest(mouse: MouseEvent, area: Rect): Bool {
    area.width > 0 && area.height > 0 && mouse.x >= area.x && mouse.x < area.right &&
        mouse.y >= area.y && mouse.y < area.bottom
}

/** 将区域内的鼠标坐标换算为列表行索引。
 * @param mouse 鼠标事件
 * @param area 列表区域
 * @param offset 首个可见行索引
 * @param total 行总数
 * @return 命中的行索引；无效或区域外时为 None
 */
public func widgetRowAt(mouse: MouseEvent, area: Rect, offset: Int64, total: Int64): ?Int64 {
    if (!widgetHitTest(mouse, area) || offset < 0 || offset >= total) { return None }
    let row = mouse.y - area.y
    if (row >= total - offset) { None } else { Some(offset + row) }
}

/** 将滚轮事件转换为行方向。
 * @param mouse 鼠标事件
 * @return 向上为 -1，向下为 1，其他事件为 0
 */
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

/** 跟踪单个鼠标拖动的拥有者、起点和初始值。 */
public class PointerCapture {
    private var owner: ?String = None
    private var start: Position = Position(0, 0)
    private var value: Int64 = 0

    /** 创建空的鼠标捕获状态。 */
    public init() {}

    /** 在区域内左键按下时开始捕获；已有拥有者时拒绝。
     * @param owner 非空的拥有者标识
     * @param mouse 鼠标事件
     * @param area 允许开始捕获的区域
     * @param value 拖动开始时的应用值
     * @return 成功捕获时为 true
     */
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

    /** 判断指定标识是否拥有捕获。
     * @param owner 拥有者标识
     * @return 拥有捕获时为 true
     */
    public func owns(owner: String): Bool { this.owner == Some(owner) }
    /** 获取当前拥有者。
     * @return 拥有者标识；无捕获时为 None
     */
    public func activeOwner(): ?String { owner }
    /** 获取最近一次捕获开始的坐标。
     * @return 起始坐标
     */
    public func origin(): Position { start }
    /** 获取最近一次捕获保存的应用值。
     * @return 起始值
     */
    public func initialValue(): Int64 { value }

    /** 由拥有者在左键释放时结束捕获；释放位置可以在原区域外。
     * @param owner 拥有者标识
     * @param mouse 鼠标事件
     * @return 结束捕获时为 true
     */
    public func release(owner: String, mouse: MouseEvent): Bool {
        if (!owns(owner)) { return false }
        match ((mouse.kind, mouse.button)) {
            case (MouseKind.Up, MouseButton.Left) | (MouseKind.Up, MouseButton.None) => cancel(); true
            case _ => false
        }
    }

    /** 取消当前捕获。 */
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
/** 管理基础焦点和可嵌套的模态焦点与快捷键层。 */
public class ModalFocusState {
    private let base: FocusManager
    private let baseKeys: KeyMap
    private let layers = ArrayList<ModalFocusLayer>()

    /** 创建模态焦点状态。
     * @param base 基础焦点管理器
     * @param keymap 基础层快捷键映射
     */
    public init(base: FocusManager, keymap!: KeyMap = KeyMap()) {
        this.base = base
        this.baseKeys = keymap
    }

    /** 打开新模态层并保存当前焦点；空标识和重复标识会被拒绝。
     * @param id 模态层标识
     * @param focusIds 新层的焦点条目
     * @param keymap 新层快捷键映射
     * @return 成功打开时为 true
     */
    public func open(id: String, focusIds: Array<String>, keymap!: KeyMap = KeyMap()): Bool {
        if (id.isEmpty()) { return false }
        for (layer in layers) { if (layer.id == id) { return false } }
        layers.add(ModalFocusLayer(id, focusIds, keymap, focus().current()))
        true
    }

    /** 获取最上层模态标识。
     * @return 模态标识；无模态层时为 None
     */
    public func active(): ?String {
        if (layers.isEmpty()) { None } else { Some(layers[layers.size - 1].id) }
    }

    /** 获取当前层的焦点管理器。
     * @return 模态层或基础层的焦点管理器
     */
    public func focus(): FocusManager {
        if (layers.isEmpty()) { base } else { layers[layers.size - 1].focus }
    }

    /** 关闭最上层并尝试恢复先前焦点。
     * @return 关闭的模态标识；无模态层时为 None
     */
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

    /** 将按键交给当前焦点层；Escape 关闭最上层模态。
     * @param key 按键事件
     * @return 事件被处理时为 true
     */
    public func handle(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.Esc =>
                if (layers.isEmpty()) { false } else { _ = close(); true }
            case _ => focus().handle(key)
        }
    }

    /** 只查询当前层的快捷键映射。
     * @param key 按键事件
     * @return 对应动作；未绑定时为 None
     */
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
