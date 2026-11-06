package markdown_adapter

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class MarkdownSemanticThemeTest {
    @TestCase
    func documentThemeUsesSemanticRolesAcrossHeadingsAndText(): Unit {
        let normal = Style(fg: Color.White, bg: Color.Blue)
        let heading = Style(fg: Color.Yellow, bg: Color.Blue)
        let theme = Theme(normal: normal, heading: heading, accent: Style(fg: Color.Green, bg: Color.Blue),
            secondary: Style(fg: Color.Cyan, bg: Color.Blue), error: Style(fg: Color.Red, bg: Color.Blue),
            surface: Style(fg: Color.White, bg: Color.Black))
        let documentTheme = documentThemeFromTheme(theme)
        let doc = markdownDocument("# Heading\n\nText and [link](https://example.test)", theme: documentTheme)
        @Expect(doc.lines[0].spans[0].style, heading)
        @Expect(doc.lines[2].spans[0].style, normal)
        @Expect(doc.lines[2].spans[1].style, theme.accent)
        @Expect(documentTheme.headingStyle(6), heading)
        @Expect(documentTheme.diagnostic, theme.error)
        @Expect(documentTheme.code, theme.surface)
        @Expect(documentTheme.emphasis, StyleOverride(italic: Some(true)).apply(normal))
    }
}
