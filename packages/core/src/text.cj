package core

import std.collection.*

const ESC: String = "\u{1B}"

public func displayWidth(text: String): Int64 {
    var width: Int64 = 0
    let bytes = unsafe { text.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        width += displayWidth(r)
        offset += len
    }
    width
}

public func displayWidth(r: Rune): Int64 {
    let code = UInt32(r)
    if (code == 0 || code < 32 || (code >= 0x7Fu32 && code < 0xA0u32)) {
        return 0
    }
    if ((code >= 0x0300u32 && code <= 0x036Fu32) ||
        (code >= 0x1AB0u32 && code <= 0x1AFFu32) ||
        (code >= 0x1DC0u32 && code <= 0x1DFFu32) ||
        (code >= 0x20D0u32 && code <= 0x20FFu32) ||
        (code >= 0xFE00u32 && code <= 0xFE0Fu32)) {
        return 0
    }
    if ((code >= 0x1100u32 && code <= 0x115Fu32) ||
        (code >= 0x2329u32 && code <= 0x232Au32) ||
        (code >= 0x2E80u32 && code <= 0xA4CFu32) ||
        (code >= 0xAC00u32 && code <= 0xD7A3u32) ||
        (code >= 0xF900u32 && code <= 0xFAFFu32) ||
        (code >= 0xFE10u32 && code <= 0xFE19u32) ||
        (code >= 0xFE30u32 && code <= 0xFE6Fu32) ||
        (code >= 0xFF00u32 && code <= 0xFF60u32) ||
        (code >= 0xFFE0u32 && code <= 0xFFE6u32) ||
        (code >= 0x1F300u32 && code <= 0x1FAFFu32)) {
        return 2
    }
    1
}

func wrapText(text: String, width: Int64, mode: WrapMode): Array<String> {
    let lines = ArrayList<String>()
    if (width <= 0) { return lines.toArray() }
    var start: Int64 = 0
    var offset: Int64 = 0
    let bytes = unsafe { text.rawData() }
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        if (r == r'\n') {
            appendWrappedLine(text[start..offset], width, mode, lines)
            start = offset + len
        }
        offset += len
    }
    appendWrappedLine(text[start..], width, mode, lines)
    lines.toArray()
}

func appendWrappedLine(text: String, width: Int64, mode: WrapMode, lines: ArrayList<String>): Unit {
    match (mode) {
        case NoWrap =>
            lines.add(text)
        case Character =>
            appendCharacterWrappedLine(text, width, lines)
        case Word =>
            appendWordWrappedLine(text, width, lines)
    }
}

func appendCharacterWrappedLine(text: String, width: Int64, lines: ArrayList<String>): Unit {
    if (text.isEmpty()) {
        lines.add("")
        return
    }
    var current = ""
    var currentWidth: Int64 = 0
    let bytes = unsafe { text.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        let part = runeToString(r)
        let partWidth = displayWidth(r)
        if (partWidth > 0 && currentWidth > 0 && currentWidth + partWidth > width) {
            lines.add(current)
            current = ""
            currentWidth = 0
        }
        current += part
        currentWidth += partWidth
        offset += len
    }
    lines.add(current)
}

func appendWordWrappedLine(text: String, width: Int64, lines: ArrayList<String>): Unit {
    let words = splitAsciiWords(text)
    if (words.size == 0) {
        lines.add("")
        return
    }
    var current = ""
    var currentWidth: Int64 = 0
    for (word in words) {
        let wordWidth = displayWidth(word)
        if (wordWidth > width) {
            if (!current.isEmpty()) {
                lines.add(current)
                current = ""
                currentWidth = 0
            }
            appendCharacterWrappedLine(word, width, lines)
        } else if (current.isEmpty()) {
            current = word
            currentWidth = wordWidth
        } else if (currentWidth + 1 + wordWidth <= width) {
            current += " " + word
            currentWidth += 1 + wordWidth
        } else {
            lines.add(current)
            current = word
            currentWidth = wordWidth
        }
    }
    if (!current.isEmpty()) {
        lines.add(current)
    }
}

func splitAsciiWords(text: String): Array<String> {
    let words = ArrayList<String>()
    var current = ""
    let bytes = unsafe { text.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        if (r == r' ' || r == r'\t') {
            if (!current.isEmpty()) {
                words.add(current)
                current = ""
            }
        } else {
            current += runeToString(r)
        }
        offset += len
    }
    if (!current.isEmpty()) {
        words.add(current)
    }
    words.toArray()
}

func alignedX(area: Rect, lineWidth: Int64, align: TextAlign): Int64 {
    let extra = max(0, area.width - lineWidth)
    match (align) {
        case Left => area.x
        case Center => area.x + extra / 2
        case Right => area.x + extra
    }
}

func styleToAnsi(style: Style): String {
    let parts = ArrayList<String>()
    parts.add("0")
    match (style.fg) {
        case Reset => ()
        case Black => parts.add("30")
        case Red => parts.add("31")
        case Green => parts.add("32")
        case Yellow => parts.add("33")
        case Blue => parts.add("34")
        case Magenta => parts.add("35")
        case Cyan => parts.add("36")
        case White => parts.add("37")
        case Indexed(v) => parts.add("38;5;${v}")
        case Rgb(r, g, b) => parts.add("38;2;${r};${g};${b}")
    }
    match (style.bg) {
        case Reset => ()
        case Black => parts.add("40")
        case Red => parts.add("41")
        case Green => parts.add("42")
        case Yellow => parts.add("43")
        case Blue => parts.add("44")
        case Magenta => parts.add("45")
        case Cyan => parts.add("46")
        case White => parts.add("47")
        case Indexed(v) => parts.add("48;5;${v}")
        case Rgb(r, g, b) => parts.add("48;2;${r};${g};${b}")
    }
    if (style.modifier.bold) { parts.add("1") }
    if (style.modifier.italic) { parts.add("3") }
    if (style.modifier.underline) { parts.add("4") }
    if (style.modifier.reversed) { parts.add("7") }
    "${ESC}[" + join(parts.toArray(), ";") + "m"
}

func colorEquals(a: Color, b: Color): Bool {
    match ((a, b)) {
        case (Reset, Reset) => true
        case (Black, Black) => true
        case (Red, Red) => true
        case (Green, Green) => true
        case (Yellow, Yellow) => true
        case (Blue, Blue) => true
        case (Magenta, Magenta) => true
        case (Cyan, Cyan) => true
        case (White, White) => true
        case (Indexed(x), Indexed(y)) => x == y
        case (Rgb(ar, ag, ab), Rgb(br, bg, bb)) => ar == br && ag == bg && ab == bb
        case _ => false
    }
}

func truncate(text: String, maxWidth: Int64): String {
    if (maxWidth <= 0) { return "" }
    let out = StringBuilder()
    var width: Int64 = 0
    let bytes = unsafe { text.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        let w = displayWidth(r)
        if (width + w > maxWidth) { break }
        out.append(r)
        width += w
        offset += len
    }
    out.toString()
}

func clampToRuneBoundary(text: String, offset: Int64): Int64 {
    let target = clamp(offset, 0, text.size)
    let bytes = unsafe { text.rawData() }
    var pos: Int64 = 0
    var last: Int64 = 0
    while (pos < bytes.size && pos <= target) {
        last = pos
        let (_, len) = Rune.fromUtf8(bytes, pos)
        pos += len
    }
    if (target == text.size) { text.size } else { last }
}

func previousRuneOffset(text: String, offset: Int64): Int64 {
    let target = clampToRuneBoundary(text, offset)
    if (target <= 0) { return 0 }
    let bytes = unsafe { text.rawData() }
    var pos: Int64 = 0
    var prev: Int64 = 0
    while (pos < target) {
        prev = pos
        let (_, len) = Rune.fromUtf8(bytes, pos)
        pos += len
    }
    prev
}

func nextRuneOffset(text: String, offset: Int64): Int64 {
    let target = clampToRuneBoundary(text, offset)
    if (target >= text.size) { return text.size }
    let bytes = unsafe { text.rawData() }
    let (_, len) = Rune.fromUtf8(bytes, target)
    min(text.size, target + len)
}

func splitLines(text: String): Array<String> {
    let lines = ArrayList<String>()
    var start: Int64 = 0
    var offset: Int64 = 0
    let bytes = unsafe { text.rawData() }
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        if (r == r'\n') {
            lines.add(text[start..offset])
            start = offset + len
        }
        offset += len
    }
    lines.add(text[start..])
    lines.toArray()
}

func cursorLine(text: String, offset: Int64): Int64 {
    let target = clampToRuneBoundary(text, offset)
    var line: Int64 = 0
    let bytes = unsafe { text.rawData() }
    var pos: Int64 = 0
    while (pos < target) {
        let (r, len) = Rune.fromUtf8(bytes, pos)
        if (r == r'\n') { line++ }
        pos += len
    }
    line
}

func lineStart(text: String, offset: Int64): Int64 {
    let target = clampToRuneBoundary(text, offset)
    var start: Int64 = 0
    let bytes = unsafe { text.rawData() }
    var pos: Int64 = 0
    while (pos < target) {
        let (r, len) = Rune.fromUtf8(bytes, pos)
        if (r == r'\n') { start = pos + len }
        pos += len
    }
    start
}

func lineEnd(text: String, offset: Int64): Int64 {
    let target = clampToRuneBoundary(text, offset)
    let bytes = unsafe { text.rawData() }
    var pos = target
    while (pos < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, pos)
        if (r == r'\n') { return pos }
        pos += len
    }
    text.size
}

func offsetAtLineColumn(text: String, line: Int64, column: Int64): Int64 {
    let bytes = unsafe { text.rawData() }
    var pos: Int64 = 0
    var currentLine: Int64 = 0
    while (pos < bytes.size && currentLine < line) {
        let (r, len) = Rune.fromUtf8(bytes, pos)
        pos += len
        if (r == r'\n') { currentLine++ }
    }
    var width: Int64 = 0
    while (pos < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, pos)
        if (r == r'\n') { return pos }
        let w = displayWidth(r)
        if (width + w > column) { return pos }
        width += w
        pos += len
    }
    pos
}

func runeToString(r: Rune): String {
    let builder = StringBuilder()
    builder.append(r)
    builder.toString()
}

func join(items: Array<String>, sep: String): String {
    let builder = StringBuilder()
    for (i in 0..items.size) {
        if (i > 0) { builder.append(sep) }
        builder.append(items[i])
    }
    builder.toString()
}

func repeat(text: String, count: Int64): String {
    let builder = StringBuilder()
    for (_ in 0..count) {
        builder.append(text)
    }
    builder.toString()
}

func splitInts(text: String): Array<Int64> {
    let result = ArrayList<Int64>()
    var current: Int64 = 0
    var hasDigits = false
    let bytes = unsafe { text.rawData() }
    for (b in bytes) {
        if (b >= b'0' && b <= b'9') {
            current = current * 10 + Int64(b - b'0')
            hasDigits = true
        } else if (b == b';') {
            if (hasDigits) { result.add(current) }
            current = 0
            hasDigits = false
        }
    }
    if (hasDigits) { result.add(current) }
    result.toArray()
}

func clamp(v: Int64, lo: Int64, hi: Int64): Int64 {
    min(max(v, lo), hi)
}

func min(a: Int64, b: Int64): Int64 { if (a < b) { a } else { b } }
func max(a: Int64, b: Int64): Int64 { if (a > b) { a } else { b } }

func readUInt16(bytes: Array<UInt8>, offset: Int64): UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

func readUInt32(bytes: Array<UInt8>, offset: Int64): UInt32 {
    UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
}

func writeUInt32(bytes: Array<UInt8>, offset: Int64, value: UInt32): Unit {
    bytes[offset] = UInt8(value & 0xFFu32)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFFu32)
    bytes[offset + 2] = UInt8((value >> 16) & 0xFFu32)
    bytes[offset + 3] = UInt8((value >> 24) & 0xFFu32)
}
