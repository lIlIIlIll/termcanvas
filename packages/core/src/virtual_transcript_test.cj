package core

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

class CountingTranscriptSource <: VirtualTranscriptSource {
    let count: Int64
    let revisions = ArrayList<Int64>()
    var documentCalls: Int64 = 0

    init(count: Int64) {
        this.count = count
        for (_ in 0..count) { revisions.add(0) }
    }

    public func size(): Int64 { count }
    public func itemId(index: Int64): String { "item-${index}" }
    public func revision(index: Int64): Int64 { revisions[index] }
    public func document(index: Int64, width: Int64, themeKey: String): Document {
        documentCalls++
        Document.plain("${themeKey} item-${index} width-${width}\nbody")
    }

    func stream(index: Int64): Unit { revisions[index]++ }
}

@Test
class VirtualTranscriptTests {
    @TestCase
    func firstRenderMaterializesBoundedTailWindow(): Unit {
        let source = CountingTranscriptSource(10000)
        let state = VirtualTranscriptState()
        let view = VirtualTranscriptView(source, state: state)
        let area = Rect(0, 0, 120, 36)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(source.documentCalls < 256)
        @Expect(backend.snapshot().contains("item-9999"))
        @Expect(state.followBottom)
    }

    @TestCase
    func defaultRenderingDoesNotEventuallyMaterializeTheWholeSource(): Unit {
        let source = CountingTranscriptSource(1000)
        let view = VirtualTranscriptView(source)
        let backend = TestBackend(area: Rect(0, 0, 80, 20))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        for (_ in 0..150) {
            _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        }
        @Expect(source.documentCalls < 128)
    }

    @TestCase
    func streamingRevisionInvalidatesOnlyChangedCard(): Unit {
        let source = CountingTranscriptSource(10000)
        let state = VirtualTranscriptState()
        let view = VirtualTranscriptView(source, state: state)
        let area = Rect(0, 0, 120, 36)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        let before = source.documentCalls
        source.stream(9999)
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(source.documentCalls - before <= 9)
        @Expect(backend.snapshot().contains("item-9999"))
    }

    @TestCase
    func pageAndResizeKeepStableItemAnchor(): Unit {
        let source = CountingTranscriptSource(10000)
        let state = VirtualTranscriptState()
        let view = VirtualTranscriptView(source, state: state)
        let firstArea = Rect(0, 0, 120, 36)
        let backend = TestBackend(area: firstArea)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(view.handle(KeyEvent(KeyCode.PageUp)))
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        let anchor = state.anchorId
        backend.setSize(Rect(0, 0, 80, 24))
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(state.anchorId, anchor)
        @Expect(!state.followBottom)

        view.setThemeKey("light")
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(state.anchorId, anchor)
        @Expect(view.handle(KeyEvent(KeyCode.End)))
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(backend.snapshot().contains("item-9999"))
    }

    @TestCase
    func rendersUtf8BoundarySamples(): Unit {
        // Shared UTF-8 boundary corpus (mirrored in cj_markdown
        // markdown_test.cj and agent_tui tui.cj headless). Rendering every
        // sample through the real VirtualTranscriptView must not throw and
        // must produce visible rows — with card chrome enabled to exercise
        // the border path over multi-byte titles.
        let samples = [
            "plain ascii body\n\n- item one\n- item two\n\n# Heading\n\n```cj\nmain()\n```\n",
            "Café résumé naïve €50\n\n- édition spéciale\n- piñata ñoño\n",
            "中文标题\n\n- 列表项一\n- 列表项二\n\n## 二级标题\n\n| 列A | 列B |\n| --- | --- |\n| 甲 | 乙 |\n\n这是一段很长的中文内容。\n",
            "🎯 任务列表\n\n- 🎯 任务一\n- [x] ✅ 已完成\n- 🚀 启动\n\n> 引用 🎉\n",
            "家庭 👨👩👧 组合\n\n- 👨👩👧 三个人\n- 组合 🧑🤝🧑 与 🇨🇳\n",
            "🚀 综合样本\n\n# 标题一\n\n- 🎯 中文任务 éé\n- [x] ✅ 完成项\n- 👨👩👧 家庭项\n\n## 二级 **加粗中文**\n\n1. 有序一\n2. 有序二\n\n```\n代码块中文\n```\n\n| 名称 | 状态 |\n| --- | --- |\n| 中文 | ✅ |\n\n很长的一段内容…\n"
        ]
        let source = Utf8BoundarySource(samples)
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let backend = TestBackend(area: Rect(0, 0, 80, 30))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(view.lastVisibleRanges.size > 0)
        let snapshot = backend.snapshot()
        @Expect(snapshot.contains("🎯"))
        // Wide glyphs occupy two cells (WideLead + space tail), so text
        // checks against snapshots must strip the tail spaces first.
        @Expect(snapshot.replace(" ", "").contains("中文"))
    }

    @TestCase
    func cardHeaderReservesRailWidthForStatusSuffix(): Unit {
        let source = TitleWidthTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let area = Rect(0, 0, 30, 8)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        @Expect(source.lastTitleWidth, 27)
        @Expect(backend.snapshot().contains("running"))
    }

    @TestCase
    func cardChromeFallsBackToAsciiWithoutUnicode(): Unit {
        let source = TitleWidthTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        view.setUnicode(false)
        let area = Rect(0, 0, 30, 8)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        let snapshot = backend.snapshot()
        @Expect(snapshot.contains("+- "))
        @Expect(snapshot.contains("|  "))
    }

    @TestCase
    func compactCardChromeOmitsEmptyFooterRow(): Unit {
        let source = CompactChromeTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let backend = TestBackend(area: Rect(0, 0, 50, 5))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)

        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        let snapshot = backend.snapshot()
        @Expect(snapshot.contains("╭─ ✓ GitHub · completed"))
        @Expect(!snapshot.contains("╰─"))
        @Expect(!snapshot.contains("│ "))
    }

    @TestCase
    func fullFrameRendersOneContainerWithLabeledSeparatorAndFooter(): Unit {
        let source = FullFrameTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let buffer = Buffer(Rect(0, 0, 32, 8))

        view.render(buffer.area, buffer)

        @Expect(buffer.getCell(0, 0).symbol, "╭")
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Indexed(8)))
        @Expect(buffer.getCell(31, 0).symbol, "╮")
        @Expect(buffer.getCell(1, 1).style, Style(fg: Color.Blue))
        @Expect(buffer.getCell(0, 2).symbol, "├")
        @Expect(buffer.getCell(4, 2).symbol, "O")
        @Expect(buffer.getCell(4, 2).style, Style(fg: Color.Yellow))
        @Expect(buffer.getCell(31, 2).symbol, "┤")
        @Expect(buffer.getCell(1, 3).style, Style(fg: Color.Cyan))
        @Expect(buffer.getCell(1, 4).symbol, "〈")
        @Expect(buffer.getCell(1, 4).style, Style(fg: Color.Indexed(8)))
        @Expect(buffer.getCell(0, 5).symbol, "╰")
        @Expect(buffer.getCell(31, 5).symbol, "╯")
    }

    @TestCase
    func runningNoOutputFrameKeepsBothSidesOnOneColumnAcrossResize(): Unit {
        let source = RunningNoOutputTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)

        for (width in [80, 120, 160]) {
            let left: Int64 = 7
            let top: Int64 = 1
            let right = left + width - 1
            let buffer = Buffer(Rect(0, 0, width + 14, 10))
            view.render(Rect(left, top, width, 8), buffer)

            @Expect(buffer.getCell(left, top).symbol, "╭")
            @Expect(buffer.getCell(right, top).symbol, "╮")
            @Expect(buffer.getCell(left, top + 1).symbol, "│")
            @Expect(buffer.getCell(right, top + 1).symbol, "│")
            @Expect(buffer.getCell(left, top + 2).symbol, "│")
            @Expect(buffer.getCell(right, top + 2).symbol, "│")
            @Expect(buffer.getCell(left, top + 3).symbol, "╰")
            @Expect(buffer.getCell(right, top + 3).symbol, "╯")
            @Expect(buffer.getCell(left + 2, top + 1).symbol, "$")
            @Expect(buffer.getCell(left + 2, top + 2).symbol, "〈")
            for (y in top..(top + 4)) {
                @Expect(buffer.getCell(left + 1, y).symbol != "│")
            }
        }
    }

    @TestCase
    func streamingOutputAddsSeparatorWithoutChangingOuterColumns(): Unit {
        let source = StreamingFullFrameTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let area = Rect(5, 1, 80, 8)
        let initial = Buffer(Rect(0, 0, 90, 10))

        view.render(area, initial)
        @Expect(initial.getCell(5, 2).symbol, "│")
        @Expect(initial.getCell(84, 2).symbol, "│")
        @Expect(initial.getCell(5, 3).symbol, "│")
        @Expect(initial.getCell(84, 3).symbol, "│")
        @Expect(initial.getCell(5, 4).symbol, "╰")
        @Expect(initial.getCell(84, 4).symbol, "╯")

        source.showOutput()
        let visible = Buffer(Rect(0, 0, 90, 10))
        view.render(area, visible)
        @Expect(visible.getCell(5, 3).symbol, "├")
        @Expect(visible.getCell(84, 3).symbol, "┤")
        @Expect(visible.getCell(5, 4).symbol, "│")
        @Expect(visible.getCell(84, 4).symbol, "│")
        @Expect(visible.getCell(5, 5).symbol, "│")
        @Expect(visible.getCell(84, 5).symbol, "│")
        @Expect(visible.getCell(5, 6).symbol, "╰")
        @Expect(visible.getCell(84, 6).symbol, "╯")
    }

    @TestCase
    func backgroundBlockFillsFullWidthAndReflowsAtNewWidth(): Unit {
        let source = BackgroundTranscriptSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let first = Buffer(Rect(0, 0, 20, 8))

        view.render(first.area, first)

        @Expect(source.lastWidth, 16)
        @Expect(first.getCell(0, 0).style, Style(bg: Color.Blue))
        @Expect(first.getCell(19, 0).style, Style(bg: Color.Blue))
        @Expect(first.getCell(2, 1).symbol, "这")
        @Expect(first.getCell(19, 2).style, Style(bg: Color.Blue))

        let resized = Buffer(Rect(0, 0, 30, 8))
        view.render(resized.area, resized)
        @Expect(source.lastWidth, 26)
        @Expect(resized.getCell(29, 1).style, Style(bg: Color.Blue))
    }
}

class FullFrameTranscriptSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "full-frame" }
    public func revision(_: Int64): Int64 { 0 }
    public func itemFooter(_: Int64): String { "〈Wall: 12ms | Exit: 0〉" }
    public func itemCardTheme(_: Int64): ?TranscriptCardTheme {
        Some(TranscriptCardTheme(
            fullFrame: true,
            bodyIndent: 0,
            borderStyle: Style(fg: Color.Indexed(8)),
            mutedStyle: Style(fg: Color.Indexed(8))
        ))
    }
    public func document(_: Int64, _: Int64, _: String): Document {
        Document([
            DocumentLine(
                DocumentLineKind.Paragraph,
                [
                    RichSpan("$", style: Style(fg: Color.Blue)),
                    RichSpan(" printf ok", style: Style(fg: Color.Green))
                ]
            ),
            DocumentLine(
                DocumentLineKind.HorizontalRule,
                [RichSpan("Output", style: Style(fg: Color.Yellow))]
            ),
            DocumentLine(DocumentLineKind.Paragraph, "ok", style: Style(fg: Color.Cyan))
        ])
    }
}

class RunningNoOutputTranscriptSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "running-no-output" }
    public func revision(_: Int64): Int64 { 0 }
    public func itemFooter(_: Int64): String { "〈Running · 12 ms〉" }
    public func itemCardTheme(_: Int64): ?TranscriptCardTheme {
        Some(TranscriptCardTheme(
            fullFrame: true,
            bodyIndent: 0,
            borderStyle: Style(fg: Color.Indexed(8)),
            mutedStyle: Style(fg: Color.Indexed(8)),
            contentPadding: Spacing.symmetric(horizontal: 1, vertical: 0)
        ))
    }
    public func document(_: Int64, _: Int64, _: String): Document {
        Document.plain("$ mkdir -p /tmp/cube")
    }
}

class StreamingFullFrameTranscriptSource <: VirtualTranscriptSource {
    var revisionValue: Int64 = 0
    var visible: Bool = false

    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "streaming-full-frame" }
    public func revision(_: Int64): Int64 { revisionValue }
    public func itemFooter(_: Int64): String { "〈Running · 0.8 s〉" }
    public func itemCardTheme(_: Int64): ?TranscriptCardTheme {
        Some(TranscriptCardTheme(
            fullFrame: true,
            bodyIndent: 0,
            borderStyle: Style(fg: Color.Indexed(8)),
            mutedStyle: Style(fg: Color.Indexed(8)),
            contentPadding: Spacing.symmetric(horizontal: 1, vertical: 0)
        ))
    }
    public func document(_: Int64, _: Int64, _: String): Document {
        if (!visible) {
            return Document.plain("$ cmake --build build -j16")
        }
        Document([
            DocumentLine(DocumentLineKind.Paragraph, "$ cmake --build build -j16"),
            DocumentLine(DocumentLineKind.HorizontalRule, "Output"),
            DocumentLine(DocumentLineKind.Paragraph, "compiling...")
        ])
    }
    func showOutput(): Unit {
        visible = true
        revisionValue++
    }
}

class BackgroundTranscriptSource <: VirtualTranscriptSource {
    var lastWidth: Int64 = 0

    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "background" }
    public func itemUsesCardChrome(_: Int64): Bool { false }
    public func revision(_: Int64): Int64 { 0 }
    public func itemCardTheme(_: Int64): ?TranscriptCardTheme {
        Some(TranscriptCardTheme(
            fillBackground: true,
            contentPadding: Spacing.symmetric(horizontal: 2, vertical: 1),
            borderBackground: Style(bg: Color.Blue)
        ))
    }
    public func document(_: Int64, width: Int64, _: String): Document {
        lastWidth = width
        Document.plain("这些失败原因中哪些是标准库实现导致的")
    }
}

class CompactChromeTranscriptSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "compact-card" }
    public func itemTitle(_: Int64): String { "✓ GitHub · completed" }
    public func itemUsesCompactCardChrome(_: Int64): Bool { true }
    public func revision(_: Int64): Int64 { 0 }
    public func document(_: Int64, _: Int64, _: String): Document { Document([]) }
}

class Utf8BoundarySource <: VirtualTranscriptSource {
    let samples: Array<String>

    init(samples: Array<String>) {
        this.samples = samples
    }

    public func size(): Int64 { samples.size }
    public func itemId(index: Int64): String { "item-utf8-${index}" }
    public func revision(index: Int64): Int64 { 0 }
    public func document(index: Int64, width: Int64, themeKey: String): Document {
        Document.plain(samples[index])
    }
}

class TitleWidthTranscriptSource <: VirtualTranscriptSource {
    var lastTitleWidth: Int64 = 0

    public func size(): Int64 { 1 }
    public func itemId(index: Int64): String { "title-width-${index}" }
    public func revision(index: Int64): Int64 {
        let _ = index
        0
    }
    public func itemUsesCardChrome(index: Int64): Bool {
        let _ = index
        true
    }
    public func itemTitleForWidth(index: Int64, width: Int64): String {
        let _ = index
        lastTitleWidth = width
        let full = "Run find long-target · running"
        if (width < displayWidth(full)) { "Run … · running" } else { full }
    }
    public func document(index: Int64, width: Int64, themeKey: String): Document {
        let _ = index
        let _ = width
        let _ = themeKey
        Document.plain("body")
    }
}
