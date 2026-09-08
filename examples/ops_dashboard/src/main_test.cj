package cjtui_ops_dashboard

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class OpsDashboardTest {
    @TestCase
    func ticksDriveTheRealDashboardState(): Unit {
        let app = OpsDashboard()

        _ = app.update(Event.Tick(TickEvent(frameIndex: 1)))
        _ = app.update(Event.Tick(TickEvent(frameIndex: 2)))

        @Expect(app.frame, Int64(2))
        @Expect(app.build, Int64(48))

        let backend = TestBackend(area: Rect(0, 0, 60, 20))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        @Assert(backend.snapshot().contains("Event log"))
    }

    @TestCase
    func resetTimerCapabilitiesAndPhaseThresholdsRender(): Unit {
        let app = OpsDashboard()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'))))
        @Expect(app.build, 0)
        @Expect(app.queue, 8)
        _ = app.update(Event.Timer(TimerEvent("queue", firedCount: 3)))
        @Expect(app.queue, 1)
        let command = app.update(Event.Capabilities(TerminalCapabilities()))
        match (command.command) {
            case Command.StartTimer(_) => ()
            case _ => @Expect(false)
        }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(app.build, 0)
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        app.build = 24
        _ = terminal.draw { frame => app.render(frame) }
        app.build = 70
        _ = terminal.draw { frame => app.render(frame) }
        app.build = 100
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("complete"))
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (quit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
