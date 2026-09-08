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
}
