package core

/** 表示样式颜色：可选择重置、具名颜色、单字节索引颜色或由三个单字节分量表示的 RGB 颜色。
 */
public enum Color {
    /** 表示重置颜色的状态，与具体颜色选项区分。
     */
    | Reset
    /** 表示黑色这一具名颜色。
     */
    | Black
    /** 表示红色这一具名颜色。
     */
    | Red
    /** 表示绿色这一具名颜色。
     */
    | Green
    /** 表示黄色这一具名颜色。
     */
    | Yellow
    /** 表示蓝色这一具名颜色。
     */
    | Blue
    /** 表示品红色这一具名颜色。
     */
    | Magenta
    /** 表示青色这一具名颜色。
     */
    | Cyan
    /** 表示白色这一具名颜色。
     */
    | White
    /** 表示以单字节索引指定的颜色，而不是具名颜色或 RGB 分量。
     */
    | Indexed(UInt8)
    /** 表示由红、绿、蓝三个单字节分量指定的颜色。
     */
    | Rgb(UInt8, UInt8, UInt8)
}

/** 保存粗体、斜体、下划线和反转四项可独立设置的布尔样式标记；默认均为 false。
 */
public struct Modifier <: Equatable<Modifier> {
    /** 是否标记为粗体；默认值为 false。
     */
    public var bold: Bool = false
    /** 是否标记为斜体；默认值为 false。
     */
    public var italic: Bool = false
    /** 是否标记为下划线；默认值为 false。
     */
    public var underline: Bool = false
    /** 是否标记为反转；默认值为 false。
     */
    public var reversed: Bool = false

    /** 创建四项样式标记均为 false 的值。
     */
    public init() {}

    /** 返回四项样式标记均为 false 的值。
     */
    public static func none(): Modifier { Modifier() }

    /** 返回仅将粗体标记设为 true、其余标记仍为 false 的值。
     */
    public static func strong(): Modifier {
        var m = Modifier()
        m.bold = true
        m
    }

    /** 逐一比较当前值与另一值的四项样式标记；全部相同才返回 true。
     */
    public operator func ==(other: Modifier): Bool {
        bold == other.bold && italic == other.italic && underline == other.underline && reversed == other.reversed
    }
}

/** 保存前景色、背景色及样式标记；默认分别为重置颜色、重置颜色和四项均为 false 的标记。
 */
public struct Style <: Equatable<Style> {
    /** 样式的前景色；默认是重置颜色。
     */
    public var fg: Color = Color.Reset
    /** 样式的背景色；默认是重置颜色。
     */
    public var bg: Color = Color.Reset
    /** 样式的修饰属性；初始值为不含修饰的 Modifier.none()。
     */
    public var modifier: Modifier = Modifier.none()

    /** 按给定前景色、背景色和修饰属性建立样式；未指定的属性分别使用重置色、重置色和无修饰。
     */
    public init(fg!: Color = Color.Reset, bg!: Color = Color.Reset, modifier!: Modifier = Modifier.none()) {
        this.fg = fg
        this.bg = bg
        this.modifier = modifier
    }

    /** 返回前景色和背景色均为 Color.Reset、修饰属性为 Modifier.none() 的样式。
     */
    public static func default(): Style { Style() }

    /** 返回以前景色替换为指定颜色的样式，其余属性沿用当前样式。
     */
    public func withFg(color: Color): Style {
        var s = this
        s.fg = color
        s
    }

    /** 返回以背景色替换为指定颜色的样式，其余属性沿用当前样式。
     */
    public func withBg(color: Color): Style {
        var s = this
        s.bg = color
        s
    }

    /** 返回以指定修饰属性替换当前修饰属性的样式，其余属性沿用当前样式。
     */
    public func withModifier(modifier: Modifier): Style {
        var s = this
        s.modifier = modifier
        s
    }

    /** 以当前样式为基础生成样式：仅用另一样式中非 Color.Reset 的前景色和背景色、非 Modifier.none() 的修饰属性覆盖对应属性。
     */
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

    /** 仅当前景色和背景色分别经 colorEquals 比较相等，且修饰属性相等时返回 true。
     */
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

/** 图标字符集；Nerd Font 需要应用显式选择并确保终端字体支持。 */
public enum IconSet {
    | Unicode
    | NerdFont
    | Ascii
}

/** 保存组件状态、界面层级、边框和图标的语义外观。
 * 使用 graphite 或 light 获取配色，并按终端能力调用 adapted。
 */
public struct Theme {
    /** 普通内容使用的样式。 */
    public let normal: Style
    /** 键盘焦点使用的样式。 */
    public let focused: Style
    /** 选中项使用的样式。 */
    public let selected: Style
    /** 禁用项使用的样式。 */
    public let disabled: Style
    /** 错误提示使用的样式。 */
    public let error: Style
    /** 强调内容使用的样式。 */
    public let accent: Style
    /** 成功状态使用的样式。 */
    public let success: Style
    /** 警告状态使用的样式。 */
    public let warning: Style
    /** 信息状态使用的样式。 */
    public let info: Style
    /** 应用背景使用的样式。 */
    public let canvas: Style
    /** 普通面板使用的样式。 */
    public let surface: Style
    /** 抬升面板使用的样式。 */
    public let raisedSurface: Style
    /** 标题文字使用的样式。 */
    public let heading: Style
    /** 次级文字使用的样式。 */
    public let secondary: Style
    /** 普通边框使用的样式。 */
    public let border: Style
    /** 强调边框使用的样式。 */
    public let strongBorder: Style
    /** 优先使用的图标字符集。 */
    public let iconSet: IconSet
    /** 面板默认使用的边框类型。 */
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
