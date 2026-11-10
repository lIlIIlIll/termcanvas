package cjtui_api_example

import core.*

main(): Int64 {
    let narrow = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Narrow)
    let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
    let text = "A界"
    let clusters = graphemeClusters(text)
    let wideClusters = graphemeClusters(text, options: wide)
    let made = GraphemeCluster("A", 0, 1, 1)
    if (clusters.size != 2 || wideClusters.size != 2 || made.text != "A" || made.startOffset != 0 ||
        made.endOffset != 1 || made.width != 1 || clusters[1].startOffset != 1 || clusters[1].endOffset != 4 ||
        displayWidth(text) != 3 || displayWidth(text, options: narrow) != 3 ||
        displayWidth(r'界') != 2 || displayWidth(r'界', options: wide) != 2 ||
        graphemeDisplayWidth("界") != 2 || graphemeDisplayWidth("界", options: wide) != 2) {
        throw IllegalStateException("incorrect display width")
    }
    if (graphemePrefix(text, 1) != "A" || graphemePrefix(text, 3, options: wide) != text ||
        cut("abcdef", 5) != "ab..." || clampToRuneBoundary(text, 2) != 1 ||
        previousGraphemeOffset(text, 4) != 1 || nextGraphemeOffset(text, 1) != 4) {
        throw IllegalStateException("incorrect text boundary")
    }
    let lines = wrapText("abc", 2, WrapMode.Character)
    let words = wrapText("a b", 2, WrapMode.Word, options: narrow)
    if (lines.size != 2 || lines[0] != "ab" || lines[1] != "c" || words.size != 2) {
        throw IllegalStateException("incorrect wrapping")
    }
    return 0
}
