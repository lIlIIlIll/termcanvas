package cjtui_api_example

import core.*

class ExampleSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "task" }
    public func revision(_: Int64): Int64 { 1 }
    public func document(_: Int64, _: Int64, _: String): Document { Document.plain("Building") }
}

main(): Int64 {
    let source: VirtualTranscriptSource = ExampleSource()
    if (source.size() != 1 || source.generation() != 0 || source.itemId(0) != "task" || source.revision(0) != 1 ||
        source.itemTitle(0) != "" || source.itemTitleForWidth(0, 20) != "" || source.itemFooter(0) != "" ||
        !source.itemUsesCardChrome(0) || source.itemUsesCompactCardChrome(0) || source.itemCardTheme(0).isSome() ||
        source.itemAppendOnlyText(0, 20, "default").isSome() ||
        source.itemAppendOnlyTextWithTheme(0, 20, "default", Option<Theme>.None).isSome() ||
        source.documentWithTheme(0, 20, "default", Option<Theme>.None).lines.size != 1) {
        throw IllegalStateException("transcript source failed")
    }
    return 0
}
