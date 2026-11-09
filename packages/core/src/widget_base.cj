package core

import std.collection.*

public interface Widget {
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

public enum WrapMode {
    | NoWrap
    | Word
    | Character
}

public enum TextAlign {
    | Left
    | Center
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
