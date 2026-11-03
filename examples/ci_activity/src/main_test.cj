package cjtui_ci_activity

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class CiActivityTest {
    @TestCase
    func simulationTransitionsAndControls(): Unit {
        let app = CiActivity()
        let backend = TestBackend(area: Rect(0, 0, 100, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("Cross-platform CI"))
        @Expect(backend.snapshot().contains("● ● ◌ ● ● ◌ ● ◌"))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 18000)))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("1 still running"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 12000)))
        @Expect(app.elapsed, 18000)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 12000)))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("All simulated checks finished"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'))))
        @Expect(app.elapsed, 0)
        match (app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q')))).flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
