package cjtui_api_example

import core.*

main(): Int64 {
    let composer = Composer(slashHints: ["/help", "/history"])
    composer.restoreDraft("/he")
    if (composer.currentSlashHints().size != 1 || composer.completionVisible()) {
        throw IllegalStateException("composer hint failed")
    }
    composer.restoreDraft("")
    _ = composer.paste("long payload", collapseThreshold: 4)
    if (composer.draftText() != Some("long payload") || composer.visualHeight(20, 4) < 1) {
        throw IllegalStateException("composer paste failed")
    }
    let buffer = Buffer(Rect(0, 0, 40, 4))
    composer.render(Rect(0, 0, 40, 4), buffer)
    _ = composer.cursorPosition(Rect(0, 0, 40, 4))
    match (composer.handle(KeyEvent(KeyCode.Enter))) {
        case Some(result) => if (result.text != "long payload") { throw IllegalStateException("composer submission failed") }
        case None => throw IllegalStateException("composer did not submit")
    }
    _ = composer.handle(KeyEvent(KeyCode.Up))
    if (composer.draftText() != Some("long payload")) { throw IllegalStateException("composer history failed") }
    return 0
}
