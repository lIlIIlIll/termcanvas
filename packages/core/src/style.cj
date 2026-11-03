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

    public static func default(): Theme {
        Theme()
    }

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
