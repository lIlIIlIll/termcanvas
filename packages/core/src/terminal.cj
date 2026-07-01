package core

import std.collection.*
import std.env.*
import std.io.*
import std.time.*

const STDIN_FILENO: Int32 = 0
const STDOUT_FILENO: Int32 = 1
const TCSAFLUSH: Int32 = 2
const TIOCGWINSZ: UInt64 = 0x5413
const TUI_SIGHUP: Int32 = 1
const TUI_SIGINT: Int32 = 2
const TUI_SIGQUIT: Int32 = 3
const TUI_SIGTERM: Int32 = 15

const TERMIOS_SIZE: Int64 = 60
const TERMIOS_CC_OFFSET: Int64 = 17
const VTIME: Int64 = 5
const VMIN: Int64 = 6

const BRKINT: UInt32 = 0x0002u32
const ICRNL: UInt32 = 0x0100u32
const INPCK: UInt32 = 0x0010u32
const ISTRIP: UInt32 = 0x0020u32
const IXON: UInt32 = 0x0400u32
const OPOST: UInt32 = 0x0001u32
const CS8: UInt32 = 0x0030u32
const ECHO: UInt32 = 0x0008u32
const ICANON: UInt32 = 0x0002u32
const IEXTEN: UInt32 = 0x8000u32
const ISIG: UInt32 = 0x0001u32

@FastNative
foreign func tcgetattr(fd: Int32, termios: CPointer<Unit>): Int32

@FastNative
foreign func tcsetattr(fd: Int32, optionalActions: Int32, termios: CPointer<Unit>): Int32

@FastNative
foreign func ioctl(fd: Int32, request: UInt64, argp: CPointer<Unit>): Int32

@FastNative
foreign func isatty(fd: Int32): Int32

@FastNative
foreign func signal(signum: Int32, handler: CFunc<(Int32) -> Unit>): CFunc<(Int32) -> Unit>

@FastNative
foreign func _exit(status: Int32): Unit

public interface Backend {
    func clear(): Unit
    func moveTo(x: Int64, y: Int64): Unit
    func enterAlternateScreen(): Unit
    func leaveAlternateScreen(): Unit
    func hideCursor(): Unit
    func showCursor(): Unit
    func enableMouse(): Unit
    func disableMouse(): Unit
    func enableBracketedPaste(): Unit
    func disableBracketedPaste(): Unit
    func size(): Rect
    func draw(buffer: Buffer): Unit
    func drawDiff(next: Buffer, plan: RenderDiffPlan): Unit
    func drawMedia(ops: Array<MediaOp>): Unit
    func write(text: String): Unit
    func flush(): Unit
}

public struct RenderDiffSpan {
    public let x: Int64
    public let y: Int64
    public let text: String
    public let style: Style

    public init(x: Int64, y: Int64, text: String, style: Style) {
        this.x = x
        this.y = y
        this.text = text
        this.style = style
    }
}

public struct RenderDiffPlan {
    public let dirtyCells: Int64
    public let spans: Array<RenderDiffSpan>

    public init(dirtyCells: Int64, spans: Array<RenderDiffSpan>) {
        this.dirtyCells = max(0, dirtyCells)
        this.spans = spans
    }
}

public class Frame {
    public let area: Rect
    private let buffer: Buffer
    private var cursor: ?Position = None

    public init(area: Rect, buffer: Buffer) {
        this.area = area
        this.buffer = buffer
    }

    public func renderWidget(widget: Widget, area: Rect): Unit {
        widget.render(area, buffer)
    }

    public func canvas(area!: Rect = this.area): Canvas {
        Canvas(buffer, area)
    }

    public func renderNode(node: ViewNode, sheet: StyleSheet): Unit {
        node.setArea(area)
        node.render(this, sheet)
    }

    public func fill(area: Rect, style: Style): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        for (y in area.y..area.bottom) {
            buffer.setString(area.x, y, repeat(" ", area.width), style: style)
        }
    }

    public func addMedia(placement: MediaPlacement): Unit {
        buffer.addMedia(placement)
    }

    public func setCursor(position: Position): Unit {
        cursor = Some(position)
    }

    public func getCursor(): ?Position {
        cursor
    }
}

public enum RenderMode {
    | Diff
    | Full
}

public class Terminal {
    private let backend: Backend
    private let renderMode: RenderMode
    private var front: ?Buffer = None
    private var back: ?Buffer = None
    private var previousMedia: Array<MediaPlacement> = []

    public init(backend: Backend, renderMode!: RenderMode = RenderMode.Diff) {
        this.backend = backend
        this.renderMode = renderMode
    }

    public func draw(render: (Frame) -> Unit): RenderMetrics {
        let area = backend.size()
        if (!frontMatches(area)) {
            front = None
            back = None
        }
        let buffer = acquireBackBuffer(area)
        let frame = Frame(area, buffer)
        let renderStart = MonoTime.now()
        render(frame)
        let renderMillis = durationMillis(MonoTime.now() - renderStart)
        let drawStart = MonoTime.now()
        var dirtyCells = area.width * area.height
        var diffWrites: Int64 = if (area.height > 0) { area.height } else { 0 }
        var fullRedraw = true
        match (renderMode) {
            case RenderMode.Full =>
                backend.draw(buffer)
            case RenderMode.Diff =>
                match (front) {
                    case Some(prev) =>
                        let plan = renderDiffPlan(prev, buffer)
                        dirtyCells = plan.dirtyCells
                        diffWrites = plan.spans.size
                        fullRedraw = false
                        backend.drawDiff(buffer, plan)
                    case None => backend.draw(buffer)
                }
        }
        let media = buffer.mediaPlacements()
        let mediaOps = diffMediaPlacements(previousMedia, media)
        backend.drawMedia(mediaOps)
        if (let Some(cursor) <- frame.getCursor()) {
            backend.moveTo(cursor.x, cursor.y)
            backend.flush()
        }
        let drawMillis = durationMillis(MonoTime.now() - drawStart)
        let oldFront = front
        front = Some(buffer)
        back = oldFront
        previousMedia = media
        RenderMetrics(
            size: area,
            dirtyCells: dirtyCells,
            diffWrites: diffWrites,
            mediaOps: mediaOps.size,
            fullRedraw: fullRedraw,
            renderMillis: renderMillis,
            drawMillis: drawMillis,
            totalMillis: renderMillis + drawMillis
        )
    }

    public func clear(): Unit {
        backend.drawMedia(diffMediaPlacements(previousMedia, []))
        backend.clear()
        front = None
        back = None
        previousMedia = []
    }

    private func frontMatches(area: Rect): Bool {
        match (front) {
            case Some(buffer) => buffer.area == area
            case None => true
        }
    }

    private func acquireBackBuffer(area: Rect): Buffer {
        match (back) {
            case Some(buffer) =>
                if (buffer.area == area) {
                    buffer.reset()
                    buffer
                } else {
                    Buffer(area)
                }
            case None => Buffer(area)
        }
    }
}

func renderDiffPlan(previous: Buffer, next: Buffer): RenderDiffPlan {
    let spans = ArrayList<RenderDiffSpan>()
    var dirtyCells: Int64 = 0
    for (y in next.area.y..next.area.bottom) {
        var x = next.area.x
        while (x < next.area.right) {
            let cell = next.getCell(x, y)
            if (previous.area == next.area && previous.getCell(x, y) == cell) {
                x++
                continue
            }
            let start = x
            let style = cell.style
            let text = StringBuilder()
            text.append(cell.symbol)
            dirtyCells++
            x++
            while (x < next.area.right) {
                let nextCell = next.getCell(x, y)
                if (previous.area == next.area && previous.getCell(x, y) == nextCell) { break }
                if (nextCell.style != style) { break }
                text.append(nextCell.symbol)
                dirtyCells++
                x++
            }
            spans.add(RenderDiffSpan(start, y, text.toString(), style))
        }
    }
    RenderDiffPlan(dirtyCells, spans.toArray())
}

public enum KeyboardProtocolMode {
    | Basic
    | ModifyOtherKeys
    | Kitty
    | Auto
}

public enum TerminalProbeMode {
    | Disabled
    | EnvOnly
    | Active
}

public struct KeyboardOptions {
    public let mode: KeyboardProtocolMode
    public let probe: TerminalProbeMode
    public let escDelayMillis: Int64
    public let repeatHeldMillis: Int64

    public init(
        mode!: KeyboardProtocolMode = KeyboardProtocolMode.Basic,
        probe!: TerminalProbeMode = TerminalProbeMode.Disabled,
        escDelayMillis!: Int64 = 25,
        repeatHeldMillis!: Int64 = 120
    ) {
        this.mode = mode
        this.probe = probe
        this.escDelayMillis = max(0, escDelayMillis)
        this.repeatHeldMillis = max(1, repeatHeldMillis)
    }
}

public class TerminalSession {
    private let backend: Backend
    private let driver: TerminalDriver
    private let rawMode: Bool
    private let alternateScreen: Bool
    private let mouse: Bool
    private let mouseMove: Bool
    private let focusEvents: Bool
    private let bracketedPaste: Bool
    private let hideCursor: Bool
    private let keyboard: KeyboardOptions
    private var active: Bool = false
    private var rawActive: Bool = false

    public prop rawModeEnabled: Bool { get() { rawActive } }

    public init(
        backend: Backend,
        driver!: TerminalDriver = LinuxTerminalDriver(),
        rawMode!: Bool = true,
        alternateScreen!: Bool = true,
        mouse!: Bool = false,
        mouseMove!: Bool = false,
        focusEvents!: Bool = false,
        bracketedPaste!: Bool = false,
        hideCursor!: Bool = true,
        keyboard!: KeyboardOptions = KeyboardOptions()
    ) {
        this.backend = backend
        this.driver = driver
        this.rawMode = rawMode
        this.alternateScreen = alternateScreen
        this.mouse = mouse
        this.mouseMove = mouseMove
        this.focusEvents = focusEvents
        this.bracketedPaste = bracketedPaste
        this.hideCursor = hideCursor
        this.keyboard = keyboard
    }

    public func start(): Bool {
        if (active) { return true }
        if (alternateScreen) { backend.enterAlternateScreen() }
        if (hideCursor) { backend.hideCursor() }
        if (mouse) { backend.enableMouse() }
        if (mouseMove) { backend.write("${ESC}[?1003h${ESC}[?1006h") }
        if (focusEvents) { backend.write("${ESC}[?1004h") }
        if (bracketedPaste) { backend.enableBracketedPaste() }
        enableKeyboardProtocol()
        let rawOk = if (rawMode) { driver.enterRawMode() } else { true }
        rawActive = rawMode && rawOk
        if (rawMode && !rawOk) {
            rollbackStartedModes()
            return false
        }
        active = true
        TerminalSignalGuard.activate(
            raw: rawActive,
            alternateScreen: alternateScreen,
            mouse: mouse,
            mouseMove: mouseMove,
            focusEvents: focusEvents,
            bracketedPaste: bracketedPaste,
            hideCursor: hideCursor,
            keyboard: keyboard
        )
        atExit { this.stop() }
        rawOk
    }

    public func stop(): Unit {
        if (!active) { return }
        disableKeyboardProtocol()
        if (rawMode) { driver.restore() }
        rawActive = false
        if (bracketedPaste) { backend.disableBracketedPaste() }
        if (focusEvents) { backend.write("${ESC}[?1004l") }
        if (mouseMove) { backend.write("${ESC}[?1003l${ESC}[?1006l") }
        if (mouse) { backend.disableMouse() }
        if (hideCursor) { backend.showCursor() }
        if (alternateScreen) { backend.leaveAlternateScreen() }
        backend.flush()
        active = false
        TerminalSignalGuard.deactivate()
    }

    public func run(action: () -> Unit): Unit {
        start()
        try {
            action()
        } finally {
            stop()
        }
    }

    private func rollbackStartedModes(): Unit {
        rawActive = false
        if (bracketedPaste) { backend.disableBracketedPaste() }
        disableKeyboardProtocol()
        if (focusEvents) { backend.write("${ESC}[?1004l") }
        if (mouseMove) { backend.write("${ESC}[?1003l${ESC}[?1006l") }
        if (mouse) { backend.disableMouse() }
        if (hideCursor) { backend.showCursor() }
        if (alternateScreen) { backend.leaveAlternateScreen() }
        backend.flush()
    }

    private func enableKeyboardProtocol(): Unit {
        match (keyboard.mode) {
            case KeyboardProtocolMode.Basic => ()
            case KeyboardProtocolMode.ModifyOtherKeys =>
                backend.write("${ESC}[>4;2m")
            case KeyboardProtocolMode.Kitty =>
                backend.write("${ESC}[>1u")
            case KeyboardProtocolMode.Auto =>
                match (keyboard.probe) {
                    case TerminalProbeMode.Disabled => ()
                    case TerminalProbeMode.EnvOnly => ()
                    case TerminalProbeMode.Active =>
                        backend.write("${ESC}[?u${ESC}[>1u${ESC}[>4;2m")
                }
        }
    }

    private func disableKeyboardProtocol(): Unit {
        match (keyboard.mode) {
            case KeyboardProtocolMode.Basic => ()
            case KeyboardProtocolMode.ModifyOtherKeys => backend.write("${ESC}[>4;0m")
            case KeyboardProtocolMode.Kitty => backend.write("${ESC}[<1u")
            case KeyboardProtocolMode.Auto =>
                match (keyboard.probe) {
                    case TerminalProbeMode.Active => backend.write("${ESC}[<1u${ESC}[>4;0m")
                    case _ => ()
                }
        }
    }
}

@C
func tuiTerminalSignalHandler(signum: Int32): Unit {
    TerminalSignalGuard.restoreFromSignal(signum)
}

class TerminalSignalGuard {
    private static var installed: Bool = false
    private static var active: Bool = false
    private static var restoring: Bool = false
    private static var previousInt: ?CFunc<(Int32) -> Unit> = None
    private static var previousTerm: ?CFunc<(Int32) -> Unit> = None
    private static var previousHup: ?CFunc<(Int32) -> Unit> = None
    private static var previousQuit: ?CFunc<(Int32) -> Unit> = None
    private static var raw: Bool = false
    private static var alternateScreen: Bool = false
    private static var mouse: Bool = false
    private static var mouseMove: Bool = false
    private static var focusEvents: Bool = false
    private static var bracketedPaste: Bool = false
    private static var hideCursor: Bool = false
    private static var keyboard: KeyboardOptions = KeyboardOptions()

    static func activate(
        raw!: Bool,
        alternateScreen!: Bool,
        mouse!: Bool,
        mouseMove!: Bool,
        focusEvents!: Bool,
        bracketedPaste!: Bool,
        hideCursor!: Bool,
        keyboard!: KeyboardOptions
    ): Unit {
        TerminalSignalGuard.raw = raw
        TerminalSignalGuard.alternateScreen = alternateScreen
        TerminalSignalGuard.mouse = mouse
        TerminalSignalGuard.mouseMove = mouseMove
        TerminalSignalGuard.focusEvents = focusEvents
        TerminalSignalGuard.bracketedPaste = bracketedPaste
        TerminalSignalGuard.hideCursor = hideCursor
        TerminalSignalGuard.keyboard = keyboard
        active = true
        restoring = false
        ensureInstalled()
    }

    static func deactivate(): Unit {
        active = false
        restoring = false
        restoreHandlers()
        raw = false
        alternateScreen = false
        mouse = false
        mouseMove = false
        focusEvents = false
        bracketedPaste = false
        hideCursor = false
        keyboard = KeyboardOptions()
    }

    static func restoreFromSignal(signum: Int32): Unit {
        if (active && !restoring) {
            restoring = true
            restoreAnsiModes()
            if (raw) { TerminalMode.restore() }
            active = false
        }
        unsafe { _exit(128 + signum) }
    }

    private static func ensureInstalled(): Unit {
        if (installed) { return }
        unsafe {
            previousInt = Some(signal(TUI_SIGINT, tuiTerminalSignalHandler))
            previousTerm = Some(signal(TUI_SIGTERM, tuiTerminalSignalHandler))
            previousHup = Some(signal(TUI_SIGHUP, tuiTerminalSignalHandler))
            previousQuit = Some(signal(TUI_SIGQUIT, tuiTerminalSignalHandler))
        }
        installed = true
    }

    private static func restoreHandlers(): Unit {
        if (!installed) { return }
        unsafe {
            match (previousInt) {
                case Some(handler) => _ = signal(TUI_SIGINT, handler)
                case None => ()
            }
            match (previousTerm) {
                case Some(handler) => _ = signal(TUI_SIGTERM, handler)
                case None => ()
            }
            match (previousHup) {
                case Some(handler) => _ = signal(TUI_SIGHUP, handler)
                case None => ()
            }
            match (previousQuit) {
                case Some(handler) => _ = signal(TUI_SIGQUIT, handler)
                case None => ()
            }
        }
        previousInt = None
        previousTerm = None
        previousHup = None
        previousQuit = None
        installed = false
    }

    private static func restoreAnsiModes(): Unit {
        writeAnsi(disableKeyboardProtocolSequence())
        if (bracketedPaste) { writeAnsi("${ESC}[?2004l") }
        if (focusEvents) { writeAnsi("${ESC}[?1004l") }
        if (mouseMove) { writeAnsi("${ESC}[?1003l${ESC}[?1006l") }
        if (mouse) { writeAnsi("${ESC}[?1006l${ESC}[?1000l") }
        if (hideCursor) { writeAnsi("${ESC}[?25h") }
        if (alternateScreen) { writeAnsi("${ESC}[?1049l") }
    }

    private static func disableKeyboardProtocolSequence(): String {
        match (keyboard.mode) {
            case KeyboardProtocolMode.Basic => ""
            case KeyboardProtocolMode.ModifyOtherKeys => "${ESC}[>4;0m"
            case KeyboardProtocolMode.Kitty => "${ESC}[<1u"
            case KeyboardProtocolMode.Auto =>
                match (keyboard.probe) {
                    case TerminalProbeMode.Active => "${ESC}[<1u${ESC}[>4;0m"
                    case _ => ""
                }
        }
    }

    private static func writeAnsi(text: String): Unit {
        if (text.isEmpty()) { return }
        unsafe {
            let bytes = text.rawData()
            let handle = acquireArrayRawData(bytes)
            _ = write(STDOUT_FILENO, CPointer<Unit>(handle.pointer), UIntNative(bytes.size))
            releaseArrayRawData(handle)
        }
    }
}

public interface TerminalDriver {
    func name(): String
    func enterRawMode(): Bool
    func restore(): Unit
    func size(): ?Rect
    func capabilities(backend: Backend): TerminalCapabilities
}

public class LinuxTerminalDriver <: TerminalDriver {
    public init() {}

    public func name(): String { "linux-glibc" }
    public func enterRawMode(): Bool { TerminalMode.enterRawMode() }
    public func restore(): Unit { TerminalMode.restore() }
    public func size(): ?Rect { TerminalMode.size() }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities.detect(backend: backend, driverName: name())
    }
}

public class FallbackTerminalDriver <: TerminalDriver {
    private let area: Rect
    public init(area!: Rect = Rect(0, 0, 80, 24)) {
        this.area = area
    }

    public func name(): String { "fallback" }
    public func enterRawMode(): Bool { false }
    public func restore(): Unit {}
    public func size(): ?Rect { Some(area) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities(
            size: backend.size(),
            trueColor: false,
            mouse: false,
            bracketedPaste: false,
            alternateScreen: false,
            unicode: true,
            driverName: name()
        )
    }
}

public class AnsiBackend <: Backend {
    private let output: OutputStream
    private let driver: TerminalDriver
    private let fallbackArea: Rect

    public init(output!: OutputStream = getStdOut(), driver!: TerminalDriver = LinuxTerminalDriver(), fallbackArea!: Rect = Rect(0, 0, 80, 24)) {
        this.output = output
        this.driver = driver
        this.fallbackArea = fallbackArea
    }

    public func clear(): Unit {
        write("${ESC}[2J${ESC}[H")
    }

    public func moveTo(x: Int64, y: Int64): Unit {
        write("${ESC}[${y + 1};${x + 1}H")
    }

    public func enterAlternateScreen(): Unit { write("${ESC}[?1049h") }
    public func leaveAlternateScreen(): Unit { write("${ESC}[?1049l") }
    public func hideCursor(): Unit { write("${ESC}[?25l") }
    public func showCursor(): Unit { write("${ESC}[?25h") }
    public func enableMouse(): Unit { write("${ESC}[?1000h${ESC}[?1006h") }
    public func disableMouse(): Unit { write("${ESC}[?1006l${ESC}[?1000l") }
    public func enableBracketedPaste(): Unit { write("${ESC}[?2004h") }
    public func disableBracketedPaste(): Unit { write("${ESC}[?2004l") }

    public func size(): Rect {
        match (driver.size()) {
            case Some(area) => area
            case None => fallbackArea
        }
    }

    public func draw(buffer: Buffer): Unit {
        var current = Style.default()
        for (y in buffer.area.y..buffer.area.bottom) {
            moveTo(buffer.area.x, y)
            for (x in buffer.area.x..buffer.area.right) {
                let cell = buffer.getCell(x, y)
                if (cell.style != current) {
                    write(styleToAnsi(cell.style))
                    current = cell.style
                }
                write(cell.symbol)
            }
        }
        write(styleToAnsi(Style.default()))
        flush()
    }

    public func drawDiff(next: Buffer, plan: RenderDiffPlan): Unit {
        if (next.area.width == 0 || next.area.height == 0) {
            write(styleToAnsi(Style.default()))
            flush()
            return
        }
        var current = Style.default()
        for (span in plan.spans) {
            moveTo(span.x, span.y)
            if (span.style != current) {
                write(styleToAnsi(span.style))
                current = span.style
            }
            write(span.text)
        }
        write(styleToAnsi(Style.default()))
        flush()
    }

    public func drawMedia(ops: Array<MediaOp>): Unit {
        for (op in ops) {
            match (op.kind) {
                case MediaOpKind.Clear => clearMediaArea(op.placement.area)
                case MediaOpKind.Draw => drawMediaPlacement(op.placement)
            }
        }
        if (ops.size > 0) { flush() }
    }

    public func write(text: String): Unit {
        output.write(unsafe { text.rawData() })
    }

    public func flush(): Unit {
        output.flush()
    }

    private func clearMediaArea(area: Rect): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        for (y in area.y..area.bottom) {
            moveTo(area.x, y)
            write(repeat(" ", area.width))
        }
    }

    private func drawMediaPlacement(placement: MediaPlacement): Unit {
        if (placement.area.width <= 0 || placement.area.height <= 0) { return }
        moveTo(placement.area.x, placement.area.y)
        match (placement.frame.protocol) {
            case MediaProtocol.Kitty =>
                let widthPixels = max(1, placement.frame.widthPixels)
                let heightPixels = max(1, placement.frame.heightPixels)
                write("${ESC}_Ga=T,f=32,i=${mediaTerminalId(placement.id)},s=${widthPixels},v=${heightPixels},c=${placement.area.width},r=${placement.area.height};${placement.frame.payload}${ESC}\\")
            case MediaProtocol.Sixel =>
                write("${ESC}Pq${placement.frame.payload}${ESC}\\")
            case MediaProtocol.Text =>
                write(truncate(placement.frame.payload, placement.area.width))
        }
    }
}

public class TestBackend <: Backend {
    private var area: Rect
    private let bytes = ArrayList<Byte>()
    private var latest: ?Buffer = None
    private let frames = ArrayList<String>()
    private let mediaFrames = ArrayList<Array<MediaOp>>()
    private var latestDiffOps: Int64 = 0
    private var latestDiffWrites: Int64 = 0

    public init(area!: Rect = Rect(0, 0, 80, 24)) {
        this.area = area
    }

    public func clear(): Unit {
        write("${ESC}[2J${ESC}[H")
    }

    public func moveTo(x: Int64, y: Int64): Unit {
        write("${ESC}[${y + 1};${x + 1}H")
    }

    public func enterAlternateScreen(): Unit { write("${ESC}[?1049h") }
    public func leaveAlternateScreen(): Unit { write("${ESC}[?1049l") }
    public func hideCursor(): Unit { write("${ESC}[?25l") }
    public func showCursor(): Unit { write("${ESC}[?25h") }
    public func enableMouse(): Unit { write("${ESC}[?1000h${ESC}[?1006h") }
    public func disableMouse(): Unit { write("${ESC}[?1006l${ESC}[?1000l") }
    public func enableBracketedPaste(): Unit { write("${ESC}[?2004h") }
    public func disableBracketedPaste(): Unit { write("${ESC}[?2004l") }

    public func size(): Rect {
        area
    }

    public func setSize(area: Rect): Unit {
        this.area = area
    }

    public func draw(buffer: Buffer): Unit {
        latest = Some(buffer)
        latestDiffOps = buffer.area.width * buffer.area.height
        latestDiffWrites = if (buffer.area.height > 0) { buffer.area.height } else { 0 }
        frames.add(bufferSnapshot(buffer))
        write("<draw>")
    }

    public func drawDiff(next: Buffer, plan: RenderDiffPlan): Unit {
        latest = Some(next)
        latestDiffOps = plan.dirtyCells
        latestDiffWrites = plan.spans.size
        frames.add(bufferSnapshot(next))
        write("<diff:${latestDiffOps}:${latestDiffWrites}>")
    }

    public func drawMedia(ops: Array<MediaOp>): Unit {
        mediaFrames.add(ops)
        if (ops.size > 0) {
            write("<media:${ops.size}>")
        }
    }

    public func write(text: String): Unit {
        for (b in unsafe { text.rawData() }) {
            bytes.add(b)
        }
    }

    public func flush(): Unit {}

    public func output(): String {
        unsafe { String.fromUtf8Unchecked(bytes.toArray()) }
    }

    public func clearOutput(): Unit {
        while (bytes.size > 0) {
            bytes.remove(at: 0)
        }
    }

    public func lastBuffer(): ?Buffer {
        latest
    }

    public func lastDiffOps(): Int64 {
        latestDiffOps
    }

    public func lastDiffWrites(): Int64 {
        latestDiffWrites
    }

    public func lastMediaOps(): Array<MediaOp> {
        if (mediaFrames.size == 0) { return [] }
        mediaFrames[mediaFrames.size - 1]
    }

    public func mediaFrameCount(): Int64 {
        mediaFrames.size
    }

    public func snapshot(): String {
        match (latest) {
            case Some(buffer) => bufferSnapshot(buffer)
            case None => ""
        }
    }

    public func snapshots(): Array<String> {
        frames.toArray()
    }

    public func snapshotAt(index: Int64): String {
        if (index < 0 || index >= frames.size) { return "" }
        frames[index]
    }

    public func assertCell(x: Int64, y: Int64, symbol: String, style!: Style = Style.default()): Bool {
        match (latest) {
            case Some(buffer) =>
                let cell = buffer.getCell(x, y)
                cell.symbol == symbol && cell.style == style
            case None => false
        }
    }

    public func assertSnapshot(expected: String): Bool {
        snapshot() == expected
    }

    public func assertSnapshotAt(index: Int64, expected: String): Bool {
        snapshotAt(index) == expected
    }

    public func assertLastMediaOpCount(expected: Int64): Bool {
        lastMediaOps().size == expected
    }
}

func mediaTerminalId(id: String): Int64 {
    var value: Int64 = 17
    for (b in unsafe { id.rawData() }) {
        value = (value * 131 + Int64(b)) % 2147483647
    }
    max(1, value)
}

public struct TerminalCapabilities {
    public let size: Rect
    public let trueColor: Bool
    public let colorLevel: Int64
    public let mouse: Bool
    public let mouseMove: Bool
    public let focusEvents: Bool
    public let bracketedPaste: Bool
    public let alternateScreen: Bool
    public let unicode: Bool
    public let kittyGraphics: Bool
    public let sixel: Bool
    public let osc8: Bool
    public let keyboardProtocol: KeyProtocol
    public let keyUp: Bool
    public let keyRepeat: Bool
    public let recommendedFps: Int64
    public let cellWidthPixels: Int64
    public let cellHeightPixels: Int64
    public let driverName: String

    public init(
        size!: Rect = Rect(0, 0, 80, 24),
        trueColor!: Bool = true,
        colorLevel!: Int64 = 24,
        mouse!: Bool = true,
        mouseMove!: Bool = true,
        focusEvents!: Bool = true,
        bracketedPaste!: Bool = true,
        alternateScreen!: Bool = true,
        unicode!: Bool = true,
        kittyGraphics!: Bool = false,
        sixel!: Bool = false,
        osc8!: Bool = true,
        keyboardProtocol!: KeyProtocol = KeyProtocol.Basic,
        keyUp!: Bool = false,
        keyRepeat!: Bool = true,
        recommendedFps!: Int64 = 30,
        cellWidthPixels!: Int64 = 8,
        cellHeightPixels!: Int64 = 16,
        driverName!: String = "linux-glibc"
    ) {
        this.size = size
        this.trueColor = trueColor
        this.colorLevel = if (trueColor) { max(24, colorLevel) } else { max(1, colorLevel) }
        this.mouse = mouse
        this.mouseMove = mouseMove
        this.focusEvents = focusEvents
        this.bracketedPaste = bracketedPaste
        this.alternateScreen = alternateScreen
        this.unicode = unicode
        this.kittyGraphics = kittyGraphics
        this.sixel = sixel
        this.osc8 = osc8
        this.keyboardProtocol = keyboardProtocol
        this.keyUp = keyUp
        this.keyRepeat = keyRepeat
        this.recommendedFps = max(1, recommendedFps)
        this.cellWidthPixels = max(1, cellWidthPixels)
        this.cellHeightPixels = max(1, cellHeightPixels)
        this.driverName = driverName
    }

    public static func detect(backend!: Backend = AnsiBackend(), driverName!: String = "linux-glibc"): TerminalCapabilities {
        let term = match (getVariable("TERM")) {
            case Some(value) => value
            case None => ""
        }
        let colorTerm = match (getVariable("COLORTERM")) {
            case Some(value) => value
            case None => ""
        }
        let trueColor = colorTerm.contains("truecolor") || colorTerm.contains("24bit")
        let dumb = term == "dumb"
        let termProgram = match (getVariable("TERM_PROGRAM")) {
            case Some(value) => value
            case None => ""
        }
        let kitty = term.contains("kitty") ||
            termProgram.contains("WezTerm") || termProgram.contains("wezterm") ||
            termProgram.contains("Ghostty") || termProgram.contains("ghostty")
        let multiplexed = term.contains("screen") || term.contains("tmux")
        let sixel = term.contains("sixel") || term.contains("mlterm")
        let enhancedKeyboard = !dumb && !multiplexed && kitty
        TerminalCapabilities(
            size: backend.size(),
            trueColor: trueColor,
            colorLevel: if (trueColor) { 24 } else if (term.contains("256color")) { 256 } else { 16 },
            mouse: !dumb,
            mouseMove: !dumb,
            focusEvents: !dumb,
            bracketedPaste: !dumb,
            alternateScreen: !dumb,
            unicode: true,
            kittyGraphics: !dumb && !multiplexed && kitty,
            sixel: !dumb && !multiplexed && sixel,
            osc8: !dumb,
            keyboardProtocol: if (enhancedKeyboard) { KeyProtocol.Kitty } else { KeyProtocol.Basic },
            keyUp: enhancedKeyboard,
            keyRepeat: true,
            recommendedFps: if (kitty) { 60 } else { 30 },
            driverName: driverName
        )
    }
}

public struct RenderMetrics {
    public let size: Rect
    public let dirtyCells: Int64
    public let diffWrites: Int64
    public let mediaOps: Int64
    public let fullRedraw: Bool
    public let renderMillis: Int64
    public let drawMillis: Int64
    public let totalMillis: Int64

    public init(
        size!: Rect = Rect(0, 0, 0, 0),
        dirtyCells!: Int64 = 0,
        diffWrites!: Int64 = 0,
        mediaOps!: Int64 = 0,
        fullRedraw!: Bool = false,
        renderMillis!: Int64 = 0,
        drawMillis!: Int64 = 0,
        totalMillis!: Int64 = 0
    ) {
        this.size = size
        this.dirtyCells = max(0, dirtyCells)
        this.diffWrites = max(0, diffWrites)
        this.mediaOps = max(0, mediaOps)
        this.fullRedraw = fullRedraw
        this.renderMillis = max(0, renderMillis)
        this.drawMillis = max(0, drawMillis)
        this.totalMillis = max(0, totalMillis)
    }
}

public class DebugOverlay <: Widget {
    private let metrics: AppMetrics
    private let style: Style

    public init(metrics: AppMetrics, style!: Style = Style(fg: Color.Black, bg: Color.Yellow)) {
        this.metrics = metrics
        this.style = style
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let frame = metrics.lastFrame()
        let text = match (frame) {
            case Some(m) => "fps=${m.fps} render=${m.renderMillis}ms draw=${m.drawMillis}ms dirty=${m.dirtyCells} writes=${m.diffWrites} queue=${m.eventQueueLength} size=${m.terminalSize.width}x${m.terminalSize.height} dropped=${m.droppedTicks}"
            case None => "fps=0 render=0ms draw=0ms dirty=0 writes=0 queue=0 size=${area.width}x${area.height} dropped=0"
        }
        buffer.setString(area.x, area.y, truncate(text, area.width), style: style)
    }
}

func bufferSnapshot(buffer: Buffer): String {
    let lines = ArrayList<String>()
    for (y in buffer.area.y..buffer.area.bottom) {
        var line = ""
        for (x in buffer.area.x..buffer.area.right) {
            let symbol = buffer.getCell(x, y).symbol
            line += if (symbol.isEmpty()) { " " } else { symbol }
        }
        lines.add(line)
    }
    join(lines.toArray(), "\n")
}

public class TerminalMode {
    private static var saved: ?Array<UInt8> = None
    private static var active: Bool = false
    private static var lastErrorValue: ?String = None

    public static func lastError(): ?String {
        lastErrorValue
    }

    public static func enterRawMode(): Bool {
        if (active) {
            lastErrorValue = None
            return true
        }
        if (unsafe { isatty(STDIN_FILENO) } == 0) {
            lastErrorValue = Some("stdin is not a tty")
            return false
        }
        let original = Array<UInt8>(TERMIOS_SIZE, repeat: 0)
        unsafe {
            let handle = acquireArrayRawData(original)
            let rc = tcgetattr(STDIN_FILENO, CPointer<Unit>(handle.pointer))
            releaseArrayRawData(handle)
            if (rc != 0) {
                lastErrorValue = Some("tcgetattr failed")
                return false
            }
        }
        var raw = Array<UInt8>(TERMIOS_SIZE, repeat: 0)
        original.copyTo(raw, 0, 0, original.size)
        makeRaw(raw)
        unsafe {
            let handle = acquireArrayRawData(raw)
            let rc = tcsetattr(STDIN_FILENO, TCSAFLUSH, CPointer<Unit>(handle.pointer))
            releaseArrayRawData(handle)
            if (rc != 0) {
                lastErrorValue = Some("tcsetattr failed")
                return false
            }
        }
        saved = original
        active = true
        lastErrorValue = None
        atExit { TerminalMode.restore() }
        true
    }

    public static func restore(): Unit {
        if (!active) { return }
        if (let Some(termios) <- saved) {
            unsafe {
                let handle = acquireArrayRawData(termios)
                _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, CPointer<Unit>(handle.pointer))
                releaseArrayRawData(handle)
            }
        }
        active = false
        saved = None
    }

    public static func size(): ?Rect {
        if (unsafe { isatty(STDOUT_FILENO) } == 0) {
            return None
        }
        let winsize = Array<UInt8>(8, repeat: 0)
        unsafe {
            let handle = acquireArrayRawData(winsize)
            let rc = ioctl(STDOUT_FILENO, TIOCGWINSZ, CPointer<Unit>(handle.pointer))
            releaseArrayRawData(handle)
            if (rc != 0) { return None }
        }
        let rows = readUInt16(winsize, 0)
        let cols = readUInt16(winsize, 2)
        if (rows == 0 || cols == 0) {
            return None
        }
        Some(Rect(0, 0, Int64(cols), Int64(rows)))
    }

    private static func makeRaw(termios: Array<UInt8>): Unit {
        var iflag = readUInt32(termios, 0)
        var oflag = readUInt32(termios, 4)
        var cflag = readUInt32(termios, 8)
        var lflag = readUInt32(termios, 12)
        iflag = iflag & ((BRKINT | ICRNL | INPCK | ISTRIP | IXON) ^ 0xFFFF_FFFFu32)
        oflag = oflag & (OPOST ^ 0xFFFF_FFFFu32)
        cflag = cflag | CS8
        lflag = lflag & ((ECHO | ICANON | IEXTEN | ISIG) ^ 0xFFFF_FFFFu32)
        writeUInt32(termios, 0, iflag)
        writeUInt32(termios, 4, oflag)
        writeUInt32(termios, 8, cflag)
        writeUInt32(termios, 12, lflag)
        termios[TERMIOS_CC_OFFSET + VMIN] = 0
        termios[TERMIOS_CC_OFFSET + VTIME] = 0
    }
}
