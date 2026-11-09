package core

import std.collection.*

/** 带样式、可选链接和源位置的文本片段。 */
public class RichSpan {
    /** 片段文本。 */
    public let text: String
    /** 文本样式。 */
    public let style: Style
    /** 可选的链接地址。 */
    public let linkUrl: ?String
    /** 可选的源字节范围字符串，格式为起点:终点。 */
    public let sourceRange: ?String

    /** 创建文本片段。
     * @param text 片段文本
     * @param style 文本样式
     * @param linkUrl 可选链接地址
     * @param sourceRange 可选的源字节范围
     */
    public init(text: String, style!: Style = Style.default(), linkUrl!: ?String = None, sourceRange!: ?String = None) {
        this.text = text
        this.style = style
        this.linkUrl = linkUrl
        this.sourceRange = sourceRange
    }
}

/** 文档行的语义类型。 */
public enum DocumentLineKind {
    /** 段落。 */
    | Paragraph
    /** 标题
     * @param _0 标题级别
     */
    | Heading(Int64)
    /** 列表项
     * @param _0 是否为有序列表
     */
    | ListItem(Bool)
    /** 引用。 */
    | Quote
    /** 代码块。 */
    | CodeBlock
    /** 表格行。 */
    | TableRow
    /** 表头。 */
    | TableHeader
    /** 分隔线。 */
    | HorizontalRule
    /** 任务列表项
     * @param _0 是否已完成
     */
    | TaskListItem(Bool)
    /** 图片。 */
    | Image
    /** 诊断信息。 */
    | Diagnostic
    /** HTML 内容。 */
    | Html
    /** 删除线内容。 */
    | Strikethrough
    /** 代码围栏信息
     * @param _0 语言或围栏信息
     */
    | CodeFenceInfo(String)
    /** 空行。 */
    | Blank
}

/** 包含语义类型、文本片段和可选媒体的文档行。 */
public class DocumentLine {
    /** 文档行类型。 */
    public let kind: DocumentLineKind
    /** 文本片段。 */
    public let spans: Array<RichSpan>
    /** 引用嵌套深度，至少为零。 */
    public let quoteDepth: Int64
    /** 可选媒体来源。 */
    public let media: ?MediaSource
    /** 媒体适配方式。 */
    public let mediaFit: MediaFit
    /** 媒体高度，至少为一行。 */
    public let mediaHeight: Int64

    /** 根据文本片段创建文档行。
     * @param kind 行类型
     * @param spans 文本片段
     * @param quoteDepth 引用深度，负值按零处理
     * @param media 可选媒体来源
     * @param mediaFit 媒体适配方式
     * @param mediaHeight 媒体高度，至少为一
     */
    public init(
        kind: DocumentLineKind,
        spans: Array<RichSpan>,
        quoteDepth!: Int64 = 0,
        media!: ?MediaSource = None,
        mediaFit!: MediaFit = MediaFit.Contain,
        mediaHeight!: Int64 = 6
    ) {
        this.kind = kind
        this.spans = spans
        this.quoteDepth = max(0, quoteDepth)
        this.media = media
        this.mediaFit = mediaFit
        this.mediaHeight = max(1, mediaHeight)
    }

    /** 根据纯文本创建文档行。
     * @param kind 行类型
     * @param text 文本
     * @param style 文本样式
     * @param quoteDepth 引用深度，负值按零处理
     * @param media 可选媒体来源
     * @param mediaFit 媒体适配方式
     * @param mediaHeight 媒体高度，至少为一
     */
    public init(
        kind: DocumentLineKind,
        text: String,
        style!: Style = Style.default(),
        quoteDepth!: Int64 = 0,
        media!: ?MediaSource = None,
        mediaFit!: MediaFit = MediaFit.Contain,
        mediaHeight!: Int64 = 6
    ) {
        this.kind = kind
        this.spans = [RichSpan(text, style: style)]
        this.quoteDepth = max(0, quoteDepth)
        this.media = media
        this.mediaFit = mediaFit
        this.mediaHeight = max(1, mediaHeight)
    }

    /** 创建图片文档行；空替代文本使用媒体回退文本。
     * @param source 媒体来源
     * @param alt 替代文本
     * @param style 文本样式
     * @param mediaHeight 媒体高度
     * @return 图片文档行
     */
    public static func image(source: MediaSource, alt!: String = "", style!: Style = Style(fg: Color.Cyan), mediaHeight!: Int64 = 6): DocumentLine {
        let label = if (alt.isEmpty()) { mediaFallbackText(source) } else { alt }
        DocumentLine(DocumentLineKind.Image, [RichSpan(label, style: style, linkUrl: Some(source.uri))], media: Some(source), mediaHeight: mediaHeight)
    }
}

/** 由文档行组成的可渲染文档。 */
public class Document {
    /** 按顺序排列的文档行。 */
    public let lines: Array<DocumentLine>

    /** 创建文档。
     * @param lines 文档行
     */
    public init(lines: Array<DocumentLine>) {
        this.lines = lines
    }

    /** 将纯文本按行转换为段落文档。
     * @param text 纯文本
     * @param style 文本样式
     * @return 段落文档
     */
    public static func plain(text: String, style!: Style = Style.default()): Document {
        let lines = ArrayList<DocumentLine>()
        for (line in splitLines(text)) {
            lines.add(DocumentLine(DocumentLineKind.Paragraph, line, style: style))
        }
        Document(lines.toArray())
    }
}

/** 文档各语义元素使用的样式集合。 */
public struct DocumentTheme {
    /** 段落样式。 */
    public let paragraph: Style
    /** 通用标题样式。 */
    public let heading: Style
    /** 一级标题样式。 */
    public let heading1: Style
    /** 二级标题样式。 */
    public let heading2: Style
    /** 三级标题样式。 */
    public let heading3: Style
    /** 四级标题样式。 */
    public let heading4: Style
    /** 五级标题样式。 */
    public let heading5: Style
    /** 六级标题样式。 */
    public let heading6: Style
    /** 列表样式。 */
    public let list: Style
    /** 引用样式。 */
    public let quoteStyle: Style
    /** 代码块样式。 */
    public let code: Style
    /** 表格样式。 */
    public let table: Style
    /** 链接样式。 */
    public let link: Style
    /** 强调样式。 */
    public let emphasis: Style
    /** 加重样式。 */
    public let strong: Style
    /** 行内代码样式。 */
    public let inlineCode: Style
    /** 图片文本样式。 */
    public let image: Style
    /** 诊断信息样式。 */
    public let diagnostic: Style
    /** HTML 样式。 */
    public let html: Style
    /** 删除线内容样式。 */
    public let strikethrough: Style
    /** 表头样式。 */
    public let tableHeader: Style

    /** 创建文档主题。一级标题缺省使用 heading；二至六级各有独立默认样式。
     * @param paragraph 段落样式
     * @param heading 通用标题样式
     * @param heading1 一级标题样式
     * @param heading2 二级标题样式
     * @param heading3 三级标题样式
     * @param heading4 四级标题样式
     * @param heading5 五级标题样式
     * @param heading6 六级标题样式
     * @param list 列表样式
     * @param quoteStyle 引用样式
     * @param code 代码块样式
     * @param table 表格样式
     * @param link 链接样式
     * @param emphasis 强调样式
     * @param strong 加重样式
     * @param inlineCode 行内代码样式
     * @param image 图片文本样式
     * @param diagnostic 诊断信息样式
     * @param html HTML 样式
     * @param strikethrough 删除线内容样式
     * @param tableHeader 表头样式
     */
    public init(
        paragraph!: Style = Style.default(),
        heading!: Style = Style(fg: Color.Yellow, modifier: Modifier.strong()),
        heading1!: ?Style = None,
        heading2!: ?Style = None,
        heading3!: ?Style = None,
        heading4!: ?Style = None,
        heading5!: ?Style = None,
        heading6!: ?Style = None,
        list!: Style = Style(fg: Color.Cyan),
        quoteStyle!: Style = Style(fg: Color.Green),
        code!: Style = Style(fg: Color.Magenta),
        table!: Style = Style(fg: Color.Cyan),
        link!: Style = Style(fg: Color.Blue),
        emphasis!: Style = Style(fg: Color.White, modifier: italicModifier()),
        strong!: Style = Style(fg: Color.White, modifier: Modifier.strong()),
        inlineCode!: Style = Style(fg: Color.Magenta),
        image!: Style = Style(fg: Color.Cyan),
        diagnostic!: Style = Style(fg: Color.Red),
        html!: Style = Style(fg: Color.Indexed(8)),
        strikethrough!: Style = Style(fg: Color.Indexed(8)),
        tableHeader!: Style = Style(fg: Color.Yellow, modifier: Modifier.strong())
    ) {
        this.paragraph = paragraph
        this.heading = heading
        this.heading1 = match (heading1) {
            case Some(style) => style
            case None => heading
        }
        this.heading2 = match (heading2) {
            case Some(style) => style
            case None => Style(fg: Color.Cyan, modifier: Modifier.strong())
        }
        this.heading3 = match (heading3) {
            case Some(style) => style
            case None => Style(fg: Color.White, modifier: Modifier.strong())
        }
        this.heading4 = match (heading4) {
            case Some(style) => style
            case None => Style(fg: Color.Magenta, modifier: Modifier.strong())
        }
        this.heading5 = match (heading5) {
            case Some(style) => style
            case None => Style(fg: Color.White, modifier: italicModifier())
        }
        this.heading6 = match (heading6) {
            case Some(style) => style
            case None => Style(fg: Color.Indexed(8), modifier: italicModifier())
        }
        this.list = list
        this.quoteStyle = quoteStyle
        this.code = code
        this.table = table
        this.link = link
        this.emphasis = emphasis
        this.strong = strong
        this.inlineCode = inlineCode
        this.image = image
        this.diagnostic = diagnostic
        this.html = html
        this.strikethrough = strikethrough
        this.tableHeader = tableHeader
    }

    /** 获取指定标题级别的样式。
     * @param level 标题级别
     * @return 一级至六级对应的样式，其他级别返回通用标题样式
     */
    public func headingStyle(level: Int64): Style {
        match (level) {
            case 1 => heading1
            case 2 => heading2
            case 3 => heading3
            case 4 => heading4
            case 5 => heading5
            case 6 => heading6
            case _ => heading
        }
    }
}

/** 文档主题的 Markdown 兼容别名。 */
public type MarkdownTheme = DocumentTheme
/** 文档模型的 Markdown 兼容别名。 */
public type MarkdownDocument = Document

/** 文档中按查询文本应用的高亮。 */
public class DocumentHighlight {
    /** 要高亮的文本。 */
    public let query: String
    /** 高亮样式。 */
    public let style: Style

    /** 创建高亮规则。
     * @param query 要匹配的文本
     * @param style 高亮样式
     */
    public init(query: String, style!: Style = Style(bg: Color.Yellow)) {
        this.query = query
        this.style = style
    }
}

/** 以源偏移定义的闭区间折叠范围。 */
public class DocumentFoldRange {
    /** 起始偏移，至少为零。 */
    public let startOffset: Int64
    /** 结束偏移，不小于起点。 */
    public let endOffset: Int64

    /** 创建折叠范围。
     * @param startOffset 起始偏移，负值按零处理
     * @param endOffset 结束偏移，小于起点时按起点处理
     */
    public init(startOffset: Int64, endOffset: Int64) {
        this.startOffset = max(0, startOffset)
        this.endOffset = max(this.startOffset, endOffset)
    }

    /** 判断偏移是否位于闭区间内。
     * @param offset 要查询的偏移
     * @return 位于范围内时为 true
     */
    public func contains(offset: Int64): Bool {
        startOffset <= offset && offset <= endOffset
    }
}

/** 保存文档视图的滚动、光标、链接、搜索和折叠状态。 */
public class DocumentViewState {
    /** 渲染行滚动偏移。 */
    public var scroll: Int64
    /** 可选的源文本光标偏移。 */
    public var cursorSourceOffset: ?Int64
    /** 当前链接索引。 */
    public var selectedLinkIndex: Int64
    /** 当前搜索匹配索引。 */
    public var searchMatchIndex: Int64
    private let foldedRanges = ArrayList<DocumentFoldRange>()
    private var foldVersion: Int64 = 0

    /** 创建视图状态；数字索引的负值限制为零。
     * @param scroll 初始滚动行数
     * @param cursorSourceOffset 可选源文本光标偏移
     * @param selectedLinkIndex 初始链接索引
     * @param searchMatchIndex 初始搜索匹配索引
     */
    public init(scroll!: Int64 = 0, cursorSourceOffset!: ?Int64 = None, selectedLinkIndex!: Int64 = 0, searchMatchIndex!: Int64 = 0) {
        this.scroll = max(0, scroll)
        this.cursorSourceOffset = cursorSourceOffset
        this.selectedLinkIndex = max(0, selectedLinkIndex)
        this.searchMatchIndex = max(0, searchMatchIndex)
    }

    /** 获取折叠范围快照。
     * @return 已折叠范围
     */
    public func folds(): Array<DocumentFoldRange> {
        foldedRanges.toArray()
    }

    /** 清除所有折叠范围。 */
    public func clearFolds(): Unit {
        if (foldedRanges.size == 0) { return }
        while (foldedRanges.size > 0) { foldedRanges.remove(at: 0) }
        foldVersion++
    }

    func foldRevision(): Int64 {
        foldVersion
    }

    /** 以原样提供的起止偏移精确匹配折叠范围。
     * @param startOffset 起始偏移
     * @param endOffset 结束偏移
     * @return 存在精确匹配时为 true
     */
    public func isFolded(startOffset: Int64, endOffset: Int64): Bool {
        for (range in foldedRanges) {
            if (range.startOffset == startOffset && range.endOffset == endOffset) { return true }
        }
        false
    }

    /** 设置折叠状态；起点限制为非负，终点限制为不小于起点。
     * @param startOffset 起始偏移
     * @param endOffset 结束偏移
     * @param folded 是否折叠
     */
    public func setFolded(startOffset: Int64, endOffset: Int64, folded: Bool): Unit {
        let start = max(0, startOffset)
        let end = max(start, endOffset)
        for (i in 0..foldedRanges.size) {
            let range = foldedRanges[i]
            if (range.startOffset == start && range.endOffset == end) {
                if (!folded) {
                    foldedRanges.remove(at: i)
                    foldVersion++
                }
                return
            }
        }
        if (folded) {
            foldedRanges.add(DocumentFoldRange(start, end))
            foldVersion++
        }
    }

    /** 切换给定范围的折叠状态；请传入非负且终点不小于起点的偏移。
     * @param startOffset 起始偏移
     * @param endOffset 结束偏移
     * @return 请求设置的新折叠状态
     */
    public func toggleFold(startOffset: Int64, endOffset: Int64): Bool {
        let folded = !isFolded(startOffset, endOffset)
        setFolded(startOffset, endOffset, folded)
        folded
    }
}

public class DocumentView <: Widget {
    private let document: Document
    private let block: ?Block
    private var theme: DocumentTheme
    private let explicitTheme: ?DocumentTheme
    private let baseStyle: ?Style
    private let headingStyle: ?Style
    private var contextTheme: ?Theme = None
    private let scroll: Int64
    private let wrap: WrapMode
    private let highlights: Array<DocumentHighlight>
    private let state: ?DocumentViewState
    private let currentSourceOverride: ?Style
    private var currentSourceStyle: Style
    private let cacheLayout: Bool
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private var cachedWidth: Int64 = -1
    private var cachedRows: Array<StyledLine> = []
    private var cachedFoldRevision: Int64 = -1
    private var cachedCursorSource: ?Int64 = None

    public init(
        document: Document,
        block!: ?Block = None,
        style!: ?Style = None,
        headingStyle!: ?Style = None,
        theme!: ?DocumentTheme = None,
        scroll!: Int64 = 0,
        wrap!: WrapMode = WrapMode.Word,
        highlights!: Array<DocumentHighlight> = [],
        state!: ?DocumentViewState = None,
        currentSourceStyle!: ?Style = None,
        cacheLayout!: Bool = false
    ) {
        this.document = document
        this.block = block
        this.explicitTheme = theme
        this.baseStyle = style
        this.headingStyle = headingStyle
        this.theme = match (theme) {
            case Some(t) => t
            case None => DocumentTheme(
                paragraph: match (style) { case Some(value) => value; case None => Style.default() },
                heading: match (headingStyle) { case Some(value) => value; case None => Style(fg: Color.Yellow, modifier: Modifier.strong()) })
        }
        this.scroll = max(0, scroll)
        this.wrap = wrap
        this.highlights = highlights
        this.state = state
        this.currentSourceOverride = currentSourceStyle
        this.currentSourceStyle = match (currentSourceStyle) { case Some(value) => value; case None => Style(bg: Color.Indexed(8)) }
        this.cacheLayout = cacheLayout
    }

    /** 指定后续排版采用的宽度策略；变更时使缓存失效。 */
    public func setTextWidthOptions(options: TextWidthOptions): Unit {
        if (usesWideAmbiguous(options) != usesWideAmbiguous(textWidthOptionsValue)) { cachedWidth = -1 }
        textWidthOptionsValue = options
    }

    public func renderedLineCount(width: Int64): Int64 {
        renderRows(document, width).size
    }

    public func sourceOffsetForRenderedLine(width: Int64, renderedLine: Int64): ?Int64 {
        let rows = renderRows(document, width)
        if (renderedLine < 0 || renderedLine >= rows.size) { return None }
        for (span in rows[renderedLine].spans) {
            match (span.sourceRange) {
                case Some(value) => return parseSourceOffset(value)
                case None => ()
            }
        }
        None
    }

    public func sourceOffsetAtRenderedLine(width: Int64, renderedLine: Int64): ?Int64 {
        sourceOffsetForRenderedLine(width, renderedLine)
    }

    public func sourceOffsetsForRenderedLines(width: Int64): Array<Int64> {
        let rows = renderRows(document, width)
        let offsets = ArrayList<Int64>()
        var last: Int64 = 0
        for (row in rows) {
            match (sourceOffsetFromRow(row)) {
                case Some(offset) =>
                    last = offset
                    offsets.add(offset)
                case None => offsets.add(last)
            }
        }
        offsets.toArray()
    }

    public func renderedLineForSourceOffset(width: Int64, sourceOffset: Int64): Int64 {
        let rows = renderRows(document, width)
        var fallback: Int64 = 0
        for (i in 0..rows.size) {
            for (span in rows[i].spans) {
                match (span.sourceRange) {
                    case Some(value) =>
                        let start = parseSourceOffset(value)
                        let end = parseSourceEndOffset(value)
                        match ((start, end)) {
                            case (Some(s), Some(e)) =>
                                if (s <= sourceOffset) { fallback = i }
                                if (s <= sourceOffset && sourceOffset <= e) { return i }
                            case _ => ()
                        }
                    case None => ()
                }
            }
        }
        fallback
    }

    public func linkAtRenderedLine(width: Int64, renderedLine: Int64): ?String {
        let rows = renderRows(document, width)
        if (renderedLine < 0 || renderedLine >= rows.size) { return None }
        for (span in rows[renderedLine].spans) {
            match (span.linkUrl) {
                case Some(url) => return Some(url)
                case None => ()
            }
        }
        None
    }

    public func handleKey(key: KeyEvent, width: Int64, viewportHeight: Int64): Bool {
        match (state) {
            case Some(s) =>
                let total = max(0, renderedLineCount(width))
                match (key.code) {
                    case KeyCode.Down =>
                        s.scroll = min(max(0, total - viewportHeight), s.scroll + 1)
                        true
                    case KeyCode.Up =>
                        s.scroll = max(0, s.scroll - 1)
                        true
                    case KeyCode.PageDown =>
                        s.scroll = min(max(0, total - viewportHeight), s.scroll + max(1, viewportHeight))
                        true
                    case KeyCode.PageUp =>
                        s.scroll = max(0, s.scroll - max(1, viewportHeight))
                        true
                    case KeyCode.Enter =>
                        match (sourceOffsetForRenderedLine(width, s.scroll)) {
                            case Some(offset) => s.cursorSourceOffset = Some(offset)
                            case None => ()
                        }
                        true
                    case _ => false
                }
            case None => false
        }
    }

    public func handleMouse(mouse: MouseEvent, area: Rect): ?Int64 {
        let target = match (block) {
            case Some(b) => b.inner(area)
            case None => area
        }
        if (mouse.x < target.x || mouse.x >= target.right ||
            mouse.y < target.y || mouse.y >= target.bottom) { return None }
        let row = mouse.y - target.y + currentScroll()
        sourceOffsetForRenderedLine(target.width, row)
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        let applicationTheme = buffer.resolveTheme(Option<Theme>.None)
        let sourceHighlight = match (currentSourceOverride) {
            case Some(value) => value
            case None => widgetRoleStyle(Option<Style>.None, applicationTheme, ThemeRole.Selected, Style(bg: Color.Indexed(8)))
        }
        if (currentSourceStyle != sourceHighlight) {
            currentSourceStyle = sourceHighlight
            cachedWidth = -1
        }
        if (explicitTheme.isNone()) {
            if (!documentContextThemeEqual(contextTheme, applicationTheme)) {
                contextTheme = applicationTheme
                theme = match (applicationTheme) {
                    case Some(value) =>
                        let heading = match (headingStyle) { case Some(style) => value.heading.patch(style); case None => value.heading }
                        DocumentTheme(
                        paragraph: widgetRoleStyle(baseStyle, applicationTheme, ThemeRole.Normal, Style.default()),
                        heading: heading,
                        heading1: Some(heading), heading2: Some(heading), heading3: Some(heading),
                        heading4: Some(heading), heading5: Some(heading), heading6: Some(heading),
                        list: value.accent, quoteStyle: value.secondary, code: value.accent, table: value.normal,
                        link: value.info, emphasis: value.normal, strong: value.heading, inlineCode: value.accent,
                        image: value.accent, diagnostic: value.error, html: value.secondary,
                        strikethrough: value.secondary, tableHeader: value.heading)
                    case None => DocumentTheme(
                        paragraph: match (baseStyle) { case Some(style) => style; case None => Style.default() },
                        heading: match (headingStyle) { case Some(style) => style; case None => Style(fg: Color.Yellow, modifier: Modifier.strong()) })
                }
                cachedWidth = -1
            }
        }
        setTextWidthOptions(buffer.textWidthOptions())
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let renderScroll = currentScroll()
        let rows = renderRowsWindow(document, target.width, renderScroll, target.height)
        var row: Int64 = 0
        while (row < target.height && row < rows.size) {
            let item = rows[row]
            renderStyledLine(buffer, target.x, target.y + row, item, target.width)
            row++
        }
    }

    func layoutRows(width: Int64): Array<StyledLine> {
        renderRows(document, width)
    }

    private func renderRows(document: Document, width: Int64): Array<StyledLine> {
        let foldRevision = match (state) {
            case Some(s) => s.foldRevision()
            case None => 0
        }
        let cursorSource = currentCursorSource()
        if (cacheLayout && cachedWidth == width &&
            cachedFoldRevision == foldRevision && cachedCursorSource == cursorSource) { return cachedRows }
        let rows = ArrayList<StyledLine>()
        for (line in document.lines) {
            appendLineRows(rows, line, width)
        }
        let result = rows.toArray()
        if (cacheLayout) {
            cachedWidth = width
            cachedRows = result
            cachedFoldRevision = foldRevision
            cachedCursorSource = cursorSource
        }
        result
    }

    private func renderRowsWindow(document: Document, width: Int64, start: Int64, count: Int64): Array<StyledLine> {
        if (cacheLayout) {
            let all = renderRows(document, width)
            let from = min(all.size, max(0, start))
            let to = min(all.size, from + max(0, count))
            return all[from..to]
        }
        let rows = ArrayList<StyledLine>()
        if (count <= 0) { return rows.toArray() }
        let from = max(0, start)
        let to = from + count
        var rowIndex: Int64 = 0
        for (line in document.lines) {
            let lineRows = ArrayList<StyledLine>()
            appendLineRows(lineRows, line, width)
            for (item in lineRows) {
                if (rowIndex >= to) { return rows.toArray() }
                if (rowIndex >= from) { rows.add(item) }
                rowIndex++
            }
        }
        rows.toArray()
    }

    private func appendLineRows(rows: ArrayList<StyledLine>, line: DocumentLine, width: Int64): Unit {
        if (isLineFolded(line)) { return }
        match (line.kind) {
            case DocumentLineKind.Blank =>
                rows.add(StyledLine(quotePrefixedSpans(line, theme.quoteStyle, [RichSpan("", style: theme.paragraph)])))
            case DocumentLineKind.Heading(level) =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans(headingMarker(level), themedSpans(line.spans, theme.headingStyle(level)), theme.headingStyle(level))), width)
            case DocumentLineKind.ListItem(ordered) =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans(if (ordered) { "1. " } else { "* " }, themedSpans(line.spans, theme.list), theme.list)), width)
            case DocumentLineKind.TaskListItem(checked) =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans(if (checked) { "[x] " } else { "[ ] " }, themedSpans(line.spans, theme.list), theme.list)), width)
            case DocumentLineKind.Quote =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, themedSpans(line.spans, theme.quoteStyle)), width)
            case DocumentLineKind.CodeBlock =>
                rows.add(StyledLine(quotePrefixedSpans(line, theme.quoteStyle, applyCurrentSourceHighlight(applyHighlights(themedSpans(line.spans, theme.code), highlights), currentCursorSource(), currentSourceStyle))))
            case DocumentLineKind.TableRow =>
                rows.add(StyledLine(quotePrefixedSpans(line, theme.quoteStyle, applyCurrentSourceHighlight(applyHighlights(themedSpans(line.spans, theme.table), highlights), currentCursorSource(), currentSourceStyle))))
            case DocumentLineKind.TableHeader =>
                rows.add(StyledLine(quotePrefixedSpans(line, theme.quoteStyle, applyCurrentSourceHighlight(applyHighlights(themedSpans(line.spans, theme.tableHeader), highlights), currentCursorSource(), currentSourceStyle))))
            case DocumentLineKind.HorizontalRule =>
                rows.add(StyledLine(
                    quotePrefixedSpans(line, theme.quoteStyle, [RichSpan(repeat("-", width), style: theme.table)]),
                    horizontalRule: true,
                    ruleLabel: themedSpans(line.spans, theme.table)
                ))
            case DocumentLineKind.Image =>
                match (line.media) {
                    case Some(source) =>
                        rows.add(StyledLine(
                            quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans("! ", themedSpans(line.spans, theme.image), theme.image)),
                            media: Some(source),
                            mediaFit: line.mediaFit,
                            mediaHeight: line.mediaHeight
                        ))
                        for (_ in 1..line.mediaHeight) {
                            rows.add(StyledLine([RichSpan("", style: theme.image)]))
                        }
                    case None =>
                        addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans("! ", themedSpans(line.spans, theme.image), theme.image)), width)
                }
            case DocumentLineKind.Diagnostic =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, prefixedSpans("! ", themedSpans(line.spans, theme.diagnostic), theme.diagnostic)), width)
            case DocumentLineKind.Html =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, themedSpans(line.spans, theme.html)), width)
            case DocumentLineKind.Strikethrough =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, themedSpans(line.spans, theme.strikethrough)), width)
            case DocumentLineKind.CodeFenceInfo(_) =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, themedSpans(line.spans, theme.inlineCode)), width)
            case DocumentLineKind.Paragraph =>
                addWrappedSpans(rows, quotePrefixedSpans(line, theme.quoteStyle, themedSpans(line.spans, theme.paragraph)), width)
        }
        }

    private func sourceOffsetFromRow(row: StyledLine): ?Int64 {
        for (span in row.spans) {
            match (span.sourceRange) {
                case Some(value) => return parseSourceOffset(value)
                case None => ()
            }
        }
        None
    }

    private func addWrappedSpans(rows: ArrayList<StyledLine>, spans: Array<RichSpan>, width: Int64): Unit {
        let highlighted = applyCurrentSourceHighlight(applyHighlights(spans, highlights), currentCursorSource(), currentSourceStyle)
        let text = spansText(highlighted)
        let noWrap = match (wrap) {
            case WrapMode.NoWrap => true
            case _ => false
        }
        if (displayWidth(text, options: textWidthOptionsValue) <= width || noWrap) {
            rows.add(StyledLine(highlighted))
            return
        }
        let wrapped = match (wrap) {
            case WrapMode.Word => wrapRichSpansByWord(highlighted, width, textWidthOptionsValue)
            case _ => wrapRichSpans(highlighted, width, textWidthOptionsValue)
        }
        for (line in wrapped) {
            rows.add(line)
        }
    }

    private func currentScroll(): Int64 {
        match (state) {
            case Some(s) => max(0, s.scroll)
            case None => scroll
        }
    }

    private func currentCursorSource(): ?Int64 {
        match (state) {
            case Some(s) => s.cursorSourceOffset
            case None => None
        }
    }

    private func isLineFolded(line: DocumentLine): Bool {
        let start = lineStartOffset(line)
        match (start) {
            case Some(offset) =>
                match (state) {
                    case Some(s) =>
                        for (range in s.folds()) {
                            if (range.startOffset < offset && offset <= range.endOffset) { return true }
                        }
                    case None => ()
                }
            case None => ()
        }
        false
    }
}

// Document layout stores styled spans, so a palette change must invalidate it.
func documentContextThemeEqual(left: ?Theme, right: ?Theme): Bool {
    match ((left, right)) {
        case (None, None) => true
        case (Some(a), Some(b)) => a.normal == b.normal && a.heading == b.heading &&
            a.accent == b.accent && a.info == b.info && a.secondary == b.secondary && a.error == b.error
        case _ => false
    }
}

public class MarkdownView <: Widget {
    private let view: DocumentView

    public init(
        text: String,
        block!: ?Block = None,
        style!: ?Style = None,
        headingStyle!: ?Style = None,
        theme!: ?DocumentTheme = None,
        scroll!: Int64 = 0,
        wrap!: WrapMode = WrapMode.Word
    ) {
        let textStyle = match (style) { case Some(value) => value; case None => Style.default() }
        this.view = DocumentView(Document.plain(text, style: textStyle), block: block, style: style, headingStyle: headingStyle, theme: theme, scroll: scroll, wrap: wrap)
    }

    public init(
        document: Document,
        block!: ?Block = None,
        style!: ?Style = None,
        headingStyle!: ?Style = None,
        theme!: ?DocumentTheme = None,
        scroll!: Int64 = 0,
        wrap!: WrapMode = WrapMode.Word
    ) {
        this.view = DocumentView(document, block: block, style: style, headingStyle: headingStyle, theme: theme, scroll: scroll, wrap: wrap)
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        view.render(area, buffer)
    }
}

class StyledLine {
    let spans: Array<RichSpan>
    let media: ?MediaSource
    let mediaFit: MediaFit
    let mediaHeight: Int64
    let horizontalRule: Bool
    let ruleLabel: Array<RichSpan>

    init(
        spans: Array<RichSpan>,
        media!: ?MediaSource = None,
        mediaFit!: MediaFit = MediaFit.Contain,
        mediaHeight!: Int64 = 0,
        horizontalRule!: Bool = false,
        ruleLabel!: Array<RichSpan> = []
    ) {
        this.spans = spans
        this.media = media
        this.mediaFit = mediaFit
        this.mediaHeight = max(0, mediaHeight)
        this.horizontalRule = horizontalRule
        this.ruleLabel = ruleLabel
    }
}

func renderStyledLine(buffer: Buffer, x: Int64, y: Int64, line: StyledLine, width: Int64): Unit {
    var cx = x
    let right = x + width
    for (span in line.spans) {
        if (cx >= right) { return }
        cx += buffer.writeStringClipped(
            cx,
            y,
            span.text,
            maxWidth: right - cx,
            style: span.style
        )
    }
    match (line.media) {
        case Some(source) =>
            let area = Rect(x, y, width, max(1, line.mediaHeight))
            buffer.addMedia(MediaPlacement("document:${source.id}:${x}:${y}", source, area, fit: line.mediaFit))
        case None => ()
    }
}

func spansText(spans: Array<RichSpan>): String {
    let parts = ArrayList<String>()
    for (span in spans) {
        parts.add(span.text)
    }
    join(parts.toArray(), "")
}

func themedSpans(spans: Array<RichSpan>, fallback: Style): Array<RichSpan> {
    if (spans.size == 0) { return [RichSpan("", style: fallback)] }
    let out = ArrayList<RichSpan>()
    for (span in spans) {
        out.add(RichSpan(span.text, style: if (span.style == Style.default()) { fallback } else { span.style }, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
    }
    out.toArray()
}

func prefixedSpans(prefix: String, spans: Array<RichSpan>, style: Style): Array<RichSpan> {
    let out = ArrayList<RichSpan>()
    out.add(RichSpan(prefix, style: style))
    for (span in spans) {
        out.add(span)
    }
    out.toArray()
}

func quotePrefixedSpans(line: DocumentLine, quoteStyle: Style, spans: Array<RichSpan>): Array<RichSpan> {
    var depth = line.quoteDepth
    match (line.kind) {
        case DocumentLineKind.Quote =>
            if (depth == 0) { depth = 1 }
        case _ => ()
    }
    if (depth <= 0) { return spans }
    prefixedSpans(repeat("| ", depth), spans, quoteStyle)
}

func headingMarker(level: Int64): String {
    repeat("#", clamp(level, 1, 6)) + " "
}

func parseSourceOffset(value: String): ?Int64 {
    var out: Int64 = 0
    var seen = false
    for (i in 0..value.size) {
        let b = value[i]
        if (b >= b'0' && b <= b'9') {
            let digit = Int64(b - b'0')
            if (out > (Int64.Max - digit) / 10) { return None }
            out = out * 10 + digit
            seen = true
        } else {
            break
        }
    }
    if (seen) { Some(out) } else { None }
}

func parseSourceEndOffset(value: String): ?Int64 {
    let sep = findByteFromLocal(value, b':', 0)
    if (sep < 0 || sep + 1 >= value.size) { return None }
    parseSourceOffset(value[sep + 1..])
}

func findByteFromLocal(text: String, value: Byte, start: Int64): Int64 {
    var i = start
    while (i < text.size) {
        if (text[i] == value) { return i }
        i++
    }
    -1
}

func applyHighlights(spans: Array<RichSpan>, highlights: Array<DocumentHighlight>): Array<RichSpan> {
    if (highlights.size == 0) { return spans }
    var current = spans
    for (highlight in highlights) {
        if (highlight.query.isEmpty()) { continue }
        current = applyHighlight(current, highlight.query, highlight.style)
    }
    current
}

func applyHighlight(spans: Array<RichSpan>, query: String, style: Style): Array<RichSpan> {
    let out = ArrayList<RichSpan>()
    for (span in spans) {
        var offset: Int64 = 0
        let clusters = graphemeClusters(span.text)
        var clusterIndex: Int64 = 0
        while (offset < span.text.size) {
            let idx = stringIndexOf(span.text, query, offset)
            if (idx < 0) {
                out.add(RichSpan(span.text[offset..], style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                offset = span.text.size
            } else {
                // A style belongs to a rendered cell. A match within a
                // grapheme therefore highlights the whole grapheme, keeping
                // combining marks and joined emoji with their leading text.
                while (clusters[clusterIndex].endOffset <= idx) { clusterIndex++ }
                let start = clusters[clusterIndex].startOffset
                let matchEnd = idx + query.size
                while (clusters[clusterIndex].endOffset < matchEnd) { clusterIndex++ }
                let end = clusters[clusterIndex].endOffset
                if (start > offset) {
                    out.add(RichSpan(span.text[offset..start], style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                }
                out.add(RichSpan(span.text[start..end], style: span.style.patch(style), linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                offset = end
            }
        }
    }
    out.toArray()
}

func applyCurrentSourceHighlight(spans: Array<RichSpan>, sourceOffset: ?Int64, style: Style): Array<RichSpan> {
    match (sourceOffset) {
        case Some(offset) =>
            let out = ArrayList<RichSpan>()
            for (span in spans) {
                if (spanContainsSource(span, offset)) {
                    out.add(RichSpan(span.text, style: span.style.patch(style), linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                } else {
                    out.add(span)
                }
            }
            out.toArray()
        case None => spans
    }
}

func spanContainsSource(span: RichSpan, offset: Int64): Bool {
    match (span.sourceRange) {
        case Some(value) =>
            match ((parseSourceOffset(value), parseSourceEndOffset(value))) {
                case (Some(start), Some(end)) => start <= offset && offset <= end
                case _ => false
            }
        case None => false
    }
}

func lineStartOffset(line: DocumentLine): ?Int64 {
    for (span in line.spans) {
        match (span.sourceRange) {
            case Some(value) => return parseSourceOffset(value)
            case None => ()
        }
    }
    None
}

func wrapRichSpans(spans: Array<RichSpan>, width: Int64, options: TextWidthOptions): Array<StyledLine> {
    let rows = ArrayList<StyledLine>()
    if (width <= 0) { return rows.toArray() }
    var current = ArrayList<RichSpan>()
    var currentWidth: Int64 = 0
    for (span in spans) {
        for (cluster in graphemeClusters(span.text, options: options)) {
            let w = cluster.width
            if (w > 0 && currentWidth > 0 && currentWidth + w > width) {
                rows.add(StyledLine(current.toArray()))
                current = ArrayList<RichSpan>()
                currentWidth = 0
            }
            current.add(RichSpan(cluster.text, style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
            currentWidth += w
        }
    }
    if (current.size > 0 || rows.size == 0) {
        rows.add(StyledLine(current.toArray()))
    }
    rows.toArray()
}

func wrapRichSpansByWord(spans: Array<RichSpan>, width: Int64, options: TextWidthOptions): Array<StyledLine> {
    let rows = ArrayList<StyledLine>()
    if (width <= 0) { return rows.toArray() }
    var current = ArrayList<RichSpan>()
    var currentWidth: Int64 = 0
    for (span in spans) {
        let chunks = wordChunks(span.text)
        for (chunk in chunks) {
            let w = displayWidth(chunk, options: options)
            if (w > width) {
                if (current.size > 0) {
                    rows.add(StyledLine(current.toArray()))
                    current = ArrayList<RichSpan>()
                    currentWidth = 0
                }
                for (line in wrapRichSpans([RichSpan(chunk, style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange)], width, options)) {
                    rows.add(line)
                }
            } else if (currentWidth > 0 && currentWidth + w > width) {
                rows.add(StyledLine(trimTrailingSpaceSpans(current.toArray())))
                current = ArrayList<RichSpan>()
                currentWidth = 0
                if (!isOnlySpaces(chunk)) {
                    current.add(RichSpan(trimLeadingSpaces(chunk), style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                    currentWidth += displayWidth(trimLeadingSpaces(chunk), options: options)
                }
            } else {
                current.add(RichSpan(chunk, style: span.style, linkUrl: span.linkUrl, sourceRange: span.sourceRange))
                currentWidth += w
            }
        }
    }
    if (current.size > 0 || rows.size == 0) {
        rows.add(StyledLine(trimTrailingSpaceSpans(current.toArray())))
    }
    rows.toArray()
}

func wordChunks(text: String): Array<String> {
    let chunks = ArrayList<String>()
    var start: Int64 = 0
    var inSpace = false
    var i: Int64 = 0
    while (i < text.size) {
        let space = text[i] == b' ' || text[i] == b'\t'
        if (i == 0) {
            inSpace = space
        } else if (space != inSpace) {
            chunks.add(text[start..i])
            start = i
            inSpace = space
        }
        i++
    }
    if (start < text.size) {
        chunks.add(text[start..])
    }
    chunks.toArray()
}

func isOnlySpaces(text: String): Bool {
    if (text.isEmpty()) { return false }
    for (i in 0..text.size) {
        if (!(text[i] == b' ' || text[i] == b'\t')) { return false }
    }
    true
}

func trimLeadingSpaces(text: String): String {
    var start: Int64 = 0
    while (start < text.size && (text[start] == b' ' || text[start] == b'\t')) { start++ }
    text[start..]
}

func trimTrailingSpaceSpans(spans: Array<RichSpan>): Array<RichSpan> {
    if (spans.size == 0) { return spans }
    let out = ArrayList<RichSpan>()
    for (span in spans) { out.add(span) }
    while (out.size > 0 && isOnlySpaces(out[out.size - 1].text)) {
        out.remove(at: out.size - 1)
    }
    if (out.size == 0) { return spans }
    let last = out[out.size - 1]
    let trimmed = trimTrailingSpaces(last.text)
    out[out.size - 1] = RichSpan(trimmed, style: last.style, linkUrl: last.linkUrl, sourceRange: last.sourceRange)
    out.toArray()
}

func trimTrailingSpaces(text: String): String {
    var end = text.size
    while (end > 0 && (text[end - 1] == b' ' || text[end - 1] == b'\t')) { end-- }
    text[..end]
}
