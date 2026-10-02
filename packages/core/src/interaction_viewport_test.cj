package core

import std.unittest.*
import std.unittest.testmacro.*

func interactionRow(buffer: Buffer, y: Int64): String {
    var text = ""
    for (x in buffer.area.x..buffer.area.right) { text += buffer.getCell(x, y).symbol }
    text
}

@Test
class InteractionViewportTest {
    @TestCase
    func selectionWidgetsRenderTheirSelectedWindow(): Unit {
        let values = ["zero", "one", "two", "three", "four", "five"]
        let area = Rect(0, 0, 16, 2)
        let select = Buffer(area)
        Select(values, selected: 5).render(area, select)
        @Expect(interactionRow(select, 0).startsWith("four"))
        @Expect(interactionRow(select, 1).startsWith("five"))
        let radio = Buffer(area)
        RadioGroup(values, selected: 5).render(area, radio)
        @Expect(interactionRow(radio, 1).startsWith("(*) five"))
        let multi = Buffer(area)
        MultiSelect(values, cursor: 5).render(area, multi)
        @Expect(interactionRow(multi, 1).startsWith("[ ] five"))
        let menu = Buffer(area)
        Menu("", [MenuItem("zero"), MenuItem("one"), MenuItem("two"), MenuItem("three"), MenuItem("four"), MenuItem("five")], selected: 5).render(area, menu)
        @Expect(interactionRow(menu, 1).startsWith("five"))
    }

    @TestCase
    func dropdownAndPaletteKeepSelectedRowVisible(): Unit {
        let area = Rect(0, 0, 16, 3)
        let dropdown = Buffer(area)
        Dropdown(["zero", "one", "two", "three", "four", "five"], selected: 5, open: true).render(area, dropdown)
        @Expect(interactionRow(dropdown, 1).startsWith("four"))
        @Expect(interactionRow(dropdown, 2).startsWith("five"))
        let palette = CommandPalette([MenuItem("zero"), MenuItem("one"), MenuItem("two"), MenuItem("three"), MenuItem("four"), MenuItem("five")], selected: 5, block: None)
        let buffer = Buffer(area)
        palette.render(area, buffer)
        @Expect(interactionRow(buffer, 2).startsWith("five"))
        palette.query = "zero"
        palette.render(area, Buffer(area))
        @Expect(palette.handle(KeyEvent(KeyCode.Enter)), Some("zero"))
    }

    @TestCase
    func selectionViewportAdaptsToResizeAndPaging(): Unit {
        let selector = Select(["zero", "one", "two", "three", "four", "five"], selected: 5)
        selector.render(Rect(0, 0, 16, 2), Buffer(Rect(0, 0, 16, 2)))
        let wide = Buffer(Rect(0, 0, 16, 4))
        selector.render(wide.area, wide)
        @Expect(interactionRow(wide, 0).startsWith("two"))
        _ = selector.handle(KeyEvent(KeyCode.PageUp))
        @Expect(selector.selected, 1)
        let small = Buffer(Rect(0, 0, 16, 1))
        selector.render(small.area, small)
        @Expect(interactionRow(small, 0).startsWith("one"))
    }
}
