package cjtui_api_example

import core.*

main(): Int64 {
    let notices = ToastManager(maxToasts: Some(2))
    notices.push(Toast("Saved", kind: Some(ToastKind.Success), ttl: 2))
    notices.push(Toast("Queued", ttl: 1))
    let buffer = Buffer(Rect(0, 0, 40, 10))
    notices.render(Rect(0, 0, 40, 2), buffer)
    notices.tick()
    if (notices.count() != 1) { throw IllegalStateException("toast expiration failed") }
    notices.tick()
    if (notices.count() != 0) { throw IllegalStateException("toast cleanup failed") }
    Spinner(label: "Working", frame: 1).render(Rect(0, 0, 20, 1), buffer)
    let dialog = ConfirmDialog("Run task?")
    _ = dialog.handle(KeyEvent(KeyCode.Right))
    if (dialog.handle(KeyEvent(KeyCode.Enter)) != Some(true)) { throw IllegalStateException("confirm failed") }
    return 0
}
