package cjtui_assistant_console

import core.*

class AssistantConsole {
    let focus = FocusManager()
    let interaction: ModalFocusState
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

    init() {
        focus.add("composer")
        interaction = ModalFocusState(focus, keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.F(2))], "approval")]))
        _ = interaction.open("approval", ["cancel", "confirm"])
    }

    private func synchronizeRequest(): Unit {
        if (showRequest && interaction.active().isNone()) { _ = interaction.open("approval", ["cancel", "confirm"]) }
        if (!showRequest && interaction.active().isSome()) { _ = interaction.close() }
    }

    func update(event: Event): ControlFlow {
        synchronizeRequest()
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) { case KeyCode.CtrlC => return ControlFlow.Exit; case _ => () }
                if (interaction.handle(key)) {
                    showRequest = interaction.active().isSome()
                    request.selected = if (interaction.focus().current() == Some("confirm")) { 1 } else { 0 }
                    return ControlFlow.Continue
                }
                if (interaction.active().isSome()) {
                    match (request.handle(key)) {
                        case Some(action) => status = "approval: " + action; _ = interaction.close(); showRequest = false
                        case None => _ = interaction.focus().focus(if (request.selected == 1) { "confirm" } else { "cancel" })
                    }
                    return ControlFlow.Continue
                }
                if (interaction.actionFor(key) == Some("approval")) {
                    _ = interaction.open("approval", ["cancel", "confirm"])
                    request.selected = 0
                    showRequest = true
                } else { _ = composer.handle(key) }
            case Event.Paste(text) => if (interaction.active().isNone()) { _ = composer.paste(text) }
            case _ => ()
        }
        ControlFlow.Continue
    }

    func render(frame: Frame): Unit {
        synchronizeRequest()
        let rows = Layout.vertical([Constraint.Min(8), Constraint.Length(5), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        let cols = Layout.horizontal([Constraint.Percent(62), Constraint.Min(20)]).withGap(1).split(rows[0])
        frame.renderWidget(TranscriptView(transcript, block: Block(title: "Transcript")), cols[0])
        frame.renderWidget(ActivityTimeline(steps, block: Block(title: "Activity")), cols[1])
        frame.renderWidget(composer, rows[1])
        if (showRequest) {
            frame.renderWidget(request, Rect(frame.area.x + 4, frame.area.y + 2, max(20, frame.area.width - 8), max(8, frame.area.height - 6)))
        }
        frame.renderWidget(StatusBar(left: "assistant_console  F2 approval  esc close  Ctrl-C quit", right: status, style: Style(fg: Color.White, bg: Color.Black)), rows[2])
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
