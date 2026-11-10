package core

import std.collection.*

/** 将一个或多个按键映射到同一动作，并提供可选的帮助说明。 */
public class KeyBinding {
    /** 可触发动作的按键。 */
    public let keys: Array<KeyEvent>
    /** 触发时返回的动作名称。 */
    public let action: String
    /** 帮助视图显示的说明；为空时显示动作名称。 */
    public let description: String

    /** 创建按键绑定。
     * @param keys 可触发动作的按键
     * @param action 动作名称
     * @param description 可选的帮助说明
     */
    public init(keys: Array<KeyEvent>, action: String, description!: String = "") {
        this.keys = keys
        this.action = action
        this.description = description
    }

    /** 按键码和修饰键比较是否匹配任一绑定。
     * @param key 待匹配的按键
     * @return 匹配时为 true
     */
    public func matches(key: KeyEvent): Bool {
        for (candidate in keys) {
            if (keyEventEquals(candidate, key)) { return true }
        }
        false
    }
}

/** 按添加顺序保存按键绑定并查找动作。 */
public class KeyMap {
    private let bindings = ArrayList<KeyBinding>()

    /** 创建键位映射并依次加入初始绑定。
     * @param bindings 初始绑定
     */
    public init(bindings!: Array<KeyBinding> = []) {
        for (binding in bindings) {
            this.bindings.add(binding)
        }
    }

    /** 在末尾追加绑定。
     * @param binding 待添加绑定
     */
    public func add(binding: KeyBinding): Unit {
        bindings.add(binding)
    }

    /** 查找第一个匹配按键的绑定。
     * @param key 待查找的按键
     * @return 匹配时返回动作，否则返回 None
     */
    public func actionFor(key: KeyEvent): ?String {
        for (binding in bindings) {
            if (binding.matches(key)) { return Some(binding.action) }
        }
        None
    }

    /** 获取按添加顺序排列的绑定数组。
     * @return 绑定数组的副本
     */
    public func all(): Array<KeyBinding> {
        bindings.toArray()
    }
}

/** 将键位映射和说明绘制为单行帮助文本。 */
public class HelpView <: Widget {
    private let keymap: KeyMap
    private let style: Style
    private let separator: String

    /** 创建帮助视图。
     * @param keymap 要显示的键位映射
     * @param style 文本样式
     * @param separator 相邻绑定之间的分隔文本
     */
    public init(keymap: KeyMap, style!: Style = Style(fg: Color.Indexed(8)), separator!: String = "  ") {
        this.keymap = keymap
        this.style = style
        this.separator = separator
    }

    /** 从区域左上角绘制帮助文本，按区域宽度截断。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let parts = ArrayList<String>()
        for (binding in keymap.all()) {
            let desc = if (binding.description.isEmpty()) { binding.action } else { binding.description }
            parts.add(keyLabel(binding.keys) + ": " + desc)
        }
        let text = join(parts.toArray(), separator)
        buffer.setString(area.x, area.y, truncate(text, area.width, options: buffer.textWidthOptions()), style: style)
    }
}

func keyEventEquals(a: KeyEvent, b: KeyEvent): Bool {
    a.modifiers == b.modifiers && keyCodeEquals(a.code, b.code)
}

func keyCodeEquals(a: KeyCode, b: KeyCode): Bool {
    match ((a, b)) {
        case (KeyCode.Char(x), KeyCode.Char(y)) => x == y
        case (KeyCode.CtrlC, KeyCode.CtrlC) => true
        case (KeyCode.Esc, KeyCode.Esc) => true
        case (KeyCode.Tab, KeyCode.Tab) => true
        case (KeyCode.BackTab, KeyCode.BackTab) => true
        case (KeyCode.Enter, KeyCode.Enter) => true
        case (KeyCode.Backspace, KeyCode.Backspace) => true
        case (KeyCode.Delete, KeyCode.Delete) => true
        case (KeyCode.Insert, KeyCode.Insert) => true
        case (KeyCode.Up, KeyCode.Up) => true
        case (KeyCode.Down, KeyCode.Down) => true
        case (KeyCode.Left, KeyCode.Left) => true
        case (KeyCode.Right, KeyCode.Right) => true
        case (KeyCode.Home, KeyCode.Home) => true
        case (KeyCode.End, KeyCode.End) => true
        case (KeyCode.PageUp, KeyCode.PageUp) => true
        case (KeyCode.PageDown, KeyCode.PageDown) => true
        case (KeyCode.F(x), KeyCode.F(y)) => x == y
        case _ => false
    }
}

func keyLabel(keys: Array<KeyEvent>): String {
    let labels = ArrayList<String>()
    for (key in keys) {
        labels.add(singleKeyLabel(key))
    }
    join(labels.toArray(), "/")
}

func singleKeyLabel(key: KeyEvent): String {
    let prefix = modifierLabel(key.modifiers)
    prefix + match (key.code) {
        case KeyCode.Char(r) => runeToString(r)
        case KeyCode.CtrlC => "ctrl+c"
        case KeyCode.Esc => "esc"
        case KeyCode.Tab => "tab"
        case KeyCode.BackTab => "shift+tab"
        case KeyCode.Enter => "enter"
        case KeyCode.Backspace => "backspace"
        case KeyCode.Delete => "delete"
        case KeyCode.Insert => "insert"
        case KeyCode.Up => "up"
        case KeyCode.Down => "down"
        case KeyCode.Left => "left"
        case KeyCode.Right => "right"
        case KeyCode.Home => "home"
        case KeyCode.End => "end"
        case KeyCode.PageUp => "pgup"
        case KeyCode.PageDown => "pgdn"
        case KeyCode.F(n) => "f${n}"
    }
}

func modifierLabel(modifiers: KeyModifier): String {
    var text = ""
    if (modifiers.ctrl) { text += "ctrl+" }
    if (modifiers.alt) { text += "alt+" }
    if (modifiers.shift) { text += "shift+" }
    text
}
