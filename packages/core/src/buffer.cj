package core

import std.collection.*

public struct Cell <: Equatable<Cell> {
    public var symbol: String = " "
    public var style: Style = Style.default()

    public init() {}

    public init(symbol: String, style!: Style = Style.default()) {
        this.symbol = symbol
        this.style = style
    }

    public operator func ==(other: Cell): Bool {
        symbol == other.symbol && style == other.style
    }
}

public class Buffer {
    public let area: Rect
    private let cells: Array<Cell>
    private let media = ArrayList<MediaPlacement>()

    public init(area: Rect) {
        this.area = area
        this.cells = Array<Cell>(area.width * area.height, repeat: Cell())
    }

    public func clear(style!: Style = Style.default()): Unit {
        for (i in 0..cells.size) {
            cells[i] = Cell(" ", style: style)
        }
    }

    func reset(style!: Style = Style.default()): Unit {
        clear(style: style)
        while (media.size > 0) {
            media.remove(at: 0)
        }
    }

    public func indexOf(x: Int64, y: Int64): ?Int64 {
        if (x < area.x || y < area.y || x >= area.right || y >= area.bottom) {
            return None
        }
        return (y - area.y) * area.width + (x - area.x)
    }

    public func setCell(x: Int64, y: Int64, cell: Cell): Unit {
        if (let Some(index) <- indexOf(x, y)) {
            if (cells[index].symbol == "" && x > area.x) {
                setCellRaw(x - 1, y, Cell(" ", style: cells[index].style))
            }
            if (cell.symbol != "" && x + 1 < area.right && getCell(x + 1, y).symbol == "") {
                setCellRaw(x + 1, y, Cell(" "))
            }
            cells[index] = cell
        }
    }

    private func setCellRaw(x: Int64, y: Int64, cell: Cell): Unit {
        if (let Some(index) <- indexOf(x, y)) {
            cells[index] = cell
        }
    }

    public func getCell(x: Int64, y: Int64): Cell {
        if (let Some(index) <- indexOf(x, y)) {
            return cells[index]
        }
        Cell()
    }

    public func setString(x: Int64, y: Int64, text: String, style!: Style = Style.default()): Unit {
        var cx = x
        var offset: Int64 = 0
        let bytes = unsafe { text.rawData() }
        while (offset < bytes.size && cx < area.right) {
            let (r, len) = Rune.fromUtf8(bytes, offset)
            let symbol = runeToString(r)
            let width = displayWidth(r)
            if (width > 0) {
                if (width == 2 && cx + 1 >= area.right) {
                    break
                }
                setCell(cx, y, Cell(symbol, style: style))
                if (width == 2 && cx + 1 < area.right) {
                    setCellRaw(cx + 1, y, Cell("", style: style))
                }
                cx += width
            }
            offset += len
        }
    }

    public func resize(area: Rect): Buffer {
        let next = Buffer(area)
        let right = min(this.area.right, area.right)
        let bottom = min(this.area.bottom, area.bottom)
        for (y in area.y..bottom) {
            for (x in area.x..right) {
                next.setCell(x, y, getCell(x, y))
            }
        }
        next
    }

    public func copy(): Buffer {
        let next = Buffer(area)
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                next.setCell(x, y, getCell(x, y))
            }
        }
        for (placement in media) {
            next.addMedia(placement)
        }
        next
    }

    public func diff(previous: Buffer): Array<DrawOp> {
        let ops = ArrayList<DrawOp>()
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                let cell = getCell(x, y)
                if (previous.area != area || previous.getCell(x, y) != cell) {
                    ops.add(DrawOp(x, y, cell))
                }
            }
        }
        ops.toArray()
    }

    public func addMedia(placement: MediaPlacement): Unit {
        media.add(placement)
    }

    public func mediaPlacements(): Array<MediaPlacement> {
        media.toArray()
    }
}

public struct DrawOp {
    public let x: Int64
    public let y: Int64
    public let cell: Cell

    public init(x: Int64, y: Int64, cell: Cell) {
        this.x = x
        this.y = y
        this.cell = cell
    }
}
