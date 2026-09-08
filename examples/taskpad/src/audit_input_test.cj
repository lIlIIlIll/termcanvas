package cjtui_taskpad

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TaskPadInputTest {
    @TestCase
    func ordinaryTaskTextDoesNotRunGlobalCommands(): Unit {
        let app = TaskPad()
        let initialDone = app.tasks[0].done
        for (rune in "a c q".runes()) {
            let result = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(rune))))
            match (result.flow) { case ControlFlow.Continue => (); case _ => @Expect(false) }
        }
        @Expect(app.input.value, "a c q")
        @Expect(app.tasks[0].done, initialDone)
        @Expect(!app.commandMode)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r't'), modifiers: KeyModifier(ctrl: true))))
        @Expect(app.tasks[0].done, !initialDone)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.tasks[app.tasks.size - 1].title, "a c q")
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'), modifiers: KeyModifier(ctrl: true))))
        match (quit.flow) { case ControlFlow.Exit => (); case _ => @Expect(false) }
    }

    @TestCase
    func escapeCancelsTheActualCommandPalette(): Unit {
        let app = TaskPad()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'p'), modifiers: KeyModifier(ctrl: true))))
        @Expect(app.commandMode)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(!app.commandMode)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(app.input.value, "x")
    }

    @TestCase
    func pasteIsTextAndTargetsTheFocusedEditor(): Unit {
        let app = TaskPad()
        _ = app.update(Event.Paste("a\u{08}b\n中"))
        @Expect(app.input.value, "ab 中")
        app.input.moveToStart()
        _ = app.update(Event.Paste("前"))
        @Expect(app.input.value, "前ab 中")
        @Expect(app.input.cursor, "前".size)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'p'), modifiers: KeyModifier(ctrl: true))))
        _ = app.update(Event.Paste("find"))
        @Expect(app.palette.query, "find")
        @Expect(app.palette.selected, 0)
        @Expect(app.input.value, "前ab 中")
    }
}
