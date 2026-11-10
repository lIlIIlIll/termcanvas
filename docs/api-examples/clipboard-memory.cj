package cjtui_api_example

import core.*

main(): Int64 {
    let memory = MemoryClipboard(text: "draft")
    memory.setText("hello")
    let clipboard: Clipboard = memory
    let caps = clipboard.capabilities()
    let read = clipboard.readText()
    let write = clipboard.writeText("updated")
    let statuses = [ClipboardStatus.Success, ClipboardStatus.Unavailable, ClipboardStatus.Unsupported,
        ClipboardStatus.Timeout, ClipboardStatus.TooLarge, ClipboardStatus.Failed]
    let custom = ClipboardCapabilities(true, false, "example", description: "Read only")
    let failure = ClipboardResult(ClipboardStatus.Failed, message: "unavailable", backend: "example")
    if (memory.getText() != "updated" || !caps.canRead || !caps.canWrite || caps.backend != "memory" ||
        !read.isSuccess() || read.text != "hello" || !write.isSuccess() || statuses.size != 6 ||
        custom.canWrite || custom.description != "Read only" || failure.isSuccess() ||
        failure.message != "unavailable" || failure.backend != "example") {
        throw IllegalStateException("clipboard failed")
    }
    match (read.status) {
        case ClipboardStatus.Success => ()
        case _ => throw IllegalStateException("clipboard status failed")
    }
    return 0
}
