package markdown_adapter

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class ThemedMarkdownViewTest {
    @TestCase
    func applicationThemeChangesRecolorConvertedTextAndLinks(): Unit {
        let view = ThemedMarkdownView("Text [link](https://example.test)")
        let first = Theme(normal: Style(fg: Color.White, bg: Color.Blue), accent: Style(fg: Color.Green, bg: Color.Blue))
        let second = Theme(normal: Style(fg: Color.White, bg: Color.Red), accent: Style(fg: Color.Yellow, bg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 30, 2))
        buffer.setTheme(first)
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, first.adapted(buffer.capabilities()).normal)
        @Expect(buffer.getCell(5, 0).style, first.adapted(buffer.capabilities()).accent)
        buffer.setTheme(second)
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.adapted(buffer.capabilities()).normal)
        @Expect(buffer.getCell(5, 0).style, second.adapted(buffer.capabilities()).accent)
        view.setText("[new](https://example.test)")
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "n")
        @Expect(buffer.getCell(0, 0).style, second.adapted(buffer.capabilities()).accent)
    }

    @TestCase
    func explicitDocumentThemeAndConfiguredSyntaxRemainAuthoritative(): Unit {
        let custom = DocumentTheme(link: Style(fg: Color.Magenta, bg: Color.Blue))
        let view = ThemedMarkdownView("[link](https://example.test)", theme: custom)
        let buffer = Buffer(Rect(0, 0, 40, 3))
        buffer.setTheme(Theme(accent: Style(fg: Color.Green)))
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, custom.link)
        buffer.setTheme(Theme(accent: Style(fg: Color.Red)))
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, custom.link)

        let syntax = parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\nkeywords task\nstyle keyword cyan bold\nend")
        let code = ThemedMarkdownView("```workflow\ntask item\n```", syntax: syntax)
        let theme = Theme(surface: Style(fg: Color.White, bg: Color.Blue))
        buffer.setTheme(theme)
        code.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Cyan, bg: Color.Blue, modifier: Modifier.strong()))
        @Expect(buffer.getCell(5, 0).style, theme.adapted(buffer.capabilities()).surface)
    }

    @TestCase
    func noApplicationThemeMatchesExistingMarkdownDefaults(): Unit {
        let old = Buffer(Rect(0, 0, 25, 2))
        let current = Buffer(old.area)
        let text = "[link](https://example.test)"
        DocumentView(markdownDocument(text)).render(old.area, old)
        ThemedMarkdownView(text).render(current.area, current)
        @Expect(current.getCell(0, 0), old.getCell(0, 0))
    }
}
