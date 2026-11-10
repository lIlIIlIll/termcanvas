package core

import std.collection.*

/** 能够向给定区域和缓冲区绘制内容的组件。 */
public interface Widget {
    /** 将组件绘制到缓冲区。
     * @param area 可供绘制的区域
     * @param buffer 目标缓冲区
     */
    func render(area: Rect, buffer: Buffer): Unit
}

// Some widgets historically always had a complete built-in theme. Resolve
// the application context first, retaining that built-in fallback when absent.
func widgetTheme(buffer: Buffer, explicit: ?Theme): Theme {
    match (buffer.resolveTheme(explicit)) {
        case Some(theme) => theme
        case None => Theme()
    }
}

// Explicit legacy styles patch a role; absent styles use the role or the
// original no-theme fallback. Use StyleOverride where an explicit reset is needed.
func widgetRoleStyle(style: ?Style, theme: ?Theme, role: ThemeRole, fallback: Style): Style {
    match (style) {
        case Some(value) => themeRoleStyle(value, role, theme)
        case None => match (theme) {
            case Some(_) => themeRoleStyle(Style.default(), role, theme)
            case None => fallback
        }
    }
}

/** 文本超出可用宽度时的换行方式。 */
public enum WrapMode {
    /** 按原始换行分行，不按宽度自动换行。 */
    | NoWrap
    /** 优先按单词边界换行。 */
    | Word
    /** 按字符显示宽度换行。 */
    | Character
}

/** 文本在区域内的水平对齐方式。 */
public enum TextAlign {
    /** 靠左对齐。 */
    | Left
    /** 居中对齐。 */
    | Center
    /** 靠右对齐。 */
    | Right
}

func resolvedStateStyle(
    style: Style,
    focusedStyle: Style,
    disabledStyle: Style,
    focused: Bool,
    disabled: Bool,
    theme: ?Theme
): Style {
    if (disabled) { return themedDisabled(disabledStyle, theme) }
    if (focused) { return themedFocused(focusedStyle, theme) }
    themedNormal(style, theme)
}

func themedNormal(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Normal, theme)
}

func themedFocused(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Focused, theme)
}

func themedSelected(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Selected, theme)
}

func themedDisabled(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Disabled, theme)
}

func themedError(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Error, theme)
}

func themedAccent(style: Style, theme: ?Theme): Style {
    themeRoleStyle(style, ThemeRole.Accent, theme)
}

func decimalDigits(value: Int64): Int64 {
    var v = max(0, value)
    var digits: Int64 = 1
    while (v >= 10) {
        v /= 10
        digits++
    }
    digits
}

func maxArray(values: Array<Int64>): Int64 {
    var out: Int64 = 0
    for (value in values) {
        if (value > out) { out = value }
    }
    out
}

func containsIndex(items: ArrayList<Int64>, value: Int64): Bool {
    for (item in items) {
        if (item == value) { return true }
    }
    false
}

func pad2(value: Int64): String {
    if (value < 10) { "0${value}" } else { "${value}" }
}

func isBorderNone(kind: BorderKind): Bool {
    match (kind) {
        case BorderKind.NoBorder => true
        case _ => false
    }
}
