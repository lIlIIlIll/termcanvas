package cjtui_workbench
import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class GhostButtonTest {
    @TestCase
    func galleryGhostStaysBorderlessWhenNormalStyleIsEmpty(): Unit {
        let app = WorkbenchApp()
        app.theme = Theme(normal: Style.default())
        let area = Rect(0, 0, 12, 1)
        let buffer = Buffer(area)
        let button = galleryButton(app, "Ghost", 2, "ghost-preview")
        button.render(area, buffer)
        @Expect(buffer.getCell(2, 0).symbol, " ")
        @Expect(buffer.getCell(3, 0).symbol, "G")
    }
}
