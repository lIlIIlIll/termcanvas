package core

import std.unittest.*
import std.unittest.testmacro.*

private class ParentThemeTreeSource <: TreeDataSource {
    public func rootCount(): Int64 { 1 }
    public func nodeAt(path: Array<Int64>): ?LazyTreeNode {
        if (path.size == 1 && path[0] == 0) { return Some(LazyTreeNode("root", "Root")) }
        Option<LazyTreeNode>.None
    }
    public func pathForId(id: String): ?Array<Int64> {
        if (id == "root") { return Some([0]) }
        Option<Array<Int64>>.None
    }
}

@Test
class TreeParentThemeTest {
    @TestCase
    func mouseBeforeFirstPaintUsesExplicitTreeOrSuppliedApplicationTheme(): Unit {
        let area = Rect(0, 0, 12, 3)
        let noBorder = Theme(borderKind: BorderKind.NoBorder)
        let bordered = Theme(borderKind: BorderKind.Unicode)
        let direct = Tree([TreeNode("root", "Root")], block: Block(), theme: noBorder)
        @Expect(direct.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
        let contextual = Tree([TreeNode("root", "Root")], block: Block())
        @Expect(contextual.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area, theme: noBorder))
        let explicitTree = Tree([TreeNode("root", "Root")], block: Block(), theme: bordered)
        @Expect(!explicitTree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area, theme: noBorder))
        let explicitBlock = Tree([TreeNode("root", "Root")], block: Block(BlockOptions(theme: bordered)), theme: noBorder)
        @Expect(!explicitBlock.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
    }

    @TestCase
    func treeThemeControlsBlockGeometryAndMouseAfterThemeChanges(): Unit {
        let app = Theme(borderKind: BorderKind.Unicode, border: Style(fg: Color.Green))
        let parent = Theme(borderKind: BorderKind.NoBorder, canvas: Style(bg: Color.Blue))
        let block = Block()
        let tree = Tree([TreeNode("first", "First"), TreeNode("second", "Second")], block: block, theme: parent)
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setTheme(app)
        tree.render(buffer.area, buffer)
        @Expect(block.inner(buffer.area), buffer.area)
        @Expect(buffer.getCell(0, 0).symbol, "●")
        @Expect(buffer.getCell(11, 3).style, parent.canvas)
        @Expect(tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), buffer.area))
        @Expect(tree.selectedId(), Some("second"))

        tree.setTheme(Option<Theme>.None)
        buffer.clear()
        tree.render(buffer.area, buffer)
        @Expect(block.inner(buffer.area), Rect(1, 1, 10, 2))
        @Expect(buffer.getCell(0, 0).symbol, "┌")
        @Expect(buffer.getCell(0, 0).style, app.border)
        @Expect(!tree.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), buffer.area))
        @Expect(tree.selectedId(), Some("second"))
    }

    @TestCase
    func explicitBlockThemeWinsOverTreeAndApplication(): Unit {
        let app = Theme(borderKind: BorderKind.Rounded, border: Style(fg: Color.Green))
        let parent = Theme(borderKind: BorderKind.NoBorder)
        let child = Theme(borderKind: BorderKind.Unicode, border: Style(fg: Color.Red))
        let block = Block(BlockOptions(theme: child))
        let tree = Tree([TreeNode("root", "Root")], block: block, theme: parent)
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setTheme(app)
        tree.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "┌")
        @Expect(buffer.getCell(0, 0).style, child.border)
        @Expect(buffer.getCell(1, 1).symbol, "●")
        @Expect(block.inner(buffer.area), Rect(1, 1, 10, 2))
        @Expect(buffer.theme().getOrThrow().border, app.border)
    }

    @TestCase
    func lazyTreeUsesSameParentThemeForItsBlock(): Unit {
        let app = Theme(borderKind: BorderKind.Unicode)
        let parent = Theme(borderKind: BorderKind.NoBorder, canvas: Style(bg: Color.Blue))
        let block = Block()
        let tree = Tree(LazyTreeModel(ParentThemeTreeSource()), block: block, theme: parent)
        let buffer = Buffer(Rect(0, 0, 12, 3))
        buffer.setTheme(app)
        tree.render(buffer.area, buffer)
        @Expect(block.inner(buffer.area), buffer.area)
        @Expect(buffer.getCell(0, 0).symbol, "●")
        @Expect(buffer.getCell(11, 2).style, parent.canvas)
    }
}
