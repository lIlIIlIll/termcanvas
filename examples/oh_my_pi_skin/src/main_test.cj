package termcanvas_oh_my_pi_skin

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

    @TestCase
    func todoStateCoversExpansionSelectionAndViewportRules(): Unit {
        let todos = TodoListState()
        @Expect(todos.visibleCount(), 10)
        @Expect(todos.totalCount(), 20)
        todos.sections[0].items[0].done = true
        @Expect(todos.completedCount(), 1)

        todos.home(3)
        @Expect(todos.selected, 0)
        todos.move(2, 1)
        @Expect(todos.selected, 2)
        @Expect(todos.offset, 2)
        todos.end(3)
        @Expect(todos.selected, todos.visibleCount() - 1)
        todos.selected = 0
        todos.ensureVisible(3)
        @Expect(todos.offset, 0)

        todos.activate(4)
        @Expect(!todos.sections[0].expanded)
        todos.setExpanded(true, 4)
        @Expect(todos.sections[0].expanded)
        todos.selected = 1
        todos.activate(4)
        @Expect(todos.sections[0].items[0].done, false)
        todos.setExpanded(false, 4)
        @Expect(todos.sections[0].expanded)
        todos.selected = 0
        todos.setExpanded(false, 4)
        @Expect(!todos.sections[0].expanded)
    }

    @TestCase
    func applicationUpdateCoversTimersFocusAndComposerRoutes(): Unit {
        let app = OhMyPiSkin()
        _ = app.update(Event.Capabilities(TerminalCapabilities(unicode: false)))
        for (id in [HERO_TIMER, TODO_TIMER, TRANSCRIPT_TIMER, STATUS_TIMER, "unknown"]) {
            _ = app.update(Event.Timer(TimerEvent(id, elapsedMillis: 12000)))
        }

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        let beforePaste = app.composer.area.value
        _ = app.update(Event.Paste(" pasted\ntext\t"))
        @Expect(app.composer.area.value != beforePaste)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Home)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.End)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'b'))))
        @Expect(!app.showBusy)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r't'))))
        @Expect(app.mode, "theme")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        _ = app.update(Event.Tick(TickEvent(elapsedMillis: 16, deltaMillis: 16, frameIndex: 2)))

        app.todoFocused = true
        _ = app.update(Event.Paste("ignored"))
        @Expect(!app.composer.area.value.endsWith("ignored"))
        let exit = app.update(Event.KeyDown(KeyEvent(KeyCode.CtrlC)))
        match (exit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Assert(false)
        }
    }

    @TestCase
    func paletteActionsCoverEveryCommandAndEscapePath(): Unit {
        let app = OhMyPiSkin()
        app.paletteOpen = true
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(!app.paletteOpen)

        for (index in 0..4) {
            app.paletteOpen = true
            app.palette.selected = index
            let result = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            if (index == 4) {
                match (result.flow) {
                    case ControlFlow.Exit => ()
                    case _ => @Assert(false)
                }
            } else {
                @Expect(app.paletteOpen, false)
            }
        }
        app.paletteOpen = true
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'z'))))
        @Expect(app.paletteOpen)
    }

    @TestCase
    func renderingCoversCompactFullUnicodeAndAsciiSurfaces(): Unit {
        let compactBackend = TestBackend(area: Rect(0, 0, 60, 20))
        let compactTerminal = Terminal(compactBackend, renderMode: RenderMode.Full)
        let compact = OhMyPiSkin()
        compact.caps = TerminalCapabilities(size: compactBackend.size(), unicode: false)
        _ = compactTerminal.draw { frame => compact.render(frame) }
        @Assert(compactBackend.snapshot().contains("terminal too small"))

        let backend = TestBackend(area: Rect(0, 0, 100, 30))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        let app = OhMyPiSkin()
        app.caps = TerminalCapabilities(size: backend.size(), unicode: true)
        _ = terminal.draw { frame => app.render(frame) }
        app.paletteOpen = true
        app.todoFocused = false
        app.showBusy = false
        app.heroMillis = 9000
        app.todoMillis = 240
        app.transcriptMillis = 750
        app.statusMillis = 249
        _ = terminal.draw { frame => app.render(frame) }
        app.caps = TerminalCapabilities(size: backend.size(), unicode: false)
        app.paletteOpen = false
        app.todoFocused = true
        _ = terminal.draw { frame => app.render(frame) }
        let snapshot = backend.snapshot()
        @Assert(snapshot.contains("oh my PI"))
        @Assert(snapshot.contains("Transcript"))
        @Assert(snapshot.contains("examples/oh_my_pi_skin"))
    }

    @TestCase
    func timerAnimationAndGeometryBoundaryModesStayCovered(): Unit {
        let app = OhMyPiSkin()
        let backend = TestBackend(area: Rect(0, 0, 100, 30))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        app.caps = TerminalCapabilities(size: backend.size(), unicode: false)
        _ = terminal.draw { frame => app.render(frame) }
        for (millis in [66, 660, 7999, 9000, 10000, 12000, 13000]) {
            _ = app.update(Event.Timer(TimerEvent(HERO_TIMER, elapsedMillis: millis)))
        }
        _ = app.update(Event.FocusIn)
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("oh my PI"))

        let narrowBackend = TestBackend(area: Rect(0, 0, 20, 1))
        let narrowTerminal = Terminal(narrowBackend, renderMode: RenderMode.Full)
        _ = narrowTerminal.draw { frame => app.render(frame) }
        @Assert(narrowBackend.snapshot().size > 0)
        let tinyBackend = TestBackend(area: Rect(0, 0, 1, 1))
        let tinyTerminal = Terminal(tinyBackend, renderMode: RenderMode.Full)
        _ = tinyTerminal.draw { frame => app.render(frame) }
        @Assert(tinyBackend.snapshot().size > 0)
    }
}
