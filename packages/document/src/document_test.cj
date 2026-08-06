package document

import core.{Buffer, Rect}
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DocumentFacadeTest {
    @TestCase
    func exposesDocumentModelAndView(): Unit {
        let doc = Document([
            DocumentLine(DocumentLineKind.Heading(1), "Title"),
            DocumentLine(DocumentLineKind.Paragraph, "body")
        ])
        let buffer = Buffer(Rect(0, 0, 16, 2))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(2, 0).symbol, "T")
        @Expect(DocumentView(doc).renderedLineCount(16), 2)
    }
}
