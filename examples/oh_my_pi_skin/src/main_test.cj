package cjtui_oh_my_pi_skin

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class OhMyPiSkinTest {
    @TestCase
    func openPaletteReceivesQueryInput(): Unit {
        let app = OhMyPiSkin()

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'z'))))

        @Expect(app.paletteOpen, true)
        @Expect(app.palette.query, "z")
        @Expect(app.composer.area.value, "/review runtime#1441 --multi-round")
    }

    @TestCase
    func paletteActionUpdatesTheOwningApplication(): Unit {
        let app = OhMyPiSkin()

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))

        @Expect(app.paletteOpen, false)
        @Expect(app.showBusy, false)
    }

    @TestCase
    func paletteQuitReturnsExit(): Unit {
        let app = OhMyPiSkin()

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        for (_ in 0..4) {
            _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        }
        let result = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))

        match (result.flow) {
            case ControlFlow.Exit => ()
            case _ => @Assert(false)
        }
        @Expect(app.paletteOpen, false)
    }
}
