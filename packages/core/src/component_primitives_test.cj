package core

import std.unittest.*
import std.unittest.testmacro.*

class PrimitiveCountingRows {
    var calls: Int64 = 0

    func rowAt(index: Int64): Array<String> {
        calls++
        ["row-${index}", "value-${index}"]
    }
}

@Test
class CjTuiComponentPrimitivesTest {
    @TestCase
    func transcriptCardsShareStatusBodyAndChoiceChrome(): Unit {
        let item = TranscriptItem(
            "approval-1",
            kind: TranscriptItemKind.Event,
            title: "Permission · edit",
            body: Document.plain("MEDIUM RISK · workspace.write\nTarget  README.md"),
            status: TranscriptItemStatus.Awaiting,
            stateLabel: "awaiting approval",
            options: [
                TranscriptCardOption("Allow once", selected: true),
                TranscriptCardOption("Reject")
            ],
            footer: "←/→ choose · Enter confirm"
        )
        let document = transcriptCardDocument(item)
        @Expect(document.lines.size, 6)
        @Expect(document.lines[0].spans[0].text, "? ")
        @Expect(document.lines[0].spans[1].text, "Permission · edit")
        @Expect(document.lines[0].spans[2].text, " · awaiting approval")
        @Expect(document.lines[1].spans[0].text, "  ")
        @Expect(document.lines[3].spans[0].text, "  › Allow once")
        @Expect(document.lines[5].spans[0].text, "  ←/→ choose · Enter confirm")

        let collapsed = transcriptCardDocument(TranscriptItem(
            "tool-1",
            title: "Tool · bash",
            body: Document.plain("$ pwd"),
            status: TranscriptItemStatus.Running,
            collapsed: true
        ))
        @Expect(collapsed.lines.size, 1)
        @Expect(collapsed.lines[0].spans[0].text, "◐ ")
        @Expect(collapsed.lines[0].spans[3].text, "  ▸")

        let timedOut = transcriptCardDocument(TranscriptItem(
            "shell-timeout",
            title: "Run command",
            status: TranscriptItemStatus.TimedOut
        ))
        let expired = transcriptCardDocument(TranscriptItem(
            "approval-expired",
            title: "Approval",
            status: TranscriptItemStatus.Expired
        ))
        @Expect(timedOut.lines[0].spans[0].text, "⌛ ")
        @Expect(timedOut.lines[0].spans[2].text, " · timed out")
        @Expect(expired.lines[0].spans[2].text, " · expired")
    }

    @TestCase
    func blockPanelRenderInnerStylesAndAlignsTitle(): Unit {
        let buffer = Buffer(Rect(0, 0, 20, 5))
        let block = Block(BlockOptions(
            title: "Info",
            borderKind: BorderKind.Rounded,
            titleAlign: TitleAlign.Center,
            padding: Spacing.all(1),
            backgroundStyle: Style(bg: Color.Blue),
            borderStyle: Style(fg: Color.Cyan),
            titleStyle: Style(fg: Color.Yellow),
            state: BoxState.Focused
        ))
        let inner = block.renderInner(buffer.area, buffer)
        @Expect(inner, Rect(2, 2, 16, 1))
        @Expect(buffer.getCell(0, 0).symbol, "╭")
        @Expect(buffer.getCell(8, 0).symbol, "I")
        @Expect(buffer.getCell(2, 2).style, Style(bg: Color.Blue))

        let panelBuffer = Buffer(Rect(0, 0, 12, 3))
        Panel(BlockOptions(title: "P"), child: Some(Paragraph("body"))).render(panelBuffer.area, panelBuffer)
        @Expect(panelBuffer.getCell(1, 1).symbol, "b")
    }

    @TestCase
    func bufferAndCanvasFillPrimitivesPreserveWideCells(): Unit {
        let buffer = Buffer(Rect(0, 0, 8, 3))
        buffer.setString(0, 0, "界a")
        buffer.fillLine(0, 1, 3, style: Style(bg: Color.Red))
        @Expect(buffer.getCell(0, 0).symbol, " ")
        @Expect(buffer.getCell(1, 0).symbol, " ")
        @Expect(buffer.writeAsciiSpan(0, 1, "abc", style: Style(fg: Color.Green)))
        buffer.writeAsciiSpanUnchecked(3, 1, "xy", style: Style(fg: Color.Cyan))
        @Expect(buffer.getCell(3, 1).symbol, "x")
        @Expect(!buffer.writeAsciiSpan(0, 2, "a界", style: Style.default()))
        buffer.hline(-1, 1, 3, "*", Style(fg: Color.Yellow))
        buffer.setString(6, 0, "界")
        buffer.vline(6, 0, 2, "|", Style(fg: Color.Cyan))
        @Expect(buffer.getCell(0, 1).symbol, "*")
        @Expect(buffer.getCell(1, 1).symbol, "*")
        @Expect(buffer.getCell(6, 0).symbol, "|")
        @Expect(buffer.getCell(7, 0).symbol, " ")

        let canvas = Canvas(buffer, buffer.area)
        canvas.fillRect(2, 2, 2, 1, Style(bg: Color.Blue))
        canvas.hline(0, 2, 4, "-", Style(fg: Color.Yellow))
        canvas.vline(5, 0, 3, "|", Style(fg: Color.Cyan))
        canvas.render(Paragraph("ok"), Rect(1, 0, 2, 1))
        @Expect(buffer.getCell(3, 2).symbol, "-")
        @Expect(buffer.getCell(5, 1).symbol, "|")
        @Expect(buffer.getCell(1, 0).symbol, "o")

        let dirty = DirtyRects()
        dirty.add(Rect(1, 1, 2, 1))
        @Expect(dirty.intersectsCell(1, 1))
        @Expect(!dirty.intersectsCell(3, 1))
        @Expect(dirty.intersectsRect(2, 1, 3, 1))
        @Expect(!dirty.intersectsRect(3, 1, 2, 1))

        let backend = TestBackend(area: Rect(0, 0, 4, 2))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw { frame =>
            frame.fillRect(0, 0, 4, 1, Style(bg: Color.Green))
            @Expect(frame.isDirtyCell(0, 0))
        }
    }

    @TestCase
    func containersRenderNestedWidgetsAndScrollableUsesState(): Unit {
        let buffer = Buffer(Rect(0, 0, 20, 8))
        let top = Paragraph("top")
        let bottom = Paragraph("bottom")
        VBox([top, bottom], gap: 1).render(Rect(0, 0, 10, 5), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "t")
        @Expect(buffer.getCell(0, 3).symbol, "b")

        HBox([Paragraph("L"), Paragraph("R")], gap: 1).render(Rect(0, 5, 7, 1), buffer)
        @Expect(buffer.getCell(0, 5).symbol, "L")
        @Expect(buffer.getCell(4, 5).symbol, "R")

        let scroll = ScrollState(offset: 1)
        Scrollable(["zero", "one", "two"], state: scroll).render(Rect(10, 0, 6, 2), buffer)
        @Expect(buffer.getCell(10, 0).symbol, "o")
        @Expect(buffer.getCell(15, 0).symbol, "|")
    }

    @TestCase
    func stateModelsAndVirtualTableExposeViewportFriendlyBehavior(): Unit {
        let selection = SelectionModel(mode: SelectionMode.Multiple)
        selection.select(2)
        selection.toggle(4)
        @Expect(selection.isSelected(2))
        @Expect(selection.isSelected(4))

        let scroll = ScrollState()
        scroll.ensureVisible(20, 100, 5)
        @Expect(scroll.offset, 16)

        let sort = SortState()
        sort.toggle(1)
        @Expect(sort.descending, false)
        sort.toggle(1)
        @Expect(sort.descending)

        let filter = FilterState(query: "row")
        @Expect(filter.matches("row-1"))

        let rows = PrimitiveCountingRows()
        let table = VirtualTable([TableColumn("Name", width: 8)], 1000000, { index => rows.rowAt(index) }, selectionModel: Some(selection))
        table.render(Rect(0, 0, 12, 4), Buffer(Rect(0, 0, 12, 4)))
        @Expect(rows.calls <= 3)
    }

    @TestCase
    func containerWrappersCoverOverlayPaddingCenterAndDock(): Unit {
        let stackBuffer = Buffer(Rect(0, 0, 12, 4))
        Stack([Paragraph("bottom"), Paragraph("top")]).render(stackBuffer.area, stackBuffer)
        @Expect(stackBuffer.getCell(0, 0).symbol, "t")

        let overlayBuffer = Buffer(Rect(0, 0, 12, 2))
        Overlay(Paragraph("base"), overlays: [Paragraph("overlay")]).render(overlayBuffer.area, overlayBuffer)
        @Expect(overlayBuffer.getCell(0, 0).symbol, "o")

        let paddingBuffer = Buffer(Rect(0, 0, 10, 3))
        Padding(Paragraph("pad"), Spacing.all(1)).render(paddingBuffer.area, paddingBuffer)
        @Expect(paddingBuffer.getCell(1, 1).symbol, "p")

        let marginBuffer = Buffer(Rect(0, 0, 10, 3))
        Margin(Paragraph("margin"), Spacing.all(1)).render(marginBuffer.area, marginBuffer)
        @Expect(marginBuffer.getCell(1, 1).symbol, "m")

        let centeredBuffer = Buffer(Rect(0, 0, 10, 3))
        Centered(Paragraph("center"), 6, 1).render(centeredBuffer.area, centeredBuffer)
        @Expect(centeredBuffer.getCell(2, 1).symbol, "c")

        let dockBuffer = Buffer(Rect(0, 0, 20, 6))
        Dock(
            top: Some(Paragraph("T")),
            bottom: Some(Paragraph("B")),
            left: Some(Paragraph("L")),
            right: Some(Paragraph("R")),
            center: Some(Paragraph("C")),
            topHeight: 1,
            bottomHeight: 1,
            leftWidth: 2,
            rightWidth: 2
        ).render(dockBuffer.area, dockBuffer)
        @Expect(dockBuffer.getCell(0, 0).symbol, "T")
        @Expect(dockBuffer.getCell(0, 5).symbol, "B")
        @Expect(dockBuffer.getCell(0, 1).symbol, "L")
        @Expect(dockBuffer.getCell(18, 1).symbol, "R")
        @Expect(dockBuffer.getCell(2, 1).symbol, "C")

        Dock().render(Rect(0, 0, 4, 2), Buffer(Rect(0, 0, 4, 2)))
    }

    @TestCase
    func scrollableHandlesKeysAndEmptyAreas(): Unit {
        let state = ScrollState()
        let scrollable = Scrollable(["zero", "one", "two"], state: state)
        @Expect(scrollable.handle(KeyEvent(KeyCode.Down), 2))
        @Expect(state.offset, 1)
        @Expect(scrollable.handle(KeyEvent(KeyCode.Char(r'x')), 2), false)

        let buffer = Buffer(Rect(0, 0, 8, 3))
        scrollable.render(Rect(0, 0, 8, 3), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "o")
        scrollable.render(Rect(0, 0, 0, 3), buffer)
        scrollable.render(Rect(0, 0, 8, 0), buffer)
    }

    @TestCase
    func selectionScrollSortAndFilterModelsCoverBoundaryModes(): Unit {
        let none = SelectionModel(mode: SelectionMode.NoSelection, current: Some(-3))
        none.select(2)
        none.toggle(2)
        @Expect(none.selectedIndices().size, 0)
        @Expect(none.move(1, 0).isNone())

        let single = SelectionModel(mode: SelectionMode.Single, current: Some(-2))
        single.select(3)
        single.select(4)
        @Expect(single.selectedIndices(), [4])
        single.toggle(5)
        @Expect(single.current, Some(5))

        let multiple = SelectionModel(mode: SelectionMode.Multiple)
        multiple.select(-1)
        multiple.select(2)
        multiple.toggle(2)
        multiple.toggle(3)
        @Expect(multiple.isSelected(0))
        @Expect(!multiple.isSelected(2))
        @Expect(multiple.move(-1, 4), Some(2))
        multiple.clear()
        @Expect(multiple.current.isNone())

        let scroll = ScrollState(offset: -2)
        scroll.scroll(-1, 10, 3)
        scroll.scrollTo(99, 10, 3)
        scroll.ensureVisible(-1, 10, 3)
        scroll.ensureVisible(8, 10, 3)
        scroll.ensureVisible(2, 0, 3)
        @Expect(scroll.offset, 0)
        @Expect(scroll.handle(KeyEvent(KeyCode.Up), 10, 3))
        @Expect(scroll.handle(KeyEvent(KeyCode.Down), 10, 3))
        @Expect(scroll.handle(KeyEvent(KeyCode.PageUp), 10, 3))
        @Expect(scroll.handle(KeyEvent(KeyCode.PageDown), 10, 3))
        @Expect(scroll.handle(KeyEvent(KeyCode.Home), 10, 3))
        @Expect(scroll.handle(KeyEvent(KeyCode.End), 10, 3))
        @Expect(!scroll.handle(KeyEvent(KeyCode.Char(r'?')), 10, 3))

        let sort = SortState()
        sort.toggle(2)
        sort.toggle(2)
        sort.toggle(3)
        sort.set(-2, descending: true)
        sort.clear()
        @Expect(sort.column.isNone())
        let filter = FilterState()
        @Expect(filter.matches("anything"))
        filter.set("needle")
        @Expect(filter.matches("needle text"))
        @Expect(!filter.matches("other"))
        filter.clear()
        @Expect(filter.matches("other"))
    }

    @TestCase
    func keyMapAndHelpViewCoverKeyLabelsAndModifiers(): Unit {
        let keyCodes = [
            KeyCode.Char(r'a'),
            KeyCode.CtrlC,
            KeyCode.Esc,
            KeyCode.Tab,
            KeyCode.BackTab,
            KeyCode.Enter,
            KeyCode.Backspace,
            KeyCode.Delete,
            KeyCode.Insert,
            KeyCode.Up,
            KeyCode.Down,
            KeyCode.Left,
            KeyCode.Right,
            KeyCode.Home,
            KeyCode.End,
            KeyCode.PageUp,
            KeyCode.PageDown,
            KeyCode.F(5)
        ]
        let map = KeyMap()
        for (code in keyCodes) {
            map.add(KeyBinding(
                [KeyEvent(code, modifiers: KeyModifier(ctrl: true, alt: true, shift: true))],
                "action"
            ))
        }
        for (code in keyCodes) {
            let event = KeyEvent(code, modifiers: KeyModifier(ctrl: true, alt: true, shift: true))
            @Expect(map.actionFor(event).isSome())
        }
        @Expect(map.actionFor(KeyEvent(KeyCode.Char(r'z'))).isNone())
        @Expect(map.all().size, keyCodes.size)

        let buffer = Buffer(Rect(0, 0, 80, 2))
        HelpView(map, separator: " | ").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "c")
        HelpView(KeyMap()).render(Rect(0, 0, 0, 1), buffer)
        HelpView(KeyMap()).render(Rect(0, 0, 1, 0), buffer)
    }

    @TestCase
    func navigationWidgetsHandleKeysAndProgressBranches(): Unit {
        let tabs = Tabs(["one", "two"], selected: 1)
        @Expect(tabs.handle(KeyEvent(KeyCode.Left)))
        @Expect(tabs.selected, 0)
        @Expect(tabs.handle(KeyEvent(KeyCode.Right)))
        @Expect(tabs.selected, 1)
        @Expect(!tabs.handle(KeyEvent(KeyCode.Enter)))
        let tabsBuffer = Buffer(Rect(0, 0, 8, 1))
        tabs.render(tabsBuffer.area, tabsBuffer)
        tabs.render(Rect(0, 0, 0, 1), tabsBuffer)

        let progress = StatusBarProgress(50, total: 100, width: 8, label: "50%")
        let statusBuffer = Buffer(Rect(0, 0, 30, 1))
        StatusBar(left: "left", right: "right", progress: Some(progress)).render(statusBuffer.area, statusBuffer)
        StatusBar(left: "left", right: "").render(Rect(0, 0, 5, 1), statusBuffer)
        StatusBar(left: "left", right: "right", progress: Some(StatusBarProgress(1, width: 1))).render(Rect(0, 0, 8, 1), statusBuffer)
        StatusBar().render(Rect(0, 0, 0, 1), statusBuffer)
        @Expect(statusBuffer.getCell(0, 0).symbol, "l")

        let viewport = Viewport(["a", "b", "c"], block: Some(Block(title: "V")))
        @Expect(viewport.handle(KeyEvent(KeyCode.Up), 2))
        @Expect(viewport.handle(KeyEvent(KeyCode.Down), 2))
        @Expect(viewport.handle(KeyEvent(KeyCode.PageUp), 2))
        @Expect(viewport.handle(KeyEvent(KeyCode.PageDown), 2))
        @Expect(viewport.handle(KeyEvent(KeyCode.Home), 2))
        @Expect(viewport.handle(KeyEvent(KeyCode.End), 2))
        @Expect(!viewport.handle(KeyEvent(KeyCode.Char(r'?')), 2))
        viewport.render(Rect(0, 0, 10, 3), Buffer(Rect(0, 0, 10, 3)))
        Viewport(["x"]).render(Rect(0, 0, 0, 1), statusBuffer)
    }

    @TestCase
    func canvasViewportAndDrawingCoverClippingPaths(): Unit {
        let area = Rect(0, 0, 10, 5)
        let buffer = Buffer(area)
        let guard = SizeGuard(4, 3)
        @Expect(guard.fit(area).content, Rect(3, 1, 4, 3))
        @Expect(guard.fit(Rect(0, 0, 2, 2)).tooSmall)
        let stretched = guard.fit(area, policy: ResizePolicy.Stretch)
        @Expect(stretched.content, area)

        let surface = Surface(Rect(1, 1, 4, 2), zIndex: 2)
        surface.canvas().fillRect(Rect(1, 1, 2, 1), Style(bg: Color.Blue))
        let canvas = Canvas(buffer, area, translateX: 1, translateY: 1)
        canvas.fillRect(Rect(-2, -2, 1, 1), Style.default())
        canvas.hline(0, 0, 3, "-", Style.default())
        canvas.hline(0, 0, 0, "-", Style.default())
        canvas.vline(0, 0, 2, "|", Style.default())
        canvas.vline(0, 0, 0, "|", Style.default())
        canvas.strokeRect(Rect(0, 0, 4, 1), Style.default())
        canvas.strokeRect(Rect(1, 1, 4, 3), Style.default())
        canvas.drawLine(0, 0, 3, 2, "*", Style.default())
        canvas.drawLine(3, 2, 0, 0, "*", Style.default())
        canvas.drawText(-1, 2, "abcdef", Style.default())
        canvas.drawText(1, 3, "界", Style.default())
        canvas.drawSprite(0, 0, ["a", "b"], Style.default())
        canvas.render(Paragraph("x"), Rect(0, 0, 1, 1))
        canvas.render(Paragraph("x"), Rect(20, 20, 1, 1))
        canvas.composite(surface)
        @Expect(centeredViewport(area, 20, 20), area)
    }

    @TestCase
    func mediaFramesPlacementsAndDiffsCoverAllProtocols(): Unit {
        let source = MediaSource("plot", "plot.svg", kind: MediaKind.Diagram, alt: "Plot")
        @Expect(mediaFallbackText(source), "Plot")
        @Expect(mediaFallbackText(MediaSource("id", "uri")), "uri")
        @Expect(mediaFallbackText(MediaSource("id", "")), "id")
        let text = MediaFrameData.text("hello")
        let kitty = MediaFrameData.kitty([1, 2, 3], widthPixels: -1, heightPixels: 2)
        let sixel = MediaFrameData.sixel("sixel", widthPixels: 4, heightPixels: -1)
        @Expect(mediaProtocolName(text.protocol), "text")
        @Expect(mediaProtocolName(kitty.protocol), "kitty")
        @Expect(mediaProtocolName(sixel.protocol), "sixel")
        @Expect(kitty.payload, "AQID")
        let old = MediaPlacement("plot", source, Rect(0, 0, 2, 2), fit: MediaFit.Contain, frameIndex: -1)
        let same = MediaPlacement("plot", source, Rect(0, 0, 2, 2), fit: MediaFit.Contain)
        let changed = MediaPlacement("plot", source, Rect(1, 0, 2, 2), fit: MediaFit.Cover, frame: Some(sixel))
        @Expect(old.frameIndex, 0)
        @Expect(old.sameRenderContent(same))
        let ops = diffMediaPlacements([old, MediaPlacement("gone", source, Rect(0, 0, 1, 1))], [same, changed, MediaPlacement("new", source, Rect(0, 0, 1, 1))])
        @Expect(ops.size, 4)
    }

    @TestCase
    func dashboardStatusAndThemeResolverRenderPublicStates(): Unit {
        let buffer = Buffer(Rect(0, 0, 40, 10))
        MetricCard("CPU", "42%", detail: "user").render(Rect(0, 0, 10, 4), buffer)
        Meter("RAM", 50).render(Rect(0, 4, 18, 1), buffer)
        Legend([LegendItem("rx"), LegendItem("tx", symbol: "*", style: Style(fg: Color.Green))]).render(Rect(0, 5, 20, 1), buffer)
        TimeSeriesChart([1, 2, 3], maxValue: 3).render(Rect(20, 0, 3, 3), buffer)
        HeaderBar("Title", left: "L", right: "R").render(Rect(0, 6, 20, 1), buffer)
        FooterBar(left: "ready").render(Rect(0, 7, 20, 1), buffer)
        EmptyState(title: "Empty").render(Rect(20, 3, 10, 3), buffer)
        InlineAlert("Warn").render(Rect(0, 8, 10, 1), buffer)

        @Expect(buffer.getCell(0, 0).symbol, "C")
        @Expect(buffer.getCell(0, 4).symbol, "R")
        @Expect(buffer.getCell(20, 2).symbol, "#")
        @Expect(buffer.getCell(0, 6).symbol, "L")
        @Expect(buffer.getCell(0, 8).symbol, "W")
    }
    @TestCase
    func generatedUnicodeTablesCoverEveryScalarRange(): Unit {
        var pictographicCount: Int64 = 0
        for (code in 0..0x110000) {
            let scalar = UInt32(code)
            _ = graphemeBreakClass(scalar)
            _ = indicConjunctBreakClass(scalar)
            if (isExtendedPictographic(scalar)) {
                pictographicCount++
            }
        }
        @Expect(pictographicCount > 0)
    }
}
