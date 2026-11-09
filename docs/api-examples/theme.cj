package cjtui_api_example

import core.*

main(): Int64 {
    let s = Style(fg: Color.Cyan)
    let custom = Theme(normal: s, focused: s, selected: s, disabled: s, error: s, accent: s,
        success: s, warning: s, info: s, canvas: s, surface: s, raisedSurface: s, heading: s,
        secondary: s, border: s, strongBorder: s, iconSet: IconSet.Unicode,
        borderKind: BorderKind.Rounded, progressSymbols: Some(ProgressBarSymbols()))
    let roles = [custom.normal, custom.focused, custom.selected, custom.disabled, custom.error, custom.accent,
        custom.success, custom.warning, custom.info, custom.canvas, custom.surface, custom.raisedSurface,
        custom.heading, custom.secondary, custom.border, custom.strongBorder]
    if (roles.size != 16 || roles[0] != s || !custom.progressSymbols.isSome()) {
        throw IllegalStateException("incorrect theme roles")
    }
    match ((custom.iconSet, custom.borderKind)) {
        case (IconSet.Unicode, BorderKind.Rounded) => ()
        case _ => throw IllegalStateException("incorrect theme options")
    }
    let resolved = custom.resolveState(focused: true, selected: true, disabled: false, error: false,
        override: StyleOverride(bold: true))
    if (!resolved.modifier.bold) { throw IllegalStateException("theme state override failed") }
    let configured = Theme.default().withIconSet(IconSet.Ascii).withBorderKind(BorderKind.Ascii)
        .withProgressSymbols(Some(ProgressBarSymbols())).withTerminalBackground()
    if (!configured.serialize().contains("iconSet=ascii") || !configured.progressSymbols.isSome()) {
        throw IllegalStateException("theme configuration failed")
    }
    let caps = TerminalCapabilities(trueColor: false, colorLevel: 16, unicode: false)
    let themes = [Theme.indigo(accent: Color.Red), Theme.graphite(accent: Color.Green), Theme.light(),
        Theme.light(accent: Color.Blue), Theme.forCapabilities(caps, dark: false, accent: Color.Cyan),
        custom.adapted(caps)]
    if (themes.size != 6 || !themes[5].serialize().contains("iconSet=ascii")) {
        throw IllegalStateException("theme adaptation failed")
    }
    return 0
}
