package core
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DialogThemeGeometryTest {
    @TestCase
    func explicitBorderlessThemeMatchesButtonsBeforeAndAfterRender(): Unit {
        let area = Rect(0, 0, 20, 7)
        let theme = Theme(borderKind: BorderKind.NoBorder)
        let dialog = Dialog(buttons: ["OK"], width: 20, height: 7, theme: theme)
        let first = MouseEvent(MouseKind.Down, MouseButton.Left, 0, 5)
        let after = MouseEvent(MouseKind.Down, MouseButton.Left, 4, 5)
        @Expect(dialog.handleMouse(first, area), Some("OK"))
        @Expect(dialog.handleMouse(after, area).isNone())
        let buffer = Buffer(area)
        dialog.render(area, buffer)
        @Expect(buffer.getCell(0, 5).symbol, "[")
        @Expect(dialog.handleMouse(first, area), Some("OK"))
        @Expect(dialog.handleMouse(after, area).isNone())
    }

    @TestCase
    func inheritedBorderlessThemeMatchesConfirmButtons(): Unit {
        let area = Rect(0, 0, 20, 7)
        let theme = Theme(borderKind: BorderKind.NoBorder)
        let dialog = ConfirmDialog("Proceed?")
        let buffer = Buffer(area)
        buffer.setTheme(Some(theme))
        dialog.render(area, buffer)
        @Expect(buffer.getCell(0, 5).symbol, "[")
        @Expect(buffer.getCell(5, 5).symbol, "[")
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 5), area), Some(false))
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 4, 5), area).isNone())
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 5, 5), area), Some(true))
    }

    @TestCase
    func updatesGeometryWhenInheritedThemeChanges(): Unit {
        let area = Rect(0, 0, 20, 7)
        let dialog = Dialog(buttons: ["OK"], width: 20, height: 7)
        let buffer = Buffer(area)
        buffer.setTheme(Some(Theme(borderKind: BorderKind.NoBorder)))
        dialog.render(area, buffer)
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 5), area), Some("OK"))
        buffer.setTheme(Some(Theme(borderKind: BorderKind.Ascii)))
        dialog.render(area, buffer)
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 5), area).isNone())
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 5), area), Some("OK"))
    }
}
