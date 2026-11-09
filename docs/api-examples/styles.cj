package cjtui_api_example

import core.*

main(): Int64 {
    let colors = [Color.Reset, Color.Black, Color.Red, Color.Green, Color.Yellow, Color.Blue,
        Color.Magenta, Color.Cyan, Color.White, Color.Indexed(42), Color.Rgb(12, 34, 56)]
    let icons = [IconSet.Unicode, IconSet.NerdFont, IconSet.Ascii]
    let states = [StyleState.Normal, StyleState.Focused, StyleState.Selected,
        StyleState.Disabled, StyleState.Error, StyleState.Accent]
    var modifier = Modifier()
    modifier.bold = true
    modifier.italic = true
    modifier.underline = true
    modifier.reversed = true
    let strong = Modifier.strong()
    let base = Style(fg: Color.Red, bg: Color.Blue, modifier: modifier)
    let patched = base.patch(Style(fg: Color.Green)).withFg(Color.Yellow).withBg(Color.Black).withModifier(strong)
    let override = StyleOverride(fg: Color.Reset, bg: Color.White, bold: false, italic: true, underline: true, reversed: true)
    let resolved = resolveStyle(patched, legacy: Style(fg: Color.Cyan), override: override)
    if (colors.size != 11 || icons.size != 3 || states.size != 6 || modifier == Modifier.none() ||
        !strong.bold || patched.modifier != strong || resolved != override.apply(patched.patch(Style(fg: Color.Cyan))) ||
        !override.fg.isSome() || !override.bg.isSome() || !override.bold.isSome() || !override.italic.isSome() ||
        !override.underline.isSome() || !override.reversed.isSome() || resolved.modifier.bold ||
        !resolved.modifier.italic || !resolved.modifier.underline || !resolved.modifier.reversed ||
        Style.default() != Style()) { throw IllegalStateException("incorrect style resolution") }
    return 0
}
