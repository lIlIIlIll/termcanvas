package core

import std.unittest.*
import std.unittest.testmacro.*

private class ThemedVirtualSource <: VirtualTranscriptSource {
    var calls: Int64 = 0
    var explicitCard: ?TranscriptCardTheme = None
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "item" }
    public func itemTitle(_: Int64): String { "header" }
    public func revision(_: Int64): Int64 { 0 }
    public func itemCardTheme(_: Int64): ?TranscriptCardTheme { explicitCard }
    public func document(_: Int64, _: Int64, _: String): Document { Document.plain("body") }
    public func documentWithTheme(_: Int64, _: Int64, _: String, theme: ?Theme): Document {
        calls++
        let style = match (theme) { case Some(value) => value.normal; case None => Style.default() }
        Document.plain("body", style: style)
    }
}

@Test
class SecondaryThemeContextTest {
    @TestCase
    func taskActivityInheritsAppThemeAndExplicitThemeWins(): Unit {
        let appTheme = Theme(accent: Style(fg: Color.Red), iconSet: IconSet.NerdFont)
        let explicit = Theme(accent: Style(fg: Color.Green), iconSet: IconSet.Ascii)
        let buffer = Buffer(Rect(0, 0, 30, 2))
        buffer.setTheme(Some(appTheme))
        let task = TaskActivity("build", status: TaskStatus.Running)
        TaskActivityView(task, layout: TaskActivityLayout.Compact).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "\u{f110}")
        @Expect(buffer.getCell(0, 0).style, appTheme.accent)
        TaskActivityView(task, layout: TaskActivityLayout.Compact, theme: explicit).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "|")
        @Expect(buffer.getCell(0, 0).style, explicit.accent)
    }

    @TestCase
    func menuDashboardAndDialogUseInheritedRolesAndExplicitPatches(): Unit {
        let theme = Theme(normal: Style(fg: Color.Blue, bg: Color.Black),
            selected: Style(fg: Color.Green, bg: Color.Magenta), accent: Style(fg: Color.Yellow))
        let buffer = Buffer(Rect(0, 0, 40, 7))
        buffer.setTheme(Some(theme))
        Menu("", [MenuItem("one"), MenuItem("two")]).render(Rect(0, 0, 10, 2), buffer)
        @Expect(buffer.getCell(0, 0).style, theme.selected)
        @Expect(buffer.getCell(0, 1).style, theme.normal)
        Menu("", [MenuItem("one")], selectedStyle: Style(fg: Color.Red)).render(Rect(0, 0, 10, 1), buffer)
        @Expect(buffer.getCell(0, 0).style, theme.selected.patch(Style(fg: Color.Red)))
        MetricCard("title", "42").render(Rect(0, 0, 10, 2), buffer)
        @Expect(buffer.getCell(0, 1).style, theme.accent)
        Dialog(buttons: ["OK"]).render(buffer.area, buffer)
        @Expect(buffer.getCell(1, 5).style, theme.selected)
    }

    @TestCase
    func documentLayoutCacheTracksApplicationThemeChanges(): Unit {
        let first = Theme(normal: Style(fg: Color.Red))
        let second = Theme(normal: Style(fg: Color.Green))
        let buffer = Buffer(Rect(0, 0, 20, 2))
        let view = DocumentView(Document.plain("hello"), cacheLayout: true)
        buffer.setTheme(Some(first))
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, first.normal)
        buffer.setTheme(Some(second))
        view.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.normal)
    }

    @TestCase
    func documentSourceHighlightTracksThemeUnlessOverridden(): Unit {
        let doc = Document([DocumentLine(DocumentLineKind.Paragraph, [RichSpan("hello", sourceRange: Some("0:5"))])])
        let state = DocumentViewState(cursorSourceOffset: Some(1))
        let first = Theme(selected: Style(bg: Color.Blue))
        let second = Theme(selected: Style(bg: Color.Green))
        let buffer = Buffer(Rect(0, 0, 20, 2))
        let view = DocumentView(doc, state: Some(state), cacheLayout: true)
        buffer.setTheme(Some(first))
        view.render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Blue))
        buffer.setTheme(Some(second))
        view.render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Green))
        let explicit = DocumentView(doc, state: Some(state), currentSourceStyle: Style(bg: Color.Red))
        explicit.render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Red))
        let cleared = DocumentView(doc, state: Some(state), currentSourceStyle: Style.default())
        cleared.render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: second.normal.bg))
    }

    @TestCase
    func errorBoxUsesThemeBorderWithExplicitKindTakingPriority(): Unit {
        let buffer = Buffer(Rect(0, 0, 15, 5))
        buffer.setTheme(Some(Theme(borderKind: BorderKind.Double, error: Style(fg: Color.Green))))
        ErrorBox("error").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╔")
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Green))
        ErrorBox("error", borderKind: BorderKind.Ascii).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
    }

    @TestCase
    func transcriptViewUsesApplicationRolesButRespectsExplicitCardTheme(): Unit {
        let item = TranscriptItem("job", title: "Build", status: TranscriptItemStatus.Done, body: Document.plain("body"))
        let transcript = Transcript(items: [item])
        let buffer = Buffer(Rect(0, 0, 30, 4))
        buffer.setTheme(Some(Theme(success: Style(fg: Color.Green), selected: Style(fg: Color.Yellow))))
        TranscriptView(transcript).render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Green))
        @Expect(Style(fg: buffer.getCell(2, 0).style.fg), Style(fg: Color.Yellow))
        TranscriptView(transcript, cardTheme: TranscriptCardTheme(selectedStyle: Style(fg: Color.Magenta))).render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(2, 0).style.fg), Style(fg: Color.Magenta))
        @Expect(buffer.getCell(2, 1).style, Style.default())
    }

    @TestCase
    func virtualTranscriptRefreshesAppThemeAndRetainsExplicitCardTheme(): Unit {
        let source = ThemedVirtualSource()
        let view = VirtualTranscriptView(source)
        view.setCardChrome(true)
        let buffer = Buffer(Rect(0, 0, 20, 4))
        let first = Theme(normal: Style(fg: Color.Red), border: Style(fg: Color.Yellow), heading: Style(fg: Color.Yellow))
        let second = Theme(normal: Style(fg: Color.Green), border: Style(fg: Color.Blue), heading: Style(fg: Color.Blue))
        buffer.setTheme(Some(first))
        view.render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Yellow))
        @Expect(Style(fg: buffer.getCell(2, 1).style.fg), Style(fg: Color.Red))
        let oldCalls = source.calls
        buffer.setTheme(Some(second))
        view.render(buffer.area, buffer)
        @Expect(source.calls > oldCalls)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Blue))
        @Expect(Style(fg: buffer.getCell(2, 1).style.fg), Style(fg: Color.Green))
        view.setCardTheme(TranscriptCardTheme(borderStyle: Style(fg: Color.Magenta), topTitleStyle: Style(fg: Color.Magenta)))
        view.render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Magenta))
        view.clearCardTheme()
        view.render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Blue))
        source.explicitCard = Some(TranscriptCardTheme(topTitleStyle: Style(fg: Color.Red)))
        view.render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Red))
    }

    @TestCase
    func compositeChildrenInheritExplicitParentBeforeAppTheme(): Unit {
        let buffer = Buffer(Rect(0, 0, 40, 12))
        let appTheme = Theme(normal: Style(fg: Color.Blue), border: Style(fg: Color.Blue), borderKind: BorderKind.Ascii)
        let parent = Theme(normal: Style(fg: Color.Green), border: Style(fg: Color.Green), borderKind: BorderKind.Double)
        let child = Theme(border: Style(fg: Color.Red), borderKind: BorderKind.Rounded)
        buffer.setTheme(Some(appTheme))
        Menu("menu", [MenuItem("one")], block: Some(Block()), theme: Some(parent)).render(Rect(0, 0, 12, 4), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╔")
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Green))
        Menu("menu", [MenuItem("one")], block: Some(Block(BlockOptions(theme: Some(child)))), theme: Some(parent)).render(Rect(0, 0, 12, 4), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╭")
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Red))
        Dialog(title: "test", theme: Some(parent)).render(Rect(0, 0, 40, 7), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╔")
        RequestDialog(detail: Document.plain("details"), theme: Some(parent)).render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(10, 6).style.fg), Style(fg: Color.Green))
        Block().render(Rect(0, 0, 5, 3), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
    }
}
