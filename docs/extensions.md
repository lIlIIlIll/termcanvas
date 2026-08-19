# Extensions

Core `cjtui` owns rich document rendering, not format parsing.

The stable boundary is:

- `RichSpan`
- `DocumentLineKind`
- `DocumentLine`
- `Document`
- `DocumentTheme`
- `DocumentView`

Extensions convert content formats into the canonical stable `core.Document`, then applications render the result with `core.DocumentView`. The former experimental `document` alias facade is retired; applications use the stable core document vocabulary directly.

The former experimental `packages/editor` facade and advanced editor shell are retired. Stable text-buffer, text-area, completion, and Markdown-editing declarations are used directly from `core`. Format adapters remain separate from editor behavior and parsing policy.

Game helpers follow the same boundary: core owns terminal events, timing, metrics, canvas, buffers, and layout, while game-specific entity/component storage, physics, tile maps, and sprite rendering live in `packages/game`.

## Current Extensions

`packages/markdown` provides the `markdown` package. It depends on the in-repository `cj_markdown` parser and only adapts `MarkdownDocument` into `core.Document`.

The parser package handles source ranges, diagnostics, ATX/setext headings, merged paragraphs with soft-break source mapping, nested lists, task list items, indented block quotes, fenced code blocks with language info, pipe tables with alignment and escaped pipes, horizontal rules, HTML blocks/inline HTML, reference links/images, shortcut reference links, multi-backtick inline code, strong/emphasis/strikethrough, autolinks, and common escapes.

The adapter maps the AST into `Document`, exposes `markdownOutline()` for heading trees, and exposes `markdownPreviewIndex()` for source-offset to preview-row synchronization.

`packages/terminal` provides the `terminal` package. It parses ANSI terminal output into a `TerminalScreen` / bounded `TerminalTranscript` model and renders it with `TerminalView`. It targets a practical xterm subset for command output and logs, including common SGR colors, erase/cursor controls, carriage-return progress output, transcript trimming, and search highlighting; process execution stays in core PTY APIs.

`packages/diff` provides the `diff` package. It parses unified diff text into `DiffDocument` / `DiffFile` / `DiffHunk` / `DiffLine` and renders it with `DiffView`. It includes added/deleted line summaries, inline line-number rendering, and a side-by-side view mode. It displays diffs only; apply/reject policy belongs to applications.

`packages/game` provides the `game` package. It includes `EntityWorld`, generic `ComponentStore<T>`, `GameInputState`, `PhysicsWorld` with continuous swept AABB collision and sensor-overlap queries, `TileMap` with symbol lookup and marker discovery, `Sprite2D`, `SpriteFrame`, `SpriteAnimation`, `Camera2D`, and `SpriteRenderer`. It is intentionally engine-shaped but small: applications own gameplay rules, assets, levels, and persistence.

```cangjie
import core.*
import markdown.*

let doc = Markdown.parse("# Title\n\n- item")
DocumentView(doc).render(area, buffer)
```

## Extension Roadmap

Format parsing extensions:

- Markdown
- ANSI logs
- HTML subset
- man/help documents
- JSON/YAML/TOML viewers
- CSV/table viewers
- diff viewers

Media rendering extensions:

- `media` image/video adapters with Kitty graphics, Sixel, text fallback, and ffmpeg-backed media-to-ASCII animation helpers
- charts and dashboard document blocks
- Mermaid/Graphviz fallback diagrams
- OSC8 links
- LaTeX/math text fallback

Interactive content extensions:

- folding trees
- sortable and searchable tables
- diagnostics and quickfix lists
- test reports
- chat transcripts
- archive/file previews

Game and simulation extensions:

- `game` ECS, input, continuous collision physics, tile maps, and sprite rendering
- pathfinding and steering helpers
- animation timelines
- particle systems
- replay/record helpers for deterministic testing

Near-term priority:

1. `editor`
2. `markdown`
3. `terminal`
4. `diff`
5. `cjtui_syntax`
6. `cjtui_json`
7. `media`
8. `game`
9. `cjtui_html`
10. `cjtui_diagnostics`
