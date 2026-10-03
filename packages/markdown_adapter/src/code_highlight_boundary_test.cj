package markdown_adapter

import std.unittest.*
import std.unittest.testmacro.*

func codeBoundaryTokens(text: String, lang: String): String {
    var result = ""
    for (token in highlightCode(text, lang, Option<SyntaxRule>.None)) {
        result += syntaxKindName(token.kind) + ":" + text[token.start..token.end] + "|"
    }
    result
}

@Test
class CodeHighlightBoundaryTest {
    @TestCase
    func languageWhitespaceAndUtf8OffsetsAreByteExact(): Unit {
        @Expect(normalizeCodeLanguage(" \t\r\nC++\n\r\t "), "c++")
        @Expect(normalizeCodeLanguage(" \t\r\n"), "")
        @Expect(normalizeCodeLanguage("Z_a+1"), "z_a+1")
        @Expect(codeRuneEnd("aé界🙂", 0), 1)
        @Expect(codeRuneEnd("aé界🙂", 1), 3)
        @Expect(codeRuneEnd("aé界🙂", 3), 6)
        @Expect(codeRuneEnd("aé界🙂", 6), 10)
        @Expect(!codeAt("abc", -1, "a"))
        @Expect(!codeAt("abc", 2, "bc"))
        @Expect(codeAt("abc", 3, ""))
        @Expect(!codeAt("abc", 0, "abd"))
        @Expect(!codeListed("a", "ab cd"))
        @Expect(!codeListed("cd", "ab ce"))
        @Expect(codeListed("cd", "ab cd"))
        @Expect(codeLineEnd("é\rnext", 0), 2)
        @Expect(codeNewlineEnd("", 0), 0)
        @Expect(codeNewlineEnd("x", 0), 0)
        @Expect(codeNewlineEnd("\r", 0), 1)
        @Expect(codeNewlineEnd("\n", 0), 1)
        @Expect(codeNewlineEnd("\r\n", 0), 2)
        @Expect(codeCLineCommentEnd("//\\\rnext\\\nlast", 0), 14)
        @Expect(codeCLineCommentEnd("", 0), 0)
    }

    @TestCase
    func numericPrefixesAndSeparatorsStopBeforeInvalidContinuation(): Unit {
        let cases: Array<(String, String, String)> = [
            ("-", "json", ""), ("x", "json", ""), ("-x", "json", ""),
            ("0", "json", "0"), ("-01", "json", "-0"), ("1_2", "json", "1"),
            ("0x", "cj", "0"), ("0xG", "cj", "0"), ("0XfF", "cj", "0XfF"),
            ("0b_1", "cj", "0"), ("0B10_1", "cj", "0B10_1"), ("0b102", "cj", "0b10"),
            ("0o8", "cj", "0"), ("0O77", "cj", "0O77"), ("0o71_", "cj", "0o71"),
            ("1_", "cj", "1"), ("1_a", "cj", "1"), ("1__2", "cj", "1"),
            ("0xA_F", "cj", "0xA_F"), ("0xA_G", "cj", "0xA"),
            ("1'2", "cpp", "1'2"), ("1'2", "c", "1'2"), ("1'2", "py", "1"),
            ("1.", "cj", "1"), ("1.a", "cj", "1"), ("1..2", "cj", "1"),
            ("0x1.G", "cpp", "0x1"), ("0x1.a_fp+2", "cpp", "0x1.a"),
            ("1.2_3", "cj", "1.2_3"), ("1.2_", "cj", "1.2"),
            ("1.2_a", "cj", "1.2"), ("1.2_3", "json", "1.2"),
            ("1e", "cj", "1"), ("1e+", "cj", "1"), ("1e-a", "cj", "1"),
            ("1E-2_3", "cj", "1E-2_3"), ("1e+2_", "cj", "1e+2"),
            ("1e2_a", "cj", "1e2"), ("1e2_3", "json", "1e2"),
            ("0x1P+2", "cpp", "0x1P+2"), ("0x1p-2", "cpp", "0x1p-2")
        ]
        for ((source, lang, accepted) in cases) { @Expect(codeNumber(source, 0, lang), accepted.size) }
    }

    @TestCase
    func numericSuffixesRespectLanguageAndIdentifierBoundaries(): Unit {
        for (suffix in ["i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f16", "f32", "f64"]) {
            let source = "7" + suffix
            @Expect(codeNumber(source, 0, "cj"), source.size)
            @Expect(codeNumber(source + ")", 0, "cj"), source.size)
            @Expect(codeNumber(source + "x", 0, "cj"), 1)
        }
        let cases: Array<(String, String, String)> = [
            ("1j", "py", "1j"), ("1J", "py", "1J"), ("1x", "py", "1"),
            ("1n", "ts", "1n"), ("1.0n", "ts", "1.0"), ("1x", "ts", "1"),
            ("1u", "c", "1u"), ("1U", "c", "1U"), ("1l", "c", "1l"),
            ("1L", "c", "1L"), ("1ll", "c", "1ll"), ("1LL", "cpp", "1LL"),
            ("1lL", "cpp", "1l"), ("1uLL", "cpp", "1uLL"), ("1LU", "cpp", "1LU"),
            ("1llux", "cpp", "1llu"), ("1z", "cpp", "1z"), ("1ZU", "cpp", "1ZU"),
            ("1uz", "cpp", "1uz"), ("1Z", "c", "1"), ("1x", "c", "1"),
            ("1.0f", "c", "1.0f"), ("1.0F", "cpp", "1.0F"),
            ("1.0l", "c", "1.0l"), ("1.0L", "cpp", "1.0L"), ("1.0x", "cpp", "1.0")
        ]
        for ((source, lang, accepted) in cases) { @Expect(codeNumber(source, 0, lang), accepted.size) }
    }

    @TestCase
    func rawStringsValidateOpenersAndRequireTheCompleteClosingDelimiter(): Unit {
        for (source in ["r", "rplain", "r#", "r##x"]) { @Expect(codeRawCj(source, 0), 0) }
        for (source in ["r#\"x\"#", "r##\"x\"#y\"##", "r##\"x\"", "r#\"", "r##\"x\"#"]) {
            @Expect(codeRawCj(source, 0), source.size)
        }
        for (source in ["R", "R\"", "R\"tag", "R\"a b(x)a b\"", "R\"a\nb(x)a\nb\"", "R\"a\rb(x)a\rb\"", "R\"abcdefghijklmnopq(x)abcdefghijklmnopq\""]) {
            @Expect(codeRawCpp(source, 0), 0)
        }
        for (source in ["R\"(x)\"", "R\"tag(x)wrong\"y)tag\"", "R\"(x)", "R\"tag(x)tagX", "R\"abcdefghijklmnop(x)abcdefghijklmnop\""]) {
            @Expect(codeRawCpp(source, 0), source.size)
        }
    }

    @TestCase
    func quotedStringsAndInterpolationsRecoverAtTheCorrectBoundary(): Unit {
        for (source in ["\"", "\"unfinished\\", "\"escaped\\\r\nnext\"", "\"escaped\\\nnext\"", "\"escaped\\🙂\""]) {
            @Expect(codeQuoted(source, 0, b'\"', false, false, false, false, false), source.size)
        }
        @Expect(codeQuoted("\"a\rb\"", 0, b'\"', false, false, false, false, false), 2)
        @Expect(codeQuoted("\"a\nb\"", 0, b'\"', false, false, false, false, false), 2)
        for (source in ["\"\"\"a\"", "\"\"\"a\"\"", "\"\"\"a\"x\"\"\""]) {
            @Expect(codeQuoted(source, 0, b'\"', true, false, true, false, false), source.size)
        }
        for (source in ["\"a\\q\"", "\"a\\\"b\""]) {
            @Expect(codeQuoted(source, 0, b'\"', false, true, false, false, false), source.size)
        }
        for (source in ["{x:{y:1}}", "{'x':\"}\", `x`}", "{\\}x}", "{\\🙂}", "{unfinished", "{\\"]) {
            @Expect(codeInterpolationEnd(source, 0), source.size)
        }
        @Expect(codeBoundaryTokens("`x\u{24}{{a:'}'}}y`", "js"), "string:`x\u{24}{{a:'}'}}y`|")
        @Expect(codeBoundaryTokens("f\"{{x}} {value}\"", "py"), "string:f\"{{x}} {value}\"|")
        @Expect(codeBlockComment("/* outer /* inner */ tail */", 0, true), 28)
        @Expect(codeBlockComment("/*", 0, true), 2)
        @Expect(codeBlockComment("/* /* */", 0, false), 8)
    }

    @TestCase
    func regularExpressionClassesEscapesAndMissingClosersAreDistinct(): Unit {
        for (source in ["/", "/x", "/x\n/", "/x\r/", "/x\\", "/[x/", "/\\🙂"]) { @Expect(codeRegex(source, 0), 0) }
        for (source in ["/x/", "/[a/b]/gi", "/\\//", "/x/é2"]) { @Expect(codeRegex(source, 0), source.size) }
        @Expect(codeRegex("/x/g+", 0), 4)
        @Expect(codeBoundaryTokens("return /x/g; value / divisor", "js"), "keyword:return|string:/x/g|")
    }

    @TestCase
    func decoratorsAndShellVariablesKeepTheirPreciseTokenRanges(): Unit {
        @Expect(codeBoundaryTokens("@类型_2() @End @", "cj"), "type:类型_2|type:End|")
        @Expect(codeBoundaryTokens("@decorate\n\t@More_2()\nx @ignored\n@", "py"), "type:decorate|type:More_2|")
        @Expect(codeBoundaryTokens("$name $_a $9 $? $# $$ $@ $* $! \u{24}{值} $", "sh"),
            "variable:$name|variable:$_a|variable:$9|variable:$?|variable:$#|variable:$$|variable:$@|variable:$*|variable:$!|variable:\u{24}{值}|")
        @Expect(codeBoundaryTokens("\u{24}{open\n\u{24}{unfinished", "sh"), "variable:\u{24}{open|variable:\u{24}{unfinished|")
        @Expect(codeBoundaryTokens("$'x\\n' 'raw' \"double\" `command`", "sh"),
            "string:$'x\\n'|string:'raw'|string:\"double\"|string:`command`|")
        @Expect(codeBoundaryTokens("\\#word \\\r\n\\\n\\x \\" , "sh"), "")
        @Expect(codeBoundaryTokens("`class` `unfinished\nlet", "cj"), "keyword:let|")
    }

    @TestCase
    func hereDocumentsHandleEmptyBodiesTabsAndQueuedDelimiters(): Unit {
        @Expect(codeBoundaryTokens("cat << \t'A' <<-\"B\"\n\nA\n\tbody\n\tB\necho", "sh"), "string:\tbody|")
        @Expect(codeBoundaryTokens("cat <<\nword", "sh"), "")
        @Expect(codeBoundaryTokens("cat <<''\nword", "sh"), "")
        @Expect(codeBoundaryTokens("cat <<'A\nbody\nA", "sh"), "string:body|")
        @Expect(codeBoundaryTokens("cat << A;\rbody\rA", "sh"), "string:body|")
    }

    @TestCase
    func configuredStringsPreserveEscapesAndRecoverFromUnclosedInput(): Unit {
        let single = SyntaxDelimiter("[", "]", CodeTokenKind.StringLiteral, escape: "\\")
        let multi = SyntaxDelimiter("[", "]", CodeTokenKind.StringLiteral, escape: "\\", multiline: true)
        for (source in ["[", "[x\\", "[x\\]y]", "[x\\🙂]", "[x\\\ry]", "[x\\\ny]", "[x\\\r\ny]"]) {
            @Expect(configuredEnd(source, 0, single), source.size)
        }
        @Expect(configuredEnd("[x\ry]", 0, single), 2)
        @Expect(configuredEnd("[x\ny]", 0, single), 2)
        @Expect(configuredEnd("[x\r\ny]", 0, multi), 6)
        let nested = SyntaxDelimiter("(*", "*)", CodeTokenKind.Comment, nested: true)
        @Expect(configuredEnd("(* a (* b *) c *)", 0, nested), 17)
        @Expect(configuredEnd("(* open", 0, nested), 7)
    }
}
