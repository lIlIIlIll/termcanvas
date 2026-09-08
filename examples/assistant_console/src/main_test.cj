package termcanvas_assistant_console

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class AssistantConsoleTest {
    @TestCase
    func requestResultAndPasteUseTheRealUpdatePath(): Unit {
        let app = AssistantConsole()

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.showRequest, false)
        @Expect(app.status, "approval: Cancel")

        app.composer.area.setValue("draft", cursor: 5)
        _ = app.update(Event.Paste(" 世界"))
        @Expect(app.composer.area.value, "draft 世界")
        @Expect(app.composer.area.cursor, Int64(12))
    }

    @TestCase
    func pasteDoesNotBypassTheOpenRequest(): Unit {
        let app = AssistantConsole()
        let before = app.composer.area.value

        _ = app.update(Event.Paste("ignored"))
        @Expect(app.composer.area.value, before)
        @Expect(app.showRequest, true)
    }

    @TestCase
    func approvalKeyboardAndRenderingCoverBothApplicationSurfaces(): Unit {
        let app = AssistantConsole()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'a'))))
        @Expect(app.showRequest)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        let accepted = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.showRequest, false)
        @Expect(app.status, "approval: Confirm")
        match (accepted) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.End)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(app.composer.area.value.endsWith("x"))
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("Transcript"))
        app.showRequest = true
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("Approval"))
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (quit) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
