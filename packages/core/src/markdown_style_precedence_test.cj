package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class MarkdownStylePrecedenceTest {
    @TestCase
    func explicitTextStyleSurvivesExplicitDocumentTheme(): Unit {
        let area = Rect(0, 0, 10, 1)
        let buffer = Buffer(area)
        let explicit = Style(fg: Color.Red)
        let theme = DocumentTheme(paragraph: Style(fg: Color.Blue))
        MarkdownView("hello", style: explicit, theme: theme).render(area, buffer)
        @Expect(buffer.getCell(0, 0).style, explicit)
    }
    @TestCase
    func omittedTextStyleFollowsExplicitDocumentTheme(): Unit {
        let area = Rect(0, 0, 10, 1)
        let buffer = Buffer(area)
        let theme = DocumentTheme(paragraph: Style(fg: Color.Blue))
        MarkdownView("hello", theme: theme).render(area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.paragraph)
    }

    @TestCase
    func omittedTextStyleFollowsApplicationTheme(): Unit {
        let area = Rect(0, 0, 10, 1)
        let buffer = Buffer(area)
        let theme = Theme(normal: Style(fg: Color.Green))
        buffer.setTheme(Some(theme))
        MarkdownView("hello").render(area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.normal)
    }
}
