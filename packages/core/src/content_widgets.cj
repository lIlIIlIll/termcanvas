package core

import std.collection.*
import std.env.*

/** 记录项的内容类别。
 */
public enum TranscriptItemKind {
    /** 文本。
     */
    | Text
    /** 代码。
     */
    | Code
    /** 事件。
     */
    | Event
    /** 错误。
     */
    | Error
    /** 进度。
     */
    | Progress
    /** 详情。
     */
    | Detail
}

/** 记录项的执行状态。
 */
public enum TranscriptItemStatus {
    /** 待处理。
     */
    | Pending
    /** 已排队。
     */
    | Queued
    /** 运行中。
     */
    | Running
    /** 流式输出中。
     */
    | Streaming
    /** 已完成。
     */
    | Done
    /** 等待批准。
     */
    | Awaiting
    /** 已批准。
     */
    | Approved
    /** 失败。
     */
    | Failed
    /** 已取消。
     */
    | Cancelled
    /** 已拒绝。
     */
    | Rejected
    /** 超时。
     */
    | TimedOut
    /** 已过期。
     */
    | Expired
    /** 冲突。
     */
    | Conflict
}

/** 记录卡片中的可选项。
 */
public class TranscriptCardOption {
    /** 选项文本。
     */
    public let label: String
    /** 是否突出显示此选项。
     */
    public let selected: Bool

    /** 创建并保存配置。
     * @param label 选项文本
     * @param selected 是否选中
     */
    public init(label: String, selected!: Bool = false) {
        this.label = label
        this.selected = selected
    }
}

/** 控制记录卡片的样式和内容布局。
 */
public class TranscriptCardTheme {
    /** 正文样式。
     */
    public let style: Style
    /** 标题样式。
     */
    public let titleStyle: Style
    /** 次要信息样式。
     */
    public let mutedStyle: Style
    /** 选项选中样式。
     */
    public let selectedStyle: Style
    /** 正文缩进列数，不小于零。
     */
    public let bodyIndent: Int64
    /** 正文最多显示的原始行数；零表示不限制。
     */
    public let bodyLimit: Int64
    /** 边框样式。
     */
    public let borderStyle: Style
    /** 边框背景样式。
     */
    public let borderBackground: Style
    /** 顶部标题样式。
     */
    public let topTitleStyle: Style
    // Transcript hosts can opt individual items into a complete terminal
    // frame or a borderless, full-width background block.  Defaults retain
    // the historical left-rail rendering for existing clients.
    /** 是否使用完整边框。
     */
    public let fullFrame: Bool
    /** 是否填充背景。
     */
    public let fillBackground: Bool
    /** 内容内边距。
     */
    public let contentPadding: Spacing
    let semanticTheme: ?Theme

    /** 创建并保存配置。
     * @param style 正文样式
     * @param titleStyle 标题样式
     * @param mutedStyle 次要信息样式
     * @param selectedStyle 选中项样式
     * @param bodyIndent 正文缩进列数，负值按零处理
     * @param bodyLimit 正文最多显示的原始行数，零表示不限制
     * @param borderStyle 边框样式
     * @param borderBackground 边框背景样式
     * @param topTitleStyle 顶部标题样式
     * @param fullFrame 是否使用完整边框
     * @param fillBackground 是否填充背景
     * @param contentPadding 内容内边距
     * @param semanticTheme 可选语义主题
     */
    public init(
        style!: Style = Style.default(),
        titleStyle!: Style = Style(modifier: Modifier.strong()),
        mutedStyle!: Style = Style(fg: Color.Indexed(8)),
        selectedStyle!: Style = Style(fg: Color.Cyan, modifier: Modifier.strong()),
        bodyIndent!: Int64 = 2,
        bodyLimit!: Int64 = 12,
        borderStyle!: Style = Style(fg: Color.Indexed(8)),
        borderBackground!: Style = Style.default(),
        topTitleStyle!: Style = Style(modifier: Modifier.strong()),
        fullFrame!: Bool = false,
        fillBackground!: Bool = false,
        contentPadding!: Spacing = Spacing.zero(),
        semanticTheme!: ?Theme = None
    ) {
        this.style = style
        this.titleStyle = titleStyle
        this.mutedStyle = mutedStyle
        this.selectedStyle = selectedStyle
        this.bodyIndent = max(0, bodyIndent)
        this.bodyLimit = max(0, bodyLimit)
        this.borderStyle = borderStyle
        this.borderBackground = borderBackground
        this.topTitleStyle = topTitleStyle
        this.fullFrame = fullFrame
        this.fillBackground = fillBackground
        this.contentPadding = contentPadding
        this.semanticTheme = semanticTheme
    }
}

// Preserve the source's card geometry while mapping the default palette to
// application roles. Explicit card themes remain fully caller-owned.
func applicationTranscriptCardTheme(theme: Theme, style!: Style = Style.default()): TranscriptCardTheme {
    TranscriptCardTheme(style: theme.normal.patch(style), titleStyle: theme.heading,
        mutedStyle: theme.secondary, selectedStyle: theme.selected,
        borderStyle: theme.border, borderBackground: theme.surface,
        topTitleStyle: theme.heading, semanticTheme: Some(theme))
}

/** 一条带状态和可折叠正文的记录。
 */
public class TranscriptItem {
    /** 记录标识。
     */
    public let id: String
    /** 内容类别。
     */
    public let kind: TranscriptItemKind
    /** 标题；为空时卡片使用标识。
     */
    public let title: String
    /** 正文文档。
     */
    public let body: Document
    /** 执行状态。
     */
    public let status: TranscriptItemStatus
    /** 是否折叠正文。
     */
    public var collapsed: Bool
    /** 调用者保存的时间文本。
     */
    public let timestamp: String
    /** 显示在标题后的耗时文本。
     */
    public let duration: String
    /** 自定义状态文本；为空时使用状态默认标签。
     */
    public let stateLabel: String
    /** 活动状态的动画帧，构造时负值按零处理。
     */
    public let activityFrame: Int64
    /** 正文后的选项。
     */
    public let options: Array<TranscriptCardOption>
    /** 正文后的页脚文本。
     */
    public let footer: String

    /** 创建并保存配置。
     * @param id 记录标识
     * @param kind 内容类别
     * @param title 标题
     * @param body 正文文档
     * @param status 执行状态
     * @param collapsed 是否折叠正文
     * @param timestamp 调用者保存的时间文本
     * @param duration 耗时文本
     * @param stateLabel 自定义状态文本
     * @param activityFrame 活动状态动画帧，负值按零处理
     * @param options 卡片选项
     * @param footer 页脚文本
     */
    public init(
        id: String,
        kind!: TranscriptItemKind = TranscriptItemKind.Text,
        title!: String = "",
        body!: Document = Document([]),
        status!: TranscriptItemStatus = TranscriptItemStatus.Done,
        collapsed!: Bool = false,
        timestamp!: String = "",
        duration!: String = "",
        stateLabel!: String = "",
        activityFrame!: Int64 = 0,
        options!: Array<TranscriptCardOption> = [],
        footer!: String = ""
    ) {
        this.id = id
        this.kind = kind
        this.title = title
        this.body = body
        this.status = status
        this.collapsed = collapsed
        this.timestamp = timestamp
        this.duration = duration
        this.stateLabel = stateLabel
        this.activityFrame = max(0, activityFrame)
        this.options = options
        this.footer = footer
    }
}

/** 按顺序保存记录项。
 */
public class Transcript {
    private let items = ArrayList<TranscriptItem>()

    /** 创建记录集合。
     * @param items 初始记录项
     */
    public init(items!: Array<TranscriptItem> = []) {
        for (item in items) { this.items.add(item) }
    }

    /** 在末尾追加记录。
     * @param item 待追加的记录
     */
    public func append(item: TranscriptItem): Unit {
        items.add(item)
    }

    /** 获取记录数。
     * @return 记录项数量。
     */
    public func size(): Int64 {
        items.size
    }

    /** 按索引查找记录。
     * @param index 从零开始的索引
     * @return 索引有效时返回记录，否则返回 None。
     */
    public func get(index: Int64): ?TranscriptItem {
        if (index < 0 || index >= items.size) { None } else { Some(items[index]) }
    }

    /** 取得顺序数组。
     * @return 包含当前记录项的数组。
     */
    public func toArray(): Array<TranscriptItem> {
        items.toArray()
    }

    /** 切换第一个匹配标识的记录的折叠状态。
     * @param id 记录标识
     * @return 找到记录时为 true，否则为 false。
     */
    public func toggleCollapsed(id: String): Bool {
        for (item in items) {
            if (item.id == id) {
                item.collapsed = !item.collapsed
                return true
            }
        }
        false
    }
}

/** 绘制记录集合并支持键盘导航。
 */
public class TranscriptView <: Widget {
    private let transcript: Transcript
    /** 视口起始记录索引。
     */
    public var offset: Int64
    /** 当前选中的记录索引。
     */
    public var selected: Int64
    private let block: ?Block
    private let style: ?Style
    private let selectedStyle: ?Style
    private let cardTheme: TranscriptCardTheme
    private let explicitCardTheme: Bool
    private var viewportWidth: Int64 = 0
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()

    /** 创建记录视图。
     * @param transcript 要显示的记录集合
     * @param offset 初始起始索引，负值按零处理
     * @param selected 初始选中索引，负值按零处理
     * @param block 可选外框
     * @param style 可选正文样式
     * @param selectedStyle 可选选中样式
     * @param cardTheme 可选卡片主题
     */
    public init(
        transcript: Transcript,
        offset!: Int64 = 0,
        selected!: Int64 = 0,
        block!: ?Block = None,
        style!: ?Style = None,
        selectedStyle!: ?Style = None,
        cardTheme!: ?TranscriptCardTheme = None
    ) {
        this.transcript = transcript
        this.offset = max(0, offset)
        this.selected = max(0, selected)
        this.block = block
        this.style = style
        this.selectedStyle = selectedStyle
        this.explicitCardTheme = cardTheme.isSome()
        this.cardTheme = match (cardTheme) {
            case Some(value) => value
            case None => TranscriptCardTheme(style: match (style) { case Some(value) => value; case None => Style.default() })
        }
    }

    /** 处理上下、翻页及折叠按键。
     * @param key 键盘事件
     * @param viewportHeight 可见高度，用于调整滚动
     * @return 按键被处理时为 true。
     */
    public func handle(key: KeyEvent, viewportHeight: Int64): Bool {
        let count = transcript.size()
        match (key.code) {
            case KeyCode.Up =>
                selected = max(0, selected - 1)
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.Down =>
                selected = min(max(0, count - 1), selected + 1)
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.PageUp =>
                selected = max(0, selected - max(1, viewportHeight))
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.PageDown =>
                selected = min(max(0, count - 1), selected + max(1, viewportHeight))
                ensureTranscriptVisible(max(1, viewportHeight))
                true
            case KeyCode.Enter | KeyCode.Char(r' ') =>
                match (transcript.get(selected)) {
                    case Some(item) => transcript.toggleCollapsed(item.id)
                    case None => false
                }
            case _ => false
        }
    }

    /** 在区域内绘制可见记录。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let applicationTheme = buffer.resolveTheme(Option<Theme>.None)
        let cardTheme = if (explicitCardTheme) { this.cardTheme } else {
            match (applicationTheme) {
                case Some(value) => applicationTranscriptCardTheme(value, style: match (style) { case Some(s) => s; case None => Style.default() })
                case None => this.cardTheme
            }
        }
        let selection = if (explicitCardTheme) {
            match (selectedStyle) { case Some(value) => value; case None => cardTheme.selectedStyle }
        } else {
            widgetRoleStyle(selectedStyle, applicationTheme, ThemeRole.Selected, Style(fg: Color.Black, bg: Color.White))
        }
        viewportWidth = target.width
        textWidthOptionsValue = buffer.textWidthOptions()
        ensureTranscriptVisible(target.height)
        var y = target.y
        var index = offset
        while (index < transcript.size() && y < target.bottom) {
            match (transcript.get(index)) {
                case Some(item) =>
                    let theme = if (index == selected) {
                        TranscriptCardTheme(
                            style: cardTheme.style,
                            titleStyle: selection,
                            mutedStyle: cardTheme.mutedStyle,
                            selectedStyle: cardTheme.selectedStyle,
                            bodyIndent: cardTheme.bodyIndent,
                            bodyLimit: cardTheme.bodyLimit,
                            borderStyle: cardTheme.borderStyle, borderBackground: cardTheme.borderBackground,
                            topTitleStyle: cardTheme.topTitleStyle, fullFrame: cardTheme.fullFrame,
                            fillBackground: cardTheme.fillBackground, contentPadding: cardTheme.contentPadding,
                            semanticTheme: cardTheme.semanticTheme
                        )
                    } else {
                        cardTheme
                    }
                    let document = transcriptCardDocument(item, theme: theme)
                    let documentTheme: ?DocumentTheme = if (explicitCardTheme) {
                        Some(DocumentTheme(paragraph: theme.style))
                    } else {
                        None
                    }
                    let view = DocumentView(document, theme: documentTheme, cacheLayout: true)
                    view.setTextWidthOptions(textWidthOptionsValue)
                    let height = min(target.bottom - y, max(1, view.renderedLineCount(target.width)))
                    view.render(
                        Rect(target.x, y, target.width, height),
                        buffer
                    )
                    y += height
                    if (y < target.bottom) { y++ }
                case None => ()
            }
            index++
        }
    }

    private func ensureTranscriptVisible(viewportHeight: Int64): Unit {
        let count = transcript.size()
        selected = clamp(selected, 0, max(0, count - 1))
        offset = clamp(offset, 0, max(0, count - 1))
        if (selected < offset) {
            offset = selected
            return
        }
        let limit = max(1, viewportHeight)
        var height = min(limit, transcriptItemHeight(selected))
        var index = selected - 1
        while (index >= offset) {
            height += transcriptItemHeight(index) + 1
            if (height > limit) {
                offset = index + 1
                return
            }
            index--
        }
    }

    private func transcriptItemHeight(index: Int64): Int64 {
        match (transcript.get(index)) {
            case Some(item) =>
                let document = transcriptCardDocument(item, theme: cardTheme)
                if (viewportWidth <= 0) { return max(1, document.lines.size) }
                let view = DocumentView(document)
                view.setTextWidthOptions(textWidthOptionsValue)
                max(1, view.renderedLineCount(viewportWidth))
            case None => 0
        }
    }
}

/** 输入器成功提交的内容。
 */
public class ComposerSubmit {
    /** 展开粘贴内容后的提交文本。
     */
    public let text: String
    /** 创建提交结果。
     * @param text 提交文本
     */
    public init(text: String) {
        this.text = text
    }
}

class ComposerRetainedPaste {
    let marker: String
    let payload: String

    init(marker: String, payload: String) {
        this.marker = marker
        this.payload = payload
    }
}

class ComposerHistoryEntry {
    let text: String
    let pastes: Array<ComposerRetainedPaste>

    init(text: String, pastes: Array<ComposerRetainedPaste>) {
        this.text = text
        this.pastes = pastes
    }
}

/** 带历史、补全和长文本粘贴处理的消息输入器。
 */
public class Composer <: Widget {
    /** 底层文本输入区域。
     */
    public let area: TextArea
    /** 最近一次长粘贴标记校验错误。
     */
    public var lastError: ?String = None
    private let history = ArrayList<ComposerHistoryEntry>()
    private let retainedPastes = ArrayList<ComposerRetainedPaste>()
    private let slashHints: Array<String>
    private var historyIndex: Int64 = -1
    private var historyDraft = ComposerHistoryEntry("", [])
    private var nextPasteId: Int64 = 1
    private var trackedValue: String
    private var visualScroll: Int64 = 0
    private let block: ?Block
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    private var cachedWrapRevision: Int64 = -1
    private var cachedWrapWidth: Int64 = -1
    private var cachedWrapLines: Array<String> = []
    private var cachedCursorRevision: Int64 = -1
    private var cachedCursorWidth: Int64 = -1
    private var cachedCursorOffset: Int64 = -1
    private var cachedCursorRow: Int64 = 0
    private var cachedCursorColumn: Int64 = 0

    /** 创建输入器。
     * @param value 初始文本
     * @param slashHints 斜杠命令候选
     * @param block 可选外框
     */
    public init(value!: String = "", slashHints!: Array<String> = [], block!: ?Block = None) {
        this.area = TextArea(value: value, block: block, placeholder: "message")
        this.slashHints = slashHints
        this.block = block
        this.trackedValue = value
    }

    /** 处理编辑、历史和提交按键；补全可见时优先处理补全。
     * @param key 键盘事件
     * @return 普通回车成功提交非空内容时返回结果，否则返回 None。
     */
    public func handle(key: KeyEvent): ?ComposerSubmit {
        synchronizeAreaValue()
        if (area.completionVisible()) {
            match (key.code) {
                case KeyCode.Enter | KeyCode.Tab | KeyCode.Up | KeyCode.Down | KeyCode.Esc =>
                    handleAreaKey(key)
                    return None
                case _ => ()
            }
        }
        match (key.code) {
            case KeyCode.Enter =>
                if (key.modifiers.shift || key.modifiers.alt) {
                    handleAreaKey(key)
                    None
                } else {
                    submit()
                }
            case KeyCode.Up =>
                if (history.size > 0 &&
                    (historyIndex >= 0 || area.value.isEmpty())) {
                    if (historyIndex < 0) {
                        historyDraft = currentHistoryEntry(area.value)
                        historyIndex = history.size - 1
                    } else {
                        historyIndex = max(0, historyIndex - 1)
                    }
                    restoreHistoryEntry(history[historyIndex])
                    None
                } else {
                    handleAreaKey(key)
                    None
                }
            case KeyCode.Down =>
                if (historyIndex >= 0 && history.size > 0) {
                    if (historyIndex < history.size - 1) {
                        historyIndex++
                        restoreHistoryEntry(history[historyIndex])
                    } else {
                        historyIndex = -1
                        restoreHistoryEntry(historyDraft)
                    }
                    None
                } else {
                    handleAreaKey(key)
                    None
                }
            case _ =>
                handleAreaKey(key)
                None
        }
    }

    /** 插入文本；超过阈值时在编辑区保留标记，提交时展开原文。
     * @param text 待粘贴文本
     * @param collapseThreshold 以字节计的折叠阈值
     * @return 当前实现返回 true。
     */
    public func paste(text: String, collapseThreshold!: Int64 = 2000): Bool {
        synchronizeAreaValue()
        let before = area.value
        if (text.size > collapseThreshold) {
            let marker = "[pasted ${text.size} bytes #${nextPasteId}]"
            nextPasteId++
            retainedPastes.add(ComposerRetainedPaste(marker, text))
            area.paste(marker)
        } else {
            area.paste(text)
        }
        recordAreaChange(before)
        true
    }

    /** 获取展开粘贴内容后的草稿。
     * @return 标记完整时返回草稿，否则返回 None 并设置错误。
     */
    public func draftText(): ?String {
        synchronizeAreaValue()
        expandedSubmissionText(area.value)
    }

    /** 替换当前草稿并重置补全与历史浏览状态。
     * @param text 要恢复的草稿文本
     */
    public func restoreDraft(text: String): Unit {
        clearRetainedPastes()
        lastError = None
        _ = area.cancelCompletion()
        historyIndex = -1
        historyDraft = ComposerHistoryEntry("", [])
        area.setValue("")
        trackedValue = ""
        _ = paste(text)
    }

    /** 按当前完整输入匹配斜杠命令前缀。
     * @return 匹配的候选数组；输入不以斜杠开头时为空。
     */
    public func currentSlashHints(): Array<String> {
        if (!area.value.startsWith("/")) { return [] }
        let out = ArrayList<String>()
        for (hint in slashHints) {
            if (hint.startsWith(area.value)) { out.add(hint) }
        }
        out.toArray()
    }

    /** 查询底层补全面板是否可见。
     * @return 可见时为 true。
     */
    public func completionVisible(): Bool {
        area.completionVisible()
    }

    /** 取消底层补全。
     * @return 取消了可见补全时为 true。
     */
    public func cancelCompletion(): Bool {
        area.cancelCompletion()
    }

    /** 计算换行和补全占用的可见高度。
     * @param width 文本宽度
     * @param maximum 最大行数
     * @return 计算得到的行数；宽度或上限非正时返回一。
     */
    public func visualHeight(width: Int64, maximum: Int64): Int64 {
        if (width <= 0 || maximum <= 0) { return 1 }
        let textRows = max(1, layoutLines(width).size)
        min(maximum, textRows + area.completionRows(
            maximum: max(0, maximum - textRows)
        ))
    }

    /** 计算当前区域内的光标位置，并调整垂直滚动。
     * @param areaRect 输入器绘制区域
     * @return 光标位置。
     */
    public func cursorPosition(areaRect: Rect): Position {
        var target = areaRect
        match (block) {
            case Some(value) => target = value.inner(areaRect)
            case None => ()
        }
        if (target.width <= 0 || target.height <= 0) {
            return Position(target.x, target.y)
        }
        let (row, column) = cursorLayout(target.width)
        visualScroll = max(0, row - target.height + 1)
        Position(
            target.x + min(column, target.width),
            target.y + clamp(
                row - visualScroll,
                0,
                max(0, target.height - 1)
            )
        )
    }

    /** 绘制文本、占位提示及补全。
     * @param areaRect 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(areaRect: Rect, buffer: Buffer): Unit {
        let theme = buffer.resolveTheme(Option<Theme>.None)
        let normal = widgetRoleStyle(Option<Style>.None, theme, ThemeRole.Normal, Style.default())
        let disabled = widgetRoleStyle(Option<Style>.None, theme, ThemeRole.Disabled, Style(fg: Color.Indexed(8)))
        let errorStyle = widgetRoleStyle(Option<Style>.None, theme, ThemeRole.Error, Style(fg: Color.Red))
        if (usesWideAmbiguous(textWidthOptionsValue) != usesWideAmbiguous(buffer.textWidthOptions())) {
            cachedWrapRevision = -1
            cachedCursorRevision = -1
        }
        textWidthOptionsValue = buffer.textWidthOptions()
        area.setTextWidthOptions(textWidthOptionsValue)
        synchronizeAreaValue()
        var target = areaRect
        match (block) {
            case Some(value) =>
                value.render(areaRect, buffer)
                target = value.inner(areaRect)
            case None => ()
        }
        if (target.width <= 0 || target.height <= 0) { return }
        if (area.value.isEmpty()) {
            buffer.setString(
                target.x,
                target.y,
                truncate("message", target.width, options: buffer.textWidthOptions()),
                style: disabled
            )
        } else {
            let lines = layoutLines(target.width)
            _ = cursorPosition(areaRect)
            for (row in 0..target.height) {
                let index = row + visualScroll
                if (index >= lines.size) { break }
                buffer.setString(
                    target.x,
                    target.y + row,
                    truncate(lines[index], target.width, options: buffer.textWidthOptions()), style: normal
                )
            }
        }
        match (lastError) {
            case Some(message) =>
                if (areaRect.height > 1) {
                    buffer.setString(
                        areaRect.x + 1,
                        areaRect.bottom - 1,
                        truncate(message, max(0, areaRect.width - 2), options: buffer.textWidthOptions()),
                        style: errorStyle
                    )
                }
            case None =>
                let hints = currentSlashHints()
                if (hints.size > 0 && areaRect.height > 1) {
                    buffer.setString(areaRect.x + 1, areaRect.bottom - 1, truncate(join(hints, "  "), max(0, areaRect.width - 2), options: buffer.textWidthOptions()), style: disabled)
                }
        }
        area.renderCompletionOverlay(target, buffer)
    }

    private func layoutLines(width: Int64): Array<String> {
        if (width <= 0) { return [] }
        let revision = area.editRevision()
        if (cachedWrapRevision != revision || cachedWrapWidth != width) {
            cachedWrapRevision = revision
            cachedWrapWidth = width
            cachedWrapLines = wrapText(area.value, width, WrapMode.Character, options: textWidthOptionsValue)
        }
        cachedWrapLines
    }

    private func cursorLayout(width: Int64): (Int64, Int64) {
        let revision = area.editRevision()
        if (cachedCursorRevision == revision && cachedCursorWidth == width && cachedCursorOffset == area.cursor) {
            return (cachedCursorRow, cachedCursorColumn)
        }
        let lines = if (area.cursor == area.value.size) {
            layoutLines(width)
        } else {
            wrapText(area.value[..area.cursor], width, WrapMode.Character, options: textWidthOptionsValue)
        }
        cachedCursorRevision = revision
        cachedCursorWidth = width
        cachedCursorOffset = area.cursor
        cachedCursorRow = max(0, lines.size - 1)
        cachedCursorColumn = if (lines.isEmpty()) { 0 } else { displayWidth(lines[lines.size - 1], options: textWidthOptionsValue) }
        (cachedCursorRow, cachedCursorColumn)
    }

    private func submit(): ?ComposerSubmit {
        synchronizeAreaValue()
        let displayText = trimAsciiSpacesLocal(area.value)
        if (displayText.isEmpty()) { return None }
        let text = match (expandedSubmissionText(displayText)) {
            case Some(value) => value
            case None => return None
        }
        history.add(currentHistoryEntry(displayText))
        historyIndex = -1
        historyDraft = ComposerHistoryEntry("", [])
        clearRetainedPastes()
        lastError = None
        area.setValue("")
        trackedValue = ""
        Some(ComposerSubmit(text))
    }

    private func handleAreaKey(key: KeyEvent): Unit {
        let before = area.value
        _ = area.handle(key)
        recordAreaChange(before)
    }

    private func synchronizeAreaValue(): Unit {
        if (trackedValue != area.value) {
            reconcileRetainedPastes(trackedValue, area.value)
            trackedValue = area.value
        }
        refreshPasteError()
    }

    private func recordAreaChange(before: String): Unit {
        reconcileRetainedPastes(before, area.value)
        trackedValue = area.value
        refreshPasteError()
    }

    private func reconcileRetainedPastes(before: String, after: String): Unit {
        if (before == after || retainedPastes.size == 0) { return }
        let (removedStart, removedEnd) = composerChangedRange(before, after)
        var index: Int64 = 0
        while (index < retainedPastes.size) {
            let item = retainedPastes[index]
            let beforeStart = stringIndexOf(before, item.marker, 0)
            let beforeCount = composerMarkerCount(before, item.marker)
            let afterCount = composerMarkerCount(after, item.marker)
            if (afterCount == 0 && beforeCount == 1 &&
                removedStart <= beforeStart &&
                removedEnd >= beforeStart + item.marker.size) {
                retainedPastes.remove(at: index)
            } else {
                index++
            }
        }
    }

    private func refreshPasteError(): Unit {
        lastError = retainedPasteError(area.value)
    }

    private func retainedPasteError(text: String): ?String {
        for (item in retainedPastes) {
            if (composerMarkerCount(text, item.marker) != 1) {
                return Some("paste marker damaged; restore or delete the entire marker")
            }
        }
        None
    }

    private func expandedSubmissionText(displayText: String): ?String {
        match (retainedPasteError(displayText)) {
            case Some(message) =>
                lastError = Some(message)
                return None
            case None => ()
        }
        var offset: Int64 = 0
        var result = ""
        while (true) {
            var nextOffset: Int64 = -1
            var nextPaste: Int64 = -1
            for (index in 0..retainedPastes.size) {
                let candidate = stringIndexOf(displayText, retainedPastes[index].marker, offset)
                if (candidate >= 0 && (nextOffset < 0 || candidate < nextOffset)) {
                    nextOffset = candidate
                    nextPaste = index
                }
            }
            if (nextPaste < 0) { break }
            let item = retainedPastes[nextPaste]
            result += displayText[offset..nextOffset]
            result += item.payload
            offset = nextOffset + item.marker.size
        }
        result += displayText[offset..]
        Some(result)
    }

    private func currentHistoryEntry(text: String): ComposerHistoryEntry {
        let pastes = ArrayList<ComposerRetainedPaste>()
        for (item in retainedPastes) { pastes.add(item) }
        ComposerHistoryEntry(text, pastes.toArray())
    }

    private func restoreHistoryEntry(entry: ComposerHistoryEntry): Unit {
        clearRetainedPastes()
        for (item in entry.pastes) { retainedPastes.add(item) }
        area.setValue(entry.text)
        trackedValue = entry.text
        refreshPasteError()
    }

    private func clearRetainedPastes(): Unit {
        while (retainedPastes.size > 0) {
            retainedPastes.remove(at: retainedPastes.size - 1)
        }
    }
}

func composerMarkerCount(text: String, marker: String): Int64 {
    var count: Int64 = 0
    var offset: Int64 = 0
    while (true) {
        let index = stringIndexOf(text, marker, offset)
        if (index < 0) { break }
        count++
        offset = index + marker.size
    }
    count
}

func composerChangedRange(before: String, after: String): (Int64, Int64) {
    var prefix: Int64 = 0
    let prefixLimit = min(before.size, after.size)
    while (prefix < prefixLimit && before[prefix] == after[prefix]) { prefix++ }
    var suffix: Int64 = 0
    while (suffix < before.size - prefix && suffix < after.size - prefix &&
        before[before.size - suffix - 1] == after[after.size - suffix - 1]) {
        suffix++
    }
    (prefix, before.size - suffix)
}

public class ActivityStep {
    public let title: String
    public let status: TranscriptItemStatus
    public let detail: String
    public let duration: String

    public init(title: String, status!: TranscriptItemStatus = TranscriptItemStatus.Pending, detail!: String = "", duration!: String = "") {
        this.title = title
        this.status = status
        this.detail = detail
        this.duration = duration
    }
}

public class ActivityTimeline <: Widget {
    private let steps: Array<ActivityStep>
    private let block: ?Block

    public init(steps: Array<ActivityStep>, block!: ?Block = None) {
        this.steps = steps
        this.block = block
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        let rows = min(target.height, steps.size)
        for (i in 0..rows) {
            let step = steps[i]
            let suffix = if (step.duration.isEmpty()) { "" } else { " " + step.duration }
            let detail = if (step.detail.isEmpty()) { "" } else { " - " + step.detail }
            buffer.setString(target.x, target.y + i, truncate(statusMark(step.status) + " " + step.title + detail + suffix, target.width, options: buffer.textWidthOptions()), style: transcriptStatusStyle(step.status, Style.default(), theme: buffer.resolveTheme(Option<Theme>.None)))
        }
    }
}

public class RequestDialog <: Widget {
    private let title: String
    private let body: String
    private let detail: Document
    private let risk: String
    private let buttons: Array<String>
    public var selected: Int64
    private let style: ?Style
    private let selectedStyle: ?Style
    private var theme: ?Theme = None

    public init(title!: String = "Request", body!: String = "", detail!: Document = Document([]), risk!: String = "", buttons!: Array<String> = ["Cancel", "Confirm"], selected!: Int64 = 0, style!: ?Style = None, selectedStyle!: ?Style = None, theme!: ?Theme = None) {
        this.title = title
        this.body = body
        this.detail = detail
        this.risk = risk
        this.buttons = buttons
        this.selected = clamp(selected, 0, max(0, buttons.size - 1))
        this.style = style
        this.selectedStyle = selectedStyle
        this.theme = theme
    }
    /** 设置请求对话框使用的语义主题；None 清除主题。
     */
    public func setTheme(theme: ?Theme): Unit {
        this.theme = theme
    }

    public func handle(key: KeyEvent): ?String {
        let dialog = Dialog(title: title, body: body, buttons: buttons, selected: selected, style: style, selectedStyle: selectedStyle, theme: theme)
        match (dialog.handle(key)) {
            case Some(action) =>
                selected = dialog.selected
                Some(action)
            case None =>
                selected = dialog.selected
                None
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withParentTheme(theme) { =>
            Dialog(title: title, body: if (risk.isEmpty()) { body } else { risk + "\n" + body }, buttons: buttons, selected: selected, style: style, selectedStyle: selectedStyle, theme: theme).render(area, buffer)
            if (detail.lines.size > 0 && area.width > 10 && area.height > 10) {
                let detailArea = Rect(area.x + area.width / 4, area.y + area.height / 2, area.width / 2, max(1, area.height / 3))
                DocumentView(detail).render(detailArea, buffer)
            }
        }
    }
}

public type DecisionDialog = RequestDialog

public func statusMark(
    status: TranscriptItemStatus,
    activityFrame!: Int64 = 0
): String {
    match (status) {
        case TranscriptItemStatus.Pending => "○"
        case TranscriptItemStatus.Queued => "✓"
        case TranscriptItemStatus.Running => runningStatusMark(activityFrame)
        case TranscriptItemStatus.Streaming => streamingStatusMark(activityFrame)
        case TranscriptItemStatus.Done => "✓"
        case TranscriptItemStatus.Awaiting => "?"
        case TranscriptItemStatus.Approved => "✓"
        case TranscriptItemStatus.Failed => "✗"
        case TranscriptItemStatus.Cancelled => "–"
        case TranscriptItemStatus.Rejected => "⊘"
        case TranscriptItemStatus.TimedOut => "⌛"
        case TranscriptItemStatus.Expired => "⌛"
        case TranscriptItemStatus.Conflict => "!"
    }
}

func runningStatusMark(frame: Int64): String {
    match (frame % 4) {
        case 0 => "◐"
        case 1 => "◓"
        case 2 => "◑"
        case _ => "◒"
    }
}

func streamingStatusMark(frame: Int64): String {
    match (frame % 4) {
        case 0 => "⋮"
        case 1 => "⋰"
        case 2 => "⋯"
        case _ => "⋱"
    }
}

public func transcriptStatusStyle(status: TranscriptItemStatus, base: Style): Style {
    transcriptStatusStyle(status, base, theme: None)
}

/** 根据显式主题解析状态样式；未提供主题时沿用原有无主题行为。 */
public func transcriptStatusStyle(status: TranscriptItemStatus, base: Style, theme!: ?Theme): Style {
    match (theme) {
        case Some(value) =>
            return match (status) {
                case TranscriptItemStatus.Pending => base.patch(value.disabled)
                case TranscriptItemStatus.Queued | TranscriptItemStatus.Done | TranscriptItemStatus.Approved => base.patch(value.success)
                case TranscriptItemStatus.Running | TranscriptItemStatus.Streaming => base.patch(value.accent)
                case TranscriptItemStatus.Awaiting | TranscriptItemStatus.Cancelled | TranscriptItemStatus.Expired => base.patch(value.warning)
                case TranscriptItemStatus.Failed | TranscriptItemStatus.Rejected | TranscriptItemStatus.TimedOut | TranscriptItemStatus.Conflict => base.patch(value.error)
            }
        case None => ()
    }
    match (getVariable("NO_COLOR")) {
        case Some(_) => return base
        case None => ()
    }
    match (status) {
        case TranscriptItemStatus.Pending => base.patch(Style(fg: Color.Indexed(8)))
        case TranscriptItemStatus.Queued => base.patch(Style(fg: Color.Green))
        case TranscriptItemStatus.Running => base.patch(Style(fg: Color.Cyan))
        case TranscriptItemStatus.Streaming => base.patch(Style(fg: Color.Cyan))
        case TranscriptItemStatus.Done => base.patch(Style(fg: Color.Green))
        case TranscriptItemStatus.Awaiting => base.patch(Style(fg: Color.Yellow))
        case TranscriptItemStatus.Approved => base.patch(Style(fg: Color.Green))
        case TranscriptItemStatus.Failed => base.patch(Style(fg: Color.Red))
        case TranscriptItemStatus.Cancelled => base.patch(Style(fg: Color.Yellow))
        case TranscriptItemStatus.Rejected => base.patch(Style(fg: Color.Red))
        case TranscriptItemStatus.TimedOut => base.patch(Style(fg: Color.Red))
        case TranscriptItemStatus.Expired => base.patch(Style(fg: Color.Yellow))
        case TranscriptItemStatus.Conflict => base.patch(Style(fg: Color.Yellow))
    }
}

public func transcriptStatusLabel(status: TranscriptItemStatus): String {
    match (status) {
        case TranscriptItemStatus.Pending => "pending"
        case TranscriptItemStatus.Queued => "queued"
        case TranscriptItemStatus.Running => "running"
        case TranscriptItemStatus.Streaming => "streaming"
        case TranscriptItemStatus.Done => "completed"
        case TranscriptItemStatus.Awaiting => "awaiting approval"
        case TranscriptItemStatus.Approved => "approved"
        case TranscriptItemStatus.Failed => "failed"
        case TranscriptItemStatus.Cancelled => "cancelled"
        case TranscriptItemStatus.Rejected => "rejected"
        case TranscriptItemStatus.TimedOut => "timed out"
        case TranscriptItemStatus.Expired => "expired"
        case TranscriptItemStatus.Conflict => "conflict"
    }
}

public func transcriptCardDocument(
    item: TranscriptItem,
    theme!: TranscriptCardTheme = TranscriptCardTheme()
): Document {
    let lines = ArrayList<DocumentLine>()
    let title = if (item.title.isEmpty()) { item.id } else { item.title }
    let state = if (item.stateLabel.isEmpty()) {
        transcriptStatusLabel(item.status)
    } else {
        item.stateLabel
    }
    let header = ArrayList<RichSpan>()
    header.add(RichSpan(
        statusMark(item.status, activityFrame: item.activityFrame) + " ",
        style: transcriptStatusStyle(item.status, theme.style, theme: theme.semanticTheme)
    ))
    header.add(RichSpan(title, style: theme.titleStyle))
    if (!state.isEmpty()) {
        header.add(RichSpan(" · " + state, style: theme.mutedStyle))
    }
    if (!item.duration.isEmpty()) {
        header.add(RichSpan(" · " + item.duration, style: theme.mutedStyle))
    }
    if (item.collapsed) {
        header.add(RichSpan("  ▸", style: theme.mutedStyle))
    }
    lines.add(DocumentLine(DocumentLineKind.Paragraph, header.toArray()))
    if (!item.collapsed) {
        let limit = if (theme.bodyLimit == 0) {
            item.body.lines.size
        } else {
            min(theme.bodyLimit, item.body.lines.size)
        }
        for (index in 0..limit) {
            lines.add(indentTranscriptLine(
                item.body.lines[index],
                theme.bodyIndent,
                theme.style
            ))
        }
        if (limit < item.body.lines.size) {
            lines.add(DocumentLine(
                DocumentLineKind.Paragraph,
                transcriptIndent(theme.bodyIndent) + "…",
                style: theme.mutedStyle
            ))
        }
        for (option in item.options) {
            lines.add(DocumentLine(
                DocumentLineKind.Paragraph,
                transcriptIndent(theme.bodyIndent) +
                    if (option.selected) { "› " } else { "  " } +
                    option.label,
                style: if (option.selected) {
                    theme.selectedStyle
                } else {
                    theme.style
                }
            ))
        }
        if (!item.footer.isEmpty()) {
            lines.add(DocumentLine(
                DocumentLineKind.Paragraph,
                transcriptIndent(theme.bodyIndent) + item.footer,
                style: theme.mutedStyle
            ))
        }
    }
    Document(lines.toArray())
}

func indentTranscriptLine(
    line: DocumentLine,
    width: Int64,
    style: Style
): DocumentLine {
    let spans = ArrayList<RichSpan>()
    spans.add(RichSpan(transcriptIndent(width), style: style))
    spans.add(all: line.spans)
    DocumentLine(
        line.kind,
        spans.toArray(),
        quoteDepth: line.quoteDepth,
        media: line.media,
        mediaFit: line.mediaFit,
        mediaHeight: line.mediaHeight
    )
}

func transcriptIndent(width: Int64): String {
    var result = ""
    for (_ in 0..max(0, width)) { result += " " }
    result
}

func insertPair(area: TextArea, left: String, right: String): Bool {
    let pos = area.cursor
    area.paste(left + right)
    area.cursor = pos + left.size
    true
}

func handleMarkdownEnter(area: TextArea): Bool {
    area.handle(KeyEvent(KeyCode.Enter))
}

func previousByteIs(area: TextArea, byte: UInt8): Bool {
    area.cursor > 0 && area.cursor <= area.value.size && area.value[area.cursor - 1] == byte
}

func closeRepeatedMarker(area: TextArea, marker: String): Bool {
    let start = area.cursor - 1
    area.select(start, area.cursor)
    area.paste(marker + marker)
    area.cursor = start + marker.size
    true
}

func wrapSelection(area: TextArea, left: String, right: String): Bool {
    match (area.selectedRange()) {
        case Some((start, end)) =>
            let text = area.value[start..end]
            area.paste(left + text + right)
            area.cursor = start + left.size + text.size
            area.clearSelection()
            true
        case None => false
    }
}

func wrapSelectionAsLink(area: TextArea): Bool {
    match (area.selectedRange()) {
        case Some((start, end)) =>
            let text = area.value[start..end]
            area.paste("[" + text + "]()")
            area.cursor = start + text.size + 3
            area.clearSelection()
            true
        case None => false
    }
}

func skipClosingDelimiter(area: TextArea, delimiter: String): Bool {
    if (area.cursor + delimiter.size <= area.value.size && area.value[area.cursor..area.cursor + delimiter.size] == delimiter) {
        area.cursor += delimiter.size
        area.clearSelection()
        return true
    }
    area.paste(delimiter)
    true
}

func wrapSelectionOrWord(area: TextArea, left: String, right: String): Bool {
    if (area.hasSelection()) { return wrapSelection(area, left, right) }
    let start = previousWordOffset(area.value, area.cursor)
    let end = nextWordOffset(area.value, area.cursor)
    area.select(start, end)
    wrapSelection(area, left, right)
}
