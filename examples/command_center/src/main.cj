package cjtui_command_center

import core.*

class CommandCenter {
    var count: Int64 = 0
    var status = "ready"
    var frame: Int64 = 0
    let toasts = ToastManager()
    let palette = CommandPalette([
        MenuItem("Increment", action: "inc"),
        MenuItem("Run async task", action: "async"),
        MenuItem("Start timer", action: "timer"),
        MenuItem("Stop timer", action: "stop"),
        MenuItem("Quit", action: "quit")
    ])
    let dialog = Dialog(title: "Confirm", body: "Command center is ready.", buttons: ["Cancel", "Run"], selected: 1)

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r'i') => UpdateResult.withCommand(Command.Message("inc"))
                case KeyCode.Char(r'a') => UpdateResult.withCommand(Command.AsyncTask("job", { => Event.Message("async_done") }))
                case KeyCode.Char(r't') => UpdateResult.withCommand(Command.StartTimer(TimerSpec("pulse", Duration.millisecond * 500)))
                case KeyCode.Char(r's') => UpdateResult.withCommand(Command.StopTimer("pulse"))
                case _ => UpdateResult.next()
            }
            case Event.Message(action) => applyAction(action)
            case Event.AsyncStarted(id) =>
                status = "started " + id
                UpdateResult.next()
            case Event.AsyncCompleted(_, inner) =>
                update(inner)
            case Event.Timer(timer) =>
                count += timer.firedCount
                status = "timer fired ${timer.firedCount}"
                toasts.push(Toast(status, ttl: 3))
                UpdateResult.next()
            case Event.Tick(_) =>
                frame++
                toasts.tick()
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    private func applyAction(action: String): UpdateResult {
        match (action) {
            case "inc" =>
                count++
                status = "count = ${count}"
                toasts.push(Toast(status, ttl: 3))
                UpdateResult.next()
            case "async_done" =>
                status = "async completed"
                toasts.push(Toast(status, ttl: 4, style: Style(fg: Color.Black, bg: Color.Green)))
                UpdateResult.next()
            case "quit" => UpdateResult.exit()
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(8), Constraint.Length(5), Constraint.Length(3)]).withGap(1).withMargin(Spacing.all(1)).split(frame.area)
        frame.renderWidget(MenuBar(["File", "Command", "Jobs"], selected: 1), rows[0])
        let cols = Layout.horizontal([Constraint.Percent(48), Constraint.Min(24)]).withGap(1).split(rows[1])
        frame.renderWidget(Paragraph("count: ${count}\nstatus: ${status}\nkeys: i increment, a async, t timer, s stop", block: Block(title: "Runtime")), cols[0])
        frame.renderWidget(palette, cols[1])
        frame.renderWidget(dialog, rows[2])
        frame.renderWidget(toasts, rows[3])
        frame.renderWidget(Spinner(label: "events", frame: this.frame), Rect(rows[0].right - 14, rows[0].y, 14, 1))
    }
}

main(): Int64 {
    let app = CommandCenter()
    App(targetFps: 8).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
