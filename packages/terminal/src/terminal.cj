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
    // A standalone parse drops an unfinished control prefix at end of input.
    // TerminalScreen owns a parser instance to preserve it across feed calls.
    AnsiParser().feed(text)
}

class AnsiParser {
    private var mode: Int64 = 0 // text, ESC, CSI, control string, string ESC, intermediate
    private var sequence = ""

    func feed(text: String): Array<AnsiToken> {
        let out = ArrayList<AnsiToken>()
        var offset: Int64 = 0
        while (offset < text.size) {
            let b = text[offset]
            if (mode == 0) {
                if (b == 0x1B) {
                    mode = 1
                    sequence = "\u{1B}"
                    offset++
                } else {
                    let start = offset
                    while (offset < text.size && text[offset] != 0x1B) { offset++ }
                    out.add(AnsiToken(AnsiTokenKind.Text, text: text[start..offset]))
                }
            } else if (mode == 3 || mode == 4) {
                // OSC/DCS payloads are ignored without retaining their bytes.
                if (b == 0x07 || (mode == 4 && b == b'\\')) { mode = 0 }
                else { mode = if (b == 0x1B) { 4 } else { 3 } }
                offset++
            } else if (b == 0x1B) {
                mode = 1
                sequence = "\u{1B}"
                offset++
            } else if (mode == 1 && b == b'[') {
                sequence += "["
                mode = 2
                offset++
            } else if (mode == 1 && (b == b']' || b == b'P' || b == b'X' || b == b'^' || b == b'_')) {
                sequence = ""
                mode = 3
                offset++
            } else if ((mode == 2 && b >= 0x40 && b <= 0x7E) || ((mode == 1 || mode == 5) && b >= 0x30 && b <= 0x7E)) {
                if (!sequence.isEmpty()) {
                    sequence += text[offset..offset + 1]
                    let kind = if (mode != 2) { AnsiTokenKind.Control }
                        else if (b == b'm') { AnsiTokenKind.Sgr }
                        else if (b == b'H' || b == b'f') { AnsiTokenKind.Cursor }
                        else if (b == b'J' || b == b'K') { AnsiTokenKind.Erase }
                        else { AnsiTokenKind.Control }
                    out.add(AnsiToken(kind, text: sequence))
                }
                mode = 0
                sequence = ""
                offset++
            } else if (b >= 0x20 && b <= 0x3F) {
                if (sequence.size >= 4096) { sequence = "" }
                else if (!sequence.isEmpty()) { sequence += text[offset..offset + 1] }
                if (mode == 1) { mode = 5 }
                offset++
            } else {
                // Invalid control: resume text at the current character boundary.
                mode = 0
                sequence = ""
            }
        }
        out.toArray()
    }
}

public class TerminalScreen {
    public let cols: Int64
    public let rows: Int64
    private let buffer: Buffer
    private var cursorX: Int64 = 0
    private var cursorY: Int64 = 0
    private var style: Style = Style.default()
    private let parser = AnsiParser()
    private var wrapPending: Bool = false

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
        for (token in parser.feed(text)) {
            apply(token)
        }
    }

    public func render(area: Rect, target: Buffer): Unit {
        let width = min(area.width, cols)
        let height = min(area.height, rows)
        target.blitFrom(buffer, Rect(0, 0, width, height), area.x, area.y)
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
                wrapPending = false
                offset++
            } else if (b == b'\n') {
                newline()
                offset++
            } else if (b == 0x08) {
                wrapPending = false
                cursorX = max(0, cursorX - 1)
                offset++
            } else {
                let next = nextUtf8(bytes, offset)
                let textPart = unsafe { String.fromUtf8Unchecked(bytes[offset..next]) }
                let width = displayWidth(textPart)
                if (width > 0 && (wrapPending || cursorX + width > cols)) { newline() }
                buffer.setString(cursorX, cursorY, textPart, style: style)
                cursorX += width
                if (cursorX >= cols) {
                    cursorX = cols - 1
                    wrapPending = true
                }
                offset = next
            }
        }
    }

    private func newline(): Unit {
        wrapPending = false
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
            wrapPending = false
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
        wrapPending = false
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
        for (row in 0..min(area.height, transcript.screen.rows)) {
            var line = ""
            let starts = ArrayList<Int64>()
            let ends = ArrayList<Int64>()
            let columns = ArrayList<Int64>()
            for (x in 0..min(area.width, transcript.screen.cols)) {
                let cell = transcript.screen.cell(x, row)
                match (cell.kind) { case CellKind.WideCont => continue; case _ => () }
                starts.add(line.size)
                line += if (cell.symbol.isEmpty()) { " " } else { cell.symbol }
                ends.add(line.size)
                columns.add(x)
            }
            var start: Int64 = 0
            while (start < line.size) {
                let found = findTerminalText(line, search, start)
                if (found < 0) { break }
                for (i in 0..columns.size) {
                    if (starts[i] >= found + search.size || ends[i] <= found) { continue }
                    let x = columns[i]
                    let original = transcript.screen.cell(x, row)
                    let width: Int64 = match (original.kind) { case CellKind.WideLead => 2; case _ => 1 }
                    if (width <= area.width - x) {
                        // setString updates a wide lead and its continuation atomically.
                        buffer.setString(area.x + x, area.y + row, original.symbol, style: original.style.withBg(Color.Yellow))
                    }
                }
                start = found + max(1, search.size)
            }
        }
    }
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
            current = min(current, 1000000) * 10 + Int64(b - b'0')
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
    let bytes = unsafe { text.rawData() }
    let wanted = unsafe { needle.rawData() }
    var i = max(0, start)
    while (i + needle.size <= text.size) {
        var matches = true
        for (j in 0..wanted.size) {
            if (bytes[i + j] != wanted[j]) { matches = false; break }
        }
        if (matches) { return i }
        i++
    }
    -1
}
