package editor

import core.{Buffer, KeyCode, KeyEvent, Rect}
import std.unittest.*
import std.unittest.testmacro.*

@Test
class EditorFacadeTest {
    @TestCase
    func exposesTextBufferAndTextArea(): Unit {
        let model = TextBuffer(text: "one")
        _ = model.insert(TextPosition(0, 3), " two")
        @Expect(model.text(), "one two")

        let area = TextArea(value: model.text(), cursor: model.text().size)
        _ = area.handle(KeyEvent(KeyCode.Char(r'!')))
        @Expect(area.value, "one two!")

        let buffer = Buffer(Rect(0, 0, 12, 1))
        area.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "o")
    }

    @TestCase
    func exposesMarkdownEditingHelpers(): Unit {
        let spans = markdownDecorations("# Title")
        @Expect(spans.size > 0)

        let area = TextArea(value: "word", cursor: 0, markdownEditing: true)
        _ = MarkdownEditorBehavior().toggleBold(area)
        @Expect(area.value.contains("**"))
    }
}
