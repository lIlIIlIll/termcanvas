package terminal_lab

import core.*
import terminal.*
import diff.*
import std.collection.*

// PTY reads may end inside a UTF-8 sequence. Keep only its incomplete suffix;
// never construct a String from unchecked, externally supplied bytes.
class PtyTextDecoder {
    private var pending: Array<Byte> = []

    func feed(bytes: Array<Byte>): String {
        let collected = ArrayList<Byte>()
        collected.add(all: pending)
        collected.add(all: bytes)
        let data = collected.toArray()
        let text = StringBuilder()
        var offset: Int64 = 0
        while (offset < data.size) {
            let first = data[offset]
            let width: Int64 = if (first < 0x80) { 1 }
                else if (first >= 0xC2 && first <= 0xDF) { 2 }
                else if (first >= 0xE0 && first <= 0xEF) { 3 }
                else if (first >= 0xF0 && first <= 0xF4) { 4 }
                else { 0 }
            var invalid = width == 0
            for (i in 1..min(width, data.size - offset)) {
                if ((data[offset + i] & 0xC0) != 0x80) { invalid = true }
            }
            if (!invalid && data.size - offset < width) { break }
            if (!invalid) {
                try {
                    let (rune, length) = Rune.fromUtf8(data, offset)
                    text.append(rune.toString())
                    offset += length
                    continue
                } catch (_: IllegalArgumentException) { () }
            }
            text.append("\u{FFFD}")
            offset++
        }
        pending = data[offset..].clone()
        text.toString()
    }

    func finish(): String {
        let result = if (pending.isEmpty()) { "" } else { "\u{FFFD}" }
        pending = []
        result
    }
}

class TerminalLab {
    let transcript = TerminalTranscript(cols: 72, rows: 12)
    let diff = parseUnifiedDiff("--- a/app.cj\n+++ b/app.cj\n@@ -1,2 +1,2 @@\n-main old\n+main new\n context\n")
    var mode = "terminal"
    var status = "ready"
    private let stdoutDecoder = PtyTextDecoder()
    private let stderrDecoder = PtyTextDecoder()

    init() {
        transcript.append("\u{1B}[32mterminal ready\u{1B}[0m\n")
        transcript.append("stdout and stderr are separate PTY events\n")
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r't') => mode = "terminal"; UpdateResult.next()
                case KeyCode.Char(r'd') => mode = "diff"; UpdateResult.next()
                case KeyCode.Char(r'r') =>
                    status = "starting pty"
                    UpdateResult.withCommand(Command.PtyStart("demo", PtySpec("/bin/sh", args: ["-lc", "printf 'pty ready\\n'; printf 'warn\\n' >&2"])))
                case _ => UpdateResult.next()
            }
            case Event.PtyStarted(_) =>
                _ = stdoutDecoder.finish()
                _ = stderrDecoder.finish()
                status = "pty started"
                UpdateResult.next()
            case Event.PtyOutput(_, stream, bytes) =>
                let text = match (stream) {
                    case PtyOutputStream.Stdout => stdoutDecoder.feed(bytes)
                    case PtyOutputStream.Stderr =>
                        let decoded = stderrDecoder.feed(bytes)
                        if (decoded.isEmpty()) { "" } else { "[stderr] " + decoded }
                }
                if (!text.isEmpty()) { transcript.append(text) }
                UpdateResult.next()
            case Event.PtyExited(_, _) =>
                let remaining = stdoutDecoder.finish() + stderrDecoder.finish()
                if (!remaining.isEmpty()) { transcript.append(remaining) }
                status = "pty exited"
                UpdateResult.next()
            case Event.PtyFailed(_, message) =>
                status = "pty failed"
                transcript.append("failed: " + message + "\n")
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(8), Constraint.Length(1)]).withMargin(Spacing.all(1)).split(frame.area)
        frame.renderWidget(MenuBar(["Terminal", "Diff", "PTY"], selected: if (mode == "diff") { 1 } else { 0 }), rows[0])
        if (mode == "diff") {
            frame.renderWidget(DiffView(diff, block: Block(title: "Unified diff")), rows[1])
        } else {
            frame.renderWidget(TerminalView(transcript, block: Block(title: "Terminal transcript"), search: "pty"), rows[1])
        }
        frame.renderWidget(StatusBar(left: "terminal_lab  t terminal  d diff  r run pty  q quit", right: status, style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

main(): Int64 {
    let app = TerminalLab()
    let runtime = App()
    runtime.attachPtyRuntime(LinuxPtyRuntime())
    runtime.runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
