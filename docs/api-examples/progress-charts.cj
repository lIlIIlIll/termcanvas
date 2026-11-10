package cjtui_api_example

import core.*
import cjtui_testing.*

main(): Int64 {
    let symbols = ProgressBarSymbols(filled: "=", empty: "-", head: ">", indeterminate: "~")
    let part = ProgressBarSegment(2, style: Style(fg: Color.Green), symbol: "=")
    if (symbols.filled != "=" || symbols.empty != "-" || symbols.head != ">" || symbols.indeterminate != "~" ||
        part.value != 2 || part.style != Style(fg: Color.Green) || part.symbol != "=") {
        throw IllegalStateException("incorrect progress configuration")
    }
    let modes = [ProgressBarLabelMode.Hidden, ProgressBarLabelMode.Percent, ProgressBarLabelMode.Value,
        ProgressBarLabelMode.Ratio, ProgressBarLabelMode.Text("Working")]
    let positions = [ProgressBarLabelPosition.Automatic, ProgressBarLabelPosition.Start, ProgressBarLabelPosition.End]
    let report = TestScenario().render().run(
        { frame =>
            frame.renderWidget(ProgressBar(1, total: 2, direction: ProgressBarDirection.Horizontal,
                labelMode: modes[1], labelPosition: positions[2], symbols: symbols), Rect(0, 0, 30, 1))
            frame.renderWidget(ProgressBar(1, total: 4, label: "Job", style: Style(), fillStyle: Style(fg: Color.Green),
                theme: Theme.graphite(), direction: ProgressBarDirection.Vertical, labelMode: modes[4],
                labelStyle: Style(), symbols: symbols, segments: [part], indeterminate: true, phase: 1,
                labelPosition: positions[1], trackOverride: StyleOverride(), fillOverride: StyleOverride(),
                labelOverride: StyleOverride()), Rect(32, 0, 8, 4))
            frame.renderWidget(Gauge(1, total: 2, label: "Gauge"), Rect(0, 1, 30, 1))
            frame.renderWidget(Sparkline([Int64(1), 3, 2], maxValue: 3), Rect(0, 2, 5, 1))
            frame.renderWidget(Chart([Int64(1), 2, 3], maxValue: 3), Rect(6, 2, 5, 3))
            frame.renderWidget(LogView(["first", "latest"]), Rect(0, 5, 20, 2))
        }, { _ => UpdateResult.unchanged() }, width: 40, height: 8
    )
    let log = LogView(["first", "latest"], offset: 0)
    log.offset = 1
    if (!report.passed || !report.lastSnapshot().contains("50.00%") ||
        !report.lastSnapshot().contains("latest") || log.offset != 1 || modes.size != 5 || positions.size != 3) {
        throw IllegalStateException("progress or chart rendering failed")
    }
    return 0
}
