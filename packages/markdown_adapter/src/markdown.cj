package markdown_adapter

import markdown.core.{DiagnosticSeverity, ListKind, Markdown, MarkdownProfile, NodeKind, NodeRef, ParseResult, SourceSpan, TableAlignment, TaskState}
import core.{Document, DocumentLine, DocumentLineKind, DocumentTheme, DocumentView, MediaKind, MediaSource, RichSpan, Style, TextDecoration, displayWidth}
import std.collection.*

public func markdownDocument(
    text: String,
    theme!: DocumentTheme = DocumentTheme(),
    preserveSoftBreaks!: Bool = false
): Document {
    markdownAstToDocument(Markdown.parse(text, profile: MarkdownProfile.gfm()), theme: theme,
        preserveSoftBreaks: preserveSoftBreaks)
}

public func markdownAstToDocument(
    result: ParseResult,
    theme!: DocumentTheme = DocumentTheme(),
    preserveSoftBreaks!: Bool = false
): Document {
    let syntax: ?SyntaxHighlightConfig = None
    convertMarkdown(result, theme, preserveSoftBreaks, false, syntax).document
}

public class MarkdownPresentation {
    public let document: Document
    public let decorations: Array<TextDecoration>

    init(document: Document, decorations: Array<TextDecoration>) {
        this.document = document
        this.decorations = decorations
    }
}

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

public class OutlineNode {
    public let level: Int64
    public let title: String
    public let sourceOffset: Int64
    public let children: Array<OutlineNode>

    public init(level: Int64, title: String, sourceOffset: Int64, children!: Array<OutlineNode> = []) {
        this.level = level
        this.title = title
        this.sourceOffset = max(0, sourceOffset)
        this.children = children
    }
}

public class MarkdownPreviewIndex {
    private let sourceOffsets: Array<Int64>

    public init(sourceOffsets: Array<Int64>) {
        this.sourceOffsets = sourceOffsets
    }

    public func renderedLineCount(): Int64 {
        sourceOffsets.size
    }

    public func sourceOffsetForRenderedLine(line: Int64): ?Int64 {
        if (line < 0 || line >= sourceOffsets.size) {
            return None
        }
        Some(sourceOffsets[line])
    }

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

public func markdownOutline(result: ParseResult): Array<OutlineNode> {
    let flat = ArrayList<OutlineNode>()
    collectOutline(result.document.root(), flat)
    nestOutline(flat.toArray())
}

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