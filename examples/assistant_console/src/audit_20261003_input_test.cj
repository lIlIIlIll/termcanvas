package cjtui_assistant_console

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003AssistantInputTest {
    @TestCase
    func typingOrdinaryLettersDoesNotInvokeApplicationCommands(): Unit {
        let app = AssistantConsole()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        app.composer.area.setValue("")
        for (rune in "aqua".runes()) {
            match (app.update(Event.KeyDown(KeyEvent(KeyCode.Char(rune))))) {
                case ControlFlow.Continue => ()
                case _ => @Expect(false)
            }
        }
        @Expect(app.composer.area.value, "aqua")
        @Expect(!app.showRequest)
    }
}
