package core

import std.collection.*

@FastNative
foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): IntNative

/** 提供可用终端输入字节的来源。 */
public interface InputSource {
    /** 读取输入字节；具体输入源可能等待数据。
    * @param maxBytes 希望读取的最大字节数
    * @return 读取到的字节
     */
    func readAvailable(maxBytes: Int64): Array<Byte>
}

public class StdinInputSource <: InputSource {
    @When[os == "Windows"]
    private let console = WindowsConsoleInput()

    public init() {}

    public func readAvailable(maxBytes: Int64): Array<Byte> { readNative(maxBytes) }

    @When[os == "Windows"]
    private func readNative(maxBytes: Int64): Array<Byte> { console.readAvailable(maxBytes) }

    @When[os != "Windows"]
    private func readNative(maxBytes: Int64): Array<Byte> {
        let capacity = max(1, maxBytes)
        let bytes = Array<Byte>(capacity, repeat: 0)
        unsafe {
            let handle = acquireArrayRawData(bytes)
            let n = read(STDIN_FILENO, CPointer<Unit>(handle.pointer), UIntNative(bytes.size))
            releaseArrayRawData(handle)
            if (n > 0) {
                return bytes[..Int64(n)]
            }
        }
        []
    }
}

/** 键盘按键代码。 */
public enum KeyCode {
    /** 字符按键。
     * @param _0 输入字符
     */
    | Char(Rune)
    /** Ctrl+C 按键。 */
    | CtrlC
    /** Escape 按键。 */
    | Esc
    /** Tab 按键。 */
    | Tab
    /** 反向 Tab 按键。 */
    | BackTab
    /** 回车按键。 */
    | Enter
    /** 退格按键。 */
    | Backspace
    /** 向前删除按键。 */
    | Delete
    /** 插入按键。 */
    | Insert
    /** 上方向键。 */
    | Up
    /** 下方向键。 */
    | Down
    /** 左方向键。 */
    | Left
    /** 右方向键。 */
    | Right
    /** Home 按键。 */
    | Home
    /** End 按键。 */
    | End
    /** 向上翻页键。 */
    | PageUp
    /** 向下翻页键。 */
    | PageDown
    /** 功能键。
     * @param _0 功能键编号
     */
    | F(Int64)
}

/** 键盘输入使用的终端协议。 */
public enum KeyProtocol {
    /** 基础键盘协议。 */
    | Basic
    /** ModifyOtherKeys 协议。 */
    | ModifyOtherKeys
    /** Kitty 键盘协议。 */
    | Kitty
}

/** 键盘或鼠标事件携带的修饰键及锁定状态。 */
public struct KeyModifier <: Equatable<KeyModifier> {
    /** Shift 状态。 */
    public let shift: Bool
    /** Alt 状态。 */
    public let alt: Bool
    /** Ctrl 状态。 */
    public let ctrl: Bool
    /** Super 状态。 */
    public let superKey: Bool
    /** Meta 状态。 */
    public let meta: Bool
    /** Hyper 状态。 */
    public let hyper: Bool
    /** 大写锁定状态。 */
    public let capsLock: Bool
    /** 数字锁定状态。 */
    public let numLock: Bool

    /** 创建修饰键状态。
     * @param shift Shift 状态
     * @param alt Alt 状态
     * @param ctrl Ctrl 状态
     * @param superKey Super 状态
     * @param meta Meta 状态
     * @param hyper Hyper 状态
     * @param capsLock 大写锁定状态
     * @param numLock 数字锁定状态
     */
    public init(
        shift!: Bool = false,
        alt!: Bool = false,
        ctrl!: Bool = false,
        superKey!: Bool = false,
        meta!: Bool = false,
        hyper!: Bool = false,
        capsLock!: Bool = false,
        numLock!: Bool = false
    ) {
        this.shift = shift
        this.alt = alt
        this.ctrl = ctrl
        this.superKey = superKey
        this.meta = meta
        this.hyper = hyper
        this.capsLock = capsLock
        this.numLock = numLock
    }

    /** 创建所有修饰键均关闭的状态。
     * @return 无修饰状态
     */
    public static func none(): KeyModifier {
        KeyModifier()
    }

    /** 解码 CSI 修饰参数；值先按至少 1 处理，扩展位可表示更多修饰与锁定状态。
     * @param value CSI 修饰参数
     * @return 解码后的状态
     */
    public static func fromCsiParam(value: Int64): KeyModifier {
        let encoded = max(1, value) - 1
        if (encoded > 7) {
            return KeyModifier(
                shift: (encoded & 1) != 0,
                alt: (encoded & 2) != 0,
                ctrl: (encoded & 4) != 0,
                superKey: (encoded & 8) != 0,
                hyper: (encoded & 16) != 0,
                meta: (encoded & 32) != 0,
                capsLock: (encoded & 64) != 0,
                numLock: (encoded & 128) != 0
            )
        }
        match (value) {
            case 2 => KeyModifier(shift: true)
            case 3 => KeyModifier(alt: true)
            case 4 => KeyModifier(shift: true, alt: true)
            case 5 => KeyModifier(ctrl: true)
            case 6 => KeyModifier(shift: true, ctrl: true)
            case 7 => KeyModifier(alt: true, ctrl: true)
            case 8 => KeyModifier(shift: true, alt: true, ctrl: true)
            case _ => KeyModifier()
        }
    }

    /** 比较所有修饰与锁定状态。
     * @param other 待比较状态
     * @return 状态相同时为 true
     */
    public operator func ==(other: KeyModifier): Bool {
        shift == other.shift &&
            alt == other.alt &&
            ctrl == other.ctrl &&
            superKey == other.superKey &&
            meta == other.meta &&
            hyper == other.hyper &&
            capsLock == other.capsLock &&
            numLock == other.numLock
    }

    /** 比较所有修饰与锁定状态。
     * @param other 待比较状态
     * @return 状态不同时为 true
     */
    public operator func !=(other: KeyModifier): Bool {
        !(this == other)
    }
}

/** 键盘事件的按键、修饰键、文本与协议元数据。 */
public struct KeyEvent {
    /** 按键代码。 */
    public let code: KeyCode
    /** 修饰键状态。 */
    public let modifiers: KeyModifier
    /** 可选的输入文本。 */
    public let text: ?String
    /** 键盘协议。 */
    public let protocol: KeyProtocol
    /** 是否由原生输入标记为重复。 */
    public let nativeRepeat: Bool

    /** 创建键盘事件。
     * @param code 按键代码
     * @param modifiers 修饰键状态
     * @param text 可选输入文本
     * @param protocol 键盘协议
     * @param nativeRepeat 是否为原生重复事件
     */
    public init(
        code: KeyCode,
        modifiers!: KeyModifier = KeyModifier.none(),
        text!: ?String = None,
        protocol!: KeyProtocol = KeyProtocol.Basic,
        nativeRepeat!: Bool = false
    ) {
        this.code = code
        this.modifiers = modifiers
        this.text = text
        this.protocol = protocol
        this.nativeRepeat = nativeRepeat
    }
}

/** 鼠标事件关联的按键或滚轮方向。 */
public enum MouseButton {
    /** 左键。 */
    | Left
    /** 中键。 */
    | Middle
    /** 右键。 */
    | Right
    /** 滚轮向上。 */
    | WheelUp
    /** 滚轮向下。 */
    | WheelDown
    /** 没有关联按键。 */
    | None
}

/** 鼠标事件类型。 */
public enum MouseKind {
    /** 按下。 */
    | Down
    /** 释放。 */
    | Up
    /** 拖动。 */
    | Drag
    /** 移动。 */
    | Move
    /** 滚动。 */
    | Scroll
}

/** 包含位置、按键和修饰键状态的鼠标事件。 */
public struct MouseEvent {
    /** 事件类型。 */
    public let kind: MouseKind
    /** 关联按键或滚轮方向。 */
    public let button: MouseButton
    /** 终端单元格横坐标。 */
    public let x: Int64
    /** 终端单元格纵坐标。 */
    public let y: Int64
    /** 修饰键状态。 */
    public let modifiers: KeyModifier
    /** 创建鼠标事件。
     * @param kind 事件类型
     * @param button 关联按键或滚轮方向
     * @param x 横坐标
     * @param y 纵坐标
     * @param modifiers 修饰键状态
     */
    public init(kind: MouseKind, button: MouseButton, x: Int64, y: Int64, modifiers!: KeyModifier = KeyModifier.none()) {
        this.kind = kind
        this.button = button
        this.x = x
        this.y = y
        this.modifiers = modifiers
    }
}

/** 描述一帧的时间与丢帧信息；数值在构造时限制为非负。 */
public struct TickEvent {
    /** 距上一帧的毫秒数。 */
    public let deltaMillis: Int64
    /** 累计经过的毫秒数。 */
    public let elapsedMillis: Int64
    /** 帧序号。 */
    public let frameIndex: Int64
    /** 丢弃的帧数。 */
    public let droppedFrames: Int64

    /** 创建帧时间事件。
    * @param deltaMillis 帧间隔毫秒数，负值按零处理
    * @param elapsedMillis 累计毫秒数，负值按零处理
    * @param frameIndex 帧序号，负值按零处理
    * @param droppedFrames 丢帧数，负值按零处理
     */
    public init(deltaMillis!: Int64 = 0, elapsedMillis!: Int64 = 0, frameIndex!: Int64 = 0, droppedFrames!: Int64 = 0) {
        this.deltaMillis = max(0, deltaMillis)
        this.elapsedMillis = max(0, elapsedMillis)
        this.frameIndex = max(0, frameIndex)
        this.droppedFrames = max(0, droppedFrames)
    }
}

/** 定时器的触发方式。 */
public enum TimerMode {
    /** 触发一次。 */
    | OneShot
    /** 重复触发。 */
    | Repeating
}

/** 处理未及时执行的帧或定时任务的策略。 */
public enum FrameMissPolicy {
    /** 丢弃错过的触发。 */
    | Drop
    /** 补执行错过的触发。
    * @param _0 补执行次数的上限
     */
    | CatchUp(Int64)
}

/** 描述一次定时器触发。 */
public struct TimerEvent {
    /** 定时器标识。 */
    public let id: String
    /** 累计经过的毫秒数。 */
    public let elapsedMillis: Int64
    /** 触发次数，至少为一。 */
    public let firedCount: Int64
    /** 丢弃的帧数。 */
    public let droppedFrames: Int64

    /** 创建定时器事件。
    * @param id 定时器标识
    * @param elapsedMillis 累计毫秒数，负值按零处理
    * @param firedCount 触发次数，小于一时按一处理
    * @param droppedFrames 丢帧数，负值按零处理
     */
    public init(id: String, elapsedMillis!: Int64 = 0, firedCount!: Int64 = 1, droppedFrames!: Int64 = 0) {
        this.id = id
        this.elapsedMillis = max(0, elapsedMillis)
        this.firedCount = max(1, firedCount)
        this.droppedFrames = max(0, droppedFrames)
    }
}

/** 定时器任务的调度优先级。 */
public enum TimerPriority {
    /** 立即执行。 */
    | Immediate
    /** 普通优先级。 */
    | Normal
    /** 低优先级。 */
    | Low
}

public enum Event {
    | KeyDown(KeyEvent)
    | KeyUp(KeyEvent)
    | KeyRepeat(KeyEvent)
    | KeyHeld(KeyEvent)
    | Mouse(MouseEvent)
    | FocusIn
    | FocusOut
    | Capabilities(TerminalCapabilities)
    | Paste(String)
    | Message(String)
    | ExecResult(String, Int64, String)
    | TextCompletion(String, TextCompletionResult)
    | ProcessStarted(String)
    | ProcessOutput(String, ProcessOutputStream, Array<Byte>)
    | ProcessFinished(String, ProcessResult)
    | ProcessFailed(String, String)
    | ProcessCancelRequested(String)
    | PtyStarted(String)
    | PtyOutput(String, PtyOutputStream, Array<Byte>)
    | PtyExited(String, PtyExitStatus)
    | PtyFailed(String, String)
    | AsyncStarted(String)
    | AsyncCompleted(String, Event)
    | AsyncFailed(String, String)
    | AsyncCancelled(String)
    | DataReady(String, Int64)
    | DataFailed(String, Int64, String)
    | DataCancelled(String, Int64)
    | Tick(TickEvent)
    | Timer(TimerEvent)
    | Resize(Rect)
    | Unknown(Array<Byte>)
}

/** 保存按下的按键及持续时间。 */
public struct PressedKey {
    /** 按键事件。 */
    public let key: KeyEvent
    /** 持续按下的毫秒数。 */
    public let heldMillis: Int64

    /** 创建按键状态快照。
    * @param key 按键事件
    * @param heldMillis 持续毫秒数，负值按零处理
     */
    public init(key: KeyEvent, heldMillis!: Int64 = 0) {
        this.key = key
        this.heldMillis = max(0, heldMillis)
    }
}

class InputKeyState {
    var key: KeyEvent
    var heldMillis: Int64 = 0
    var sinceLastEventMillis: Int64 = 0

    init(key: KeyEvent) {
        this.key = key
    }
}

/** 跟踪按键、修饰键和按住时间。超时的按键会被移除。 */
public class InputState {
    private let keys = ArrayList<InputKeyState>()
    private var mods: KeyModifier = KeyModifier.none()
    private let releaseAfterMillis: Int64

    /** 创建输入状态。
    * @param releaseAfterMillis 没有新按键事件时的释放超时，至少为一毫秒
     */
    public init(releaseAfterMillis!: Int64 = 180) {
        this.releaseAfterMillis = max(1, releaseAfterMillis)
    }

    /** 更新按键状态；重复按键额外产生按住事件。失焦时清空状态。
    * @param event 输入事件
    * @return 额外产生的事件
     */
    public func handle(event: Event): Array<Event> {
        let generated = ArrayList<Event>()
        match (event) {
            case Event.KeyDown(key) => press(key)
            case Event.KeyRepeat(key) =>
                press(key)
                generated.add(Event.KeyHeld(key))
            case Event.KeyHeld(key) => press(key)
            case Event.KeyUp(key) => release(key)
            case Event.FocusOut => clear()
            case _ => ()
        }
        generated.toArray()
    }

    /** 推进按住时间并移除超时按键。
    * @param deltaMillis 增加的毫秒数，负值按零处理
    * @return 仍按住的按键事件
     */
    public func advance(deltaMillis: Int64): Array<Event> {
        let generated = ArrayList<Event>()
        var i: Int64 = 0
        while (i < keys.size) {
            keys[i].heldMillis += max(0, deltaMillis)
            keys[i].sinceLastEventMillis += max(0, deltaMillis)
            if (keys[i].sinceLastEventMillis >= releaseAfterMillis) {
                keys.remove(at: i)
                continue
            }
            generated.add(Event.KeyHeld(keys[i].key))
            i++
        }
        refreshModifiers()
        generated.toArray()
    }

    /** 查询按键是否处于按下状态。
    * @param key 要查询的按键
    * @return 按下时为 true
     */
    public func isPressed(key: KeyEvent): Bool {
        find(key) >= 0
    }

    /** 获取当前按键状态快照。
    * @return 按下的按键及持续时间
     */
    public func pressedKeys(): Array<PressedKey> {
        let out = ArrayList<PressedKey>()
        for (state in keys) {
            out.add(PressedKey(state.key, heldMillis: state.heldMillis))
        }
        out.toArray()
    }

    /** 获取当前按下按键的修饰键集合。
    * @return 合并后的修饰键
     */
    public func modifiers(): KeyModifier {
        mods
    }

    /** 清空按键和修饰键状态。 */
    public func clear(): Unit {
        while (keys.size > 0) { keys.remove(at: 0) }
        mods = KeyModifier.none()
    }

    private func press(key: KeyEvent): Unit {
        let index = find(key)
        if (index >= 0) {
            keys[index].key = key
            keys[index].sinceLastEventMillis = 0
        } else {
            keys.add(InputKeyState(key))
        }
        refreshModifiers()
    }

    private func release(key: KeyEvent): Unit {
        let index = find(key)
        if (index >= 0) {
            keys.remove(at: index)
        }
        refreshModifiers()
    }

    private func find(key: KeyEvent): Int64 {
        let id = keyIdentity(key)
        for (i in 0..keys.size) {
            if (keyIdentity(keys[i].key) == id) { return i }
        }
        -1
    }

    private func refreshModifiers(): Unit {
        var shift = false
        var alt = false
        var ctrl = false
        var superKey = false
        var meta = false
        var hyper = false
        var capsLock = false
        var numLock = false
        for (state in keys) {
            shift = shift || state.key.modifiers.shift
            alt = alt || state.key.modifiers.alt
            ctrl = ctrl || state.key.modifiers.ctrl
            superKey = superKey || state.key.modifiers.superKey
            meta = meta || state.key.modifiers.meta
            hyper = hyper || state.key.modifiers.hyper
            capsLock = capsLock || state.key.modifiers.capsLock
            numLock = numLock || state.key.modifiers.numLock
        }
        mods = KeyModifier(shift: shift, alt: alt, ctrl: ctrl, superKey: superKey, meta: meta, hyper: hyper, capsLock: capsLock, numLock: numLock)
    }
}

/** 增量解析输入字节为终端事件。 */
public class EventParser {
    private let inputSource: InputSource
    private var pending = ArrayList<Byte>()
    private var ready = ArrayList<Event>()
    private var lastReadByteCount: Int64 = 0
    private var pendingEscPolls: Int64 = 0
    private var inputDrainPending = false

    /** 创建解析器；可注入输入源以便测试。
    * @param inputSource 提供输入字节的来源
     */
    public init(inputSource!: InputSource = StdinInputSource()) {
        this.inputSource = inputSource
    }

    /** 追加字节并解析完整事件；不完整序列保留到下次输入。
    * @param bytes 输入字节
    * @return 当前解析出的事件
     */
    public func push(bytes: Array<Byte>): Array<Event> {
        for (b in bytes) {
            pending.add(b)
        }
        if (bytes.size > 0) {
            pendingEscPolls = 0
        }
        let events = parseAvailable()
        for (event in events) {
            ready.add(event)
        }
        drainReady()
    }

    /** 从输入源读取并解析当前可用事件；一次最多读取 65536 字节。
    * @return 当前解析出的事件
     */
    public func readEvents(): Array<Event> {
        // SGR mouse reports are commonly around ten bytes each.  Reading
        // only 64 bytes leaves a fast wheel gesture queued across many app
        // frames, so a later direction reversal appears seconds late.
        // Drain a normal terminal input burst in one pass; parsing remains
        // incremental when a paste or escape sequence exceeds this window.
        var drained: Int64 = 0
        inputDrainPending = false
        while (drained < 65536) {
            let bytes = inputSource.readAvailable(min(4096, 65536 - drained))
            if (bytes.isEmpty()) {
                break
            }
            drained += bytes.size
            for (event in parseBytes(bytes)) {
                ready.add(event)
            }
            pendingEscPolls = 0
            if (drained >= 65536) {
                // A bounded drain keeps input floods fair to timers and PTYs.
                // The App must immediately continue parsing rather than wait
                // for a new EPOLLET edge while stdin may still be readable.
                inputDrainPending = true
            }
        }
        lastReadByteCount = drained
        drainReady()
    }

    /** 读取一个事件；其余事件保留供后续读取。
    * @return 下一个事件，无事件时为 None
     */
    public func readEvent(): ?Event {
        if (ready.size == 0) {
            let events = readEvents()
            for (event in events) {
                ready.add(event)
            }
        }
        if (ready.size > 0) {
            let event = ready[0]
            ready.remove(at: 0)
            return Some(event)
        }
        None
    }

    /** 获取上次读取的字节数。
    * @return 上次读取的字节数
     */
    public func lastReadBytes(): Int64 {
        lastReadByteCount
    }

    /** 判断上次读取是否达到单次读取上限。
    * @return 达到上限时为 true
     */
    public func hasPendingInputDrain(): Bool {
        inputDrainPending
    }

    func pendingEsc(): Bool {
        pending.size == 1 && pending[0] == 0x1B
    }

    /** 将单独等待中的 ESC 字节解析为 Escape 按键。
    * @return 当前可交付的事件
     */
    public func flushEsc(): Array<Event> {
        if (pending.size == 1 && pending[0] == 0x1B) {
            pending.remove(at: 0)
            pendingEscPolls = 0
            ready.add(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        }
        drainReady()
    }

    /** 多次轮询后将等待中的单独 ESC 解析为按键。
    * @param polls 触发解析所需的轮询次数，至少为一
    * @return 当前可交付的事件
     */
    public func flushEscAfterPolls(polls: Int64): Array<Event> {
        if (pending.size == 1 && pending[0] == 0x1B) {
            pendingEscPolls++
            if (pendingEscPolls >= max(1, polls)) {
                return flushEsc()
            }
        } else {
            pendingEscPolls = 0
        }
        drainReady()
    }

    private func parseBytes(bytes: Array<Byte>): Array<Event> {
        for (b in bytes) {
            pending.add(b)
        }
        parseAvailable()
    }

    private func parseAvailable(): Array<Event> {
        let events = ArrayList<Event>()
        while (pending.size > 0) {
            if (pending[0] == 0x09) {
                drop(1)
                events.add(Event.KeyDown(KeyEvent(KeyCode.Tab)))
            } else if (pending[0] == 0x0D || pending[0] == 0x0A) {
                drop(1)
                events.add(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            } else if (pending[0] == 0x7F || pending[0] == 0x08) {
                drop(1)
                events.add(Event.KeyDown(KeyEvent(KeyCode.Backspace)))
            } else if (pending[0] > 0 && pending[0] <= 0x1A) {
                let code = ctrlKeyCode(pending[0])
                drop(1)
                events.add(Event.KeyDown(KeyEvent(code, modifiers: ctrlKeyModifier(code))))
            } else if (pending[0] == 0x1B) {
                if (!parseEscape(events)) { break }
            } else {
                let data = pending.toArray()
                let expected = utf8ExpectedLength(pending[0])
                if (expected < 0) {
                    events.add(Event.Unknown(data[..1]))
                    drop(1)
                } else if (pending.size < expected) {
                    break
                } else {
                    try {
                        let (r, len) = Rune.fromUtf8(data, 0)
                        drop(len)
                        events.add(Event.KeyDown(KeyEvent(KeyCode.Char(r))))
                    } catch (_) {
                        events.add(Event.Unknown(data[..1]))
                        drop(1)
                    }
                }
            }
        }
        events.toArray()
    }

    private func parseEscape(events: ArrayList<Event>): Bool {
        if (pending.size == 1) {
            return false
        }
        if (pending.size == 2 && (pending[1] == b'[' || pending[1] == b'O')) {
            return false
        }
        if (pending.size >= 3 && pending[1] == b'[') {
            if (startsWith("\u{1B}[200~")) {
                return parseBracketedPaste(events)
            }
            if (pending[2] == b'<') {
                return parseSgrMouse(events)
            }
            if (pending[2] == b'Z') {
                return dropKey(events, KeyCode.BackTab, 3)
            }
            if (pending[2] == b'I') {
                drop(3)
                events.add(Event.FocusIn)
                return true
            }
            if (pending[2] == b'O') {
                drop(3)
                events.add(Event.FocusOut)
                return true
            }
            return parseCsiKey(events)
        } else if (pending.size >= 3 && pending[1] == b'O') {
            match (pending[2]) {
                case b'A' => dropKey(events, KeyCode.Up, 3)
                case b'B' => dropKey(events, KeyCode.Down, 3)
                case b'C' => dropKey(events, KeyCode.Right, 3)
                case b'D' => dropKey(events, KeyCode.Left, 3)
                case b'H' => dropKey(events, KeyCode.Home, 3)
                case b'F' => dropKey(events, KeyCode.End, 3)
                case b'P' => dropKey(events, KeyCode.F(1), 3)
                case b'Q' => dropKey(events, KeyCode.F(2), 3)
                case b'R' => dropKey(events, KeyCode.F(3), 3)
                case b'S' => dropKey(events, KeyCode.F(4), 3)
                case _ => emitEsc(events)
            }
        } else {
            return parseAltKey(events)
        }
    }

    private func parseCsiKey(events: ArrayList<Event>): Bool {
        let end = findCsiEnd()
        if (end < 0) { return false }
        let data = pending.toArray()
        let body = unsafe { String.fromUtf8Unchecked(data[2..end]) }
        if (pending[end] == b'u') {
            return parseKittyKey(events, body, end)
        }
        var parts = splitInts(body)
        var eventType: Int64 = 1
        var enhanced = false
        if (body.contains(":")) {
            let fields = kittyParameters(body)
            if (fields.size != 2 || fields[0].size != 1 || fields[1].size != 2) {
                return dropUnknown(events, end + 1)
            }
            parts = [fields[0][0], fields[1][0]]
            eventType = max(1, fields[1][1])
            if (eventType > 3) { return dropUnknown(events, end + 1) }
            enhanced = true
        }
        if (!body.isEmpty() && parts.size == 0) { return dropUnknown(events, end + 1) }
        if (pending[end] == b'~' && parts.size >= 3 && parts[0] == 27) {
            let modifiers = KeyModifier.fromCsiParam(parts[1])
            let code = match (keyCodeFromUnicode(parts[2])) {
                case Some(value) => value
                case None => return dropUnknown(events, end + 1)
            }
            drop(end + 1)
            events.add(Event.KeyDown(KeyEvent(code, modifiers: modifiers, protocol: KeyProtocol.ModifyOtherKeys)))
            return true
        }
        let modifiers = if (parts.size >= 2) {
            KeyModifier.fromCsiParam(parts[parts.size - 1])
        } else {
            KeyModifier.none()
        }
        let code: ?KeyCode = match (pending[end]) {
            case b'A' => Some(KeyCode.Up)
            case b'B' => Some(KeyCode.Down)
            case b'C' => Some(KeyCode.Right)
            case b'D' => Some(KeyCode.Left)
            case b'H' => Some(KeyCode.Home)
            case b'F' => Some(KeyCode.End)
            case b'P' => Some(KeyCode.F(1))
            case b'Q' => Some(KeyCode.F(2))
            case b'S' => Some(KeyCode.F(4))
            case b'~' =>
                if (parts.size == 0) { None } else {
                    match (parts[0]) {
                        case 1 => Some(KeyCode.Home)
                        case 2 => Some(KeyCode.Insert)
                        case 3 => Some(KeyCode.Delete)
                        case 4 => Some(KeyCode.End)
                        case 5 => Some(KeyCode.PageUp)
                        case 6 => Some(KeyCode.PageDown)
                        case 7 => Some(KeyCode.Home)
                        case 8 => Some(KeyCode.End)
                        case 11 => Some(KeyCode.F(1))
                        case 12 => Some(KeyCode.F(2))
                        case 13 => Some(KeyCode.F(3))
                        case 14 => Some(KeyCode.F(4))
                        case 15 => Some(KeyCode.F(5))
                        case 17 => Some(KeyCode.F(6))
                        case 18 => Some(KeyCode.F(7))
                        case 19 => Some(KeyCode.F(8))
                        case 20 => Some(KeyCode.F(9))
                        case 21 => Some(KeyCode.F(10))
                        case 23 => Some(KeyCode.F(11))
                        case 24 => Some(KeyCode.F(12))
                        case _ => None
                    }
                }
            case _ => None
        }
        match (code) {
            case Some(k) =>
                drop(end + 1)
                let key = KeyEvent(k, modifiers: modifiers,
                    protocol: if (enhanced) { KeyProtocol.Kitty } else { KeyProtocol.Basic },
                    nativeRepeat: eventType == 2)
                addKeyEvent(events, key, eventType)
                true
            case None => if (enhanced) { dropUnknown(events, end + 1) } else { emitEsc(events) }
        }
    }

    private func parseKittyKey(events: ArrayList<Event>, body: String, end: Int64): Bool {
        let fields = kittyParameters(body)
        if (fields.size == 0 || fields.size > 3 || fields[0].size > 3 ||
            (fields.size > 1 && fields[1].size > 2)) { return dropUnknown(events, end + 1) }
        let modifierValue = if (fields.size > 1) { max(1, fields[1][0]) } else { 1 }
        let modifiers = KeyModifier.fromCsiParam(modifierValue)
        let eventType = if (fields.size > 1 && fields[1].size > 1) { max(1, fields[1][1]) } else { 1 }
        if (eventType > 3) { return dropUnknown(events, end + 1) }
        for (value in fields[0]) {
            if (!isUnicodeScalar(value)) { return dropUnknown(events, end + 1) }
        }
        let code = match (keyCodeFromUnicode(fields[0][0])) {
            case Some(value) => value
            case None => return dropUnknown(events, end + 1)
        }
        var text: ?String = match (code) {
            case KeyCode.Char(r) => Some(r.toString())
            case _ => None
        }
        if (fields.size > 2) {
            var associated = ""
            for (value in fields[2]) {
                if (!isUnicodeScalar(value) || value < 32 || (value >= 127 && value < 160)) {
                    return dropUnknown(events, end + 1)
                }
                associated += Rune(UInt32(value)).toString()
            }
            text = Some(associated)
        }
        let key = KeyEvent(code, modifiers: modifiers, text: text, protocol: KeyProtocol.Kitty, nativeRepeat: eventType == 2)
        drop(end + 1)
        addKeyEvent(events, key, eventType)
        true
    }

    private func addKeyEvent(events: ArrayList<Event>, key: KeyEvent, eventType: Int64): Unit {
        match (eventType) {
            case 2 => events.add(Event.KeyRepeat(key))
            case 3 => events.add(Event.KeyUp(key))
            case _ => events.add(Event.KeyDown(key))
        }
    }

    private func dropUnknown(events: ArrayList<Event>, count: Int64): Bool {
        events.add(Event.Unknown(pending.toArray()[..count]))
        drop(count)
        true
    }

    private func emitEsc(events: ArrayList<Event>): Bool {
        drop(1)
        events.add(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        true
    }

    private func parseAltKey(events: ArrayList<Event>): Bool {
        if (pending.size < 2) { return false }
        if (pending[1] > 0 && pending[1] <= 0x1A) {
            let code = ctrlKeyCode(pending[1])
            drop(2)
            events.add(Event.KeyDown(KeyEvent(code, modifiers: altCtrlKeyModifier(code))))
            return true
        }
        let data = pending.toArray()
        let expected = utf8ExpectedLength(pending[1])
        if (expected > 0 && pending.size >= expected + 1) {
            try {
                let (r, len) = Rune.fromUtf8(data, 1)
                drop(len + 1)
                events.add(Event.KeyDown(KeyEvent(KeyCode.Char(r), modifiers: KeyModifier(alt: true))))
                return true
            } catch (_) {
                events.add(Event.Unknown(data[..2]))
                drop(2)
                return true
            }
        }
        if (expected < 0) {
            events.add(Event.Unknown(data[..2]))
            drop(2)
            return true
        }
        false
    }

    private func parseBracketedPaste(events: ArrayList<Event>): Bool {
        if (!startsWith("\u{1B}[200~")) { return false }
        let end = indexOf("\u{1B}[201~", 6)
        if (end < 0) { return false }
        let data = pending.toArray()
        drop(end + 6)
        try {
            let bytes = data[6..end]
            var offset: Int64 = 0
            while (offset < bytes.size) {
                let (_, length) = Rune.fromUtf8(bytes, offset)
                offset += length
            }
            events.add(Event.Paste(unsafe { String.fromUtf8Unchecked(bytes) }))
        } catch (_) {
            events.add(Event.Unknown(data[..end + 6]))
        }
        true
    }

    private func parseSgrMouse(events: ArrayList<Event>): Bool {
        let end = findMouseEnd()
        if (end < 0) { return false }
        let data = pending.toArray()
        let seq = unsafe { String.fromUtf8Unchecked(data[3..end]) }
        let release = pending[end] == b'm'
        let parts = splitInts(seq)
        if (parts.size == 3) {
            events.add(Event.Mouse(mouseFrom(parts[0], parts[1] - 1, parts[2] - 1, release)))
        } else {
            events.add(Event.Unknown(data[..end + 1]))
        }
        drop(end + 1)
        true
    }

    private func dropKey(events: ArrayList<Event>, code: KeyCode, n: Int64): Bool {
        drop(n)
        events.add(Event.KeyDown(KeyEvent(code)))
        true
    }

    private func findCsiEnd(): Int64 {
        for (i in 2..pending.size) {
            let b = pending[i]
            if ((b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z') || b == b'~') {
                return i
            }
        }
        -1
    }

    private func drop(n: Int64): Unit {
        let count = min(max(0, n), pending.size)
        if (count == 0) { return }
        if (count == pending.size) {
            pending = ArrayList<Byte>()
            return
        }
        let remaining = pending.toArray()[count..]
        pending = ArrayList<Byte>()
        for (byte in remaining) {
            pending.add(byte)
        }
    }

    private func startsWith(prefix: String): Bool {
        let bytes = unsafe { prefix.rawData() }
        if (pending.size < bytes.size) { return false }
        for (i in 0..bytes.size) {
            if (pending[i] != bytes[i]) { return false }
        }
        true
    }

    private func indexOf(needle: String, start: Int64): Int64 {
        let bytes = unsafe { needle.rawData() }
        var i = start
        while (i + bytes.size <= pending.size) {
            var ok = true
            for (j in 0..bytes.size) {
                if (pending[i + j] != bytes[j]) {
                    ok = false
                }
            }
            if (ok) { return i }
            i++
        }
        -1
    }

    private func findMouseEnd(): Int64 {
        for (i in 3..pending.size) {
            if (pending[i] == b'M' || pending[i] == b'm') {
                return i
            }
        }
        -1
    }

    private func drainReady(): Array<Event> {
        let events = ready.toArray()
        ready = ArrayList<Event>()
        events
    }
}

func utf8ExpectedLength(first: Byte): Int64 {
    if (first < 0x80) { return 1 }
    if (first >= 0xC2 && first <= 0xDF) { return 2 }
    if (first >= 0xE0 && first <= 0xEF) { return 3 }
    if (first >= 0xF0 && first <= 0xF4) { return 4 }
    -1
}

func ctrlKeyCode(value: Byte): KeyCode {
    if (value == 0x03) {
        return KeyCode.CtrlC
    }
    KeyCode.Char(Rune(UInt32(b'a' + value - 1)))
}

func ctrlKeyModifier(code: KeyCode): KeyModifier {
    match (code) {
        case KeyCode.CtrlC => KeyModifier.none()
        case _ => KeyModifier(ctrl: true)
    }
}

func altCtrlKeyModifier(code: KeyCode): KeyModifier {
    match (code) {
        case KeyCode.CtrlC => KeyModifier(alt: true)
        case _ => KeyModifier(alt: true, ctrl: true)
    }
}

func isUnicodeScalar(value: Int64): Bool {
    value >= 0 && value <= 0x10FFFF && (value < 0xD800 || value > 0xDFFF)
}

// CSI u separates main fields with semicolons and their subfields with
// colons. Empty optional numbers retain their position and use zero/default.
func kittyParameters(text: String): Array<Array<Int64>> {
    if (text.isEmpty()) { return [] }
    let fields = ArrayList<Array<Int64>>()
    var values = ArrayList<Int64>()
    var current: Int64 = 0
    for (byte in unsafe { text.rawData() }) {
        if (byte >= b'0' && byte <= b'9') {
            let digit = Int64(byte - b'0')
            if (current > (Int64.Max - digit) / 10) { return [] }
            current = current * 10 + digit
        } else if (byte == b':' || byte == b';') {
            values.add(current)
            current = 0
            if (byte == b';') {
                fields.add(values.toArray())
                values = ArrayList<Int64>()
            }
        } else {
            return []
        }
    }
    values.add(current)
    fields.add(values.toArray())
    fields.toArray()
}

func keyCodeFromUnicode(value: Int64): ?KeyCode {
    if (!isUnicodeScalar(value)) { return None }
    match (value) {
        case 9 => Some(KeyCode.Tab)
        case 13 => Some(KeyCode.Enter)
        case 27 => Some(KeyCode.Esc)
        case 127 => Some(KeyCode.Backspace)
        case _ =>
            if (value >= 57376 && value <= 57398) {
                Some(KeyCode.F(value - 57363))
            } else if (value >= 57344 && value <= 63743) {
                // Reserved functional keys without a KeyCode variant must
                // not become text or an unrelated editing key.
                None
            } else {
                Some(KeyCode.Char(Rune(UInt32(value))))
            }
    }
}

func keyIdentity(key: KeyEvent): String {
    let code = match (key.code) {
        case KeyCode.Char(r) => "char:" + r.toString()
        case KeyCode.CtrlC => "ctrl-c"
        case KeyCode.Esc => "esc"
        case KeyCode.Tab => "tab"
        case KeyCode.BackTab => "backtab"
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
        case KeyCode.PageUp => "pageup"
        case KeyCode.PageDown => "pagedown"
        case KeyCode.F(n) => "f:${n}"
    }
    code
}

func mouseFrom(code: Int64, x: Int64, y: Int64, release: Bool): MouseEvent {
    let button = match (code & 0x43) {
        case 0 => MouseButton.Left
        case 1 => MouseButton.Middle
        case 2 => MouseButton.Right
        case 64 => MouseButton.WheelUp
        case 65 => MouseButton.WheelDown
        case _ => MouseButton.None
    }
    let kind = if (code >= 64) {
        MouseKind.Scroll
    } else if (release) {
        MouseKind.Up
    } else if ((code & 35) == 35) {
        MouseKind.Move
    } else if ((code & 32) != 0) {
        MouseKind.Drag
    } else {
        MouseKind.Down
    }
    MouseEvent(kind, button, x, y, modifiers: KeyModifier(
        shift: (code & 4) != 0,
        alt: (code & 8) != 0,
        ctrl: (code & 16) != 0
    ))
}
