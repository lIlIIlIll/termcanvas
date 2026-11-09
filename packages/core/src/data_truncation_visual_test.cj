package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class DataTruncationVisualTest {
    @TestCase
    func tableShowsClippingWithoutLosingSelectionStyleOrCrossingColumn(): Unit {
        let selected = Style(fg: Color.Yellow, bg: Color.Blue)
        let area = Rect(2, 1, 12, 3)
        let buffer = Buffer(Rect(0, 0, 16, 5))
        buffer.setString(area.right, 3, "!")
        Table(["Heading", "Status"], [["A界BC", "Ready"]], widths: [4, 4],
            state: Some(TableState(selectedRow: Some(0))), selectedStyle: selected, focused: true).render(area, buffer)
        @Expect(buffer.getCell(4, 1).symbol, "H")
        @Expect(buffer.getCell(7, 1).symbol, "…")
        @Expect(buffer.getCell(4, 3).symbol, "A")
        @Expect(buffer.getCell(5, 3).symbol, "界")
        @Expect(match (buffer.getCell(6, 3).kind) { case CellKind.WideCont => true; case _ => false })
        @Expect(buffer.getCell(7, 3).symbol, "…")
        @Expect(buffer.getCell(9, 3).symbol, "R")
        @Expect(buffer.getCell(12, 3).symbol, "…")
        @Expect(Style(fg: buffer.getCell(7, 3).style.fg), Style(fg: selected.fg))
        @Expect(Style(bg: buffer.getCell(7, 3).style.bg), Style(bg: selected.bg))
        @Expect(buffer.getCell(7, 3).style.modifier.underline)
        @Expect(buffer.getCell(area.right, 3).symbol, "!")
    }

    @TestCase
    func tableHandlesExactFitTinyWidthsAndAsciiFallback(): Unit {
        for (unicode in [true, false]) {
            let buffer = Buffer(Rect(0, 0, 8, 3))
            buffer.setCapabilities(TerminalCapabilities(unicode: unicode))
            Table(["H"], [["A界BC"]], widths: [5]).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 2).symbol, "A")
            @Expect(buffer.getCell(4, 2).symbol, "C")
            let clipped = Buffer(Rect(0, 0, 8, 3))
            clipped.setCapabilities(TerminalCapabilities(unicode: unicode))
            Table(["H"], [["A界BC"]], widths: [3]).render(clipped.area, clipped)
            @Expect(clipped.getCell(0, 2).symbol, "A")
            @Expect(clipped.getCell(1, 2).symbol, if (unicode) { "…" } else { "." })
            @Expect(clipped.getCell(2, 2).symbol, " ")
            let tiny = Buffer(Rect(0, 0, 1, 3))
            tiny.setCapabilities(TerminalCapabilities(unicode: unicode))
            Table(["Heading"], [["long"]]).render(tiny.area, tiny)
            @Expect(tiny.getCell(0, 0).symbol, if (unicode) { "…" } else { "." })
            @Expect(tiny.getCell(0, 2).symbol, if (unicode) { "…" } else { "." })
        }
        let wideAmbiguous = Buffer(Rect(0, 0, 5, 3))
        wideAmbiguous.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        Table(["Heading"], [["long text"]], widths: [5]).render(wideAmbiguous.area, wideAmbiguous)
        @Expect(wideAmbiguous.getCell(4, 0).symbol, ".")
        @Expect(wideAmbiguous.getCell(4, 2).symbol, ".")
    }

    @TestCase
    func treeKeepsDisclosureAndFocusWhileClippingWholeGraphemes(): Unit {
        let selected = Style(fg: Color.Cyan, bg: Color.Blue)
        let focused = Style(fg: Color.Yellow, bg: Color.Black)
        let root = TreeNode("root", "A界BC", children: [TreeNode("leaf", "Leaf")])
        let tree = Tree([root], selectedStyle: selected, focusedStyle: focused)
        let area = Rect(1, 1, 8, 2)
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setString(area.right, area.y, "!")
        tree.render(area, buffer)
        @Expect(buffer.getCell(3, 1).symbol, "+")
        @Expect(buffer.getCell(5, 1).symbol, "A")
        @Expect(buffer.getCell(6, 1).symbol, "界")
        @Expect(match (buffer.getCell(7, 1).kind) { case CellKind.WideCont => true; case _ => false })
        @Expect(buffer.getCell(8, 1).symbol, "…")
        @Expect(buffer.getCell(8, 1).style, selected)
        @Expect(buffer.getCell(area.right, area.y).symbol, "!")
        tree.setFocused(true)
        tree.render(area, buffer)
        @Expect(buffer.getCell(8, 1).style, focused)
        let exact = Buffer(Rect(0, 0, 9, 1))
        tree.render(exact.area, exact)
        @Expect(exact.getCell(8, 0).symbol, "C")
    }

    @TestCase
    func treeUsesSingleCellFallbackWithAsciiAndWideAmbiguousText(): Unit {
        let tree = Tree([TreeNode("root", "ABCD")])
        let area = Rect(0, 0, 7, 1)
        let ascii = Buffer(area)
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        tree.render(area, ascii)
        @Expect(ascii.getCell(6, 0).symbol, ".")
        let wide = Buffer(area)
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        tree.render(area, wide)
        @Expect(wide.getCell(6, 0).symbol, ".")
        let one = Buffer(Rect(0, 0, 5, 1))
        tree.render(one.area, one)
        @Expect(one.getCell(4, 0).symbol, "…")
        let normal = Style(fg: Color.Red)
        let unselected = Buffer(area)
        Tree([TreeNode("first", "ABCD"), TreeNode("second", "Other")], selected: 1, style: normal).render(area, unselected)
        @Expect(unselected.getCell(6, 0).symbol, "…")
        @Expect(unselected.getCell(6, 0).style, normal)
    }

    @TestCase
    func clippedCellsEraseOnlyTheirUnusedRemainder(): Unit {
        let bounds = Rect(0, 0, 10, 3)
        let table = Buffer(bounds)
        table.fill(bounds, Cell("Z"))
        Table(["A界BC"], [["A界BC"]], widths: [3]).render(Rect(1, 0, 3, 3), table)
        @Expect(table.getCell(1, 0).symbol, "A")
        @Expect(table.getCell(2, 0).symbol, "…")
        @Expect(table.getCell(3, 0).symbol, " ")
        @Expect(table.getCell(4, 0).symbol, "Z")
        let tree = Buffer(bounds)
        tree.fill(bounds, Cell("Z"))
        let normal = Style(fg: Color.Red)
        Tree([TreeNode("one", "A界BC"), TreeNode("two", "two")], selected: 1, style: normal).render(Rect(1, 0, 7, 2), tree)
        @Expect(tree.getCell(5, 0).symbol, "A")
        @Expect(tree.getCell(6, 0).symbol, "…")
        @Expect(tree.getCell(7, 0).symbol, " ")
        @Expect(tree.getCell(7, 0).style, normal)
        @Expect(tree.getCell(8, 0).symbol, "Z")
    }

    @TestCase
    func deepTreeKeepsLabelAndDisclosureHitTestingInNarrowSpace(): Unit {
        let branch = TreeNode("deep", "Node", children: [TreeNode("leaf", "Leaf")])
        let child = TreeNode("child", "Child", expanded: true, children: [branch])
        let root = TreeNode("root", "Root", expanded: true, children: [child])
        let tree = Tree([root])
        let area = Rect(1, 0, 8, 3)
        let buffer = Buffer(Rect(0, 0, 10, 3))
        tree.render(area, buffer)
        @Expect(buffer.getCell(5, 2).symbol, "+")
        @Expect(buffer.getCell(7, 2).symbol, "N")
        @Expect(buffer.getCell(8, 2).symbol, "…")
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 7, 2), area))
        @Expect(!branch.expanded)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 2), area))
        @Expect(branch.expanded)
        for (width in 1..5) {
            let tiny = Buffer(Rect(0, 0, width, 1))
            Tree([TreeNode("tiny", "Long", children: [TreeNode("leaf", "leaf")])]).render(tiny.area, tiny)
            @Expect(tiny.getCell(width - 1, 0).symbol, "…")
        }
    }

    @TestCase
    func virtualTablePreservesSortCueAndClipsSelectedWideCell(): Unit {
        let active = Style(fg: Color.Magenta, bg: Color.Blue)
        let table = VirtualTable([TableColumn("A界BC", width: 3)], 1, { _ => ["A界BC"] },
            selectedRow: Some(0), cellStyle: active)
        let area = Rect(1, 0, 3, 2)
        let buffer = Buffer(Rect(0, 0, 6, 2))
        buffer.fill(buffer.area, Cell("Z"))
        table.render(area, buffer)
        @Expect(buffer.getCell(1, 0).symbol, "A")
        @Expect(buffer.getCell(2, 0).symbol, "…")
        @Expect(buffer.getCell(3, 0).symbol, " ")
        @Expect(buffer.getCell(3, 1).symbol, " ")
        @Expect(buffer.getCell(2, 1).style, active)
        @Expect(buffer.getCell(4, 1).symbol, "Z")
        table.sortBy(0)
        table.render(area, buffer)
        @Expect(buffer.getCell(1, 0).symbol, "…")
        @Expect(buffer.getCell(3, 0).symbol, "^")
    }

    @TestCase
    func virtualTableSortDirectionSurvivesOneAndTwoColumnWidths(): Unit {
        let longTitle = "Name" + repeat("x", 1000000)
        for (unicode in [true, false]) {
            for (descending in [true, false]) {
                for (width in 1..3) {
                    let table = VirtualTable([TableColumn(longTitle, width: width)], 0, { _ => Array<String>() })
                    table.sortBy(0, descending: descending)
                    let buffer = Buffer(Rect(0, 0, width, 1))
                    buffer.setCapabilities(TerminalCapabilities(unicode: unicode))
                    table.render(buffer.area, buffer)
                    @Expect(buffer.getCell(width - 1, 0).symbol, if (descending) { "v" } else { "^" })
                    if (width == 2) {
                        @Expect(buffer.getCell(0, 0).symbol, if (unicode) { "…" } else { "." })
                    }
                }
            }
        }
    }

    @TestCase
    func truncationScansOnlyVisibleClustersAndKeepsEmojiWhole(): Unit {
        let text = "A👩\u{200D}💻" + repeat("x", 1000000)
        let (prefixEnd, scannedEnd, clipped) = ellipsisScan(text, 3, TextWidthOptions())
        @Expect(clipped)
        @Expect(prefixEnd, 1)
        @Expect(scannedEnd < 32)
        let buffer = Buffer(Rect(0, 0, 3, 3))
        Table(["x"], [[text]], widths: [3]).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "A")
        @Expect(buffer.getCell(1, 2).symbol, "…")
        let fits = Buffer(Rect(0, 0, 4, 3))
        Table(["x"], [["A👩\u{200D}💻"]], widths: [4]).render(fits.area, fits)
        @Expect(fits.getCell(1, 2).symbol, "👩\u{200D}💻")
        @Expect(match (fits.getCell(2, 2).kind) { case CellKind.WideCont => true; case _ => false })
    }
}
