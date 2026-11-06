package core

import std.collection.*

public enum ResizePolicy {
    | Stretch
    | Letterbox
    | Pillarbox
    | Center
}

public struct ViewportFit {
    public let area: Rect
    public let content: Rect
    public let tooSmall: Bool
    public let scaleX: Float64
    public let scaleY: Float64

    public init(area: Rect, content: Rect, tooSmall!: Bool = false, scaleX!: Float64 = 1.0, scaleY!: Float64 = 1.0) {
        this.area = area
        this.content = content
        this.tooSmall = tooSmall
        this.scaleX = scaleX
        this.scaleY = scaleY
    }
}

public class SizeGuard {
    public let minWidth: Int64
    public let minHeight: Int64

    public init(minWidth: Int64, minHeight: Int64) {
        this.minWidth = max(1, minWidth)
        this.minHeight = max(1, minHeight)
    }

    public func fit(area: Rect, policy!: ResizePolicy = ResizePolicy.Center): ViewportFit {
        let tooSmall = area.width < minWidth || area.height < minHeight
        let width = min(area.width, minWidth)
        let height = min(area.height, minHeight)
        let x = area.x + max(0, (area.width - width) / 2)
        let y = area.y + max(0, (area.height - height) / 2)
        match (policy) {
            case ResizePolicy.Stretch => ViewportFit(area, area, tooSmall: tooSmall, scaleX: Float64(area.width) / Float64(minWidth), scaleY: Float64(area.height) / Float64(minHeight))
            case _ => ViewportFit(area, Rect(x, y, width, height), tooSmall: tooSmall)
        }
    }
}

public class Surface {
    public let area: Rect
    public let zIndex: Int64
    private let buffer: Buffer

    public init(area: Rect, zIndex!: Int64 = 0) {
        this.area = area
        this.zIndex = zIndex
        this.buffer = Buffer(area)
    }

    public func canvas(): Canvas {
        Canvas(buffer, area)
    }

    public func bufferView(): Buffer {
        buffer
    }
}

public class Canvas {
    private let buffer: Buffer
    private let clip: Rect
    private let dx: Int64
    private let dy: Int64

    public init(buffer: Buffer, clip: Rect, translateX!: Int64 = 0, translateY!: Int64 = 0) {
        this.buffer = buffer
        this.clip = intersect(buffer.area, clip)
        this.dx = translateX
        this.dy = translateY
    }

    /** 返回画布底层缓冲区采用的文本宽度策略。 */
    public func textWidthOptions(): TextWidthOptions { buffer.textWidthOptions() }

    /** 创建带当前缓冲区视觉上下文快照的独立表面；area 使用缓冲区绝对坐标。
     * 快照包含应用及有效父主题、终端能力和文本宽度策略；后续修改不会自动同步。
     * 示例：`let surface = canvas.createSurface(area)`，绘制后用 `canvas.composite(surface)` 合成。
     * 直接调用 Surface(area) 仍创建具有默认上下文的独立表面。
     */
    public func createSurface(area: Rect, zIndex!: Int64 = 0): Surface {
        let result = Surface(area, zIndex: zIndex)
        result.bufferView().inheritVisualContext(buffer)
        result
    }

    public func withClip(area: Rect): Canvas {
        Canvas(buffer, intersect(clip, area), translateX: dx, translateY: dy)
    }

    public func translated(x: Int64, y: Int64): Canvas {
        Canvas(buffer, clip, translateX: dx + x, translateY: dy + y)
    }

    public func viewport(camera: Position): Canvas {
        translated(-camera.x, -camera.y)
    }

    public func fillRect(area: Rect, style: Style): Unit {
        let target = intersect(clip, Rect(area.x + dx, area.y + dy, area.width, area.height))
        if (target.width <= 0 || target.height <= 0) { return }
        buffer.withCanvasClip(clip) { => buffer.fillRect(target, style: style) }
    }

    public func fillRect(x: Int64, y: Int64, width: Int64, height: Int64, style: Style): Unit {
        fillRect(Rect(x, y, width, height), style)
    }

    public func hline(x: Int64, y: Int64, width: Int64, symbol: String, style: Style): Unit {
        if (width <= 0) { return }
        let target = intersect(clip, Rect(x + dx, y + dy, width, 1))
        if (target.width <= 0 || target.height <= 0) { return }
        buffer.withCanvasClip(clip) { => buffer.hline(target.x, target.y, target.width, symbol, style) }
    }

    public func vline(x: Int64, y: Int64, height: Int64, symbol: String, style: Style): Unit {
        if (height <= 0) { return }
        let target = intersect(clip, Rect(x + dx, y + dy, 1, height))
        if (target.width <= 0 || target.height <= 0) { return }
        let clippedSymbol = truncate(symbol, clip.right - target.x, options: buffer.textWidthOptions())
        buffer.withCanvasClip(clip) { =>
            for (row in target.y..target.bottom) {
                buffer.setString(target.x, row, clippedSymbol, style: style)
            }
        }
    }

    public func strokeRect(area: Rect, style: Style, horizontal!: String = "-", vertical!: String = "|", corner!: String = "+"): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        drawText(area.x, area.y, corner + repeat(horizontal, max(0, area.width - 2)) + if (area.width > 1) { corner } else { "" }, style)
        if (area.height > 1) {
            drawText(area.x, area.y + area.height - 1, corner + repeat(horizontal, max(0, area.width - 2)) + if (area.width > 1) { corner } else { "" }, style)
        }
        for (y in area.y + 1..area.y + max(1, area.height - 1)) {
            drawText(area.x, y, vertical, style)
            if (area.width > 1) { drawText(area.x + area.width - 1, y, vertical, style) }
        }
    }

    /** 使用与 Block 相同的字符集在区域自身边界单元格上绘制边框。 */
    public func strokeBorder(area: Rect, style: Style, border!: ?BorderSet = None): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let chars = match (border) {
            case Some(value) => value
            case None => if (buffer.capabilities().unicode && !usesWideAmbiguous(buffer.textWidthOptions())) { BorderSet.rounded() } else { BorderSet.ascii() }
        }
        let vertical = truncate(chars.vertical, 1, options: buffer.textWidthOptions())
        if (area.height == 1) {
            hline(area.x, area.y, area.width, chars.horizontal, style)
            return
        }
        if (area.width == 1) {
            vline(area.x, area.y, area.height, vertical, style)
            return
        }
        hline(area.x, area.y, area.width, chars.horizontal, style)
        hline(area.x, area.bottom - 1, area.width, chars.horizontal, style)
        vline(area.x, area.y + 1, area.height - 2, vertical, style)
        vline(area.right - 1, area.y + 1, area.height - 2, vertical, style)
        drawText(area.x, area.y, truncate(chars.topLeft, 1, options: buffer.textWidthOptions()), style)
        drawText(area.right - 1, area.y, truncate(chars.topRight, 1, options: buffer.textWidthOptions()), style)
        drawText(area.x, area.bottom - 1, truncate(chars.bottomLeft, 1, options: buffer.textWidthOptions()), style)
        drawText(area.right - 1, area.bottom - 1, truncate(chars.bottomRight, 1, options: buffer.textWidthOptions()), style)
    }

    public func drawLine(x1: Int64, y1: Int64, x2: Int64, y2: Int64, symbol: String, style: Style): Unit {
        var x = x1
        var y = y1
        let sx = if (x1 < x2) { Int64(1) } else { Int64(-1) }
        let sy = if (y1 < y2) { Int64(1) } else { Int64(-1) }
        var err = abs64(x2 - x1) - abs64(y2 - y1)
        var done = false
        while (!done) {
            drawText(x, y, symbol, style)
            if (x == x2 && y == y2) { done = true } else {
                let e2 = err * 2
                if (e2 > -abs64(y2 - y1)) {
                    err -= abs64(y2 - y1)
                    x += sx
                }
                if (e2 < abs64(x2 - x1)) {
                    err += abs64(x2 - x1)
                    y += sy
                }
            }
        }
    }

    public func drawText(x: Int64, y: Int64, text: String, style: Style): Unit {
        buffer.withCanvasClip(clip) { => drawTextClipped(x, y, text, style) }
    }

    private func drawTextClipped(x: Int64, y: Int64, text: String, style: Style): Unit {
        let tx = x + dx
        let ty = y + dy
        if (ty < clip.y || ty >= clip.bottom || tx >= clip.right) { return }
        let bytes = unsafe { text.rawData() }
        if (isPrintableAscii(bytes)) {
            drawAsciiText(tx, ty, text, bytes, style)
            return
        }
        if (tx >= clip.x) {
            buffer.setString(tx, ty, truncate(text, clip.right - tx, options: buffer.textWidthOptions()), style: style)
        } else {
            let hiddenWidth = clip.x - tx
            var droppedWidth: Int64 = 0
            var byteOffset: Int64 = 0
            for (cluster in graphemeClusters(text, options: buffer.textWidthOptions())) {
                if (droppedWidth + cluster.width <= hiddenWidth) {
                    droppedWidth += cluster.width
                    byteOffset = cluster.endOffset
                } else {
                    // A terminal grapheme is atomic. If it crosses the left
                    // clip edge, omit it without shifting following text.
                    if (droppedWidth < hiddenWidth) {
                        droppedWidth += cluster.width
                        byteOffset = cluster.endOffset
                    }
                    break
                }
            }
            let drawX = tx + droppedWidth
            if (byteOffset < text.size && drawX < clip.right) {
                buffer.setString(drawX, ty, truncate(text[byteOffset..], clip.right - drawX, options: buffer.textWidthOptions()), style: style)
            }
        }
    }

    private func drawAsciiText(tx: Int64, ty: Int64, text: String, bytes: Array<UInt8>, style: Style): Unit {
        if (bytes.size == 0) { return }
        var startOffset: Int64 = 0
        var drawX = tx
        if (drawX < clip.x) {
            startOffset = clip.x - drawX
            drawX = clip.x
        }
        if (startOffset >= bytes.size || drawX >= clip.right) { return }
        let maxBytes = min(bytes.size - startOffset, clip.right - drawX)
        if (maxBytes <= 0) { return }
        let out = if (startOffset == 0 && maxBytes == bytes.size) {
            text
        } else {
            text[startOffset..startOffset + maxBytes]
        }
        buffer.writeAsciiSpanUnchecked(drawX, ty, out, style: style)
    }

    public func drawSprite(x: Int64, y: Int64, lines: Array<String>, style: Style): Unit {
        for (row in 0..lines.size) {
            drawText(x, y + row, lines[row], style)
        }
    }

    public func render(widget: Widget, area: Rect): Unit {
        let target = intersect(
            clip,
            Rect(area.x + dx, area.y + dy, area.width, area.height)
        )
        if (target.width <= 0 || target.height <= 0) { return }
        buffer.withCanvasClip(clip) { => widget.render(target, buffer) }
    }

    /** 以表面的缓冲区视图为来源，将表面区域与画布裁剪范围的交集复制到画布缓冲区的相同位置；不使用画布平移量。
     * 来源与目标的文本宽度策略不一致或来源含过时字符时，在任何目标写入前抛出 IllegalArgumentException。
     */
    public func composite(surface: Surface): Unit {
        let source = surface.bufferView()
        let target = intersect(clip, surface.area)
        buffer.withCanvasClip(clip) { => buffer.blitFrom(source, target, target.x, target.y) }
    }
}

public func centeredViewport(area: Rect, width: Int64, height: Int64): Rect {
    let w = min(area.width, max(1, width))
    let h = min(area.height, max(1, height))
    Rect(area.x + max(0, (area.width - w) / 2), area.y + max(0, (area.height - h) / 2), w, h)
}

func intersect(a: Rect, b: Rect): Rect {
    let x1 = max(a.x, b.x)
    let y1 = max(a.y, b.y)
    let x2 = min(a.right, b.right)
    let y2 = min(a.bottom, b.bottom)
    Rect(x1, y1, max(0, x2 - x1), max(0, y2 - y1))
}

func abs64(value: Int64): Int64 {
    if (value < 0) { -value } else { value }
}
