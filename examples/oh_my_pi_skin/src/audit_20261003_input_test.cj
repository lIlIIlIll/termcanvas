package cjtui_oh_my_pi_skin

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003SkinInputTest {
    @TestCase
    func focusedComposerOwnsOrdinaryCommandLetters(): Unit {
        let app = OhMyPiSkin()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        app.composer.area.setValue("")
        for (rune in "/btq".runes()) {
            let result = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(rune))))
            match (result.flow) {
                case ControlFlow.Continue => ()
                case _ => @Expect(false)
            }
        }
        @Expect(app.composer.area.value, "/btq")
        @Expect(!app.paletteOpen)
        @Expect(app.showBusy)
        @Expect(app.mode, "agent")
    }
}
