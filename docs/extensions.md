# Extensions

## Reader task

Use an extension when content or behavior is outside the cjtui core rendering
loop. An extension may parse or model a format, but the application still owns
state and routes events and effects through `App` / update before immediate
widgets render. Core provides the stable document vocabulary; extensions adapt
into it.

## Boundary and stable document model

Core owns rich document rendering, not format parsing. The stable hand-off is:

- `RichSpan`: styled text with optional source range.
- `DocumentLineKind`: paragraph, heading, list/task item, quote, code, table,
  HTML, diagnostic, and related row kinds.
- `DocumentLine`: one renderable document row.
- `Document`: ordered document lines.
- `DocumentTheme`: document-specific styles.
- `DocumentView`: immediate renderer with scrolling, links, highlights, folds,
  and source-offset lookup.

An adapter converts a source format into `core.Document`; application-owned
state then supplies the document and view state to `core.DocumentView`:

```cj
import core.*
import markdown_adapter.*

let doc = markdownDocument("# Title\n\n- item")
let buffer = Buffer(Rect(0, 0, 40, 10))
DocumentView(doc).render(buffer.area, buffer)
```

The former experimental `document` / `packages/document` alias facade is retired.
Applications use the stable core document vocabulary directly. The former
`packages/editor` facade and advanced editor shell are also retired; stable
text-buffer, text-area, completion, and Markdown-editing declarations are used
directly from `core`. Format adapters remain separate from editor behavior and
parsing policy.

## Current packages

### Markdown

The `markdown_adapter` package maps the AST from
[markdown v0.9.0](https://github.com/lIlIIlIll/markdown/releases/tag/v0.9.0)
into `core.Document`. This upstream release is a pre-GA preview; the adapter
pins its Git tag and `cjpm.lock` records the resolved commit.
The parser remains independent of cjtui. Import `markdown.core.Markdown`
to parse directly, or call `markdownDocument(text)` to parse with the GFM
profile and convert for `DocumentView`.

`markdownAstToDocument(result)` accepts the upstream `ParseResult`;
`markdownOutline(result)` derives heading trees from that same result.
`markdownPreviewIndex()` maps source byte offsets to rendered rows.
Diagnostics appear only when the upstream parser emits them; an unclosed
code fence is valid Markdown and does not imply a warning.
Markdown parsing remains outside `core.DocumentView`.

`markdownAstToPresentation(result, syntax: Some(config))` (experimental)
produces both a preview `document` and a complete `decorations` array for a
`TextArea` containing the **same** `result.source.text()` revision.
`config` is a `SyntaxHighlightConfig` returned by
`parseSyntaxHighlightConfig(text)`; omit the named argument to use only
the built-in lexers. Parse the editor value once, pass the result to this
function, assign `presentation.document` to the preview, and call
`editor.setDecorations(presentation.decorations)`. Replace both on
every text revision; the decorations include ordinary Markdown, not just
code tokens. Keep the configuration instance across revisions rather than
reloading the file on each edit. `markdownDocument` and
`markdownAstToDocument` remain preview-only and use the built-in
code-block colors without constructing editor decorations.

Fenced code language and literal come directly from the Markdown AST; the
adapter does not render HTML to recover an info string. Supported languages
are Cangjie, C/C++, JavaScript/TypeScript, Python, JSON, and Shell (aliases and
usage are listed in [the Studio example](examples.md#focused-commands)).
Highlighting is lexical, not compiler or semantic analysis. Unknown or absent
languages and indented code retain the plain code style. Preview source ranges
and editor styles use AST-anchored UTF-8 byte offsets; virtual indentation
cannot claim source bytes. Only parse results whose source bytes match the
editor String can supply editor decorations.

For a runnable dependency declaration, see
[`examples/markdown_studio/cjpm.toml`](../examples/markdown_studio/cjpm.toml).
It declares both the local `markdown_adapter` and upstream `markdown` v0.9.0.

### Terminal output

`packages/terminal` provides `terminal`. It parses ANSI terminal output into a
`TerminalScreen` / bounded `TerminalTranscript` model and renders it with
`TerminalView`. Its practical xterm subset includes common SGR colors,
erase/cursor controls, carriage-return progress output, transcript trimming,
and search highlighting. Process execution stays in core PTY APIs; terminal
parsing does not own application state.

### Unified diffs

`packages/diff` provides `diff`. It parses unified diff text into
`DiffDocument`, `DiffFile`, `DiffHunk`, and `DiffLine`, then renders with
`DiffView`. It includes added/deleted line summaries, inline line-number
rendering, and a side-by-side view mode. It displays diffs only; apply/reject
policy belongs to applications.

### Media

`packages/media` provides `media` and depends on `core`. It is a current
extension, not a future route. `MediaAdapter` has a text fallback and an
`ExternalMediaAdapter` for Kitty and Sixel output backed by ImageMagick,
ffmpeg, and `img2sixel` tools when available. `MediaDecodeRequest` carries a
`MediaSource`, target area, protocol, and frame index.

The package also provides `AsciiRenderOptions` with ASCII, half-block, and
Braille modes; `AsciiFrame` and `AsciiAnimation`; `FfmpegAsciiAnimationDecoder`;
and `AsciiAnimationView`. GIF/video-to-ASCII animation and media gallery
examples use these extension APIs. Applications decide when to decode, how to
handle tool failure, and where the resulting widget is rendered; media does
not own application state.

### Game and simulation helpers

`packages/game` provides `game`. It includes `EntityWorld`, generic
`ComponentStore<T>`, `GameInputState`, `PhysicsWorld` with continuous swept AABB
collision and sensor-overlap queries, `TileMap` with symbol lookup and marker
discovery, `Sprite2D`, `SpriteFrame`, `SpriteAnimation`, `Camera2D`, and
`SpriteRenderer`. It is intentionally engine-shaped but small: applications
own gameplay rules, assets, levels, and persistence. Core continues to own
terminal events, timing, metrics, canvas, buffers, and layout.

## Candidate and experimental families

These are candidate capabilities rather than the stable quick-start path. A
candidate becomes current only when its package and API contract exist; do not
import a package merely because a roadmap entry is listed here.

### Format parsing candidates

- HTML subset
- man/help documents
- JSON/YAML/TOML viewers
- CSV/table viewers

### Media and document candidates

- charts and dashboard document blocks
- Mermaid/Graphviz fallback diagrams
- OSC8 links
- LaTeX/math text fallback

### Interactive content candidates

- folding trees
- sortable and searchable tables
- diagnostics and quickfix lists
- test reports
- chat transcripts
- archive/file previews

### Game and simulation candidates

- pathfinding and steering helpers
- animation timelines
- particle systems
- replay/record helpers for deterministic testing

No current package is claimed for the candidate list above. The former editor
facade and advanced editor shell are retired and are not a route for new
applications.

## Related documents

- [`architecture.md`](architecture.md): application-owned state and immediate
  rendering boundaries.
- [`widgets.md`](widgets.md): `DocumentView`, editor primitives, and widget
  composition.
- [`events.md`](events.md): input and completion events entering update.
- [Upstream markdown v0.9.0](https://github.com/lIlIIlIll/markdown/releases/tag/v0.9.0):
  parser API, source ranges, profiles, and release artifacts.
- [`api.md`](api.md) and generated [`api-inventory.json`](api-inventory.json):
  current ownership and stability tiers.
