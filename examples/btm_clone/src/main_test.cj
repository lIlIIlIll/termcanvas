package cjtui_btm_clone

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class BtmCloneInputTest {
    @TestCase
    func searchBackspaceRemovesAWholeRune(): Unit {
        let app = BtmClone()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'界'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Backspace)))

        let backend = TestBackend(area: Rect(0, 0, 100, 32))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw({ frame => app.renderFrame(frame) })

        @Assert(backend.snapshot().contains("search: _"))
        @Assert(!backend.snapshot().contains("search: 界"))
    }

    @TestCase
    func staleBackgroundSampleDoesNotReplaceInteractiveFilter(): Unit {
        let app = BtmClone()
        var poll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
        if (!commandHasAsyncTask(poll.command)) {
            poll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
        }
        @Assert(commandHasAsyncTask(poll.command))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'界'))))
        let appliedBefore = app.appliedProcessRequestId()
        _ = runAsyncCommand(app, poll.command)

        @Expect(app.appliedProcessRequestId(), appliedBefore)
    }
}
