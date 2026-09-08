# cj_markdown

## Purpose and boundary

`cj_markdown` is the standalone Markdown parser used by cjtui. It intentionally
has no dependency on cjtui or `core`: non-TUI consumers can inspect the same AST,
and UI packages can map it into their own render model, such as `core.Document`.
Parsing is separate from application-owned state, `App` update, and immediate
widget rendering. The `packages/markdown` adapter is the cjtui integration;
[`docs/extensions.md`](../../docs/extensions.md) describes the package boundary.

## Parse a document

```cangjie
import cj_markdown.*

let doc = parseMarkdown("# Title\n\n- item")
for (block in doc.blocks) {
    // inspect block.kind, block.text, block.inlines
}

for (diagnostic in doc.diagnostics) {
    // inspect diagnostic.severity, diagnostic.message, diagnostic.range
}
```

`parseMarkdown(text)` uses the default `MarkdownParserOptions`. Use
`parseMarkdownWithOptions(text, options)` or construct `MarkdownParser(options:
...)` when a caller needs explicit parser policy:

- `mergeParagraphs`: merge compatible adjacent paragraph lines (default `true`)
  while retaining soft-break source ranges.
- `enableHtml`: parse HTML blocks and inline HTML (default `true`).
- `enableStrikethrough`: parse strikethrough spans (default `true`).

`parseInline(text)` parses inline content without a block document.

## Public model

- `MarkdownDocument`: ordered `blocks` and parser `diagnostics`.
- `MarkdownBlock`: `kind`, source `text`, `inlines`, optional `table`, nested
  `children`, and optional `SourceRange`.
- `MarkdownBlockKind`: paragraph, heading, list/list item, task item, quote,
  fenced or indented code, table, horizontal rule, HTML block, reference
  definition, and blank block forms.
- `MarkdownInline`: inline `kind`, text, child spans, and optional source range.
- `MarkdownInlineKind`: text, emphasis, strong, strikethrough, code, link,
  image, inline HTML, soft break, and hard break.
- `MarkdownTable`, `MarkdownTableRow`, and `MarkdownTableCell`: table header,
  alignments, body rows, and parsed cell inlines.
- `SourcePos` / `SourceRange`: line, column, and byte-offset locations.
- `MarkdownDiagnostic`: warning or error severity, message, and source range.
- `MarkdownDiagnosticSeverity`: `Warning` or `Error`.
- `MarkdownTableAlign`: `Left`, `Center`, `Right`, or `None`.

The model is immutable from the parser's point of view: parse once, inspect the
result, and let the owning application decide how to store, edit, or render it.

## Parser coverage

Current coverage includes:

- source ranges on blocks and inline spans
- ATX headings, including an optional closing `#`
- setext headings
- merged paragraphs
- soft-break inline ranges for merged paragraph source mapping
- grouped unordered and ordered list items with nested child items
- task list items
- block quotes with parsed child blocks, including indented quote markers
- fenced code blocks with language info
- indented code blocks
- list continuation lines
- pipe tables with header, alignment, and body rows
- horizontal rules
- HTML blocks and inline HTML
- reference definitions and reference-style links/images
- shortcut reference links
- inline links with an optional title
- inline images
- inline code
- multi-backtick inline code spans
- inline strong and emphasis
- inline strikethrough
- autolinks
- common backslash escapes
- escaped pipe characters in table cells
- parser diagnostics, including unclosed fenced code blocks

Unsupported or unrecognized source is represented by the available text/HTML
nodes and diagnostics rather than by a cjtui-specific widget. Rendering policy
belongs to the consumer.

## cjtui adapter path

The cjtui integration lives in the separate `markdown` extension package, not in
cjtui core or this parser:

```text
cj_markdown MarkdownDocument
    -> markdown adapter
    -> core.Document
    -> core.DocumentView
```

The adapter exposes `Markdown.parse`, `markdownDocument`, and
`markdownAstToDocument`, plus `markdownOutline()` for heading trees and
`markdownPreviewIndex()` for source-offset to preview-row synchronization. The
application still owns the resulting document/view state and sends input and
completion events through `App` update.
