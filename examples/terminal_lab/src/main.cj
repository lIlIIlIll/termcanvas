package terminal_lab

import core.*
import terminal.*
import diff.*

class TerminalLab {
    let transcript = TerminalTranscript(cols: 72, rows: 12)
    let diff = parseUnifiedDiff("--- a/app.cj\n+++ b/app.cj\n@@ -1,2 +1,2 @@\n-main old\n+main new\n context\n")
    var mode = "terminal"
    var status = "ready"

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
                status = "pty started"
                UpdateResult.next()
            case Event.PtyOutput(_, stream, bytes) =>
                let prefix = match (stream) {
                    case PtyOutputStream.Stdout => ""
                    case PtyOutputStream.Stderr => "[stderr] "
                }
                transcript.append(prefix + unsafe { String.fromUtf8Unchecked(bytes) })
                UpdateResult.next()
            case Event.PtyExited(_, _) =>
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
