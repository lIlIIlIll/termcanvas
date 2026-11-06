package markdown_adapter

import core.*
import markdown.core.{Markdown, MarkdownProfile, ParseResult}

/** 根据目标缓冲区的应用主题渲染 Markdown；显式文档主题优先。
 *
 * 文本只在创建或更新时解析；文档样式仅在实际使用的文档主题变化时重新转换。
 * 语法高亮保留自身颜色，并在对应代码背景上绘制。需要滚动交互时传入 state。
 */
public class ThemedMarkdownView <: Widget {
    private var source: String
    private var parsed: ParseResult
    private let explicitTheme: ?DocumentTheme
    private let preserveSoftBreaks: Bool
    private let syntax: ?SyntaxHighlightConfig
    private let block: ?Block
    private let state: ?DocumentViewState
    private let scroll: Int64
    private let wrap: WrapMode
    private let highlights: Array<DocumentHighlight>
    private let cacheLayout: Bool
    private var cachedTheme: ?DocumentTheme = None
    private var cachedView: ?DocumentView = None

    /** 创建主题感知视图；未指定 theme 时读取每次绘制的应用主题，无应用主题时沿用 DocumentTheme 默认值。 */
    public init(text: String, theme!: ?DocumentTheme = None, preserveSoftBreaks!: Bool = false,
        syntax!: ?SyntaxHighlightConfig = None, block!: ?Block = None, state!: ?DocumentViewState = None,
        scroll!: Int64 = 0, wrap!: WrapMode = WrapMode.Word, highlights!: Array<DocumentHighlight> = [],
        cacheLayout!: Bool = false) {
        source = text
        parsed = Markdown.parse(text, profile: MarkdownProfile.gfmModernV1())
        explicitTheme = theme
        this.preserveSoftBreaks = preserveSoftBreaks
        this.syntax = syntax
        this.block = block
        this.state = state
        this.scroll = scroll
        this.wrap = wrap
        this.highlights = highlights
        this.cacheLayout = cacheLayout
    }

    /** 替换源文本；相同文本不会重新解析，视图状态对象保持不变。 */
    public func setText(text: String): Unit {
        if (text == source) { return }
        source = text
        parsed = Markdown.parse(text, profile: MarkdownProfile.gfmModernV1())
        cachedTheme = None
        cachedView = None
    }

    private func viewFor(theme: DocumentTheme): DocumentView {
        if (let Some(previous) <- cachedTheme) {
            if (sameMarkdownDocumentTheme(previous, theme)) {
                if (let Some(view) <- cachedView) { return view }
            }
        }
        let document = convertMarkdown(parsed, theme, preserveSoftBreaks, false, syntax).document
        let view = DocumentView(document, theme: Some(theme), block: block, state: state,
            scroll: scroll, wrap: wrap, highlights: highlights, cacheLayout: cacheLayout)
        cachedTheme = Some(theme)
        cachedView = Some(view)
        view
    }

    private func defaultTheme(): DocumentTheme {
        match (explicitTheme) { case Some(value) => value; case None => DocumentTheme() }
    }

    /** 使用最近一次绘制的视图处理滚动键；未传入状态对象时返回 false。 */
    public func handleKey(key: KeyEvent, width: Int64, viewportHeight: Int64): Bool {
        let view = match (cachedView) { case Some(value) => value; case None => viewFor(defaultTheme()) }
        view.handleKey(key, width, viewportHeight)
    }

    /** 使用最近一次绘制的视图将鼠标位置映射到源偏移。 */
    public func handleMouse(mouse: MouseEvent, area: Rect): ?Int64 {
        let view = match (cachedView) { case Some(value) => value; case None => viewFor(defaultTheme()) }
        view.handleMouse(mouse, area)
    }

    /** 使用目标缓冲区的主题和宽度策略绘制；不修改已提供的显式文档主题。 */
    public func render(area: Rect, buffer: Buffer): Unit {
        let theme = match (explicitTheme) {
            case Some(value) => value
            case None => match (buffer.resolveTheme(Option<Theme>.None)) {
                case Some(value) => documentThemeFromTheme(value)
                case None => DocumentTheme()
            }
        }
        viewFor(theme).render(area, buffer)
    }
}

// DocumentTheme does not implement Equatable; compare every style that can
// affect conversion or DocumentView rendering rather than an incomplete key.
func sameMarkdownDocumentTheme(a: DocumentTheme, b: DocumentTheme): Bool {
    a.paragraph == b.paragraph && a.heading == b.heading && a.heading1 == b.heading1 && a.heading2 == b.heading2 &&
    a.heading3 == b.heading3 && a.heading4 == b.heading4 && a.heading5 == b.heading5 && a.heading6 == b.heading6 &&
    a.list == b.list && a.quoteStyle == b.quoteStyle && a.code == b.code && a.table == b.table && a.link == b.link &&
    a.emphasis == b.emphasis && a.strong == b.strong && a.inlineCode == b.inlineCode && a.image == b.image &&
    a.diagnostic == b.diagnostic && a.html == b.html && a.strikethrough == b.strikethrough && a.tableHeader == b.tableHeader
}
