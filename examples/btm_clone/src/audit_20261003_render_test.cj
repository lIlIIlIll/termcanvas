package cjtui_btm_clone

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003BtmRenderTest {
    @TestCase
    func truncationUsesTerminalColumnsAndPreservesGraphemes(): Unit {
        @Expect(truncateLocal("界界x", 3), "界")
        @Expect(truncateLocal("a界x", 2), "a")
        @Expect(truncateLocal("e\u{301}x", 1), "e\u{301}")
    }

    @TestCase
    func navigatingWhileDetailIsOpenMatchesAFullRender(): Unit {
        let app = BtmClone()
        let backend = TestBackend(area: Rect(0, 0, 100, 48))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw { frame => app.renderFrame(frame) }
        let open = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: open.dirtyRects)
        @Assert(backend.snapshot().contains(" detail "))
        let move = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: move.dirtyRects)
        let afterNavigation = backend.snapshot()
        _ = terminal.draw { frame => app.renderFrame(frame) }
        @Expect(afterNavigation, backend.snapshot())
    }
}
