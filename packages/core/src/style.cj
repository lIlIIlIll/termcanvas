package core

import std.collection.*

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

public struct Theme {
    public let normal: Style
    public let focused: Style
    public let selected: Style
    public let disabled: Style
    public let error: Style
    public let accent: Style

    public init(
        normal!: Style = Style.default(),
        focused!: Style = Style(fg: Color.Black, bg: Color.White),
        selected!: Style = Style(fg: Color.Black, bg: Color.White),
        disabled!: Style = Style(fg: Color.Indexed(8)),
        error!: Style = Style(fg: Color.Red),
        accent!: Style = Style(fg: Color.Cyan)
    ) {
        this.normal = normal
        this.focused = focused
        this.selected = selected
        this.disabled = disabled
        this.error = error
        this.accent = accent
    }

    public static func default(): Theme {
        Theme()
    }

    public func serialize(): String {
        "normal=${styleName(normal)}\nfocused=${styleName(focused)}\nselected=${styleName(selected)}\ndisabled=${styleName(disabled)}\nerror=${styleName(error)}\naccent=${styleName(accent)}"
    }
}

public enum StyleState {
    | Normal
    | Focused
    | Selected
    | Disabled
    | Error
    | Accent
}

public class StyleClass {
    public let name: String
    public let normal: Style
    public let focused: Style
    public let selected: Style
    public let disabled: Style
    public let error: Style

    public init(
        name: String,
        normal!: Style = Style.default(),
        focused!: Style = Style.default(),
        selected!: Style = Style.default(),
        disabled!: Style = Style.default(),
        error!: Style = Style.default()
    ) {
        this.name = name
        this.normal = normal
        this.focused = focused
        this.selected = selected
        this.disabled = disabled
        this.error = error
    }

    public func resolve(state!: StyleState = StyleState.Normal, base!: Style = Style.default()): Style {
        base.patch(match (state) {
            case StyleState.Normal => normal
            case StyleState.Focused => normal.patch(focused)
            case StyleState.Selected => normal.patch(selected)
            case StyleState.Disabled => normal.patch(disabled)
            case StyleState.Error => normal.patch(error)
            case StyleState.Accent => normal
        })
    }
}

public class StyleSheet {
    private let classes = ArrayList<StyleClass>()
    private let rules = ArrayList<StyleRule>()
    private let cssRules = ArrayList<CssRule>()

    public init(classes!: Array<StyleClass> = []) {
        for (styleClass in classes) {
            this.classes.add(styleClass)
        }
    }

    public func add(styleClass: StyleClass): Unit {
        classes.add(styleClass)
    }

    public func addRule(rule: StyleRule): Unit {
        rules.add(rule)
    }

    public func addCssRule(rule: CssRule): Unit {
        rule.sourceOrder = cssRules.size
        cssRules.add(rule)
    }

    public func resolve(name: String, state!: StyleState = StyleState.Normal, base!: Style = Style.default()): Style {
        for (styleClass in classes) {
            if (styleClass.name == name) {
                return styleClass.resolve(state: state, base: base)
            }
        }
        base
    }

    public func resolveSelector(selector: String, state!: StyleState = StyleState.Normal, base!: Style = Style.default()): Style {
        var result = base
        for (rule in rules) {
            if (rule.matches(selector, state)) {
                result = result.patch(rule.style)
            }
        }
        result
    }

    public func compute(node: ViewNode, inherited!: ComputedStyle = ComputedStyle.default()): ComputedStyle {
        var result = ComputedStyle.inherit(inherited)
        for (rule in sortedMatchingRules(node)) {
            result = result.patch(rule.declarations)
        }
        result.patch(node.inlineStyle())
    }

    public func apply(root: ViewNode, area: Rect): Unit {
        applyNode(root, area, ComputedStyle.default())
    }

    public func size(): Int64 {
        classes.size + rules.size + cssRules.size
    }

    public static func parse(text: String): StyleSheet {
        let sheet = StyleSheet()
        var rest = text
        while (true) {
            let open = indexOfChar(rest, r'{')
            match (open) {
                case Some(openIndex) =>
                    let close = indexOfChar(rest[openIndex + 1..], r'}')
                    match (close) {
                        case Some(closeIndex) =>
                            let selectorText = cssTrimAscii(rest[..openIndex])
                            let body = rest[openIndex + 1..openIndex + 1 + closeIndex]
                            let declarations = StyleDeclaration.parse(body)
                            for (selector in splitSelectorList(selectorText)) {
                                match (CssSelector.parse(selector)) {
                                    case Some(parsed) => sheet.addCssRule(CssRule(parsed, declarations))
                                    case None => ()
                                }
                            }
                            rest = rest[openIndex + closeIndex + 2..]
                        case None => return sheet
                    }
                case None => return sheet
            }
        }
        sheet
    }

    private func applyNode(node: ViewNode, area: Rect, inherited: ComputedStyle): Unit {
        let computed = compute(node, inherited: inherited)
        node.setComputedStyle(computed)
        let layout = computeNodeLayout(area, computed)
        node.setLayoutBox(layout)
        let children = node.childNodes()
        if (children.size == 0 || cssDisplayIsHidden(computed.display)) { return }
        let content = computed.contentBox(layout)
        match (computed.display) {
            case CssDisplay.Flex => applyFlex(children, content, computed)
            case CssDisplay.Block => applyBlock(children, content, computed)
            case CssDisplay.Hidden => ()
        }
    }

    private func applyBlock(children: Array<ViewNode>, area: Rect, computed: ComputedStyle): Unit {
        let gap = computed.gap
        var y = area.y
        let visible = visibleChildren(children, computed)
        for (i in 0..visible.size) {
            let child = visible[i]
            let childStyle = compute(child, inherited: computed)
            let height = match (childStyle.height) {
                case Some(value) => value
                case None => max(1, area.height - (y - area.y) - max(0, visible.size - i - 1) * (1 + gap))
            }
            let childArea = Rect(area.x, y, area.width, min(max(0, height), max(0, area.bottom - y)))
            applyNode(child, childArea, computed)
            y += childArea.height + gap
            if (y >= area.bottom) { return }
        }
    }

    private func applyFlex(children: Array<ViewNode>, area: Rect, computed: ComputedStyle): Unit {
        let visible = visibleChildren(children, computed)
        if (visible.size == 0) { return }
        let totalGap = computed.gap * max(0, visible.size - 1)
        match (computed.flexDirection) {
            case CssFlexDirection.Row =>
                let share = max(0, area.width - totalGap) / visible.size
                var x = area.x
                for (child in visible) {
                    let childStyle = compute(child, inherited: computed)
                    let width = match (childStyle.width) {
                        case Some(value) => value
                        case None => share
                    }
                    let childArea = Rect(x, area.y, min(width, max(0, area.right - x)), area.height)
                    applyNode(child, childArea, computed)
                    x += childArea.width + computed.gap
                    if (x >= area.right) { return }
                }
            case CssFlexDirection.Column => applyBlock(visible, area, computed)
        }
    }

    private func visibleChildren(children: Array<ViewNode>, inherited: ComputedStyle): Array<ViewNode> {
        let out = ArrayList<ViewNode>()
        for (child in children) {
            if (!cssDisplayIsHidden(compute(child, inherited: inherited).display)) {
                out.add(child)
            }
        }
        out.toArray()
    }

    private func sortedMatchingRules(node: ViewNode): Array<CssRule> {
        let pending = ArrayList<CssRule>()
        for (rule in cssRules) {
            if (rule.matches(node)) {
                pending.add(rule)
            }
        }
        let out = ArrayList<CssRule>()
        while (pending.size > 0) {
            var bestIndex: Int64 = 0
            for (i in 1..pending.size) {
                if (pending[i].comesBefore(pending[bestIndex])) {
                    bestIndex = i
                }
            }
            out.add(pending[bestIndex])
            pending.remove(at: bestIndex)
        }
        out.toArray()
    }
}

public class StyleRule {
    public let selector: String
    public let state: StyleState
    public let style: Style

    public init(selector: String, style: Style, state!: StyleState = StyleState.Normal) {
        this.selector = selector
        this.style = style
        this.state = state
    }

    public func matches(selector: String, state: StyleState): Bool {
        this.selector == selector && styleStateEquals(this.state, state)
    }
}

public struct DesignTokens {
    public let gap: Int64
    public let padding: Int64
    public let radius: Int64
    public let accent: Color

    public init(gap!: Int64 = 1, padding!: Int64 = 1, radius!: Int64 = 0, accent!: Color = Color.Cyan) {
        this.gap = max(0, gap)
        this.padding = max(0, padding)
        this.radius = max(0, radius)
        this.accent = accent
    }
}

public class ThemePack {
    public let name: String
    public let theme: Theme
    public let tokens: DesignTokens
    public let sheet: StyleSheet

    public init(name: String, theme!: Theme = Theme.default(), tokens!: DesignTokens = DesignTokens(), sheet!: StyleSheet = StyleSheet()) {
        this.name = name
        this.theme = theme
        this.tokens = tokens
        this.sheet = sheet
    }
}

func styleStateEquals(a: StyleState, b: StyleState): Bool {
    match ((a, b)) {
        case (StyleState.Normal, StyleState.Normal) => true
        case (StyleState.Focused, StyleState.Focused) => true
        case (StyleState.Selected, StyleState.Selected) => true
        case (StyleState.Disabled, StyleState.Disabled) => true
        case (StyleState.Error, StyleState.Error) => true
        case (StyleState.Accent, StyleState.Accent) => true
        case _ => false
    }
}

func styleName(style: Style): String {
    if (style == Style.default()) { return "default" }
    "style"
}
