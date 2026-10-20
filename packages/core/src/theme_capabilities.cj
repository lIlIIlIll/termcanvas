package core

enum ThemeRole {
    | Normal
    | Focused
    | Selected
    | Disabled
    | Error
    | Accent
}

func themeRoleStyle(style: Style, role: ThemeRole, theme: ?Theme): Style {
    match (theme) {
        case Some(value) =>
            let roleStyle = match (role) {
                case ThemeRole.Normal => value.normal
                case ThemeRole.Focused => value.focused
                case ThemeRole.Selected => value.selected
                case ThemeRole.Disabled => value.disabled
                case ThemeRole.Error => value.error
                case ThemeRole.Accent => value.accent
            }
            roleStyle.patch(style)
        case None => style
    }
}

func combineModifiers(base: Modifier, added: Modifier): Modifier {
    var result = Modifier()
    result.bold = base.bold || added.bold
    result.italic = base.italic || added.italic
    result.underline = base.underline || added.underline
    result.reversed = base.reversed || added.reversed
    result
}

func addFocusedModifiers(style: Style, focusedStyle: Style, theme: ?Theme): Style {
    match (theme) {
        case Some(value) =>
            let focus = value.focused.patch(focusedStyle)
            style.withModifier(combineModifiers(style.modifier, focus.modifier))
        case None => style
    }
}

func resolvedSemanticStateStyle(
    normalStyle: Style,
    focusedStyle: Style,
    selectedStyle: Style,
    disabledStyle: Style,
    errorStyle: Style,
    focused: Bool,
    selected: Bool,
    disabled: Bool,
    error: Bool,
    theme: ?Theme
): Style {
    if (disabled) { return themeRoleStyle(disabledStyle, ThemeRole.Disabled, theme) }
    if (error) {
        let resolved = themeRoleStyle(errorStyle, ThemeRole.Error, theme)
        return if (focused) { addFocusedModifiers(resolved, focusedStyle, theme) } else { resolved }
    }
    if (selected) {
        let resolved = themeRoleStyle(selectedStyle, ThemeRole.Selected, theme)
        return if (focused) { addFocusedModifiers(resolved, focusedStyle, theme) } else { resolved }
    }
    if (focused) { return themeRoleStyle(focusedStyle, ThemeRole.Focused, theme) }
    themeRoleStyle(normalStyle, ThemeRole.Normal, theme)
}

func semanticTheme(dark!: Bool, accent!: Color): Theme {
    let background = if (dark) { Color.Rgb(18, 21, 26) } else { Color.Rgb(247, 249, 252) }
    let foreground = if (dark) { Color.Rgb(224, 230, 237) } else { Color.Rgb(31, 41, 51) }
    let selectedBackground = if (dark) { Color.Rgb(26, 43, 50) } else { Color.Rgb(229, 239, 243) }
    let focusedBackground = if (dark) { Color.Rgb(30, 61, 69) } else { Color.Rgb(213, 238, 243) }
    let mutedForeground = if (dark) { Color.Rgb(145, 157, 169) } else { Color.Rgb(97, 110, 126) }
    let semanticError = if (dark) { Color.Rgb(255, 119, 125) } else { Color.Rgb(180, 35, 45) }
    let semanticSuccess = if (dark) { Color.Rgb(103, 216, 166) } else { Color.Rgb(26, 128, 83) }
    let semanticWarning = if (dark) { Color.Rgb(255, 200, 105) } else { Color.Rgb(150, 91, 0) }
    let semanticInfo = if (dark) { Color.Rgb(80, 203, 221) } else { Color.Rgb(0, 109, 129) }
    Theme(
        normal: Style(fg: foreground, bg: background),
        focused: Style(fg: foreground, bg: focusedBackground, modifier: Modifier.strong()),
        selected: Style(fg: foreground, bg: selectedBackground, modifier: Modifier.strong()),
        disabled: Style(fg: mutedForeground, bg: background),
        error: Style(fg: semanticError, bg: background),
        accent: Style(fg: accent, bg: background),
        success: Style(fg: semanticSuccess, bg: background),
        warning: Style(fg: semanticWarning, bg: background),
        info: Style(fg: semanticInfo, bg: background)
    )
}

/** Adapt a style without emitting colors the declared terminal tier cannot represent. */
public func adaptStyleForCapabilities(style: Style, capabilities: TerminalCapabilities): Style {
    if (capabilities.trueColor) { return style }
    if (capabilities.colorLevel >= 256) {
        return Style(
            fg: adaptXtermColor(style.fg),
            bg: adaptXtermColor(style.bg),
            modifier: style.modifier
        )
    }
    if (capabilities.colorLevel >= 8) {
        return Style(
            fg: adaptAnsi8Color(style.fg),
            bg: adaptAnsi8Color(style.bg),
            modifier: style.modifier
        )
    }
    Style(fg: Color.Reset, bg: Color.Reset, modifier: style.modifier)
}

private func adaptXtermColor(color: Color): Color {
    match (color) {
        case Color.Rgb(r, g, b) => Color.Indexed(nearestXtermIndex(Int64(r), Int64(g), Int64(b)))
        case _ => color
    }
}

private func adaptAnsi8Color(color: Color): Color {
    match (color) {
        case Color.Reset => Color.Reset
        case Color.Black | Color.Red | Color.Green | Color.Yellow |
            Color.Blue | Color.Magenta | Color.Cyan | Color.White => color
        case Color.Indexed(index) =>
            let (r, g, b) = xtermRgb(Int64(index))
            nearestAnsi8Color(r, g, b)
        case Color.Rgb(r, g, b) => nearestAnsi8Color(Int64(r), Int64(g), Int64(b))
    }
}

private func nearestXtermIndex(r: Int64, g: Int64, b: Int64): UInt8 {
    var bestIndex: Int64 = 0
    var bestDistance: Int64 = 195076
    var index: Int64 = 0
    while (index < 256) {
        let (pr, pg, pb) = xtermRgb(index)
        let dr = r - pr
        let dg = g - pg
        let db = b - pb
        let distance = dr * dr + dg * dg + db * db
        if (distance < bestDistance) {
            bestDistance = distance
            bestIndex = index
        }
        index++
    }
    UInt8(bestIndex)
}

private func nearestAnsi8Color(r: Int64, g: Int64, b: Int64): Color {
    var bestIndex: Int64 = 0
    var bestDistance: Int64 = 195076
    var index: Int64 = 0
    while (index < 8) {
        let (pr, pg, pb) = ansi8Rgb(index)
        let dr = r - pr
        let dg = g - pg
        let db = b - pb
        let distance = dr * dr + dg * dg + db * db
        if (distance < bestDistance) {
            bestDistance = distance
            bestIndex = index
        }
        index++
    }
    match (bestIndex) {
        case 0 => Color.Black
        case 1 => Color.Red
        case 2 => Color.Green
        case 3 => Color.Yellow
        case 4 => Color.Blue
        case 5 => Color.Magenta
        case 6 => Color.Cyan
        case _ => Color.White
    }
}

private func xtermRgb(index: Int64): (Int64, Int64, Int64) {
    if (index < 16) {
        return match (index) {
            case 0 => (0, 0, 0)
            case 1 => (205, 0, 0)
            case 2 => (0, 205, 0)
            case 3 => (205, 205, 0)
            case 4 => (0, 0, 238)
            case 5 => (205, 0, 205)
            case 6 => (0, 205, 205)
            case 7 => (229, 229, 229)
            case 8 => (127, 127, 127)
            case 9 => (255, 0, 0)
            case 10 => (0, 255, 0)
            case 11 => (255, 255, 0)
            case 12 => (92, 92, 255)
            case 13 => (255, 0, 255)
            case 14 => (0, 255, 255)
            case _ => (255, 255, 255)
        }
    }
    if (index < 232) {
        let cube = index - 16
        (cubeChannel(cube / 36), cubeChannel((cube / 6) % 6), cubeChannel(cube % 6))
    } else {
        let gray = 8 + (index - 232) * 10
        (gray, gray, gray)
    }
}

private func cubeChannel(value: Int64): Int64 {
    match (value) {
        case 0 => 0
        case 1 => 95
        case 2 => 135
        case 3 => 175
        case 4 => 215
        case _ => 255
    }
}

private func ansi8Rgb(index: Int64): (Int64, Int64, Int64) {
    match (index) {
        case 0 => (0, 0, 0)
        case 1 => (205, 0, 0)
        case 2 => (0, 205, 0)
        case 3 => (205, 205, 0)
        case 4 => (0, 0, 238)
        case 5 => (205, 0, 205)
        case 6 => (0, 205, 205)
        case _ => (229, 229, 229)
    }
}
