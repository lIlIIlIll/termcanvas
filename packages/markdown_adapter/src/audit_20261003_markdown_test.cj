package markdown_adapter

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003MarkdownTest {
    @TestCase
    func linksPreserveEnclosingStrongAndEmphasisModifiers(): Unit {
        let doc = markdownDocument("***[link](https://example.com)***")
        @Assert(doc.lines.size, 1)
        @Assert(doc.lines[0].spans.size, 1)
        let span = doc.lines[0].spans[0]
        @Expect(span.text, "link")
        @Expect(span.linkUrl, Some("https://example.com"))
        @Expect(span.style.modifier.bold)
        @Expect(span.style.modifier.italic)
        match (span.style.fg) { case Color.Blue => (); case _ => @Expect(false) }
    }
}
