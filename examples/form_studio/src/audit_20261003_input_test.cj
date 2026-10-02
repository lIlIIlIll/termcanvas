package cjtui_form_studio

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003FormInputTest {
    @TestCase
    func letterQCanBeEnteredInBothEditors(): Unit {
        let app = FormStudio()
        app.name.setValue("")
        match (app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }
        @Expect(app.name.value, "q")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        app.notes.setValue("")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        @Expect(app.notes.value, "q")
    }
}
