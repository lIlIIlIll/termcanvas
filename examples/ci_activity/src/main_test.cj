package cjtui_ci_activity

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class CiActivityTest {
    @TestCase
    func completedTasksKeepTheirDurations(): Unit {
        let app = CiActivity()
        let backend = TestBackend(area: Rect(0, 0, 120, 18))
        let terminal = Terminal(backend)
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 60000)))
        _ = terminal.draw { frame => app.render(frame) }
        let snapshot = backend.snapshot()
        @Expect(snapshot.contains("bg_202 done 0m1s"))
        @Expect(snapshot.contains("0m18s"))
        @Expect(snapshot.contains("0m30s"))
        @Expect(snapshot.contains("1m0s"))
    }

    @TestCase
    func simulationTransitionsAndControls(): Unit {
        let app = CiActivity()
        let backend = TestBackend(area: Rect(0, 0, 100, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("Cross-platform CI"))
        @Expect(backend.snapshot().contains("● ● ◌ ● ● ◌ ● ◌"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.offset, 1)
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("1 above"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        @Expect(app.offset, 0)
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 18000)))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("1 still running"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 12000)))
        @Expect(app.elapsed, 18000)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 12000)))
        _ = terminal.draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("All simulated checks finished"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'))))
        @Expect(app.elapsed, 0)
        match (app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q')))).flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
    @TestCase
    func cyclesIconsAndRespectsAsciiTerminal(): Unit {
        let app = CiActivity()
        let area = Rect(0, 0, 100, 24)
        let unicode = Buffer(area)
        app.render(Frame(area, unicode))
        @Expect(unicode.getCell(1, 5).symbol, "✓")
        let backend = TestBackend(area: area)
        backend.draw(unicode)
        @Expect(backend.snapshot().contains("icons: Unicode"))
        @Expect(backend.snapshot().contains("◐ running"))
        @Expect(backend.snapshot().contains("n icons"))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'n'))))
        let nerd = Buffer(area)
        app.render(Frame(area, nerd))
        @Expect(nerd.getCell(1, 5).symbol, "\u{f058}")
        backend.draw(nerd)
        @Expect(backend.snapshot().contains("icons: Nerd Font"))
        @Expect(backend.snapshot().contains("\u{f110} running"))
        _ = app.update(Event.Capabilities(TerminalCapabilities(unicode: false)))
        let asciiTerminal = Buffer(area)
        asciiTerminal.setCapabilities(TerminalCapabilities(unicode: false))
        app.render(Frame(area, asciiTerminal))
        @Expect(asciiTerminal.getCell(1, 5).symbol, "+")
        backend.draw(asciiTerminal)
        @Expect(backend.snapshot().contains("icons: Nerd Font"))
        let fallbackText = backend.snapshot()
        @Expect(fallbackText.contains("| running"))
        let fallbackBytes = unsafe { fallbackText.rawData() }
        for (b in fallbackBytes) { @Expect(b < 128) }

        _ = app.update(Event.Capabilities(TerminalCapabilities(unicode: true)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'n'))))
        let ascii = Buffer(area)
        app.render(Frame(area, ascii))
        @Expect(ascii.getCell(1, 5).symbol, "+")
        backend.draw(ascii)
        @Expect(backend.snapshot().contains("icons: ASCII"))
        let asciiText = backend.snapshot()
        let asciiBytes = unsafe { asciiText.rawData() }
        for (b in asciiBytes) { @Expect(b < 128) }
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 30000)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r' '))))
        let completed = Buffer(area)
        app.render(Frame(area, completed))
        backend.draw(completed)
        let completedText = backend.snapshot()
        @Expect(completedText.contains("All jobs completed"))
        let completedBytes = unsafe { completedText.rawData() }
        for (b in completedBytes) { @Expect(b < 128) }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'n'))))
        let again = Buffer(area)
        app.render(Frame(area, again))
        @Expect(again.getCell(1, 5).symbol, "✓")
    }

    @TestCase
    func compactScreenPlacesLegendAndControlsAfterTasks(): Unit {
        let app = CiActivity()
        let area = Rect(0, 0, 80, 12)
        let buffer = Buffer(area)
        app.render(Frame(area, buffer))
        @Expect(buffer.getCell(3, 8).symbol, "2")
        @Expect(buffer.getCell(1, 9).symbol, "●")
        @Expect(buffer.getCell(2, 9).symbol, " ")
        @Expect(buffer.getCell(1, 10).symbol, "d")
        @Expect(buffer.getCell(1, 11).symbol, "n")
        _ = app.update(Event.Capabilities(TerminalCapabilities(unicode: false)))
        let ascii = Buffer(area)
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        app.render(Frame(area, ascii))
        @Expect(ascii.getCell(1, 9).symbol, "+")
        let roomyArea = Rect(0, 0, 120, 36)
        let roomy = Buffer(roomyArea)
        let fresh = CiActivity()
        fresh.render(Frame(roomyArea, roomy))
        @Expect(roomy.getCell(3, 12).symbol, "2")
        @Expect(roomy.getCell(1, 13).symbol, " ")
        @Expect(roomy.getCell(1, 14).symbol, "●")
        @Expect(roomy.getCell(2, 14).symbol, " ")
        @Expect(roomy.getCell(1, 15).symbol, "d")
        @Expect(roomy.getCell(1, 16).symbol, "n")
    }

}
