package cjtui_testing

import core.*

// This package owns the downstream contract. Repository test machinery stays
// behind private fields and is never part of its public signatures.
/** 保存一次无头场景运行的结果。
 * 帧和文本快照按产生顺序保存；失败详情可用于诊断断言。
 */
public class TestReport {
    /** 所有场景期望是否通过。 */
    public let passed: Bool
    /** 应用更新过程是否返回退出控制流。 */
    public let exited: Bool
    /** 运行期间采集的渲染缓冲区。 */
    public let frames: Array<Buffer>
    /** 运行期间采集的文本快照。 */
    public let snapshots: Array<String>
    /** 未通过期望对应的诊断信息。 */
    public let failures: Array<String>

    /** 保存状态并复制传入的帧、快照和失败数组。 */
    public init(passed: Bool, exited: Bool, frames: Array<Buffer>, snapshots: Array<String>, failures: Array<String>) {
        this.passed = passed
        this.exited = exited
        this.frames = frames.clone()
        this.snapshots = snapshots.clone()
        this.failures = failures.clone()
    }

    /** 返回最后一个文本快照；没有采集到快照时返回空字符串。 */
    public func lastSnapshot(): String {
        if (snapshots.isEmpty()) { "" } else { snapshots[snapshots.size - 1] }
    }
}

/** 按顺序组合输入、渲染和期望，在测试后端运行应用。
 *
 * @example 检查渲染内容
 * ```cangjie
 * let report = TestScenario().expectCell(0, 0, "O").run(
 *     { frame => frame.renderWidget(Paragraph("OK"), frame.area) },
 *     { _ => UpdateResult.unchanged() }
 * )
 * if (!report.passed) { throw IllegalStateException("scenario failed") }
 * ```
 *
 * @example 组合任务状态与进度条
 * ```cangjie
 * let task = TaskActivity("Build", status: TaskStatus.Running, duration: "2s")
 * let dashboard = TestScenario().run(
 *     { frame =>
 *         frame.renderWidget(TaskActivityView(task, theme: Theme.graphite()), Rect(0, 0, 40, 2))
 *         frame.renderWidget(ProgressBar(1, total: 2, labelMode: ProgressBarLabelMode.Percent), Rect(0, 2, 40, 1))
 *     },
 *     { _ => UpdateResult.unchanged() }, width: 40, height: 4
 * )
 * if (!dashboard.lastSnapshot().contains("Build") || !dashboard.lastSnapshot().contains("50.00%")) {
 *     throw IllegalStateException("dashboard rendering failed")
 * }
 * ```
 */
public class TestScenario {
    private let script = HeadlessScript()

    /** 创建不含步骤的场景。 */
    public init() {}

    /** 追加事件，并返回当前场景以继续组合步骤。 */
    public func event(value: Event): TestScenario { script.event(value); this }
    /** 追加按键按下事件，并返回当前场景。 */
    public func key(value: KeyEvent): TestScenario { script.key(value); this }
    /** 追加文本粘贴事件，并返回当前场景。 */
    public func paste(text: String): TestScenario { script.paste(text); this }
    /** 追加应用消息事件，并返回当前场景。 */
    public func message(text: String): TestScenario { script.message(text); this }
    /** 追加一次显式渲染，并返回当前场景。 */
    public func render(): TestScenario { script.render(); this }

    /** 追加终端尺寸调整；宽或高非正时抛出 IllegalArgumentException。 */
    public func resize(width: Int64, height: Int64): TestScenario {
        requireSize(width, height)
        script.resize(Rect(0, 0, width, height))
        this
    }

    /** 追加指定次数的时钟步进；负数时抛出 IllegalArgumentException。 */
    public func tick(count!: Int64 = 1): TestScenario {
        if (count < 0) { throw IllegalArgumentException("tick count must be non-negative") }
        script.tick(count: count)
        this
    }

    /** 追加对当前完整文本快照的精确期望，并返回当前场景。 */
    public func expectSnapshot(text: String): TestScenario { script.expectSnapshot(text); this }
    /** 追加对指定终端单元格符号的期望，并返回当前场景。 */
    public func expectCell(x: Int64, y: Int64, symbol: String): TestScenario {
        script.expectCell(x, y, symbol)
        this
    }

    /** 先渲染初始画面，再按添加顺序执行场景并返回报告。
     * 尺寸和 tick 间隔必须为正，否则抛出 IllegalArgumentException。
     *
     * @param render 根据应用状态绘制当前帧的回调
     * @param update 处理输入和计时事件的回调
     * @param width 初始终端宽度，单位为单元格
     * @param height 初始终端高度，单位为单元格
     * @param tickDeltaMillis 每次时钟步进的毫秒数
     * @return 包含状态、快照和失败信息的报告
     */
    public func run(
        render: (Frame) -> Unit,
        update: (Event) -> UpdateResult,
        width!: Int64 = 80,
        height!: Int64 = 24,
        tickDeltaMillis!: Int64 = 16
    ): TestReport {
        requireSize(width, height)
        if (tickDeltaMillis <= 0) { throw IllegalArgumentException("tick interval must be positive") }
        let result = AppTestRunner.run(script, render, update, options: HeadlessRunOptions(
            area: Rect(0, 0, width, height), tickDeltaMillis: tickDeltaMillis
        ))
        let exited = match (result.flow) { case ControlFlow.Exit => true; case _ => false }
        TestReport(result.passed(), exited, result.frames, result.snapshots, result.failures)
    }

    private func requireSize(width: Int64, height: Int64): Unit {
        if (width <= 0 || height <= 0) { throw IllegalArgumentException("test dimensions must be positive") }
    }
}
