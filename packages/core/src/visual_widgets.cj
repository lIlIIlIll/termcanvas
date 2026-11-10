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
    /** 将限制在零与总量之间的当前值换算为百分比；空间不足时使用紧凑格式。
     */
    | Percent
    /** 将限制在零与总量之间的当前值作为进度文字。
     */
    | Value
    /** 以“当前值/总量”的形式生成进度文字；当前值限制在零与总量之间。
     */
    | Ratio
    /** 使用所携带的字符串作为进度文字。
     * @param _0 标签文字
     */
    | Text(String)
}

/** 选择标签相对于轨道的位置；Automatic 保持水平右侧、垂直上方。 */
public enum ProgressBarLabelPosition {
    /** 水平进度条显示在右侧，垂直进度条显示在上方。 */
    | Automatic
    /** 水平左侧或垂直上方。 */
    | Start
    /** 水平右侧或垂直下方。 */
    | End
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
     * @param filled 已填充部分符号
     * @param empty 未填充部分符号
     * @param head 填充前端符号
     * @param indeterminate 不确定进度符号
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
        let result = if (unicode) { ProgressBarSymbols(filled: "━", empty: "─", head: "━", indeterminate: "━") }
        else { ProgressBarSymbols(filled: "=", empty: "-", head: "=", indeterminate: "=") }
        result.autoSelect = true
        result
    }

    func isAutomatic(): Bool { autoSelect }

    // The lengths are UTF-8 byte lengths, so delimiters in symbols remain unambiguous.
    func serialize(): String {
        let aBytes = unsafe { filled.rawData() }
        let bBytes = unsafe { empty.rawData() }
        let cBytes = unsafe { head.rawData() }
        let dBytes = unsafe { indeterminate.rawData() }
        let a = aBytes.size
        let b = bBytes.size
        let c = cBytes.size
        let d = dBytes.size
        "${a}:${filled}${b}:${empty}${c}:${head}${d}:${indeterminate}"
    }

    func usableFor(unicode: Bool, options: TextWidthOptions): Bool {
        for (symbol in [filled, empty, head, indeterminate]) {
            if (displayWidth(symbol, options: options) != 1) { return false }
            for (byte in unsafe { symbol.rawData() }) {
                if (byte < 32u8 || byte == 127u8 || (!unicode && byte >= 128u8)) { return false }
            }
        }
        true
    }
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
     * @param value 分段数值
     * @param style 分段样式
     * @param symbol 分段符号
     */
    public init(value: Int64, style!: Style = Style(fg: Color.Cyan), symbol!: String = "#") {
        this.value = max(0, value)
        this.style = style
        this.symbol = symbol
    }
}

/** 可显示确定或不确定进度、分段及标签的进度条。 */
public class ProgressBar <: Widget {
    private let value: Int64
    private let total: Int64
    private let label: String
    private let style: ?Style
    private let fillStyle: ?Style
    private let theme: ?Theme
    private let direction: ProgressBarDirection
    private let labelMode: ProgressBarLabelMode
    private let labelStyle: ?Style
    private let labelPosition: ProgressBarLabelPosition
    private let trackOverride: StyleOverride
    private let fillOverride: StyleOverride
    private let labelOverride: StyleOverride
    private let symbols: ProgressBarSymbols
    private let segments: Array<ProgressBarSegment>
    private let indeterminate: Bool
    private let phase: Int64

    /** 创建进度条，当前值至少保存为零，总量至少保存为一。显式符号优先于主题符号；主题符号须符合终端能力及单列宽度，否则自动回退。
     * 默认水平标签位于轨道右侧、垂直标签位于上方；可用 labelPosition 改变位置。
     * 窄区域优先保留百分比，其他过长标签以省略号代替。省略样式时继承主题，覆盖可显式清除背景。
     * @param value 当前值
     * @param total 总量，至少为一
     * @param label 附加标签
     * @param style 可选轨道样式
     * @param fillStyle 可选填充样式
     * @param theme 可选主题
     * @param direction 绘制方向
     * @param labelMode 进度文字模式
     * @param labelStyle 可选标签样式
     * @param symbols 轨道符号
     * @param segments 可选的进度分段
     * @param indeterminate 是否显示不确定进度
     * @param phase 不确定进度动画帧序号
     * @param labelPosition 标签位置
     * @param trackOverride 轨道逐属性覆盖
     * @param fillOverride 填充逐属性覆盖
     * @param labelOverride 标签逐属性覆盖
     */
    public init(
        value: Int64,
        total!: Int64 = 100,
        label!: String = "",
        style!: ?Style = None,
        fillStyle!: ?Style = None,
        theme!: ?Theme = None,
        direction!: ProgressBarDirection = ProgressBarDirection.Horizontal,
        labelMode!: ProgressBarLabelMode = ProgressBarLabelMode.Hidden,
        labelStyle!: ?Style = None,
        symbols!: ProgressBarSymbols = ProgressBarSymbols.automatic(),
        segments!: Array<ProgressBarSegment> = [],
        indeterminate!: Bool = false,
        phase!: Int64 = 0,
        labelPosition!: ProgressBarLabelPosition = ProgressBarLabelPosition.Automatic,
        trackOverride!: StyleOverride = StyleOverride(),
        fillOverride!: StyleOverride = StyleOverride(),
        labelOverride!: StyleOverride = StyleOverride()
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
        this.labelPosition = labelPosition
        this.trackOverride = trackOverride
        this.fillOverride = fillOverride
        this.labelOverride = labelOverride
        this.symbols = symbols
        this.segments = segments
        this.indeterminate = indeterminate
        this.phase = max(0, phase)
    }

    /** 在指定区域绘制组件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.withCanvasClip(area) { =>
            let resolved = resolveSymbols(buffer)
            match (direction) {
                case ProgressBarDirection.Horizontal => renderHorizontal(area, buffer, resolved)
                case ProgressBarDirection.Vertical => renderVertical(area, buffer, resolved)
            }
        }
    }

    private func resolveSymbols(buffer: Buffer): ProgressBarSymbols {
        if (!symbols.isAutomatic()) { return symbols }
        match (buffer.resolveTheme(theme)) {
            case Some(t) =>
                match (t.progressSymbols) {
                    case Some(candidate) =>
                        if (candidate.usableFor(buffer.capabilities().unicode, buffer.textWidthOptions())) { return candidate }
                    case None => ()
                }
            case None => ()
        }
        symbols.resolve(buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions()))
    }

    private func renderHorizontal(area: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        let text = displayLabel(area.width, buffer.capabilities().unicode, buffer.textWidthOptions())
        let textWidth = displayWidth(text, options: buffer.textWidthOptions())
        let labelWidth = min(area.width, textWidth)
        let trackWidth = if (textWidth == 0) { area.width } else { max(0, area.width - textWidth - 1) }
        let atStart = match (labelPosition) { case ProgressBarLabelPosition.Start => true; case _ => false }
        let trackX = if (atStart && textWidth > 0) { area.right - trackWidth } else { area.x }
        let track = Rect(trackX, area.y, trackWidth, 1)
        buffer.setString(track.x, track.y, repeat(symbols.empty, track.width), style: trackStyle(buffer))
        if (indeterminate) {
            renderHorizontalIndeterminate(track, buffer, symbols)
        } else if (segments.size > 0) {
            renderHorizontalSegments(track, buffer, symbols)
        } else {
            let filled = scaledChartHeight(clamp(value, 0, total), track.width, total)
            if (filled > 0) {
                _ = buffer.writeStringClipped(track.x, track.y, repeat(symbols.filled, filled), maxWidth: filled, style: filledStyle(buffer))
                if (filled < track.width && !symbols.head.isEmpty()) {
                    _ = buffer.writeStringClipped(track.x + filled - 1, track.y, symbols.head, maxWidth: 1, style: filledStyle(buffer))
                }
            } else if (value > 0 && track.width > 0) {
                let mark = if (symbols.isAutomatic() && buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { "╺" } else { symbols.filled }
                _ = buffer.writeStringClipped(track.x, track.y, mark, maxWidth: 1, style: filledStyle(buffer))
            }
        }
        if (labelWidth > 0) {
            let x = if (atStart) { area.x } else { area.right - textWidth }
            buffer.setString(x, area.y, text, style: resolvedLabelStyle(buffer, x, area.y))
        }
    }

    private func renderHorizontalIndeterminate(area: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        if (area.width <= 0) { return }
        let fill = filledStyle(buffer)
        let window = max(1, area.width / 3)
        let span = area.width + window
        let start = phase % span
        for (i in 0..window) {
            let x = area.x + start - window + i
            if (x >= area.x && x < area.right) {
                _ = buffer.writeStringClipped(x, area.y, symbols.indeterminate, maxWidth: 1, style: fill)
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
                _ = buffer.writeStringClipped(x, area.y, repeat(segment.symbol, clipped), maxWidth: clipped, style: themedAccent(segment.style, buffer.resolveTheme(theme)))
                x += clipped
                used += clipped
            }
        }
        if (used == 0 && value > 0) {
            let scaled = scaledChartHeight(clamp(value, 0, total), area.width, total)
            let filled = min(area.width, max(1, scaled))
            let mark = if (scaled == 0 && symbols.isAutomatic() && buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { "╺" } else { symbols.filled }
            _ = buffer.writeStringClipped(area.x, area.y, repeat(mark, filled), maxWidth: filled, style: filledStyle(buffer))
        }
    }

    private func renderVertical(original: Rect, buffer: Buffer, symbols: ProgressBarSymbols): Unit {
        let text = displayLabel(original.width, buffer.capabilities().unicode, buffer.textWidthOptions())
        let atEnd = match (labelPosition) { case ProgressBarLabelPosition.End => true; case _ => false }
        let area = if (text.isEmpty()) { original } else {
            Rect(original.x, original.y + if (atEnd) { 0 } else { 1 }, original.width, max(0, original.height - 1))
        }
        if (!text.isEmpty()) {
            let y = if (atEnd) { original.bottom - 1 } else { original.y }
            buffer.setString(original.x, y, text, style: resolvedLabelStyle(buffer, original.x, y))
        }
        if (area.height <= 0) { return }
        let track = trackStyle(buffer)
        let fill = filledStyle(buffer)
        for (row in 0..area.height) {
            buffer.setString(area.x, area.y + row, repeat(symbols.empty, area.width), style: track)
        }
        if (indeterminate) {
            let window = max(1, area.height / 3)
            let span = area.height + window
            let start = phase % span
            for (i in 0..window) {
                let y = area.bottom - 1 - start + i
                if (y >= area.y && y < area.bottom) {
                    buffer.setString(area.x, y, repeat(symbols.indeterminate, area.width), style: fill)
                }
            }
        } else {
            let filled = scaledChartHeight(clamp(value, 0, total), area.height, total)
            for (row in 0..filled) {
                let y = area.bottom - 1 - row
                buffer.setString(area.x, y, repeat(symbols.filled, area.width), style: fill)
            }
            if (filled == 0 && value > 0) {
                let mark = if (symbols.isAutomatic() && buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { "▁" } else { symbols.filled }
                _ = buffer.writeStringClipped(area.x, area.bottom - 1, repeat(mark, area.width), maxWidth: area.width, style: fill)
            }
        }
    }

    private func trackStyle(buffer: Buffer): Style {
        let base = match (buffer.resolveTheme(theme)) { case Some(t) => t.secondary; case None => Style(fg: Color.Indexed(8)) }
        trackOverride.apply(match (style) { case Some(s) => base.patch(s); case None => base })
    }

    private func filledStyle(buffer: Buffer): Style {
        let base = match (buffer.resolveTheme(theme)) { case Some(t) => t.accent; case None => Style(fg: Color.Cyan) }
        fillOverride.apply(match (fillStyle) { case Some(s) => base.patch(s); case None => base })
    }

    private func resolvedLabelStyle(buffer: Buffer, x: Int64, y: Int64): Style {
        var base = match (buffer.resolveTheme(theme)) { case Some(t) => t.normal; case None => Style(fg: Color.White) }
        // A label does not introduce a background patch over its surrounding surface.
        base.bg = buffer.getCell(x, y).style.bg
        labelOverride.apply(match (labelStyle) { case Some(s) => base.patch(s); case None => base })
    }

    private func displayLabel(width: Int64, unicode: Bool, options: TextWidthOptions): String {
        let text = progressLabel()
        if (displayWidth(text, options: options) <= width) { return text }
        if (label.isEmpty()) {
            match (labelMode) {
                case ProgressBarLabelMode.Percent =>
                    let percent = scaledChartHeight(clamp(value, 0, total), 100, total)
                    let compact = if (value > 0 && percent == 0) { "<1%" } else { "${percent}%" }
                    if (displayWidth(compact, options: options) <= width) { return compact }
                    if (value > 0 && percent == 0) {
                        if (width >= 2) { return "<1" }
                        if (width == 1) { return "<" }
                    }
                    let digits = "${percent}"
                    if (displayWidth(digits, options: options) <= width) { return digits }
                case _ => ()
            }
        }
        progressClippedLabel(text, width, unicode, options)
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

func progressClippedLabel(text: String, width: Int64, unicode: Bool, options: TextWidthOptions): String {
    if (displayWidth(text, options: options) <= width) { return text }
    if (width <= 0) { return "" }
    let ellipsis = if (unicode && !usesWideAmbiguous(options)) { "…" } else { "." }
    ellipsis
}

/** 以单行符号显示数据趋势，可选择最新或最早的可见样本。 */
public class Sparkline <: Widget {
    private let values: Array<Int64>
    private let maxValue: Int64
    private let style: ?Style
    private let block: ?Block
    private let latest: Bool
    private let symbols: ?Array<String>

    /** 创建趋势图；最大值非正时根据可见样本计算。
     * @param values 按顺序排列的样本
     * @param maxValue 缩放上限
     * @param style 可选样式
     * @param block 可选外围区块
     * @param latest 是否优先显示末尾样本
     * @param symbols 可选等级符号
     */
    public init(values: Array<Int64>, maxValue!: Int64 = 0, style!: ?Style = None, block!: ?Block = None,
        latest!: Bool = true, symbols!: ?Array<String> = None) {
        this.values = values
        this.maxValue = max(0, maxValue)
        this.style = style
        this.block = block
        this.latest = latest
        this.symbols = symbols
    }

    /** 在指定区域绘制组件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0 || values.size == 0) { return }
        let paint = visualContextStyle(buffer, style, ThemeRole.Accent, Style(fg: Color.Cyan))
        let bars = match (symbols) {
            case Some(custom) => if (custom.size > 0) { custom } else { [" "] }
            case None => if (buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"] } else { [" ", ".", "-", "=", "#"] }
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
            _ = buffer.writeStringClipped(target.x + i, target.y, bars[level], maxWidth: 1, style: paint)
        }
    }
}

/** 进度条的简化包装，使用当前值、总量和可选标签。 */
public class Gauge <: Widget {
    private let value: Int64
    private let total: Int64
    private let label: String
    private let style: ?Style
    private let fillStyle: ?Style

    /** 创建简化进度组件；当前值负数置零，总量至少为一。
     * @param value 当前值
     * @param total 总量
     * @param label 标签
     * @param style 可选轨道样式
     * @param fillStyle 可选填充样式
     */
    public init(
        value: Int64,
        total!: Int64 = 100,
        label!: String = "",
        style!: ?Style = None,
        fillStyle!: ?Style = None
    ) {
        this.value = max(0, value)
        this.total = max(1, total)
        this.label = label
        this.style = style
        this.fillStyle = fillStyle
    }

    /** 在指定区域绘制组件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        let hasTheme = buffer.resolveTheme(None).isSome()
        let track = if (hasTheme || style.isSome()) { style } else { Some(Style(fg: Color.Indexed(8))) }
        let fill = if (hasTheme || fillStyle.isSome()) { fillStyle } else { Some(Style(fg: Color.Green)) }
        ProgressBar(value, total: total, label: label, style: track, fillStyle: fill).render(area, buffer)
    }
}

/** 按样本顺序绘制柱状图；可见柱至少占一行。 */
public class Chart <: Widget {
    private let values: Array<Int64>
    private let block: ?Block
    private let style: ?Style
    private let maxValue: Int64

    /** 创建柱状图；最大值非正时根据样本计算。
     * @param values 按顺序排列的样本
     * @param block 可选外围区块
     * @param style 可选样式
     * @param maxValue 缩放上限
     */
    public init(
        values: Array<Int64>,
        block!: ?Block = None,
        style!: ?Style = None,
        maxValue!: Int64 = 0
    ) {
        this.values = values
        this.block = block
        this.style = style
        this.maxValue = max(0, maxValue)
    }

    /** 在指定区域绘制组件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0 || values.size == 0) { return }
        let paint = visualContextStyle(buffer, style, ThemeRole.Accent, Style(fg: Color.Cyan))
        let maxV = max(1, if (maxValue > 0) { maxValue } else { maxArray(values) })
        let count = min(target.width, values.size)
        for (i in 0..count) {
            let height = max(1, scaledChartHeight(clamp(values[i], 0, maxV), target.height, maxV))
            for (dy in 0..height) {
                buffer.setString(target.x + i, target.bottom - 1 - dy, "#", style: paint)
            }
        }
    }
}

/** 显示文本行的只读日志视图。 */
public class LogView <: Widget {
    private let lines: Array<String>
    /** 首行偏移；负数表示显示末尾内容。 */
    public var offset: Int64
    private let block: ?Block
    private let style: Style

    /** 创建日志视图。
     * @param lines 日志行
     * @param offset 首行偏移；负数跟随末尾
     * @param block 可选外围区块
     * @param style 文本样式
     */
    public init(lines: Array<String>, offset!: Int64 = -1, block!: ?Block = None, style!: Style = Style.default()) {
        this.lines = lines
        this.offset = offset
        this.block = block
        this.style = style
    }

    /** 在指定区域绘制组件。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let start = if (offset < 0) { max(0, lines.size - target.height) } else { clamp(offset, 0, max(0, lines.size - target.height)) }
        let paint = themedNormal(style, buffer.resolveTheme(None))
        for (row in 0..min(target.height, lines.size - start)) {
            buffer.setString(target.x, target.y + row, truncate(lines[start + row], target.width, options: buffer.textWidthOptions()), style: paint)
        }
    }
}

private func visualContextStyle(buffer: Buffer, style: ?Style, role: ThemeRole, fallback: Style): Style {
    match (buffer.resolveTheme(None)) {
        case Some(theme) => themeRoleStyle(match (style) { case Some(value) => value; case None => Style.default() }, role, Some(theme))
        case None => match (style) { case Some(value) => value; case None => fallback }
    }
}
