package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ThemeRolesTest {
    @TestCase
    func defaultIndigoThemeProvidesLayeredSurfacesAndDistinctStates(): Unit {
        let theme = Theme()
        let fg = Color.Rgb(225, 226, 235)
        let background = Color.Rgb(19, 20, 34)
        @Expect(theme.normal, Style(fg: fg, bg: background))
        @Expect(theme.canvas, Style(fg: fg, bg: background))
        @Expect(theme.surface, Style(fg: fg, bg: Color.Rgb(26, 27, 44)))
        @Expect(theme.raisedSurface, Style(fg: fg, bg: Color.Rgb(36, 38, 57)))
        @Expect(theme.focused, Style(fg: fg, bg: Color.Rgb(54, 50, 61), modifier: focusModifierForTest()))
        @Expect(theme.selected, Style(fg: fg, bg: Color.Rgb(42, 44, 63), modifier: Modifier.strong()))
        @Expect(theme.accent, Style(fg: Color.Rgb(244, 187, 96), bg: background))
        @Expect(Theme.default().normal, theme.normal)
        @Expect(Theme.indigo().accent, theme.accent)
        @Expect(theme.serialize().contains("info=style\ncanvas=style"), true)
        @Expect(theme.serialize().contains("iconSet=unicode"), true)
    }

    @TestCase
    func terminalBackgroundCanBeRequestedWithoutDroppingForegroundOrState(): Unit {
        let theme = Theme()
        let terminal = theme.withTerminalBackground()
        @Expect(terminal.canvas, theme.canvas.withBg(Color.Reset))
        @Expect(terminal.surface, theme.surface.withBg(Color.Reset))
        @Expect(terminal.raisedSurface, theme.raisedSurface.withBg(Color.Reset))
        @Expect(terminal.focused, theme.focused.withBg(Color.Reset))
        @Expect(terminal.selected, theme.selected.withBg(Color.Reset))
        @Expect(terminal.error, theme.error.withBg(Color.Reset))
        @Expect(theme.canvas, Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(19, 20, 34)))
    }

    @TestCase
    func monochromeSelectionAndFocusKeepDistinctCues(): Unit {
        let theme = Theme().adapted(TerminalCapabilities(trueColor: false, colorLevel: 1))
        var selected = Modifier.strong()
        selected.reversed = true
        @Expect(theme.selected, Style(modifier: selected))
        @Expect(theme.focused, Style(modifier: focusModifierForTest()))
        var error = Modifier()
        error.italic = true
        @Expect(theme.error, Style(modifier: error))
        var combined = Modifier.strong()
        combined.reversed = true
        combined.underline = true
        combined.italic = true
        @Expect(theme.resolveState(focused: true, selected: true, error: true), Style(modifier: combined))
        @Expect(theme.resolveState(focused: true, selected: true, error: true, disabled: true), theme.disabled)
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
