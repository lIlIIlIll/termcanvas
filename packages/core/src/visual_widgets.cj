package core

import std.collection.*

/** 区分进度条沿水平方向或垂直方向绘制。
 */
public enum ProgressBarDirection {
    /** 进度条采用水平方向绘制。
     */
    | Horizontal
    /** 进度条采用垂直方向绘制。
     */
    | Vertical
}

/** 区分不显示进度文字、显示百分比、当前值、当前值与总量之比，以及显示指定文字。
 */
public enum ProgressBarLabelMode {
    /** 不生成进度文字。
     */
    | Hidden
    /** 将限制在零与总量之间的当前值换算为两位小数的百分比文字。
     */
    | Percent
    /** 将限制在零与总量之间的当前值作为进度文字。
     */
    | Value
    /** 以“当前值/总量”的形式生成进度文字；当前值限制在零与总量之间。
     */
    | Ratio
    /** 使用所携带的字符串作为进度文字。
     */
    | Text(String)
}

/** 保存进度条已填充部分、未填充部分、前端及不确定进度所用的符号字符串。
 */
public class ProgressBarSymbols {
    private var autoSelect: Bool = false
    /** 表示进度条已填充部分的符号字符串。
     */
    public let filled: String
    /** 表示进度条未填充部分的符号字符串。
     */
    public let empty: String
    /** 表示进度条填充前端的符号字符串。
     */
    public let head: String
    /** 表示不确定进度所用的符号字符串。
     */
    public let indeterminate: String

    /** 按传入字符串保存进度条各部分的符号；省略时已填充部分、前端和不确定进度使用“#”，未填充部分使用“-”。
     */
    public init(filled!: String = "#", empty!: String = "-", head!: String = "#", indeterminate!: String = "#") {
        this.filled = filled
        this.empty = empty
        this.head = head
        this.indeterminate = indeterminate
    }

    static func automatic(): ProgressBarSymbols {
        let result = ProgressBarSymbols()
        result.autoSelect = true
        result
    }

    func resolve(unicode: Bool): ProgressBarSymbols {
        if (!autoSelect) { return this }
        if (unicode) { ProgressBarSymbols(filled: "━", empty: "─", head: "━", indeterminate: "━") }
        else { ProgressBarSymbols(filled: "=", empty: "-", head: "=", indeterminate: "=") }
    }

    func isAutomatic(): Bool { autoSelect }
}

/** 保存一个进度条分段的非负数值、样式和符号。
 */
public class ProgressBarSegment {
    /** 分段保存的数值；构造时负数会被置为零。
     */
    public let value: Int64
    /** 分段保存的显示样式。
     */
    public let style: Style
    /** 分段保存的符号字符串。
     */
    public let symbol: String

    /** 创建分段，将负数值置为零，并保存指定的样式和符号。
     */
    public init(value: Int64, style!: Style = Style(fg: Color.Cyan), symbol!: String = "#") {
        this.value = max(0, value)
        this.style = style
        this.symbol = symbol
    }
}

/** 可在指定区域向缓冲区绘制的进度条组件，支持水平或垂直方向。
 */
public class ProgressBar <: Widget {
    private let value: Int64
    private let total: Int64
    private let label: String
    private let style: Style
    private let fillStyle: Style
    private let theme: ?Theme
    private let direction: ProgressBarDirection
    private let labelMode: ProgressBarLabelMode
    private let labelStyle: Style
    private let symbols: ProgressBarSymbols
    private let segments: Array<ProgressBarSegment>
    private let indeterminate: Bool
    private let phase: Int64

    /** 创建进度条，当前值至少保存为零，总量至少保存为一。默认符号根据缓冲区的终端能力选择，显式符号始终优先。
     * 水平进度标签位于轨道右侧，垂直进度标签位于轨道上方；空间不足时以省略号代替标签。
     *
     * @param value 当前进度值
     * @param total 进度总量，非正数按一处理
     * @param label 非空时覆盖 labelMode 生成的标签
     * @param style 未填充轨道的样式
     * @param fillStyle 已填充轨道的样式
     * @param theme 可选语义主题
     * @param direction 轨道方向
     * @param labelMode 标签的显示内容
     * @param labelStyle 标签样式
     * @param symbols 轨道各部分使用的符号
     * @param segments 可选分段
     * @param indeterminate 是否绘制不确定进度
     * @param phase 不确定进度的动画帧序号
     */
    public init(
        value: Int64,
        total!: Int64 = 100,
        label!: String = "",
        style!: Style = Style(fg: Color.Indexed(8)),
        fillStyle!: Style = Style(fg: Color.Cyan),
        theme!: ?Theme = None,
        direction!: ProgressBarDirection = ProgressBarDirection.Horizontal,
        labelMode!: ProgressBarLabelMode = ProgressBarLabelMode.Hidden,
        labelStyle!: Style = Style(fg: Color.White),
        symbols!: ProgressBarSymbols = ProgressBarSymbols.automatic(),
        segments!: Array<ProgressBarSegment> = [],
        indeterminate!: Bool = false,
        phase!: Int64 = 0
    ) {
        this.value = max(0, value)
        this.total = max(1, total)
        this.label = label
        this.style = style
        this.fillStyle = fillStyle
        this.theme = theme
        this.direction = direction
        this.labelMode = labelMode
        this.labelStyle = labelStyle
        this.symbols = symbols
        this.segments = segments
        this.indeterminate = indeterminate
        this.phase = max(0, phase)
    }

    /** 按设置的方向在缓冲区的指定区域绘制进度条；区域宽或高不大于零时不作绘制。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.withCanvasClip(area) { =>
            let resolved = symbols.resolve(buffer.capabilities().unicode)
            match (direction) {
                case ProgressBarDirection.Horizontal => renderHorizontal(area, buffer, resolved)
                case ProgressBarDirection.Vertical => renderVertical(area, buffer, resolved)
            }
        }
    }

    private func renderHorizontal(area: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        let text = progressLabel()
        let textWidth = displayWidth(text)
        let labelWidth = min(area.width, textWidth)
        let trackWidth = if (textWidth == 0) { area.width } else { max(0, area.width - textWidth - 1) }
        let track = Rect(area.x, area.y, trackWidth, 1)
        buffer.setString(track.x, track.y, repeat(symbols.empty, track.width), style: themedNormal(style, theme))
        if (indeterminate) {
            renderHorizontalIndeterminate(track, buffer, symbols)
        } else if (segments.size > 0) {
            renderHorizontalSegments(track, buffer, symbols)
        } else {
            let filled = scaledChartHeight(clamp(value, 0, total), track.width, total)
            if (filled > 0) {
                _ = buffer.writeStringClipped(track.x, track.y, repeat(symbols.filled, filled), maxWidth: filled, style: themedAccent(fillStyle, theme))
                if (filled < track.width && !symbols.head.isEmpty()) {
                    _ = buffer.writeStringClipped(track.x + filled - 1, track.y, symbols.head, maxWidth: 1, style: themedAccent(fillStyle, theme))
                }
            } else if (value > 0 && track.width > 0) {
                let mark = if (this.symbols.isAutomatic() && buffer.capabilities().unicode) { "╺" } else { symbols.filled }
                _ = buffer.writeStringClipped(track.x, track.y, mark, maxWidth: 1, style: themedAccent(fillStyle, theme))
            }
        }
        if (labelWidth > 0) {
            let displayed = progressClippedLabel(text, area.width, buffer.capabilities().unicode)
            let x = area.right - displayWidth(displayed)
            buffer.setString(x, area.y, displayed, style: themedNormal(labelStyle, theme))
        }
    }

    private func renderHorizontalIndeterminate(area: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        if (area.width <= 0) { return }
        let window = max(1, area.width / 3)
        let span = area.width + window
        let start = phase % span
        for (i in 0..window) {
            let x = area.x + start - window + i
            if (x >= area.x && x < area.right) {
                buffer.setString(x, area.y, symbols.indeterminate, style: themedAccent(fillStyle, theme))
            }
        }
    }

    private func renderHorizontalSegments(area: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        var x = area.x
        var used = 0
        for (segment in segments) {
            if (x >= area.right) { break }
            let width = scaledChartHeight(min(segment.value, total), area.width, total)
            let clipped = min(area.right - x, max(0, width))
            if (clipped > 0) {
                _ = buffer.writeStringClipped(x, area.y, repeat(segment.symbol, clipped), maxWidth: clipped, style: themedAccent(segment.style, theme))
                x += clipped
                used += clipped
            }
        }
        if (used == 0 && value > 0) {
            let scaled = scaledChartHeight(clamp(value, 0, total), area.width, total)
            let filled = min(area.width, max(1, scaled))
            let mark = if (scaled == 0 && this.symbols.isAutomatic() && buffer.capabilities().unicode) { "╺" } else { symbols.filled }
            _ = buffer.writeStringClipped(area.x, area.y, repeat(mark, filled), maxWidth: filled, style: themedAccent(fillStyle, theme))
        }
    }

    private func renderVertical(original: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        let text = progressLabel()
        let area = if (text.isEmpty()) { original } else { Rect(original.x, original.y + 1, original.width, max(0, original.height - 1)) }
        if (!text.isEmpty()) {
            buffer.setString(original.x, original.y, progressClippedLabel(text, original.width, buffer.capabilities().unicode), style: themedNormal(labelStyle, theme))
        }
        if (area.height <= 0) { return }
        for (row in 0..area.height) {
            buffer.setString(area.x, area.y + row, repeat(symbols.empty, area.width), style: themedNormal(style, theme))
        }
        if (indeterminate) {
            let window = max(1, area.height / 3)
            let span = area.height + window
            let start = phase % span
            for (i in 0..window) {
                let y = area.bottom - 1 - start + i
                if (y >= area.y && y < area.bottom) {
                    buffer.setString(area.x, y, repeat(symbols.indeterminate, area.width), style: themedAccent(fillStyle, theme))
                }
            }
        } else {
            let filled = scaledChartHeight(clamp(value, 0, total), area.height, total)
            for (row in 0..filled) {
                let y = area.bottom - 1 - row
                buffer.setString(area.x, y, repeat(symbols.filled, area.width), style: themedAccent(fillStyle, theme))
            }
            if (filled == 0 && value > 0) {
                let mark = if (this.symbols.isAutomatic() && buffer.capabilities().unicode) { "▁" } else { symbols.filled }
                _ = buffer.writeStringClipped(area.x, area.bottom - 1, repeat(mark, area.width), maxWidth: area.width, style: themedAccent(fillStyle, theme))
            }
        }
    }

    private func progressLabel(): String {
        if (!label.isEmpty()) { return label }
        match (labelMode) {
            case ProgressBarLabelMode.Hidden => ""
            case ProgressBarLabelMode.Percent => progressPercent(clamp(value, 0, total), total)
            case ProgressBarLabelMode.Value => "${clamp(value, 0, total)}"
            case ProgressBarLabelMode.Ratio => "${clamp(value, 0, total)}/${total}"
            case ProgressBarLabelMode.Text(text) => text
        }
    }
}

func progressPercent(value: Int64, total: Int64): String {
    let hundredths = scaledChartHeight(value, 10000, total)
    if (value > 0 && hundredths == 0) { return "<0.01%" }
    let rounded = (scaledChartHeight(value, 100000, total) + 5) / 10
    let fraction = rounded % 100
    "${rounded / 100}.${if (fraction < 10) { "0" } else { "" }}${fraction}%"
}

func progressClippedLabel(text: String, width: Int64, unicode: Bool): String {
    if (displayWidth(text) <= width) { return text }
    if (width <= 0) { return "" }
    let ellipsis = if (unicode) { "…" } else { "." }
    ellipsis
}

/** 将数值序列绘制为单行等级字符的组件；可选区块先绘制，序列写入其首个内部行。
 */
public class Sparkline <: Widget {
    private let values: Array<Int64>
    private let maxValue: Int64
    private let style: Style
    private let block: ?Block
    private let latest: Bool
    private let symbols: ?Array<String>

    /** 保存数值序列、最大值、绘制样式和可选区块。最大值小于等于零时自动取可见样本最大值，正值用作等级上限。
     * latest 为 true 时显示最近的样本，false 时显示最早的样本。symbols 可显式提供从低到高的等级符号。
     */
    public init(values: Array<Int64>, maxValue!: Int64 = 0, style!: Style = Style(fg: Color.Cyan), block!: ?Block = None,
        latest!: Bool = true, symbols!: ?Array<String> = None) {
        this.values = values
        this.maxValue = max(0, maxValue)
        this.style = style
        this.block = block
        this.latest = latest
        this.symbols = symbols
    }

    /** 先绘制可选区块，再在其首个内部行或原区域首行绘制等级字符；默认选择最近的可见样本，并按终端能力选择 Unicode 或 ASCII 符号。数量不超过目标宽度和序列长度。区域宽高非正时不绘制数据；序列为空时仍可绘制区块。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0 || values.size == 0) { return }
        let bars = match (symbols) {
            case Some(custom) => if (custom.size > 0) { custom } else { [" "] }
            case None => if (buffer.capabilities().unicode) { [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"] } else { [" ", ".", "-", "=", "#"] }
        }
        let count = min(target.width, values.size)
        let start = if (latest) { values.size - count } else { 0 }
        var maxV = maxValue
        if (maxV <= 0) {
            for (i in 0..count) { maxV = max(maxV, values[start + i]) }
        }
        for (i in 0..count) {
            let sample = clamp(values[start + i], 0, maxV)
            let scaled = if (maxV <= 0) { 0 } else { scaledChartHeight(sample, bars.size - 1, maxV) }
            let level = if (sample > 0 && bars.size > 1) { max(1, scaled) } else { scaled }
            _ = buffer.writeStringClipped(target.x + i, target.y, bars[level], maxWidth: 1, style: style)
        }
    }
}

/** 保存进度值、总量、标签及样式，绘制时将它们交给进度条绘制。
 */
public class Gauge <: Widget {
    private let value: Int64
    private let total: Int64
    private let label: String
    private let style: Style
    private let fillStyle: Style

    /** 创建按进度条方式绘制的组件；负进度值按零保存，总量小于一时按一保存。
     */
    public init(
        value: Int64,
        total!: Int64 = 100,
        label!: String = "",
        style!: Style = Style(fg: Color.Indexed(8)),
        fillStyle!: Style = Style(fg: Color.Green)
    ) {
        this.value = max(0, value)
        this.total = max(1, total)
        this.label = label
        this.style = style
        this.fillStyle = fillStyle
    }

    /** 用保存的进度值、总量、标签和样式创建进度条，并将指定区域与缓冲区交给它绘制。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        ProgressBar(value, total: total, label: label, style: style, fillStyle: fillStyle).render(area, buffer)
    }
}

/** 将数值序列绘制成从底部向上延伸的井号列；非正上限自动缩放，正上限固定尺度并饱和超限样本。
 */
public class Chart <: Widget {
    private let values: Array<Int64>
    private let block: ?Block
    private let style: Style
    private let maxValue: Int64

    /** 保存数值序列、可选区块、绘制样式和最大值；最大值非正时自动取序列最大值，正值用作固定上限。
     */
    public init(
        values: Array<Int64>,
        block!: ?Block = None,
        style!: Style = Style(fg: Color.Cyan),
        maxValue!: Int64 = 0
    ) {
        this.values = values
        this.block = block
        this.style = style
        this.maxValue = max(0, maxValue)
    }

    /** 先绘制可选区块，再在其内部或原区域绘制自底向上的井号列；列数不超过目标宽度和序列长度，每列至少一格。正上限固定尺度并饱和超限样本，非正上限自动缩放；无绘制空间或序列为空时不绘制列。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0 || values.size == 0) { return }
        let maxV = max(1, if (maxValue > 0) { maxValue } else { maxArray(values) })
        let count = min(target.width, values.size)
        for (i in 0..count) {
            let height = max(1, scaledChartHeight(clamp(values[i], 0, maxV), target.height, maxV))
            for (dy in 0..height) {
                buffer.setString(target.x + i, target.bottom - 1 - dy, "#", style: style)
            }
        }
    }
}

/** 按可调整的起始行显示文本行；负偏移量从可容纳的最后一页开始，行内容按可用宽度截短。
 */
public class LogView <: Widget {
    private let lines: Array<String>
    /** 显示文本的起始行偏移量；负值表示从可容纳的最后一页开始，非负值在绘制时限制到有效范围。
     */
    public var offset: Int64
    private let block: ?Block
    private let style: Style

    /** 保存文本行、起始偏移量、可选区块和文字样式；默认偏移量为负值，绘制时显示最后一页。
     */
    public init(lines: Array<String>, offset!: Int64 = -1, block!: ?Block = None, style!: Style = Style.default()) {
        this.lines = lines
        this.offset = offset
        this.block = block
        this.style = style
    }

    /** 先绘制可选区块，再从选定的起始行逐行写入其内部或原区域；负偏移量选择最后一页，非负偏移量限制在有效范围内，每行按区域宽度截短。区域宽高非正时不写入文本。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let start = if (offset < 0) { max(0, lines.size - target.height) } else { clamp(offset, 0, max(0, lines.size - target.height)) }
        for (row in 0..min(target.height, lines.size - start)) {
            buffer.setString(target.x, target.y + row, truncate(lines[start + row], target.width), style: style)
        }
    }
}
