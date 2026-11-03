package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ThemeRolesTest {
    @TestCase
    func defaultsRespectTerminalColorsAndDistinguishSelectionFromFocus(): Unit {
        let theme = Theme()
        @Expect(theme.normal, Style.default())
        @Expect(theme.canvas, Style.default())
        @Expect(theme.surface, Style.default())
        @Expect(theme.raisedSurface, Style.default())
        @Expect(theme.focused, Style(modifier: focusModifierForTest()))
        @Expect(theme.selected, Style(bg: Color.Indexed(8), modifier: Modifier.strong()))
        @Expect(theme.serialize().contains("info=style\ncanvas=default"), true)
        @Expect(theme.serialize().contains("iconSet=unicode"), true)
    }

    @TestCase
    func monochromeSelectionAndFocusKeepDistinctCues(): Unit {
        let theme = Theme().adapted(TerminalCapabilities(trueColor: false, colorLevel: 1))
        var selected = Modifier.strong()
        selected.reversed = true
        @Expect(theme.selected, Style(modifier: selected))
        @Expect(theme.focused, Style(modifier: focusModifierForTest()))
    }

    @TestCase
    func explicitAccentRemainsExplicitOnLightTheme(): Unit {
        @Expect(Theme.light().accent, Style(fg: Color.Rgb(0, 109, 129), bg: Color.Rgb(247, 249, 252)))
        @Expect(Theme.light(accent: Color.Cyan).accent, Style(fg: Color.Cyan, bg: Color.Rgb(247, 249, 252)))
        @Expect(Theme.forCapabilities(TerminalCapabilities(), dark: false).accent, Theme.light().accent)
        @Expect(Theme.forCapabilities(TerminalCapabilities(), dark: false, accent: Color.Cyan).accent,
            Theme.light(accent: Color.Cyan).accent)
    }

    @TestCase
    func changeIconSetKeepsPresetAndCustomRoles(): Unit {
        let original = Theme.light(accent: Color.Magenta)
        let changed = original.withIconSet(IconSet.NerdFont)
        @Expect(changed.serialize().contains("iconSet=nerd-font"), true)
        @Expect(original.serialize().contains("iconSet=unicode"), true)
        @Expect(changed.accent, original.accent)
        @Expect(changed.normal, original.normal)
        @Expect(changed.focused, original.focused)
        @Expect(changed.selected, original.selected)
        @Expect(changed.disabled, original.disabled)
        @Expect(changed.error, original.error)
        @Expect(changed.success, original.success)
        @Expect(changed.warning, original.warning)
        @Expect(changed.info, original.info)
        @Expect(changed.canvas, original.canvas)
        @Expect(changed.surface, original.surface)
        @Expect(changed.raisedSurface, original.raisedSurface)
        @Expect(changed.heading, original.heading)
        @Expect(changed.secondary, original.secondary)
        @Expect(changed.border, original.border)
        @Expect(changed.strongBorder, original.strongBorder)
    }

    @TestCase
    func explicitRolesAdaptAcrossColorTiersAndKeepModifiers(): Unit {
        var emphasis = Modifier()
        emphasis.italic = true
        let custom = Style(fg: Color.Rgb(95, 135, 175), bg: Color.Rgb(0, 0, 0), modifier: emphasis)
        let theme = Theme(canvas: custom, surface: custom, raisedSurface: custom, heading: custom,
            secondary: custom, border: custom, strongBorder: custom, iconSet: IconSet.NerdFont)
        let xterm = theme.adapted(TerminalCapabilities(trueColor: false, colorLevel: 256))
        let expected = Style(fg: Color.Indexed(67), bg: Color.Indexed(0), modifier: emphasis)
        @Expect(xterm.canvas, expected)
        @Expect(xterm.surface, expected)
        @Expect(xterm.raisedSurface, expected)
        @Expect(xterm.heading, expected)
        @Expect(xterm.secondary, expected)
        @Expect(xterm.border, expected)
        @Expect(xterm.strongBorder, expected)
        @Expect(xterm.serialize().contains("iconSet=nerd-font"), true)
        let mono = theme.adapted(TerminalCapabilities(trueColor: false, colorLevel: 1, unicode: false))
        @Expect(mono.canvas, Style(modifier: emphasis))
        @Expect(mono.heading, Style(modifier: emphasis))
        @Expect(mono.serialize().contains("iconSet=ascii"), true)
        @Expect(mono.selected.modifier.reversed, true)
    }
}

private func focusModifierForTest(): Modifier {
    var result = Modifier()
    result.underline = true
    result
}
