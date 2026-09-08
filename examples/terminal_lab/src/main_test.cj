package terminal_lab

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalLabTest {
    @TestCase
    func ptyEventsDriveTheRealTranscriptAndStatus(): Unit {
        let app = TerminalLab()

        _ = app.update(Event.PtyStarted("demo"))
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stderr, [b'w', b'a', b'r', b'n', b'i', b'n', b'g', b'\n']))
        _ = app.update(Event.PtyExited("demo", PtyExitStatus.Exited(0)))

        @Expect(app.status, "pty exited")

        let backend = TestBackend(area: Rect(0, 0, 74, 16))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        let snapshot = backend.snapshot()
        @Assert(snapshot.contains("Terminal transcript"))
        @Assert(snapshot.contains("[stderr] warning"))
        @Assert(snapshot.contains("pty exited"))
    }

    @TestCase
    func modeSwitchAndPtyFailurePathsUpdateTheTranscript(): Unit {
        let app = TerminalLab()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'd'))))
        @Expect(app.mode, "diff")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r't'))))
        @Expect(app.mode, "terminal")
        let start = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'r'))))
        match (start.command) {
            case Command.PtyStart(_, _) => ()
            case _ => @Expect(false)
        }
        _ = app.update(Event.PtyFailed("demo", "permission denied"))
        @Expect(app.status, "pty failed")
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [b'o', b'k', b'\n']))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        let backend = TestBackend(area: Rect(0, 0, 90, 18))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("Terminal transcript"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'd'))))
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("main new"))
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (quit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
