package markdown_adapter

import core.{Color, Modifier, Style}
import std.collection.*

// All offsets in configuration and code literals are UTF-8 bytes.
class SyntaxDelimiter {
    let open: String
    let close: String
    let escape: String
    let kind: CodeTokenKind
    let nested: Bool
    let multiline: Bool
    init(open: String, close: String, kind: CodeTokenKind, escape!: String = "",
        nested!: Bool = false, multiline!: Bool = false) {
        this.open = open
        this.close = close
        this.kind = kind
        this.escape = escape
        this.nested = nested
        this.multiline = multiline
    }
}

class SyntaxRule {
    let canonical: String
    let builtin: Bool
    var aliasCount: Int64 = 0
    let words = HashMap<String, CodeTokenKind>()
    let styles = HashMap<String, Style>()
    let delimiters = ArrayList<SyntaxDelimiter>()
    let openers = HashMap<Byte, Array<SyntaxDelimiter>>()
    var numbers = "decimal"
    var hasNumbers = false

    init(canonical: String, builtin: Bool) {
        this.canonical = canonical
        this.builtin = builtin
    }

    func compileOpeners(): Unit {
        // At most 64 rules per language; sort once, not for every token.
        for (delimiter in delimiters) {
            let key = delimiter.open[0]
            let previous: Array<SyntaxDelimiter> = match (openers.get(key)) { case Some(entries) => entries; case None => [] }
            let ordered = ArrayList<SyntaxDelimiter>()
            var inserted = false
            for (entry in previous) {
                if (!inserted && delimiter.open.size > entry.open.size) {
                    ordered.add(delimiter)
                    inserted = true
                }
                ordered.add(entry)
            }
            if (!inserted) { ordered.add(delimiter) }
            _ = openers.add(key, ordered.toArray())
        }
    }

    func wordKind(word: String): ?CodeTokenKind { words.get(word) }
    func overlay(kind: CodeTokenKind): ?Style { styles.get(syntaxKindName(kind)) }
}

public class SyntaxHighlightConfig {
    private let names: HashMap<String, SyntaxRule>
    init(names: HashMap<String, SyntaxRule>) { this.names = names }
    func resolve(name: String): ?SyntaxRule { names.get(name) }
}

func syntaxKindName(kind: CodeTokenKind): String {
    match (kind) {
        case CodeTokenKind.Keyword => "keyword"
        case CodeTokenKind.TypeName => "type"
        case CodeTokenKind.StringLiteral => "string"
        case CodeTokenKind.Number => "number"
        case CodeTokenKind.Comment => "comment"
        case CodeTokenKind.Directive => "directive"
        case CodeTokenKind.Variable => "variable"
        case CodeTokenKind.Property => "property"
    }
}

func syntaxError(line: Int64, reason: String): Nothing {
    throw IllegalArgumentException("syntax config line ${line}: ${reason}")
}

func syntaxSpace(ch: Byte): Bool { ch == b' ' || ch == b'\t' }

func syntaxArguments(text: String, line: Int64): Array<String> {
    let result = ArrayList<String>()
    var i: Int64 = 0
    while (i < text.size) {
        while (i < text.size && syntaxSpace(text[i])) { i++ }
        if (i == text.size) { break }
        let bytes = ArrayList<Byte>()
        if (text[i] == b'"') {
            i++
            var closed = false
            while (i < text.size) {
                if (text[i] == b'"') { i++; closed = true; break }
                if (text[i] == b'\\') {
                    i++
                    if (i == text.size) { syntaxError(line, "unfinished escape") }
                    let decoded = match (text[i]) {
                        case b'\\' => b'\\'
                        case b'"' => b'"'
                        case b'n' => b'\n'
                        case b'r' => b'\r'
                        case b't' => b'\t'
                        case _ => syntaxError(line, "unknown escape")
                    }
                    bytes.add(decoded)
                } else { bytes.add(text[i]) }
                i++
            }
            if (!closed) { syntaxError(line, "unclosed quoted argument") }
            if (i < text.size && !syntaxSpace(text[i])) { syntaxError(line, "missing argument separator") }
        } else {
            while (i < text.size && !syntaxSpace(text[i])) {
                if (text[i] == b'"' || text[i] == b'\\') { syntaxError(line, "quote or backslash requires quoted argument") }
                bytes.add(text[i])
                i++
            }
        }
        result.add(String.fromUtf8(bytes.toArray()))
    }
    result.toArray()
}

func syntaxName(raw: String, line: Int64): String {
    if (raw.size == 0 || raw.size > 64 || !syntaxAsciiLetter(raw[0])) { syntaxError(line, "invalid language name") }
    let bytes = ArrayList<Byte>()
    for (i in 0..raw.size) {
        let ch = raw[i]
        if (!syntaxAsciiLetter(ch) && !codeDigit(ch) && ch != b'_' && ch != b'+' && ch != b'.' && ch != b'-') {
            syntaxError(line, "invalid language name")
        }
        bytes.add(if (ch >= b'A' && ch <= b'Z') { ch + 32 } else { ch })
    }
    String.fromUtf8(bytes.toArray())
}
func syntaxAsciiLetter(ch: Byte): Bool { (ch >= b'A' && ch <= b'Z') || (ch >= b'a' && ch <= b'z') }

func syntaxWord(word: String, line: Int64): Unit {
    if (word.size == 0 || word.size > 256 || !codeWordStart(word[0])) { syntaxError(line, "invalid identifier") }
    for (i in 0..word.size) {
        let ch = word[i]
        if (!codeWordPart(ch) || ch == 0x7F || (ch < 0x20)) { syntaxError(line, "invalid identifier") }
    }
}

func syntaxDelimiter(value: String, line: Int64): Unit {
    if (value.size == 0 || value.size > 64) { syntaxError(line, "delimiter must be 1 to 64 bytes") }
    for (i in 0..value.size) { if (value[i] < 0x20 || value[i] == 0x7F) { syntaxError(line, "invalid delimiter") } }
}

func syntaxHex(ch: Byte, line: Int64): Int64 {
    if (codeDigit(ch)) { return Int64(ch - b'0') }
    if (ch >= b'a' && ch <= b'f') { return Int64(ch - b'a') + 10 }
    if (ch >= b'A' && ch <= b'F') { return Int64(ch - b'A') + 10 }
    syntaxError(line, "invalid color")
}
func syntaxColor(raw: String, line: Int64): Color {
    match (raw) {
        case "inherit" => return Color.Reset
        case "black" => return Color.Black
        case "red" => return Color.Red
        case "green" => return Color.Green
        case "yellow" => return Color.Yellow
        case "blue" => return Color.Blue
        case "magenta" => return Color.Magenta
        case "cyan" => return Color.Cyan
        case "white" => return Color.White
        case _ => ()
    }
    if (raw.size == 7 && raw[0] == b'#') {
        let r = syntaxHex(raw[1], line) * 16 + syntaxHex(raw[2], line)
        let g = syntaxHex(raw[3], line) * 16 + syntaxHex(raw[4], line)
        let b = syntaxHex(raw[5], line) * 16 + syntaxHex(raw[6], line)
        return Color.Rgb(UInt8(r), UInt8(g), UInt8(b))
    }
    if (raw.startsWith("indexed:") && raw.size > 8) {
        var value: Int64 = 0
        for (i in 8..raw.size) {
            if (!codeDigit(raw[i])) { syntaxError(line, "invalid color") }
            value = value * 10 + Int64(raw[i] - b'0')
            if (value > 255) { syntaxError(line, "invalid color") }
        }
        return Color.Indexed(UInt8(value))
    }
    syntaxError(line, "invalid color")
}

func syntaxArity(args: Array<String>, low: Int64, high: Int64, line: Int64): Unit {
    if (args.size < low || args.size > high) { syntaxError(line, "wrong argument count") }
}

public func parseSyntaxHighlightConfig(text: String): SyntaxHighlightConfig {
    if (text.size > 256 * 1024) { syntaxError(1, "configuration exceeds 256 KiB") }
    let names = HashMap<String, SyntaxRule>()
    let targets = HashMap<String, SyntaxRule>()
    var active: ?SyntaxRule = None
    var header = false
    var count: Int64 = 0
    var line: Int64 = 1
    var start: Int64 = if (codeAt(text, 0, "\u{FEFF}")) { 3 } else { 0 }
    while (start < text.size) {
        var end = start
        while (end < text.size && text[end] != b'\n' && text[end] != b'\r') {
            if ((text[end] < 0x20 && text[end] != b'\t') || text[end] == 0x7F) { syntaxError(line, "control character") }
            end++
        }
        var content = start
        while (content < end && syntaxSpace(text[content])) { content++ }
        let args: Array<String> = if (content < end && text[content] == b'#') { [] } else { syntaxArguments(text[start..end], line) }
        if (args.size > 0 && !args[0].startsWith("#")) {
            let command = args[0]
            if (!header) {
                if (args.size != 2 || command != "syntax" || args[1] != "1") { syntaxError(line, "expected syntax 1 header") }
                header = true
            } else if (command == "syntax") { syntaxError(line, "duplicate header") }
            else if (command == "end") {
                syntaxArity(args, 1, 1, line)
                if (let Some(rule) <- active) { rule.compileOpeners(); active = None }
                else { syntaxError(line, "end outside language") }
            } else if (command == "language" || command == "extend") {
                syntaxArity(args, 2, if (command == "language") { 3 } else { 2 }, line)
                let replacing = args.size == 3
                if (replacing && args[2] != "replace") { syntaxError(line, "expected replace") }
                let name = syntaxName(args[1], line)
                let builtin = codeLanguage(name)
                if ((command == "extend" || replacing) && builtin == "") { syntaxError(line, "unknown built-in language") }
                if (command == "language" && !replacing && builtin != "") { syntaxError(line, "built-in language requires replace") }
                let canonical = if (builtin != "") { builtin } else { name }
                if (targets.contains(canonical) || names.contains(name)) { syntaxError(line, "duplicate language") }
                count++
                if (count > 64) { syntaxError(line, "too many languages") }
                let rule = SyntaxRule(canonical, builtin != "" && command == "extend")
                _ = targets.add(canonical, rule)
                _ = names.add(name, rule)
                if (builtin != "") {
                    // Resolver canonicalizes built-in aliases after the config-specific lookup.
                    _ = names.add(canonical, rule)
                }
                active = Some(rule)
            } else if (let Some(rule) <- active) {
                match (command) {
                    case "aliases" =>
                        syntaxArity(args, 2, 65, line)
                        if (rule.aliasCount + args.size - 1 > 64) { syntaxError(line, "too many aliases") }
                        for (i in 1..args.size) {
                            let alias = syntaxName(args[i], line)
                            if (codeLanguage(alias) != "" || names.contains(alias)) { syntaxError(line, "duplicate or built-in alias") }
                            rule.aliasCount++
                            _ = names.add(alias, rule)
                        }
                    case "keywords" | "types" | "literals" =>
                        syntaxArity(args, 2, 4097, line)
                        if (rule.words.size + args.size - 1 > 4096) { syntaxError(line, "too many words") }
                        for (i in 1..args.size) {
                            let word = args[i]
                            syntaxWord(word, line)
                            if (rule.words.contains(word)) { syntaxError(line, "duplicate word") }
                            _ = rule.words.add(word, if (command == "types") { CodeTokenKind.TypeName } else { CodeTokenKind.Keyword })
                        }
                    case "line-comment" | "block-comment" | "string" =>
                        if (rule.builtin) { syntaxError(line, "extend cannot change delimiters") }
                        syntaxArity(args, if (command == "line-comment") { 2 } else if (command == "block-comment") { 4 } else { 5 },
                            if (command == "line-comment") { 2 } else if (command == "block-comment") { 4 } else { 5 }, line)
                        if (rule.delimiters.size >= 64) { syntaxError(line, "too many delimiters") }
                        let open = args[1]
                        syntaxDelimiter(open, line)
                        for (other in rule.delimiters) { if (other.open == open) { syntaxError(line, "duplicate opener") } }
                        if (command == "line-comment") {
                            rule.delimiters.add(SyntaxDelimiter(open, "", CodeTokenKind.Comment))
                        } else {
                            let close = args[2]
                            syntaxDelimiter(close, line)
                            if (command == "block-comment") {
                                if (args[3] != "flat" && args[3] != "nested") { syntaxError(line, "invalid nesting mode") }
                                if (args[3] == "nested" && open == close) { syntaxError(line, "nested opener equals closer") }
                                rule.delimiters.add(SyntaxDelimiter(open, close, CodeTokenKind.Comment, nested: args[3] == "nested"))
                            } else {
                                let escape = args[3]
                                if (escape.size != 0 && (escape.size != 1 || escape[0] < 0x20 || escape[0] > 0x7E || escape[0] == close[0])) {
                                    syntaxError(line, "invalid string escape")
                                }
                                if (args[4] != "single" && args[4] != "multi") { syntaxError(line, "invalid string mode") }
                                rule.delimiters.add(SyntaxDelimiter(open, close, CodeTokenKind.StringLiteral,
                                    escape: escape, multiline: args[4] == "multi"))
                            }
                        }
                    case "numbers" =>
                        syntaxArity(args, 2, 2, line)
                        if (rule.builtin || rule.hasNumbers) { syntaxError(line, "duplicate or forbidden numbers") }
                        if (!codeListed(args[1], "none decimal cj c cpp js ts py json")) { syntaxError(line, "invalid number profile") }
                        rule.numbers = args[1]
                        rule.hasNumbers = true
                    case "style" =>
                        syntaxArity(args, 3, 7, line)
                        let kind = args[1]
                        if (!codeListed(kind, "keyword type string number comment directive variable property") || rule.styles.contains(kind)) {
                            syntaxError(line, "invalid or duplicate style kind")
                        }
                        let fg = syntaxColor(args[2], line)
                        var modifier = Modifier.none()
                        for (i in 3..args.size) {
                            match (args[i]) {
                                case "bold" => if (modifier.bold) { syntaxError(line, "duplicate modifier") } else { modifier.bold = true }
                                case "italic" => if (modifier.italic) { syntaxError(line, "duplicate modifier") } else { modifier.italic = true }
                                case "underline" => if (modifier.underline) { syntaxError(line, "duplicate modifier") } else { modifier.underline = true }
                                case "reversed" => if (modifier.reversed) { syntaxError(line, "duplicate modifier") } else { modifier.reversed = true }
                                case _ => syntaxError(line, "invalid modifier")
                            }
                        }
                        _ = rule.styles.add(kind, Style(fg: fg, modifier: modifier))
                    case _ => syntaxError(line, "unknown declaration")
                }
            } else { syntaxError(line, "declaration outside language") }
        }
        start = codeNewlineEnd(text, end)
        line++
    }
    if (!header) { syntaxError(line, "missing syntax 1 header") }
    if (active.isSome()) { syntaxError(line, "missing end") }
    SyntaxHighlightConfig(names)
}
