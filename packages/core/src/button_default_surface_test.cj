package core
import std.unittest.*
import std.unittest.testmacro.*

@Test
class ButtonDefaultSurfaceTest {
    @TestCase
    func themedDefaultHasVisibleSurfaceAndBoundary(): Unit {
        let area = Rect(0, 0, 10, 1)
        let theme = Theme.indigo()
        let buffer = Buffer(area)
        Button("OK", theme: theme).render(area, buffer)
        @Expect(colorEquals(buffer.getCell(0, 0).style.bg, theme.raisedSurface.bg))
        @Expect(buffer.getCell(3, 0).symbol, "[")
        @Expect(buffer.getCell(4, 0).symbol, "O")
        @Expect(buffer.getCell(6, 0).symbol, "]")
    }

    @TestCase
    func explicitThemeNormalRetainsGhostAppearance(): Unit {
        let area = Rect(0, 0, 10, 1)
        let theme = Theme.indigo()
        let buffer = Buffer(area)
        Button("OK", style: theme.normal, theme: theme).render(area, buffer)
        @Expect(colorEquals(buffer.getCell(0, 0).style.bg, theme.normal.bg))
        @Expect(buffer.getCell(3, 0).symbol, " ")
        @Expect(buffer.getCell(4, 0).symbol, "O")
    }

    @TestCase
    func monochromeAndFocusedDefaultKeepBoundary(): Unit {
        let area = Rect(0, 0, 10, 1)
        let buffer = Buffer(area)
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 1, unicode: false))
        Button("OK", focused: true, theme: Theme.indigo()).render(area, buffer)
        @Expect(buffer.getCell(3, 0).symbol, "[")
        @Expect(buffer.getCell(6, 0).symbol, "]")
        @Expect(buffer.getCell(4, 0).style.modifier.underline)
        @Expect(!buffer.getCell(3, 0).style.modifier.underline)
    }

    @TestCase
    func noThemeRetainsLegacyAppearanceAndTinyAreaDoesNotOverflow(): Unit {
        let area = Rect(0, 0, 10, 1)
        let buffer = Buffer(area)
        Button("OK").render(area, buffer)
        @Expect(buffer.getCell(3, 0).symbol, " ")
        @Expect(buffer.getCell(4, 0).symbol, "O")
        let tiny = Buffer(Rect(0, 0, 3, 1))
        Button("OK", theme: Theme.indigo()).render(Rect(1, 0, 1, 1), tiny)
        @Expect(tiny.getCell(0, 0).symbol, " ")
        @Expect(tiny.getCell(2, 0).symbol, " ")
    }

    @TestCase
    func disabledAndWideLabelsKeepBoundaryWithinArea(): Unit {
        let theme = Theme.indigo()
        let area = Rect(0, 0, 6, 1)
        let buffer = Buffer(area)
        buffer.setTheme(Some(theme))
        Button("界", disabled: true).render(area, buffer)
        @Expect(buffer.getCell(1, 0).symbol, "[")
        @Expect(buffer.getCell(2, 0).symbol, "界")
        @Expect(buffer.getCell(4, 0).symbol, "]")
        @Expect(buffer.getCell(2, 0).style.modifier.italic)
    }

    @TestCase
    func ghostCanBeSelectedWhenThemeNormalIsEmpty(): Unit {
        let area = Rect(0, 0, 10, 1)
        let theme = Theme(normal: Style.default(), raisedSurface: Style(bg: Color.Blue))
        let buffer = Buffer(area)
        let button = Button("OK", theme: theme)
        button.setGhost(true)
        button.render(area, buffer)
        @Expect(buffer.getCell(3, 0).symbol, " ")
        @Expect(buffer.getCell(0, 0).style, theme.normal)
        button.setGhost(false)
        button.render(area, buffer)
        @Expect(buffer.getCell(3, 0).symbol, "[")
        @Expect(buffer.getCell(0, 0).style, theme.raisedSurface)
    }
}
