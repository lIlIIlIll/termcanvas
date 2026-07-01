package terminal

import core.*
import std.collection.*

public enum AnsiTokenKind {
    | Text
    | Sgr
    | Cursor
    | Erase
    | Control
}

public class AnsiToken {
    public let kind: AnsiTokenKind
    public let text: String

    public init(kind: AnsiTokenKind, text!: String = "") {
        this.kind = kind
        this.text = text
    }
}

public func parseAnsi(text: String): Array<AnsiToken> {
    let out = ArrayList<AnsiToken>()
    let bytes = unsafe { text.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        if (bytes[offset] == 0x1B && offset + 1 < bytes.size && bytes[offset + 1] == b'[') {
            let end = csiEnd(bytes, offset + 2)
            if (end > offset) {
                let seq = unsafe { String.fromUtf8Unchecked(bytes[offset..end + 1]) }
                let final = bytes[end]
                if (final == b'm') {
                    out.add(AnsiToken(AnsiTokenKind.Sgr, text: seq))
                } else if (final == b'H' || final == b'f') {
                    out.add(AnsiToken(AnsiTokenKind.Cursor, text: seq))
                } else if (final == b'J' || final == b'K') {
                    out.add(AnsiToken(AnsiTokenKind.Erase, text: seq))
                } else {
                    out.add(AnsiToken(AnsiTokenKind.Control, text: seq))
                }
                offset = end + 1
            } else {
                offset++
            }
        } else {
            let start = offset
            while (offset < bytes.size && bytes[offset] != 0x1B) {
                offset++
            }
            out.add(AnsiToken(AnsiTokenKind.Text, text: unsafe { String.fromUtf8Unchecked(bytes[start..offset]) }))
        }
    }
    out.toArray()
}

public class TerminalScreen {
    public let cols: Int64
    public let rows: Int64
    private let buffer: Buffer
    private var cursorX: Int64 = 0
    private var cursorY: Int64 = 0
    private var style: Style = Style.default()

    public init(cols!: Int64 = 80, rows!: Int64 = 24) {
        this.cols = max(1, cols)
        this.rows = max(1, rows)
        buffer = Buffer(Rect(0, 0, this.cols, this.rows))
    }

    public func cell(x: Int64, y: Int64): Cell {
        buffer.getCell(x, y)
    }

    public func lineText(y: Int64): String {
        var out = ""
        if (y < 0 || y >= rows) { return out }
        for (x in 0..cols) {
            let symbol = buffer.getCell(x, y).symbol
            out += if (symbol.isEmpty()) { " " } else { symbol }
        }
        out
    }

    public func feed(text: String): Unit {
        for (token in parseAnsi(text)) {
            apply(token)
        }
    }

    public func render(area: Rect, target: Buffer): Unit {
        let width = min(area.width, cols)
        let height = min(area.height, rows)
        for (y in 0..height) {
            for (x in 0..width) {
                target.setCell(area.x + x, area.y + y, buffer.getCell(x, y))
            }
        }
    }

    private func apply(token: AnsiToken): Unit {
        match (token.kind) {
            case AnsiTokenKind.Text => writeText(token.text)
            case AnsiTokenKind.Sgr => applySgr(token.text)
            case AnsiTokenKind.Erase => applyErase(token.text)
            case AnsiTokenKind.Cursor => applyCursor(token.text)
            case AnsiTokenKind.Control => ()
        }
    }

    private func writeText(text: String): Unit {
        let bytes = unsafe { text.rawData() }
        var offset: Int64 = 0
        while (offset < bytes.size) {
            let b = bytes[offset]
            if (b == b'\r') {
                cursorX = 0
                offset++
            } else if (b == b'\n') {
                newline()
                offset++
            } else if (b == 0x08) {
                cursorX = max(0, cursorX - 1)
                offset++
            } else {
                let next = nextUtf8(bytes, offset)
                let textPart = unsafe { String.fromUtf8Unchecked(bytes[offset..next]) }
                buffer.setString(cursorX, cursorY, textPart, style: style)
                cursorX += displayWidth(textPart)
                if (cursorX >= cols) {
                    newline()
                }
                offset = next
            }
        }
    }

    private func newline(): Unit {
        cursorX = 0
        cursorY++
        if (cursorY >= rows) {
            scrollUp()
            cursorY = rows - 1
        }
    }

    private func scrollUp(): Unit {
        for (y in 1..rows) {
            for (x in 0..cols) {
                buffer.setCell(x, y - 1, buffer.getCell(x, y))
            }
        }
        for (x in 0..cols) {
            buffer.setCell(x, rows - 1, Cell(" "))
        }
    }

    private func applySgr(seq: String): Unit {
        let params = csiParams(seq)
        if (params.size == 0) {
            style = Style.default()
            return
        }
        for (param in params) {
            match (param) {
                case 0 => style = Style.default()
                case 1 => style = style.withModifier(Modifier.strong())
                case 22 => style = style.withModifier(Modifier.none())
                case 39 => style = style.withFg(Color.Reset)
                case 49 => style = style.withBg(Color.Reset)
                case 30 => style = style.withFg(Color.Black)
                case 31 => style = style.withFg(Color.Red)
                case 32 => style = style.withFg(Color.Green)
                case 33 => style = style.withFg(Color.Yellow)
                case 34 => style = style.withFg(Color.Blue)
                case 35 => style = style.withFg(Color.Magenta)
                case 36 => style = style.withFg(Color.Cyan)
                case 37 => style = style.withFg(Color.White)
                case 40 => style = style.withBg(Color.Black)
                case 41 => style = style.withBg(Color.Red)
                case 42 => style = style.withBg(Color.Green)
                case 43 => style = style.withBg(Color.Yellow)
                case 44 => style = style.withBg(Color.Blue)
                case 45 => style = style.withBg(Color.Magenta)
                case 46 => style = style.withBg(Color.Cyan)
                case 47 => style = style.withBg(Color.White)
                case 90 => style = style.withFg(Color.Indexed(8))
                case 91 => style = style.withFg(Color.Indexed(9))
                case 92 => style = style.withFg(Color.Indexed(10))
                case 93 => style = style.withFg(Color.Indexed(11))
                case 94 => style = style.withFg(Color.Indexed(12))
                case 95 => style = style.withFg(Color.Indexed(13))
                case 96 => style = style.withFg(Color.Indexed(14))
                case 97 => style = style.withFg(Color.Indexed(15))
                case 100 => style = style.withBg(Color.Indexed(8))
                case 101 => style = style.withBg(Color.Indexed(9))
                case 102 => style = style.withBg(Color.Indexed(10))
                case 103 => style = style.withBg(Color.Indexed(11))
                case 104 => style = style.withBg(Color.Indexed(12))
                case 105 => style = style.withBg(Color.Indexed(13))
                case 106 => style = style.withBg(Color.Indexed(14))
                case 107 => style = style.withBg(Color.Indexed(15))
                case _ => ()
            }
        }
    }

    private func applyErase(seq: String): Unit {
        if (seq.endsWith("K")) {
            for (x in cursorX..cols) {
                buffer.setCell(x, cursorY, Cell(" "))
            }
        } else if (seq.endsWith("J")) {
            for (y in 0..rows) {
                for (x in 0..cols) {
                    buffer.setCell(x, y, Cell(" "))
                }
            }
            cursorX = 0
            cursorY = 0
        }
    }

    private func applyCursor(seq: String): Unit {
        let params = csiParams(seq)
        if (params.size >= 2) {
            cursorY = clampInt(params[0] - 1, 0, rows - 1)
            cursorX = clampInt(params[1] - 1, 0, cols - 1)
        } else {
            cursorX = 0
            cursorY = 0
        }
    }
}

public class TerminalTranscript {
    public let screen: TerminalScreen
    private let chunks = ArrayList<String>()
    public let maxChunks: Int64
    public var followTail: Bool

    public init(cols!: Int64 = 80, rows!: Int64 = 24, maxChunks!: Int64 = 10000, followTail!: Bool = true) {
        screen = TerminalScreen(cols: cols, rows: rows)
        this.maxChunks = max(1, maxChunks)
        this.followTail = followTail
    }

    public func append(text: String): Unit {
        chunks.add(text)
        while (chunks.size > maxChunks) { chunks.remove(at: 0) }
        screen.feed(text)
    }

    public func chunkCount(): Int64 {
        chunks.size
    }
}

public class TerminalView <: Widget {
    private let transcript: TerminalTranscript
    private let block: ?Block
    private let search: String

    public init(transcript: TerminalTranscript, block!: ?Block = None, search!: String = "") {
        this.transcript = transcript
        this.block = block
        this.search = search
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        transcript.screen.render(target, buffer)
        renderSearch(target, buffer)
    }

    private func renderSearch(area: Rect, buffer: Buffer): Unit {
        if (search.isEmpty()) { return }
        for (row in 0..area.height) {
            let line = transcript.screen.lineText(row)
            var start: Int64 = 0
            while (start < line.size) {
                let found = findTerminalText(line, search, start)
                if (found < 0) { break }
                for (x in found..min(area.width, found + search.size)) {
                    let cell = buffer.getCell(area.x + x, area.y + row)
                    buffer.setCell(area.x + x, area.y + row, Cell(cell.symbol, style: cell.style.withBg(Color.Yellow)))
                }
                start = found + max(1, search.size)
            }
        }
    }
}

func csiEnd(bytes: Array<Byte>, start: Int64): Int64 {
    var i = start
    while (i < bytes.size) {
        let b = bytes[i]
        if (b >= 0x40 && b <= 0x7E) { return i }
        i++
    }
    -1
}

func csiParams(seq: String): Array<Int64> {
    let out = ArrayList<Int64>()
    var current: Int64 = 0
    var hasDigit = false
    let bytes = unsafe { seq.rawData() }
    var i: Int64 = 2
    while (i < bytes.size) {
        let b = bytes[i]
        if (b >= b'0' && b <= b'9') {
            current = current * 10 + Int64(b - b'0')
            hasDigit = true
        } else if (b == b';') {
            out.add(if (hasDigit) { current } else { 0 })
            current = 0
            hasDigit = false
        } else {
            if (hasDigit) { out.add(current) }
            return out.toArray()
        }
        i++
    }
    if (hasDigit) { out.add(current) }
    out.toArray()
}

func nextUtf8(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset >= bytes.size) { return bytes.size }
    let first = bytes[offset]
    let width: Int64 = if (first < 0x80) {
        1
    } else if ((first & 0xE0) == 0xC0) {
        2
    } else if ((first & 0xF0) == 0xE0) {
        3
    } else if ((first & 0xF8) == 0xF0) {
        4
    } else {
        1
    }
    min(bytes.size, offset + width)
}

func clampInt(value: Int64, low: Int64, high: Int64): Int64 {
    if (value < low) { low } else if (value > high) { high } else { value }
}

func findTerminalText(text: String, needle: String, start: Int64): Int64 {
    var i = max(0, start)
    while (i + needle.size <= text.size) {
        if (text[i..i + needle.size] == needle) { return i }
        i++
    }
    -1
}
