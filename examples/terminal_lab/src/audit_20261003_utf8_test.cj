package terminal_lab

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003PtyUtf8Test {
    @TestCase
    func splitUtf8IsDecodedAcrossOutputEvents(): Unit {
        let app = TerminalLab()
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xE4]))
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xB8, 0xAD]))
        @Expect(app.transcript.screen.cell(0, 2).symbol, "中")
    }

    @TestCase
    func invalidBytesAreReplacedWithoutLosingFollowingText(): Unit {
        let app = TerminalLab()
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xFF, b'x']))
        @Expect(app.transcript.screen.cell(0, 2).symbol, "\u{FFFD}")
        @Expect(app.transcript.screen.cell(1, 2).symbol, "x")
    }

    @TestCase
    func stdoutAndStderrKeepIndependentIncompleteSequences(): Unit {
        let app = TerminalLab()
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xE4]))
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stderr, [b'!']))
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xB8, 0xAD]))
        @Expect(app.transcript.screen.cell(10, 2).symbol, "中")
    }

    @TestCase
    func exitFlushesIncompleteTextAndRestartClearsItsState(): Unit {
        let app = TerminalLab()
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [0xE4]))
        _ = app.update(Event.PtyExited("demo", PtyExitStatus.Exited(0)))
        @Expect(app.transcript.screen.cell(0, 2).symbol, "\u{FFFD}")
        _ = app.update(Event.PtyStarted("demo"))
        _ = app.update(Event.PtyOutput("demo", PtyOutputStream.Stdout, [b'x']))
        @Expect(app.transcript.screen.cell(1, 2).symbol, "x")
    }
}
