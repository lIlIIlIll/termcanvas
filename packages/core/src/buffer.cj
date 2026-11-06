package core

import std.collection.*

public enum CellKind {
    | Normal
    | WideLead
    | WideCont
}

public struct Cell <: Equatable<Cell> {
    public var symbol: String = " "
    public var style: Style = Style.default()
    public var kind: CellKind = CellKind.Normal

    public init() {}

    public init(symbol: String, style!: Style = Style.default(), kind!: CellKind = CellKind.Normal) {
        this.symbol = symbol
        this.style = style
        this.kind = kind
    }

    public operator func ==(other: Cell): Bool {
        symbol == other.symbol && style == other.style && sameCellKind(kind, other.kind)
    }
}

public class Buffer {
    public let area: Rect
    private let cells: Array<Cell>
    private let media = ArrayList<MediaPlacement>()
    private var capabilitiesValue: TerminalCapabilities = TerminalCapabilities()
    private var themeValue: ?Theme = None
    private var adaptedThemeValue: ?Theme = None
    private var parentThemeValue: ?Theme = None
    // A render-context snapshot may outlive the parent scope that created it.
    private var inheritedParentThemeValue: ?Theme = None
    private var textWidthOptionsValue: TextWidthOptions = TextWidthOptions()
    // Width changes do not rewrite existing cells. A later blit must verify
    // potentially stale ambiguous-width glyphs before copying them.
    private var widthRevalidationNeeded: Bool = false
    private var writeClip: ?DirtyRects = None
    private var canvasClip: ?Rect = None
    private var scopedStyleOverride: ?StyleOverride = None
    // Step-0 diagnostics are opt-in and reset for each render closure. These
    // counters never participate in clipping, layout, or cell equality.
    private var workMetricsEnabled: Bool = false
    private var cellAttemptsValue: Int64 = 0
    private var cellWritesValue: Int64 = 0

    public init(area: Rect) {
        this.area = area
        this.cells = Array<Cell>(area.width * area.height, repeat: Cell())
    }

    public func capabilities(): TerminalCapabilities { capabilitiesValue }

    public func setCapabilities(capabilities: TerminalCapabilities): Unit {
        capabilitiesValue = capabilities
        refreshAdaptedTheme()
    }

    /** 返回应用为此缓冲区设置的主题，None 表示沿用组件的默认样式。 */
    public func theme(): ?Theme { themeValue }

    /** 设置后续组件绘制使用的应用主题；已有单元格不会自动重绘。 */
    public func setTheme(theme: ?Theme): Unit {
        themeValue = theme
        inheritedParentThemeValue = None
        refreshAdaptedTheme()
    }

    private func refreshAdaptedTheme(): Unit {
        adaptedThemeValue = match (themeValue) {
            case Some(value) => Some(value.adapted(capabilitiesValue))
            case None => None
        }
    }

    /** 显式组件主题优先，其次为嵌套父主题，最后为适配终端能力的应用主题。 */
    public func resolveTheme(explicit: ?Theme): ?Theme {
        match (explicit) {
            case Some(value) => Some(value)
            case None => match (parentThemeValue) {
                case Some(value) => Some(value)
                case None => match (inheritedParentThemeValue) {
                    case Some(value) => Some(value)
                    case None => adaptedThemeValue
                }
            }
        }
    }

    /** 在同步绘制闭包内临时提供父主题；子组件显式主题优先，None 保留已有父主题。
     * 闭包返回或抛出异常时恢复原作用域；同一缓冲区不得在此期间由其他线程使用。
     */
    public func withParentTheme(explicit: ?Theme, draw: () -> Unit): Unit {
        if (explicit.isNone()) { draw(); return }
        let previous = parentThemeValue
        parentThemeValue = explicit
        try {
            draw()
        } finally {
            parentThemeValue = previous
        }
    }

    // Capture visual inputs independently of paint state, clips and media.
    func inheritVisualContext(source: Buffer): Unit {
        capabilitiesValue = source.capabilitiesValue
        themeValue = source.themeValue
        adaptedThemeValue = source.adaptedThemeValue
        textWidthOptionsValue = source.textWidthOptionsValue
        inheritedParentThemeValue = match (source.parentThemeValue) {
            case Some(value) => Some(value)
            case None => source.inheritedParentThemeValue
        }
    }

    /** 返回当前文本的显示宽度策略。 */
    public func textWidthOptions(): TextWidthOptions { textWidthOptionsValue }

    /** 设置后续绘制的宽度策略；现有单元格不会重新排版。 */
    public func setTextWidthOptions(options: TextWidthOptions): Unit {
        let changed = usesWideAmbiguous(options) != usesWideAmbiguous(textWidthOptionsValue)
        textWidthOptionsValue = options
        if (changed) { widthRevalidationNeeded = hasStaleWidthCells(area) }
    }

    public func clear(style!: Style = Style.default()): Unit {
        // A widget-scoped clear must remain within that widget's clip and
        // the current frame's dirty region, just like other widget writes.
        if (scopedStyleOverride.isSome()) { fill(area, style: style); return }
        let blank = Cell(" ", style: style)
        for (i in 0..cells.size) {
            cells[i] = blank
        }
        widthRevalidationNeeded = false
    }

    func reset(style!: Style = Style.default()): Unit {
        writeClip = None
        clear(style: style)
        while (media.size > 0) {
            media.remove(at: 0)
        }
    }

    func setWriteClip(clip: ?DirtyRects): Unit {
        writeClip = clip
    }

    func withCanvasClip(clip: Rect, draw: () -> Unit): Unit {
        let previous = canvasClip
        if (clip == area) { draw(); return }
        canvasClip = Some(match (previous) { case Some(area) => intersect(area, clip); case None => clip })
        try {
            draw()
        } finally {
            canvasClip = previous
        }
    }

    // Overrides apply to writes, not to pre-existing cells. Nested scopes
    // merge per attribute so a child's choice wins over its parent's.
    func withStyleOverride(value: StyleOverride, draw: () -> Unit): Unit {
        let previous = scopedStyleOverride
        scopedStyleOverride = Some(match (previous) {
            case Some(outer) => mergeStyleOverride(outer, value)
            case None => value
        })
        try {
            draw()
        } finally {
            scopedStyleOverride = previous
        }
    }

    private func scopedCell(cell: Cell): Cell {
        match (scopedStyleOverride) {
            case Some(value) =>
                var result = cell
                result.style = value.apply(cell.style)
                result
            case None => cell
        }
    }

    func beginWorkMetrics(enabled: Bool): Unit {
        workMetricsEnabled = enabled
        cellAttemptsValue = 0
        cellWritesValue = 0
    }

    func cellAttempts(): Int64 { cellAttemptsValue }

    func cellWrites(): Int64 { cellWritesValue }

    // Package-internal paint pruning hook. Widgets may use the Terminal's
    // existing physical write clip to skip whole derived paint units; this
    // does not create or widen damage and is never a correctness fallback.
    func intersectsWriteClip(area: Rect): Bool {
        match (writeClip) {
            case Some(clip) => clip.intersects(area)
            case None => true
        }
    }

    func clearDirty(rects: DirtyRects, style!: Style = Style.default()): Unit {
        let blank = Cell(" ", style: style)
        for (rect in rects.rects()) {
            let target = intersect(area, rect)
            for (y in target.y..target.bottom) {
                for (x in target.x..target.right) {
                    setCellRaw(x, y, blank)
                }
            }
        }
    }

    public func indexOf(x: Int64, y: Int64): ?Int64 {
        if (x < area.x || y < area.y || x >= area.right || y >= area.bottom) {
            return None
        }
        return (y - area.y) * area.width + (x - area.x)
    }

    public func setCell(x: Int64, y: Int64, cell: Cell): Unit {
        if (workMetricsEnabled) { cellAttemptsValue++ }
        if (!isWritable(x, y)) { return }
        if (let Some(index) <- indexOf(x, y)) {
            let repairLeft = isWideContinuation(cells[index]) && x > area.x
            let repairRight = !isWideContinuation(cell) && x + 1 < area.right && isWideContinuation(getCell(x + 1, y))
            if ((repairLeft && !isWritable(x - 1, y)) || (repairRight && !isWritable(x + 1, y))) { return }
            if (repairLeft) {
                setCellRaw(x - 1, y, scopedCell(Cell(" ", style: cells[index].style)))
            }
            if (repairRight) {
                setCellRaw(x + 1, y, scopedCell(Cell(" ")))
            }
            cells[index] = scopedCell(cell)
            if (workMetricsEnabled) { cellWritesValue++ }
        }
    }

    private func setCellRaw(x: Int64, y: Int64, cell: Cell): Unit {
        if (workMetricsEnabled) { cellAttemptsValue++ }
        if (!isWritable(x, y)) { return }
        if (let Some(index) <- indexOf(x, y)) {
            cells[index] = cell
            if (workMetricsEnabled) { cellWritesValue++ }
        }
    }

    public func getCell(x: Int64, y: Int64): Cell {
        if (let Some(index) <- indexOf(x, y)) {
            return cells[index]
        }
        Cell()
    }

    public func fill(area: Rect, cell: Cell): Unit {
        let physical = intersect(this.area, area)
        let target = match (canvasClip) { case Some(clip) => intersect(physical, clip); case None => physical }
        if (target.width <= 0 || target.height <= 0) { return }
        let styled = scopedCell(cell)
        match (writeClip) {
            case Some(clip) =>
                for (rect in clip.rects()) {
                    let clipped = intersect(target, rect)
                    fillUnclipped(clipped, styled)
                }
                return
            case None => ()
        }
        fillUnclipped(target, styled)
    }

    private func fillUnclipped(target: Rect, cell: Cell): Unit {
        if (target.width <= 0 || target.height <= 0) { return }
        if (!isSingleWidthNormal(cell)) {
            for (y in target.y..target.bottom) {
                for (x in target.x..target.right) {
                    setCell(x, y, cell)
                }
            }
            return
        }
        let boundaryBlank = Cell(" ", style: cell.style)
        for (y in target.y..target.bottom) {
            var left = target.x
            var right = target.right
            if (target.x > this.area.x && isWideContinuation(getCell(target.x, y))) {
                if (isWritable(target.x - 1, y)) { setCellRaw(target.x - 1, y, boundaryBlank) }
                else { left++ }
            }
            if (target.right < this.area.right && isWideContinuation(getCell(target.right, y))) {
                if (isWritable(target.right, y)) { setCellRaw(target.right, y, boundaryBlank) }
                else { right-- }
            }
            for (x in left..right) {
                setCellRaw(x, y, cell)
            }
        }
    }

    public func fill(area: Rect, style!: Style = Style.default()): Unit {
        let blank = Cell(" ", style: style)
        fill(area, blank)
    }

    public func fillRect(x: Int64, y: Int64, width: Int64, height: Int64, style!: Style = Style.default()): Unit {
        fill(Rect(x, y, width, height), style: style)
    }

    public func fillLine(y: Int64, x: Int64, width: Int64, cell: Cell): Unit {
        if (width <= 0) { return }
        fill(Rect(x, y, width, 1), cell)
    }

    public func fillLine(y: Int64, x: Int64, width: Int64, style!: Style = Style.default()): Unit {
        fillLine(y, x, width, Cell(" ", style: style))
    }

    public func hline(x: Int64, y: Int64, width: Int64, symbol: String, style: Style): Unit {
        if (width <= 0 || symbol == "") { return }
        let target = intersect(this.area, Rect(x, y, width, 1))
        if (target.width <= 0) { return }
        if (symbol == " ") {
            fillLine(target.y, target.x, target.width, style: style)
            return
        }

        let symbolWidth = graphemeDisplayWidth(symbol, options: textWidthOptionsValue)
        if (symbolWidth <= 0) { return }
        if (symbolWidth == 1) {
            for (cx in target.x..target.right) {
                setCell(cx, target.y, Cell(symbol, style: style))
            }
            return
        }

        var cx = target.x
        while (cx + symbolWidth <= target.right) {
            setString(cx, target.y, symbol, style: style)
            cx += symbolWidth
        }
    }

    public func hline(x: Int64, y: Int64, width: Int64, style!: Style = Style.default()): Unit {
        hline(x, y, width, "-", style)
    }

    public func vline(x: Int64, y: Int64, height: Int64, symbol: String, style: Style): Unit {
        if (height <= 0 || symbol == "") { return }
        let target = intersect(this.area, Rect(x, y, 1, height))
        if (target.height <= 0) { return }
        if (symbol == " ") {
            fill(target, style: style)
            return
        }

        let symbolWidth = graphemeDisplayWidth(symbol, options: textWidthOptionsValue)
        if (symbolWidth <= 0) { return }
        if (symbolWidth == 1) {
            for (cy in target.y..target.bottom) {
                setCell(target.x, cy, Cell(symbol, style: style))
            }
            return
        }

        if (target.x + symbolWidth > this.area.right) { return }
        for (cy in target.y..target.bottom) {
            setString(target.x, cy, symbol, style: style)
        }
    }

    public func vline(x: Int64, y: Int64, height: Int64, style!: Style = Style.default()): Unit {
        vline(x, y, height, "|", style)
    }

    public func writeAsciiSpan(x: Int64, y: Int64, text: String, style!: Style = Style.default()): Bool {
        let bytes = unsafe { text.rawData() }
        if (!isPrintableAscii(bytes)) {
            return false
        }
        writeAsciiSpanUnchecked(x, y, text, style: style)
        true
    }

    public func writeAsciiSpanUnchecked(x: Int64, y: Int64, text: String, style!: Style = Style.default()): Unit {
        let bytes = unsafe { text.rawData() }
        setAsciiString(x, y, bytes, style)
    }

    func fillRect(area: Rect, style!: Style = Style.default()): Unit {
        fill(area, style: style)
    }

    public func setString(x: Int64, y: Int64, text: String, style!: Style = Style.default()): Unit {
        let _ = writeString(x, y, text, 0, false, style)
    }

    func writeStringClipped(
        x: Int64,
        y: Int64,
        text: String,
        maxWidth!: Int64,
        style!: Style = Style.default()
    ): Int64 {
        writeString(x, y, text, maxWidth, true, style)
    }

    private func writeString(
        x: Int64,
        y: Int64,
        text: String,
        maxWidth: Int64,
        bounded: Bool,
        style: Style
    ): Int64 {
        if (text.isEmpty() || (bounded && maxWidth <= 0) || (!bounded && x >= area.right)) {
            return 0
        }
        let bytes = unsafe { text.rawData() }
        if (isPrintableAscii(bytes)) {
            let count = if (bounded) { min(bytes.size, maxWidth) } else { bytes.size }
            setAsciiRange(x, y, bytes, 0, count, style)
            return count
        }

        var cx = x
        var consumed: Int64 = 0
        var offset: Int64 = 0
        while (offset < bytes.size &&
               ((bounded && consumed < maxWidth) || (!bounded && cx < area.right))) {
            // Unicode UI chrome commonly prefixes an otherwise ASCII line
            // (for example `╭─ ✓ Run cargo test`).  Running the full
            // grapheme-break state machine for every trailing ASCII byte is
            // needlessly expensive while scrolling.  Flush printable ASCII
            // runs in bulk, retaining the last byte before a Unicode code
            // point so an ASCII base plus a combining mark still forms one
            // grapheme cluster.
            if (bytes[offset] >= 0x20u8 && bytes[offset] < 0x7Fu8) {
                var runEnd = offset + 1
                while (runEnd < bytes.size &&
                       bytes[runEnd] >= 0x20u8 && bytes[runEnd] < 0x7Fu8) {
                    runEnd++
                }
                let safeEnd = if (runEnd < bytes.size) {
                    max(offset, runEnd - 1)
                } else {
                    runEnd
                }
                if (safeEnd > offset) {
                    let available = safeEnd - offset
                    let asciiCount = if (bounded) {
                        min(available, maxWidth - consumed)
                    } else {
                        available
                    }
                    let asciiEnd = offset + asciiCount
                    setAsciiRange(cx, y, bytes, offset, asciiEnd, style)
                    consumed += asciiCount
                    cx = advanceCoordinate(cx, asciiCount)
                    offset = asciiEnd
                    continue
                }
            }
            let next = nextGraphemeOffset(text, offset)
            let symbol = text[offset..next]
            let width = graphemeDisplayWidth(symbol, options: textWidthOptionsValue)
            if (width > 0) {
                if (bounded && width > maxWidth - consumed) {
                    break
                }
                let fitsPhysical = cx >= area.x && cx < area.right && (width != 2 || cx + 1 < area.right)
                if (!bounded && width == 2 && cx >= area.x && !fitsPhysical) {
                    break
                }
                if (fitsPhysical) {
                    if (width == 2) {
                        writeCellGroup(cx, y, Cell(symbol, style: style, kind: CellKind.WideLead), 2)
                    } else {
                        setCell(cx, y, Cell(symbol, style: style))
                    }
                }
                consumed += width
                cx = advanceCoordinate(cx, width)
            }
            offset = next
        }
        consumed
    }

    private func advanceCoordinate(value: Int64, amount: Int64): Int64 {
        if (amount > 0 && value > Int64.Max - amount) { return Int64.Max }
        value + amount
    }

    private func setAsciiString(x: Int64, y: Int64, bytes: Array<UInt8>, style: Style): Unit {
        setAsciiRange(x, y, bytes, 0, bytes.size, style)
    }

    private func setAsciiRange(
        x: Int64,
        y: Int64,
        bytes: Array<UInt8>,
        start: Int64,
        end: Int64,
        style: Style
    ): Unit {
        var cx = x
        var offset = start
        while (offset < end && cx < area.right) {
            setCell(cx, y, Cell(asciiByteToString(bytes[offset]), style: style))
            cx++
            offset++
        }
    }

    public func resize(area: Rect): Buffer {
        let next = Buffer(area)
        next.inheritVisualContext(this)
        let overlap = intersect(this.area, area)
        next.blitFrom(this, overlap, overlap.x, overlap.y)
        next.widthRevalidationNeeded = widthRevalidationNeeded
        next
    }

    public func copy(): Buffer {
        let next = Buffer(area)
        next.inheritVisualContext(this)
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                next.setCell(x, y, getCell(x, y))
            }
        }
        for (placement in media) {
            next.addMedia(placement)
        }
        next.widthRevalidationNeeded = widthRevalidationNeeded
        next
    }

    // Copy normalized cells, blanking a wide glyph cut by either boundary.
    // The target origin corresponds to the requested sourceArea origin,
    // including when the source rectangle is clipped by the source Buffer.
    // Existing destination glyphs are repaired as a group, as with setString.
    /** 将来源区域的单元格复制到目标位置；在边界截断宽字符时以空白处理被截断部分，并成组修复目标中原有的宽字符。
     * 非空来源区域的宽度策略与目标不同时，或来源切换策略后仍有过时字符时，在写入前抛出 IllegalArgumentException。
     */
    public func blitFrom(source: Buffer, sourceArea: Rect, targetX: Int64, targetY: Int64): Unit {
        blitCells(source, sourceArea, targetX, targetY, true)
    }

    // Ignore the frame's dirty rectangle for a caller that has already
    // constrained the destination. Physical and Canvas bounds still apply.
    /** 将来源区域的单元格复制到目标位置，忽略帧的脏矩形限制；物理边界和画布边界仍然生效。调用方需自行约束目标区域。
     * 与 blitFrom 一样检查宽度策略与过时字符，并在写入前报告不兼容。
     */
    public func blitFromUnchecked(source: Buffer, sourceArea: Rect, targetX: Int64, targetY: Int64): Unit {
        blitCells(source, sourceArea, targetX, targetY, false)
    }

    private func blitCells(source: Buffer, sourceArea: Rect, targetX: Int64, targetY: Int64, respectClip: Bool): Unit {
        let sourceClip = intersect(source.area, sourceArea)
        if (sourceClip.width <= 0 || sourceClip.height <= 0) { return }
        if (usesWideAmbiguous(source.textWidthOptionsValue) != usesWideAmbiguous(textWidthOptionsValue)) {
            throw IllegalArgumentException("Cannot blit buffers with different text width policies")
        }
        if (source.widthRevalidationNeeded) {
            if (source.hasStaleWidthCells(sourceClip)) {
                throw IllegalArgumentException("Cannot blit stale cells after a text width policy change; redraw the source")
            }
            if (sourceClip == source.area) { source.widthRevalidationNeeded = false }
        }
        let clippedTargetX = advanceCoordinate(targetX, sourceClip.x - sourceArea.x)
        let clippedTargetY = advanceCoordinate(targetY, sourceClip.y - sourceArea.y)
        // Snapshot before writing, including when source and destination are
        // the same Buffer and the rectangles overlap.
        let copied = ArrayList<Cell>()
        for (y in sourceClip.y..sourceClip.bottom) {
            for (x in sourceClip.x..sourceClip.right) { copied.add(source.getCell(x, y)) }
        }
        let previousClip = writeClip
        if (!respectClip) { writeClip = None }
        try {
            for (row in 0..sourceClip.height) {
                let y = advanceCoordinate(clippedTargetY, row)
                var column: Int64 = 0
                while (column < sourceClip.width) {
                    let x = advanceCoordinate(clippedTargetX, column)
                    let cell = copied[row * sourceClip.width + column]
                    let lead = match (cell.kind) { case CellKind.WideLead => true; case _ => false }
                    let pair = lead && column + 1 < sourceClip.width &&
                        isWideContinuation(copied[row * sourceClip.width + column + 1])
                    if (pair && x < Int64.Max && isWritable(x, y) && isWritable(x + 1, y)) {
                        writeCellGroup(x, y, cell, 2)
                        column += 2
                    } else {
                        let single = if (lead || isWideContinuation(cell)) { Cell(" ", style: cell.style) } else { cell }
                        writeCellGroup(x, y, single, 1)
                        column++
                    }
                }
            }
        } finally {
            writeClip = previousClip
        }
    }

    // Only used after a policy change; normal blits keep their existing fast path.
    private func hasStaleWidthCells(region: Rect): Bool {
        let narrow = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Narrow)
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let currentWide = usesWideAmbiguous(textWidthOptionsValue)
        for (y in region.y..region.bottom) {
            for (x in region.x..region.right) {
                let cell = getCell(x, y)
                let candidate = match (cell.kind) {
                    case CellKind.WideCont => if (x > area.x) { getCell(x - 1, y) } else { cell }
                    case _ => cell
                }
                let bytes = unsafe { candidate.symbol.rawData() }
                if (bytes.size == 0 || bytes[0] < 0x80u8) { continue }
                let narrowWidth = graphemeDisplayWidth(candidate.symbol, options: narrow)
                let wideWidth = graphemeDisplayWidth(candidate.symbol, options: wide)
                if (narrowWidth == wideWidth) { continue }
                let actualWide = match (candidate.kind) { case CellKind.WideLead => true; case _ => false }
                if (actualWide != currentWide) { return true }
            }
        }
        false
    }

    // Replace the entire glyph footprint, including old pairs crossed by
    // either edge. Preflight all repairs before modifying any cell.
    private func writeCellGroup(x: Int64, y: Int64, cell: Cell, width: Int64): Unit {
        if (!canWriteGroup(x, y, width)) { return }
        let styled = scopedCell(cell)
        let leftPair = x > area.x && isWideContinuation(getCell(x, y))
        let right = advanceCoordinate(x, width)
        let rightPair = right < area.right && isWideContinuation(getCell(right, y))
        if (leftPair) { setCellRaw(x - 1, y, Cell(" ", style: styled.style)) }
        if (rightPair) { setCellRaw(right, y, Cell(" ", style: styled.style)) }
        setCellRaw(x, y, styled)
        if (width == 2) {
            setCellRaw(x + 1, y, Cell("", style: styled.style, kind: CellKind.WideCont))
        }
    }

    public func diff(previous: Buffer): Array<DrawOp> {
        let ops = ArrayList<DrawOp>()
        for (y in area.y..area.bottom) {
            for (x in area.x..area.right) {
                let cell = getCell(x, y)
                if (previous.area != area || previous.getCell(x, y) != cell) {
                    ops.add(DrawOp(x, y, cell))
                }
            }
        }
        ops.toArray()
    }

    public func addMedia(placement: MediaPlacement): Unit {
        media.add(placement)
    }

    public func mediaPlacements(): Array<MediaPlacement> {
        media.toArray()
    }

    private func isWritable(x: Int64, y: Int64): Bool {
        if (x < area.x || x >= area.right || y < area.y || y >= area.bottom) { return false }
        if (let Some(clip) <- canvasClip) {
            if (x < clip.x || x >= clip.right || y < clip.y || y >= clip.bottom) { return false }
        }
        match (writeClip) {
            case Some(clip) => clip.intersectsCell(x, y)
            case None => true
        }
    }

    private func canWriteGroup(x: Int64, y: Int64, width: Int64): Bool {
        if (!isWritable(x, y) || !isWritable(advanceCoordinate(x, width - 1), y)) { return false }
        // If an existing glyph straddles the clip, leave it intact until both
        // cells can be repainted together.
        if (x > area.x && isWideContinuation(getCell(x, y)) && !isWritable(x - 1, y)) { return false }
        let right = advanceCoordinate(x, width)
        if (right < area.right && isWideContinuation(getCell(right, y)) && !isWritable(right, y)) { return false }
        true
    }
}

func sameCellKind(left: CellKind, right: CellKind): Bool {
    match (left) {
        case CellKind.Normal =>
            match (right) {
                case CellKind.Normal => true
                case _ => false
            }
        case CellKind.WideLead =>
            match (right) {
                case CellKind.WideLead => true
                case _ => false
            }
        case CellKind.WideCont =>
            match (right) {
                case CellKind.WideCont => true
                case _ => false
            }
    }
}

func isWideContinuation(cell: Cell): Bool {
    match (cell.kind) {
        case CellKind.WideCont => true
        case _ => cell.symbol == ""
    }
}

func isSingleWidthNormal(cell: Cell): Bool {
    match (cell.kind) {
        case CellKind.Normal => cell.symbol != "" && graphemeDisplayWidth(cell.symbol) == 1
        case _ => false
    }
}

func isPrintableAscii(bytes: Array<UInt8>): Bool {
    for (byte in bytes) {
        if (byte < 0x20 || byte > 0x7E) {
            return false
        }
    }
    true
}

func asciiByteToString(byte: UInt8): String {
    unsafe { String.fromUtf8Unchecked([byte]) }
}

public struct DrawOp {
    public let x: Int64
    public let y: Int64
    public let cell: Cell

    public init(x: Int64, y: Int64, cell: Cell) {
        this.x = x
        this.y = y
        this.cell = cell
    }
}
