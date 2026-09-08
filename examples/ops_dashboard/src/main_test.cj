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
}
