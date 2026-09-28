package markdown_adapter

import markdown.core.Markdown
import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class MarkdownExtensionTest {
    @TestCase
    func outlineRetainsEarlierDeepAndLaterShallowHeadings(): Unit {
        let nodes = markdownOutline(Markdown.parse("## A\n# B\n## C"))
        @Assert(nodes.size, 2)
        @Expect(nodes[0].title, "A")
        @Expect(nodes[1].title, "B")
        @Assert(nodes[1].children.size, 1)
        @Expect(nodes[1].children[0].title, "C")
    }

    @TestCase
    func parsesMarkdownIntoDocumentLines(): Unit {
        let doc = markdownDocument("# Title\n\n- item\n> note\n```cj\nmain\n```\n| a | b |\n| --- | --- |\n| c | d |")
        @Expect(doc.lines.size, 7)
        match (doc.lines[0].kind) {
            case DocumentLineKind.Heading(level) => @Expect(level, 1)
            case _ => @Expect(false)
        }
        match (doc.lines[2].kind) {
            case DocumentLineKind.ListItem(false) => ()
            case _ => @Expect(false)
        }
        match (doc.lines[5].kind) {
            case DocumentLineKind.TableHeader => ()
            case _ => @Expect(false)
        }
        @Expect(doc.lines[5].spans[0].text, "a | b")
        @Expect(doc.lines[6].spans[0].text, "c | d")
    }

    @TestCase
    func rendersChineseMarkdownTable(): Unit {
        let doc = markdownDocument(
            "| 姓名 | 角色 | 状态 |\n| --- | --- | --- |\n| 张三 | 开发者 | 正常 |\n| 李四 | 测试员 | 休假 |")
        @Expect(doc.lines.size, 3)
        match (doc.lines[0].kind) {
            case DocumentLineKind.TableHeader => ()
            case _ => @Expect(false)
        }
        match (doc.lines[1].kind) {
            case DocumentLineKind.TableRow => ()
            case _ => @Expect(false)
        }
        @Expect(doc.lines[0].spans[0].text.startsWith("姓名 | 角色"))
        @Expect(doc.lines[1].spans[0].text.startsWith("张三 | 开发者"))
        @Expect(doc.lines[2].spans[0].text.startsWith("李四 | 测试员"))
    }

    @TestCase
    func preservesMarkdownHardBreaksAsDocumentRows(): Unit {
        let doc = markdownDocument("/help — Show help  \n/setup — Configure providers")
        @Expect(doc.lines.size, 2)
        @Expect(doc.lines[0].spans[0].text, "/help — Show help")
        @Expect(doc.lines[1].spans[0].text, "/setup — Configure providers")
    }

    @TestCase
    func optionallyPreservesMarkdownSoftBreaksAsDocumentRows(): Unit {
        let defaultDoc = markdownDocument("first line\nsecond line")
        @Expect(defaultDoc.lines.size, 1)
        @Expect(defaultDoc.lines[0].spans[1].text, " ")

        let preserved = markdownDocument(
            "first line\nsecond line",
            preserveSoftBreaks: true
        )
        @Expect(preserved.lines.size, 2)
        @Expect(preserved.lines[0].spans[0].text, "first line")
        @Expect(preserved.lines[1].spans[0].text, "second line")
    }

    @TestCase
    func rendersParsedDocumentWithMarkdownView(): Unit {
        let buffer = Buffer(Rect(0, 0, 20, 4))
        DocumentView(markdownDocument("# Title\n[link](https://example.com)\n**strong**")).render(Rect(0, 0, 20, 3),
            buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(2, 0).symbol, "T")
        @Expect(buffer.getCell(0, 1).symbol, "l")
        @Expect(buffer.getCell(0, 1).style, Style(fg: Color.Blue))
        @Expect(buffer.getCell(5, 1).symbol, "s")
        @Expect(buffer.getCell(5, 1).style, Style(fg: Color.White, modifier: Modifier.strong()))
    }

    @TestCase
    func mapsHeadingLevelsToPreviewStyles(): Unit {
        let doc = markdownDocument("# One\n## Two\n### Three")
        let buffer = Buffer(Rect(0, 0, 20, 3))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, DocumentTheme().headingStyle(1))
        @Expect(buffer.getCell(0, 1).style, DocumentTheme().headingStyle(2))
        @Expect(buffer.getCell(0, 2).style, DocumentTheme().headingStyle(3))
        @Expect(buffer.getCell(2, 0).style, buffer.getCell(0, 0).style)
        @Expect(buffer.getCell(3, 1).style, buffer.getCell(0, 1).style)
        @Expect(buffer.getCell(4, 2).style, buffer.getCell(0, 2).style)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(0, 1).symbol, "#")
        @Expect(buffer.getCell(1, 1).symbol, "#")
        @Expect(buffer.getCell(0, 2).symbol, "#")
        @Expect(buffer.getCell(2, 2).symbol, "#")
    }

    @TestCase
    func mapsExtendedMarkdownNodes(): Unit {
        let doc = markdownDocument("- [x] done\n---\n\n![alt](img.png)\n\n<div>x</div>\n```cj\nopen")
        var task = false
        var rule = false
        var image = false
        var html = false
        for (line in doc.lines) {
            match (line.kind) {
                case DocumentLineKind.TaskListItem(true) => task = true
                case DocumentLineKind.HorizontalRule => rule = true
                case DocumentLineKind.Image => image = true
                case DocumentLineKind.Html => html = true
                case _ => ()
            }
        }
        @Expect(task)
        @Expect(rule)
        @Expect(image)
        @Expect(html)
    }

    @TestCase
    func mapsStrikethroughAndSourceOffsets(): Unit {
        let doc = markdownDocument("A ~~gone~~")
        @Expect(doc.lines[0].spans[1].style, DocumentTheme().strikethrough)
        match (doc.lines[0].spans[1].sourceRange) {
            case Some(value) => @Expect(value.contains(":"))
            case None => @Expect(false)
        }
    }

    @TestCase
    func rendersNestedEmphasisStyles(): Unit {
        let doc = markdownDocument("***both***")
        var modifier = Modifier.strong()
        modifier.italic = true
        @Expect(doc.lines[0].spans[0].text, "both")
        @Expect(doc.lines[0].spans[0].style, Style(fg: Color.White, modifier: modifier))
    }

    @TestCase
    func rendersNestedListItemsFromAstChildren(): Unit {
        let doc = markdownDocument("- parent\n  - child")
        @Expect(doc.lines.size, 2)
        @Expect(doc.lines[1].spans[0].text, "  ")
        match (doc.lines[1].kind) {
            case DocumentLineKind.ListItem(false) => ()
            case _ => @Expect(false)
        }
    }

    @TestCase
    func buildsOutlineAndPreviewIndex(): Unit {
        let ast = Markdown.parse("# A\n\n## B\n\ntext")
        let outline = markdownOutline(ast)
        @Expect(outline.size, 1)
        @Expect(outline[0].title, "A")
        @Expect(outline[0].children.size, 1)
        @Expect(outline[0].children[0].title, "B")
        let doc = markdownAstToDocument(ast)
        let index = markdownPreviewIndex(doc, 20)
        @Expect(index.renderedLineCount() > 0)
        @Expect(index.renderedLineForSourceOffset(outline[0].children[0].sourceOffset) >= 0)
        match (index.sourceOffsetForRenderedLine(0)) {
            case Some(offset) => @Expect(offset, 2)
            case None => @Expect(false)
        }
    }

    @TestCase
    func adapterPreservesTableAlignmentEscapesAndWrappedOffsets(): Unit {
        let tableDoc = markdownDocument("| name | score |\n| :--- | ---: |\n| a\\|b | 9 |\n| 中文 | 12 |")
        @Expect(tableDoc.lines.size, 3)
        @Expect(tableDoc.lines[0].spans[0].text, "name | score")
        @Expect(tableDoc.lines[1].spans[0].text, "a|b  |     9")
        @Expect(tableDoc.lines[2].spans[0].text, "中文 |    12")
        match (tableDoc.lines[1].kind) {
            case DocumentLineKind.TableRow => ()
            case _ => @Expect(false)
        }

        let wrappedDoc = markdownDocument("# Heading\n\nabcdef ghijkl")
        let index = markdownPreviewIndex(wrappedDoc, 8)
        @Expect(index.renderedLineCount() >= 3)
        match (index.sourceOffsetForRenderedLine(0)) {
            case Some(offset) => @Expect(offset >= 0)
            case None => @Expect(false)
        }
        @Expect(index.renderedLineForSourceOffset(10) >= 0)
    }

    @TestCase
    func rendersFocusedMarkdownPreviewCases(): Unit {
        let doc = markdownDocument(
            "# Title\n\n- item\n\n```cj\nmain\n```\n\n| 名 | 值 |\n| --- | --- |\n| 张三 | 正常 |\n\n[link](https://example.com) **strong** *em* ~~old~~ `code`")
        var hasLink = false
        var hasStrong = false
        var hasItalic = false
        var hasStrike = false
        var hasInlineCode = false
        for (line in doc.lines) {
            for (span in line.spans) {
                match (span.linkUrl) {
                    case Some(_) => hasLink = true
                    case None => ()
                }
                if (span.style == DocumentTheme().strong) {
                    hasStrong = true
                }
                if (span.style == DocumentTheme().emphasis) {
                    hasItalic = true
                }
                if (span.style == DocumentTheme().strikethrough) {
                    hasStrike = true
                }
                if (span.style == DocumentTheme().inlineCode) {
                    hasInlineCode = true
                }
            }
        }
        @Expect(hasLink)
        @Expect(hasStrong)
        @Expect(hasItalic)
        @Expect(hasStrike)
        @Expect(hasInlineCode)

        let buffer = Buffer(Rect(0, 0, 80, 24))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(2, 0).symbol, "T")
        @Expect(renderedRow(buffer, 0, 16).startsWith("# Title"))
        @Expect(buffer.getCell(0, 0).style, DocumentTheme().headingStyle(1))

        let listBuffer = Buffer(Rect(0, 0, 80, 4))
        DocumentView(doc, scroll: firstLineIndexContaining(doc, "item")).render(listBuffer.area, listBuffer)
        @Expect(renderedRow(listBuffer, 0, 16).startsWith("* item"))
        @Expect(listBuffer.getCell(0, 0).style, DocumentTheme().list)

        let codeBuffer = Buffer(Rect(0, 0, 80, 4))
        DocumentView(doc, scroll: firstLineIndexContaining(doc, "main")).render(codeBuffer.area, codeBuffer)
        @Expect(renderedRow(codeBuffer, 0, 16).startsWith("main"))
        @Expect(codeBuffer.getCell(0, 0).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))

        let tableBuffer = Buffer(Rect(0, 0, 80, 4))
        DocumentView(doc, scroll: firstTableHeaderLine(doc)).render(tableBuffer.area, tableBuffer)
        @Expect(renderedRow(tableBuffer, 0, 16).startsWith("名   | 值"))
        @Expect(renderedRow(tableBuffer, 1, 16).contains("张三"))
        @Expect(renderedRow(tableBuffer, 1, 16).contains("正常"))
        @Expect(tableBuffer.getCell(0, 0).style, DocumentTheme().tableHeader)
        @Expect(tableBuffer.getCell(0, 1).style, DocumentTheme().table)
    }

    @TestCase
    func rendersNestedBlockQuotesWithDepth(): Unit {
        let doc = markdownDocument("> one\n> > two\n> > > three")
        @Expect(doc.lines.size, 3)
        @Expect(doc.lines[0].quoteDepth, 1)
        @Expect(doc.lines[1].quoteDepth, 2)
        @Expect(doc.lines[2].quoteDepth, 3)

        let buffer = Buffer(Rect(0, 0, 40, 3))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(renderedRow(buffer, 0, 12).startsWith("| one"))
        @Expect(renderedRow(buffer, 1, 12).startsWith("| | two"))
        @Expect(renderedRow(buffer, 2, 14).startsWith("| | | three"))
        @Expect(buffer.getCell(0, 0).style, DocumentTheme().quoteStyle)
        @Expect(buffer.getCell(2, 1).style, DocumentTheme().quoteStyle)
        @Expect(buffer.getCell(4, 2).style, DocumentTheme().quoteStyle)
    }

    @TestCase
    func rendersBlockElementsInsideQuotes(): Unit {
        let doc = markdownDocument("> - item\n> ```cj\n> let x = 1\n> ```")
        @Expect(doc.lines.size, 2)
        @Expect(doc.lines[0].quoteDepth, 1)
        @Expect(doc.lines[1].quoteDepth, 1)
        match (doc.lines[0].kind) {
            case DocumentLineKind.ListItem(false) => ()
            case _ => @Expect(false)
        }
        match (doc.lines[1].kind) {
            case DocumentLineKind.CodeBlock => ()
            case _ => @Expect(false)
        }

        let buffer = Buffer(Rect(0, 0, 40, 2))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(renderedRow(buffer, 0, 16).startsWith("| * item"))
        @Expect(renderedRow(buffer, 1, 16).startsWith("| let x = 1"))
        @Expect(buffer.getCell(0, 0).style, DocumentTheme().quoteStyle)
        @Expect(buffer.getCell(2, 0).style, DocumentTheme().list)
        @Expect(buffer.getCell(2, 1).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))

        let index = markdownPreviewIndex(doc, 24)
        @Expect(index.renderedLineCount() >= doc.lines.size)
        match (index.sourceOffsetForRenderedLine(0)) {
            case Some(offset) => @Expect(offset >= 0)
            case None => @Expect(false)
        }
    }

    @TestCase
    func rendersFencedCodeBlockInsideListItem(): Unit {
        let doc = markdownDocument(
            "1. 第一项\n\n   ```go\n   func main() {\n       fmt.Println(\"Hello\")\n   }\n   ```\n\n2. 第二项")
        @Expect(doc.lines.size, 5)
        match (doc.lines[0].kind) {
            case DocumentLineKind.ListItem(true) => @Expect(doc.lines[0].spans[0].text, "第一项")
            case _ => @Expect(false)
        }
        match (doc.lines[1].kind) {
            case DocumentLineKind.CodeBlock => @Expect(doc.lines[1].spans[0].text, "func main() {")
            case _ => @Expect(false)
        }
        @Expect(doc.lines[2].spans[0].text.contains("fmt.Println"))
        match (doc.lines[4].kind) {
            case DocumentLineKind.ListItem(true) => @Expect(doc.lines[4].spans[0].text, "第二项")
            case _ => @Expect(false)
        }

        let buffer = Buffer(Rect(0, 0, 40, 5))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(renderedRow(buffer, 0, 16).startsWith("1. 第一项"))
        @Expect(renderedRow(buffer, 1, 16).startsWith("func main()"))
        @Expect(buffer.getCell(0, 1).style, DocumentTheme().code)
        @Expect(renderedRow(buffer, 4, 16).startsWith("1. 第二项"))
    }

    @TestCase
    func quotedChildrenDoNotResetPreviewSourceOffsets(): Unit {
        let text = "# Top\n\nintro\n\n> quote\n> - item"
        let doc = markdownDocument(text)
        let index = markdownPreviewIndex(doc, 40)
        @Expect(index.renderedLineForSourceOffset(0), 0)
        match (index.sourceOffsetForRenderedLine(4)) {
            case Some(offset) => @Expect(offset > 0)
            case None => @Expect(false)
        }
    }

    @TestCase
    func previewSyncCanMoveUpInsideQuotedBlocks(): Unit {
        let text = "# Top\n\nbefore\n\n> first\n> - second\n> > third\n\nafter"
        let doc = markdownDocument(text)
        let index = markdownPreviewIndex(doc, 40)
        let firstOffset = byteIndex(text, "first")
        let secondOffset = byteIndex(text, "second")
        let thirdOffset = byteIndex(text, "third")
        @Expect(firstOffset > 0)
        @Expect(secondOffset > firstOffset)
        @Expect(thirdOffset > secondOffset)

        let firstLine = index.renderedLineForSourceOffset(firstOffset)
        let secondLine = index.renderedLineForSourceOffset(secondOffset)
        let thirdLine = index.renderedLineForSourceOffset(thirdOffset)
        @Expect(firstLine < secondLine)
        @Expect(secondLine < thirdLine)
        @Expect(index.renderedLineForSourceOffset(firstOffset), firstLine)
    }
    @TestCase
    func codePaletteSurvivesMarkdownMarkersAndUnicodeIdentifiers(): Unit {
        let text = "# 中文😀\n\n```cj\nlet中文 = \"// *\" // let 7\nlet x = 0x1f32\n```\n\n```json\n{\"a\": true, \"b\": -1.25e+3, \"c\": \"#\"}\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 12))
        editor.render(source.area, source)
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        @Expect(source.getCell(0, 3).style, DocumentTheme().code)
        @Expect(source.getCell(0, 4).style, keyword)
        @Expect(source.getCell(11, 3).style, Style(fg: Color.Green))
        @Expect(source.getCell(18, 3).style, Style(fg: Color.Indexed(8)))
        @Expect(source.getCell(1, 8).style, Style(fg: Color.Cyan))
        @Expect(source.getCell(6, 8).style, keyword)
        @Expect(source.getCell(17, 8).style, Style(fg: Color.Yellow))
        let preview = Buffer(Rect(0, 0, 80, 12))
        DocumentView(presentation.document).render(preview.area, preview)
        let firstCode = firstLineIndexContaining(presentation.document, "let中文")
        @Expect(preview.getCell(0, firstCode).style, DocumentTheme().code)
        let json = firstLineIndexContaining(presentation.document, "true")
        @Expect(preview.getCell(2, json).style, Style(fg: Color.Cyan))
        @Expect(preview.getCell(6, json).style, keyword)
    }

    @TestCase
    func sourceSpansAndDecorationsStayAnchoredAcrossRepeatedQuotedBlocks(): Unit {
        let text = "# 中文😀\r\n\r\n> ```cj\r\n> let x = 1\r\n> ```\r\n\r\n```cj\r\nlet x = 1\r\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 12))
        editor.render(source.area, source)
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        @Expect(source.getCell(2, 3).style, keyword)
        @Expect(source.getCell(0, 3).style, DocumentTheme().quoteStyle)
        @Expect(source.getCell(0, 7).style, keyword)
        let expected = byteIndex(text, "let x = 1")
        let first = presentation.document.lines[firstLineIndexContaining(presentation.document, "let x = 1")]
        @Expect(first.spans[0].text, "let")
        @Expect(first.spans[0].sourceRange, Some("${expected}:${expected + 3}"))
        @Expect(first.quoteDepth, 1)
    }
    @TestCase
    func eachSupportedDialectColorsItsOwnSyntaxInBothSurfaces(): Unit {
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        let directive = Style(fg: Color.Cyan, modifier: Modifier.strong())
        let fixtures: Array<(String, String, Int64, Int64, Style)> = [
            ("cj", "/* outer /* inner */ let 7 */\nlet x = r#\"let\"#", 0, 3, Style(fg: Color.Indexed(8))),
            ("c", "#define X 0x1p2\nchar c = 'x';", 0, 0, directive),
            ("cpp", "auto s = R\"tag(\nreturn /*\n)tag\";", 1, 0, Style(fg: Color.Green)),
            ("js", "const t = `return\nstill`;\nlet r = /a[b/]c/g;\nlet q = 8 / 2;", 2, 8, Style(fg: Color.Green)),
            ("ts", "interface Box { readonly x: number }", 0, 0, keyword),
            ("python", "s = f'''return\nstill'''\npass", 1, 0, Style(fg: Color.Green)),
            ("json", "{\"a\": true, \"b\": -1.25e+3}", 0, 1, Style(fg: Color.Cyan)),
            ("sh", "cat <<-EOF\nlet $name\nEOF\nif true; then echo hi; fi #comment", 1, 0, Style(fg: Color.Green))
        ]
        for ((lang, body, row, col, style) in fixtures) {
            let text = "```" + lang + "\n" + body + "\n```"
            let presentation = markdownAstToPresentation(Markdown.parse(text))
            let editor = TextArea(value: text)
            editor.setDecorations(presentation.decorations)
            let source = Buffer(Rect(0, 0, 90, 10))
            editor.render(source.area, source)
            let preview = Buffer(Rect(0, 0, 90, 10))
            DocumentView(presentation.document).render(preview.area, preview)
            @Expect(source.getCell(col, row + 1).style, style)
            @Expect(preview.getCell(col, row).style, style)
        }
    }
    @TestCase
    func literalDelimitersAndNumericSuffixesStopAtTheirActualBoundaries(): Unit {
        let green = Style(fg: Color.Green)
        let yellow = Style(fg: Color.Yellow)
        let cyan = Style(fg: Color.Cyan)
        let cases: Array<(String, String, String, Style, String, String, Style)> = [
            ("cj", "let n = 0b1010u64; let s = r##\"a\"#b\"##", "0b1010u64", yellow, ";", "r##\"a\"#b\"##", green),
            ("c", "char *s = u8\"hi\"; double x = 0x1.8p+2F;", "0x1.8p+2F", yellow, ";", "u8\"hi\"", green),
            ("cpp", "auto s = u8R\"tag(a)not-end)tag\"; auto n = 0xff'eeULL;", "u8R\"tag(a)not-end)tag\"", green, ";", "0xff'eeULL", yellow),
            ("js", "return /a\\/[b/]+/gi; const n = 42n / 2;", "/a\\/[b/]+/gi", green, "/ 2", "42n", yellow),
            ("ts", "const s = `a$" + "{{x: \"b\"}.x}c`;", "`a$" + "{{x: \"b\"}.x}c`", green, ";", "const", Style(fg: Color.Yellow, modifier: Modifier.strong())),
            ("py", "value = fr'''a{{b}}{obj[\"x\"]}z''' ; z = 2j", "fr'''a{{b}}{obj[\"x\"]}z'''", green, ";", "2j", yellow),
            ("json", "{\"key\" : -0.35e-2, \"value\": \"literal\"}", "\"key\"", cyan, ",", "-0.35e-2", yellow),
            ("sh", "echo $'a\\n' $" + "{name} $# ;", "$" + "{name}", cyan, ";", "$'a\\n'", green)
        ]
        for ((lang, body, colored, style, plain, secondary, secondaryStyle) in cases) {
            let text = "```" + lang + "\n" + body + "\n```"
            let presentation = markdownAstToPresentation(Markdown.parse(text))
            let source = TextArea(value: text)
            source.setDecorations(presentation.decorations)
            let sourceCells = Buffer(Rect(0, 0, 100, 3))
            source.render(sourceCells.area, sourceCells)
            let previewCells = Buffer(Rect(0, 0, 100, 1))
            DocumentView(presentation.document).render(previewCells.area, previewCells)
            let coloredAt = byteIndex(body, colored)
            let plainAt = byteIndex(body, plain)
            let secondaryAt = byteIndex(body, secondary)
            @Expect(sourceCells.getCell(coloredAt, 1).style, style)
            @Expect(sourceCells.getCell(coloredAt + colored.size - 1, 1).style, style)
            @Expect(sourceCells.getCell(plainAt, 1).style, DocumentTheme().code)
            @Expect(sourceCells.getCell(secondaryAt, 1).style, secondaryStyle)
            @Expect(sourceCells.getCell(secondaryAt + secondary.size - 1, 1).style, secondaryStyle)
            @Expect(previewCells.getCell(coloredAt, 0).style, style)
            @Expect(previewCells.getCell(plainAt, 0).style, DocumentTheme().code)
            @Expect(previewCells.getCell(secondaryAt, 0).style, secondaryStyle)
        }
    }
    @TestCase
    func quotedAndTabStrippedHereDocumentsStopAtTheirOwnDelimiters(): Unit {
        let text = "```sh\ncat <<-'A' <<B\n$x # literal\n\tA\nif false\nB\nif true; then echo done; fi\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 50, 8))
        editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 50, 6))
        DocumentView(presentation.document).render(preview.area, preview)
        let stringStyle = Style(fg: Color.Green)
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        @Expect(source.getCell(0, 2).style, stringStyle)
        @Expect(source.getCell(0, 4).style, stringStyle)
        @Expect(source.getCell(0, 6).style, keyword)
        @Expect(preview.getCell(0, 1).style, stringStyle)
        @Expect(preview.getCell(0, 3).style, stringStyle)
        @Expect(preview.getCell(0, 5).style, keyword)
    }
    @TestCase
    func shellSpecialParametersAndEscapedHashKeepWordBoundaries(): Unit {
        let body = "echo $? $# $$ $@ $* $!\necho \\#plain # comment\necho \\\nif true"
        let text = "```sh\n" + body + "\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 6))
        editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 80, 4))
        DocumentView(presentation.document).render(preview.area, preview)
        let first = "echo $? $# $$ $@ $* $!"
        for (variable in ["$?", "$#", "$$", "$@", "$*", "$!"]) {
            let at = byteIndex(first, variable)
            @Expect(source.getCell(at, 1).style, Style(fg: Color.Cyan))
            @Expect(source.getCell(at + 1, 1).style, Style(fg: Color.Cyan))
            @Expect(preview.getCell(at, 0).style, Style(fg: Color.Cyan))
        }
        let second = "echo \\#plain # comment"
        let plain = byteIndex(second, "#plain")
        let comment = byteIndex(second, "# comment")
        @Expect(source.getCell(plain, 2).style, DocumentTheme().code)
        @Expect(source.getCell(comment, 2).style, Style(fg: Color.Indexed(8)))
        @Expect(preview.getCell(plain, 1).style, DocumentTheme().code)
        @Expect(preview.getCell(comment, 1).style, Style(fg: Color.Indexed(8)))
        let keyword = Style(fg: Color.Yellow, modifier: Modifier.strong())
        @Expect(source.getCell(0, 4).style, keyword)
        @Expect(preview.getCell(0, 3).style, keyword)
    }
    @TestCase
    func pythonPrefixPairsColorOnlySupportedStringCombinations(): Unit {
        let body = "Rb\"raw\" Br'bytes' fR\"{x}\" rF'''a{{b}}{x}''' bf\"bad\""
        let text = "```python\n" + body + "\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 3))
        editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 80, 1))
        DocumentView(presentation.document).render(preview.area, preview)
        let stringStyle = Style(fg: Color.Green)
        for (valid in ["Rb\"raw\"", "Br'bytes'", "fR\"{x}\"", "rF'''a{{b}}{x}'''"]) {
            let at = byteIndex(body, valid)
            @Expect(source.getCell(at, 1).style, stringStyle)
            @Expect(source.getCell(at + valid.size - 1, 1).style, stringStyle)
            @Expect(preview.getCell(at, 0).style, stringStyle)
        }
        let invalid = byteIndex(body, "bf\"bad\"")
        @Expect(source.getCell(invalid, 1).style, DocumentTheme().code)
        @Expect(source.getCell(invalid + 2, 1).style, stringStyle)
        @Expect(preview.getCell(invalid, 0).style, DocumentTheme().code)
        @Expect(preview.getCell(invalid + 2, 0).style, stringStyle)
    }
    @TestCase
    func basedAndFractionalNumbersKeepOnlyValidSeparators(): Unit {
        let body = "0b10_01 0o7_5 0xA_F 1_000.2_5e+1_0 0x_1"
        let text = "```cj\n" + body + "\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 3))
        editor.render(source.area, source)
        let preview = Buffer(Rect(0, 0, 80, 1))
        DocumentView(presentation.document).render(preview.area, preview)
        let number = Style(fg: Color.Yellow)
        for (valid in ["0b10_01", "0o7_5", "0xA_F", "1_000.2_5e+1_0"]) {
            let at = byteIndex(body, valid)
            @Expect(source.getCell(at, 1).style, number)
            @Expect(source.getCell(at + valid.size - 1, 1).style, number)
            @Expect(preview.getCell(at + valid.size - 1, 0).style, number)
        }
        let invalid = byteIndex(body, "0x_1")
        @Expect(source.getCell(invalid, 1).style, number)
        @Expect(source.getCell(invalid + 1, 1).style, DocumentTheme().code)
        @Expect(preview.getCell(invalid + 1, 0).style, DocumentTheme().code)
    }
    @TestCase
    func astFenceOwnershipPreventsInnerMarkersFromLeakingStyles(): Unit {
        let text = "# Before\n````cj\n```\nlet x = 1\n````\n# After\n\n~~~go\n# title\n*x* [a](b)\n~~~"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(presentation.decorations)
        let source = Buffer(Rect(0, 0, 80, 13))
        editor.render(source.area, source)
        @Expect(source.getCell(0, 2).style, DocumentTheme().code)
        @Expect(source.getCell(0, 3).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        @Expect(source.getCell(0, 5).style, DocumentTheme().headingStyle(1))
        @Expect(source.getCell(0, 8).style, DocumentTheme().code)
        @Expect(source.getCell(0, 9).style, DocumentTheme().code)
        let preview = Buffer(Rect(0, 0, 80, 13))
        DocumentView(presentation.document).render(preview.area, preview)
        let keywordRow = firstLineIndexContaining(presentation.document, "let x")
        @Expect(preview.getCell(0, keywordRow).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        let unknownRow = firstLineIndexContaining(presentation.document, "# title")
        @Expect(preview.getCell(0, unknownRow).style, DocumentTheme().code)
    }

    @TestCase
    func codeThemeBackgroundAndSelectionOverrideTokenForeground(): Unit {
        let theme = DocumentTheme(code: Style(fg: Color.Magenta, bg: Color.Blue))
        let text = "```cj\nlet s = \"let\"\n```"
        let result = markdownAstToPresentation(Markdown.parse(text), theme: theme)
        let editor = TextArea(value: text)
        editor.setDecorations(result.decorations)
        let source = Buffer(Rect(0, 0, 30, 3))
        editor.render(source.area, source)
        @Expect(source.getCell(0, 1).style, Style(fg: Color.Yellow, bg: Color.Blue, modifier: Modifier.strong()))
        @Expect(source.getCell(8, 1).style, Style(fg: Color.Green, bg: Color.Blue))
        editor.select(6, 9)
        let selected = Buffer(Rect(0, 0, 30, 3))
        editor.render(selected.area, selected)
        @Expect(selected.getCell(0, 1).style, Style(fg: Color.Black, bg: Color.White, modifier: Modifier.strong()))
        let preview = Buffer(Rect(0, 0, 30, 2))
        DocumentView(result.document).render(preview.area, preview)
        @Expect(preview.getCell(0, 0).style, Style(fg: Color.Yellow, bg: Color.Blue, modifier: Modifier.strong()))
    }
    @TestCase
    func listIndentAndTabKeepKeywordOnItsOwnSourceBytes(): Unit {
        let text = "- item\n\n  ```cj\n  \tlet x = 1\n  ```"
        let presentation = markdownAstToPresentation(Markdown.parse(text))
        let expected = byteIndex(text, "let x = 1")
        let codeLine = presentation.document.lines[firstLineIndexContaining(presentation.document, "let x = 1")]
        var found = false
        for (span in codeLine.spans) {
            if (span.text == "let") {
                @Expect(span.sourceRange, Some("${expected}:${expected + 3}"))
                @Expect(span.style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
                found = true
            }
        }
        @Expect(found)
    }
    @TestCase
    func unsupportedAndIndentedCodeDoNotAcquireMarkdownOrLanguageColors(): Unit {
        let text = "```\n# title\n```\n\n```go\n*x* [a](b)\n```\n\n    # indented\n\n```jsonc\ntrue\n```\n\n```cj\n```\n\n# Outside"
        let result = markdownAstToPresentation(Markdown.parse(text))
        let editor = TextArea(value: text)
        editor.setDecorations(result.decorations)
        let source = Buffer(Rect(0, 0, 80, 19))
        editor.render(source.area, source)
        @Expect(source.getCell(0, 1).style, DocumentTheme().code)
        @Expect(source.getCell(0, 5).style, DocumentTheme().code)
        @Expect(source.getCell(4, 8).style, DocumentTheme().code)
        @Expect(source.getCell(0, 11).style, DocumentTheme().code)
        @Expect(source.getCell(0, 17).style, DocumentTheme().headingStyle(1))
        for (needle in ["# title", "*x* [a](b)", "# indented", "true"]) {
            let line = result.document.lines[firstLineIndexContaining(result.document, needle)]
            @Expect(lineText(line).contains(needle))
            @Expect(line.spans[0].style, DocumentTheme().code)
        }
        var emptyBlock = false
        for (line in result.document.lines) {
            if (let DocumentLineKind.CodeBlock <- line.kind) {
                if (lineText(line).isEmpty()) { emptyBlock = true }
            }
        }
        @Expect(emptyBlock)
    }
    @TestCase
    func numericSuffixesDoNotColorInvalidFollowingText(): Unit {
        let fixtures: Array<(String, String, Int64, Int64)> = [
            ("c", "12uLLf", 4, 5),
            ("cpp", "1.25fl", 4, 5),
            ("js", "1.0n", 2, 3)
        ]
        for ((lang, body, colored, plain) in fixtures) {
            let result = markdownAstToPresentation(Markdown.parse("```" + lang + "\n" + body + "\n```"))
            let preview = Buffer(Rect(0, 0, 30, 2))
            DocumentView(result.document).render(preview.area, preview)
            @Expect(preview.getCell(colored, 0).style, Style(fg: Color.Yellow))
            @Expect(preview.getCell(plain, 0).style, DocumentTheme().code)
        }
    }
    @TestCase
    func cLineSplicesKeepCommentsAndQuotesAcrossCrLf(): Unit {
        let comment = markdownAstToPresentation(Markdown.parse("```c\n// note \\\nreturn 3\nint x = 0;\n```"))
        let source = TextArea(value: "```c\n// note \\\nreturn 3\nint x = 0;\n```")
        source.setDecorations(comment.decorations)
        let cells = Buffer(Rect(0, 0, 30, 5))
        source.render(cells.area, cells)
        @Expect(cells.getCell(0, 2).style, Style(fg: Color.Indexed(8)))
        @Expect(cells.getCell(0, 3).style, Style(fg: Color.Cyan))
        let literal = "```cpp\r\nconst char* s = \"a\\\r\nb\";\r\nint x;\r\n```"
        let quoted = markdownAstToPresentation(Markdown.parse(literal))
        let editor = TextArea(value: literal)
        editor.setDecorations(quoted.decorations)
        let continued = Buffer(Rect(0, 0, 40, 5))
        editor.render(continued.area, continued)
        @Expect(continued.getCell(0, 2).style, Style(fg: Color.Green))
        @Expect(continued.getCell(0, 3).style, Style(fg: Color.Cyan))
    }
    @TestCase
    func unterminatedFenceMapsCrOnlyBodyBytesWithoutGuessing(): Unit {
        let text = "~~~CangJie\rlet x = 1\rnext"
        let result = markdownAstToPresentation(Markdown.parse(text))
        let codeLine = result.document.lines[firstLineIndexContaining(result.document, "let x = 1")]
        let offset = byteIndex(text, "let x = 1")
        @Expect(codeLine.spans[0].text, "let")
        @Expect(codeLine.spans[0].style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        @Expect(codeLine.spans[0].sourceRange, Some("${offset}:${offset + 3}"))
        let preview = Buffer(Rect(0, 0, 30, 3))
        DocumentView(result.document).render(preview.area, preview)
        @Expect(preview.getCell(0, 0).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        @Expect(preview.getCell(0, 1).style, DocumentTheme().code)
    }
    @TestCase
    func syntaxConfigRejectsAmbiguousDeclarationsWithPhysicalLines(): Unit {
        let invalid: Array<(String, Int64)> = [
            ("", 1),
            ("# comment\r\n", 2),
            ("syntax 2", 1),
            ("syntax 1\r\nlanguage workflow\r\naliases wf wf\r\nend", 3),
            ("syntax 1\nlanguage workflow\nnumbers decimal\nnumbers decimal\nend", 4),
            ("syntax 1\nlanguage workflow\nblock-comment x x nested\nend", 3),
            ("syntax 1\n# ignored\nlanguage cj\nend", 3),
            ("syntax 1\nlanguage workflow\nkeywords task", 4),
            ("syntax 1\nlanguage first\nline-comment \"#\"\nlanguage second\nend", 4),
            ("syntax 1\nextend cj\nkeywords task\nextend js\nend", 4),
            ("syntax 1\nlanguage workflow\nline-comment \"\"\nend", 3),
            ("syntax 1\nlanguage workflow\nstring q q q single\nend", 3),
            ("syntax 1\nlanguage workflow\nnumbers unsupported\nend", 3),
            ("syntax 1\nlanguage workflow\nstyle keyword indexed:256\nend", 3),
            ("syntax 1\nlanguage workflow\nstyle keyword red bold bold\nend", 3),
            ("syntax 1\nlanguage workflow\nkeywords bad-word\nend", 3),
            ("syntax 1\nlanguage workflow\naliases cj\nend", 3),
            ("syntax 1\nlanguage workflow\nunknown thing\nend", 3),
            ("syntax 1\nlanguage workflow\naliases \"unterminated\nend", 3),
            ("syntax 1\nlanguage workflow\naliases \"a\\x\"\nend", 3),
            ("syntax 1\nlanguage workflow\naliases \"a\"b\nend", 3),
            ("syntax 1\nlanguage workflow\nline-comment \"#\"\nline-comment \"#\"\nend", 4),
            ("syntax 1\nlanguage workflow\naliases wf\u{1B}\nend", 3)
        ]
        for ((input, line) in invalid) {
            var message = ""
            try { _ = parseSyntaxHighlightConfig(input) }
            catch (error: IllegalArgumentException) { message = error.message }
            @Expect(message.startsWith("syntax config line " + line.toString() + ":"))
        }
    }
    @TestCase
    func configuredAliasColorsBothSurfacesWithoutLeakingIntoUnknownFences(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\ntypes Text\nline-comment \"#\"\nnumbers decimal\nstyle keyword cyan bold\nend")
        let text = "```WF\ntask Text 12.5e2 # task\n```\n\n```unknown\ntask Text\n```"
        let result = markdownAstToPresentation(Markdown.parse(text), syntax: Some(config))
        let editor = TextArea(value: text)
        editor.setDecorations(result.decorations)
        let source = Buffer(Rect(0, 0, 50, 9))
        editor.render(source.area, source)
        let keyword = Style(fg: Color.Cyan, modifier: Modifier.strong())
        @Expect(source.getCell(0, 1).style, keyword)
        @Expect(source.getCell(5, 1).style, Style(fg: Color.Cyan))
        @Expect(source.getCell(10, 1).style, Style(fg: Color.Yellow))
        @Expect(source.getCell(17, 1).style, Style(fg: Color.Indexed(8)))
        @Expect(source.getCell(0, 6).style, DocumentTheme().code)
        let preview = Buffer(Rect(0, 0, 50, 5))
        DocumentView(result.document).render(preview.area, preview)
        @Expect(preview.getCell(0, 0).style, keyword)
        @Expect(preview.getCell(17, 0).style, Style(fg: Color.Indexed(8)))
    }
    @TestCase
    func configuredStringsAndNestedCommentsRespectStateAndBlockBoundary(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task emit\nline-comment \"#\"\nblock-comment \"/*\" \"*/\" nested\nstring \"\\\"\" \"\\\"\" \"\\\\\" single\nstring \"\\\"\\\"\\\"\" \"\\\"\\\"\\\"\" \"\\\\\" multi\nstyle keyword cyan bold\nend")
        let text = "```wf\n\"\"\"task\nemit\"\"\" task\n/* outer /* task */ inner */ task\n\"emit\\\"task\" task\n```\n\n```WORKFLOW\ntask\n```"
        let result = markdownAstToPresentation(Markdown.parse(text), syntax: Some(config))
        let editor = TextArea(value: text)
        editor.setDecorations(result.decorations)
        let source = Buffer(Rect(0, 0, 55, 12))
        editor.render(source.area, source)
        let keyword = Style(fg: Color.Cyan, modifier: Modifier.strong())
        @Expect(source.getCell(3, 1).style, Style(fg: Color.Green))
        @Expect(source.getCell(0, 2).style, Style(fg: Color.Green))
        @Expect(source.getCell(8, 2).style, keyword)
        @Expect(source.getCell(12, 3).style, Style(fg: Color.Indexed(8)))
        @Expect(source.getCell(29, 3).style, keyword)
        @Expect(source.getCell(7, 4).style, Style(fg: Color.Green))
        @Expect(source.getCell(13, 4).style, keyword)
        @Expect(source.getCell(0, 8).style, keyword)
        let preview = Buffer(Rect(0, 0, 55, 9))
        DocumentView(result.document).render(preview.area, preview)
        @Expect(preview.getCell(8, 1).style, keyword)
        @Expect(preview.getCell(0, 5).style, keyword)
    }
    @TestCase
    func configuredPalettePreservesUtf8SourceMappingAndSelection(): Unit {
        let config = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword #D787FF\nend")
        let text = "# 中文\r\n> ```WF\r\n> task 中文\r\n> ```\r\n\r\n```wf\r\ntask 中文\r\n```"
        var italic = Modifier.none()
        italic.italic = true
        let expected = Style(fg: Color.Rgb(215, 135, 255), bg: Color.Blue, modifier: italic)
        let theme = DocumentTheme(code: Style(fg: Color.White, bg: Color.Blue, modifier: italic))
        let result = markdownAstToPresentation(Markdown.parse(text), theme: theme, syntax: Some(config))
        let first = byteIndex(text, "task 中文")
        let second = first + 4 + byteIndex(text[first + 4..text.size], "task 中文")
        var found: Int64 = 0
        for (line in result.document.lines) {
            for (span in line.spans) {
                if (span.text == "task") {
                    let offset = if (found == 0) { first } else { second }
                    @Expect(span.sourceRange, Some(offset.toString() + ":" + (offset + 4).toString()))
                    @Expect(span.style, expected)
                    found++
                }
            }
        }
        @Expect(found, 2)
        let editor = TextArea(value: text)
        editor.setDecorations(result.decorations)
        let source = Buffer(Rect(0, 0, 50, 9))
        editor.render(source.area, source)
        @Expect(source.getCell(2, 2).style, expected)
        @Expect(source.getCell(0, 6).style, expected)
        editor.select(first, first + 4)
        let selected = Buffer(Rect(0, 0, 50, 9))
        editor.render(selected.area, selected)
        @Expect(selected.getCell(2, 2).style, Style(fg: Color.Black, bg: Color.White, modifier: italic))
        let preview = Buffer(Rect(0, 0, 50, 5))
        DocumentView(result.document).render(preview.area, preview)
        let firstCode = firstLineIndexContaining(result.document, "task 中文")
        @Expect(preview.getCell(2, firstCode).style, expected)
    }
    @TestCase
    func extendRetainsBuiltinLexerWhileReplaceUsesOnlyDeclaredRules(): Unit {
        let extended = parseSyntaxHighlightConfig("syntax 1\nextend Cangjie\nkeywords service\ntypes Money\nstyle keyword magenta bold\nend")
        let text = "```cj\nlet service Money = r#\"service\"#\n```\n\n```js\nlet service\n```"
        let presentation = markdownAstToPresentation(Markdown.parse(text), syntax: Some(extended))
        let source = TextArea(value: text)
        source.setDecorations(presentation.decorations)
        let buffer = Buffer(Rect(0, 0, 50, 9))
        source.render(buffer.area, buffer)
        let keyword = Style(fg: Color.Magenta, modifier: Modifier.strong())
        @Expect(buffer.getCell(0, 1).style, keyword)
        @Expect(buffer.getCell(4, 1).style, keyword)
        @Expect(buffer.getCell(12, 1).style, Style(fg: Color.Cyan))
        @Expect(buffer.getCell(20, 1).style, Style(fg: Color.Green))
        @Expect(buffer.getCell(0, 5).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        let replaced = parseSyntaxHighlightConfig("syntax 1\nlanguage cj replace\nkeywords task\nstyle keyword cyan bold\nend")
        let replacement = "```cangjie\nlet task\n```\n\n```cj\nlet task\n```"
        let result = markdownAstToPresentation(Markdown.parse(replacement), syntax: Some(replaced))
        let editor = TextArea(value: replacement)
        editor.setDecorations(result.decorations)
        let actual = Buffer(Rect(0, 0, 40, 9))
        editor.render(actual.area, actual)
        @Expect(actual.getCell(0, 1).style, DocumentTheme().code)
        @Expect(actual.getCell(4, 1).style, Style(fg: Color.Cyan, modifier: Modifier.strong()))
        @Expect(actual.getCell(4, 5).style, Style(fg: Color.Cyan, modifier: Modifier.strong()))
    }

    @TestCase
    func separateConfigurationsCannotChangeExistingPresentation(): Unit {
        let red = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword red\nend")
        let blue = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nkeywords task\nstyle keyword blue\nend")
        let text = "```wf\ntask\n```"
        let first = markdownAstToPresentation(Markdown.parse(text), syntax: Some(red))
        let second = markdownAstToPresentation(Markdown.parse(text), syntax: Some(blue))
        @Expect(first.document.lines[0].spans[0].style, Style(fg: Color.Red))
        @Expect(second.document.lines[0].spans[0].style, Style(fg: Color.Blue))
        var rejected = false
        try { _ = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\naliases wf\nend\nlanguage another\naliases wf\nend") }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
        let again = markdownAstToPresentation(Markdown.parse(text), syntax: Some(red))
        @Expect(again.document.lines[0].spans[0].style, Style(fg: Color.Red))
    }
    @TestCase
    func syntaxConfigEnforcesEveryBoundAtTheDeclarationThatCrossesIt(): Unit {
        let words = StringBuilder()
        words.append("syntax 1\nlanguage workflow\nkeywords")
        for (i in 0..4096) { words.append(" w" + i.toString()) }
        words.append("\nend")
        let config = parseSyntaxHighlightConfig(words.toString())
        let rendered = markdownAstToPresentation(Markdown.parse("```workflow\nw4095\n```"), syntax: Some(config))
        @Expect(rendered.document.lines[0].spans[0].style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        let overflowWords = words.toString().replace("\nend", " w4096\nend")
        let aliases = StringBuilder()
        aliases.append("syntax 1\nlanguage workflow\naliases")
        for (i in 0..64) { aliases.append(" a" + i.toString()) }
        aliases.append("\naliases a64\nend")
        let delimiters = StringBuilder()
        delimiters.append("syntax 1\nlanguage workflow\n")
        for (i in 0..65) { delimiters.append("line-comment #" + i.toString() + "\n") }
        delimiters.append("end")
        let languages = StringBuilder()
        languages.append("syntax 1\n")
        for (i in 0..65) { languages.append("language l" + i.toString() + "\nend\n") }
        let tooLarge = String.fromUtf8(Array<Byte>(262145, repeat: b' '))
        let invalid: Array<(String, Int64)> = [
            (overflowWords, 3), (aliases.toString(), 4), (delimiters.toString(), 67),
            (languages.toString(), 130), (tooLarge, 1)
        ]
        for ((input, line) in invalid) {
            var message = ""
            try { _ = parseSyntaxHighlightConfig(input) }
            catch (error: IllegalArgumentException) { message = error.message }
            @Expect(message.startsWith("syntax config line " + line.toString() + ":"))
        }
    }
    @TestCase
    func configuredNumberProfilesKeepSignsRangesAndSuffixesDistinct(): Unit {
        let code = "1..3 12.5e2 -4 0xFF 1i64"
        let text = "```num\n" + code + "\n```"
        for (profile in ["decimal", "none", "json", "cj"]) {
            let config = parseSyntaxHighlightConfig("syntax 1\nlanguage num\nnumbers " + profile + "\nend")
            let result = markdownAstToPresentation(Markdown.parse(text), syntax: Some(config))
            let preview = Buffer(Rect(0, 0, 40, 2))
            DocumentView(result.document).render(preview.area, preview)
            let base = DocumentTheme().code
            let number = Style(fg: Color.Yellow)
            @Expect(preview.getCell(1, 0).style, base)
            @Expect(preview.getCell(2, 0).style, base)
            @Expect(preview.getCell(12, 0).style, if (profile == "json") { number } else { base })
            @Expect(preview.getCell(16, 0).style, if (profile == "cj") { number } else { base })
            @Expect(preview.getCell(21, 0).style, if (profile == "cj") { number } else { base })
            @Expect(preview.getCell(5, 0).style, if (profile == "none") { base } else { number })
        }
    }
    @TestCase
    func bomCrConfigAndUnclosedStatesResetAtLineAndBlockBoundaries(): Unit {
        let config = parseSyntaxHighlightConfig("\u{FEFF}syntax 1\r\nlanguage workflow\r\nkeywords task\r\nstring q q \"\" single\r\nblock-comment \"/*\" \"*/\" nested\r\nstyle keyword cyan bold\r\nend")
        let text = "```workflow\r\nqtask\r\ntask\r\n/* task\r\n```\r\n\r\n```workflow\r\ntask\r\n```"
        let result = markdownAstToPresentation(Markdown.parse(text), syntax: Some(config))
        let source = TextArea(value: text)
        source.setDecorations(result.decorations)
        let buffer = Buffer(Rect(0, 0, 40, 10))
        source.render(buffer.area, buffer)
        let keyword = Style(fg: Color.Cyan, modifier: Modifier.strong())
        @Expect(buffer.getCell(1, 1).style, Style(fg: Color.Green))
        @Expect(buffer.getCell(0, 2).style, keyword)
        @Expect(buffer.getCell(3, 3).style, Style(fg: Color.Indexed(8)))
        @Expect(buffer.getCell(0, 7).style, keyword)
        var seen: Int64 = 0
        for (line in result.document.lines) {
            if (lineText(line) == "task") {
                @Expect(line.spans[0].style, keyword)
                seen++
            }
        }
        @Expect(seen, 2)
    }
}

func renderedRow(buffer: Buffer, y: Int64, width: Int64): String {
    let builder = StringBuilder()
    for (x in 0..width) {
        builder.append(buffer.getCell(x, y).symbol)
    }
    builder.toString()
}

func firstLineIndexContaining(doc: Document, needle: String): Int64 {
    for (i in 0..doc.lines.size) {
        if (lineText(doc.lines[i]).contains(needle)) {
            return i
        }
    }
    0
}

func firstTableHeaderLine(doc: Document): Int64 {
    for (i in 0..doc.lines.size) {
        match (doc.lines[i].kind) {
            case DocumentLineKind.TableHeader => return i
            case _ => ()
        }
    }
    0
}

func lineText(line: DocumentLine): String {
    let builder = StringBuilder()
    for (span in line.spans) {
        builder.append(span.text)
    }
    builder.toString()
}

func byteIndex(text: String, needle: String): Int64 {
    if (needle.isEmpty()) {
        return 0
    }
    var i: Int64 = 0
    while (i + needle.size <= text.size) {
        var ok = true
        for (j in 0..needle.size) {
            if (text[i + j] != needle[j]) {
                ok = false
            }
        }
        if (ok) {
            return i
        }
        i++
    }
    -1
}
