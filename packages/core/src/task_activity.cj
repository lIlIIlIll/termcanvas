package core

/** 表示任务或子任务的显示状态。
 */
public enum TaskStatus {
    /** 尚未开始。 */
    | Pending
    /** 已排队。 */
    | Queued
    /** 正在运行。 */
    | Running
    /** 已完成。 */
    | Done
    /** 已失败。 */
    | Failed
    /** 已取消。 */
    | Cancelled
}

/** 选择逐项状态或完成数与总数作为任务进度。
 */
public enum TaskProgress {
    /** 按顺序显示各子任务的独立状态。
     */
    | Items(Array<TaskStatus>)
    /** 显示完成数与总数，越界数值在 TaskActivity 创建时限制到有效范围。
     */
    | Counts(Int64, Int64)
}

/** 选择任务的单行摘要或多行详情布局。
 */
public enum TaskActivityLayout {
    /** 单行显示任务和摘要。
     */
    | Compact
    /** 显示任务行、可选进度行和可选详情行。
     */
    | Expanded
}

/** 保存一个任务的显示数据；逐项进度在构造时复制，不随调用方数组变化。
 */
public class TaskActivity {
    /** 任务标题。
     */
    public let title: String
    /** 当前任务状态。
     */
    public let status: TaskStatus
    /** 可选的任务标识。
     */
    public let id: String
    /** 可选的标题前缀。
     */
    public let prefix: String
    /** 紧凑布局中的自定义状态文字；空串使用状态的英文名称。
     */
    public let statusText: String
    /** 调用方提供的耗时文字。
     */
    public let duration: String
    /** 可选详情文字。
     */
    public let detail: String
    /** 子任务进度行的可选标题。
     */
    public let progressLabel: String
    private let progressSnapshot: ?TaskProgress

    /** 创建任务显示数据；省略进度时不绘制进度行。
     */
    public init(
        title: String,
        status!: TaskStatus = TaskStatus.Pending,
        id!: String = "",
        prefix!: String = "",
        statusText!: String = "",
        duration!: String = "",
        detail!: String = "",
        progressLabel!: String = "",
        progress!: ?TaskProgress = None
    ) {
        this.title = title
        this.status = status
        this.id = id
        this.prefix = prefix
        this.statusText = statusText
        this.duration = duration
        this.detail = detail
        this.progressLabel = progressLabel
        this.progressSnapshot = match (progress) {
            case Some(TaskProgress.Items(items)) =>
                Some(TaskProgress.Items(Array<TaskStatus>(items.size, { i => items[i] })))
            case Some(TaskProgress.Counts(completed, total)) =>
                let boundedTotal = max(0, total)
                Some(TaskProgress.Counts(max(0, min(completed, boundedTotal)), boundedTotal))
            case None => None
        }
    }

    func renderProgress(): ?TaskProgress { progressSnapshot }
}

/** 绘制单个任务；调用方拥有任务状态，并在需要动画时传入新的帧序号。
 */
public class TaskActivityView <: Widget {
    private let activity: TaskActivity
    private let layout: TaskActivityLayout
    private let activityFrame: Int64
    private let theme: Theme
    private let unicode: ?Bool
    private let maxHeaderWidth: Int64

    /** 创建任务 Widget；负帧序号按零处理，默认使用展开布局，根据终端能力和主题选择标记；显式 unicode 参数覆盖自动选择。
     * 展开布局将耗时对齐到最多 88 列的标题行，maxHeaderWidth 为零时使用整个宽度；
     * 长标题需要更多空间时会扩展该宽度，空间不足时优先显示标题。
     */
    public init(
        activity: TaskActivity,
        layout!: TaskActivityLayout = TaskActivityLayout.Expanded,
        activityFrame!: Int64 = 0,
        theme!: Theme = Theme(),
        unicode!: ?Bool = None,
        maxHeaderWidth!: Int64 = 88
    ) {
        this.activity = activity
        this.layout = layout
        this.activityFrame = max(0, activityFrame)
        this.theme = theme
        this.unicode = unicode
        this.maxHeaderWidth = max(0, maxHeaderWidth)
    }

    /** 在指定区域绘制任务；空区域不绘制，超出区域的内容按单元格宽度裁剪。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let canvas = Canvas(buffer, area)
        let icons = match (unicode) {
            case Some(true) => IconSet.Unicode
            case Some(false) => IconSet.Ascii
            case None => if (buffer.capabilities().unicode) { theme.iconSet } else { IconSet.Ascii }
        }
        match (layout) {
            case TaskActivityLayout.Compact => renderCompact(canvas, area, icons)
            case TaskActivityLayout.Expanded => renderExpanded(canvas, area, icons)
        }
    }

    private func renderCompact(canvas: Canvas, area: Rect, icons: IconSet): Unit {
        var x = drawMarker(canvas, area.x, area.y, area.right, marker(activity.status, icons), statusStyle(activity.status))
        x = drawPart(canvas, x, area.y, area.right, activity.prefix, theme.accent)
        x = drawPart(canvas, x, area.y, area.right, activity.title, theme.normal)
        x = drawPart(canvas, x, area.y, area.right, activity.id, theme.disabled)
        let label = if (activity.statusText.isEmpty()) { taskStatusText(activity.status) } else { activity.statusText }
        x = drawPart(canvas, x, area.y, area.right, label, statusStyle(activity.status))
        x = drawPart(canvas, x, area.y, area.right, activity.duration, theme.disabled)
        _ = drawPart(canvas, x, area.y, area.right, activity.detail, theme.disabled)
    }

    private func renderExpanded(canvas: Canvas, area: Rect, icons: IconSet): Unit {
        let durationWidth = displayWidth(activity.duration)
        let markerText = marker(activity.status, icons)
        var contentWidth = displayWidth(markerText) + 2
        if (!activity.prefix.isEmpty()) { contentWidth += displayWidth(activity.prefix) + 1 }
        contentWidth += displayWidth(activity.title)
        if (!activity.id.isEmpty()) { contentWidth += 1 + displayWidth(activity.id) }
        let showDuration = !activity.duration.isEmpty() && contentWidth + 1 + durationWidth <= area.width
        let preferredWidth = if (maxHeaderWidth == 0) { area.width } else { min(maxHeaderWidth, area.width) }
        let headerWidth = if (showDuration) { max(preferredWidth, contentWidth + 1 + durationWidth) } else { area.width }
        let headerRight = area.x + headerWidth
        let textRight = if (showDuration) { headerRight - durationWidth - 1 } else { area.right }
        let header = canvas.withClip(Rect(area.x, area.y, max(0, textRight - area.x), 1))
        var x = drawMarker(header, area.x, area.y, textRight, markerText, statusStyle(activity.status))
        x = drawPart(header, x, area.y, textRight, activity.prefix, theme.accent)
        x = drawPart(header, x, area.y, textRight, activity.title, theme.normal)
        _ = drawPart(header, x, area.y, textRight, activity.id, theme.disabled)
        if (showDuration) { canvas.drawText(headerRight - durationWidth, area.y, activity.duration, theme.disabled) }

        var y = area.y + 1
        match (activity.renderProgress()) {
            case Some(progress) =>
                if (y < area.bottom) { renderProgress(canvas, area, y, progress, icons) }
                y++
            case None => ()
        }
        if (!activity.detail.isEmpty() && y < area.bottom) {
            canvas.drawText(area.x + 2, y, activity.detail, theme.disabled)
        }
    }

    private func renderProgress(canvas: Canvas, area: Rect, y: Int64, progress: TaskProgress, icons: IconSet): Unit {
        let start = min(area.right, area.x + 2)
        let x = drawPart(canvas, start, y, area.right, activity.progressLabel, theme.disabled)
        let available = max(0, area.right - x)
        let visible = available / 2 + available % 2
        match (progress) {
            case TaskProgress.Items(items) =>
                for (i in 0..min(visible, items.size)) {
                    canvas.drawText(x + i * 2, y, progressMarker(items[i], icons), progressStyle(items[i]))
                }
            case TaskProgress.Counts(completed, total) =>
                for (i in 0..min(visible, total)) {
                    let status = if (i < completed) { TaskStatus.Done } else { TaskStatus.Pending }
                    canvas.drawText(x + i * 2, y, progressMarker(status, icons), progressStyle(status))
                }
        }
    }

    private func drawMarker(canvas: Canvas, x: Int64, y: Int64, right: Int64, text: String, style: Style): Int64 {
        let next = drawPart(canvas, x, y, right, text, style)
        if (next >= right || next == x) { return next }
        canvas.drawText(next, y, " ", theme.normal)
        next + 1
    }

    // Returns the next cell, explicitly clearing the separator after each nonempty part.
    private func drawPart(canvas: Canvas, x: Int64, y: Int64, right: Int64, text: String, style: Style): Int64 {
        if (text.isEmpty() || x >= right) { return x }
        canvas.drawText(x, y, text, style)
        let occupied = min(right - x, displayWidth(text))
        let end = x + occupied
        if (end < right) { canvas.drawText(end, y, " ", style) }
        min(right, end + min(1, right - end))
    }

    private func marker(status: TaskStatus, icons: IconSet): String {
        let unicode = match (icons) { case IconSet.Ascii => false; case _ => true }
        if (match (icons) { case IconSet.NerdFont => true; case _ => false }) {
            return match (status) {
                case TaskStatus.Pending => "\u{f10c}"
                case TaskStatus.Queued => "\u{f252}"
                case TaskStatus.Running => "\u{f110}"
                case TaskStatus.Done => "\u{f058}"
                case TaskStatus.Failed => "\u{f057}"
                case TaskStatus.Cancelled => "\u{f068}"
            }
        }
        match (status) {
            case TaskStatus.Pending => if (unicode) { "○" } else { "o" }
            case TaskStatus.Queued => if (unicode) { "…" } else { "-" }
            case TaskStatus.Running =>
                if (!unicode) {
                    ["|", "/", "-", "\\"][activityFrame % 4]
                } else {
                    ["◐", "◓", "◑", "◒"][activityFrame % 4]
                }
            case TaskStatus.Done => if (unicode) { "✓" } else { "+" }
            case TaskStatus.Failed => if (unicode) { "✗" } else { "x" }
            case TaskStatus.Cancelled => if (unicode) { "–" } else { "-" }
        }
    }

    private func progressMarker(status: TaskStatus, icons: IconSet): String {
        let unicode = match (icons) { case IconSet.Ascii => false; case _ => true }
        match (status) {
            case TaskStatus.Pending | TaskStatus.Queued => if (unicode) { "◌" } else { "o" }
            case TaskStatus.Done => if (unicode) { "●" } else { "+" }
            case _ => marker(status, icons)
        }
    }

    private func progressStyle(status: TaskStatus): Style {
        match (status) {
            case TaskStatus.Pending | TaskStatus.Queued => theme.normal
            case _ => statusStyle(status)
        }
    }

    private func statusStyle(status: TaskStatus): Style {
        match (status) {
            case TaskStatus.Pending | TaskStatus.Queued => theme.disabled
            case TaskStatus.Running => theme.accent
            case TaskStatus.Done => theme.success
            case TaskStatus.Failed => theme.error
            case TaskStatus.Cancelled => theme.warning
        }
    }
}

/** 一个任务及其紧凑或展开显示方式。 */
public class TaskActivityListEntry {
    public let activity: TaskActivity
    public let layout: TaskActivityLayout

    public init(activity: TaskActivity, layout!: TaskActivityLayout = TaskActivityLayout.Expanded) {
        this.activity = activity
        this.layout = layout
    }

    func height(): Int64 {
        match (layout) {
            case TaskActivityLayout.Compact => 1
            case TaskActivityLayout.Expanded =>
                let progressHeight = match (activity.renderProgress()) { case Some(_) => 1; case None => 0 }
                1 + progressHeight + if (activity.detail.isEmpty()) { 0 } else { 1 }
        }
    }
}

/**
 * 按任务索引滚动的只读活动列表。调用方管理数据、偏移、动画与输入。
 * 当内容被裁剪或偏移时，在末行显示隐藏或不完整任务的数量；单行区域优先显示任务标题。
 * maxHeaderWidth 控制展开项耗时的对齐宽度，默认为 88，设为 0 使用整个宽度。
 */
public class TaskActivityList <: Widget {
    private let entries: Array<TaskActivityListEntry>
    private let offset: Int64
    private let activityFrame: Int64
    private let theme: Theme
    private let unicode: ?Bool
    private let maxHeaderWidth: Int64

    public init(entries: Array<TaskActivityListEntry>, offset!: Int64 = 0, activityFrame!: Int64 = 0,
        theme!: Theme = Theme(), unicode!: ?Bool = None, maxHeaderWidth!: Int64 = 88) {
        this.entries = Array<TaskActivityListEntry>(entries.size, { i => entries[i] })
        this.offset = max(0, min(offset, max(0, entries.size - 1)))
        this.activityFrame = activityFrame
        this.theme = theme
        this.unicode = unicode
        this.maxHeaderWidth = max(0, maxHeaderWidth)
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0 || entries.size == 0) { return }
        if (area.height == 1) {
            let entry = entries[offset]
            let above = if (offset > 0) { "${offset} above" } else { "" }
            let belowCount = entries.size - offset - 1
            let below = if (belowCount > 0) { "${belowCount} more" } else { "" }
            let separator = if (!above.isEmpty() && !below.isEmpty()) { " | " } else { "" }
            let indicator = above + separator + below
            let requiredTitle = 3 + displayWidth(entry.activity.prefix) +
                (if (entry.activity.prefix.isEmpty()) { 0 } else { 1 }) + displayWidth(entry.activity.title)
            let indicatorWidth = displayWidth(indicator)
            let showIndicator = !indicator.isEmpty() && requiredTitle + 1 + indicatorWidth <= area.width
            let itemWidth = if (showIndicator) { area.width - indicatorWidth - 1 } else { area.width }
            TaskActivityView(entry.activity, layout: entry.layout, activityFrame: activityFrame,
                theme: theme, unicode: unicode, maxHeaderWidth: maxHeaderWidth).render(Rect(area.x, area.y, itemWidth, 1), buffer)
            if (showIndicator) {
                Canvas(buffer, area).drawText(area.right - indicatorWidth, area.y, indicator, theme.disabled)
            }
            return
        }
        var remaining = area.height
        var index = offset
        while (index < entries.size && entries[index].height() <= remaining) {
            remaining -= entries[index].height()
            index++
        }
        let needsIndicator = offset > 0 || index < entries.size
        let contentHeight = if (needsIndicator) { max(0, area.height - 1) } else { area.height }
        var y = area.y
        index = offset
        var partial = false
        while (index < entries.size && y - area.y < contentHeight) {
            let entry = entries[index]
            let height = min(entry.height(), contentHeight - (y - area.y))
            TaskActivityView(entry.activity, layout: entry.layout, activityFrame: activityFrame,
                theme: theme, unicode: unicode, maxHeaderWidth: maxHeaderWidth).render(Rect(area.x, y, area.width, height), buffer)
            y += height
            if (height < entry.height()) { partial = true; break }
            index++
        }
        if (needsIndicator) {
            let hidden = entries.size - index
            let earlier = if (offset > 0) { "${offset} above" } else { "" }
            let later = if (hidden > 0) {
                if (partial) { "${hidden} more/partial" } else { "${hidden} more" }
            } else { "" }
            let separator = if (!earlier.isEmpty() && !later.isEmpty()) { " | " } else { "" }
            Canvas(buffer, area).drawText(area.x, area.bottom - 1, earlier + separator + later, theme.disabled)
        }
    }
}

func taskStatusText(status: TaskStatus): String {
    match (status) {
        case TaskStatus.Pending => "pending"
        case TaskStatus.Queued => "queued"
        case TaskStatus.Running => "running"
        case TaskStatus.Done => "done"
        case TaskStatus.Failed => "failed"
        case TaskStatus.Cancelled => "cancelled"
    }
}
