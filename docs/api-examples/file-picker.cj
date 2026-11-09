package cjtui_api_example

import core.*

main(): Int64 {
    let picker = FilePicker(path: ".")
    picker.setSearch("a-name-that-does-not-exist")
    if (picker.selectedEntry() != Some("..") || picker.selectedPath().isNone()) {
        throw IllegalStateException("picker parent entry failed")
    }
    match (picker.selectedInfo()) {
        case Some(info) => if (info.name != "..") { throw IllegalStateException("picker info failed") }
        case None => throw IllegalStateException("picker missing info")
    }
    picker.toggleHidden()
    if (!picker.showHidden) { throw IllegalStateException("picker hidden toggle failed") }
    picker.render(Rect(0, 0, 30, 6), Buffer(Rect(0, 0, 30, 6)))
    return 0
}
