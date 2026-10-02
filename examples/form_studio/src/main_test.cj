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
    @TestCase
    func modalSaveAndNestedHelpKeepTheFormIsolated(): Unit {
        let app = FormStudio()
        @Expect(app.focus.focus("notes"))
        let original = app.notes.value
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        @Expect(app.interaction.active(), Some("save"))
        _ = app.update(Event.Paste("must not reach notes"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(app.notes.value, original)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        @Expect(app.interaction.focus().current(), Some("confirm"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(1))))
        @Expect(app.interaction.active(), Some("help"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        @Expect(app.interaction.active(), Some("help"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(app.interaction.active(), Some("save"))
        @Expect(app.interaction.focus().current(), Some("confirm"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.interaction.active().isNone())
        @Expect(app.focus.current(), Some("notes"))
        @Expect(app.status, "saved profile for Ada")
    }

    @TestCase
    func mouseControlsUseRenderedGeometryAndModalDoesNotClickThrough(): Unit {
        let app = FormStudio()
        let terminal = Terminal(TestBackend(area: Rect(0, 0, 100, 32)), renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        let area = app.regions[2]
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x, area.y)))
        @Expect(!app.enabled.checked)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, area.x, area.y)))
        @Expect(!app.enabled.checked)
        @Expect(app.interaction.active(), Some("save"))
    }

}
