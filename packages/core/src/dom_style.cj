package core

import std.collection.*

public enum CssDisplay {
    | Hidden
    | Block
    | Flex
}

public enum CssFlexDirection {
    | Row
    | Column
}

public enum CssSelectorRelation {
    | Self
    | Descendant
    | Child
}

func cssDisplayIsHidden(display: CssDisplay): Bool {
    match (display) {
        case CssDisplay.Hidden => true
        case _ => false
    }
}

public class StyleDeclaration {
    public var style: ?Style = None
    public var display: ?CssDisplay = None
    public var width: ?Int64 = None
    public var height: ?Int64 = None
    public var minWidth: ?Int64 = None
    public var minHeight: ?Int64 = None
    public var maxWidth: ?Int64 = None
    public var maxHeight: ?Int64 = None
    public var margin: ?Spacing = None
    public var padding: ?Spacing = None
    public var border: ?Spacing = None
    public var gap: ?Int64 = None
    public var flexDirection: ?CssFlexDirection = None
    public var objectFit: ?MediaFit = None

    public init() {}

    public static func visual(style: Style): StyleDeclaration {
        let out = StyleDeclaration()
        out.style = Some(style)
        out
    }

    public static func parse(text: String): StyleDeclaration {
        let out = StyleDeclaration()
        for (raw in splitCssDeclarations(text)) {
            let pair = splitCssProperty(raw)
            match (pair) {
                case Some((name, value)) => applyCssProperty(out, name, value)
                case None => ()
            }
        }
        out
    }
}

public class ComputedStyle {
    public var style: Style
    public var display: CssDisplay
    public var width: ?Int64
    public var height: ?Int64
    public var minWidth: Int64
    public var minHeight: Int64
    public var maxWidth: Int64
    public var maxHeight: Int64
    public var margin: Spacing
    public var padding: Spacing
    public var border: Spacing
    public var gap: Int64
    public var flexDirection: CssFlexDirection
    public var objectFit: MediaFit

    public init(
        style!: Style = Style.default(),
        display!: CssDisplay = CssDisplay.Block,
        width!: ?Int64 = None,
        height!: ?Int64 = None,
        minWidth!: Int64 = 0,
        minHeight!: Int64 = 0,
        maxWidth!: Int64 = Int64.Max,
        maxHeight!: Int64 = Int64.Max,
        margin!: Spacing = Spacing.zero(),
        padding!: Spacing = Spacing.zero(),
        border!: Spacing = Spacing.zero(),
        gap!: Int64 = 0,
        flexDirection!: CssFlexDirection = CssFlexDirection.Row,
        objectFit!: MediaFit = MediaFit.Contain
    ) {
        this.style = style
        this.display = display
        this.width = width
        this.height = height
        this.minWidth = max(0, minWidth)
        this.minHeight = max(0, minHeight)
        this.maxWidth = max(0, maxWidth)
        this.maxHeight = max(0, maxHeight)
        this.margin = margin
        this.padding = padding
        this.border = border
        this.gap = max(0, gap)
        this.flexDirection = flexDirection
        this.objectFit = objectFit
    }

    public static func default(): ComputedStyle {
        ComputedStyle()
    }

    public static func inherit(parent: ComputedStyle): ComputedStyle {
        ComputedStyle(style: parent.style)
    }

    public func patch(declarations: StyleDeclaration): ComputedStyle {
        let out = copy()
        match (declarations.style) {
            case Some(value) => out.style = out.style.patch(value)
            case None => ()
        }
        match (declarations.display) {
            case Some(value) => out.display = value
            case None => ()
        }
        match (declarations.width) {
            case Some(value) => out.width = Some(max(0, value))
            case None => ()
        }
        match (declarations.height) {
            case Some(value) => out.height = Some(max(0, value))
            case None => ()
        }
        match (declarations.minWidth) {
            case Some(value) => out.minWidth = max(0, value)
            case None => ()
        }
        match (declarations.minHeight) {
            case Some(value) => out.minHeight = max(0, value)
            case None => ()
        }
        match (declarations.maxWidth) {
            case Some(value) => out.maxWidth = max(0, value)
            case None => ()
        }
        match (declarations.maxHeight) {
            case Some(value) => out.maxHeight = max(0, value)
            case None => ()
        }
        match (declarations.margin) {
            case Some(value) => out.margin = value
            case None => ()
        }
        match (declarations.padding) {
            case Some(value) => out.padding = value
            case None => ()
        }
        match (declarations.border) {
            case Some(value) => out.border = value
            case None => ()
        }
        match (declarations.gap) {
            case Some(value) => out.gap = max(0, value)
            case None => ()
        }
        match (declarations.flexDirection) {
            case Some(value) => out.flexDirection = value
            case None => ()
        }
        match (declarations.objectFit) {
            case Some(value) => out.objectFit = value
            case None => ()
        }
        out
    }

    public func contentBox(area: Rect): Rect {
        border.inner(padding.inner(area))
    }

    public func copy(): ComputedStyle {
        ComputedStyle(
            style: style,
            display: display,
            width: width,
            height: height,
            minWidth: minWidth,
            minHeight: minHeight,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            margin: margin,
            padding: padding,
            border: border,
            gap: gap,
            flexDirection: flexDirection,
            objectFit: objectFit
        )
    }
}

public class CssSelector {
    public let tag: String
    public let id: String
    public let classes: Array<String>
    public let pseudo: String
    public let part: String
    public let relation: CssSelectorRelation
    public let ancestor: ?CssSelector

    public init(
        tag!: String = "",
        id!: String = "",
        classes!: Array<String> = [],
        pseudo!: String = "",
        part!: String = "",
        relation!: CssSelectorRelation = CssSelectorRelation.Self,
        ancestor!: ?CssSelector = None
    ) {
        this.tag = tag
        this.id = id
        this.classes = classes
        this.pseudo = pseudo
        this.part = part
        this.relation = relation
        this.ancestor = ancestor
    }

    public static func parse(text: String): ?CssSelector {
        parseSelector(cssTrimAscii(text))
    }

    public func matches(node: ViewNode): Bool {
        if (!matchesSimple(node)) { return false }
        match (ancestor) {
            case Some(parentSelector) =>
                match (relation) {
                    case CssSelectorRelation.Child =>
                        match (node.parentNode()) {
                            case Some(parent) => parentSelector.matches(parent)
                            case None => false
                        }
                    case CssSelectorRelation.Descendant => matchesAncestor(parentSelector, node)
                    case CssSelectorRelation.Self => true
                }
            case None => true
        }
    }

    public func specificity(): Int64 {
        var out: Int64 = 0
        if (!id.isEmpty()) { out += 100 }
        out += classes.size * 10
        if (!pseudo.isEmpty()) { out += 10 }
        if (!part.isEmpty()) { out += 10 }
        if (!tag.isEmpty()) { out += 1 }
        match (ancestor) {
            case Some(selector) => out + selector.specificity()
            case None => out
        }
    }

    private func matchesSimple(node: ViewNode): Bool {
        if (!tag.isEmpty() && tag != node.tag) { return false }
        if (!id.isEmpty() && id != node.id) { return false }
        if (!part.isEmpty() && part != node.partName()) { return false }
        if (!pseudo.isEmpty() && !node.hasState(pseudo)) { return false }
        for (className in classes) {
            if (!node.hasClass(className)) { return false }
        }
        true
    }

    private func matchesAncestor(selector: CssSelector, node: ViewNode): Bool {
        var current = node.parentNode()
        while (true) {
            match (current) {
                case Some(candidate) =>
                    if (selector.matches(candidate)) { return true }
                    current = candidate.parentNode()
                case None => return false
            }
        }
        false
    }
}

public class CssRule {
    public let selector: CssSelector
    public let declarations: StyleDeclaration
    public let specificity: Int64
    public var sourceOrder: Int64 = 0

    public init(selector: CssSelector, declarations: StyleDeclaration, sourceOrder!: Int64 = 0) {
        this.selector = selector
        this.declarations = declarations
        this.specificity = selector.specificity()
        this.sourceOrder = max(0, sourceOrder)
    }

    public func matches(node: ViewNode): Bool {
        selector.matches(node)
    }

    public func comesBefore(other: CssRule): Bool {
        if (specificity < other.specificity) { return true }
        if (specificity > other.specificity) { return false }
        sourceOrder < other.sourceOrder
    }
}

func computeNodeLayout(area: Rect, style: ComputedStyle): Rect {
    let base = style.margin.inner(area)
    let width = match (style.width) {
        case Some(value) => value
        case None => base.width
    }
    let height = match (style.height) {
        case Some(value) => value
        case None => base.height
    }
    Rect(base.x, base.y, clamp(width, style.minWidth, style.maxWidth), clamp(height, style.minHeight, style.maxHeight))
}

func parseSelector(text: String): ?CssSelector {
    let childIndex = indexOfChar(text, r'>')
    match (childIndex) {
        case Some(index) =>
            let left = parseSelector(text[..index])
            let right = parseSimpleSelector(text[index + 1..])
            match ((left, right)) {
                case (Some(l), Some(r)) => Some(CssSelector(tag: r.tag, id: r.id, classes: r.classes, pseudo: r.pseudo, part: r.part, relation: CssSelectorRelation.Child, ancestor: Some(l)))
                case _ => None
            }
        case None =>
            let spaceIndex = lastAsciiSpaceIndex(text)
            match (spaceIndex) {
                case Some(index) =>
                    let left = parseSelector(text[..index])
                    let right = parseSimpleSelector(text[index + 1..])
                    match ((left, right)) {
                        case (Some(l), Some(r)) => Some(CssSelector(tag: r.tag, id: r.id, classes: r.classes, pseudo: r.pseudo, part: r.part, relation: CssSelectorRelation.Descendant, ancestor: Some(l)))
                        case _ => None
                    }
                case None => parseSimpleSelector(text)
            }
    }
}

func parseSimpleSelector(raw: String): ?CssSelector {
    let text = cssTrimAscii(raw)
    if (text.isEmpty()) { return None }
    let parts = CssSelectorParts()
    var token = ""
    var mode: Rune = r't'
    var i: Int64 = 0
    while (i < text.size) {
        let ch = runeAtAscii(text, i)
        if (ch == r'.' || ch == r'#' || ch == r':') {
            parts.flush(mode, token)
            token = ""
            if (ch == r':' && i + 1 < text.size && runeAtAscii(text, i + 1) == r':') {
                mode = r'p'
                i++
            } else {
                mode = ch
            }
        } else if (cssIsAsciiSpace(ch)) {
            return None
        } else {
            token += "${ch}"
        }
        i++
    }
    parts.flush(mode, token)
    Some(CssSelector(tag: parts.tag, id: parts.id, classes: parts.classes.toArray(), pseudo: parts.pseudo, part: normalizePart(parts.part)))
}

func normalizePart(value: String): String {
    if (value.startsWith("part(") && value.endsWith(")")) {
        value[5..value.size - 1]
    } else {
        value
    }
}

class CssSelectorParts {
    var tag: String = ""
    var id: String = ""
    var pseudo: String = ""
    var part: String = ""
    let classes = ArrayList<String>()

    init() {}

    func flush(mode: Rune, token: String): Unit {
        if (token.isEmpty()) { return }
        if (mode == r'.') {
            classes.add(token)
        } else if (mode == r'#') {
            id = token
        } else if (mode == r':') {
            pseudo = token
        } else if (mode == r'p') {
            part = token
        } else {
            tag = token
        }
    }
}

func applyCssProperty(out: StyleDeclaration, name: String, value: String): Unit {
    if (name == "color" || name == "fg") {
        match (parseCssColor(value)) {
            case Some(color) => out.style = Some(currentStyle(out).withFg(color))
            case None => ()
        }
    } else if (name == "background-color" || name == "background" || name == "bg") {
        match (parseCssColor(value)) {
            case Some(color) => out.style = Some(currentStyle(out).withBg(color))
            case None => ()
        }
    } else if (name == "font-weight" && value == "bold") {
        var modifier = currentStyle(out).modifier
        modifier.bold = true
        out.style = Some(currentStyle(out).withModifier(modifier))
    } else if (name == "font-style" && value == "italic") {
        var modifier = currentStyle(out).modifier
        modifier.italic = true
        out.style = Some(currentStyle(out).withModifier(modifier))
    } else if (name == "text-decoration" && value == "underline") {
        var modifier = currentStyle(out).modifier
        modifier.underline = true
        out.style = Some(currentStyle(out).withModifier(modifier))
    } else if (name == "modifier" && value == "reversed") {
        var modifier = currentStyle(out).modifier
        modifier.reversed = true
        out.style = Some(currentStyle(out).withModifier(modifier))
    } else if (name == "display") {
        if (value == "none") { out.display = Some(CssDisplay.Hidden) }
        else if (value == "flex") { out.display = Some(CssDisplay.Flex) }
        else if (value == "block") { out.display = Some(CssDisplay.Block) }
    } else if (name == "width") {
        out.width = parseCssInt(value)
    } else if (name == "height") {
        out.height = parseCssInt(value)
    } else if (name == "min-width") {
        out.minWidth = parseCssInt(value)
    } else if (name == "min-height") {
        out.minHeight = parseCssInt(value)
    } else if (name == "max-width") {
        out.maxWidth = parseCssInt(value)
    } else if (name == "max-height") {
        out.maxHeight = parseCssInt(value)
    } else if (name == "gap") {
        out.gap = parseCssInt(value)
    } else if (name == "padding") {
        match (parseCssInt(value)) {
            case Some(v) => out.padding = Some(Spacing.all(v))
            case None => ()
        }
    } else if (name == "margin") {
        match (parseCssInt(value)) {
            case Some(v) => out.margin = Some(Spacing.all(v))
            case None => ()
        }
    } else if (name == "border") {
        match (parseCssInt(value)) {
            case Some(v) => out.border = Some(Spacing.all(v))
            case None => ()
        }
    } else if (name == "flex-direction") {
        if (value == "column") { out.flexDirection = Some(CssFlexDirection.Column) }
        else if (value == "row") { out.flexDirection = Some(CssFlexDirection.Row) }
    } else if (name == "object-fit") {
        if (value == "contain") { out.objectFit = Some(MediaFit.Contain) }
        else if (value == "cover") { out.objectFit = Some(MediaFit.Cover) }
        else if (value == "fill") { out.objectFit = Some(MediaFit.Fill) }
        else if (value == "none") { out.objectFit = Some(MediaFit.Original) }
    }
}

func currentStyle(declaration: StyleDeclaration): Style {
    match (declaration.style) {
        case Some(style) => style
        case None => Style.default()
    }
}

func parseCssColor(value: String): ?Color {
    if (value == "reset" || value == "default") { Some(Color.Reset) }
    else if (value == "black") { Some(Color.Black) }
    else if (value == "red") { Some(Color.Red) }
    else if (value == "green") { Some(Color.Green) }
    else if (value == "yellow") { Some(Color.Yellow) }
    else if (value == "blue") { Some(Color.Blue) }
    else if (value == "magenta") { Some(Color.Magenta) }
    else if (value == "cyan") { Some(Color.Cyan) }
    else if (value == "white") { Some(Color.White) }
    else { None }
}

func parseCssInt(value: String): ?Int64 {
    let trimmed = cssTrimAscii(value)
    if (trimmed.isEmpty()) { return None }
    var limit = trimmed.size
    if (trimmed.endsWith("px")) { limit -= 2 }
    var out: Int64 = 0
    let bytes = unsafe { trimmed.rawData() }
    for (i in 0..limit) {
        let ch = bytes[i]
        if (ch < 48 || ch > 57) { return None }
        out = out * 10 + Int64(ch - 48)
    }
    Some(out)
}

func splitCssDeclarations(text: String): Array<String> {
    let out = ArrayList<String>()
    var start: Int64 = 0
    for (i in 0..text.size) {
        if (runeAtAscii(text, i) == r';') {
            out.add(text[start..i])
            start = i + 1
        }
    }
    if (start < text.size) { out.add(text[start..]) }
    out.toArray()
}

func splitCssProperty(text: String): ?(String, String) {
    let index = indexOfChar(text, r':')
    match (index) {
        case Some(i) => Some((cssTrimAscii(text[..i]), cssTrimAscii(text[i + 1..])))
        case None => None
    }
}

func splitSelectorList(text: String): Array<String> {
    let out = ArrayList<String>()
    var start: Int64 = 0
    for (i in 0..text.size) {
        if (runeAtAscii(text, i) == r',') {
            out.add(cssTrimAscii(text[start..i]))
            start = i + 1
        }
    }
    if (start < text.size) { out.add(cssTrimAscii(text[start..])) }
    out.toArray()
}

func indexOfChar(text: String, ch: Rune): ?Int64 {
    for (i in 0..text.size) {
        if (runeAtAscii(text, i) == ch) { return Some(i) }
    }
    None
}

func lastAsciiSpaceIndex(text: String): ?Int64 {
    var i = text.size - 1
    while (i >= 0) {
        if (cssIsAsciiSpace(runeAtAscii(text, i))) { return Some(i) }
        i--
    }
    None
}

func cssTrimAscii(text: String): String {
    var start: Int64 = 0
    var end: Int64 = text.size
    while (start < end && cssIsAsciiSpace(runeAtAscii(text, start))) { start++ }
    while (end > start && cssIsAsciiSpace(runeAtAscii(text, end - 1))) { end-- }
    text[start..end]
}

func cssIsAsciiSpace(ch: Rune): Bool {
    ch == r' ' || ch == r'\n' || ch == r'\t' || ch == r'\r'
}

func runeAtAscii(text: String, index: Int64): Rune {
    let bytes = unsafe { text.rawData() }
    let (r, _) = Rune.fromUtf8(bytes, index)
    r
}
