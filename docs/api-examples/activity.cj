package cjtui_api_example

import core.*

main(): Int64 {
    let step = ActivityStep("Compile", status: TranscriptItemStatus.Running, detail: "core", duration: "2s")
    let buffer = Buffer(Rect(0, 0, 60, 18))
    ActivityTimeline([step]).render(Rect(0, 0, 50, 2), buffer)
    if (step.title != "Compile" || transcriptStatusLabel(TranscriptItemStatus.Done) != "completed" ||
        statusMark(TranscriptItemStatus.Running, activityFrame: 0) == statusMark(TranscriptItemStatus.Running, activityFrame: 1)) {
        throw IllegalStateException("activity state failed")
    }
    _ = transcriptStatusStyle(step.status, Style.default())
    let card = transcriptCardDocument(TranscriptItem("compile", title: step.title, status: step.status))
    if (card.lines.size == 0) { throw IllegalStateException("card is empty") }
    let dialog = RequestDialog(title: "Run task?", buttons: ["Cancel", "Run"])
    dialog.render(Rect(0, 2, 60, 16), buffer)
    _ = dialog.handle(KeyEvent(KeyCode.Right))
    if (dialog.handle(KeyEvent(KeyCode.Enter)) != Some("Run") || dialog.selected != 1) {
        throw IllegalStateException("dialog selection failed")
    }
    return 0
}
