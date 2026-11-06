package core

import std.unittest.*
import std.unittest.testmacro.*

class WidthTestTranscriptSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "one" }
    public func revision(_: Int64): Int64 { 0 }
    public func document(_: Int64, _: Int64, _: String): Document { Document.plain("a·b") }
}

@Test
class TextWidthContextTest {
    @TestCase
    func bufferAndCanvasRespectWidePolicyAndPreserveItOnCopy(): Unit {
        let area = Rect(0, 0, 8, 2)
        let buffer = Buffer(area)
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        buffer.setTextWidthOptions(wide)
        buffer.setString(0, 0, "·界e\u{301}😀")
        @Expect(buffer.getCell(0, 0), Cell("·", kind: CellKind.WideLead))
        @Expect(buffer.getCell(1, 0), Cell("", kind: CellKind.WideCont))
        @Expect(buffer.getCell(2, 0), Cell("界", kind: CellKind.WideLead))
        @Expect(buffer.getCell(4, 0).symbol, "e\u{301}")
        @Expect(buffer.getCell(5, 0), Cell("😀", kind: CellKind.WideLead))
        let copied = buffer.copy()
        copied.setString(0, 1, "·x")
        @Expect(copied.getCell(2, 1).symbol, "x")
        let resized = buffer.resize(Rect(0, 0, 9, 2))
        resized.setString(0, 1, "·x")
        @Expect(resized.getCell(2, 1).symbol, "x")
        let clipped = Buffer(area)
        clipped.setTextWidthOptions(wide)
        Canvas(clipped, Rect(1, 0, 3, 1)).drawText(0, 0, "·ab", Style.default())
        @Expect(clipped.getCell(1, 0).symbol, " ")
        @Expect(clipped.getCell(2, 0).symbol, "a")
        @Expect(clipped.getCell(3, 0).symbol, "b")
    }

    @TestCase
    func paragraphWrapAndBuiltInBorderUseTheBufferPolicy(): Unit {
        let area = Rect(0, 0, 4, 3)
        let buffer = Buffer(area)
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        Paragraph("a·b", wrap: WrapMode.Character).render(Rect(0, 0, 3, 2), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(buffer.getCell(1, 0).symbol, "·")
        @Expect(buffer.getCell(0, 1).symbol, "b")
        buffer.clear()
        Block().render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
        @Expect(buffer.getCell(3, 0).symbol, "+")
    }

    @TestCase
    func inputAndTextAreaKeepCursorAlignedWithRenderedColumns(): Unit {
        let area = Rect(0, 0, 8, 2)
        let buffer = Buffer(area)
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        let input = Input(value: "·x", cursor: "·".size, showBoundary: false)
        input.render(area, buffer)
        @Expect(input.cursorPosition(area).x, 2)
        @Expect(buffer.getCell(2, 0).symbol, "x")
        buffer.clear()
        let editor = TextArea(value: "·x", cursor: "·".size)
        editor.render(area, buffer)
        @Expect(editor.cursorPosition(area).x, 2)
        @Expect(buffer.getCell(2, 0).symbol, "x")
    }

    @TestCase
    func cursorCanBeMeasuredBeforeRenderingAndAfterPolicyChanges(): Unit {
        let area = Rect(0, 0, 8, 2)
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let narrow = TextWidthOptions()
        let buffer = Buffer(area)
        let input = Input(value: "·x", cursor: "·".size, showBoundary: false)
        let editor = TextArea(value: "·x", cursor: "·".size)
        @Expect(input.cursorPosition(area, options: wide).x, 2)
        @Expect(editor.cursorPosition(area, options: wide).x, 2)
        buffer.setTextWidthOptions(wide)
        input.render(area, buffer)
        @Expect(buffer.getCell(2, 0).symbol, "x")
        @Expect(input.cursorPosition(area, options: narrow).x, 1)
        @Expect(editor.cursorPosition(area, options: narrow).x, 1)
        buffer.setTextWidthOptions(narrow)
        buffer.clear()
        input.render(area, buffer)
        @Expect(buffer.getCell(1, 0).symbol, "x")
    }

    @TestCase
    func wideTreeMarkerKeepsRowsAndDisclosureHitTargetsAligned(): Unit {
        let first = TreeNode("first", "First", children: [TreeNode("child", "Child")])
        let second = TreeNode("second", "Second")
        let tree = Tree([first, second])
        let area = Rect(0, 0, 12, 2)
        let buffer = Buffer(area)
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        tree.render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "*")
        @Expect(buffer.getCell(2, 0).symbol, "+")
        @Expect(buffer.getCell(4, 0).symbol, "F")
        @Expect(buffer.getCell(4, 1).symbol, "S")
        @Expect(tree.handle(KeyEvent(KeyCode.Down), 2))
        buffer.clear()
        tree.render(area, buffer)
        @Expect(buffer.getCell(4, 0).symbol, "F")
        @Expect(buffer.getCell(0, 1).symbol, "*")
        @Expect(buffer.getCell(4, 1).symbol, "S")
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 0), area))
        @Expect(first.expanded)
    }

    @TestCase
    func navigationAndDocumentCachesFollowChangedPolicy(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let buffer = Buffer(Rect(0, 0, 10, 3))
        buffer.setTextWidthOptions(wide)
        let tabs = Tabs(["·", "X"])
        tabs.render(Rect(0, 0, 10, 1), buffer)
        @Expect(buffer.getCell(4, 0).symbol, " ")
        @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 0), Rect(0, 0, 10, 1)))
        @Expect(tabs.selected, 1)
        let doc = DocumentView(Document.plain("a·b"), wrap: WrapMode.Character, cacheLayout: true)
        @Expect(doc.renderedLineCount(3), 1)
        doc.setTextWidthOptions(wide)
        @Expect(doc.renderedLineCount(3), 2)
        doc.setTextWidthOptions(TextWidthOptions())
        @Expect(doc.renderedLineCount(3), 1)
    }

    @TestCase
    func transcriptRemeasuresWhenWidthPolicyChanges(): Unit {
        let view = VirtualTranscriptView(WidthTestTranscriptSource())
        let area = Rect(0, 0, 3, 3)
        let buffer = Buffer(area)
        view.render(area, buffer)
        @Expect(view.totalRows(), 2)
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        buffer.clear()
        view.render(area, buffer)
        @Expect(view.totalRows(), 3)
        @Expect(buffer.getCell(0, 1).symbol, "b")
    }

    @TestCase
    func automaticChartsRemainVisibleInWideMode(): Unit {
        let buffer = Buffer(Rect(0, 0, 5, 2))
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        ProgressBar(1, total: 100).render(Rect(0, 0, 5, 1), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "=")
        Sparkline([1, 2, 3]).render(Rect(0, 1, 3, 1), buffer)
        @Expect(buffer.getCell(0, 1).symbol, ".")
        @Expect(buffer.getCell(2, 1).symbol, "#")
    }

    @TestCase
    func terminalReconfiguresAndRedrawsWithNewPolicy(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 5, 1))
        let terminal = Terminal(backend)
        terminal.draw({frame => frame.canvas().drawText(0, 0, "·x", Style.default())})
        match (backend.lastBuffer()) {
            case Some(buffer) => @Expect(buffer.getCell(1, 0).symbol, "x")
            case None => @Assert(false)
        }
        terminal.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        terminal.draw({frame => frame.canvas().drawText(0, 0, "·x", Style.default())})
        match (backend.lastBuffer()) {
            case Some(buffer) => @Expect(buffer.getCell(2, 0).symbol, "x")
            case None => @Assert(false)
        }
    }
}
