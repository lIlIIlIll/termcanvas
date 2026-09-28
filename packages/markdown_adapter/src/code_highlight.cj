package markdown_adapter

import core.{Color, Modifier, Style, RichSpan, TextDecoration, markdownDecorations}
import markdown.core.{CodeBlockKind, CodeBlockNodeView, NodeRef}
import std.collection.*

enum CodeTokenKind {
    | Keyword
    | TypeName
    | StringLiteral
    | Number
    | Comment
    | Directive
    | Variable
    | Property
}

struct CodeToken {
    let start: Int64
    let end: Int64
    let kind: CodeTokenKind
    init(start: Int64, end: Int64, kind: CodeTokenKind) {
        this.start = start
        this.end = end
        this.kind = kind
    }
}

func codeTokenStyle(kind: CodeTokenKind, base: Style, rule: ?SyntaxRule): Style {
    let overlay = match (kind) {
        case CodeTokenKind.Keyword => Style(fg: Color.Yellow, modifier: Modifier.strong())
        case CodeTokenKind.TypeName | CodeTokenKind.Property | CodeTokenKind.Variable => Style(fg: Color.Cyan)
        case CodeTokenKind.StringLiteral => Style(fg: Color.Green)
        case CodeTokenKind.Number => Style(fg: Color.Yellow)
        case CodeTokenKind.Comment => Style(fg: Color.Indexed(8))
        case CodeTokenKind.Directive => Style(fg: Color.Cyan, modifier: Modifier.strong())
    }
    match (rule) {
        case Some(active) =>
            match (active.overlay(kind)) {
                case Some(user) => base.patch(user)
                case None => base.patch(overlay)
            }
        case None => base.patch(overlay)
    }
}

// Byte indexes here are UTF-8 offsets, not terminal columns. Every unrecognized rune advances intact.
func codeRuneEnd(text: String, at: Int64): Int64 {
    let b = text[at]
    let width: Int64 = if (b < 0x80) { 1 } else if (b < 0xE0) { 2 } else if (b < 0xF0) { 3 } else { 4 }
    min(text.size, at + width)
}
func codeAt(text: String, at: Int64, value: String): Bool {
    if (at < 0 || at + value.size > text.size) { return false }
    for (j in 0..value.size) { if (text[at + j] != value[j]) { return false } }
    true
}
func codeWordStart(ch: Byte): Bool {
    (ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z') || ch == b'_' || ch >= 0x80
}
func codeWordPart(ch: Byte): Bool { codeWordStart(ch) || (ch >= b'0' && ch <= b'9') }
func codeDigit(ch: Byte): Bool { ch >= b'0' && ch <= b'9' }
func codeHex(ch: Byte): Bool { codeDigit(ch) || (ch >= b'a' && ch <= b'f') || (ch >= b'A' && ch <= b'F') }
func normalizeCodeLanguage(raw: String): String {
    var first: Int64 = 0
    var last = raw.size
    while (first < last && (raw[first] == b' ' || raw[first] == b'\t' || raw[first] == b'\r' || raw[first] == b'\n')) { first++ }
    while (last > first && (raw[last - 1] == b' ' || raw[last - 1] == b'\t' || raw[last - 1] == b'\r' || raw[last - 1] == b'\n')) { last-- }
    let bytes = ArrayList<Byte>()
    for (i in first..last) {
        let ch = raw[i]
        bytes.add(if (ch >= b'A' && ch <= b'Z') { ch + 32 } else { ch })
    }
    String.fromUtf8(bytes.toArray())
}
func codeLanguage(out: String): String {
    match (out) {
        case "cj" | "cangjie" => "cj"
        case "c" | "h" => "c"
        case "cpp" | "c++" | "cxx" | "cc" | "hpp" | "hxx" => "cpp"
        case "js" | "javascript" | "mjs" | "cjs" => "js"
        case "ts" | "typescript" => "ts"
        case "py" | "python" | "python3" => "py"
        case "json" => "json"
        case "sh" | "bash" | "shell" | "zsh" => "sh"
        case _ => ""
    }
}

func codeListed(word: String, words: String): Bool {
    // Fixed, whole-identifier lookup; no token-time collection construction.
    var start: Int64 = 0
    for (i in 0..words.size) {
        if (words[i] == b' ') {
            if (i - start == word.size && codeAt(words, start, word)) { return true }
            start = i + 1
        }
    }
    words.size - start == word.size && codeAt(words, start, word)
}

const CJ_KEYWORDS = "package import class interface struct enum extend type func macro main init prop let var const if else match case try catch finally handle for in while do throw return continue break where with this super This spawn synchronized unsafe quote perform resume throwing public private internal protected static override redef abstract sealed open foreign inout mut operator common specific is as get set"
const CJ_TYPES = "Int8 Int16 Int32 Int64 IntNative UInt8 UInt16 UInt32 UInt64 UIntNative Float16 Float32 Float64 Rune Bool Nothing Unit String Byte Int UInt Array VArray Option"
const C_KEYWORDS = "auto break case const continue default do else enum extern for goto if inline register restrict return sizeof static struct switch typedef union volatile while _Alignas _Alignof _Atomic _Generic _Noreturn _Static_assert _Thread_local"
const C_TYPES = "void char short int long float double signed unsigned _Bool _Complex _Imaginary size_t"
const CPP_KEYWORDS = "alignas alignof asm catch class concept consteval constexpr constinit const_cast co_await co_return co_yield decltype delete dynamic_cast explicit export friend mutable namespace new noexcept operator private protected public reinterpret_cast requires static_assert static_cast template this thread_local throw try typeid typename using virtual and or not bitand bitor xor compl and_eq or_eq not_eq xor_eq"
const CPP_TYPES = "bool wchar_t char8_t char16_t char32_t"
const JS_KEYWORDS = "async await break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new of return static super switch this throw try typeof var void while with yield"
const TS_KEYWORDS = "abstract as asserts declare enum implements infer interface is keyof module namespace never out override private protected public readonly require satisfies type unique unknown"
const TS_TYPES = "any bigint boolean number object string symbol undefined unknown never void"
const PY_KEYWORDS = "and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case"
const PY_TYPES = "bool bytes bytearray complex dict float frozenset int list object set str tuple type"
const SH_KEYWORDS = "if then else elif fi for while until do done case esac in function select time coproc repeat end"

func codeIdentifierKind(word: String, lang: String): ?CodeTokenKind {
    let constants = match (lang) {
        case "cj" => "true false"
        case "cpp" => "true false nullptr"
        case "js" | "ts" => "true false null undefined"
        case "py" => "True False None"
        case "json" => "true false null"
        case _ => ""
    }
    if (codeListed(word, constants)) { return Some(CodeTokenKind.Keyword) }
    let types = match (lang) {
        case "cj" => codeListed(word, CJ_TYPES)
        case "c" => codeListed(word, C_TYPES)
        case "cpp" => codeListed(word, C_TYPES) || codeListed(word, CPP_TYPES)
        case "ts" => codeListed(word, TS_TYPES)
        case "py" => codeListed(word, PY_TYPES)
        case _ => false
    }
    if (types) { return Some(CodeTokenKind.TypeName) }
    let keyword = match (lang) {
        case "cj" => codeListed(word, CJ_KEYWORDS)
        case "c" => codeListed(word, C_KEYWORDS)
        case "cpp" => codeListed(word, C_KEYWORDS) || codeListed(word, CPP_KEYWORDS)
        case "js" | "ts" => codeListed(word, JS_KEYWORDS) || (lang == "ts" && codeListed(word, TS_KEYWORDS))
        case "py" => codeListed(word, PY_KEYWORDS)
        case "sh" => codeListed(word, SH_KEYWORDS)
        case _ => false
    }
    if (keyword) { Some(CodeTokenKind.Keyword) } else { None }
}

func codeLineEnd(text: String, from: Int64): Int64 {
    var i = from
    while (i < text.size && text[i] != b'\n' && text[i] != b'\r') { i = codeRuneEnd(text, i) }
    i
}
func codeNewlineEnd(text: String, at: Int64): Int64 {
    if (at < text.size && text[at] == b'\r' && codeAt(text, at + 1, "\n")) { at + 2 }
    else if (at < text.size && (text[at] == b'\r' || text[at] == b'\n')) { at + 1 }
    else { at }
}
func codeCLineCommentEnd(text: String, from: Int64): Int64 {
    var end = codeLineEnd(text, from)
    while (end > from && end < text.size && text[end - 1] == b'\\') {
        end = codeLineEnd(text, codeNewlineEnd(text, end))
    }
    end
}
func codeQuoted(text: String, from: Int64, quoteByte: Byte, triple: Bool, raw: Bool,
    multiline: Bool, interpolated: Bool, braceFormat: Bool): Int64 {
    let opener: Int64 = if (triple) { 3 } else { 1 }
    var i = from + opener
    while (i < text.size) {
        if (!multiline && (text[i] == b'\n' || text[i] == b'\r')) { break }
        if (text[i] == b'\\' && i + 1 < text.size && (!raw || text[i + 1] == quoteByte)) {
            i = if (text[i + 1] == b'\r' || text[i + 1] == b'\n') { codeNewlineEnd(text, i + 1) }
                else { codeRuneEnd(text, i + 1) }
            continue
        }
        if (interpolated && (((text[i] == b'$' && i + 1 < text.size && text[i + 1] == b'{') && !braceFormat) ||
            (braceFormat && text[i] == b'{' && !codeAt(text, i, "{{")))) {
            i = codeInterpolationEnd(text, if (braceFormat) { i } else { i + 1 })
            continue
        }
        if (braceFormat && codeAt(text, i, "{{")) { i += 2; continue }
        if (text[i] == quoteByte && (!triple || (i + 2 < text.size && text[i + 1] == quoteByte && text[i + 2] == quoteByte))) {
            return i + opener
        }
        i = codeRuneEnd(text, i)
    }
    i
}
func codeInterpolationEnd(text: String, opening: Int64): Int64 {
    var depth: Int64 = 1
    var i = opening + 1
    while (i < text.size) {
        if (text[i] == b'\'' || text[i] == b'"' || text[i] == b'`') {
            i = codeQuoted(text, i, text[i], false, false, true, false, false)
        } else if (text[i] == b'{') { depth++; i++ }
        else if (text[i] == b'}') { depth--; i++; if (depth == 0) { return i } }
        else if (text[i] == b'\\' && i + 1 < text.size) { i = codeRuneEnd(text, i + 1) }
        else { i = codeRuneEnd(text, i) }
    }
    i
}
func codeBlockComment(text: String, from: Int64, nested: Bool): Int64 {
    var depth: Int64 = 1
    var i = from + 2
    while (i < text.size) {
        if (nested && codeAt(text, i, "/*")) { depth++; i += 2 }
        else if (codeAt(text, i, "*/")) { depth--; i += 2; if (depth == 0) { return i } }
        else { i = codeRuneEnd(text, i) }
    }
    i
}
func codeRawCj(text: String, from: Int64): Int64 {
    var i = from + 1
    while (i < text.size && text[i] == b'#') { i++ }
    if (i == from + 1 || !codeAt(text, i, "\"")) { return from }
    let hashes = i - from - 1
    i++
    while (i < text.size) {
        if (text[i] == b'\"') {
            var n: Int64 = 0
            while (n < hashes && i + 1 + n < text.size && text[i + 1 + n] == b'#') { n++ }
            if (n == hashes) { return i + 1 + n }
        }
        i = codeRuneEnd(text, i)
    }
    i
}
func codeRawCpp(text: String, from: Int64): Int64 {
    if (!codeAt(text, from, "R\"")) { return from }
    var i = from + 2
    let tag = i
    while (i < text.size && i - tag <= 16 && text[i] != b'(' && text[i] != b'\n' && text[i] != b'\r' && text[i] != b' ') { i++ }
    if (i - tag > 16 || i == text.size || text[i] != b'(') { return from }
    let delimiter = text[tag..i]
    i++
    while (i < text.size) {
        if (text[i] == b')' && codeAt(text, i + 1, delimiter) && codeAt(text, i + 1 + delimiter.size, "\"")) { return i + 2 + delimiter.size }
        i = codeRuneEnd(text, i)
    }
    i
}
func codeRegex(text: String, from: Int64): Int64 {
    var i = from + 1
    var inClass = false
    while (i < text.size && text[i] != b'\n' && text[i] != b'\r') {
        if (text[i] == b'\\') { i = if (i + 1 < text.size) { codeRuneEnd(text, i + 1) } else { i + 1 }; continue }
        if (text[i] == b'[') { inClass = true }
        else if (text[i] == b']') { inClass = false }
        else if (text[i] == b'/' && !inClass) {
            i++
            while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            return i
        }
        i = codeRuneEnd(text, i)
    }
    from
}
func codeNumber(text: String, from: Int64, lang: String): Int64 {
    var i = from
    if (lang == "json" && text[i] == b'-') { i++ }
    if (i >= text.size || !codeDigit(text[i])) { return from }
    var base: Int64 = 10
    if (lang != "json" && text[i] == b'0' && i + 1 < text.size) {
        let marker = text[i + 1]
        if (marker == b'x' || marker == b'X') { base = 16 }
        else if (marker == b'b' || marker == b'B') { base = 2 }
        else if (marker == b'o' || marker == b'O') { base = 8 }
        if (base != 10) { i += 2 }
    }
    let digits = i
    let jsonZero = lang == "json" && text[digits] == b'0'
    while (i < text.size) {
        if (jsonZero && i > digits) { break }
        let ch = text[i]
        let valid = if (base == 16) { codeHex(ch) } else if (base == 8) { ch >= b'0' && ch <= b'7' }
            else if (base == 2) { ch == b'0' || ch == b'1' } else { codeDigit(ch) }
        if (valid) { i++ }
        else if (lang != "json" && (ch == b'_' || ((lang == "cpp" || lang == "c") && ch == b'\'')) &&
            i > digits && i + 1 < text.size && (if (base == 16) { codeHex(text[i + 1]) } else { codeDigit(text[i + 1]) })) { i++ }
        else { break }
    }
    if (i == digits) { return from + 1 }
    var floating = false
    if ((base == 10 || base == 16) && i < text.size && text[i] == b'.' && !codeAt(text, i, "..") && i + 1 < text.size &&
        (if (base == 16) { codeHex(text[i + 1]) } else { codeDigit(text[i + 1]) })) {
        floating = true
        i++
        while (i < text.size && ((if (base == 16) { codeHex(text[i]) } else { codeDigit(text[i]) }) ||
            (lang != "json" && text[i] == b'_' && i + 1 < text.size && codeDigit(text[i + 1])))) { i++ }
    }
    if (i < text.size && ((base == 16 && (text[i] == b'p' || text[i] == b'P')) ||
        (base == 10 && (text[i] == b'e' || text[i] == b'E')))) {
        var e = i + 1
        if (e < text.size && (text[e] == b'+' || text[e] == b'-')) { e++ }
        if (e < text.size && codeDigit(text[e])) {
            floating = true
            i = e + 1
            while (i < text.size && (codeDigit(text[i]) || (lang != "json" && text[i] == b'_' && i + 1 < text.size && codeDigit(text[i + 1])))) { i++ }
        }
    }
    if (lang == "cj") {
        for (suffix in ["i16", "i32", "i64", "i8", "u16", "u32", "u64", "u8", "f16", "f32", "f64"]) {
            if (codeAt(text, i, suffix) && (i + suffix.size == text.size || !codeWordPart(text[i + suffix.size]))) { return i + suffix.size }
        }
    } else if (lang == "py" && i < text.size && (text[i] == b'j' || text[i] == b'J')) { i++ }
    else if ((lang == "js" || lang == "ts") && !floating && i < text.size && text[i] == b'n') { i++ }
    else if (lang == "c" || lang == "cpp") {
        if (floating) {
            if (i < text.size && (text[i] == b'f' || text[i] == b'F' || text[i] == b'l' || text[i] == b'L')) { i++ }
        } else {
            var unsigned = false
            if (i < text.size && (text[i] == b'u' || text[i] == b'U')) { i++; unsigned = true }
            if (i < text.size && (text[i] == b'l' || text[i] == b'L')) {
                let suffix = text[i]
                i++
                if (i < text.size && text[i] == suffix) { i++ }
            } else if (lang == "cpp" && i < text.size && (text[i] == b'z' || text[i] == b'Z')) { i++ }
            if (!unsigned && i < text.size && (text[i] == b'u' || text[i] == b'U')) { i++ }
        }
    }
    i
}

func highlightCode(text: String, lang: String, rule: ?SyntaxRule): Array<CodeToken> {
    if (let Some(active) <- rule) {
        if (!active.builtin) { return highlightConfiguredCode(text, active) }
    }
    if (lang == "") { return [] }
    let out = ArrayList<CodeToken>()
    var i: Int64 = 0
    var expressionStart = true
    var lineStart = true
    var shellWordStart = true
    let pendingHere = ArrayList<(String, Bool)>()
    var hereIndex: Int64 = 0
    while (i < text.size) {
        let start = i
        if (lang == "sh" && lineStart && hereIndex < pendingHere.size) {
            let end = codeLineEnd(text, i)
            let (delimiter, stripTabs) = pendingHere[hereIndex]
            var content = i
            if (stripTabs) { while (content < end && text[content] == b'\t') { content++ } }
            if (text[content..end] == delimiter) {
                hereIndex++
                if (hereIndex == pendingHere.size) { pendingHere.clear(); hereIndex = 0 }
            } else if (end > i) { out.add(CodeToken(i, end, CodeTokenKind.StringLiteral)) }
            i = codeNewlineEnd(text, end)
            lineStart = true
            shellWordStart = true
            continue
        }
        if (text[i] == b'\n' || text[i] == b'\r') {
            i = codeNewlineEnd(text, i)
            lineStart = true
            shellWordStart = true
            continue
        }
        if (text[i] == b' ' || text[i] == b'\t') { i++; if (lang == "sh") { shellWordStart = true }; continue }
        if (lang == "sh" && codeAt(text, i, "<<") && !codeAt(text, i, "<<<")) {
            let stripTabs = codeAt(text, i, "<<-")
            var d = i + if (stripTabs) { 3 } else { 2 }
            while (d < text.size && (text[d] == b' ' || text[d] == b'\t')) { d++ }
            var end = d
            var delimiter = ""
            if (end < text.size && (text[end] == b'\'' || text[end] == b'\"')) {
                let quoteByte = text[end]
                end++
                let content = end
                while (end < text.size && text[end] != quoteByte && text[end] != b'\n') { end++ }
                delimiter = text[content..end]
                if (end < text.size && text[end] == quoteByte) { end++ }
            } else {
                while (end < text.size && text[end] != b' ' && text[end] != b'\t' && text[end] != b'\n' && text[end] != b'\r' && text[end] != b';') { end++ }
                delimiter = text[d..end]
            }
            if (!delimiter.isEmpty()) { pendingHere.add((delimiter, stripTabs)) }
            i = max(i + 2, end)
            lineStart = false
            shellWordStart = false
            continue
        }
        if (lang == "sh" && text[i] == b'#' && shellWordStart) {
            i = codeLineEnd(text, i); out.add(CodeToken(start, i, CodeTokenKind.Comment)); continue
        }
        if (lang == "py" && text[i] == b'#') {
            i = codeLineEnd(text, i); out.add(CodeToken(start, i, CodeTokenKind.Comment)); continue
        }
        if (lang != "sh" && lang != "py" && lang != "json" && codeAt(text, i, "//")) {
            i = if (lang == "c" || lang == "cpp") { codeCLineCommentEnd(text, i) } else { codeLineEnd(text, i) }
            out.add(CodeToken(start, i, CodeTokenKind.Comment)); continue
        }
        if (lang != "sh" && lang != "py" && lang != "json" && codeAt(text, i, "/*")) {
            i = codeBlockComment(text, i, lang == "cj"); out.add(CodeToken(start, i, CodeTokenKind.Comment)); continue
        }
        if ((lang == "c" || lang == "cpp") && lineStart && text[i] == b'#') {
            i++
            while (i < text.size && codeWordPart(text[i])) { i++ }
            out.add(CodeToken(start, i, CodeTokenKind.Directive)); lineStart = false; continue
        }
        if (lang == "cj" && text[i] == b'@' && i + 1 < text.size && codeWordStart(text[i + 1])) {
            i++
            let name = i
            while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            out.add(CodeToken(name, i, CodeTokenKind.TypeName)); lineStart = false; continue
        }
        if (lang == "py" && lineStart && text[i] == b'@' && i + 1 < text.size && codeWordStart(text[i + 1])) {
            i++
            let name = i
            while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            out.add(CodeToken(name, i, CodeTokenKind.TypeName)); lineStart = false; continue
        }
        if (lang == "sh" && text[i] == b'$') {
            if (codeAt(text, i, "$'")) { i = codeQuoted(text, i + 1, b'\'', false, false, true, false, false); out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; continue }
            i++
            if (i < text.size && text[i] == b'{') {
                i++
                while (i < text.size && text[i] != b'}' && text[i] != b'\n') { i = codeRuneEnd(text, i) }
                if (i < text.size && text[i] == b'}') { i++ }
            } else if (i < text.size && codeWordPart(text[i])) {
                while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            } else if (i < text.size && (text[i] == b'?' || text[i] == b'#' || text[i] == b'$' || text[i] == b'@' || text[i] == b'*' || text[i] == b'!')) { i++ }
            if (i > start + 1) { out.add(CodeToken(start, i, CodeTokenKind.Variable)) }
            lineStart = false; shellWordStart = false; continue
        }
        var prefixEnd = i
        var raw = false
        var formatString = false
        if (lang == "cj" && text[i] == b'r') {
            let end = codeRawCj(text, i)
            if (end > i) { i = end; out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; continue }
        }
        if (lang == "cpp" || lang == "c") {
            if (codeAt(text, i, "u8")) { prefixEnd += 2 }
            else if (text[i] == b'u' || text[i] == b'U' || text[i] == b'L') { prefixEnd++ }
            if (lang == "cpp" && prefixEnd < text.size && text[prefixEnd] == b'R') {
                let end = codeRawCpp(text, prefixEnd)
                if (end > prefixEnd) { i = end; out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; continue }
            }
        } else if (lang == "py") {
            while (prefixEnd < text.size && prefixEnd - i < 2 && (text[prefixEnd] == b'r' || text[prefixEnd] == b'R' || text[prefixEnd] == b'u' || text[prefixEnd] == b'U' || text[prefixEnd] == b'b' || text[prefixEnd] == b'B' || text[prefixEnd] == b'f' || text[prefixEnd] == b'F')) {
                if (text[prefixEnd] == b'r' || text[prefixEnd] == b'R') { raw = true }
                if (text[prefixEnd] == b'f' || text[prefixEnd] == b'F') { formatString = true }
                prefixEnd++
            }
            if (prefixEnd - i == 2) {
                let a = text[i]
                let b = text[i + 1]
                let hasR = a == b'r' || a == b'R' || b == b'r' || b == b'R'
                let hasB = a == b'b' || a == b'B' || b == b'b' || b == b'B'
                let hasF = a == b'f' || a == b'F' || b == b'f' || b == b'F'
                if (!(hasR && (hasB || hasF) && !(hasB && hasF))) {
                    prefixEnd = i
                    raw = false
                    formatString = false
                }
            }
        } else if (lang == "cj" && (text[i] == b'b' || text[i] == b'r')) { prefixEnd++ ; raw = text[i] == b'r' }
        if (prefixEnd < text.size && (text[prefixEnd] == b'\'' || text[prefixEnd] == b'\"') && lang != "sh") {
            if (lang != "json" || text[prefixEnd] == b'\"') {
                let quoteByte = text[prefixEnd]
                let triple = (lang == "cj" || lang == "py") && prefixEnd + 2 < text.size && text[prefixEnd + 1] == quoteByte && text[prefixEnd + 2] == quoteByte
                i = codeQuoted(text, prefixEnd, quoteByte, triple, raw, triple, lang == "cj" || formatString, formatString)
                let kind = if (lang == "json") {
                    var after = i
                    while (after < text.size && (text[after] == b' ' || text[after] == b'\t' || text[after] == b'\r' || text[after] == b'\n')) { after++ }
                    if (after < text.size && text[after] == b':') { CodeTokenKind.Property } else { CodeTokenKind.StringLiteral }
                } else { CodeTokenKind.StringLiteral }
                out.add(CodeToken(start, i, kind)); lineStart = false; expressionStart = false; continue
            }
        }
        if ((lang == "js" || lang == "ts") && text[i] == b'`') {
            i = codeQuoted(text, i, b'`', false, false, true, true, false)
            out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; expressionStart = false; continue
        }
        if (lang == "sh" && (text[i] == b'\'' || text[i] == b'\"' || text[i] == b'`')) {
            i = codeQuoted(text, i, text[i], false, text[i] == b'\'', true, false, false)
            out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; shellWordStart = false; continue
        }
        if ((lang == "js" || lang == "ts") && text[i] == b'/' && expressionStart) {
            let end = codeRegex(text, i)
            if (end > i) { i = end; out.add(CodeToken(start, i, CodeTokenKind.StringLiteral)); lineStart = false; expressionStart = false; continue }
        }
        if (codeDigit(text[i]) || (lang == "json" && text[i] == b'-' && i + 1 < text.size && codeDigit(text[i + 1]))) {
            i = codeNumber(text, i, lang)
            out.add(CodeToken(start, i, CodeTokenKind.Number)); lineStart = false; expressionStart = false; shellWordStart = false; continue
        }
        if (lang == "cj" && text[i] == b'`') {
            i++
            while (i < text.size && text[i] != b'`' && text[i] != b'\n') { i = codeRuneEnd(text, i) }
            if (i < text.size && text[i] == b'`') { i++ }
            lineStart = false; continue
        }
        if (codeWordStart(text[i])) {
            i = codeRuneEnd(text, i)
            while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            let word = text[start..i]
            let configured: ?CodeTokenKind = match (rule) {
                case Some(active) => active.wordKind(word)
                case None => None
            }
            if (let Some(kind) <- configured) { out.add(CodeToken(start, i, kind)) }
            else if (let Some(kind) <- codeIdentifierKind(word, lang)) { out.add(CodeToken(start, i, kind)) }
            expressionStart = (lang == "js" || lang == "ts") && codeListed(word, "return throw case yield await typeof void delete in of instanceof")
            lineStart = false; shellWordStart = false; continue
        }
        if (lang == "sh" && text[i] == b'\\' && i + 1 < text.size) {
            i = if (text[i + 1] == b'\r' || text[i + 1] == b'\n') { codeNewlineEnd(text, i + 1) }
                else { codeRuneEnd(text, i + 1) }
        }
        else { i = codeRuneEnd(text, i) }
        if (lang == "js" || lang == "ts") {
            expressionStart = codeListed(text[start..i], "= + - * % ! ~ & | ^ < > ( [ { , : ; ?")
        }
        if (lang == "sh") { shellWordStart = codeListed(text[start..i], "; | & ( )") }
        lineStart = false
    }
    out.toArray()
}

func resolveCodeLanguage(raw: String, syntax: ?SyntaxHighlightConfig): (String, ?SyntaxRule) {
    let name = normalizeCodeLanguage(raw)
    if (let Some(config) <- syntax) {
        if (let Some(rule) <- config.resolve(name)) { return (rule.canonical, Some(rule)) }
        let builtin = codeLanguage(name)
        if (let Some(rule) <- config.resolve(builtin)) { return (rule.canonical, Some(rule)) }
        return (builtin, None)
    }
    (codeLanguage(name), None)
}

func configuredDelimiter(text: String, at: Int64, rule: SyntaxRule): ?SyntaxDelimiter {
    if (let Some(openers) <- rule.openers.get(text[at])) {
        for (entry in openers) {
            if (codeAt(text, at, entry.open)) { return Some(entry) }
        }
    }
    None
}

func configuredEnd(text: String, from: Int64, entry: SyntaxDelimiter): Int64 {
    if (entry.close == "") { return codeLineEnd(text, from) }
    var i = from + entry.open.size
    var depth: Int64 = 1
    while (i < text.size) {
        if (let CodeTokenKind.StringLiteral <- entry.kind) {
            if (!entry.multiline && (text[i] == b'\r' || text[i] == b'\n')) { return i }
            if (entry.escape != "" && codeAt(text, i, entry.escape)) {
                i++
                if (i < text.size) {
                    i = if (text[i] == b'\r' || text[i] == b'\n') { codeNewlineEnd(text, i) }
                        else { codeRuneEnd(text, i) }
                }
                continue
            }
        }
        if (codeAt(text, i, entry.close)) {
            i += entry.close.size
            depth--
            if (depth == 0) { return i }
        } else if (entry.nested && codeAt(text, i, entry.open)) {
            i += entry.open.size
            depth++
        } else { i = codeRuneEnd(text, i) }
    }
    i
}

func highlightConfiguredCode(text: String, rule: SyntaxRule): Array<CodeToken> {
    let out = ArrayList<CodeToken>()
    var i: Int64 = 0
    while (i < text.size) {
        let start = i
        if (let Some(entry) <- configuredDelimiter(text, i, rule)) {
            i = configuredEnd(text, i, entry)
            out.add(CodeToken(start, i, entry.kind))
        } else if (rule.numbers != "none" && (codeDigit(text[i]) ||
            (rule.numbers == "json" && text[i] == b'-' && i + 1 < text.size && codeDigit(text[i + 1])))) {
            i = codeNumber(text, i, if (rule.numbers == "decimal") { "json" } else { rule.numbers })
            out.add(CodeToken(start, i, CodeTokenKind.Number))
        } else if (codeWordStart(text[i])) {
            i = codeRuneEnd(text, i)
            while (i < text.size && codeWordPart(text[i])) { i = codeRuneEnd(text, i) }
            if (let Some(kind) <- rule.wordKind(text[start..i])) { out.add(CodeToken(start, i, kind)) }
        } else { i = codeRuneEnd(text, i) }
    }
    out.toArray()
}

// Physical source lines preserve CR, LF and CRLF byte widths independently of the normalized literal.
struct CodeSourceLine {
    let start: Int64
    let end: Int64
    let next: Int64
    init(start: Int64, end: Int64, next: Int64) { this.start = start; this.end = end; this.next = next }
}
struct CodeOwnedRange {
    let start: Int64
    let end: Int64
    init(start: Int64, end: Int64) { this.start = start; this.end = end }
}

class CodeHighlightContext {
    private let source: String
    private let physical: Array<CodeSourceLine>
    private let baseStyle: Style
    private let collect: Bool
    private let trusted: Bool
    private let syntax: ?SyntaxHighlightConfig
    private let owned = ArrayList<CodeOwnedRange>()
    private let bases = ArrayList<TextDecoration>()
    private let tokens = ArrayList<TextDecoration>()

    init(source: String, baseStyle: Style, collect: Bool, trusted!: Bool = true,
        syntax!: ?SyntaxHighlightConfig = None) {
        this.source = source
        this.baseStyle = baseStyle
        this.collect = collect && trusted
        this.trusted = trusted
        this.syntax = syntax
        let lines = ArrayList<CodeSourceLine>()
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < source.size) {
            if (source[i] == b'\n' || source[i] == b'\r') {
                let next = codeNewlineEnd(source, i)
                lines.add(CodeSourceLine(start, i, next))
                start = next
                i = next
            } else { i = codeRuneEnd(source, i) }
        }
        lines.add(CodeSourceLine(start, source.size, source.size))
        physical = lines.toArray()
    }

    private func lineAt(offset: Int64): Int64 {
        var low: Int64 = 0
        var high = physical.size
        while (low + 1 < high) {
            let mid = (low + high) / 2
            if (physical[mid].start <= offset) { low = mid } else { high = mid }
        }
        low
    }

    private func own(start: Int64, end: Int64, style: Style): Unit {
        if (!collect || end <= start) { return }
        owned.add(CodeOwnedRange(start, end))
        bases.add(TextDecoration(start, end, style))
    }

    func codeLines(node: NodeRef, code: CodeBlockNodeView, style: Style): Array<Array<RichSpan>> {
        let literal = code.literal
        let lang = if (let CodeBlockKind.Fenced <- code.codeKind) { code.language } else { "" }
        let (canonical, rule) = resolveCodeLanguage(lang, syntax)
        let lexical = highlightCode(literal, canonical, rule)
        let displayLines = splitDocumentLines(literal)
        let out = ArrayList<Array<RichSpan>>()
        var first: Int64 = -1
        var stop: Int64 = -1
        var closingStart: Int64 = -1
        var closingEnd: Int64 = -1
        if (trusted) {
            if (let Some(span) <- node.span) {
                if (span.startByte <= source.size && span.endByte <= source.size) {
                    first = lineAt(span.startByte)
                    stop = lineAt(max(span.startByte, span.endByte - 1)) + 1
                    if (let CodeBlockKind.Fenced <- code.codeKind) {
                        if (let Some(open) <- code.openingFenceSpan) {
                            first = lineAt(open.startByte) + 1
                            let opener = physical[first - 1]
                            own(open.startByte, opener.end, style)
                        } else { first = -1 }
                        if (let Some(close) <- code.closingFenceSpan) {
                            stop = lineAt(close.startByte)
                            let closer = physical[stop]
                            if (let Some(marker) <- code.fenceCharacter) {
                                var end = closer.end
                                while (end > closer.start && (source[end - 1] == b' ' || source[end - 1] == b'\t')) { end-- }
                                var begin = end
                                while (begin > closer.start && source[begin - 1] == marker) { begin-- }
                                if (end - begin >= code.fenceLength) { closingStart = begin; closingEnd = closer.end }
                            }
                        }
                    }
                }
            }
        }
        var literalStart: Int64 = 0
        var tokenIndex: Int64 = 0
        for (lineIndex in 0..displayLines.size) {
            let value = displayLines[lineIndex]
            let end = literalStart + value.size
            var matchedLiteral = end
            var matchedSource: Int64 = -1
            if (first >= 0 && first + lineIndex < stop && first + lineIndex < physical.size) {
                let raw = physical[first + lineIndex]
                let suffix = source[raw.start..raw.end]
                var overlap: Int64 = 0
                while (overlap < value.size && overlap < suffix.size &&
                    value[value.size - overlap - 1] == suffix[suffix.size - overlap - 1]) { overlap++ }
                // A shared suffix may not start in the middle of a UTF-8 scalar.
                while (overlap > 0 && ((value[value.size - overlap] >= 0x80 && value[value.size - overlap] < 0xC0) ||
                    (suffix[suffix.size - overlap] >= 0x80 && suffix[suffix.size - overlap] < 0xC0))) { overlap-- }
                var virtualOnly = true
                for (n in 0..value.size - overlap) { if (value[n] != b' ') { virtualOnly = false; break } }
                if (virtualOnly && overlap > 0) {
                    matchedLiteral = end - overlap
                    matchedSource = raw.end - overlap
                    own(matchedSource, raw.end, style)
                } else if (collect && raw.end > raw.start) {
                    // A trusted AST owns this line, even when its literal cannot be mapped byte-for-byte.
                    own(raw.start, raw.end, style)
                }
            }
            let spans = ArrayList<RichSpan>()
            var cursor = literalStart
            while (tokenIndex < lexical.size && lexical[tokenIndex].end <= literalStart) { tokenIndex++ }
            var t = tokenIndex
            while (t < lexical.size && lexical[t].start < end) {
                let token = lexical[t]
                let begin = max(literalStart, token.start)
                let finish = min(end, token.end)
                if (begin > cursor) { piece(spans, literal, cursor, begin, style, matchedLiteral, matchedSource) }
                if (finish > begin) { piece(spans, literal, begin, finish, codeTokenStyle(token.kind, style, rule), matchedLiteral, matchedSource) }
                cursor = finish
                t++
            }
            if (cursor < end) { piece(spans, literal, cursor, end, style, matchedLiteral, matchedSource) }
            if (spans.size == 0) { spans.add(RichSpan("", style: style)) }
            out.add(spans.toArray())
            literalStart = end + 1
        }
        if (closingStart >= 0) { own(closingStart, closingEnd, style) }
        out.toArray()
    }

    private func piece(out: ArrayList<RichSpan>, literal: String, start: Int64, end: Int64,
        style: Style, mappedFrom: Int64, mappedAt: Int64): Unit {
        if (start >= end) { return }
        if (mappedAt >= 0 && start < mappedFrom && end > mappedFrom) {
            out.add(RichSpan(literal[start..mappedFrom], style: style))
            piece(out, literal, mappedFrom, end, style, mappedFrom, mappedAt)
            return
        }
        let mapped = mappedAt >= 0 && start >= mappedFrom
        let range: ?String = if (mapped) { Some(rangeText(mappedAt + start - mappedFrom,
            mappedAt + end - mappedFrom)) } else { None }
        out.add(RichSpan(literal[start..end], style: style, sourceRange: range))
        if (mapped && collect && style != baseStyle) {
            tokens.add(TextDecoration(mappedAt + start - mappedFrom, mappedAt + end - mappedFrom, style))
        }
    }

    func decorations(): Array<TextDecoration> {
        if (!collect) { return [] }
        let all = ArrayList<TextDecoration>()
        for (line in physical) {
            if (line.end <= line.start) { continue }
            let raw = source[line.start..line.end]
            for (dec in markdownDecorations(raw)) {
                var from = line.start + dec.start
                let end = min(line.end, line.start + dec.end)
                for (region in owned) {
                    if (region.end <= from) { continue }
                    if (region.start >= end) { break }
                    if (region.start > from) { all.add(TextDecoration(from, min(end, region.start), dec.style)) }
                    from = max(from, region.end)
                    if (from >= end) { break }
                }
                if (from < end) { all.add(TextDecoration(from, end, dec.style)) }
            }
        }
        for (dec in bases) { all.add(dec) }
        for (dec in tokens) { all.add(dec) }
        all.toArray()
    }
}
