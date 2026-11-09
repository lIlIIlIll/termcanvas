package cjtui_api_example

import core.*
import cjtui_testing.*

main(): Int64 {
    let statuses = [TaskStatus.Pending, TaskStatus.Queued, TaskStatus.Running, TaskStatus.Paused,
        TaskStatus.Done, TaskStatus.Failed, TaskStatus.Cancelled]
    let build = TaskActivity("Build", status: TaskStatus.Running, id: "job-1", prefix: "CI",
        statusText: "running", duration: "2s", detail: "Compile source", progressLabel: "Jobs",
        progress: Some(TaskProgress.Items(statuses)))
    let test = TaskActivity("Test", status: TaskStatus.Done, progress: Some(TaskProgress.Counts(2, 3)))
    let first = TaskActivityListEntry(build, layout: TaskActivityLayout.Expanded)
    let second = TaskActivityListEntry(test, layout: TaskActivityLayout.Compact)
    if (build.title != "Build" || build.id != "job-1" || build.prefix != "CI" || build.statusText != "running" ||
        build.duration != "2s" || build.detail != "Compile source" || build.progressLabel != "Jobs" ||
        first.activity.title != "Build") { throw IllegalStateException("incorrect task data") }
    match ((build.status, first.layout, second.layout)) {
        case (TaskStatus.Running, TaskActivityLayout.Expanded, TaskActivityLayout.Compact) => ()
        case _ => throw IllegalStateException("incorrect task presentation")
    }
    let report = TestScenario().render().run(
        { frame =>
            frame.renderWidget(TaskActivityList([first, second], offset: 0, activityFrame: 1,
                theme: Theme.graphite(), unicode: true, maxHeaderWidth: 40), frame.area)
        }, { _ => UpdateResult.unchanged() }, width: 50, height: 6
    )
    let compact = TestScenario().render().run(
        { frame => frame.renderWidget(TaskActivityView(test, layout: TaskActivityLayout.Compact,
            activityFrame: 0, unicode: false), frame.area) },
        { _ => UpdateResult.unchanged() }, width: 40, height: 1
    )
    if (!report.passed || !report.lastSnapshot().contains("Build") || !report.lastSnapshot().contains("Compile source") ||
        !compact.lastSnapshot().contains("Test")) { throw IllegalStateException("task display failed") }
    return 0
}
