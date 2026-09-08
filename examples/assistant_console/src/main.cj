package cjtui_assistant_console

import core.*

class AssistantConsole {
    let transcript = Transcript(items: [
        TranscriptItem("u1", title: "User", body: Document.plain("Run the release checks")),
        TranscriptItem("a1", title: "Assistant", body: Document.plain("I will prepare a plan and ask for approval."), status: TranscriptItemStatus.Done)
    ])
    let composer = Composer(value: "/run release_gate", slashHints: ["/run", "/review", "/open", "/clear"])
    let steps = [
        ActivityStep("Plan", status: TranscriptItemStatus.Done, detail: "examples rewrite"),
        ActivityStep("Implement", status: TranscriptItemStatus.Pending, detail: "12 real apps"),
        ActivityStep("Validate", status: TranscriptItemStatus.Pending, detail: "release gate")
    ]
    let request = RequestDialog(title: "Approval", body: "Run release gate after rewrite?", detail: Document.plain("This may take a while."), risk: "Long-running validation")
    var showRequest = true
    var status = "ready"

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return ControlFlow.Exit
                    case KeyCode.Char(r'a') => showRequest = true
                    case KeyCode.Esc => showRequest = false
                    case _ =>
                        if (showRequest) {
                            match (request.handle(key)) {
                                case Some(action) => status = "approval: " + action; showRequest = false
                                case None => ()
                            }
                        } else {
                            _ = composer.handle(key)
                        }
                }
            case Event.Paste(text) =>
                if (!showRequest) {
                    _ = composer.paste(text)
                }
            case _ => ()
        }
        ControlFlow.Continue
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Min(8), Constraint.Length(5), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        let cols = Layout.horizontal([Constraint.Percent(62), Constraint.Min(20)]).withGap(1).split(rows[0])
        frame.renderWidget(TranscriptView(transcript, block: Block(title: "Transcript")), cols[0])
        frame.renderWidget(ActivityTimeline(steps, block: Block(title: "Activity")), cols[1])
        frame.renderWidget(composer, rows[1])
        if (showRequest) {
            frame.renderWidget(request, Rect(frame.area.x + 4, frame.area.y + 2, max(20, frame.area.width - 8), max(8, frame.area.height - 6)))
        }
        frame.renderWidget(StatusBar(left: "assistant_console  a approval  esc close  q quit", right: status, style: Style(fg: Color.White, bg: Color.Black)), rows[2])
        if (!showRequest) { frame.setCursor(composer.area.cursorPosition(rows[1])) }
    }
}

main(): Int64 {
    let app = AssistantConsole()
    App(bracketedPaste: true, hideCursor: false).run(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
