package core

import std.collection.*

/** 按行显示指标标题、数值、详情和趋势。 */
public class MetricCard <: Widget {
    private let title: String
    private let value: String
    private let detail: String
    private let trend: String
    private let style: ?Style
    private let valueStyle: ?Style

    /** 创建控件。
     * @param title 指标标题
     * @param value 指标数值
     * @param detail 可选详情
     * @param trend 可选趋势
     * @param style 标题及详情样式
     * @param valueStyle 数值样式
     */
    public init(
        title: String,
        value: String,
        detail!: String = "",
        trend!: String = "",
        style!: ?Style = None,
        valueStyle!: ?Style = None
    ) {
        this.title = title
        this.value = value
        this.detail = detail
        this.trend = trend
        this.style = style
        this.valueStyle = valueStyle
    }

    /** 按可用高度绘制指标内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let theme = buffer.resolveTheme(Option<Theme>.None)
        let normal = widgetRoleStyle(style, theme, ThemeRole.Normal, Style.default())
        let value = widgetRoleStyle(valueStyle, theme, ThemeRole.Accent, Style(fg: Color.Cyan, modifier: Modifier.strong()))
        buffer.setString(area.x, area.y, truncate(title, area.width, options: buffer.textWidthOptions()), style: normal)
        if (area.height > 1) {
            buffer.setString(area.x, area.y + 1, truncate(this.value, area.width, options: buffer.textWidthOptions()), style: value)
        }
        if (area.height > 2 && !detail.isEmpty()) {
            buffer.setString(area.x, area.y + 2, truncate(detail, area.width, options: buffer.textWidthOptions()), style: normal)
        }
        if (area.height > 3 && !trend.isEmpty()) {
            buffer.setString(area.x, area.y + 3, truncate(trend, area.width, options: buffer.textWidthOptions()), style: normal)
        }
    }
}

/** 显示标签及百分比进度条。 */
public class Meter <: Widget {
    private let label: String
    private let value: Int64
    private let total: Int64
    private let style: ?Style
    private let fillStyle: ?Style

    /** 创建控件。
     * @param label 指标标签
     * @param value 当前值，负值按零处理
     * @param total 总量，至少为一
     * @param style 轨道样式
     * @param fillStyle 填充样式
     */
    public init(label: String, value: Int64, total!: Int64 = 100, style!: ?Style = None, fillStyle!: ?Style = None) {
        this.label = label
        this.value = max(0, value)
        this.total = max(1, total)
        this.style = style
        this.fillStyle = fillStyle
    }

    /** 在首行绘制标签和进度条。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let theme = buffer.resolveTheme(Option<Theme>.None)
        let normal = widgetRoleStyle(style, theme, ThemeRole.Disabled, Style(fg: Color.Indexed(8)))
        let fill = widgetRoleStyle(fillStyle, theme, ThemeRole.Accent, Style(fg: Color.Green))
        let labelWidth = min(area.width, max(0, displayWidthFast(label, options: buffer.textWidthOptions()) + 1))
        if (labelWidth > 0) {
            buffer.setString(area.x, area.y, truncate(label, labelWidth, options: buffer.textWidthOptions()), style: normal)
        }
        let bar = Rect(area.x + labelWidth, area.y, max(0, area.width - labelWidth), 1)
        ProgressBar(value, total: total, style: normal, fillStyle: fill, labelMode: ProgressBarLabelMode.Percent).render(bar, buffer)
    }
}

/** 图例中的符号、标签和样式。 */
public class LegendItem {
    /** 图例标签。 */
    public let label: String
    /** 图例符号。 */
    public let symbol: String
    /** 无主题时的图例样式。 */
    public let style: Style
    let explicitStyle: ?Style

    /** 创建图例项。
     * @param label 图例标签
     * @param symbol 图例符号
     * @param style 可选样式
     */
    public init(label: String, symbol!: String = "#", style!: ?Style = None) {
        this.label = label
        this.symbol = symbol
        this.explicitStyle = style
        this.style = match (style) { case Some(value) => value; case None => Style(fg: Color.Cyan) }
    }
}

/** 在一行显示一组图例。 */
public class Legend <: Widget {
    private let items: Array<LegendItem>
    private let gap: String

    /** 创建控件。
     * @param items 图例项
     * @param gap 图例项之间的间隔
     */
    public init(items: Array<LegendItem>, gap!: String = "  ") {
        this.items = items
        this.gap = gap
    }

    /** 绘制可见的图例项。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        var x = area.x
        for (item in items) {
            let text = item.symbol + " " + item.label
            if (x >= area.right) { return }
            let itemStyle = widgetRoleStyle(item.explicitStyle, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Accent, item.style)
            buffer.setString(x, area.y, truncate(text, area.right - x, options: buffer.textWidthOptions()), style: itemStyle)
            x += displayWidthFast(text, options: buffer.textWidthOptions())
            if (x < area.right) {
                buffer.setString(x, area.y, truncate(gap, area.right - x, options: buffer.textWidthOptions()), style: Style.default())
            }
            x += displayWidthFast(gap, options: buffer.textWidthOptions())
        }
    }
}

/** 在区域内以字符柱显示数值序列。 */
public class TimeSeriesChart <: Widget {
    private let values: Array<Int64>
    private let maxValue: Int64
    private let style: ?Style

    /** 创建控件。
     * @param values 数值序列
     * @param maxValue 纵向最大值；非正值使用序列最大值
     * @param style 柱形样式
     */
    public init(values: Array<Int64>, maxValue!: Int64 = 0, style!: ?Style = None) {
        this.values = values
        this.maxValue = max(0, maxValue)
        this.style = style
    }

    /** 按区域宽度绘制序列的前若干个值。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || values.size == 0) { return }
        let style = widgetRoleStyle(this.style, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Accent, Style(fg: Color.Cyan))
        let maxV = max(1, if (maxValue > 0) { maxValue } else { maxArray(values) })
        let count = min(area.width, values.size)
        for (i in 0..count) {
            let value = max(0, values[i])
            let height = if (value >= maxV) { area.height } else { max(1, scaledChartHeight(value, area.height, maxV)) }
            for (dy in 0..height) {
                buffer.setString(area.x + i, area.bottom - 1 - dy, "#", style: style)
            }
        }
    }
}

// Scale a nonnegative value into a bounded extent without overflowing the
// intermediate product. The same exact ratio is used by charts and progress.
func scaledChartHeight(value: Int64, height: Int64, maximum: Int64): Int64 {
    if (value <= 0 || height <= 0) { return 0 }
    if (value >= maximum) { return height }
    if (value <= Int64.Max / height) { return value * height / maximum }
    let divisor = UInt64(maximum)
    let factor = UInt64(value)
    let multiplier = UInt64(height)
    var quotient: UInt64 = 0
    var remainder: UInt64 = 0
    var bit: Int64 = 63
    while (bit > 0) {
        bit--
        quotient *= 2
        remainder *= 2
        if (remainder >= divisor) { remainder -= divisor; quotient++ }
        if (((multiplier >> bit) & 1) != 0) {
            remainder += factor
            if (remainder >= divisor) { remainder -= divisor; quotient++ }
        }
    }
    Int64(quotient)
}

/** 显示左、中、右文本的顶部栏。 */
public class HeaderBar <: Widget {
    private let title: String
    private let left: String
    private let right: String
    private let style: ?Style

    /** 创建控件。
     * @param title 居中标题
     * @param left 左侧文本
     * @param right 右侧文本
     * @param style 栏样式
     */
    public init(title: String, left!: String = "", right!: String = "", style!: ?Style = None) {
        this.title = title
        this.left = left
        this.right = right
        this.style = style
    }

    /** 在首行绘制顶部栏。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderBar(area, buffer, left, title, right, widgetRoleStyle(style, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Normal, Style(fg: Color.White, modifier: Modifier.strong())))
    }
}

/** 显示左、中、右文本的底部栏。 */
public class FooterBar <: Widget {
    private let left: String
    private let center: String
    private let right: String
    private let style: ?Style

    /** 创建控件。
     * @param left 左侧文本
     * @param center 居中文本
     * @param right 右侧文本
     * @param style 栏样式
     */
    public init(left!: String = "", center!: String = "", right!: String = "", style!: ?Style = None) {
        this.left = left
        this.center = center
        this.right = right
        this.style = style
    }

    /** 在首行绘制底部栏。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderBar(area, buffer, left, center, right, widgetRoleStyle(style, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Disabled, Style(fg: Color.Indexed(8))))
    }
}

/** 居中显示空状态标题和说明。 */
public class EmptyState <: Widget {
    private let title: String
    private let detail: String
    private let style: ?Style

    /** 创建控件。
     * @param title 空状态标题
     * @param detail 附加说明
     * @param style 文本样式
     */
    public init(title!: String = "No data", detail!: String = "", style!: ?Style = None) {
        this.title = title
        this.detail = detail
        this.style = style
    }

    /** 在区域中居中绘制内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        renderCenteredLines(area, buffer, [title, detail], widgetRoleStyle(style, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Disabled, Style(fg: Color.Indexed(8))))
    }
}

/** 在边框内显示错误信息。 */
public class ErrorBox <: Widget {
    private let message: String
    private let detail: String
    private let style: ?Style
    private let borderKind: ?BorderKind
    private let theme: ?Theme

    /** 创建控件。
     * @param message 错误信息
     * @param detail 附加说明
     * @param style 错误样式
     * @param borderKind 可选边框类型
     * @param theme 可选语义主题
     */
    public init(message: String, detail!: String = "", style!: ?Style = None, borderKind!: ?BorderKind = None, theme!: ?Theme = None) {
        this.message = message
        this.detail = detail
        this.style = style
        this.borderKind = borderKind
        this.theme = theme
    }

    /** 绘制错误边框和内容。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let resolvedTheme = buffer.resolveTheme(theme)
        let errorStyle = widgetRoleStyle(style, resolvedTheme, ThemeRole.Error, Style(fg: Color.Red))
        let kind = match (borderKind) {
            case Some(value) => value
            case None => if (resolvedTheme.isSome()) { BorderKind.Auto } else { BorderKind.Ascii }
        }
        let block = Block(BlockOptions(title: "Error", borderKind: kind, borderStyle: errorStyle, titleStyle: errorStyle, theme: theme))
        let inner = block.renderInner(area, buffer)
        renderCenteredLines(inner, buffer, [message, detail], errorStyle)
    }
}

/** 在区域中显示加载提示和旋转帧。 */
public class LoadingOverlay <: Widget {
    private let label: String
    private let frame: Int64

    /** 创建控件。
     * @param label 加载提示
     * @param frame 动画帧索引，负值按零处理
     */
    public init(label!: String = "Loading", frame!: Int64 = 0) {
        this.label = label
        this.frame = max(0, frame)
    }

    /** 在区域中居中绘制加载提示。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        Spinner(label: label, frame: frame).render(centeredViewport(area, min(area.width, label.size + 4), 1), buffer)
    }
}

/** 绘制表示加载中内容的占位行。 */
public class Skeleton <: Widget {
    private let rows: Int64
    private let style: ?Style

    /** 创建控件。
     * @param rows 占位行数，负值按零处理
     * @param style 占位行样式
     */
    public init(rows!: Int64 = 3, style!: ?Style = None) {
        this.rows = max(0, rows)
        this.style = style
    }

    /** 按可用高度绘制占位行。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let style = widgetRoleStyle(this.style, buffer.resolveTheme(Option<Theme>.None), ThemeRole.Disabled, Style(fg: Color.Indexed(8)))
        let count = min(rows, area.height)
        for (row in 0..count) {
            let width = max(1, area.width - row % 3)
            buffer.setString(area.x, area.y + row, repeat("-", min(area.width, width)), style: style)
        }
    }
}

/** 按语义状态显示单行提示。 */
public class InlineAlert <: Widget {
    private let message: String
    private let state: StyleState

    /** 创建控件。
     * @param message 提示文本
     * @param state 语义样式状态
     */
    public init(message: String, state!: StyleState = StyleState.Accent) {
        this.message = message
        this.state = state
    }

    /** 在首行绘制提示文本。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let fallback = match (state) {
            case StyleState.Error => Style(fg: Color.Red)
            case StyleState.Disabled => Style(fg: Color.Indexed(8))
            case StyleState.Selected => Style(fg: Color.Green)
            case StyleState.Focused => Style(fg: Color.Cyan)
            case StyleState.Accent => Style(fg: Color.Yellow)
            case StyleState.Normal => Style.default()
        }
        let role = match (state) {
            case StyleState.Error => ThemeRole.Error
            case StyleState.Disabled => ThemeRole.Disabled
            case StyleState.Selected => ThemeRole.Selected
            case StyleState.Focused => ThemeRole.Focused
            case StyleState.Accent => ThemeRole.Accent
            case StyleState.Normal => ThemeRole.Normal
        }
        let style = widgetRoleStyle(Option<Style>.None, buffer.resolveTheme(Option<Theme>.None), role, fallback)
        buffer.setString(area.x, area.y, truncate(message, area.width, options: buffer.textWidthOptions()), style: style)
    }
}

/** 绘制单行方括号标签；空标签显示为“[]”，仅为可见文本设置样式。 */
public class Badge <: Widget {
    private let label: String
    private let style: ?Style
    private let theme: ?Theme

    /** 保存标签及绘制样式；提供主题时，显式样式会修补 normal 角色。
     * @param label 标签文本
     * @param style 可选样式
     * @param theme 可选语义主题
     */
    public init(label: String, style!: ?Style = None, theme!: ?Theme = None) {
        this.label = label
        this.style = style
        this.theme = theme
    }

    /** 只在区域首行绘制可见的 [label] 文本，并裁剪到指定区域。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let resolvedStyle = widgetRoleStyle(style, buffer.resolveTheme(theme), ThemeRole.Normal, Style.default())
        buffer.withCanvasClip(Rect(area.x, area.y, area.width, 1)) { =>
            buffer.setString(area.x, area.y, "[", style: resolvedStyle)
            if (area.width > 1) {
                buffer.setString(area.x + 1, area.y, label, style: resolvedStyle)
                let labelWidth = displayWidthFast(label, options: buffer.textWidthOptions())
                if (labelWidth < area.width - 1) {
                    buffer.setString(area.x + 1 + labelWidth, area.y, "]", style: resolvedStyle)
                }
            }
        }
    }
}

func renderBar(area: Rect, buffer: Buffer, left: String, center: String, right: String, style: Style): Unit {
    if (area.width <= 0 || area.height <= 0) { return }
    buffer.fillLine(area.y, area.x, area.width, style: style)
    if (!left.isEmpty()) {
        buffer.setString(area.x, area.y, truncate(left, area.width, options: buffer.textWidthOptions()), style: style)
    }
    if (!center.isEmpty()) {
        let text = truncate(center, area.width, options: buffer.textWidthOptions())
        buffer.setString(alignedX(area, displayWidthFast(text, options: buffer.textWidthOptions()), TextAlign.Center), area.y, text, style: style)
    }
    if (!right.isEmpty()) {
        let text = truncate(right, area.width, options: buffer.textWidthOptions())
        buffer.setString(area.right - displayWidthFast(text, options: buffer.textWidthOptions()), area.y, text, style: style)
    }
}

func renderCenteredLines(area: Rect, buffer: Buffer, lines: Array<String>, style: Style): Unit {
    if (area.width <= 0 || area.height <= 0) { return }
    let count = min(lines.size, area.height)
    let startY = area.y + max(0, (area.height - count) / 2)
    for (i in 0..count) {
        if (lines[i].isEmpty()) { continue }
        let text = truncate(lines[i], area.width, options: buffer.textWidthOptions())
        buffer.setString(alignedX(Rect(area.x, startY + i, area.width, 1), displayWidthFast(text, options: buffer.textWidthOptions()), TextAlign.Center), startY + i, text, style: style)
    }
}
