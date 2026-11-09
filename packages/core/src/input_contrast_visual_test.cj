package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class InputContrastVisualTest {
    @TestCase
    func indigoSixteenColorKeepsErrorAndMutedRolesLegible(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16, unicode: false)
        let theme = Theme.indigo().adapted(caps)
        @Expect(Style(fg: theme.error.fg), Style(fg: Color.Indexed(9)))
        @Expect(Style(fg: theme.secondary.fg), Style(fg: Color.Indexed(7)))
        let buffer = Buffer(Rect(0, 0, 3, 3))
        buffer.setCapabilities(caps)
        Scrollbar(20, viewport: 4, style: theme.secondary, thumbStyle: theme.accent).render(buffer.area, buffer)
        @Expect(buffer.getCell(2, 0).symbol, "#")
        @Expect(buffer.getCell(2, 2).symbol, "|")
        @Expect(buffer.getCell(2, 2).style, theme.secondary)
    }

    @TestCase
    func focusedErrorStylesTextWithoutUnderliningEmptyRows(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16, unicode: false)
        let area = Rect(1, 1, 12, 3)
        let buffer = Buffer(Rect(0, 0, 15, 5))
        buffer.setCapabilities(caps)
        buffer.setTheme(Theme.indigo())
        let input = Input(value: "Hello", cursor: 5)
        input.setVisualState(focused: true, error: true)
        input.render(area, buffer)
        @Expect(buffer.getCell(2, 1).symbol, "H")
        @Expect(Style(fg: buffer.getCell(2, 1).style.fg), Style(fg: Color.Indexed(9)))
        @Expect(buffer.getCell(2, 1).style.modifier.underline)
        @Expect(buffer.getCell(2, 1).style.modifier.italic)
        for (y in 2..4) {
            for (x in 1..13) { @Expect(!buffer.getCell(x, y).style.modifier.underline) }
        }
        @Expect(!buffer.getCell(11, 1).style.modifier.underline)
    }

    @TestCase
    func placeholderUsesStateCueAndRespectsExplicitGray(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16)
        let area = Rect(0, 0, 10, 2)
        let buffer = Buffer(area)
        buffer.setCapabilities(caps)
        buffer.setTheme(Theme.indigo())
        let input = Input(placeholder: "Name")
        input.setVisualState(focused: true, error: true)
        input.render(area, buffer)
        @Expect(Style(fg: buffer.getCell(1, 0).style.fg), Style(fg: Color.Indexed(9)))
        @Expect(buffer.getCell(1, 0).style.modifier.underline)
        @Expect(!buffer.getCell(1, 1).style.modifier.underline)
        let explicit = Input(placeholder: "Name", placeholderStyle: Style(fg: Color.Indexed(8)))
        explicit.setVisualState(focused: true, error: true)
        explicit.render(area, buffer)
        @Expect(Style(fg: buffer.getCell(1, 0).style.fg), Style(fg: Color.Indexed(8)))
        @Expect(buffer.getCell(1, 0).style.modifier.underline)
        let override = Input(value: "x", style: Style(fg: Color.Magenta))
        override.setVisualState(focused: true, error: true)
        override.render(area, buffer)
        @Expect(Style(fg: buffer.getCell(1, 0).style.fg), Style(fg: Color.Magenta))
    }

    @TestCase
    func monochromeAndNarrowInputsKeepFocusWithinText(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 1, unicode: false)
        for (width in [1, 2, 3]) {
            let buffer = Buffer(Rect(0, 0, width, 2))
            buffer.setCapabilities(caps)
            buffer.setTheme(Theme.indigo())
            let input = Input(value: "x")
            input.setVisualState(focused: true, error: true)
            input.render(buffer.area, buffer)
            for (x in 0..width) { @Expect(!buffer.getCell(x, 1).style.modifier.underline) }
            if (width == 3) {
                @Expect(buffer.getCell(1, 0).symbol, "x")
                @Expect(buffer.getCell(1, 0).style.modifier.underline)
            }
        }
    }

    @TestCase
    func explicitIndexedThemeRolesAndNonErrorColorsArePreserved(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16)
        let indexed = Style(fg: Color.Indexed(8), bg: Color.Black)
        let custom = Theme(error: indexed, secondary: indexed).adapted(caps)
        @Expect(custom.error, indexed)
        @Expect(custom.secondary, indexed)
        let blue = Style(fg: Color.Rgb(90, 100, 180), bg: Color.Black)
        @Expect(Theme(error: blue).adapted(caps).error, adaptStyleForCapabilities(blue, caps))
        let same = Style(fg: Color.Rgb(255, 122, 131), bg: Color.Rgb(19, 20, 34))
        let matchingRoles = Theme(normal: same, error: same, secondary: same, disabled: same).adapted(caps)
        @Expect(matchingRoles.error, matchingRoles.normal)
        @Expect(matchingRoles.secondary, matchingRoles.normal)
        @Expect(matchingRoles.disabled, matchingRoles.normal)
    }

    @TestCase
    func otherColorTiersAndLightThemeRetainStandardColorAdaptation(): Unit {
        for (theme in [Theme.indigo(), Theme.graphite(), Theme.light()]) {
            for (level in [1, 8, 256]) {
                let caps = TerminalCapabilities(trueColor: false, colorLevel: level)
                let adapted = theme.adapted(caps)
                let error = adaptStyleForCapabilities(theme.error, caps)
                let secondary = adaptStyleForCapabilities(theme.secondary, caps)
                @Expect(Style(fg: adapted.error.fg, bg: adapted.error.bg), Style(fg: error.fg, bg: error.bg))
                @Expect(Style(fg: adapted.secondary.fg, bg: adapted.secondary.bg),
                    Style(fg: secondary.fg, bg: secondary.bg))
            }
        }
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16)
        let light = Theme.light().adapted(caps)
        let error = adaptStyleForCapabilities(Theme.light().error, caps)
        let secondary = adaptStyleForCapabilities(Theme.light().secondary, caps)
        @Expect(light.error, error)
        @Expect(light.secondary, secondary)
    }
}
