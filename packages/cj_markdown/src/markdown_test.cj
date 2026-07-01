package cj_markdown

import std.unittest.*
import std.unittest.testmacro.*

@Test
class MarkdownParserTest {
    @TestCase
    func parsesBlockKindsAndMetadata(): Unit {
        let doc = parseMarkdown("# Title ###\n\n- item\n  1. ordered\n> quote\n```cj\nmain\n```\n| a | b |\n| :--- | ---: |\n| c | d |")
        @Expect(doc.blocks.size, 6)
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.Heading(level) => @Expect(level, 1)
            case _ => @Expect(false)
        }
        @Expect(doc.blocks[0].text, "Title")
        match (doc.blocks[2].kind) {
            case MarkdownBlockKind.List =>
                @Expect(doc.blocks[2].children.size, 1)
                match (doc.blocks[2].children[0].kind) {
                    case MarkdownBlockKind.ListItem(false, level) => @Expect(level, 0)
                    case _ => @Expect(false)
                }
                @Expect(doc.blocks[2].children[0].children.size, 1)
                match (doc.blocks[2].children[0].children[0].kind) {
                    case MarkdownBlockKind.ListItem(true, level) => @Expect(level, 1)
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
        match (doc.blocks[4].kind) {
            case MarkdownBlockKind.CodeBlock(language) => @Expect(language, "cj")
            case _ => @Expect(false)
        }
        @Expect(doc.blocks[4].text, "main")
        match (doc.blocks[5].table) {
            case Some(table) =>
                @Expect(table.header.cells[0].text, "a")
                @Expect(table.rows[0].cells[1].text, "d")
                match (table.alignments[0]) {
                    case MarkdownTableAlign.Left => ()
                    case _ => @Expect(false)
                }
                match (table.alignments[1]) {
                    case MarkdownTableAlign.Right => ()
                    case _ => @Expect(false)
                }
            case None => @Expect(false)
        }
    }

    @TestCase
    func parsesSourceRangesTaskListAndDiagnostics(): Unit {
        let doc = parseMarkdown("# A\n- [x] done\n---\n```cj\nopen")
        match (doc.blocks[0].range) {
            case Some(range) =>
                @Expect(range.start.line, 0)
                @Expect(range.start.offset, 0)
            case None => @Expect(false)
        }
        match (doc.blocks[1].children[0].kind) {
            case MarkdownBlockKind.TaskListItem(true, level) => @Expect(level, 0)
            case _ => @Expect(false)
        }
        match (doc.blocks[2].kind) {
            case MarkdownBlockKind.HorizontalRule => ()
            case _ => @Expect(false)
        }
        @Expect(doc.diagnostics.size, 1)
    }

    @TestCase
    func parsesSetextHtmlStrikethroughAndInlineChildren(): Unit {
        let doc = parseMarkdown("Title\n===\n\n<div>x</div>\n\nA ~~gone~~ and **[link](url)**")
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.Heading(level) => @Expect(level, 1)
            case _ => @Expect(false)
        }
        match (doc.blocks[2].kind) {
            case MarkdownBlockKind.HtmlBlock => @Expect(doc.blocks[2].text, "<div>x</div>")
            case _ => @Expect(false)
        }
        let inlines = doc.blocks[4].inlines
        match (inlines[1].kind) {
            case MarkdownInlineKind.Strikethrough => @Expect(inlines[1].text, "gone")
            case _ => @Expect(false)
        }
        match (inlines[3].kind) {
            case MarkdownInlineKind.Strong =>
                @Expect(inlines[3].children.size, 1)
                match (inlines[3].children[0].kind) {
                    case MarkdownInlineKind.Link(url, _) => @Expect(url, "url")
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
    }

    @TestCase
    func mergesParagraphLinesAndQuotes(): Unit {
        let doc = parseMarkdown("first line\nsecond line\n\n> a\n> - b")
        @Expect(doc.blocks.size, 3)
        @Expect(doc.blocks[0].text, "first line second line")
        @Expect(doc.blocks[2].text, "a - b")
        @Expect(doc.blocks[2].children.size > 0)
    }

    @TestCase
    func parsesInlineMarkersReferencesAutolinksAndEscapes(): Unit {
        let doc = parseMarkdown("[id]: https://example.com \"t\"\nplain [link][id] ![alt][id] <https://cangjie-lang.cn> `code` **strong** *em* \\*")
        let inlines = doc.blocks[1].inlines
        @Expect(inlines.size, 13)
        match (inlines[1].kind) {
            case MarkdownInlineKind.Link(url, title) =>
                @Expect(url, "https://example.com")
                @Expect(title, "t")
            case _ => @Expect(false)
        }
        match (inlines[3].kind) {
            case MarkdownInlineKind.Image(url) => @Expect(url, "https://example.com")
            case _ => @Expect(false)
        }
        match (inlines[5].kind) {
            case MarkdownInlineKind.Link(url, _) => @Expect(url, "https://cangjie-lang.cn")
            case _ => @Expect(false)
        }
        match (inlines[7].kind) {
            case MarkdownInlineKind.Code => @Expect(inlines[7].text, "code")
            case _ => @Expect(false)
        }
        match (inlines[9].kind) {
            case MarkdownInlineKind.Strong => @Expect(inlines[9].text, "strong")
            case _ => @Expect(false)
        }
        match (inlines[12].kind) {
            case MarkdownInlineKind.Text => @Expect(inlines[12].text, " *")
            case _ => @Expect(false)
        }
        match (inlines[1].range) {
            case Some(range) =>
                @Expect(range.start.offset > 0)
                @Expect(range.start.column < range.start.offset)
            case None => @Expect(false)
        }
    }

    @TestCase
    func preservesParagraphLineSourcesAndAdditionalInlineForms(): Unit {
        let doc = parseMarkdown("[shortcut]: https://example.com\nfirst **line**\nsecond [shortcut] ``code ` span``")
        @Expect(doc.blocks[1].text, "first **line** second [shortcut] ``code ` span``")
        let inlines = doc.blocks[1].inlines
        var sawBreak = false
        var sawShortcut = false
        var sawCode = false
        for (inline in inlines) {
            match (inline.kind) {
                case MarkdownInlineKind.SoftBreak =>
                    sawBreak = true
                    match (inline.range) {
                        case Some(range) => @Expect(range.end.line, 2)
                        case None => @Expect(false)
                    }
                case MarkdownInlineKind.Link(url, _) =>
                    if (url == "https://example.com") { sawShortcut = true }
                case MarkdownInlineKind.Code =>
                    if (inline.text == "code ` span") { sawCode = true }
                case _ => ()
            }
        }
        @Expect(sawBreak)
        @Expect(sawShortcut)
        @Expect(sawCode)
    }

    @TestCase
    func parsesEscapedPipeTableCells(): Unit {
        let doc = parseMarkdown("| a\\|b | c |\n| --- | --- |\n| x | y |")
        match (doc.blocks[0].table) {
            case Some(table) =>
                @Expect(table.header.cells.size, 2)
                @Expect(table.header.cells[0].text, "a|b")
            case None => @Expect(false)
        }
    }

    @TestCase
    func parsesChineseTableAndInlineText(): Unit {
        let doc = parseMarkdown("| 姓名 | 角色 | 状态 |\n| --- | --- | --- |\n| 张三 | 开发者 | 正常 |\n| 李四 | 测试员 | 休假 |")
        @Expect(doc.diagnostics.size, 0)
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.Table => ()
            case _ => @Expect(false)
        }
        match (doc.blocks[0].table) {
            case Some(table) =>
                @Expect(table.header.cells.size, 3)
                @Expect(table.header.cells[0].text, "姓名")
                @Expect(table.header.cells[1].text, "角色")
                @Expect(table.header.cells[2].text, "状态")
                @Expect(table.rows.size, 2)
                @Expect(table.rows[0].cells[0].text, "张三")
                @Expect(table.rows[0].cells[1].text, "开发者")
                @Expect(table.rows[0].cells[2].text, "正常")
                @Expect(table.rows[1].cells[0].text, "李四")
                @Expect(table.rows[1].cells[1].text, "测试员")
                @Expect(table.rows[1].cells[2].text, "休假")
            case None => @Expect(false)
        }

        let inlineDoc = parseMarkdown("中文 **加粗** 和 [链接](url)")
        @Expect(inlineDoc.blocks.size, 1)
        let inlines = inlineDoc.blocks[0].inlines
        @Expect(inlines[0].text, "中文 ")
        match (inlines[1].kind) {
            case MarkdownInlineKind.Strong => @Expect(inlines[1].text, "加粗")
            case _ => @Expect(false)
        }
        match (inlines[3].kind) {
            case MarkdownInlineKind.Link(url, _) => @Expect(url, "url")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func coversCommonMarkAndGfmInlineRegressions(): Unit {
        let doc = parseMarkdown("***both*** `**code**` [**strong link**](url)\n\n- [ ] todo\n- [x] done\n\n<https://example.com>\n\n| a | b |\n| --- | --- |\n| ~~gone~~ | ok |")
        let first = doc.blocks[0].inlines
        match (first[0].kind) {
            case MarkdownInlineKind.Strong =>
                @Expect(first[0].text, "both")
                @Expect(first[0].children.size, 1)
                match (first[0].children[0].kind) {
                    case MarkdownInlineKind.Emphasis => @Expect(first[0].children[0].text, "both")
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
        match (first[2].kind) {
            case MarkdownInlineKind.Code => @Expect(first[2].text, "**code**")
            case _ => @Expect(false)
        }
        match (first[4].kind) {
            case MarkdownInlineKind.Link(url, _) =>
                @Expect(url, "url")
                @Expect(first[4].children.size, 1)
                match (first[4].children[0].kind) {
                    case MarkdownInlineKind.Strong => @Expect(first[4].children[0].text, "strong link")
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
        match (doc.blocks[2].children[0].kind) {
            case MarkdownBlockKind.TaskListItem(false, _) => ()
            case _ => @Expect(false)
        }
        match (doc.blocks[2].children[1].kind) {
            case MarkdownBlockKind.TaskListItem(true, _) => ()
            case _ => @Expect(false)
        }
        match (doc.blocks[4].inlines[0].kind) {
            case MarkdownInlineKind.Link(url, _) => @Expect(url, "https://example.com")
            case _ => @Expect(false)
        }
        match (doc.blocks[6].table) {
            case Some(table) =>
                @Expect(table.rows[0].cells[0].text, "~~gone~~")
                match (table.rows[0].cells[0].inlines[0].kind) {
                    case MarkdownInlineKind.Strikethrough => @Expect(table.rows[0].cells[0].inlines[0].text, "gone")
                    case _ => @Expect(false)
                }
            case None => @Expect(false)
        }
    }

    @TestCase
    func nestsListItemsAndIndentedBlockQuotes(): Unit {
        let doc = parseMarkdown("- parent\n  - child\n    - grandchild")
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.List =>
                @Expect(doc.blocks[0].children.size, 1)
                let parent = doc.blocks[0].children[0]
                @Expect(parent.children.size, 1)
                match (parent.children[0].kind) {
                    case MarkdownBlockKind.ListItem(false, level) => @Expect(level, 1)
                    case _ => @Expect(false)
                }
                @Expect(parent.children[0].children.size, 1)
            case _ => @Expect(false)
        }
        let quotedDoc = parseMarkdown("  > quote")
        match (quotedDoc.blocks[0].kind) {
            case MarkdownBlockKind.Quote => @Expect(quotedDoc.blocks[0].text, "quote")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func parsesIndentedCodeAndListContinuation(): Unit {
        let doc = parseMarkdown("    let x = 1\n    x\n\n- item\n  continuation")
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.CodeBlock(language) =>
                @Expect(language, "")
                @Expect(doc.blocks[0].text, "let x = 1\nx")
            case _ => @Expect(false)
        }
        match (doc.blocks[2].kind) {
            case MarkdownBlockKind.List =>
                @Expect(doc.blocks[2].children[0].text, "item continuation")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func parsesFencedCodeBlockInsideListItem(): Unit {
        let doc = parseMarkdown("1. 第一项\n\n   ```go\n   func main() {\n       fmt.Println(\"Hello\")\n   }\n   ```\n\n2. 第二项")
        match (doc.blocks[0].kind) {
            case MarkdownBlockKind.List =>
                @Expect(doc.blocks[0].children.size, 2)
                let first = doc.blocks[0].children[0]
                @Expect(first.text, "第一项")
                @Expect(first.children.size, 1)
                match (first.children[0].kind) {
                    case MarkdownBlockKind.CodeBlock(language) =>
                        @Expect(language, "go")
                        @Expect(first.children[0].text.contains("func main()"))
                        @Expect(first.children[0].text.contains("    fmt.Println"))
                    case _ => @Expect(false)
                }
                @Expect(doc.blocks[0].children[1].text, "第二项")
            case _ => @Expect(false)
        }
    }
}
