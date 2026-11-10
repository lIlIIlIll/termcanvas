package cjtui_api_example

import core.*
import cjtui_testing.*

main(): Int64 {
    let initial = TestScenario().render().run(
        { frame => frame.renderWidget(Paragraph("OK"), frame.area) },
        { _ => UpdateResult.unchanged() }, width: 4, height: 1
    )
    let scenario = TestScenario().event(Event.FocusIn).key(KeyEvent(KeyCode.Char(r'a')))
        .paste("text").message("refresh").resize(4, 1).tick(count: 2).render()
        .expectCell(0, 0, "O").expectSnapshot(initial.lastSnapshot())
    let report = scenario.run(
        { frame => frame.renderWidget(Paragraph("OK"), frame.area) },
        { _ => UpdateResult.unchanged() }, width: 4, height: 1, tickDeltaMillis: 25
    )
    if (!report.passed || report.exited || report.frames.size == 0 || report.snapshots.size == 0 ||
        report.failures.size != 0 || report.lastSnapshot() != initial.lastSnapshot()) {
        throw IllegalStateException("headless scenario failed")
    }
    let saved = TestReport(report.passed, report.exited, report.frames, report.snapshots, report.failures)
    if (saved.lastSnapshot() != report.lastSnapshot()) { throw IllegalStateException("report copy failed") }
    return 0
}
