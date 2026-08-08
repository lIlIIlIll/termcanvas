package core

import std.collection.*

// A product supplies already-themed, single-card documents. The core owns
// viewport selection, measurement and cache invalidation only.
public interface VirtualTranscriptSource {
    func size(): Int64
    func itemId(index: Int64): String
    func itemTitle(_: Int64): String { "" }
    // Hosts may keep ordinary conversation rows as plain transcript text
    // while giving structured events the left event rail.  The default keeps
    // the historical card behaviour for existing cjtui clients.
    func itemUsesCardChrome(_: Int64): Bool { true }
    // The title is measured/rendered with the live terminal width so a host
    // can preserve the useful tail of a path or command before truncation.
    func itemTitleForWidth(index: Int64, width: Int64): String {
        let _ = width
        itemTitle(index)
    }
    func itemFooter(_: Int64): String { "" }
    // A structured event with no visible body or footer may use only the
    // title rail. This avoids spending a second terminal row on an empty
    // `╰─` while preserving the normal two-ended rail for meaningful
    // summaries and expanded content.
    func itemUsesCompactCardChrome(_: Int64): Bool { false }
    func revision(index: Int64): Int64
    func document(index: Int64, width: Int64, themeKey: String): Document
    // Per-entry border theme; falls back to the view-wide card theme when
    // None, so hosts can color borders by card kind.
    func itemCardTheme(_: Int64): ?TranscriptCardTheme { None }
}

public class VirtualTranscriptState {
    public var scrollTop: Int64
    public var followBottom: Bool
    public var anchorId: String
    public var anchorRow: Int64

    public init(
        scrollTop!: Int64 = 0,
        followBottom!: Bool = true,
        anchorId!: String = "",
        anchorRow!: Int64 = 0
    ) {
        this.scrollTop = max(0, scrollTop)
        this.followBottom = followBottom
        this.anchorId = anchorId
        this.anchorRow = max(0, anchorRow)
    }

    public func scrollBy(delta: Int64, totalRows: Int64, viewportRows: Int64): Unit {
        let maximum = max(0, totalRows - max(1, viewportRows))
        scrollTop = clamp(scrollTop + delta, 0, maximum)
        followBottom = scrollTop >= maximum
    }

    public func home(): Unit {
        scrollTop = 0
        followBottom = false
        anchorId = ""
        anchorRow = 0
    }

    public func end(totalRows: Int64, viewportRows: Int64): Unit {
        scrollTop = max(0, totalRows - max(1, viewportRows))
        followBottom = true
    }
}

class VirtualTranscriptCacheEntry {
    var id: String = ""
    var revision: Int64 = -1
    var width: Int64 = -1
    var themeKey: String = ""
    var document: Document = Document([])
    var rows: Array<StyledLine> = []
    var measured: Bool = false
    var height: Int64 = 1
    var chrome: Bool = false
    var compactChrome: Bool = false
    var fullFrame: Bool = false
    var fillBackground: Bool = false
    var contentPadding: Spacing = Spacing.zero()
    var footerRow: Bool = false
}

class TranscriptHeightIndex {
    private var countValue: Int64 = 0
    private var base: Int64 = 1
    private let tree = ArrayList<Int64>()
    private let values = ArrayList<Int64>()

    init() { reset(0) }

    func reset(count: Int64): Unit {
        countValue = max(0, count)
        base = 1
        while (base < countValue) { base *= 2 }
        tree.clear()
        values.clear()
        for (_ in 0..base * 2) { tree.add(0) }
        for (index in 0..countValue) {
            values.add(1)
            tree[base + index] = 1
        }
        var node = base - 1
        while (node > 0) {
            tree[node] = tree[node * 2] + tree[node * 2 + 1]
            node--
        }
    }

    func value(index: Int64): Int64 {
        if (index < 0 || index >= countValue) { 0 } else { values[index] }
    }

    func update(index: Int64, height: Int64): Unit {
        if (index < 0 || index >= countValue) { return }
        let normalized = max(1, height)
        if (values[index] == normalized) { return }
        values[index] = normalized
        var node = base + index
        tree[node] = normalized
        node /= 2
        while (node > 0) {
            tree[node] = tree[node * 2] + tree[node * 2 + 1]
            node /= 2
        }
    }

    func total(): Int64 { if (tree.isEmpty()) { 0 } else { tree[1] } }

    func prefix(exclusive: Int64): Int64 {
        var left = base
        var right = base + clamp(exclusive, 0, countValue)
        var result: Int64 = 0
        while (left < right) {
            if (left % 2 == 1) {
                result += tree[left]
                left++
            }
            if (right % 2 == 1) {
                right--
                result += tree[right]
            }
            left /= 2
            right /= 2
        }
        result
    }

    func itemAt(row: Int64): Int64 {
        if (countValue == 0) { return -1 }
        var remaining = clamp(row, 0, max(0, total() - 1))
        var node: Int64 = 1
        while (node < base) {
            let left = node * 2
            if (remaining < tree[left]) {
                node = left
            } else {
                remaining -= tree[left]
                node = left + 1
            }
        }
        min(countValue - 1, node - base)
    }
}

public class VisibleRange {
    public let id: String
    public let top: Int64
    public let bottom: Int64

    public init(id: String, top: Int64, bottom: Int64) {
        this.id = id
        this.top = top
        this.bottom = bottom
    }
}

// A narrow, read-only diagnostics contract for profiling hosts. Keeping the
// counters in one snapshot avoids growing the view API for every new probe.
public class VirtualTranscriptMetrics {
    public let materialized: Int64
    public let cacheEntries: Int64
    public let measuredEntries: Int64
    public let cachedRows: Int64

    public init(
        materialized: Int64,
        cacheEntries: Int64,
        measuredEntries: Int64,
        cachedRows: Int64
    ) {
        this.materialized = materialized
        this.cacheEntries = cacheEntries
        this.measuredEntries = measuredEntries
        this.cachedRows = cachedRows
    }
}

public class VirtualTranscriptView <: Widget {
    private let source: VirtualTranscriptSource
    public let state: VirtualTranscriptState
    private let entries = ArrayList<VirtualTranscriptCacheEntry>()
    private let heights = TranscriptHeightIndex()
    private var width: Int64 = -1
    private var viewportRows: Int64 = 1
    private var themeKey: String
    private var backgroundCursor: Int64 = -1
    private let overscanViewports: Int64
    private let backgroundBatch: Int64
    private var materializedCountValue: Int64 = 0
    private var cardChrome: Bool = false
    private var unicode: Bool = true
    private var cardTheme: TranscriptCardTheme = TranscriptCardTheme()
    // Screen ranges of items rendered by the last render() call, in
    // transcript order: (itemId, topRow, bottomRow). Used by hosts for
    // hit-testing (e.g. clicking a collapsed tool card to expand it).
    public let lastVisibleRanges = ArrayList<VisibleRange>()

    public init(
        source: VirtualTranscriptSource,
        state!: VirtualTranscriptState = VirtualTranscriptState(),
        themeKey!: String = "default",
        overscanViewports!: Int64 = 2,
        backgroundBatch!: Int64 = 0
    ) {
        this.source = source
        this.state = state
        this.themeKey = themeKey
        this.overscanViewports = max(0, overscanViewports)
        this.backgroundBatch = max(0, backgroundBatch)
        syncCount()
    }

    public func setThemeKey(value: String): Unit {
        if (themeKey == value) { return }
        themeKey = value
        invalidateAllMeasurements()
    }

    public func setCardChrome(enabled: Bool): Unit {
        if (cardChrome == enabled) { return }
        cardChrome = enabled
        invalidateAllMeasurements()
    }

    // Hosts can switch the event rail to the portable ASCII form when the
    // terminal capability probe says Unicode is unavailable.
    public func setUnicode(enabled: Bool): Unit {
        if (unicode == enabled) { return }
        unicode = enabled
        invalidateAllMeasurements()
    }

    public func setCardTheme(theme: TranscriptCardTheme): Unit {
        cardTheme = theme
    }

    public func invalidateItem(id: String): Bool {
        for (index in 0..entries.size) {
            if (entries[index].id == id) {
                entries[index].measured = false
                entries[index].revision = -1
                entries[index].height = 1
                heights.update(index, 1)
                return true
            }
        }
        false
    }

    public func totalRows(): Int64 {
        syncCount()
        heights.total()
    }

    public func materializedCount(): Int64 { materializedCountValue }

    public func metrics(): VirtualTranscriptMetrics {
        var count: Int64 = 0
        var rows: Int64 = 0
        for (entry in entries where entry.measured) { count++ }
        for (entry in entries where entry.measured) { rows += entry.rows.size }
        VirtualTranscriptMetrics(
            materializedCountValue,
            entries.size,
            count,
            rows
        )
    }

    public func handle(key: KeyEvent): Bool {
        let page = max(1, viewportRows)
        match (key.code) {
            case KeyCode.Up => prepareNavigation(); state.scrollBy(-1, heights.total(), page); true
            case KeyCode.Down => prepareNavigation(); state.scrollBy(1, heights.total(), page); true
            case KeyCode.PageUp => prepareNavigation(); state.scrollBy(-page, heights.total(), page); true
            case KeyCode.PageDown => prepareNavigation(); state.scrollBy(page, heights.total(), page); true
            case KeyCode.Home => state.home(); true
            case KeyCode.End => state.end(heights.total(), page); true
            case _ => false
        }
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        syncCount()
        viewportRows = max(1, area.height)
        configureWidth(area.width)
        if (entries.isEmpty()) { return }

        var anchorIndex = heights.itemAt(state.scrollTop)
        if (!state.followBottom && state.anchorId == "") {
            captureAnchor(anchorIndex)
        }
        materializedCountValue = 0
        measureBackground()
        if (state.followBottom) {
            measureTailWindow(area.height)
            state.scrollTop = max(0, heights.total() - area.height)
            anchorIndex = heights.itemAt(state.scrollTop)
        }
        materializeWindow(area.height)
        restoreAnchor(anchorIndex)
        if (state.followBottom) {
            state.scrollTop = max(0, heights.total() - area.height)
        } else {
            state.scrollTop = clamp(
                state.scrollTop,
                0,
                max(0, heights.total() - area.height)
            )
        }

        var index = heights.itemAt(state.scrollTop)
        if (index < 0) { return }
        lastVisibleRanges.clear()
        var itemTop = heights.prefix(index)
        var y = area.y
        var skip = max(0, state.scrollTop - itemTop)
        while (index < entries.size && y < area.bottom) {
            let entry = materialize(index, area.width)
            let documentHeight = max(1, entry.height - 1)
            if (skip < documentHeight) {
                let available = min(
                    area.bottom - y,
                    documentHeight - skip
                )
                var row = skip
                var out: Int64 = 0
                let entryTheme = match (source.itemCardTheme(index)) {
                    case Some(value) => value
                    case None => cardTheme
                }
                if (entry.fullFrame) {
                    let totalRows = framedRowCount(entry)
                    let footer = source.itemFooter(index)
                    // Resolve the outer frame once for the whole card.  Body,
                    // footer, empty-output and separator rows must all reuse
                    // these absolute columns; content padding is strictly an
                    // interior concern.
                    let geometry = FullFrameGeometry(
                        area.x,
                        area.width,
                        entry.contentPadding
                    )
                    buffer.fillRect(
                        Rect(area.x, y, area.width, available),
                        style: entryTheme.borderBackground
                    )
                    while (row < totalRows && out < available) {
                        renderFullFrameRow(
                            buffer,
                            y + out,
                            row,
                            entry,
                            footer,
                            entryTheme,
                            unicode,
                            geometry
                        )
                        row++
                        out++
                    }
                } else if (entry.chrome) {
                    let totalRows = if (entry.compactChrome) { 1 } else { entry.rows.size + 2 }
                    buffer.fillRect(
                        Rect(area.x, y, area.width, available),
                        style: entryTheme.borderBackground
                    )
                    let bodyRail = if (unicode) { "│ " } else { "|  " }
                    while (row < totalRows && out < available) {
                        if (row == 0) {
                            // Left event-rail header: no right frame, no
                            // fill to the edge (OMP style).
                            // The rail itself consumes three cells (`╭─ ` or
                            // `+- `).  Reserve them before asking the host
                            // to fit the title; otherwise the final
                            // `running`, duration, or result suffix is
                            // clipped by the outer truncate call.
                            let titleRail = if (unicode) { "╭─ " } else { "+- " }
                            let title = source.itemTitleForWidth(
                                index,
                                max(1, area.width - displayWidth(titleRail))
                            )
                            buffer.setString(
                                area.x,
                                y + out,
                                truncate(titleRail + title, area.width),
                                style: entryTheme.topTitleStyle
                            )
                        } else if (row == totalRows - 1) {
                            let footer = source.itemFooter(index)
                            buffer.setString(
                                area.x,
                                y + out,
                                truncate((if (unicode) { "╰─ " } else { "+- " }) + footer, area.width),
                                style: entryTheme.borderStyle
                            )
                        } else {
                            buffer.setString(area.x, y + out, bodyRail, style: entryTheme.borderStyle)
                            renderStyledLine(buffer, area.x + (if (unicode) { 2 } else { 3 }), y + out, entry.rows[row - 1], area.width - (if (unicode) { 2 } else { 3 }))
                        }
                        row++
                        out++
                    }
                } else if (entry.fillBackground) {
                    buffer.fillRect(
                        Rect(area.x, y, area.width, available),
                        style: entryTheme.borderBackground
                    )
                    let contentStart = entry.contentPadding.top
                    let contentEnd = contentStart + entry.rows.size
                    while (row < max(1, entry.height - 1) && out < available) {
                        if (row >= contentStart && row < contentEnd) {
                            renderStyledLine(
                                buffer,
                                area.x + entry.contentPadding.left,
                                y + out,
                                entry.rows[row - contentStart],
                                max(1, area.width - entry.contentPadding.left - entry.contentPadding.right)
                            )
                        }
                        row++
                        out++
                    }
                } else {
                    while (row < entry.rows.size && out < available) {
                        renderStyledLine(buffer, area.x, y + out, entry.rows[row], area.width)
                        row++
                        out++
                    }
                }
                lastVisibleRanges.add(VisibleRange(
                    entry.id,
                    y,
                    y + available
                ))
                y += available
            }
            if (y < area.bottom && skip <= documentHeight) { y++ }
            skip = 0
            index++
        }
    }

    private func syncCount(): Unit {
        let count = max(0, source.size())
        if (count == entries.size) { return }
        let previous = ArrayList<Int64>()
        for (entry in entries) { previous.add(entry.height) }
        while (entries.size < count) {
            entries.add(VirtualTranscriptCacheEntry())
        }
        while (entries.size > count) {
            entries.remove(at: entries.size - 1)
        }
        heights.reset(count)
        for (index in 0..min(previous.size, count)) {
            heights.update(index, previous[index])
        }
        backgroundCursor = count - 1
    }

    private func configureWidth(nextWidth: Int64): Unit {
        if (width == nextWidth) { return }
        width = nextWidth
        invalidateAllMeasurements()
    }

    private func invalidateAllMeasurements(): Unit {
        for (index in 0..entries.size) {
            entries[index].measured = false
            entries[index].height = 1
            heights.update(index, 1)
        }
        backgroundCursor = entries.size - 1
    }

    private func captureAnchor(index: Int64): Unit {
        if (index < 0 || index >= entries.size) { return }
        state.anchorId = source.itemId(index)
        state.anchorRow = max(0, state.scrollTop - heights.prefix(index))
    }

    private func prepareNavigation(): Unit {
        state.anchorId = ""
        state.anchorRow = 0
    }

    private func restoreAnchor(fallbackIndex: Int64): Unit {
        if (state.followBottom || state.anchorId == "") { return }
        var index = fallbackIndex
        if (index < 0 || index >= entries.size ||
            source.itemId(index) != state.anchorId) {
            index = findItem(state.anchorId)
        }
        if (index >= 0) {
            state.scrollTop = heights.prefix(index) + min(
                state.anchorRow,
                max(0, heights.value(index) - 1)
            )
        }
    }

    private func findItem(id: String): Int64 {
        for (index in 0..entries.size) {
            if (source.itemId(index) == id) { return index }
        }
        -1
    }

    private func measureBackground(): Unit {
        var remaining = backgroundBatch
        while (remaining > 0 && backgroundCursor >= 0) {
            let _ = materialize(backgroundCursor, width)
            backgroundCursor--
            remaining--
        }
    }

    private func measureTailWindow(height: Int64): Unit {
        let target = max(1, height * (overscanViewports + 1))
        var measuredRows: Int64 = 0
        var index = entries.size - 1
        while (index >= 0 && measuredRows < target) {
            let entry = materialize(index, width)
            measuredRows += entry.height
            index--
        }
    }

    private func materializeWindow(height: Int64): Unit {
        let overscan = max(0, height * overscanViewports)
        let from = max(0, state.scrollTop - overscan)
        let to = min(heights.total(), state.scrollTop + height + overscan)
        var index = heights.itemAt(from)
        if (index < 0) { return }
        while (index < entries.size && heights.prefix(index) < to) {
            let _ = materialize(index, width)
            index++
        }
    }

    private func materialize(
        index: Int64,
        itemWidth: Int64
    ): VirtualTranscriptCacheEntry {
        let entry = entries[index]
        let id = source.itemId(index)
        let revision = source.revision(index)
        if (!entry.measured || entry.id != id ||
            entry.revision != revision || entry.width != itemWidth ||
            entry.themeKey != themeKey) {
            entry.id = id
            entry.revision = revision
            entry.width = itemWidth
            entry.themeKey = themeKey
            let usesChrome = cardChrome && source.itemUsesCardChrome(index)
            let entryTheme = match (source.itemCardTheme(index)) {
                case Some(value) => value
                case None => cardTheme
            }
            entry.chrome = usesChrome
            entry.compactChrome = usesChrome && source.itemUsesCompactCardChrome(index)
            entry.fullFrame = usesChrome && entryTheme.fullFrame
            entry.fillBackground = !usesChrome && entryTheme.fillBackground
            entry.contentPadding = entryTheme.contentPadding
            entry.footerRow = entry.fullFrame && source.itemFooter(index) != ""
            let chromeColumns = if (entry.fullFrame) {
                2
            } else if (usesChrome) {
                2
            } else {
                0
            }
            let contentWidth = max(
                1,
                itemWidth - chromeColumns - entry.contentPadding.left - entry.contentPadding.right
            )
            entry.document = source.document(index, contentWidth, themeKey)
            entry.rows = DocumentView(entry.document).layoutRows(contentWidth)
            if (entry.fullFrame) {
                entry.height = framedRowCount(entry) + 1
            } else if (usesChrome) {
                entry.height = if (entry.compactChrome) { 2 } else { max(1, entry.rows.size) + 3 }
            } else if (entry.fillBackground) {
                entry.height = entry.contentPadding.top + max(1, entry.rows.size) + entry.contentPadding.bottom + 1
            } else {
                entry.height = max(1, entry.rows.size) + 1
            }
            entry.measured = true
            heights.update(index, entry.height)
            materializedCountValue++
        }
        entry
    }
}

func framedRowCount(entry: VirtualTranscriptCacheEntry): Int64 {
    2 + entry.contentPadding.top + entry.rows.size + entry.contentPadding.bottom + if (entry.footerRow) { 1 } else { 0 }
}

class FullFrameGeometry {
    let leftBorderX: Int64
    let rightBorderX: Int64
    let contentX: Int64
    let contentWidth: Int64
    let cardWidth: Int64

    init(x: Int64, width: Int64, padding: Spacing) {
        cardWidth = max(0, width)
        leftBorderX = x
        rightBorderX = x + max(0, cardWidth - 1)
        contentX = x + 1 + padding.left
        contentWidth = max(
            0,
            cardWidth - 2 - padding.left - padding.right
        )
    }
}

func renderFullFrameRow(
    buffer: Buffer,
    y: Int64,
    row: Int64,
    entry: VirtualTranscriptCacheEntry,
    footer: String,
    theme: TranscriptCardTheme,
    unicode: Bool,
    geometry: FullFrameGeometry
): Unit {
    let x = geometry.leftBorderX
    let width = geometry.cardWidth
    if (width <= 0) { return }
    let horizontal = if (unicode) { "─" } else { "-" }
    let topLeft = if (unicode) { "╭" } else { "+" }
    let topRight = if (unicode) { "╮" } else { "+" }
    let bottomLeft = if (unicode) { "╰" } else { "+" }
    let bottomRight = if (unicode) { "╯" } else { "+" }
    let vertical = if (unicode) { "│" } else { "|" }
    let separatorLeft = if (unicode) { "├" } else { "+" }
    let separatorRight = if (unicode) { "┤" } else { "+" }
    let totalRows = framedRowCount(entry)
    if (row == 0) {
        renderFrameRule(buffer, x, y, width, topLeft, topRight, horizontal, theme.borderStyle)
        return
    }
    if (row == totalRows - 1) {
        renderFrameRule(buffer, x, y, width, bottomLeft, bottomRight, horizontal, theme.borderStyle)
        return
    }
    if (width == 1) {
        buffer.setString(geometry.leftBorderX, y, vertical, style: theme.borderStyle)
        return
    }
    let contentStart = 1 + entry.contentPadding.top
    let contentEnd = contentStart + entry.rows.size
    if (row >= contentStart && row < contentEnd) {
        let line = entry.rows[row - contentStart]
        if (line.horizontalRule) {
            renderFrameRule(buffer, x, y, width, separatorLeft, separatorRight, horizontal, theme.borderStyle)
            renderFrameRuleLabel(buffer, x, y, width, line.ruleLabel, theme.borderStyle)
            return
        } else {
            if (geometry.contentWidth > 0) {
                renderStyledLine(
                    buffer,
                    geometry.contentX,
                    y,
                    line,
                    geometry.contentWidth
                )
            }
        }
    } else if (entry.footerRow && row == totalRows - 2 && geometry.contentWidth > 0) {
        buffer.setString(
            geometry.contentX,
            y,
            truncate(footer, geometry.contentWidth),
            style: theme.mutedStyle
        )
    }
    // Draw the outer sides last so neither styled content, a footer update,
    // nor an empty-output row can erase or shift the frame columns.
    buffer.setString(geometry.leftBorderX, y, vertical, style: theme.borderStyle)
    buffer.setString(geometry.rightBorderX, y, vertical, style: theme.borderStyle)
}

func renderFrameRule(
    buffer: Buffer,
    x: Int64,
    y: Int64,
    width: Int64,
    left: String,
    right: String,
    horizontal: String,
    style: Style
): Unit {
    if (width <= 0) { return }
    if (width == 1) {
        buffer.setString(x, y, left, style: style)
        return
    }
    buffer.setString(x, y, left + repeat(horizontal, max(0, width - 2)) + right, style: style)
}

func renderFrameRuleLabel(
    buffer: Buffer,
    x: Int64,
    y: Int64,
    width: Int64,
    label: Array<RichSpan>,
    borderStyle: Style
): Unit {
    let textWidth = displayWidth(spansText(label))
    if (textWidth <= 0 || width < 7) { return }
    let available = max(1, width - 6)
    buffer.setString(x + 3, y, " ", style: borderStyle)
    let rendered = StyledLine(label)
    renderStyledLine(buffer, x + 4, y, rendered, available)
    let shown = min(textWidth, available)
    if (x + 4 + shown < x + width - 1) {
        buffer.setString(x + 4 + shown, y, " ", style: borderStyle)
    }
}
