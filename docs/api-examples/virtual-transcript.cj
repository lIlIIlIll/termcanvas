package cjtui_api_example

import core.*

class ExampleTranscript <: VirtualTranscriptSource {
    public func size(): Int64 { 2 }
    public func itemId(index: Int64): String { "item-${index}" }
    public func revision(_: Int64): Int64 { 0 }
    public func document(index: Int64, _: Int64, _: String): Document { Document.plain("message ${index}") }
}

main(): Int64 {
    let state = VirtualTranscriptState(followBottom: false)
    state.scrollBy(1, 10, 3)
    if (state.scrollTop != 1 || state.followBottom) { throw IllegalStateException("transcript scroll failed") }
    state.end(10, 3)
    if (!state.followBottom || state.scrollTop != 7) { throw IllegalStateException("transcript follow failed") }
    state.home()
    let view = VirtualTranscriptView(ExampleTranscript(), state: state, instrumentationEnabled: true)
    view.setThemeKey("default")
    view.setCardChrome(false)
    view.setUnicode(true)
    view.setCardTheme(TranscriptCardTheme())
    view.clearCardTheme()
    let buffer = Buffer(Rect(0, 0, 30, 4))
    view.render(buffer.area, buffer)
    if (view.totalRows() < 2 || view.materializedCount() < 1 || view.lastVisibleRanges.size < 1 ||
        !view.handle(KeyEvent(KeyCode.End))) { throw IllegalStateException("virtual transcript failed") }
    _ = view.metrics()
    _ = view.dirtyRectForItemRevision("item-0")
    if (!view.invalidateItem("item-0")) { throw IllegalStateException("invalidation failed") }
    return 0
}
