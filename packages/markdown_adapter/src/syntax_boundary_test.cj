package markdown_adapter

import core.*
import std.unittest.*
import std.unittest.testmacro.*

func syntaxBoundaryError(text: String): String {
    try { _ = parseSyntaxHighlightConfig(text); "accepted" }
    catch (error: IllegalArgumentException) { error.message }
}

func syntaxBoundaryRepeat(text: String, count: Int64): String {
    var result = ""
    for (_ in 0..count) { result += text }
    result
}

@Test
class SyntaxBoundaryTest {
    @TestCase
    func argumentEscapesPreserveTheirExactBytes(): Unit {
        let args = syntaxArguments(" \tplain \"\\\\\\\"\\n\\r\\t\" \"\"\t ", 4)
        @Assert(args.size, 3)
        @Expect(args[0], "plain")
        @Expect(args[1], "\\\"\n\r\t")
        @Expect(args[2], "")
        let invalid: Array<(String, String)> = [
            ("\"abc\\", "unfinished escape"),
            ("abc\\def", "quote or backslash requires quoted argument"),
            ("abc\"def", "quote or backslash requires quoted argument")
        ]
        for ((argument, reason) in invalid) {
            var message = "accepted"
            try { _ = syntaxArguments(argument, 7) }
            catch (error: IllegalArgumentException) { message = error.message }
            @Expect(message, "syntax config line 7: " + reason)
        }
    }

    @TestCase
    func languageNamesRejectInvalidLengthsAndCharacters(): Unit {
        @Expect(syntaxName("A0_b+C.d-E", 1), "a0_b+c.d-e")
        @Expect(syntaxName(syntaxBoundaryRepeat("a", 64), 1).size, 64)
        for (name in ["", "0abc", "_abc", "a/b", "a:b", "a@b", "é", syntaxBoundaryRepeat("a", 65)]) {
            @Expect(syntaxBoundaryError("syntax 1\nlanguage \"" + name + "\"\nend"),
                "syntax config line 2: invalid language name")
        }
    }

    @TestCase
    func wordAndDelimiterByteLimitsAreEnforced(): Unit {
        let longWord = syntaxBoundaryRepeat("a", 256)
        let valid = parseSyntaxHighlightConfig("syntax 1\nlanguage custom\nkeywords " + longWord + " 值_2\nend")
        @Expect(valid.resolve("custom").isSome())
        for (word in ["", "9bad", "bad-name", "bad\\tname", syntaxBoundaryRepeat("a", 257)]) {
            @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nkeywords \"" + word + "\"\nend"),
                "syntax config line 3: invalid identifier")
        }
        @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nline-comment " + syntaxBoundaryRepeat("/", 65) + "\nend"),
            "syntax config line 3: delimiter must be 1 to 64 bytes")
        for (delimiter in ["\\n", "\\r", "\\t"]) {
            @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nline-comment \"" + delimiter + "\"\nend"),
                "syntax config line 3: invalid delimiter")
        }
        @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nkeywords x\u{7F}\nend"),
            "syntax config line 3: control character")
    }

    @TestCase
    func colorNamesRgbAndIndexedEndpointsRoundTrip(): Unit {
        let colors: Array<(String, Color)> = [
            ("inherit", Color.Reset), ("black", Color.Black), ("red", Color.Red),
            ("green", Color.Green), ("yellow", Color.Yellow), ("blue", Color.Blue),
            ("magenta", Color.Magenta), ("cyan", Color.Cyan), ("white", Color.White),
            ("#abcdef", Color.Rgb(171, 205, 239)), ("#ABCDEF", Color.Rgb(171, 205, 239)),
            ("#012345", Color.Rgb(1, 35, 69)), ("indexed:0", Color.Indexed(0)),
            ("indexed:255", Color.Indexed(255)), ("indexed:007", Color.Indexed(7))
        ]
        for ((name, color) in colors) { @Expect(Style(fg: syntaxColor(name, 2)), Style(fg: color)) }
        for (name in ["#g00000", "#0G0000", "#00/000", "#000:00", "#0000@0", "#00000z", "#12345", "indexed:", "indexed:-1", "indexed:1x", "indexed:999", "pink"]) {
            @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nstyle keyword " + name + "\nend"),
                "syntax config line 3: invalid color")
        }
    }

    @TestCase
    func everyStyleKindSupportsIndependentModifiers(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage custom\n" +
            "style keyword red bold italic underline reversed\nstyle type green\nstyle string yellow\n" +
            "style number blue\nstyle comment magenta\nstyle directive cyan\nstyle variable white\nstyle property indexed:255\nend")
        match (config.resolve("custom")) {
            case Some(rule) =>
                let kinds: Array<(CodeTokenKind, String, Color)> = [
                    (CodeTokenKind.Keyword, "keyword", Color.Red), (CodeTokenKind.TypeName, "type", Color.Green),
                    (CodeTokenKind.StringLiteral, "string", Color.Yellow), (CodeTokenKind.Number, "number", Color.Blue),
                    (CodeTokenKind.Comment, "comment", Color.Magenta), (CodeTokenKind.Directive, "directive", Color.Cyan),
                    (CodeTokenKind.Variable, "variable", Color.White), (CodeTokenKind.Property, "property", Color.Indexed(255))
                ]
                for ((kind, name, color) in kinds) {
                    @Expect(syntaxKindName(kind), name)
                    match (rule.overlay(kind)) {
                        case Some(style) =>
                            @Expect(Style(fg: style.fg), Style(fg: color))
                            if (name == "keyword") {
                                @Expect(style.modifier.bold && style.modifier.italic && style.modifier.underline && style.modifier.reversed)
                            }
                        case None => @Expect(false)
                    }
                }
            case None => @Expect(false)
        }
        for (modifier in ["italic", "underline", "reversed"]) {
            @Expect(syntaxBoundaryError("syntax 1\nlanguage custom\nstyle keyword red " + modifier + " " + modifier + "\nend"),
                "syntax config line 3: duplicate modifier")
        }
    }

    @TestCase
    func parserReportsDeclarationFailuresAtThePhysicalLine(): Unit {
        let cases: Array<(String, Int64, String)> = [
            ("syntax", 1, "expected syntax 1 header"),
            ("wrong 1", 1, "expected syntax 1 header"),
            ("syntax 1\nsyntax 1", 2, "duplicate header"),
            ("syntax 1\nend", 2, "end outside language"),
            ("syntax 1\nkeywords x", 2, "declaration outside language"),
            ("syntax 1\nlanguage", 2, "wrong argument count"),
            ("syntax 1\nlanguage cj wrong", 2, "expected replace"),
            ("syntax 1\nextend custom", 2, "unknown built-in language"),
            ("syntax 1\nlanguage custom replace", 2, "unknown built-in language"),
            ("syntax 1\nextend cj\nend\nextend cangjie", 4, "duplicate language"),
            ("syntax 1\nlanguage first\naliases second\nend\nlanguage second", 5, "duplicate language"),
            ("syntax 1\nlanguage custom\nkeywords x x", 3, "duplicate word"),
            ("syntax 1\nextend cj\nline-comment //", 3, "extend cannot change delimiters"),
            ("syntax 1\nextend cj\nnumbers none", 3, "duplicate or forbidden numbers"),
            ("syntax 1\nlanguage custom\nblock-comment /* */ wrong", 3, "invalid nesting mode"),
            ("syntax 1\nlanguage custom\nstring [ ] xx single", 3, "invalid string escape"),
            ("syntax 1\nlanguage custom\nstring [ ] \"\\n\" single", 3, "invalid string escape"),
            ("syntax 1\nlanguage custom\nstring [ ] é single", 3, "invalid string escape"),
            ("syntax 1\nlanguage custom\nstring [ ] \"\" wrong", 3, "invalid string mode"),
            ("syntax 1\nlanguage custom\nstyle strange red", 3, "invalid or duplicate style kind"),
            ("syntax 1\nlanguage custom\nstyle keyword red\nstyle keyword blue", 4, "invalid or duplicate style kind"),
            ("syntax 1\nlanguage custom\nstyle keyword red blink", 3, "invalid modifier"),
            ("syntax 1\nlanguage custom\nend extra", 3, "wrong argument count")
        ]
        for ((text, line, reason) in cases) {
            @Expect(syntaxBoundaryError(text), "syntax config line ${line}: ${reason}")
        }
    }

    @TestCase
    func openerPrecedenceUsesLongestMatchAndFallsThroughCandidates(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage custom\nline-comment /\n" +
            "block-comment /* */ flat\nstring /[ ]/ \"\" multi\nblock-comment /** **/ flat\nnumbers none\nend")
        match (config.resolve("custom")) {
            case Some(rule) =>
                let cases: Array<(String, String)> = [("/**x**/", "/**"), ("/*x*/", "/*"), ("/[x]/", "/["), ("/x", "/")]
                for ((text, opener) in cases) {
                    match (configuredDelimiter(text, 0, rule)) {
                        case Some(entry) => @Expect(entry.open, opener)
                        case None => @Expect(false)
                    }
                    @Expect(highlightConfiguredCode(text, rule).size, 1)
                }
                @Expect(configuredDelimiter("x", 0, rule).isNone())
            case None => @Expect(false)
        }
        @Expect(parseSyntaxHighlightConfig(" \t# comment\r\n\tsyntax 1 \t\r\nlanguage Custom\r\nend\r\n").resolve("custom").isSome())
    }
}
