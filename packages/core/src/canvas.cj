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
        this.clip = clip
        this.dx = translateX
        this.dy = translateY
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
        for (y in target.y..target.bottom) {
            buffer.setString(target.x, y, repeat(" ", target.width), style: style)
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
        let tx = x + dx
        let ty = y + dy
        if (ty < clip.y || ty >= clip.bottom || tx >= clip.right) { return }
        if (tx >= clip.x) {
            buffer.setString(tx, ty, truncate(text, clip.right - tx), style: style)
        } else {
            var dropped: Int64 = 0
            var byteOffset: Int64 = 0
            for (r in text.runes()) {
                let w = displayWidth(r)
                if (dropped + w <= clip.x - tx) {
                    dropped += w
                    byteOffset += r.toString().size
                }
            }
            if (byteOffset < text.size) {
                buffer.setString(clip.x, ty, truncate(text[byteOffset..], clip.width), style: style)
            }
        }
    }

    public func drawSprite(x: Int64, y: Int64, lines: Array<String>, style: Style): Unit {
        for (row in 0..lines.size) {
            drawText(x, y + row, lines[row], style)
        }
    }

    public func composite(surface: Surface): Unit {
        let source = surface.bufferView()
        let target = intersect(clip, surface.area)
        for (y in target.y..target.bottom) {
            for (x in target.x..target.right) {
                buffer.setCell(x, y, source.getCell(x, y))
            }
        }
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
