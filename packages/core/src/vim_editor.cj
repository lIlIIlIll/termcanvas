package core

// A limited, opt-in modal policy for one TextArea. The application's edit/preview
// focus state remains independent of this editor's Normal/Insert state.
/** Vim 编辑行为支持的模式。 */
public enum VimMode {
    /** 普通模式，按键用于导航和有限编辑命令。 */
    | Normal
    /** 插入模式，输入交给插入处理器。 */
    | Insert
}

/** 为一个 TextArea 提供可选的有限 Vim 模式编辑行为；应用焦点状态由调用方单独管理。 */
public class VimEditorBehavior {
    private let area: TextArea
    private let insertHandler: (TextArea, KeyEvent) -> Bool
    private var currentMode: VimMode = VimMode.Normal
    private var prefix: ?Rune = None
    private var attached: Bool = true

    /** 附加编辑行为并进入普通模式；同一 TextArea 不能同时附加两个活动行为。
     * @param area 要控制的文本区域
     * @param insertHandler 插入模式下处理按键的回调
     * @throws IllegalStateException 文本区域已附加其他活动 Vim 编辑行为
     */
    public init(area: TextArea, insertHandler!: (TextArea, KeyEvent) -> Bool = { target, key => target.handle(key) }) {
        this.area = area
        this.insertHandler = insertHandler
        if (area.vimEditorAttached) { throw IllegalStateException("TextArea already has an active Vim editor") }
        area.vimEditorAttached = true
        area.setCarets([TextAreaCaret(area.cursor)])
        area.invalidateCompletionRequest()
        normalizeCursor()
    }

    /** 当前普通或插入模式。 */
    public prop mode: VimMode {
        get() { currentMode }
    }

    /** 退出插入模式并解除附加；可重复调用。后续 handle 可尝试重新附加。 */
    public func deactivate(): Unit {
        if (!attached) { return }
        if (let VimMode.Insert <- currentMode) {
            leaveInsert()
        } else {
            prefix = None
            area.setCarets([TextAreaCaret(area.cursor)])
            area.invalidateCompletionRequest()
            normalizeCursor()
        }
        area.vimEditorAttached = false
        attached = false
    }

    /** 处理按键、粘贴和补全事件；失焦会解除附加。解除后再次处理事件时尝试重新附加。
     * @param event 输入或补全事件
     * @return 事件被处理时为 true
     * @throws IllegalStateException 重新附加时文本区域已有其他活动 Vim 编辑行为
     */
    public func handle(event: Event): Bool {
        if (let Event.FocusOut <- event) { deactivate(); return false }
        if (!attached) {
            if (area.vimEditorAttached) { throw IllegalStateException("TextArea already has an active Vim editor") }
            area.vimEditorAttached = true
            attached = true
        }
        match (event) {
            case Event.FocusOut =>
                deactivate()
                false
            case Event.TextCompletion(_, _) | Event.AsyncCompleted(_, _) =>
                match (currentMode) {
                    case VimMode.Insert => area.handleCompletionEvent(event)
                    case VimMode.Normal => false
                }
            case Event.Paste(text) =>
                if (area.readOnly) { if (let VimMode.Insert <- currentMode) { deactivate() } }
                if (area.readOnly || text.isEmpty()) { return true }
                match (currentMode) {
                    case VimMode.Insert =>
                        area.beginUndoGroup()
                        area.paste(text)
                    case VimMode.Normal =>
                        prefix = None
                        area.beginUndoGroup()
                        let end = area.lineEndForOffset(area.cursor)
                        if (area.cursor < end) { area.cursor = area.nextOffset(area.cursor) }
                        area.paste(text)
                        area.cursor = if (text.endsWith("\n")) { area.cursor } else { area.previousOffset(area.cursor) }
                        area.endUndoGroup()
                        normalizeCursor()
                }
                true
            case Event.KeyDown(key) => handleKey(key, false)
            case Event.KeyRepeat(key) => handleKey(key, true)
            case _ => false
        }
    }

    private func handleKey(key: KeyEvent, repeated: Bool): Bool {
        if (area.readOnly) { if (let VimMode.Insert <- currentMode) { deactivate() } }
        let repeat = repeated || key.nativeRepeat
        if (let KeyCode.Esc <- key.code) {
            if (repeat) { return true }
            prefix = None
            match (currentMode) {
                case VimMode.Insert =>
                    if (area.completionVisible()) { area.invalidateCompletionRequest() }
                    else { leaveInsert() }
                case VimMode.Normal => area.invalidateCompletionRequest()
            }
            return true
        }
        match (currentMode) {
            case VimMode.Insert =>
                if (let KeyCode.CtrlC <- key.code) { return false }
                if (let KeyCode.F(_) <- key.code) { return false }
                area.beginUndoGroup()
                try {
                    if (area.completionVisible()) {
                        match (key.code) {
                            case KeyCode.Up | KeyCode.Down | KeyCode.Enter | KeyCode.Tab => return area.handle(key)
                            case _ => ()
                        }
                    }
                    return insertHandler(area, key)
                } catch (error: Exception) {
                    deactivate()
                    throw error
                }
            case VimMode.Normal => handleNormal(key, repeat)
        }
    }

    private func handleNormal(key: KeyEvent, repeat: Bool): Bool {
        let mods = key.modifiers
        if (mods.alt || mods.superKey || mods.meta || mods.hyper) { return false }
        if (mods.ctrl) {
            if (let KeyCode.Char(r) <- key.code) {
                if (r == r'r' && !mods.shift) {
                    if (let Some(_) <- prefix) { prefix = None; return true }
                    if (!area.readOnly) { _ = area.redo(); normalizeCursor() }
                    return true
                }
            }
            return false
        }
        if (let KeyCode.CtrlC <- key.code) { return false }
        if (let KeyCode.F(_) <- key.code) { return false }
        if (let Some(_) <- prefix) {
            if (repeat) { return true }
            match (normalCharacter(key)) {
                case Some(r) =>
                    let pending = prefix
                    prefix = None
                    match (pending) {
                        case Some(r'g') => if (r == r'g') { jumpToLine(false) }
                        case Some(r'd') => if (r == r'd' && !area.readOnly) { deleteLine() }
                        case _ => ()
                    }
                    return true
                case None =>
                    prefix = None
                    return true
            }
        }
        match (key.code) {
            case KeyCode.Left | KeyCode.Right | KeyCode.Up | KeyCode.Down |
                 KeyCode.Home | KeyCode.End | KeyCode.PageUp | KeyCode.PageDown =>
                if (mods.shift) { return false }
                navigate(key.code)
                return true
            case KeyCode.Char(_) => ()
            case _ => return false
        }
        match (normalCharacter(key)) {
            case None => true
            case Some(r) =>
                if (repeat && !(r == r'h' || r == r'j' || r == r'k' || r == r'l' ||
                    r == r'w' || r == r'b' || r == r'0' || r == r'$' || r == r'G' ||
                    r == r'x' || r == r'u')) { return true }
                match (r) {
                    case r'g' | r'd' => prefix = Some(r)
                    case r'h' => navigate(KeyCode.Left)
                    case r'l' => navigate(KeyCode.Right)
                    case r'j' => navigate(KeyCode.Down)
                    case r'k' => navigate(KeyCode.Up)
                    case r'w' => area.moveWordRight(); normalizeCursor()
                    case r'b' => area.moveWordLeft(); normalizeCursor()
                    case r'0' => area.cursor = area.lineStartForOffset(area.cursor)
                    case r'$' => area.cursor = lastCharacter(area.cursor)
                    case r'G' => jumpToLine(true)
                    case r'i' => enterInsert(area.cursor)
                    case r'a' =>
                        let end = area.lineEndForOffset(area.cursor)
                        enterInsert(if (area.cursor < end) { area.nextOffset(area.cursor) } else { end })
                    case r'I' => enterInsert(firstNonBlank(area.lineStartForOffset(area.cursor)))
                    case r'A' => enterInsert(area.lineEndForOffset(area.cursor))
                    case r'o' | r'O' => openLine(r == r'o')
                    case r'x' => if (!area.readOnly) { deleteCharacter() }
                    case r'u' => if (!area.readOnly) { _ = area.undo(); normalizeCursor() }
                    case _ => ()
                }
                true
        }
    }

    private func normalCharacter(key: KeyEvent): ?Rune {
        match (key.code) {
            case KeyCode.Char(r) =>
                let n = UInt32(r)
                if (n > 127u32) { return None }
                if (let Some(text) <- key.text) {
                    if (text != runeToString(r)) {
                        let bytes = unsafe { text.rawData() }
                        if (bytes.size == 1 && bytes[0] < 128u8) { return Some(Rune(UInt32(bytes[0]))) }
                        return None
                    }
                }
                if (key.modifiers.shift) {
                    if (r >= r'a' && r <= r'z') { return Some(Rune(n - 32u32)) }
                    if (r == r'4') { return Some(r'$') }
                    if (r >= r'0' && r <= r'9') { return None }
                }
                Some(r)
            case _ => None
        }
    }

    private func navigate(code: KeyCode): Unit {
        let start = area.lineStartForOffset(area.cursor)
        let end = area.lineEndForOffset(area.cursor)
        match (code) {
            case KeyCode.Left => if (area.cursor > start) { area.cursor = area.previousOffset(area.cursor) }
            case KeyCode.Right =>
                if (area.cursor < end) {
                    let next = area.nextOffset(area.cursor)
                    if (next < end) { area.cursor = next }
                }
            case KeyCode.Home => area.cursor = start
            case KeyCode.End => area.cursor = lastCharacter(area.cursor)
            case _ => _ = area.handle(KeyEvent(code))
        }
        normalizeCursor()
    }

    private func lastCharacter(offset: Int64): Int64 {
        let start = area.lineStartForOffset(offset)
        let end = area.lineEndForOffset(offset)
        if (end == start) { start } else { area.previousOffset(end) }
    }

    private func firstNonBlank(start: Int64): Int64 {
        let end = area.lineEndForOffset(start)
        var pos = start
        while (pos < end) {
            let part = area.textModel.slice(pos, area.nextOffset(pos))
            if (part != " " && part != "\t") { break }
            pos = area.nextOffset(pos)
        }
        if (pos == end) { start } else { pos }
    }

    private func jumpToLine(last: Bool): Unit {
        let start = if (last) { area.lineStartForOffset(area.textModel.byteLength()) } else { 0 }
        area.cursor = firstNonBlank(start)
        normalizeCursor()
    }

    private func normalizeCursor(): Unit {
        let start = area.lineStartForOffset(area.cursor)
        let end = area.lineEndForOffset(area.cursor)
        if (start == end) { area.cursor = start; return }
        let target = area.textModel.clampOffset(area.cursor)
        var pos = start
        while (true) {
            let next = area.nextOffset(pos)
            if (next >= end || next > target) { area.cursor = pos; return }
            pos = next
        }
    }

    private func enterInsert(offset: Int64): Unit {
        if (area.readOnly) { return }
        area.beginUndoGroup()
        area.cursor = offset
        currentMode = VimMode.Insert
    }

    private func leaveInsert(): Unit {
        area.endUndoGroup()
        area.cursor = max(area.lineStartForOffset(area.cursor), area.previousOffset(area.cursor))
        area.setCarets([TextAreaCaret(area.cursor)])
        prefix = None
        area.invalidateCompletionRequest()
        currentMode = VimMode.Normal
        normalizeCursor()
    }

    private func openLine(below: Bool): Unit {
        if (area.readOnly) { return }
        area.beginUndoGroup()
        let start = area.lineStartForOffset(area.cursor)
        let end = area.lineEndForOffset(area.cursor)
        area.cursor = if (below) { end } else { start }
        area.paste("\n")
        if (!below) { area.cursor = start }
        currentMode = VimMode.Insert
    }

    private func deleteCharacter(): Unit {
        let end = area.lineEndForOffset(area.cursor)
        if (area.cursor >= end) { return }
        area.beginUndoGroup()
        area.select(area.cursor, area.nextOffset(area.cursor))
        area.deleteSelection()
        area.endUndoGroup()
        normalizeCursor()
    }

    private func deleteLine(): Unit {
        let start = area.lineStartForOffset(area.cursor)
        let end = area.lineEndForOffset(area.cursor)
        if (start == 0 && end == 0 && area.textModel.byteLength() == 0) { return }
        var from = start
        var to = end
        if (end < area.textModel.byteLength()) { to++ }
        else if (start > 0) {
            from--
            if (from > 0 && area.textModel.slice(from - 1, from + 1) == "\r\n") { from-- }
        }
        area.beginUndoGroup()
        area.select(from, to)
        area.deleteSelection()
        area.cursor = firstNonBlank(area.lineStartForOffset(min(start, area.textModel.byteLength())))
        area.endUndoGroup()
        normalizeCursor()
    }
}
