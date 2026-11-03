package core

import std.collection.*

public enum ProgressBarDirection {
    | Horizontal
    | Vertical
}

public enum ProgressBarLabelMode {
    | Hidden
    | Percent
    | Value
    | Ratio
    | Text(String)
}

public class ProgressBarSymbols {
    private var autoSelect: Bool = false
    public let filled: String
    public let empty: String
    public let head: String
    public let indeterminate: String

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

public class ProgressBarSegment {
    public let value: Int64
    public let style: Style
    public let symbol: String

    public init(value: Int64, style!: Style = Style(fg: Color.Cyan), symbol!: String = "#") {
        this.value = max(0, value)
        this.style = style
        this.symbol = symbol
    }
}

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

public class Sparkline <: Widget {
    private let values: Array<Int64>
    private let maxValue: Int64
    private let style: Style
    private let block: ?Block
    private let latest: Bool
    private let symbols: ?Array<String>

    public init(values: Array<Int64>, maxValue!: Int64 = 0, style!: Style = Style(fg: Color.Cyan), block!: ?Block = None,
        latest!: Bool = true, symbols!: ?Array<String> = None) {
        this.values = values
        this.maxValue = max(0, maxValue)
        this.style = style
        this.block = block
        this.latest = latest
        this.symbols = symbols
    }

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

public class Gauge <: Widget {
    private let value: Int64
    private let total: Int64
    private let label: String
    private let style: Style
    private let fillStyle: Style

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

    public func render(area: Rect, buffer: Buffer): Unit {
        ProgressBar(value, total: total, label: label, style: style, fillStyle: fillStyle).render(area, buffer)
    }
}

public class Chart <: Widget {
    private let values: Array<Int64>
    private let block: ?Block
    private let style: Style
    private let maxValue: Int64

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

public class LogView <: Widget {
    private let lines: Array<String>
    public var offset: Int64
    private let block: ?Block
    private let style: Style

    public init(lines: Array<String>, offset!: Int64 = -1, block!: ?Block = None, style!: Style = Style.default()) {
        this.lines = lines
        this.offset = offset
        this.block = block
        this.style = style
    }

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
