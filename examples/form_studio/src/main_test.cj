package cjtui_form_studio

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class FormStudioTest {
    @TestCase
    func pasteFollowsTheFocusedEditor(): Unit {
        let app = FormStudio()
        let originalName = app.name.value

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        @Expect(app.focus.current(), Some("notes"))

        app.notes.setValue("note", cursor: 4)
        _ = app.update(Event.Paste(" 中文"))

        @Expect(app.name.value, originalName)
        @Expect(app.notes.value, "note 中文")
        @Expect(app.status, "pasted into notes")
    }

    @TestCase
    func namePasteInsertsAtItsCursor(): Unit {
        let app = FormStudio()
        app.name.setValue("Ada", cursor: 1)

        _ = app.update(Event.Paste(" Li "))

        @Expect(app.name.value, "ALida")
        @Expect(app.name.cursor, Int64(3))
        @Expect(app.status, "pasted into name")
    }
}
