package core

public enum Color {
    | Reset
    | Black
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White
    | Indexed(UInt8)
    | Rgb(UInt8, UInt8, UInt8)
}

public struct Modifier <: Equatable<Modifier> {
    public var bold: Bool = false
    public var italic: Bool = false
    public var underline: Bool = false
    public var reversed: Bool = false

    public init() {}

    public static func none(): Modifier { Modifier() }

    public static func strong(): Modifier {
        var m = Modifier()
        m.bold = true
        m
    }

    public operator func ==(other: Modifier): Bool {
        bold == other.bold && italic == other.italic && underline == other.underline && reversed == other.reversed
    }
}

public struct Style <: Equatable<Style> {
    public var fg: Color = Color.Reset
    public var bg: Color = Color.Reset
    public var modifier: Modifier = Modifier.none()

    public init(fg!: Color = Color.Reset, bg!: Color = Color.Reset, modifier!: Modifier = Modifier.none()) {
        this.fg = fg
        this.bg = bg
        this.modifier = modifier
    }

    public static func default(): Style { Style() }

    public func withFg(color: Color): Style {
        var s = this
        s.fg = color
        s
    }

    public func withBg(color: Color): Style {
        var s = this
        s.bg = color
        s
    }

    public func withModifier(modifier: Modifier): Style {
        var s = this
        s.modifier = modifier
        s
    }

    public func patch(other: Style): Style {
        var s = this
        if (!colorEquals(other.fg, Color.Reset)) {
            s.fg = other.fg
        }
        if (!colorEquals(other.bg, Color.Reset)) {
            s.bg = other.bg
        }
        if (other.modifier != Modifier.none()) {
            s.modifier = other.modifier
        }
        s
    }

    public operator func ==(other: Style): Bool {
        colorEquals(fg, other.fg) && colorEquals(bg, other.bg) && modifier == other.modifier
    }
}

/** 样式属性覆盖：None 继承，Some(Color.Reset) 恢复终端默认颜色，Some(false) 关闭对应修饰。
 * 恢复终端默认背景并不表示缓冲区透明合成。
 */
public struct StyleOverride {
    public let fg: ?Color
    public let bg: ?Color
    public let bold: ?Bool
    public let italic: ?Bool
    public let underline: ?Bool
    public let reversed: ?Bool

    public init(fg!: ?Color = None, bg!: ?Color = None, bold!: ?Bool = None,
        italic!: ?Bool = None, underline!: ?Bool = None, reversed!: ?Bool = None) {
        this.fg = fg
        this.bg = bg
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.reversed = reversed
    }

    /** 对基础样式逐项应用覆盖；未指定的属性保持原值。 */
    public func apply(base: Style): Style {
        var result = base
        match (fg) { case Some(value) => result.fg = value; case None => () }
        match (bg) { case Some(value) => result.bg = value; case None => () }
        var modifier = result.modifier
        match (bold) { case Some(value) => modifier.bold = value; case None => () }
        match (italic) { case Some(value) => modifier.italic = value; case None => () }
        match (underline) { case Some(value) => modifier.underline = value; case None => () }
        match (reversed) { case Some(value) => modifier.reversed = value; case None => () }
        result.modifier = modifier
        result
    }
}

/** 在旧式非重置样式合并之后应用逐属性覆盖，支持显式恢复默认颜色或关闭修饰。 */
public func resolveStyle(base: Style, legacy!: Style = Style.default(), override!: ?StyleOverride = None): Style {
    let resolved = base.patch(legacy)
    match (override) {
        case Some(value) => value.apply(resolved)
        case None => resolved
    }
}

public enum IconSet {
    | Unicode
    | NerdFont
    | Ascii
}

public struct Theme {
    public let normal: Style
    public let focused: Style
    public let selected: Style
    public let disabled: Style
    public let error: Style
    public let accent: Style
    public let success: Style
    public let warning: Style
    public let info: Style
    public let canvas: Style
    public let surface: Style
    public let raisedSurface: Style
    public let heading: Style
    public let secondary: Style
    public let border: Style
    public let strongBorder: Style
    public let iconSet: IconSet
    public let borderKind: BorderKind
    /** 进度条的可选默认符号；未设置时由终端能力选择。 */
    public let progressSymbols: ?ProgressBarSymbols

    public init(
        normal!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(19, 20, 34)),
        focused!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(54, 50, 61), modifier: focusModifier()),
        selected!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(42, 44, 63), modifier: Modifier.strong()),
        disabled!: Style = Style(fg: Color.Rgb(157, 160, 181), bg: Color.Rgb(19, 20, 34)),
        error!: Style = Style(fg: Color.Rgb(255, 122, 131), bg: Color.Rgb(19, 20, 34), modifier: errorModifier()),
        accent!: Style = Style(fg: Color.Rgb(244, 187, 96), bg: Color.Rgb(19, 20, 34)),
        success!: Style = Style(fg: Color.Rgb(111, 211, 162), bg: Color.Rgb(19, 20, 34)),
        warning!: Style = Style(fg: Color.Rgb(255, 198, 114), bg: Color.Rgb(19, 20, 34)),
        info!: Style = Style(fg: Color.Rgb(118, 193, 231), bg: Color.Rgb(19, 20, 34)),
        canvas!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(19, 20, 34)),
        surface!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(26, 27, 44)),
        raisedSurface!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(36, 38, 57)),
        heading!: Style = Style(fg: Color.Rgb(225, 226, 235), bg: Color.Rgb(19, 20, 34), modifier: Modifier.strong()),
        secondary!: Style = Style(fg: Color.Rgb(157, 160, 181), bg: Color.Rgb(19, 20, 34)),
        border!: Style = Style(fg: Color.Rgb(88, 92, 115), bg: Color.Rgb(19, 20, 34)),
        strongBorder!: Style = Style(fg: Color.Rgb(244, 187, 96), bg: Color.Rgb(19, 20, 34)),
        iconSet!: IconSet = IconSet.Unicode,
        borderKind!: BorderKind = BorderKind.Auto,
        progressSymbols!: ?ProgressBarSymbols = None
    ) {
        this.normal = normal
        this.focused = focused
        this.selected = selected
        this.disabled = disabled
        this.error = error
        this.accent = accent
        this.success = success
        this.warning = warning
        this.info = info
        this.canvas = canvas
        this.surface = surface
        this.raisedSurface = raisedSurface
        this.heading = heading
        this.secondary = secondary
        this.border = border
        this.strongBorder = strongBorder
        this.iconSet = iconSet
        this.borderKind = borderKind
        this.progressSymbols = progressSymbols
    }

    public static func default(): Theme {
        Theme()
    }

    /** 根据状态组合解析样式；禁用优先，错误保留颜色，其余状态通过修饰属性叠加。 */
    public func resolveState(focused!: Bool = false, selected!: Bool = false, disabled!: Bool = false,
        error!: Bool = false, override!: ?StyleOverride = None): Style {
        let base = resolvedSemanticStateStyle(Style.default(), Style.default(), Style.default(),
            Style.default(), Style.default(), focused, selected, disabled, error, Some(this))
        resolveStyle(base, override: override)
    }

    public func withIconSet(value: IconSet): Theme {
        Theme(normal: normal, focused: focused, selected: selected, disabled: disabled, error: error,
            accent: accent, success: success, warning: warning, info: info, canvas: canvas,
            surface: surface, raisedSurface: raisedSurface, heading: heading, secondary: secondary,
            border: border, strongBorder: strongBorder, iconSet: value, borderKind: borderKind,
            progressSymbols: progressSymbols)
    }

    /** 设置使用本主题的区块默认边框；区块显式设置优先。 */
    public func withBorderKind(value: BorderKind): Theme {
        Theme(normal: normal, focused: focused, selected: selected, disabled: disabled, error: error,
            accent: accent, success: success, warning: warning, info: info, canvas: canvas,
            surface: surface, raisedSurface: raisedSurface, heading: heading, secondary: secondary,
            border: border, strongBorder: strongBorder, iconSet: iconSet, borderKind: value,
            progressSymbols: progressSymbols)
    }

    /** 设置本主题的进度条默认符号；None 恢复自动选择。 */
    public func withProgressSymbols(value: ?ProgressBarSymbols): Theme {
        Theme(normal: normal, focused: focused, selected: selected, disabled: disabled, error: error,
            accent: accent, success: success, warning: warning, info: info, canvas: canvas,
            surface: surface, raisedSurface: raisedSurface, heading: heading, secondary: secondary,
            border: border, strongBorder: strongBorder, iconSet: iconSet, borderKind: borderKind,
            progressSymbols: value)
    }

    /** 使用终端默认背景；此设置不会启用单元格透明合成。 */
    public func withTerminalBackground(): Theme {
        let clear = StyleOverride(bg: Some(Color.Reset))
        Theme(normal: clear.apply(normal), focused: clear.apply(focused), selected: clear.apply(selected),
            disabled: clear.apply(disabled), error: clear.apply(error), accent: clear.apply(accent),
            success: clear.apply(success), warning: clear.apply(warning), info: clear.apply(info),
            canvas: clear.apply(canvas), surface: clear.apply(surface), raisedSurface: clear.apply(raisedSurface),
            heading: clear.apply(heading), secondary: clear.apply(secondary), border: clear.apply(border),
            strongBorder: clear.apply(strongBorder), iconSet: iconSet, borderKind: borderKind,
            progressSymbols: progressSymbols)
    }

    /** 深靛蓝底色与琥珀强调色的主题，成功、警告、错误保留独立语义色。 */
    public static func indigo(accent!: Color = Color.Rgb(244, 187, 96)): Theme {
        let bg = Color.Rgb(19, 20, 34)
        Theme(accent: Style(fg: accent, bg: bg), strongBorder: Style(fg: accent, bg: bg))
    }

    /** 返回石墨色语义主题，并将指定颜色用作强调色。
     */
    public static func graphite(accent!: Color = Color.Cyan): Theme {
        semanticTheme(dark: true, accent: accent)
    }

    /** 返回浅色语义主题，并将指定颜色用作强调色。
     */
    public static func light(): Theme {
        semanticTheme(dark: false, accent: Color.Rgb(0, 109, 129))
    }

    public static func light(accent!: Color): Theme {
        semanticTheme(dark: false, accent: accent)
    }

    /** 按终端支持的颜色能力适配语义主题中的全部样式。
     */
    public static func forCapabilities(
        capabilities: TerminalCapabilities,
        dark!: Bool = true,
        accent!: ?Color = None
    ): Theme {
        let base = match (accent) {
            case Some(color) => if (dark) { Theme.indigo(accent: color) } else { Theme.light(accent: color) }
            case None => if (dark) { Theme.indigo() } else { Theme.light() }
        }
        base.adapted(capabilities)
    }

    /** 将当前主题的颜色和图标集适配到终端能力，保留样式修饰。
     * 当原本不同的普通和禁用样式在适配后重合时，尽可能添加一个状态修饰以区分它们。
     */
    public func adapted(capabilities: TerminalCapabilities): Theme {
        let adaptedNormal = adaptStyleForCapabilities(normal, capabilities)
        let disabledStyle = if (disabled == normal) { adaptStyleForCapabilities(disabled, capabilities) } else {
            adaptMutedThemeRole(disabled, capabilities)
        }
        let adaptedDisabled = if (normal != disabled && adaptedNormal == disabledStyle) {
            distinguishDisabled(disabledStyle)
        } else { disabledStyle }
        let selectedStyle = adaptStyleForCapabilities(selected, capabilities)
        let adaptedSelected = if (!capabilities.trueColor && capabilities.colorLevel < 8) {
            selectedStyle.withModifier(combineModifiers(selectedStyle.modifier, selectedModifier()))
        } else { selectedStyle }
        let focusedStyle = adaptStyleForCapabilities(focused, capabilities)
        let errorStyle = if (error == normal) { adaptStyleForCapabilities(error, capabilities) } else {
            adaptErrorThemeRole(error, capabilities)
        }
        let monochrome = !capabilities.trueColor && capabilities.colorLevel < 8
        Theme(
            normal: adaptedNormal,
            focused: if (monochrome) { focusedStyle.withModifier(combineModifiers(focusedStyle.modifier, focusModifier())) } else { focusedStyle },
            selected: adaptedSelected,
            disabled: adaptedDisabled,
            error: if (monochrome) { errorStyle.withModifier(combineModifiers(errorStyle.modifier, errorModifier())) } else { errorStyle },
            accent: adaptStyleForCapabilities(accent, capabilities),
            success: adaptStyleForCapabilities(success, capabilities),
            warning: adaptStyleForCapabilities(warning, capabilities),
            info: adaptStyleForCapabilities(info, capabilities),
            canvas: adaptStyleForCapabilities(canvas, capabilities),
            surface: adaptStyleForCapabilities(surface, capabilities),
            raisedSurface: adaptStyleForCapabilities(raisedSurface, capabilities),
            heading: adaptStyleForCapabilities(heading, capabilities),
            secondary: if (secondary == normal) { adaptedNormal } else { adaptMutedThemeRole(secondary, capabilities) },
            border: adaptStyleForCapabilities(border, capabilities),
            strongBorder: adaptStyleForCapabilities(strongBorder, capabilities),
            iconSet: if (capabilities.unicode) { iconSet } else { IconSet.Ascii },
            borderKind: borderKind,
            progressSymbols: progressSymbols
        )
    }

    public func serialize(): String {
        let icons = match (iconSet) {
            case IconSet.Unicode => "unicode"
            case IconSet.NerdFont => "nerd-font"
            case IconSet.Ascii => "ascii"
        }
        let progress = match (progressSymbols) {
            case Some(value) => value.serialize()
            case None => "auto"
        }
        "normal=${styleName(normal)}\nfocused=${styleName(focused)}\nselected=${styleName(selected)}\ndisabled=${styleName(disabled)}\nerror=${styleName(error)}\naccent=${styleName(accent)}\nsuccess=${styleName(success)}\nwarning=${styleName(warning)}\ninfo=${styleName(info)}\ncanvas=${styleName(canvas)}\nsurface=${styleName(surface)}\nraisedSurface=${styleName(raisedSurface)}\nheading=${styleName(heading)}\nsecondary=${styleName(secondary)}\nborder=${styleName(border)}\nstrongBorder=${styleName(strongBorder)}\niconSet=${icons}\nprogressSymbols=${progress}"
    }
}

// Shared state value used by immediate experimental widgets.
public enum StyleState {
    | Normal
    | Focused
    | Selected
    | Disabled
    | Error
    | Accent
}

func styleName(style: Style): String {
    if (style == Style.default()) { return "default" }
    "style"
}
