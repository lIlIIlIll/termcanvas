package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TranscriptWidthLayoutTest {
    @TestCase
    func allocatesAllWideWrappedBodyRows(): Unit {
        let item = TranscriptItem("one", title: "T", stateLabel: "x", body: Document.plain("··········"))
        let area = Rect(0, 0, 12, 8)
        let options = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let actual = Buffer(area)
        actual.setTextWidthOptions(options)
        TranscriptView(Transcript(items: [item])).render(area, actual)
        let expected = Buffer(area)
        expected.setTextWidthOptions(options)
        DocumentView(transcriptCardDocument(item)).render(area, expected)
        for (y in 0..area.height) {
            for (x in 0..area.width) {
                @Expect(actual.getCell(x, y).symbol, expected.getCell(x, y).symbol)
            }
        }
    }
    @TestCase
    func wideWrappedPreviousItemDoesNotHideSelectedItem(): Unit {
        let first = TranscriptItem("one", title: "T", stateLabel: "x", body: Document.plain("··········"))
        let second = TranscriptItem("two", title: "S", stateLabel: "x", body: Document.plain("tail"))
        let view = TranscriptView(Transcript(items: [first, second]), selected: 1)
        let area = Rect(0, 0, 12, 5)
        let buffer = Buffer(area)
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        view.render(area, buffer)
        @Expect(view.offset, 1)
    }
}
