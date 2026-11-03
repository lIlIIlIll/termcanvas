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
    private let unicode: Bool

    /** 创建任务 Widget；负帧序号按零处理，默认使用展开布局与 Unicode 标记。
     */
    public init(
        activity: TaskActivity,
        layout!: TaskActivityLayout = TaskActivityLayout.Expanded,
        activityFrame!: Int64 = 0,
        theme!: Theme = Theme(),
        unicode!: Bool = true
    ) {
        this.activity = activity
        this.layout = layout
        this.activityFrame = max(0, activityFrame)
        this.theme = theme
        this.unicode = unicode
    }

    /** 在指定区域绘制任务；空区域不绘制，超出区域的内容按单元格宽度裁剪。
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let canvas = Canvas(buffer, area)
        match (layout) {
            case TaskActivityLayout.Compact => renderCompact(canvas, area)
            case TaskActivityLayout.Expanded => renderExpanded(canvas, area)
        }
    }

    private func renderCompact(canvas: Canvas, area: Rect): Unit {
        var x = drawPart(canvas, area.x, area.y, area.right, marker(activity.status), statusStyle(activity.status))
        x = drawPart(canvas, x, area.y, area.right, activity.prefix, theme.accent)
        x = drawPart(canvas, x, area.y, area.right, activity.title, theme.normal)
        x = drawPart(canvas, x, area.y, area.right, activity.id, theme.disabled)
        let label = if (activity.statusText.isEmpty()) { taskStatusText(activity.status) } else { activity.statusText }
        x = drawPart(canvas, x, area.y, area.right, label, statusStyle(activity.status))
        x = drawPart(canvas, x, area.y, area.right, activity.duration, theme.disabled)
        _ = drawPart(canvas, x, area.y, area.right, activity.detail, theme.disabled)
    }

    private func renderExpanded(canvas: Canvas, area: Rect): Unit {
        let durationWidth = displayWidth(activity.duration)
        let showDuration = !activity.duration.isEmpty() && durationWidth <= area.width - 14
        let textRight = if (showDuration) { area.right - durationWidth - 1 } else { area.right }
        let header = canvas.withClip(Rect(area.x, area.y, max(0, textRight - area.x), 1))
        var x = drawPart(header, area.x, area.y, textRight, marker(activity.status), statusStyle(activity.status))
        x = drawPart(header, x, area.y, textRight, activity.prefix, theme.accent)
        x = drawPart(header, x, area.y, textRight, activity.title, theme.normal)
        _ = drawPart(header, x, area.y, textRight, activity.id, theme.disabled)
        if (showDuration) { canvas.drawText(area.right - durationWidth, area.y, activity.duration, theme.disabled) }

        var y = area.y + 1
        match (activity.renderProgress()) {
            case Some(progress) =>
                if (y < area.bottom) { renderProgress(canvas, area, y, progress) }
                y++
            case None => ()
        }
        if (!activity.detail.isEmpty() && y < area.bottom) {
            canvas.drawText(area.x + 2, y, activity.detail, theme.disabled)
        }
    }

    private func renderProgress(canvas: Canvas, area: Rect, y: Int64, progress: TaskProgress): Unit {
        let start = min(area.right, area.x + 2)
        let x = drawPart(canvas, start, y, area.right, activity.progressLabel, theme.disabled)
        let available = max(0, area.right - x)
        let visible = available / 2 + available % 2
        match (progress) {
            case TaskProgress.Items(items) =>
                for (i in 0..min(visible, items.size)) {
                    canvas.drawText(x + i * 2, y, progressMarker(items[i]), statusStyle(items[i]))
                }
            case TaskProgress.Counts(completed, total) =>
                for (i in 0..min(visible, total)) {
                    let status = if (i < completed) { TaskStatus.Done } else { TaskStatus.Pending }
                    canvas.drawText(x + i * 2, y, progressMarker(status), statusStyle(status))
                }
        }
    }

    // Returns the next cell, with one separating space after each nonempty part.
    private func drawPart(canvas: Canvas, x: Int64, y: Int64, right: Int64, text: String, style: Style): Int64 {
        if (text.isEmpty() || x >= right) { return x }
        canvas.drawText(x, y, text, style)
        let occupied = min(right - x, displayWidth(text))
        min(right, x + occupied + min(1, right - x - occupied))
    }

    private func marker(status: TaskStatus): String {
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

    private func progressMarker(status: TaskStatus): String {
        match (status) {
            case TaskStatus.Pending | TaskStatus.Queued => if (unicode) { "◌" } else { "o" }
            case TaskStatus.Done => if (unicode) { "●" } else { "+" }
            case _ => marker(status)
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
