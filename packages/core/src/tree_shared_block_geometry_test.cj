package core
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TreeSharedBlockGeometryTest {
    @TestCase
    func inheritedThemeGeometryBelongsToEachTree(): Unit {
        let area = Rect(0, 0, 12, 4)
        let shared = Block()
        let first = Tree([TreeNode("one", "One"), TreeNode("two", "Two")], block: shared)
        let second = Tree([TreeNode("other", "Other")], block: shared)
        let borderless = Buffer(area)
        borderless.setTheme(Some(Theme(borderKind: BorderKind.NoBorder)))
        let bordered = Buffer(area)
        bordered.setTheme(Some(Theme(borderKind: BorderKind.Unicode)))
        first.render(area, borderless)
        second.render(area, bordered)
        @Expect(first.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), area))
        @Expect(first.selectedId(), Some("two"))
        first.render(area, borderless)
        @Expect(!second.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), area))
        @Expect(second.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), area))
    }

    @TestCase
    func unrenderedTreeDoesNotInheritSharedBlocksLastTheme(): Unit {
        let area = Rect(0, 0, 12, 3)
        let shared = Block()
        let rendered = Tree([TreeNode("first", "First")], block: shared)
        let buffer = Buffer(area)
        buffer.setTheme(Some(Theme(borderKind: BorderKind.NoBorder)))
        rendered.render(area, buffer)
        let unrendered = Tree([TreeNode("other", "Other")], block: shared)
        @Expect(!unrendered.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 0), area))
        @Expect(unrendered.handle(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 1), area))
    }
}
