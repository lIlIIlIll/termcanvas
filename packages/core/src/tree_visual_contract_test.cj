package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TreeVisualContractTest {
    @TestCase
    func selectionAndDisclosureHaveSeparateCellsAndHitTargets(): Unit {
        let root = TreeNode("root", "Root", children: [TreeNode("leaf", "Leaf")])
        let selected = Style(fg: Color.Cyan, bg: Color.Blue)
        let focused = Style(fg: Color.Yellow, bg: Color.Black)
        let tree = Tree([root], selectedStyle: selected, focusedStyle: focused)
        let area = Rect(1, 1, 12, 3)
        let buffer = Buffer(Rect(0, 0, 15, 5))
        tree.render(area, buffer)
        @Expect(buffer.getCell(1, 1).symbol, "●")
        @Expect(buffer.getCell(3, 1).symbol, "+")
        @Expect(buffer.getCell(12, 1).style, selected)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), area))
        @Expect(!root.expanded)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 1), area))
        @Expect(root.expanded)
        tree.setFocused(true)
        tree.render(area, buffer)
        @Expect(buffer.getCell(3, 1).symbol, "-")
        @Expect(buffer.getCell(12, 1).style, focused)
        @Expect(buffer.getCell(0, 1).symbol, " ")
    }

    @TestCase
    func asciiAndMonochromeRetainSelectionAndFocusCues(): Unit {
        let tree = Tree([TreeNode("one", "One")])
        let buffer = Buffer(Rect(0, 0, 12, 1))
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 1, unicode: false))
        tree.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "*")
        @Expect(buffer.getCell(0, 0).style.modifier.bold)
        tree.setFocused(true)
        tree.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style.modifier.underline)
    }
}
