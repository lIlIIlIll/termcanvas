package cjtui_testing

import core.*
import std.unittest.*
import std.unittest.testmacro.*

class ScenarioState {
    var count: Int64 = 0
    var width: Int64 = 0
    var elapsed: Int64 = 0
    var text = ""
}

@Test
class DownstreamTestingTest {
    @TestCase
    func scenarioRunsCommandsResizeTicksAndExitThroughTheApplication(): Unit {
        let state = ScenarioState()
        let report = TestScenario().message("inc").resize(12, 3).tick(count: 2)
            .expectCell(0, 0, "1").key(KeyEvent(KeyCode.Char(r'q'))).run(
                { frame => frame.renderWidget(Paragraph(state.count.toString()), frame.area) },
                { event =>
                    match (event) {
                        case Event.Message("inc") => UpdateResult.withCommand(Command.Message("apply"))
                        case Event.Message("apply") => state.count++; UpdateResult.next()
                        case Event.Resize(area) => state.width = area.width; UpdateResult.next()
                        case Event.Tick(tick) => state.elapsed += tick.deltaMillis; UpdateResult.next()
                        case Event.KeyDown(_) => UpdateResult.exit()
                        case _ => UpdateResult.unchanged()
                    }
                }, tickDeltaMillis: 25
            )
        @Expect(report.passed)
        @Expect(report.exited)
        @Expect(state.count, 1)
        @Expect(state.width, 12)
        @Expect(state.elapsed, 50)
        @Expect(report.frames[report.frames.size - 1].area, Rect(0, 0, 12, 3))
        @Expect(report.lastSnapshot().contains("1"))
    }

    @TestCase
    func failuresAndPasteAreAvailableWithoutInternalTestTypes(): Unit {
        let state = ScenarioState()
        let report = TestScenario().paste("界").expectCell(0, 0, "wrong").run(
            { frame => frame.renderWidget(Paragraph(state.text), frame.area) },
            { event => match (event) {
                case Event.Paste(value) => state.text = value; UpdateResult.next()
                case _ => UpdateResult.unchanged()
            } }
        )
        @Expect(!report.passed)
        @Expect(!report.exited)
        @Expect(report.failures.size, 1)
        @Expect(report.lastSnapshot().contains("界"))
    }
}
