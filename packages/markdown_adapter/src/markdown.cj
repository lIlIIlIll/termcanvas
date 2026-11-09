package markdown_adapter

import markdown.core.{DiagnosticSeverity, ListKind, Markdown, MarkdownProfile, NodeKind, NodeRef, ParseResult, SourceSpan, TableAlignment, TaskState}
import core.{Document, DocumentLine, DocumentLineKind, DocumentTheme, DocumentView, MediaKind, MediaSource, RichSpan, Style, StyleOverride, TextDecoration, Theme, displayWidth}
import std.collection.*

/** 以应用的语义主题构建文档主题；代码语法高亮的独立配色仍由语法配置决定。
 * @param theme 应用主题
 * @return 转换后的文档主题
 */
public func documentThemeFromTheme(theme: Theme): DocumentTheme {
    let emphasis = StyleOverride(italic: Some(true)).apply(theme.normal)
    let strong = StyleOverride(bold: Some(true)).apply(theme.normal)
    DocumentTheme(paragraph: theme.normal, heading: theme.heading,
        heading1: Some(theme.heading), heading2: Some(theme.heading), heading3: Some(theme.heading),
        heading4: Some(theme.heading), heading5: Some(theme.heading), heading6: Some(theme.heading),
        list: theme.normal, quoteStyle: theme.secondary, code: theme.surface,
        table: theme.normal, link: theme.accent, emphasis: emphasis, strong: strong,
        inlineCode: theme.surface, image: theme.accent, diagnostic: theme.error,
        html: theme.secondary, strikethrough: theme.secondary, tableHeader: theme.heading)
}

/** 解析 Markdown 文本并转换为文档。
 * @param text Markdown 源文本
 * @param theme 文档主题
 * @param preserveSoftBreaks 是否将软换行保留为行分隔
 * @return 转换后的文档
 */
public func markdownDocument(
    text: String,
    theme!: DocumentTheme = DocumentTheme(),
    preserveSoftBreaks!: Bool = false
): Document {
    markdownAstToDocument(Markdown.parse(text, profile: MarkdownProfile.gfmModernV1()), theme: theme,
        preserveSoftBreaks: preserveSoftBreaks)
}

/** 将已解析的 Markdown 转换为文档。
 * @param result Markdown 解析结果
 * @param theme 文档主题
 * @param preserveSoftBreaks 是否保留软换行
 * @return 转换后的文档
 */
public func markdownAstToDocument(
    result: ParseResult,
    theme!: DocumentTheme = DocumentTheme(),
    preserveSoftBreaks!: Bool = false
): Document {
    let syntax: ?SyntaxHighlightConfig = None
    convertMarkdown(result, theme, preserveSoftBreaks, false, syntax).document
}

/** 保存转换后的文档及源文本装饰。 */
public class MarkdownPresentation {
    /** 转换后的文档。 */
    public let document: Document
    /** 对应源文本的装饰，包含代码高亮信息。 */
    public let decorations: Array<TextDecoration>

    init(document: Document, decorations: Array<TextDecoration>) {
        this.document = document
        this.decorations = decorations
    }
}

/** 转换 Markdown 并收集可用于源文本编辑器的装饰。
 * @param result Markdown 解析结果
 * @param theme 文档主题
 * @param preserveSoftBreaks 是否保留软换行
 * @param syntax 可选语法高亮配置
 * @return 文档与源文本装饰
 */
public func markdownAstToPresentation(
    result: ParseResult,
    theme!: DocumentTheme = DocumentTheme(),
    preserveSoftBreaks!: Bool = false,
    syntax!: ?SyntaxHighlightConfig = None
): MarkdownPresentation {
    convertMarkdown(result, theme, preserveSoftBreaks, true, syntax)
}

func convertMarkdown(result: ParseResult, theme: DocumentTheme, preserveSoftBreaks: Bool, collect: Bool,
    syntax: ?SyntaxHighlightConfig): MarkdownPresentation {
    let source = result.source.text()
    let context = CodeHighlightContext(source, theme.code, collect, trusted: source.size == result.source.byteLength(),
        syntax: syntax)
    let lines = ArrayList<DocumentLine>()
    let blocks = result.document.children()
    var previousEnd: Int64 = 0
    for (i in 0..blocks.size) {
        let block = blocks[i]
        let start = sourceStart(block)
        if (i > 0 && start >= previousEnd) {
            let gap = result.source.slice(SourceSpan(previousEnd, start))
            if (gap.contains("\n\n")) {
                lines.add(DocumentLine(DocumentLineKind.Blank, ""))
            }
        }
        appendBlock(lines, block, theme, 0, 0, false, preserveSoftBreaks, context)
        previousEnd = sourceEnd(block)
    }
    for (diagnostic in result.diagnostics.toArray()) {
        lines.add(DocumentLine(DocumentLineKind.Diagnostic,
            [RichSpan(diagnosticMessage(diagnostic.severity) + diagnostic.message, style: theme.diagnostic,
                sourceRange: Some(rangeText(diagnostic.span.startByte, diagnostic.span.endByte)))]))
    }
    MarkdownPresentation(Document(lines.toArray()), context.decorations())
}

/** Markdown 标题大纲节点。 */
public class OutlineNode {
    /** 标题级别。 */
    public let level: Int64
    /** 标题的纯文本内容。 */
    public let title: String
    /** 标题在源文本中的字节偏移。 */
    public let sourceOffset: Int64
    /** 下级标题节点。 */
    public let children: Array<OutlineNode>

    /** 创建大纲节点。
     * @param level 标题级别
     * @param title 标题文本
     * @param sourceOffset 源字节偏移，负值按零处理
     * @param children 下级标题
     */
    public init(level: Int64, title: String, sourceOffset: Int64, children!: Array<OutlineNode> = []) {
        this.level = level
        this.title = title
        this.sourceOffset = max(0, sourceOffset)
        this.children = children
    }
}

/** 保存渲染行与源字节偏移之间的映射。 */
public class MarkdownPreviewIndex {
    private let sourceOffsets: Array<Int64>

    /** 根据各渲染行的源偏移创建索引。
     * @param sourceOffsets 各渲染行的源字节偏移
     */
    public init(sourceOffsets: Array<Int64>) {
        this.sourceOffsets = sourceOffsets
    }

    /** 获取已索引的渲染行数。
     * @return 渲染行数
     */
    public func renderedLineCount(): Int64 {
        sourceOffsets.size
    }

    /** 查询渲染行对应的源偏移。
     * @param line 渲染行索引
     * @return 源字节偏移；索引无效时为 None
     */
    public func sourceOffsetForRenderedLine(line: Int64): ?Int64 {
        if (line < 0 || line >= sourceOffsets.size) {
            return None
        }
        Some(sourceOffsets[line])
    }

    /** 查找源偏移之前最后一个匹配的渲染行。
     * @param offset 源字节偏移
     * @return 最后一个偏移不大于输入值的行索引；无匹配时为零
     */
    public func renderedLineForSourceOffset(offset: Int64): Int64 {
        var best: Int64 = 0
        for (i in 0..sourceOffsets.size) {
            if (sourceOffsets[i] <= offset) {
                best = i
            }
        }
        best
    }
}

/** 从解析结果提取嵌套标题大纲。
 * @param result Markdown 解析结果
 * @return 大纲根节点
 */
public func markdownOutline(result: ParseResult): Array<OutlineNode> {
    let flat = ArrayList<OutlineNode>()
    collectOutline(result.document.root(), flat)
    nestOutline(flat.toArray())
}

/** 为指定宽度的文档生成预览行索引。
 * @param document 转换后的文档
 * @param width 预览宽度
 * @return 行与源偏移的索引
 */
public func markdownPreviewIndex(document: Document, width: Int64): MarkdownPreviewIndex {
    MarkdownPreviewIndex(DocumentView(document).sourceOffsetsForRenderedLines(width))
}

func collectOutline(node: NodeRef, out: ArrayList<OutlineNode>): Unit {
    if (let Some(heading) <- node.asHeading()) {
        out.add(OutlineNode(heading.level, plainText(node), sourceStart(node)))
    }
    let children = node.children()
    for (i in 0..children.size) {
        collectOutline(children[i], out)
    }
}

func nestOutline(flat: Array<OutlineNode>): Array<OutlineNode> {
    if (flat.size == 0) {
        return []
    }
    let out = ArrayList<OutlineNode>()
    var start: Int64 = 0
    while (start < flat.size) {
        let (nodes, next) = nestOutlineAt(flat, start, flat[start].level)
        for (node in nodes) { out.add(node) }
        start = next
    }
    out.toArray()
}

func nestOutlineAt(flat: Array<OutlineNode>, start: Int64, level: Int64): (Array<OutlineNode>, Int64) {
    let out = ArrayList<OutlineNode>()
    var i = start
    while (i < flat.size) {
        if (flat[i].level < level) {
            break
        } else if (flat[i].level > level) {
            if (out.size == 0) {
                out.add(flat[i])
                i++
            } else {
                let (children, next) = nestOutlineAt(flat, i, flat[i].level)
                let last = out[out.size - 1]
                out[out.size - 1] = OutlineNode(last.level, last.title, last.sourceOffset,
                    children: mergeOutline(last.children, children))
                i = next
            }
        } else {
            out.add(flat[i])
            i++
        }
    }
    (out.toArray(), i)
}

func mergeOutline(first: Array<OutlineNode>, second: Array<OutlineNode>): Array<OutlineNode> {
    let out = ArrayList<OutlineNode>()
    for (node in first) { out.add(node) }
    for (node in second) { out.add(node) }
    out.toArray()
}

func sourceStart(node: NodeRef): Int64 {
    match (node.span) {
        case Some(span) => span.startByte
        case None => 0
    }
}

func sourceEnd(node: NodeRef): Int64 {
    match (node.span) {
        case Some(span) => span.endByte
        case None => 0
    }
}

func rangeText(start: Int64, end: Int64): String {
    "${start}:${end}"
}

func rangeOption(node: NodeRef): ?String {
    match (node.span) {
        case Some(span) => Some(rangeText(span.startByte, span.endByte))
        case None => None
    }
}

func appendBlock(lines: ArrayList<DocumentLine>, node: NodeRef, theme: DocumentTheme,
    quoteDepth: Int64, listDepth: Int64, ordered: Bool, preserveSoftBreaks: Bool, context: CodeHighlightContext): Unit {
    let children = node.children()
    match (node.kind) {
        case NodeKind.Heading =>
            let heading = node.asHeading().getOrThrow()
            lines.add(DocumentLine(DocumentLineKind.Heading(heading.level),
                inlineSpans(node, theme, theme.headingStyle(heading.level)), quoteDepth: quoteDepth))
        case NodeKind.Paragraph =>
            if (children.size == 1 && isImage(children[0])) {
                let image = children[0].asImage().getOrThrow()
                lines.add(DocumentLine(DocumentLineKind.Image,
                    inlineSpans(node, theme, theme.image), quoteDepth: quoteDepth,
                    media: Some(MediaSource("markdown:${image.destination}", image.destination,
                        kind: MediaKind.Image, alt: plainText(children[0]))), mediaHeight: 6))
            } else {
                appendParagraph(lines, node, theme, quoteDepth, preserveSoftBreaks)
            }
        case NodeKind.BlockQuote =>
            for (i in 0..children.size) {
                appendBlock(lines, children[i], theme, quoteDepth + 1, listDepth, ordered, preserveSoftBreaks, context)
            }
        case NodeKind.List =>
            let isOrdered = if (let ListKind.Ordered <- node.asList().getOrThrow().listKind) { true } else { false }
            for (i in 0..children.size) {
                appendBlock(lines, children[i], theme, quoteDepth, listDepth, isOrdered, preserveSoftBreaks, context)
            }
        case NodeKind.ListItem =>
            let task = node.asListItem().getOrThrow().taskState
            let kind = match (task) {
                case TaskState.Checked => DocumentLineKind.TaskListItem(true)
                case TaskState.Unchecked => DocumentLineKind.TaskListItem(false)
                case TaskState.NotTask => DocumentLineKind.ListItem(ordered)
            }
            if (children.size > 0 && isParagraph(children[0])) {
                lines.add(DocumentLine(kind, indentedSpans(listDepth,
                    inlineSpans(children[0], theme, theme.list), theme.list), quoteDepth: quoteDepth))
            } else {
                lines.add(DocumentLine(kind, "", quoteDepth: quoteDepth))
            }
            for (i in 0..children.size) {
                if (i > 0 || !isParagraph(children[i])) {
                    appendBlock(lines, children[i], theme, quoteDepth, listDepth + 1, ordered, preserveSoftBreaks, context)
                }
            }
        case NodeKind.CodeBlock =>
            let code = node.asCodeBlock().getOrThrow()
            for (spans in context.codeLines(node, code, theme.code)) {
                lines.add(DocumentLine(DocumentLineKind.CodeBlock, spans, quoteDepth: quoteDepth))
            }
        case NodeKind.Table => appendTable(lines, node, theme, quoteDepth)
        case NodeKind.ThematicBreak => lines.add(DocumentLine(DocumentLineKind.HorizontalRule, "",
            style: theme.table, quoteDepth: quoteDepth))
        case NodeKind.HtmlBlock => lines.add(DocumentLine(DocumentLineKind.Html,
            node.asHtmlBlock().getOrThrow().literal, style: theme.html, quoteDepth: quoteDepth))
        case _ => for (i in 0..children.size) {
            appendBlock(lines, children[i], theme, quoteDepth, listDepth, ordered, preserveSoftBreaks, context)
        }
    }
}

func appendParagraph(lines: ArrayList<DocumentLine>, node: NodeRef, theme: DocumentTheme,
    quoteDepth: Int64, preserveSoftBreaks: Bool): Unit {
    let spans = ArrayList<RichSpan>()
    let children = node.children()
    for (i in 0..children.size) {
        let child = children[i]
        if (isHardBreak(child) || (preserveSoftBreaks && isSoftBreak(child))) {
            lines.add(DocumentLine(DocumentLineKind.Paragraph, spans.toArray(), quoteDepth: quoteDepth))
            spans.clear()
        } else {
            appendInline(spans, child, theme, theme.paragraph, Option<String>.None)
        }
    }
    lines.add(DocumentLine(DocumentLineKind.Paragraph, spans.toArray(), quoteDepth: quoteDepth))
}

func inlineSpans(node: NodeRef, theme: DocumentTheme, style: Style): Array<RichSpan> {
    let out = ArrayList<RichSpan>()
    let children = node.children()
    for (i in 0..children.size) {
        appendInline(out, children[i], theme, style, Option<String>.None)
    }
    out.toArray()
}

func appendInline(out: ArrayList<RichSpan>, node: NodeRef, theme: DocumentTheme,
    style: Style, link: ?String): Unit {
    let source = rangeOption(node)
    match (node.kind) {
        case NodeKind.Text => out.add(RichSpan(node.asText().getOrThrow().value, style: style,
            linkUrl: link, sourceRange: source))
        case NodeKind.CodeSpan => out.add(RichSpan(node.asCodeSpan().getOrThrow().literal,
            style: theme.inlineCode, linkUrl: link, sourceRange: source))
        case NodeKind.HtmlInline => out.add(RichSpan(node.asHtmlInline().getOrThrow().literal,
            style: theme.html, linkUrl: link, sourceRange: source))
        case NodeKind.SoftBreak | NodeKind.HardBreak => out.add(RichSpan(" ", style: style, sourceRange: source))
        case NodeKind.Image =>
            let url = node.asImage().getOrThrow().destination
            let alt = plainText(node)
            out.add(RichSpan(if (alt.isEmpty()) { url } else { alt + " " + url },
                style: theme.image, linkUrl: Some(url), sourceRange: source))
        case _ =>
            let nextStyle = match (node.kind) {
                case NodeKind.Emphasis => mergeInlineStyles(style, theme.emphasis)
                case NodeKind.Strong => mergeInlineStyles(style, theme.strong)
                case NodeKind.Strikethrough => mergeInlineStyles(style, theme.strikethrough)
                case NodeKind.Link => mergeInlineStyles(style, theme.link)
                case _ => style
            }
            let nextLink = if (isLink(node)) {
                Some(node.asLink().getOrThrow().destination)
            } else { link }
            let children = node.children()
            for (i in 0..children.size) {
                appendInline(out, children[i], theme, nextStyle, nextLink)
            }
    }
}

func plainText(node: NodeRef): String {
    match (node.kind) {
        case NodeKind.Text => return node.asText().getOrThrow().value
        case NodeKind.CodeSpan => return node.asCodeSpan().getOrThrow().literal
        case NodeKind.SoftBreak | NodeKind.HardBreak => return " "
        case _ => ()
    }
    var text = ""
    let children = node.children()
    for (i in 0..children.size) { text += plainText(children[i]) }
    text
}

func mergeInlineStyles(outer: Style, inner: Style): Style {
    var merged = outer.patch(inner)
    var modifier = merged.modifier
    modifier.bold = outer.modifier.bold || inner.modifier.bold
    modifier.italic = outer.modifier.italic || inner.modifier.italic
    modifier.underline = outer.modifier.underline || inner.modifier.underline
    modifier.reversed = outer.modifier.reversed || inner.modifier.reversed
    merged.modifier = modifier
    merged
}

func appendTable(lines: ArrayList<DocumentLine>, table: NodeRef, theme: DocumentTheme, quoteDepth: Int64): Unit {
    let rows = table.children()
    if (rows.size == 0) { return }
    let widths = ArrayList<Int64>()
    for (i in 0..rows.size) {
        let cells = rows[i].children()
        for (j in 0..cells.size) {
            let width = displayWidth(plainText(cells[j]))
            if (j >= widths.size) { widths.add(width) } else { widths[j] = max(widths[j], width) }
        }
    }
    let aligns = table.asTable().getOrThrow().alignments
    for (i in 0..rows.size) {
        let cells = rows[i].children()
        let texts = ArrayList<String>()
        for (j in 0..cells.size) {
            let align = if (j < aligns.size) { aligns[j] } else { TableAlignment.None }
            texts.add(alignText(plainText(cells[j]), widths[j], align))
        }
        let header = rows[i].asTableRow().getOrThrow().header
        lines.add(DocumentLine(if (header) { DocumentLineKind.TableHeader } else { DocumentLineKind.TableRow },
            joinDocument(texts.toArray(), " | "), style: if (header) { theme.tableHeader } else { theme.table },
            quoteDepth: quoteDepth))
    }
}

func alignText(text: String, width: Int64, align: TableAlignment): String {
    let extra = max(0, width - displayWidth(text))
    match (align) {
        case TableAlignment.Right => repeatSpaces(extra) + text
        case TableAlignment.Center =>
            let left = extra / 2
            repeatSpaces(left) + text + repeatSpaces(extra - left)
        case _ => text + repeatSpaces(extra)
    }
}

func indentedSpans(level: Int64, spans: Array<RichSpan>, style: Style): Array<RichSpan> {
    if (level <= 0) { return spans }
    let out = ArrayList<RichSpan>()
    out.add(RichSpan(repeatSpaces(level * 2), style: style))
    for (span in spans) { out.add(span) }
    out.toArray()
}

func diagnosticMessage(severity: DiagnosticSeverity): String {
    match (severity) {
        case DiagnosticSeverity.Info => "info: "
        case DiagnosticSeverity.Warning => "warning: "
        case DiagnosticSeverity.Error => "error: "
    }
}

func splitDocumentLines(text: String): Array<String> {
    let lines = ArrayList<String>()
    if (text.isEmpty()) { return [""] }
    var start: Int64 = 0
    for (i in 0..text.size) {
        if (text[i] == b'\n') {
            lines.add(text[start..i])
            start = i + 1
        }
    }
    if (start < text.size) { lines.add(text[start..]) }
    lines.toArray()
}

func repeatSpaces(count: Int64): String {
    var out = ""
    for (_ in 0..count) { out += " " }
    out
}

func joinDocument(parts: Array<String>, sep: String): String {
    var out = ""
    for (i in 0..parts.size) {
        if (i > 0) { out += sep }
        out += parts[i]
    }
    out
}


func isImage(node: NodeRef): Bool { if (let NodeKind.Image <- node.kind) { true } else { false } }
func isParagraph(node: NodeRef): Bool { if (let NodeKind.Paragraph <- node.kind) { true } else { false } }
func isHardBreak(node: NodeRef): Bool { if (let NodeKind.HardBreak <- node.kind) { true } else { false } }
func isSoftBreak(node: NodeRef): Bool { if (let NodeKind.SoftBreak <- node.kind) { true } else { false } }
func isLink(node: NodeRef): Bool { if (let NodeKind.Link <- node.kind) { true } else { false } }
