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

/** 图标字符集；Nerd Font 需要应用显式选择并确保终端字体支持。 */
public enum IconSet {
    | Unicode
    | NerdFont
    | Ascii
}

/** 保存组件状态、界面层级和图标的语义外观。
 * 使用 `graphite` 或 `light` 获取配色，再按终端能力调用 `adapted`。
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
    /** 优先使用的图标字符集；不支持 Unicode 的终端可适配为 ASCII。 */
    public let iconSet: IconSet

    /** 使用指定语义样式创建主题；未提供的项使用各自默认值。
     *
     * @param normal 普通内容样式
     * @param focused 聚焦状态样式
     * @param selected 选中状态样式
     * @param disabled 禁用状态样式
     * @param error 错误提示样式
     * @param accent 强调样式
     * @param success 成功状态样式
     * @param warning 警告状态样式
     * @param info 信息状态样式
     * @param canvas 应用背景样式
     * @param surface 普通面板样式
     * @param raisedSurface 抬升面板样式
     * @param heading 标题样式
     * @param secondary 次级文字样式
     * @param border 普通边框样式
     * @param strongBorder 强调边框样式
     * @param iconSet 图标字符集
     */
    public init(
        normal!: Style = Style.default(),
        focused!: Style = Style(modifier: focusModifier()),
        selected!: Style = Style(bg: Color.Indexed(8), modifier: Modifier.strong()),
        disabled!: Style = Style(fg: Color.Indexed(8)),
        error!: Style = Style(fg: Color.Red),
        accent!: Style = Style(fg: Color.Cyan),
        success!: Style = Style(fg: Color.Green),
        warning!: Style = Style(fg: Color.Yellow),
        info!: Style = Style(fg: Color.Cyan),
        canvas!: Style = Style.default(),
        surface!: Style = Style.default(),
        raisedSurface!: Style = Style.default(),
        heading!: Style = Style(modifier: Modifier.strong()),
        secondary!: Style = Style(fg: Color.Indexed(8)),
        border!: Style = Style(fg: Color.Indexed(8)),
        strongBorder!: Style = Style.default(),
        iconSet!: IconSet = IconSet.Unicode
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
    }

    /** 创建默认主题；普通内容沿用终端默认前景色与背景色。 */
    public static func default(): Theme {
        Theme()
    }

    /** 返回保留所有样式、仅替换图标集的新主题。 */
    public func withIconSet(value: IconSet): Theme {
        Theme(normal: normal, focused: focused, selected: selected, disabled: disabled, error: error,
            accent: accent, success: success, warning: warning, info: info, canvas: canvas,
            surface: surface, raisedSurface: raisedSurface, heading: heading, secondary: secondary,
            border: border, strongBorder: strongBorder, iconSet: value)
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

    /** 返回浅色主题；显式强调色不被替换。 */
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
            case Some(color) => if (dark) { Theme.graphite(accent: color) } else { Theme.light(accent: color) }
            case None => if (dark) { Theme.graphite() } else { Theme.light() }
        }
        base.adapted(capabilities)
    }

    /** 将当前主题的所有颜色和图标集适配到终端能力，保留样式修饰。 */
    public func adapted(capabilities: TerminalCapabilities): Theme {
        let selectedStyle = adaptStyleForCapabilities(selected, capabilities)
        let adaptedSelected = if (!capabilities.trueColor && capabilities.colorLevel < 8) {
            selectedStyle.withModifier(combineModifiers(selectedStyle.modifier, selectedModifier()))
        } else { selectedStyle }
        Theme(
            normal: adaptStyleForCapabilities(normal, capabilities),
            focused: adaptStyleForCapabilities(focused, capabilities),
            selected: adaptedSelected,
            disabled: adaptStyleForCapabilities(disabled, capabilities),
            error: adaptStyleForCapabilities(error, capabilities),
            accent: adaptStyleForCapabilities(accent, capabilities),
            success: adaptStyleForCapabilities(success, capabilities),
            warning: adaptStyleForCapabilities(warning, capabilities),
            info: adaptStyleForCapabilities(info, capabilities),
            canvas: adaptStyleForCapabilities(canvas, capabilities),
            surface: adaptStyleForCapabilities(surface, capabilities),
            raisedSurface: adaptStyleForCapabilities(raisedSurface, capabilities),
            heading: adaptStyleForCapabilities(heading, capabilities),
            secondary: adaptStyleForCapabilities(secondary, capabilities),
            border: adaptStyleForCapabilities(border, capabilities),
            strongBorder: adaptStyleForCapabilities(strongBorder, capabilities),
            iconSet: if (capabilities.unicode) { iconSet } else { IconSet.Ascii }
        )
    }

    /** 列出各语义角色是否为默认样式及图标集名称；不编码具体颜色或修饰。 */
    public func serialize(): String {
        let icons = match (iconSet) {
            case IconSet.Unicode => "unicode"
            case IconSet.NerdFont => "nerd-font"
            case IconSet.Ascii => "ascii"
        }
        "normal=${styleName(normal)}\nfocused=${styleName(focused)}\nselected=${styleName(selected)}\ndisabled=${styleName(disabled)}\nerror=${styleName(error)}\naccent=${styleName(accent)}\nsuccess=${styleName(success)}\nwarning=${styleName(warning)}\ninfo=${styleName(info)}\ncanvas=${styleName(canvas)}\nsurface=${styleName(surface)}\nraisedSurface=${styleName(raisedSurface)}\nheading=${styleName(heading)}\nsecondary=${styleName(secondary)}\nborder=${styleName(border)}\nstrongBorder=${styleName(strongBorder)}\niconSet=${icons}"
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
