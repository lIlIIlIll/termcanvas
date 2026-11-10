package cjtui_api_example

import core.*

main(): Int64 {
    let item = TranscriptItem("build", title: "Build", status: TranscriptItemStatus.Running,
        body: Document([DocumentLine(DocumentLineKind.Paragraph, "Compiling")]),
        options: [TranscriptCardOption("Details", selected: true)])
    let transcript = Transcript(items: [item])
    let second = TranscriptItem("test", title: "Test", status: TranscriptItemStatus.Pending)
    transcript.append(second)
    if (transcript.size() != 2 || transcript.get(2).isSome() || transcript.toArray().size != 2) {
        throw IllegalStateException("transcript collection failed")
    }
    let view = TranscriptView(transcript, cardTheme: Some(TranscriptCardTheme(bodyLimit: 1)))
    let buffer = Buffer(Rect(0, 0, 50, 8))
    view.render(Rect(0, 0, 50, 8), buffer)
    if (!view.handle(KeyEvent(KeyCode.Enter), 8) || !item.collapsed ||
        !transcript.toggleCollapsed("build") || item.collapsed || transcript.toggleCollapsed("missing")) {
        throw IllegalStateException("transcript fold failed")
    }
    if (!view.handle(KeyEvent(KeyCode.Down), 8) || view.selected != 1 || item.title != "Build") {
        throw IllegalStateException("transcript selection failed")
    }
    return 0
}
