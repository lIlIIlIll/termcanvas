package cjtui_api_example

import core.*

main(): Int64 {
    let span = RichSpan("Guide", linkUrl: Some("https://example.test"), sourceRange: Some("0:5"))
    let title = DocumentLine(DocumentLineKind.Heading(1), [span])
    let paragraph = DocumentLine(DocumentLineKind.Paragraph, "Hello")
    let image = DocumentLine.image(MediaSource("logo", "logo.png", alt: "Logo"))
    let kinds = [DocumentLineKind.ListItem(true), DocumentLineKind.Quote, DocumentLineKind.CodeBlock,
        DocumentLineKind.TableRow, DocumentLineKind.TableHeader, DocumentLineKind.HorizontalRule,
        DocumentLineKind.TaskListItem(false), DocumentLineKind.Image, DocumentLineKind.Diagnostic,
        DocumentLineKind.Html, DocumentLineKind.Strikethrough, DocumentLineKind.CodeFenceInfo("cj"), DocumentLineKind.Blank]
    let doc = Document([title, paragraph, image])
    let highlight = DocumentHighlight("Hello")
    let fold = DocumentFoldRange(2, 6)
    if (doc.lines.size != 3 || doc.lines[0].spans[0].linkUrl.getOrThrow() != "https://example.test" ||
        doc.lines[2].media.isNone() || Document.plain("a\nb").lines.size != 2 || kinds.size != 13 ||
        highlight.query != "Hello" || fold.startOffset != 2 || fold.endOffset != 6 || !fold.contains(6)) {
        throw IllegalStateException("document model failed")
    }
    return 0
}
