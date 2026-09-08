package cjtui_assistant_console

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
}
