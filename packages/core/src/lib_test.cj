package core

import std.unittest.*
import std.unittest.testmacro.*
import std.io.*
import std.collection.ArrayList
import std.fs.*

class TestOutput <: OutputStream {
    let bytes = ArrayList<Byte>()
    var writeCalls: Int64 = 0
    var flushCalls: Int64 = 0

    public func write(buffer: Array<Byte>): Unit {
        writeCalls++
        for (b in buffer) {
            bytes.add(b)
        }
    }

    public func flush(): Unit { flushCalls++ }

    func text(): String {
        unsafe { String.fromUtf8Unchecked(bytes.toArray()) }
    }
}

class CountingEventWaiter <: EventWaiter {
    var waits: Int64 = 0
    var closed: Bool = false
    var lastTimeoutMillis: Int64 = -2
    var lastPreviousReadBytes: Int64 = -2
    var lastSourceCount: Int64 = -1

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64, sources!: Array<EventSource>): Unit {
        waits++
        lastTimeoutMillis = timeoutMillis
        lastPreviousReadBytes = previousReadBytes
        lastSourceCount = sources.size
    }

    public func close(): Unit {
        closed = true
    }
}

class ResizeChangingWaiter <: EventWaiter {
    private let backend: TestBackend
    private let nextArea: Rect
    var waits: Int64 = 0
    var closed: Bool = false
    var lastTimeoutMillis: Int64 = -2

    init(backend: TestBackend, nextArea: Rect) {
        this.backend = backend
        this.nextArea = nextArea
    }

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64, sources!: Array<EventSource>): Unit {
        waits++
        lastTimeoutMillis = timeoutMillis
        backend.setSize(nextArea)
        if (previousReadBytes < -1 || sources.size < 0) { return }
    }

    public func close(): Unit {
        closed = true
    }
}

class ChunkedInputSource <: InputSource {
    private let chunks = ArrayList<Array<Byte>>()

    init(chunks: Array<Array<Byte>>) {
        for (chunk in chunks) {
            this.chunks.add(chunk)
        }
    }

    public func readAvailable(maxBytes: Int64): Array<Byte> {
        if (maxBytes <= 0 || chunks.size == 0) { return [] }
        let chunk = chunks[0]
        chunks.remove(at: 0)
        if (chunk.size <= maxBytes) { return chunk }
        chunk[..maxBytes]
    }
}

class RecordingInputSource <: InputSource {
    var maximumRequested: Int64 = 0

    public func readAvailable(maxBytes: Int64): Array<Byte> {
        maximumRequested = maxBytes
        []
    }
}

class BufferedInputSource <: InputSource {
    private let bytes: Array<Byte>
    private var offset: Int64 = 0

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public func readAvailable(maxBytes: Int64): Array<Byte> {
        if (maxBytes <= 0 || offset >= bytes.size) { return [] }
        let end = min(bytes.size, offset + maxBytes)
        let chunk = bytes[offset..end]
        offset = end
        chunk
    }
}

class CountingWidget <: Widget {
    var renders: Int64 = 0
    let text: String

    init(text: String) {
        this.text = text
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        renders++
        buffer.setString(area.x, area.y, text)
    }
}

class RestoreFailingDriver <: TerminalDriver {
    public init() {}

    public func name(): String { "restore-failing" }
    public func enterRawMode(): Bool { true }
    public func restore(): Unit { throw Exception("restore failed") }
    public func size(): ?Rect { Some(Rect(0, 0, 8, 2)) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities(size: backend.size())
    }
}

class ObservedTerminalDriver <: TerminalDriver {
    var rawEnters: Int64 = 0
    var restores: Int64 = 0
    var capabilityCalls: Int64 = 0

    public init() {}

    public func name(): String { "observed-driver" }
    public func enterRawMode(): Bool {
        rawEnters++
        true
    }
    public func restore(): Unit {
        restores++
    }
    public func size(): ?Rect { Some(Rect(0, 0, 9, 3)) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        capabilityCalls++
        TerminalCapabilities(size: backend.size(), driverName: name())
    }
}

class FixedComponentLayoutProvider <: ComponentLayoutProvider {
    private let rects: Array<Rect>

    init(rects: Array<Rect>) {
        this.rects = rects
    }

    public func split(area: Rect, count: Int64): Array<Rect> {
        if (area.width < 0 || count < 0) { return [] }
        rects
    }
}

func readText(path: String): String {
    unsafe { String.fromUtf8Unchecked(File.readFrom(Path(path))) }
}

func withoutFinalNewline(text: String): String {
    if (text.endsWith("\n")) { text[..text.size - 1] } else { text }
}

func countOccurrences(text: String, needle: String): Int64 {
    var count: Int64 = 0
    var start: Int64 = 0
    while (start <= text.size - needle.size) {
        if (text[start..start + needle.size] == needle) {
            count++
            start += needle.size
        } else {
            start++
        }
    }
    count
}

func stripComment(line: String): String {
    var i: Int64 = 0
    while (i < line.size) {
        if (line[i] == b'#') { return line[..i] }
        i++
    }
    line
}

func trimAscii(text: String): String {
    var start: Int64 = 0
    var end = text.size
    while (start < end && isAsciiWhitespace(text[start])) {
        start++
    }
    while (end > start && isAsciiWhitespace(text[end - 1])) {
        end--
    }
    text[start..end]
}

func isAsciiWhitespace(ch: Byte): Bool {
    ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n'
}

func asciiTokens(text: String): Array<String> {
    let tokens = ArrayList<String>()
    var i: Int64 = 0
    while (i < text.size) {
        while (i < text.size && isAsciiWhitespace(text[i])) {
            i++
        }
        let start = i
        while (i < text.size && !isAsciiWhitespace(text[i])) {
            i++
        }
        if (i > start) {
            tokens.add(text[start..i])
        }
    }
    tokens.toArray()
}

func parseHexUInt32(token: String): UInt32 {
    var value: UInt32 = 0
    for (ch in unsafe { token.rawData() }) {
        value = value * 16u32 + hexDigitValue(ch)
    }
    value
}

func hexDigitValue(ch: Byte): UInt32 {
    if (ch >= b'0' && ch <= b'9') { return UInt32(ch - b'0') }
    if (ch >= b'a' && ch <= b'f') { return UInt32(ch - b'a') + 10u32 }
    if (ch >= b'A' && ch <= b'F') { return UInt32(ch - b'A') + 10u32 }
    0u32
}

func addOffsetIfNew(offsets: ArrayList<Int64>, offset: Int64): Unit {
    if (offsets.size == 0 || offsets[offsets.size - 1] != offset) {
        offsets.add(offset)
    }
}

func graphemeOffsets(text: String): Array<Int64> {
    let offsets = ArrayList<Int64>()
    var offset: Int64 = 0
    offsets.add(0)
    while (offset < text.size) {
        offset = nextGraphemeOffset(text, offset)
        offsets.add(offset)
    }
    offsets.toArray()
}

func sameOffsets(left: Array<Int64>, right: Array<Int64>): Bool {
    if (left.size != right.size) { return false }
    var i: Int64 = 0
    while (i < left.size) {
        if (left[i] != right[i]) { return false }
        i++
    }
    true
}

func parseGraphemeBreakTestCase(line: String): (String, Array<Int64>) {
    let tokens = asciiTokens(trimAscii(stripComment(line)))
    let builder = StringBuilder()
    let expected = ArrayList<Int64>()
    var byteOffset: Int64 = 0
    for (token in tokens) {
        if (token == "÷") {
            addOffsetIfNew(expected, byteOffset)
        } else if (token == "×") {
            ()
        } else {
            let r = Rune(parseHexUInt32(token))
            builder.append(r)
            byteOffset += r.toString().size
        }
    }
    (builder.toString(), expected.toArray())
}

class DemoScreen <: Screen {
    let label: String

    init(label: String) {
        this.label = label
    }

    public func render(frame: Frame): Unit {
        frame.renderWidget(Paragraph(label), frame.area)
    }

    public func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.CtrlC => ControlFlow.Exit
                case _ => ControlFlow.Continue
            }
            case _ => ControlFlow.Continue
        }
    }
}

func strongItalicTestModifier(): Modifier {
    var modifier = Modifier.strong()
    modifier.italic = true
    modifier
}

class CountingComponent <: Component {
    let id: String
    var handled: Int64 = 0
    var rendered: Bool = false

    init(id: String) {
        this.id = id
    }

    public func render(frame: Frame, area: Rect): Unit {
        rendered = true
        frame.renderWidget(Paragraph(id), area)
    }

    public func handle(event: Event): HandleResult {
        handled++
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC => HandleResult.exit()
                case KeyCode.Char(r'h') => HandleResult.consumed()
                case KeyCode.Char(r'm') => HandleResult.withCommand(Command.Message(id))
                case _ => HandleResult.ignored()
            }
            case _ => HandleResult.ignored()
        }
    }

    public func focusId(): ?String {
        Some(id)
    }
}

class RuntimeProbeComponent <: RuntimeComponent {
    let id: String
    let text: String
    var mounts: Int64 = 0
    var unmounts: Int64 = 0
    var updates: Int64 = 0
    var renders: Int64 = 0
    var resizes: Int64 = 0
    var tickEvents: Int64 = 0
    var lastEventText: String = ""
    var resultDirty: Dirty = Dirty.Clean
    var resultHandled: Bool = false
    var stopOnUpdate: Bool = false
    var startTimerOnMount: Bool = false
    var poller: ?AsyncPoller = None

    init(id: String, text!: String = "x") {
        this.id = id
        this.text = text
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        mounts++
        if (startTimerOnMount) {
            ctx.startTimer("sample", Duration.millisecond * 10)
        }
        ComponentResult.ignored()
    }

    public func unmount(ctx: ComponentContext): ComponentResult {
        unmounts++
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        resizes++
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        updates++
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        match (event) {
            case Event.ComponentTick(tick) =>
                tickEvents++
                lastEventText = tick.componentId + ":" + tick.timerId
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.AsyncCompleted(id, inner) =>
                match (poller) {
                    case Some(p) => p.complete()
                    case None => ()
                }
                match (inner) {
                    case Event.Message(text) => lastEventText = id + ":" + text
                    case _ => lastEventText = id
                }
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.DataReady(id, version) =>
                lastEventText = id + ":" + "${version}"
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.DataFailed(id, _, message) =>
                lastEventText = id + ":error:" + message
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.DataCancelled(id, version) =>
                lastEventText = id + ":cancelled:" + "${version}"
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.Up =>
                        if (resultHandled) {
                            ComponentResult(handled: true, dirty: resultDirty, propagation: if (stopOnUpdate) { EventPropagation.Stop } else { EventPropagation.Continue })
                        } else {
                            ComponentResult.ignored()
                        }
                    case _ => ComponentResult.ignored()
                }
            case Event.Message(text) =>
                lastEventText = text
                if (resultHandled) {
                    ComponentResult(handled: true, dirty: resultDirty, propagation: if (stopOnUpdate) { EventPropagation.Stop } else { EventPropagation.Continue })
                } else {
                    ComponentResult.ignored()
                }
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        renders++
        frame.renderWidget(Paragraph(text), area)
    }

    public func focusId(): ?String {
        Some(id)
    }
}

class RuntimeTableRows {
    var calls: Int64 = 0

    func row(index: Int64): Array<String> {
        calls++
        ["${index}", "row-${index}"]
    }
}

class DataSourceProbeComponent <: RuntimeComponent {
    let source = DataSource<Int64>("proc", debounceMillis: 10, idleMillis: 5)
    var lastEventText = ""

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        match (event) {
            case Event.Message(text) =>
                match (text) {
                    case "activity" =>
                        source.markActivity(100)
                        ComponentResult.consumed()
                    case "poll-idle-blocked" =>
                        if (!source.refresh(ctx, { => Int64(1) }, nowMillis: 102, lowPriority: true)) {
                            lastEventText = "blocked"
                        }
                        ComponentResult.consumed()
                    case "poll" =>
                        if (source.refresh(ctx, { => Int64(2) }, nowMillis: 106, lowPriority: true)) {
                            lastEventText = "pending"
                        }
                        ComponentResult.consumed()
                    case "cancel" =>
                        source.cancel(ctx)
                        ComponentResult.consumed()
                    case _ => ComponentResult.ignored()
                }
            case Event.DataReady(id, version) =>
                lastEventText = id + ":" + "${version}"
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.DataFailed(id, _, message) =>
                lastEventText = id + ":error:" + message
                ComponentResult.consumed(dirty: Dirty.Self)
            case Event.DataCancelled(id, version) =>
                lastEventText = id + ":cancelled:" + "${version}"
                ComponentResult.consumed(dirty: Dirty.Self)
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(Paragraph("data"), area)
    }

    public func focusId(): ?String { Some("data") }
}

class CommandCounter {
    var messages: Int64 = 0
    var ticks: Int64 = 0
    var execs: Int64 = 0
    var ptyOutputs: Int64 = 0
    var ptyStdout: Int64 = 0
    var ptyStderr: Int64 = 0
    var ptyExits: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.Message(text) =>
                if (text == "load") { messages++ }
                UpdateResult.next()
            case Event.AsyncCompleted(_, event) =>
                match (event) {
                    case Event.Message(text) =>
                        if (text.startsWith("async:") || text == "load") { messages++ }
                    case Event.ExecResult(_, code, _) =>
                        if (code == 0) { execs++ }
                    case _ => ()
                }
                UpdateResult.next()
            case Event.AsyncStarted(_) =>
                UpdateResult.next()
            case Event.AsyncCancelled(_) =>
                UpdateResult.next()
            case Event.AsyncFailed(_, _) =>
                UpdateResult.next()
            case Event.Tick(_) =>
                ticks++
                UpdateResult.next()
            case Event.ExecResult(_, code, _) =>
                if (code == 0) { execs++ }
                UpdateResult.next()
            case Event.PtyStarted(_) =>
                UpdateResult.next()
            case Event.PtyOutput(_, stream, _) =>
                ptyOutputs++
                match (stream) {
                    case PtyOutputStream.Stdout => ptyStdout++
                    case PtyOutputStream.Stderr => ptyStderr++
                }
                UpdateResult.next()
            case Event.PtyExited(_, _) =>
                ptyExits++
                UpdateResult.next()
            case Event.PtyFailed(_, _) =>
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }
}

class FlowCounter {
    var seen: Int64 = 0

    func update(event: Event): ControlFlow {
        seen++
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC => ControlFlow.Exit
                case _ => ControlFlow.Continue
            }
            case _ => ControlFlow.Continue
        }
    }
}

@Test
class CjTuiCoreTest {
    @TestCase
    func layoutSplitsHorizontally(): Unit {
        let chunks = Layout.horizontal([Constraint.Length(10), Constraint.Percent(50), Constraint.Min(1)])
            .split(Rect(0, 0, 40, 5))

        @Expect(chunks.size, 3)
        @Expect(chunks[0].width, 10)
        @Expect(chunks[1].x, 10)
        @Expect(chunks[2].right, 40)
    }

    @TestCase
    func layoutSupportsGapMarginFlexMaxAndRatio(): Unit {
        let chunks = Layout.horizontal([
            Constraint.Ratio(1, 4),
            Constraint.Max(6),
            Constraint.Length(4)
        ])
            .withGap(1)
            .withMargin(Spacing.symmetric(horizontal: 2))
            .withFlex(Flex.Center)
            .split(Rect(0, 0, 30, 3))

        @Expect(chunks.size, 3)
        @Expect(chunks[0].x, 6)
        @Expect(chunks[0].width, 6)
        @Expect(chunks[1].x, 13)
        @Expect(chunks[1].width, 6)
        @Expect(chunks[2].x, 20)
        @Expect(chunks[2].width, 4)

        let rows = Layout.vertical([Constraint.Length(2), Constraint.Length(2), Constraint.Length(2)])
            .withFlex(Flex.SpaceBetween)
            .split(Rect(0, 0, 5, 10))
        @Expect(rows[0].y, 0)
        @Expect(rows[1].y, 4)
        @Expect(rows[2].y, 8)
    }

    @TestCase
    func bufferStoresStyledWideText(): Unit {
        let buffer = Buffer(Rect(0, 0, 8, 2))
        buffer.setString(0, 0, "a界", style: Style(fg: Color.Red))

        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(buffer.getCell(1, 0).symbol, "界")
        @Expect(buffer.getCell(2, 0).symbol, "")
    }

    @TestCase
    func bufferDiffFindsChangedCells(): Unit {
        let prev = Buffer(Rect(0, 0, 4, 1))
        let next = Buffer(Rect(0, 0, 4, 1))
        next.setString(2, 0, "x")

        let diff = next.diff(prev)
        @Expect(diff.size, 1)
        @Expect(diff[0].x, 2)
        @Expect(diff[0].cell.symbol, "x")
    }

    @TestCase
    func eventParserRecognizesKeysPasteAndMouse(): Unit {
        let parser = EventParser()
        let keys = parser.push([0x1B, b'[', b'A', 0x03])
        @Expect(keys.size, 2)

        match (keys[0]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.Up => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }

        let paste = parser.push(unsafe { "\u{1B}[200~hi\u{1B}[201~".rawData() })
        @Expect(paste.size, 1)
        match (paste[0]) {
            case Event.Paste(text) => @Expect(text, "hi")
            case _ => @Expect(false)
        }

        let mouse = parser.push(unsafe { "\u{1B}[<64;3;4M".rawData() })
        @Expect(mouse.size, 1)
        match (mouse[0]) {
            case Event.Mouse(m) =>
                @Expect(m.x, 2)
                @Expect(m.y, 3)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserKeepsQueuedEventsAndFlushesEsc(): Unit {
        let parser = EventParser()
        let events = parser.push([0x1B, b'[', b'A', 0x03, b'a'])
        @Expect(events.size, 3)

        parser.push([0x1B])
        @Expect(parser.flushEscAfterPolls(2).size, 0)
        let esc = parser.flushEsc()
        @Expect(esc.size, 1)
        match (esc[0]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.Esc => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserReadsFromInjectedInputSource(): Unit {
        let parser = EventParser(inputSource: ChunkedInputSource([[0x1B, b'['], [b'A']]))
        let events = parser.readEvents()
        @Expect(parser.lastReadBytes(), 3)
        @Expect(events.size, 1)
        match (events[0]) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Up => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserDrainsTerminalInputBurst(): Unit {
        let input = RecordingInputSource()
        let parser = EventParser(inputSource: input)
        @Expect(parser.readEvents().size, 0)
        @Expect(input.maximumRequested, 4096)
    }

    @TestCase
    func eventParserContinuesAfterBoundedEdgeTriggeredDrain(): Unit {
        let bytes = Array<Byte>(70000, repeat: b'a')
        bytes[0] = 0x1B
        bytes[1] = b'['
        bytes[2] = b'2'
        bytes[3] = b'0'
        bytes[4] = b'0'
        bytes[5] = b'~'
        bytes[69994] = 0x1B
        bytes[69995] = b'['
        bytes[69996] = b'2'
        bytes[69997] = b'0'
        bytes[69998] = b'1'
        bytes[69999] = b'~'
        let parser = EventParser(inputSource: BufferedInputSource(bytes))
        @Expect(parser.readEvents().size, 0)
        @Expect(parser.lastReadBytes(), 65536)
        @Expect(parser.hasPendingInputDrain())
        @Expect(parser.readEvents().size, 1)
        @Expect(parser.lastReadBytes(), 4464)
        @Expect(!parser.hasPendingInputDrain())
    }

    @TestCase
    func pendingWheelReversalKeepsLatestDirection(): Unit {
        let up = Event.Mouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 2, 3))
        let down = Event.Mouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 2, 3))
        let events = coalescePendingScrollReversal([up, up, up, down, down])
        @Expect(events.size, 2)
        for (event in events) {
            match (event) {
                case Event.Mouse(mouse) => match (mouse.button) {
                    case MouseButton.WheelDown => ()
                    case _ => @Expect(false)
                }
                case _ => @Expect(false)
            }
        }
    }

    @TestCase
    func nonWheelEventSeparatesScrollBursts(): Unit {
        let up = Event.Mouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelUp, 2, 3))
        let click = Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, 2, 3))
        let down = Event.Mouse(MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 2, 3))
        let events = coalescePendingScrollReversal([up, click, down])
        @Expect(events.size, 3)
    }

    @TestCase
    func eventParserRecognizesAltAndDelayedEsc(): Unit {
        let parser = EventParser()
        @Expect(parser.push([0x1B]).size, 0)
        @Expect(parser.flushEscAfterPolls(2).size, 0)
        let esc = parser.flushEscAfterPolls(2)
        @Expect(esc.size, 1)
        match (esc[0]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.Esc => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }

        let alt = EventParser().push([0x1B, b'x'])
        @Expect(alt.size, 1)
        match (alt[0]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'x') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.alt)
            case _ => @Expect(false)
        }

        let altCtrl = EventParser().push([0x1B, 0x04])
        @Expect(altCtrl.size, 1)
        match (altCtrl[0]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'd') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.alt)
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserRecognizesExtendedKeysAndModifiers(): Unit {
        let parser = EventParser()
        let events = parser.push(unsafe { "\t\u{1B}[Z\u{1B}[5~\u{1B}OP\u{1B}[1;5A".rawData() })
        @Expect(events.size, 5)

        match (events[0]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.Tab => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.BackTab => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
        match (events[2]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.PageUp => ()
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
        match (events[3]) {
            case Event.KeyDown(k) => match (k.code) {
                case KeyCode.F(n) => @Expect(n, 1)
                case _ => @Expect(false)
            }
            case _ => @Expect(false)
        }
        match (events[4]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Up => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserRecognizesCommonCtrlCharKeys(): Unit {
        let parser = EventParser()
        let events = parser.push([0x01, 0x04, 0x05, 0x0C, 0x13, 0x15, 0x17, 0x19, 0x1A])
        @Expect(events.size, 9)

        match (events[0]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'a') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'd') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[2]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'e') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[3]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'l') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[4]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r's') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[5]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'u') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[6]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'w') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[7]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'y') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
        match (events[8]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'z') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func eventParserRecognizesEnhancedKeyboardFocusAndMouseMove(): Unit {
        let parser = EventParser()
        let events = parser.push(unsafe { "\u{1B}[97;5;2u\u{1B}[97;5;3u\u{1B}[I\u{1B}[O\u{1B}[<35;4;5M\u{1B}[27;6;65~".rawData() })
        @Expect(events.size, 6)
        match (events[0]) {
            case Event.KeyRepeat(k) =>
                match (k.code) {
                    case KeyCode.Char(r'a') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.ctrl)
                match (k.protocol) {
                    case KeyProtocol.Kitty => ()
                    case _ => @Expect(false)
                }
                @Expect(k.nativeRepeat)
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyUp(k) =>
                match (k.code) {
                    case KeyCode.Char(r'a') => ()
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
        match (events[2]) {
            case Event.FocusIn => ()
            case _ => @Expect(false)
        }
        match (events[3]) {
            case Event.FocusOut => ()
            case _ => @Expect(false)
        }
        match (events[4]) {
            case Event.Mouse(m) =>
                match (m.kind) {
                    case MouseKind.Move => ()
                    case _ => @Expect(false)
                }
                @Expect(m.x, 3)
                @Expect(m.y, 4)
            case _ => @Expect(false)
        }
        match (events[5]) {
            case Event.KeyDown(k) =>
                match (k.code) {
                    case KeyCode.Char(r'A') => ()
                    case _ => @Expect(false)
                }
                @Expect(k.modifiers.shift)
                @Expect(k.modifiers.ctrl)
                match (k.protocol) {
                    case KeyProtocol.ModifyOtherKeys => ()
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
    }

    @TestCase
    func inputStateTracksHeldAndReleasedKeys(): Unit {
        let state = InputState(releaseAfterMillis: 10)
        let down = Event.KeyDown(KeyEvent(KeyCode.Char(r'x'), modifiers: KeyModifier(ctrl: true)))
        @Expect(state.handle(down).size, 0)
        @Expect(state.isPressed(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(state.modifiers().ctrl)
        let held = state.advance(5)
        @Expect(held.size, 1)
        match (held[0]) {
            case Event.KeyHeld(k) =>
                match (k.code) {
                    case KeyCode.Char(r'x') => ()
                    case _ => @Expect(false)
                }
            case _ => @Expect(false)
        }
        _ = state.handle(Event.KeyUp(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(!state.isPressed(KeyEvent(KeyCode.Char(r'x'))))
        _ = state.handle(down)
        _ = state.advance(15)
        @Expect(state.pressedKeys().size, 0)
    }

    @TestCase
    func canvasDrawsClippedTextSpritesAndViewport(): Unit {
        let buffer = Buffer(Rect(0, 0, 8, 4))
        let canvas = Canvas(buffer, buffer.area)
        canvas.fillRect(buffer.area, Style(bg: Color.Black))
        canvas.drawText(-1, 0, "abc", Style(fg: Color.Red))
        canvas.strokeRect(Rect(1, 1, 5, 3), Style(fg: Color.Blue))
        canvas.translated(2, 1).drawSprite(0, 0, ["xy", "zz"], Style(fg: Color.Green))
        @Expect(buffer.getCell(0, 0).symbol, "b")
        @Expect(buffer.getCell(2, 1).symbol, "x")
        @Expect(buffer.getCell(2, 2).symbol, "z")
        let guard = SizeGuard(10, 5)
        let fit = guard.fit(Rect(0, 0, 8, 4))
        @Expect(fit.tooSmall)
        @Expect(fit.content.width, 8)
    }

    @TestCase
    func inputEditsByRuneBoundaryAndDisplayWidth(): Unit {
        let input = Input(value: "a界b", cursor: 1)
        input.handle(KeyEvent(KeyCode.Right))
        @Expect(input.cursor, 4)
        input.handle(KeyEvent(KeyCode.Backspace))
        @Expect(input.value, "ab")
        @Expect(input.cursorPosition(Rect(0, 0, 10, 1)).x, 1)
    }

    @TestCase
    func inputKeepsCursorVisibleAndSupportsValueHelpers(): Unit {
        let input = Input(value: "abcdef", cursor: 6, placeholder: "type")
        let buffer = Buffer(Rect(0, 0, 3, 1))
        input.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "d")
        @Expect(input.cursorPosition(buffer.area).x, 3)

        input.moveToStart()
        @Expect(input.cursor, 0)
        input.moveToEnd()
        @Expect(input.cursor, input.value.size)
        input.setValue("界abc", cursor: 3)
        @Expect(input.cursorPosition(Rect(0, 0, 4, 1)).x, 2)
        input.clear()
        @Expect(input.value, "")
    }

    @TestCase
    func paragraphWrapsAndAlignsText(): Unit {
        let wrapped = Buffer(Rect(0, 0, 4, 3))
        Paragraph("one two", wrap: WrapMode.Word).render(wrapped.area, wrapped)
        @Expect(wrapped.getCell(0, 0).symbol, "o")
        @Expect(wrapped.getCell(0, 1).symbol, "t")

        let centered = Buffer(Rect(0, 0, 6, 1))
        Paragraph("ok", wrap: WrapMode.NoWrap, align: TextAlign.Center).render(centered.area, centered)
        @Expect(centered.getCell(2, 0).symbol, "o")
    }

    @TestCase
    func terminalAppliesFrameCursor(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let terminal = Terminal(backend)
        terminal.draw { frame =>
            frame.renderWidget(Paragraph("ok"), frame.area)
            frame.setCursor(Position(2, 1))
        }
        terminal.draw { frame =>
            frame.renderWidget(Paragraph("next"), frame.area)
            frame.setCursor(Position(3, 1))
        }
        @Expect(out.text().contains("\u{1B}[?25h"))
        @Expect(out.text().contains("\u{1B}[2;3H"))
        @Expect(out.text().contains("\u{1B}[2;4H"))
        @Expect(countOccurrences(out.text(), "\u{1B}[?25h"), 1)

        terminal.draw { frame =>
            frame.renderWidget(Paragraph("done"), frame.area)
        }
        terminal.draw { frame =>
            frame.renderWidget(Paragraph("still done"), frame.area)
        }
        @Expect(out.text().contains("\u{1B}[?25l"))
        @Expect(countOccurrences(out.text(), "\u{1B}[?25l"), 1)
    }

    @TestCase
    func ansiBackendBatchesEachFullAndDiffFrameIntoOneWrite(): Unit {
        let fullOut = TestOutput()
        let fullBackend = AnsiBackend(output: fullOut, fallbackArea: Rect(0, 0, 8, 2))
        let full = Buffer(Rect(0, 0, 8, 2))
        full.setString(0, 0, "中文🙂", style: Style(fg: Color.Cyan))
        full.setString(0, 1, "e\u{301} ansi", style: Style.default())
        fullBackend.draw(full)
        @Expect(fullOut.writeCalls, 1)
        @Expect(fullOut.flushCalls, 1)
        @Expect(fullOut.text().contains("中文🙂"))
        @Expect(fullOut.text().contains("e\u{301} ansi"))

        let diffOut = TestOutput()
        let diffBackend = AnsiBackend(output: diffOut, fallbackArea: Rect(0, 0, 8, 2))
        diffBackend.drawDiff(
            full,
            RenderDiffPlan(
                4,
                [
                    RenderDiffSpan(0, 0, "中文", Style(fg: Color.Cyan)),
                    RenderDiffSpan(4, 1, "🙂", Style.default())
                ]
            )
        )
        @Expect(diffOut.writeCalls, 1)
        @Expect(diffOut.flushCalls, 1)
        @Expect(diffOut.text().contains("中文"))
        @Expect(diffOut.text().contains("🙂"))
    }

    @TestCase
    func testBackendCapturesDrawDiffAndOutput(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let terminal = Terminal(backend)
        terminal.draw { frame => frame.renderWidget(Paragraph("one"), frame.area) }
        terminal.draw { frame => frame.renderWidget(Paragraph("two"), frame.area) }
        @Expect(backend.output().contains("<draw>"))
        @Expect(backend.output().contains("<diff:"))
        match (backend.lastBuffer()) {
            case Some(buffer) => @Expect(buffer.getCell(0, 0).symbol, "t")
            case None => @Expect(false)
        }
    }

    @TestCase
    func terminalSessionRestoresModes(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            rawMode: false,
            alternateScreen: true,
            mouse: true,
            bracketedPaste: true,
            hideCursor: true
        )
        session.run { backend.write("body") }
        let text = out.text()
        @Expect(text.contains("\u{1B}[?1049h"))
        @Expect(text.contains("\u{1B}[?25l"))
        @Expect(text.contains("\u{1B}[?2004l"))
        @Expect(text.contains("\u{1B}[?25h"))
        @Expect(text.contains("\u{1B}[?1049l"))
        @Expect(!session.rawModeEnabled)
    }

    @TestCase
    func terminalSessionEnablesBracketedPasteByDefault(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        TerminalSession(backend, rawMode: false, alternateScreen: false, hideCursor: false).run {
            backend.write("body")
        }
        let text = out.text()
        @Expect(text.contains("\u{1B}[?2004h"))
        @Expect(text.contains("\u{1B}[?2004l"))
    }

    @TestCase
    func terminalSessionRestoresMouseMoveSgrModeWithoutMouseMode(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            rawMode: false,
            alternateScreen: false,
            mouse: false,
            mouseMove: true,
            bracketedPaste: false,
            hideCursor: false
        )
        session.run { backend.write("body") }
        let text = out.text()
        @Expect(text.contains("\u{1B}[?1003h\u{1B}[?1006h"))
        @Expect(text.contains("\u{1B}[?1003l\u{1B}[?1006l"))
    }

    @TestCase
    func terminalSessionRunRestoresModesAfterExceptionAndStopIsIdempotent(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            rawMode: false,
            alternateScreen: true,
            mouse: true,
            bracketedPaste: true,
            hideCursor: true
        )
        var caught = false
        try {
            session.run {
                backend.write("before-error")
                throw Exception("boom")
            }
        } catch (_: Exception) {
            caught = true
        }

        @Expect(caught)
        @Expect(!session.rawModeEnabled)
        let beforeStopAgain = out.text()
        @Expect(beforeStopAgain.contains("before-error"))
        @Expect(beforeStopAgain.contains("\u{1B}[?1049h"))
        @Expect(beforeStopAgain.contains("\u{1B}[?1000h\u{1B}[?1006h"))
        @Expect(beforeStopAgain.contains("\u{1B}[?2004h"))
        @Expect(beforeStopAgain.contains("\u{1B}[?2004l"))
        @Expect(beforeStopAgain.contains("\u{1B}[?1006l\u{1B}[?1000l"))
        @Expect(beforeStopAgain.contains("\u{1B}[?25h"))
        @Expect(beforeStopAgain.contains("\u{1B}[?1049l"))

        session.stop()
        let afterStopAgain = out.text()
        @Expect(afterStopAgain, beforeStopAgain)
        @Expect(countOccurrences(afterStopAgain, "\u{1B}[?1049l"), 1)
        @Expect(countOccurrences(afterStopAgain, "\u{1B}[?25h"), 1)
    }

    @TestCase
    func terminalSessionRunReportsPrimaryAndRestoreErrors(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            driver: RestoreFailingDriver(),
            rawMode: true,
            alternateScreen: false,
            bracketedPaste: false,
            hideCursor: false
        )

        var message = ""
        try {
            session.run {
                throw Exception("update failed")
            }
        } catch (e: Exception) {
            message = e.message
        }

        @Expect(message.contains("update failed"))
        @Expect(message.contains("restore failed"))
    }

    @TestCase
    func terminalSessionStartCleansUpForRawModeResult(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            rawMode: true,
            alternateScreen: true,
            mouse: true,
            bracketedPaste: true,
            hideCursor: true
        )
        let ok = session.start()
        if (ok) {
            @Expect(session.rawModeEnabled)
            session.stop()
            @Expect(!session.rawModeEnabled)
            let text = out.text()
            @Expect(text.contains("\u{1B}[?1049h"))
            @Expect(text.contains("\u{1B}[?2004h"))
            @Expect(text.contains("\u{1B}[?2004l"))
            @Expect(text.contains("\u{1B}[?1006l"))
            @Expect(text.contains("\u{1B}[?25h"))
            @Expect(text.contains("\u{1B}[?1049l"))
        } else {
            @Expect(!session.rawModeEnabled)
            let text = out.text()
            @Expect(text.contains("\u{1B}[?1049h"))
            @Expect(text.contains("\u{1B}[?2004l"))
            @Expect(text.contains("\u{1B}[?1006l"))
            @Expect(text.contains("\u{1B}[?25h"))
            @Expect(text.contains("\u{1B}[?1049l"))
        }
    }

    @TestCase
    func terminalSessionUsesBasicKeyboardByDefaultAndRequiresExplicitEnhancedMode(): Unit {
        let defaultOut = TestOutput()
        let defaultBackend = AnsiBackend(output: defaultOut, fallbackArea: Rect(0, 0, 8, 2))
        TerminalSession(defaultBackend, rawMode: false, alternateScreen: false, hideCursor: false).run {
            defaultBackend.write("body")
        }
        let defaultText = defaultOut.text()
        @Expect(!defaultText.contains("\u{1B}[?u"))
        @Expect(!defaultText.contains("\u{1B}[>1u"))
        @Expect(!defaultText.contains("\u{1B}[>4;2m"))

        let kittyOut = TestOutput()
        let kittyBackend = AnsiBackend(output: kittyOut, fallbackArea: Rect(0, 0, 8, 2))
        TerminalSession(
            kittyBackend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Kitty)
        ).run { kittyBackend.write("body") }
        @Expect(kittyOut.text().contains("\u{1B}[>1u"))
        @Expect(kittyOut.text().contains("\u{1B}[<1u"))

        let modifyOut = TestOutput()
        let modifyBackend = AnsiBackend(output: modifyOut, fallbackArea: Rect(0, 0, 8, 2))
        TerminalSession(
            modifyBackend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.ModifyOtherKeys)
        ).run { modifyBackend.write("body") }
        @Expect(modifyOut.text().contains("\u{1B}[>4;2m"))
        @Expect(modifyOut.text().contains("\u{1B}[>4;0m"))

        let autoOut = TestOutput()
        let autoBackend = AnsiBackend(output: autoOut, fallbackArea: Rect(0, 0, 8, 2))
        TerminalSession(
            autoBackend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            probeInputSource: ChunkedInputSource([unsafe { "\u{1B}[?1u".rawData() }]),
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: TerminalProbeMode.Active, probeBudgetMillis: 250)
        ).run { autoBackend.write("body") }
        @Expect(autoOut.text().contains("\u{1B}[?u"))
        @Expect(autoOut.text().contains("\u{1B}[>1u\u{1B}[>4;2m"))
        @Expect(autoOut.text().contains("\u{1B}[<1u\u{1B}[>4;0m"))
    }

    @TestCase
    func terminalProbeConsumesResponsesWithinClampedBudget(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let result = TerminalProbe.run(
            backend,
            ChunkedInputSource([unsafe { "\u{1B}[?1u".rawData() }]),
            base: TerminalCapabilities(size: Rect(0, 0, 8, 2), keyboardProtocol: KeyProtocol.Basic, keyUp: false),
            budgetMillis: 250
        )
        @Expect(result.budgetMillis, 100)
        @Expect(result.consumedBytes.size > 0)
        @Expect(out.text().contains("\u{1B}[?u"))
        match (result.capabilities.keyboardProtocol) {
            case KeyProtocol.Kitty => ()
            case _ => @Expect(false)
        }
        @Expect(result.capabilities.keyUp)
    }

    @TestCase
    func terminalSessionStoresProbeResultForAutoActiveKeyboard(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 8, 2))
        let session = TerminalSession(
            backend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            probeInputSource: ChunkedInputSource([unsafe { "\u{1B}[?1u".rawData() }]),
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: TerminalProbeMode.Active)
        )
        session.run { backend.write("body") }
        match (session.probeResult()) {
            case Some(result) =>
                @Expect(result.consumedBytes.size > 0)
                match (result.capabilities.keyboardProtocol) {
                    case KeyProtocol.Kitty => ()
                    case _ => @Expect(false)
                }
            case None => @Expect(false)
        }
    }

    @TestCase
    func platformDefaultsSelectLinuxDriverAndWaiterOnLinux(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        @Expect(defaultTerminalDriver().capabilities(backend).driverName, "linux-glibc")

        let waiter = defaultEventWaiter()
        waiter.wait(0, previousReadBytes: 0, sources: [])
        waiter.close()
    }

    @TestCase
    func unicodeWidthHandlesAsciiCjkAndCombining(): Unit {
        @Expect(displayWidth("abc"), 3)
        @Expect(displayWidth("界"), 2)
        @Expect(displayWidth("e\u{0301}"), 1)
        @Expect(displayWidth("\u{FE0F}"), 0)
        @Expect(displayWidth("\u{2764}\u{FE0F}"), 1)
        @Expect(displayWidth("\u{1F469}\u{200D}\u{1F4BB}") >= 2)
    }

    @TestCase
    func unicode17GraphemeBreakTestFixturePasses(): Unit {
        let fixture = readText("tests/unicode/17.0.0/GraphemeBreakTest.txt")
        var cases: Int64 = 0
        var mismatches: Int64 = 0
        for (line in splitLines(fixture)) {
            let body = trimAscii(stripComment(line))
            if (body.isEmpty()) { continue }
            let (text, expected) = parseGraphemeBreakTestCase(line)
            let actual = graphemeOffsets(text)
            if (!sameOffsets(actual, expected)) {
                mismatches++
            }
            cases++
        }
        @Expect(cases >= 700)
        @Expect(mismatches, 0)
    }

    @TestCase
    func trueColorAndStylePatchRenderAnsi(): Unit {
        let out = TestOutput()
        let backend = AnsiBackend(output: out, fallbackArea: Rect(0, 0, 2, 1))
        let buffer = Buffer(Rect(0, 0, 2, 1))
        let patched = Style(fg: Color.Red).patch(Style(bg: Color.Rgb(1, 2, 3)))
        buffer.setString(0, 0, "x", style: patched.withFg(Color.Rgb(4, 5, 6)))
        backend.draw(buffer)
        let text = out.text()
        @Expect(text.contains("38;2;4;5;6"))
        @Expect(text.contains("48;2;1;2;3"))
    }

    @TestCase
    func statefulListTableAndScrollbarRenderVisibleSelection(): Unit {
        let listBuffer = Buffer(Rect(0, 0, 12, 2))
        let listState = ListState(selected: Some(2), offset: 1)
        List(["zero", "one", "two"], state: Some(listState)).render(listBuffer.area, listBuffer)
        @Expect(listBuffer.getCell(2, 0).symbol, "o")
        @Expect(listBuffer.getCell(0, 1).symbol, ">")
        @Expect(listBuffer.getCell(0, 1).style, Style(fg: Color.Black, bg: Color.White))

        let tableBuffer = Buffer(Rect(0, 0, 14, 4))
        let tableState = TableState(selectedRow: Some(2), offset: 1)
        Table(["A"], [["r0"], ["r1"], ["r2"]], widths: [4], state: Some(tableState)).render(tableBuffer.area, tableBuffer)
        @Expect(tableBuffer.getCell(0, 2).symbol, "r")
        @Expect(tableBuffer.getCell(1, 2).symbol, "1")
        @Expect(tableBuffer.getCell(0, 3).style, Style(fg: Color.Black, bg: Color.White))

        let scrollBuffer = Buffer(Rect(0, 0, 1, 5))
        Scrollbar(10, offset: 5, viewport: 5).render(scrollBuffer.area, scrollBuffer)
        @Expect(scrollBuffer.getCell(0, 3).symbol, "#")
    }

    @TestCase
    func stateMoveKeepsSelectionVisible(): Unit {
        let listState = ListState(selected: Some(0))
        listState.move(4, 10, viewportHeight: 3)
        @Expect(listState.selected, Some(4))
        @Expect(listState.offset, 2)

        let tableState = TableState(selectedRow: Some(5), offset: 4)
        tableState.move(-4, 10, viewportHeight: 3)
        @Expect(tableState.selectedRow, Some(1))
        @Expect(tableState.offset, 1)
    }

    @TestCase
    func focusManagerMovesAndSkipsDisabledItems(): Unit {
        let focus = FocusManager()
        focus.add("name")
        focus.add("disabled", enabled: false)
        focus.add("submit")
        @Expect(focus.current(), Some("name"))
        @Expect(focus.next(), Some("submit"))
        @Expect(focus.handle(KeyEvent(KeyCode.BackTab)))
        @Expect(focus.current(), Some("name"))
        @Expect(!focus.focus("disabled"))
        focus.remove("name")
        @Expect(focus.current(), Some("submit"))
    }

    @TestCase
    func eventRouterDispatchesFocusedComponentBeforeGlobalFallback(): Unit {
        let keymap = KeyMap()
        keymap.add(KeyBinding([KeyEvent(KeyCode.Char(r'q'))], "quit"))
        let router = EventRouter(globalKeys: keymap)
        let first = CountingComponent("first")
        let second = CountingComponent("second")
        router.add(first)
        router.add(second)

        let flow = router.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))), { action =>
            if (action == "quit") { ControlFlow.Exit } else { ControlFlow.Continue }
        })
        match (flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
        @Expect(first.handled, 1)

        @Expect(router.focusManager().focus("second"))
        _ = router.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(first.handled, 1)
        @Expect(second.handled, 1)
        let handled = router.handleResult(Event.KeyDown(KeyEvent(KeyCode.Char(r'h'))))
        @Expect(handled.handled)
        match (handled.flow) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }
        let command = router.handleResult(Event.KeyDown(KeyEvent(KeyCode.Char(r'm'))))
        @Expect(command.handled)
        match (command.command) {
            case Command.Message(text) => @Expect(text, "second")
            case _ => @Expect(false)
        }

        let backend = TestBackend(area: Rect(0, 0, 10, 2))
        let terminal = Terminal(backend)
        terminal.draw { frame =>
            router.render(frame, Layout.vertical([Constraint.Length(1), Constraint.Length(1)]).split(frame.area))
        }
        @Expect(first.rendered)
        @Expect(second.rendered)
        @Expect(backend.snapshot().contains("first"))
    }

    @TestCase
    func textAreaRenderReusesLineCacheAcrossStableFrames(): Unit {
        let value = "one\ntwo\nthree\nfour\nfive\nsix"
        let area = TextArea(value: value, cursor: 0, lineNumbers: true)
        let buffer = Buffer(Rect(0, 0, 20, 4))
        area.render(Rect(0, 0, 20, 4), buffer)
        @Expect(area.lineCacheRebuildCount(), 1)
        area.render(Rect(0, 0, 20, 4), buffer)
        @Expect(area.lineCacheRebuildCount(), 1)
        area.paste("x")
        area.render(Rect(0, 0, 20, 4), buffer)
        @Expect(area.lineCacheRebuildCount(), 2)
    }

    @TestCase
    func commandRuntimeProcessesBatchMessagesAndQuit(): Unit {
        let queue = ArrayList<Command>()
        let counter = CommandCounter()
        let runtime = AsyncRuntime()
        @Expect(App.applyUpdateResult(UpdateResult.withCommand(Command.Batch([
            Command.Message("load"),
            Command.Async("job"),
            Command.AsyncTask("task", { => Event.Message("load") }),
            Command.AsyncExec("printf", "/usr/bin/printf ok"),
            Command.AsyncExecArgs("printf-args", "/usr/bin/printf", ["ok"]),
            Command.Emit(Event.Tick(TickEvent())),
            Command.StartTimer(TimerSpec("test", Duration.millisecond, mode: TimerMode.OneShot)),
            Command.StopTimer("test"),
            Command.Exec("/usr/bin/printf ok"),
            Command.ExecArgs("printf-sync-args", "/usr/bin/printf", ["ok"])
        ])), queue))
        @Expect(queue.size, 10)
        let running = App.processCommands({ event => counter.update(event) }, queue, asyncRuntime: runtime)
        @Expect(running)
        while (runtime.pendingCount() > 0) {
            @Expect(App.processCommands({ event => counter.update(event) }, queue, asyncRuntime: runtime))
        }
        @Expect(counter.messages >= 3)
        @Expect(counter.ticks, 1)
        @Expect(counter.execs >= 2)
        queue.add(Command.Quit)
        @Expect(!App.processCommands({ event => counter.update(event) }, queue))

        match (App.executeCommand("/usr/bin/printf ok")) {
            case Event.ExecResult(_, code, output) =>
                @Expect(code, 0)
                @Expect(output, "ok")
            case _ => @Expect(false)
        }
        match (App.executeCommandArgs("args", "/usr/bin/printf", ["ok"])) {
            case Event.ExecResult(id, code, output) =>
                @Expect(id, "args")
                @Expect(code, 0)
                @Expect(output, "ok")
            case _ => @Expect(false)
        }

        let subscription = Subscription(2, Event.Message("sub"))
        match (subscription.poll()) {
            case Some(_) => @Expect(false)
            case None => ()
        }
        match (subscription.poll()) {
            case Some(Event.Message(text)) => @Expect(text, "sub")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func processCommandsWithEventsFlattensDirectlyQueuedBatch(): Unit {
        let queue = ArrayList<Command>()
        let counter = CommandCounter()
        queue.add(Command.Batch([
            Command.Message("load"),
            Command.Batch([
                Command.Emit(Event.Tick(TickEvent())),
                Command.Message("load")
            ]),
            Command.Quit
        ]))

        let (running, changed) = App.processCommandsWithEvents({ event => counter.update(event) }, queue)
        @Expect(!running)
        @Expect(changed)
        @Expect(queue.size, 0)
        @Expect(counter.messages, 2)
        @Expect(counter.ticks, 1)
    }

    @TestCase
    func terminalLifecycleCommandsAreSafeInHeadlessProcessing(): Unit {
        let queue = ArrayList<Command>()
        queue.add(Command.ResetTerminal)
        queue.add(Command.Suspend)
        let (running, changed) = App.processCommandsWithEvents(
            {_ => UpdateResult.next()},
            queue
        )
        @Expect(running)
        @Expect(changed)
        @Expect(queue.size, 0)
    }

    @TestCase
    func ptyRuntimeProcessesSplitStreamsAndControlCommands(): Unit {
        let queue = ArrayList<Command>()
        let counter = CommandCounter()
        let runtime = FakePtyRuntime()
        queue.add(Command.PtyStart("shell", PtySpec("/bin/sh", size: PtySize(cols: 100, rows: 30))))
        queue.add(Command.PtyWrite("shell", unsafe { "echo ok\n".rawData() }))
        queue.add(Command.PtyResize("shell", PtySize(cols: 120, rows: 40)))
        queue.add(Command.PtySendSignal("shell", PtySignal.Interrupt))
        @Expect(App.processCommands({ event => counter.update(event) }, queue, ptyRuntime: runtime))

        match (runtime.fakeProcess("shell")) {
            case Some(process) =>
                @Expect(process.lastSize.cols, 120)
                @Expect(process.lastSize.rows, 40)
                @Expect(process.lastWrite.size > 0)
                match (process.lastSignal) {
                    case Some(PtySignal.Interrupt) => @Expect(true)
                    case _ => @Expect(false)
                }
            case None => @Expect(false)
        }

        runtime.injectText("shell", "stdout")
        runtime.injectText("shell", "stderr", stream: PtyOutputStream.Stderr)
        runtime.injectExit("shell", PtyExitStatus.exited(0))
        @Expect(App.processCommands({ event => counter.update(event) }, queue, ptyRuntime: runtime))
        @Expect(counter.ptyOutputs, 2)
        @Expect(counter.ptyStdout, 1)
        @Expect(counter.ptyStderr, 1)
        @Expect(counter.ptyExits, 1)
    }

    @TestCase
    func linuxPtyRuntimeRunsBoundedCommandWhenAvailable(): Unit {
        let runtime = LinuxPtyRuntime()
        match (runtime.start("printf", PtySpec("/bin/sh", args: ["-lc", "printf pty-ok; printf pty-err >&2"]))) {
            case Event.PtyStarted(id) => @Expect(id, "printf")
            case Event.PtyFailed(_, _) => return
            case _ => @Expect(false)
        }
        var sawOutput = false
        var sawStderr = false
        var sawExit = false
        for (_ in 0..10000) {
            for (source in runtime.sources()) {
                source.onReady(true, false, false, false)
            }
            for (event in runtime.drain()) {
                match (event) {
                    case Event.PtyOutput(_, stream, bytes) =>
                        if (unsafe { String.fromUtf8Unchecked(bytes) }.contains("pty-ok")) {
                            match (stream) {
                                case PtyOutputStream.Stdout => ()
                                case _ => @Expect(false)
                            }
                            sawOutput = true
                        }
                        if (unsafe { String.fromUtf8Unchecked(bytes) }.contains("pty-err")) {
                            match (stream) {
                                case PtyOutputStream.Stderr => ()
                                case _ => @Expect(false)
                            }
                            sawStderr = true
                        }
                    case Event.PtyExited(_, status) =>
                        match (status.code) {
                            case Some(code) => @Expect(code, 0)
                            case None => ()
                        }
                        sawExit = true
                    case _ => ()
                }
            }
            if (sawOutput && sawStderr && sawExit) { break }
        }
        if (runtime.activeCount() > 0) {
            _ = runtime.close("printf")
        }
        @Expect(sawOutput)
        @Expect(sawStderr)
        @Expect(sawExit)
    }

    @TestCase
    func asyncRuntimeStartsCompletesAndCancelsTasks(): Unit {
        let runtime = AsyncRuntime()
        match (runtime.start("one", { => Event.Message("done") })) {
            case Event.AsyncStarted(id) => @Expect(id, "one")
            case _ => @Expect(false)
        }
        var completed = false
        while (!completed) {
            for (event in runtime.drain()) {
                match (event) {
                    case Event.AsyncCompleted(id, Event.Message(text)) =>
                        @Expect(id, "one")
                        @Expect(text, "done")
                        completed = true
                    case _ => ()
                }
            }
        }

        _ = runtime.start("cancel", { => Event.Message("late") })
        @Expect(runtime.cancel("cancel"))
        var sawCancel = false
        while (!sawCancel) {
            for (event in runtime.drain()) {
                match (event) {
                    case Event.AsyncCancelled(id) =>
                        @Expect(id, "cancel")
                        sawCancel = true
                    case _ => ()
                }
            }
        }
    }

    @TestCase
    func formWidgetsRenderAndHandleEvents(): Unit {
        let buffer = Buffer(Rect(0, 0, 20, 10))
        Button("Save", focused: true).render(Rect(0, 0, 10, 1), buffer)
        @Expect(buffer.getCell(3, 0).symbol, "S")

        let checkbox = Checkbox("Enabled")
        @Expect(checkbox.handle(KeyEvent(KeyCode.Char(r' '))))
        @Expect(checkbox.checked)
        checkbox.render(Rect(0, 1, 20, 1), buffer)
        @Expect(buffer.getCell(1, 1).symbol, "x")

        let radio = RadioGroup(["one", "two"], selected: 0)
        @Expect(radio.handle(KeyEvent(KeyCode.Down)))
        @Expect(radio.selected, 1)
        radio.render(Rect(0, 2, 20, 2), buffer)
        @Expect(buffer.getCell(1, 3).symbol, "*")

        ProgressBar(5, total: 10, label: "50%").render(Rect(0, 4, 10, 1), buffer)
        @Expect(buffer.getCell(0, 4).symbol, "#")
        @Expect(buffer.getCell(9, 4).symbol, "-")

        ProgressBar(25, total: 100, labelMode: ProgressBarLabelMode.Percent).render(Rect(0, 5, 8, 1), buffer)
        @Expect(buffer.getCell(2, 5).symbol, "2")
        @Expect(buffer.getCell(4, 5).symbol, "%")

        ProgressBar(
            0,
            total: 10,
            symbols: ProgressBarSymbols(filled: "=", empty: ".", indeterminate: ">"),
            indeterminate: true,
            phase: 4
        ).render(Rect(0, 6, 9, 1), buffer)
        @Expect(buffer.getCell(1, 6).symbol, ">")
        @Expect(buffer.getCell(3, 6).symbol, ">")

        ProgressBar(
            0,
            total: 10,
            segments: [
                ProgressBarSegment(3, style: Style(fg: Color.Green), symbol: "G"),
                ProgressBarSegment(2, style: Style(fg: Color.Yellow), symbol: "Y")
            ]
        ).render(Rect(0, 7, 10, 1), buffer)
        @Expect(buffer.getCell(0, 7).symbol, "G")
        @Expect(buffer.getCell(2, 7).symbol, "G")
        @Expect(buffer.getCell(3, 7).symbol, "Y")
        @Expect(buffer.getCell(4, 7).symbol, "Y")

        ProgressBar(2, total: 4, direction: ProgressBarDirection.Vertical).render(Rect(12, 4, 2, 4), buffer)
        @Expect(buffer.getCell(12, 7).symbol, "#")
        @Expect(buffer.getCell(12, 6).symbol, "#")
        @Expect(buffer.getCell(12, 5).symbol, "-")
    }

    @TestCase
    func transcriptComposerTimelineAndRequestWidgetsWork(): Unit {
        @Expect(statusMark(TranscriptItemStatus.Streaming, activityFrame: 0), "⋮")
        @Expect(statusMark(TranscriptItemStatus.Streaming, activityFrame: 1), "⋰")
        @Expect(statusMark(TranscriptItemStatus.Running, activityFrame: 0), "◐")
        @Expect(statusMark(TranscriptItemStatus.Running, activityFrame: 1), "◓")
        let transcript = Transcript(items: [
            TranscriptItem("one", title: "First", body: Document.plain("hello")),
            TranscriptItem("two", kind: TranscriptItemKind.Error, title: "Error", body: Document.plain("bad"), status: TranscriptItemStatus.Failed, collapsed: true)
        ])
        let view = TranscriptView(transcript, selected: 0)
        let buffer = Buffer(Rect(0, 0, 40, 12))
        view.render(Rect(0, 0, 40, 5), buffer)
        @Expect(buffer.getCell(2, 0).symbol, "F")
        @Expect(view.handle(KeyEvent(KeyCode.Down), 5))
        @Expect(view.selected, 1)
        @Expect(view.handle(KeyEvent(KeyCode.Enter), 5))
        match (transcript.get(1)) {
            case Some(item) => @Expect(!item.collapsed)
            case None => @Expect(false)
        }

        let composer = Composer(slashHints: ["/run", "/open"])
        match (composer.handle(KeyEvent(KeyCode.Char(r'/')))) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        match (composer.handle(KeyEvent(KeyCode.Char(r'r')))) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        @Expect(composer.currentSlashHints().size, 1)
        match (composer.handle(KeyEvent(KeyCode.Enter))) {
            case Some(submit) => @Expect(submit.text, "/r")
            case None => @Expect(false)
        }
        @Expect(composer.area.value, "")
        match (composer.handle(KeyEvent(KeyCode.Up))) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        @Expect(composer.area.value, "/r")
        composer.area.setValue("/open")
        match (composer.handle(KeyEvent(KeyCode.Enter))) {
            case Some(submit) => @Expect(submit.text, "/open")
            case None => @Expect(false)
        }
        _ = composer.handle(KeyEvent(KeyCode.Up))
        @Expect(composer.area.value, "/open")
        _ = composer.handle(KeyEvent(KeyCode.Up))
        @Expect(composer.area.value, "/r")
        _ = composer.handle(KeyEvent(KeyCode.Up))
        @Expect(composer.area.value, "/r")
        _ = composer.handle(KeyEvent(KeyCode.Down))
        @Expect(composer.area.value, "/open")
        _ = composer.handle(KeyEvent(KeyCode.Down))
        @Expect(composer.area.value, "")
        composer.area.setValue("abcdefgh")
        @Expect(composer.visualHeight(4, 8), 2)
        let composerBuffer = Buffer(Rect(0, 0, 4, 2))
        composer.render(composerBuffer.area, composerBuffer)
        @Expect(composerBuffer.getCell(0, 0).symbol, "a")
        @Expect(composerBuffer.getCell(0, 1).symbol, "e")
        @Expect(composer.cursorPosition(composerBuffer.area).y, 1)

        ActivityTimeline([
            ActivityStep("queued"),
            ActivityStep("running", status: TranscriptItemStatus.Running, duration: "1s")
        ]).render(Rect(0, 6, 30, 2), buffer)
        @Expect(buffer.getCell(2, 7).symbol, "r")

        let request = RequestDialog(title: "Confirm", body: "run command")
        request.render(Rect(0, 0, 40, 12), buffer)
        match (request.handle(KeyEvent(KeyCode.Right))) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        match (request.handle(KeyEvent(KeyCode.Enter))) {
            case Some(action) => @Expect(action, "Confirm")
            case None => @Expect(false)
        }
    }

    @TestCase
    func commandWidgetsRenderAndHandleActions(): Unit {
        let menu = Menu("File", [
            MenuItem("Open", action: "open"),
            MenuItem("Disabled", action: "disabled", enabled: false)
        ])
        @Expect(menu.handle(KeyEvent(KeyCode.Enter)), Some("open"))
        _ = menu.handle(KeyEvent(KeyCode.Down))
        let noAction: ?String = None
        @Expect(menu.handle(KeyEvent(KeyCode.Enter)), noAction)

        let menuBuffer = Buffer(Rect(0, 0, 20, 4))
        menu.render(menuBuffer.area, menuBuffer)
        @Expect(menuBuffer.getCell(0, 0).symbol, "F")

        let bar = MenuBar(["File", "Edit"])
        @Expect(bar.handle(KeyEvent(KeyCode.Right)))
        @Expect(bar.selected, 1)

        let palette = CommandPalette([
            MenuItem("Open File", action: "open"),
            MenuItem("Save File", action: "save")
        ])
        _ = palette.handle(KeyEvent(KeyCode.Char(r's')))
        match (palette.handle(KeyEvent(KeyCode.Enter))) {
            case Some(action) => @Expect(action, "save")
            case None => @Expect(false)
        }

        let toasts = ToastManager(toasts: [Toast("one", ttl: 2), Toast("gone", ttl: 1)])
        toasts.tick()
        @Expect(toasts.count(), 1)
        let toastBuffer = Buffer(Rect(0, 0, 20, 2))
        toasts.render(toastBuffer.area, toastBuffer)
        @Expect(toastBuffer.getCell(0, 0).symbol, "o")

        let spinnerBuffer = Buffer(Rect(0, 0, 12, 1))
        Spinner(label: "Loading", frame: 1).render(spinnerBuffer.area, spinnerBuffer)
        @Expect(spinnerBuffer.getCell(0, 0).symbol, "/")

        let dialog = Dialog(title: "Confirm", body: "Continue?", buttons: ["No", "Yes"])
        _ = dialog.handle(KeyEvent(KeyCode.Right))
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some("Yes"))
    }

    @TestCase
    func componentTreeStylesAndVisualWidgetsWork(): Unit {
        let rootComponent = CountingComponent("root")
        let childComponent = CountingComponent("child")
        let tree = ViewNode("root", component: Some(rootComponent), area: Rect(0, 0, 8, 1), classes: ["panel"])
        tree.add(ViewNode("child", component: Some(childComponent), area: Rect(0, 1, 8, 1), classes: ["panel", "leaf"]))
        @Expect(tree.isDirty())
        tree.clearDirty()
        @Expect(!tree.isDirty())
        tree.setArea(Rect(0, 0, 9, 1))
        @Expect(tree.isDirty())
        @Expect(tree.queryByClass("panel").size, 2)
        let flow = tree.dispatch(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))), focusId: Some("child"))
        match (flow) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }
        @Expect(rootComponent.handled > 0)
        @Expect(childComponent.handled > 0)
        let stringState = StringState(value: "a")
        stringState.set("b")
        @Expect(stringState.isDirty())
        let intState = IntState(value: 1)
        intState.set(2)
        @Expect(intState.get(), 2)

        let sheet = StyleSheet(classes: [StyleClass("danger", normal: Style(fg: Color.Red), focused: Style(bg: Color.White))])
        sheet.addRule(StyleRule(".button", Style(fg: Color.Green), state: StyleState.Selected))
        @Expect(sheet.resolve("danger", state: StyleState.Focused), Style(fg: Color.Red, bg: Color.White))
        @Expect(sheet.resolveSelector(".button", state: StyleState.Selected), Style(fg: Color.Green))
        let css = StyleSheet.parse("screen { color: white; background: blue; display: flex; gap: 1; } .danger:selected { color: red; } #child { width: 3; height: 1; }")
        let dom = ViewNode("root", tag: "screen", area: Rect(0, 0, 8, 2))
        let child = ViewNode("child", tag: "button", classes: ["danger"])
        child.setState("selected")
        dom.add(child)
        css.apply(dom, Rect(0, 0, 8, 2))
        @Expect(dom.computedStyle().style, Style(fg: Color.White, bg: Color.Blue))
        @Expect(child.computedStyle().style, Style(fg: Color.Red, bg: Color.Blue))
        @Expect(child.layoutBox(), Rect(0, 0, 3, 1))
        let domBackend = TestBackend(area: Rect(0, 0, 8, 2))
        Terminal(domBackend).draw { frame => frame.renderNode(dom, css) }
        @Expect(domBackend.assertCell(0, 0, " ", style: Style(fg: Color.Red, bg: Color.Blue)))
        let cascadeCss = StyleSheet.parse("#child { color: yellow; } .danger { color: green; } .danger { background: red; }")
        cascadeCss.apply(dom, Rect(0, 0, 8, 2))
        @Expect(child.computedStyle().style, Style(fg: Color.Yellow, bg: Color.Red))
        let pack = ThemePack("default", tokens: DesignTokens(gap: 2))
        @Expect(pack.tokens.gap, 2)
        @Expect(Theme.default().serialize().contains("normal="))

        let buffer = Buffer(Rect(0, 0, 30, 12))
        Sparkline([1, 2, 3]).render(Rect(0, 0, 5, 1), buffer)
        Gauge(2, total: 4, label: "50").render(Rect(0, 1, 6, 1), buffer)
        Chart([1, 3, 2]).render(Rect(0, 2, 6, 3), buffer)
        DocumentView(Document([DocumentLine(DocumentLineKind.Heading(1), "Title")])).render(Rect(8, 0, 12, 2), buffer)
        LogView(["a", "b", "c"]).render(Rect(8, 2, 5, 2), buffer)
        SplitPane(Paragraph("L"), Paragraph("R")).render(Rect(0, 6, 12, 1), buffer)
        let wizard = Wizard(["One", "Two"], bodies: ["Body"])
        wizard.next()
        wizard.render(Rect(0, 7, 20, 2), buffer)
        let picker = ColorPicker()
        _ = picker.handle(KeyEvent(KeyCode.Right))
        picker.render(Rect(0, 10, 20, 1), buffer)
        match (picker.selectedColor()) {
            case Some(_) => ()
            case None => @Expect(false)
        }
        @Expect(buffer.getCell(8, 0).symbol, "#")
        @Expect(buffer.getCell(10, 0).symbol, "T")
    }

    @TestCase
    func documentViewRendersStructuredDocument(): Unit {
        let buffer = Buffer(Rect(0, 0, 24, 6))
        let doc = Document([
            DocumentLine(DocumentLineKind.Heading(1), "Title", style: Style(fg: Color.Yellow)),
            DocumentLine(DocumentLineKind.ListItem(false), "item"),
            DocumentLine(DocumentLineKind.Quote, "note"),
            DocumentLine(DocumentLineKind.CodeBlock, "let x = 1"),
            DocumentLine(DocumentLineKind.TableRow, "a | b")
        ])
        DocumentView(doc).render(Rect(0, 0, 24, 6), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(2, 0).symbol, "T")
        @Expect(buffer.getCell(0, 1).symbol, "*")
        @Expect(buffer.getCell(0, 2).symbol, "|")
        @Expect(buffer.getCell(0, 3).symbol, "l")
        @Expect(buffer.getCell(0, 4).symbol, "a")
    }

    @TestCase
    func documentViewStylesHeadingLevels(): Unit {
        let doc = Document([
            DocumentLine(DocumentLineKind.Heading(1), "One"),
            DocumentLine(DocumentLineKind.Heading(2), "Two"),
            DocumentLine(DocumentLineKind.Heading(3), "Three"),
            DocumentLine(DocumentLineKind.Heading(6), "Six")
        ])
        let buffer = Buffer(Rect(0, 0, 20, 4))
        DocumentView(doc).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, DocumentTheme().headingStyle(1))
        @Expect(buffer.getCell(0, 1).style, DocumentTheme().headingStyle(2))
        @Expect(buffer.getCell(0, 2).style, DocumentTheme().headingStyle(3))
        @Expect(buffer.getCell(0, 3).style, DocumentTheme().headingStyle(6))
        @Expect(buffer.getCell(2, 0).style, buffer.getCell(0, 0).style)
        @Expect(buffer.getCell(3, 1).style, buffer.getCell(0, 1).style)
        @Expect(buffer.getCell(4, 2).style, buffer.getCell(0, 2).style)
        @Expect(buffer.getCell(7, 3).style, buffer.getCell(0, 3).style)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(0, 1).symbol, "#")
        @Expect(buffer.getCell(1, 1).symbol, "#")
        @Expect(buffer.getCell(5, 3).symbol, "#")
        @Expect(buffer.getCell(7, 3).symbol, "S")
        @Expect(buffer.getCell(0, 0).style != buffer.getCell(0, 1).style)
    }

    @TestCase
    func documentViewRendersRichSpanStyles(): Unit {
        let buffer = Buffer(Rect(0, 0, 24, 2))
        let doc = Document([
            DocumentLine(DocumentLineKind.Paragraph, [
                RichSpan("plain ", style: Style(fg: Color.White)),
                RichSpan("link", style: Style(fg: Color.Blue))
            ])
        ])
        DocumentView(doc).render(Rect(0, 0, 24, 2), buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.White))
        @Expect(buffer.getCell(6, 0).symbol, "l")
        @Expect(buffer.getCell(6, 0).style, Style(fg: Color.Blue))
    }

    @TestCase
    func documentViewRendersExtendedDocumentLinesAndWrappedSpanStyles(): Unit {
        let buffer = Buffer(Rect(0, 0, 20, 8))
        let doc = Document([
            DocumentLine(DocumentLineKind.TaskListItem(true), "done"),
            DocumentLine(DocumentLineKind.HorizontalRule, ""),
            DocumentLine(DocumentLineKind.Image, "alt image"),
            DocumentLine(DocumentLineKind.Diagnostic, "warning"),
            DocumentLine(DocumentLineKind.Html, "<b>x</b>"),
            DocumentLine(DocumentLineKind.TableHeader, "A | B"),
            DocumentLine(DocumentLineKind.Strikethrough, "old")
        ])
        DocumentView(doc).render(Rect(0, 0, 12, 7), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "[")
        @Expect(buffer.getCell(0, 1).symbol, "-")
        @Expect(buffer.getCell(0, 2).symbol, "!")
        @Expect(buffer.getCell(0, 3).symbol, "!")
        @Expect(buffer.getCell(0, 4).symbol, "<")
        @Expect(buffer.getCell(0, 5).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))

        let wrapped = Document([
            DocumentLine(DocumentLineKind.Paragraph, [
                RichSpan("abcdef", style: Style(fg: Color.Blue)),
                RichSpan("ghijk", style: Style(fg: Color.Red))
            ])
        ])
        DocumentView(wrapped).render(Rect(0, 7, 6, 2), buffer)
        @Expect(buffer.getCell(0, 7).style, Style(fg: Color.Blue))
        @Expect(DocumentView(wrapped).renderedLineCount(6) >= 1)

        let mediaSource = MediaSource("logo", "logo.png", alt: "Logo")
        let mediaBuffer = Buffer(Rect(0, 0, 20, 8))
        DocumentView(Document([DocumentLine.image(mediaSource, mediaHeight: 3)])).render(Rect(0, 0, 20, 8), mediaBuffer)
        @Expect(mediaBuffer.mediaPlacements().size, 1)
        @Expect(mediaBuffer.mediaPlacements()[0].area.height, 3)

        let domBackend = TestBackend(area: Rect(0, 0, 12, 4))
        let node = ViewNode("hero", tag: "img", inlineStyle: StyleDeclaration.parse("width: 8; height: 2; object-fit: cover")).setMedia(mediaSource)
        Terminal(domBackend).draw { frame => frame.renderNode(node, StyleSheet()) }
        @Expect(domBackend.assertLastMediaOpCount(1))
        @Expect(domBackend.lastMediaOps()[0].placement.area.width, 8)

        let sourced = DocumentView(Document([DocumentLine(DocumentLineKind.Paragraph, [RichSpan("abc", sourceRange: Some("12:15"))])]))
        match (sourced.sourceOffsetForRenderedLine(10, 0)) {
            case Some(offset) => @Expect(offset, 12)
            case None => @Expect(false)
        }

        @Expect(sourced.renderedLineForSourceOffset(10, 14), 0)
        let highlighted = Buffer(Rect(0, 0, 12, 1))
        DocumentView(
            Document([DocumentLine(DocumentLineKind.Paragraph, "alpha beta")]),
            highlights: [DocumentHighlight("beta")]
        ).render(Rect(0, 0, 12, 1), highlighted)
        @Expect(highlighted.getCell(6, 0).style, Style(bg: Color.Yellow))
        let highlightedHeading = Buffer(Rect(0, 0, 20, 1))
        DocumentView(
            Document([DocumentLine(DocumentLineKind.Heading(3), "Three")]),
            highlights: [DocumentHighlight("#")]
        ).render(Rect(0, 0, 20, 1), highlightedHeading)
        @Expect(highlightedHeading.getCell(0, 0).style, DocumentTheme().headingStyle(3).patch(Style(bg: Color.Yellow)))
        @Expect(highlightedHeading.getCell(4, 0).style, DocumentTheme().headingStyle(3))

        let state = DocumentViewState(cursorSourceOffset: Some(25))
        state.setFolded(10, 20, true)
        let interactive = Document([
            DocumentLine(DocumentLineKind.Heading(1), [RichSpan("Head", sourceRange: Some("10:20"))]),
            DocumentLine(DocumentLineKind.Paragraph, [RichSpan("hidden", sourceRange: Some("12:18"))]),
            DocumentLine(DocumentLineKind.Paragraph, [RichSpan("active", sourceRange: Some("25:30"), linkUrl: Some("https://example.com"))])
        ])
        let interactiveBuffer = Buffer(Rect(0, 0, 20, 3))
        let interactiveView = DocumentView(interactive, state: Some(state))
        interactiveView.render(interactiveBuffer.area, interactiveBuffer)
        @Expect(interactiveBuffer.getCell(0, 0).symbol, "#")
        @Expect(interactiveBuffer.getCell(2, 0).symbol, "H")
        @Expect(interactiveBuffer.getCell(0, 1).symbol, "a")
        @Expect(interactiveBuffer.getCell(0, 1).style, Style(bg: Color.Indexed(8)))
        match (interactiveView.linkAtRenderedLine(20, 1)) {
            case Some(url) => @Expect(url, "https://example.com")
            case None => @Expect(false)
        }
        @Expect(interactiveView.handleKey(KeyEvent(KeyCode.Down), 20, 1))
        @Expect(state.scroll, 1)
    }

    @TestCase
    func gridFlexCacheAndAdditionalControlsWork(): Unit {
        let grid = Grid([Constraint.Length(2), Constraint.Min(1)], [Constraint.Percent(50), Constraint.Min(1)], gap: 1)
        let cells = grid.split(Rect(0, 0, 20, 6))
        @Expect(cells.size, 2)
        @Expect(cells[0].size, 2)

        let flex = FlexLayout(Direction.Horizontal, [FlexItem(basis: 4, grow: 1), FlexItem(basis: 4, grow: 1)], gap: 1)
        let flexed = flex.split(Rect(0, 0, 13, 1))
        @Expect(flexed[0].width, 6)

        let cache = LayoutCache()
        let cached = cache.get(Rect(0, 0, 10, 1), { area => Layout.horizontal([Constraint.Length(5), Constraint.Min(1)]).split(area) })
        @Expect(cached.size, 2)

        let out = Buffer(Rect(0, 0, 40, 16))
        let multi = MultiSelect(["a", "b"])
        @Expect(multi.handle(KeyEvent(KeyCode.Char(r' '))))
        @Expect(multi.selectedIndices().size, 1)
        multi.render(Rect(0, 0, 10, 2), out)

        let date = DatePicker(year: 2026, month: 5, day: 28)
        _ = date.handle(KeyEvent(KeyCode.Right))
        @Expect(date.value(), "2026-05-29")
        date.render(Rect(0, 2, 12, 1), out)

        Accordion(["One", "Two"], bodies: ["Body"]).render(Rect(0, 3, 16, 4), out)
        Breadcrumb(["home", "docs"]).render(Rect(0, 7, 20, 1), out)
        TreeTable(Tree([TreeNode("r", "Root")]), Table(["A"], [["1"]])).render(Rect(0, 8, 24, 3), out)
        let fileDialog = FileDialog(path: ".", extension: ".cj")
        fileDialog.render(Rect(0, 11, 16, 3), out)
        let confirm = ConfirmDialog("Continue?")
        @Expect(confirm.handle(KeyEvent(KeyCode.Char(r'y'))), Some(true))

        let highlighter = SyntaxHighlighter(rules: [SyntaxRule("error", Style(fg: Color.Red))])
        @Expect(highlighter.styleFor("has error"), Style(fg: Color.Red))
        SoftWrapView("hello world").render(Rect(18, 0, 8, 3), out)
        let editor = TextEditor(value: "one")
        editor.render(Rect(18, 4, 16, 5), out)
    }

    @TestCase
    func textAreaEditsMultipleLinesAndMovesCursor(): Unit {
        let area = TextArea(value: "one\ntwo", cursor: 3)
        @Expect(area.handle(KeyEvent(KeyCode.Enter)))
        @Expect(area.value, "one\n\ntwo")
        @Expect(area.handle(KeyEvent(KeyCode.Down)))
        area.render(Rect(0, 0, 6, 3), Buffer(Rect(0, 0, 6, 3)))
        let pos = area.cursorPosition(Rect(0, 0, 6, 3))
        @Expect(pos.y >= 0)

        let chinese = TextArea()
        @Expect(chinese.handle(KeyEvent(KeyCode.Char(r'中'))))
        @Expect(chinese.handle(KeyEvent(KeyCode.Char(r'文'))))
        @Expect(chinese.value, "中文")
        @Expect(chinese.cursor, "中文".size)
        @Expect(chinese.handle(KeyEvent(KeyCode.Left)))
        @Expect(chinese.cursor, "中".size)
        @Expect(chinese.handle(KeyEvent(KeyCode.Backspace)))
        @Expect(chinese.value, "文")
        @Expect(chinese.cursor, 0)

        let wideCursor = TextArea(value: "中a文", cursor: "中a".size)
        let widePos = wideCursor.cursorPosition(Rect(0, 0, 20, 1))
        @Expect(widePos.x, 3)

        let vim = TextArea(value: "one\ntwo three", cursor: 0)
        @Expect(vim.handleVimNavigation(KeyEvent(KeyCode.Char(r'j'))))
        @Expect(vim.cursor, 4)
        @Expect(vim.handleVimNavigation(KeyEvent(KeyCode.Char(r'l'))))
        @Expect(vim.cursor, 5)
        @Expect(vim.handleVimNavigation(KeyEvent(KeyCode.Char(r'w'))))
        @Expect(vim.cursor, 8)
        @Expect(vim.handleVimNavigation(KeyEvent(KeyCode.Char(r'b'))))
        @Expect(vim.cursor, 4)
        @Expect(vim.handleVimNavigation(KeyEvent(KeyCode.Char(r'G'))))
        @Expect(vim.cursor, vim.value.size)
    }

    @TestCase
    func textAreaSelectionPasteFindAndWordMovement(): Unit {
        let area = TextArea(value: "alpha beta gamma", cursor: 0)
        area.select(6, 10)
        @Expect(area.selectedText(), "beta")
        area.paste("BETA")
        @Expect(area.value, "alpha BETA gamma")
        @Expect(area.undo())
        @Expect(area.value, "alpha beta gamma")
        @Expect(area.redo())
        @Expect(area.value, "alpha BETA gamma")
        @Expect(area.findNext("gamma"), Some(11))
        @Expect(area.selectedText(), "gamma")
        area.clearSelection()
        area.moveWordLeft()
        @Expect(area.cursor, 6)
        area.moveWordRight()
        @Expect(area.cursor, 11)

        let buffer = Buffer(Rect(0, 0, 20, 1))
        area.select(0, 5)
        area.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Black, bg: Color.White))
    }

    @TestCase
    func textAreaSupportsMultipleCaretsAndSelections(): Unit {
        let area = TextArea(value: "one\ntwo", cursor: 0)
        area.setCarets([TextAreaCaret(0), TextAreaCaret(4)])
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'>'))))
        @Expect(area.value, ">one\n>two")
        @Expect(area.carets().size, 2)
        @Expect(area.carets()[0].offset, 1)
        @Expect(area.carets()[1].offset, 6)
        @Expect(area.undo())
        @Expect(area.value, "one\ntwo")

        area.setCarets([TextAreaCaret(0, anchor: Some(3)), TextAreaCaret(4, anchor: Some(7))])
        @Expect(area.selectedTexts().size, 2)
        @Expect(area.selectedTexts()[0], "one")
        @Expect(area.selectedTexts()[1], "two")
        area.paste("x")
        @Expect(area.value, "x\nx")
        let selected = Buffer(Rect(0, 0, 8, 2))
        area.setCarets([TextAreaCaret(0, anchor: Some(1)), TextAreaCaret(2, anchor: Some(3))])
        area.render(selected.area, selected)
        @Expect(selected.getCell(0, 0).style, Style(fg: Color.Black, bg: Color.White))
        @Expect(selected.getCell(0, 1).style, Style(fg: Color.Black, bg: Color.White))
    }

    @TestCase
    func textAreaUsesFoldStateAndMouseEditing(): Unit {
        let folds = DocumentViewState()
        folds.setFolded(0, 7, true)
        let area = TextArea(value: "one\ntwo\nthree", foldState: Some(folds), lineNumbers: true)
        let folded = Buffer(Rect(0, 0, 12, 3))
        area.render(folded.area, folded)
        @Expect(folded.getCell(0, 0).symbol, "1")
        @Expect(folded.getCell(0, 1).symbol, "3")
        @Expect(folded.getCell(7, 0).symbol, ".")

        @Expect(area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 0, 1), folded.area))
        @Expect(area.cursor, 8)
        @Expect(area.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 1), folded.area))
        @Expect(area.cursor, 8)
        @Expect(area.handleMouse(MouseEvent(MouseKind.Drag, MouseButton.Left, 6, 1), folded.area))
        @Expect(area.selectedText(), "thr")
        @Expect(area.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 7, 1), folded.area))
    }

    @TestCase
    func textAreaSupportsAsyncCompletionResults(): Unit {
        let area = TextArea(value: "pri", cursor: 3)
        let command = area.completionCommand("complete-1", { request =>
            @Expect(request.prefix, "pri")
            TextCompletionResult(
                request.requestId,
                request.revision,
                request.prefixStart,
                request.prefixEnd,
                [TextCompletionItem("print"), TextCompletionItem("private", detail: "keyword")]
            )
        })
        let queue = ArrayList<Command>()
        @Expect(App.applyUpdateResult(UpdateResult.withCommand(command), queue))
        let runtime = AsyncRuntime()
        @Expect(App.processCommands({ event =>
            _ = area.handleCompletionEvent(event)
            UpdateResult.next()
        }, queue, asyncRuntime: runtime))
        while (runtime.pendingCount() > 0) {
            @Expect(App.processCommands({ event =>
                _ = area.handleCompletionEvent(event)
                UpdateResult.next()
            }, queue, asyncRuntime: runtime))
        }
        @Expect(area.handle(KeyEvent(KeyCode.Down)))
        @Expect(area.handle(KeyEvent(KeyCode.Enter)))
        @Expect(area.value, "private")

        let cancellable = area.beginCompletion("cancel")
        @Expect(area.handleCompletionEvent(Event.TextCompletion(
            "cancel",
            TextCompletionResult(
                cancellable.requestId,
                cancellable.revision,
                cancellable.prefixStart,
                cancellable.prefixEnd,
                [TextCompletionItem("private")]
            )
        )))
        @Expect(area.completionVisible())
        @Expect(area.cancelCompletion())
        @Expect(!area.completionVisible())
        @Expect(!area.cancelCompletion())

        let staleRequest = area.beginCompletion("stale")
        area.paste("!")
        let stale = Event.TextCompletion("stale", TextCompletionResult(staleRequest.requestId, staleRequest.revision, staleRequest.prefixStart, staleRequest.prefixEnd, [TextCompletionItem("ignored")]))
        @Expect(!area.handleCompletionEvent(stale))

        let long = TextArea()
        let longRequest = long.beginCompletion("long")
        @Expect(long.handleCompletionEvent(Event.TextCompletion(
            "long",
            TextCompletionResult(
                longRequest.requestId,
                longRequest.revision,
                longRequest.prefixStart,
                longRequest.prefixEnd,
                [
                    TextCompletionItem("zero"),
                    TextCompletionItem("one"),
                    TextCompletionItem("two"),
                    TextCompletionItem("three"),
                    TextCompletionItem("four"),
                    TextCompletionItem("five"),
                    TextCompletionItem("six")
                ]
            )
        )))
        for (_ in 0..5) {
            @Expect(long.handle(KeyEvent(KeyCode.Down)))
        }
        @Expect(long.completionRows(), 5)
        let completionBuffer = Buffer(Rect(0, 0, 20, 6))
        long.renderCompletionOverlay(completionBuffer.area, completionBuffer)
        @Expect(completionBuffer.getCell(2, 1).symbol, "t")
        @Expect(completionBuffer.getCell(0, 4).symbol, ">")
        @Expect(completionBuffer.getCell(3, 4).symbol, "i")
        @Expect(completionBuffer.getCell(2, 5).symbol, "s")
        @Expect(long.handle(KeyEvent(KeyCode.Tab)))
        @Expect(long.value, "five")
    }

    @TestCase
    func textAreaSupportsReadlineStyleControlKeys(): Unit {
        let move = TextArea(value: "zero\nalpha beta\ngamma", cursor: 10)
        @Expect(move.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true))))
        @Expect(move.cursor, 5)
        @Expect(move.handle(KeyEvent(KeyCode.Char(r'e'), modifiers: KeyModifier(ctrl: true))))
        @Expect(move.cursor, 15)
        @Expect(move.handle(KeyEvent(KeyCode.Char(r'b'), modifiers: KeyModifier(ctrl: true))))
        @Expect(move.cursor, 14)
        @Expect(move.handle(KeyEvent(KeyCode.Char(r'f'), modifiers: KeyModifier(ctrl: true))))
        @Expect(move.cursor, 15)

        let killStart = TextArea(value: "zero\nalpha beta\ngamma", cursor: 10)
        @Expect(killStart.handle(KeyEvent(KeyCode.Char(r'u'), modifiers: KeyModifier(ctrl: true))))
        @Expect(killStart.value, "zero\n beta\ngamma")
        @Expect(killStart.cursor, 5)
        @Expect(killStart.handle(KeyEvent(KeyCode.Char(r'z'), modifiers: KeyModifier(ctrl: true))))
        @Expect(killStart.value, "zero\nalpha beta\ngamma")

        let killEnd = TextArea(value: "zero\nalpha beta\ngamma", cursor: 10)
        @Expect(killEnd.handle(KeyEvent(KeyCode.Char(r'k'), modifiers: KeyModifier(ctrl: true))))
        @Expect(killEnd.value, "zero\nalpha\ngamma")
        @Expect(killEnd.cursor, 10)

        let killWord = TextArea(value: "zero\nalpha beta\ngamma", cursor: 15)
        @Expect(killWord.handle(KeyEvent(KeyCode.Char(r'w'), modifiers: KeyModifier(ctrl: true))))
        @Expect(killWord.value, "zero\nalpha \ngamma")
        @Expect(killWord.cursor, 11)

        let unbound = TextArea(value: "safe", cursor: 4)
        @Expect(!unbound.handle(KeyEvent(KeyCode.Char(r'p'), modifiers: KeyModifier(ctrl: true))))
        @Expect(unbound.value, "safe")

        let readOnly = TextArea(value: "locked", cursor: 3, readOnly: true)
        @Expect(!readOnly.handle(KeyEvent(KeyCode.Char(r'u'), modifiers: KeyModifier(ctrl: true))))
        @Expect(readOnly.value, "locked")

        let composer = Composer(value: "alpha beta")
        composer.area.cursor = 5
        match (composer.handle(KeyEvent(
            KeyCode.Char(r'u'),
            modifiers: KeyModifier(ctrl: true)
        ))) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        @Expect(composer.area.value, " beta")
        @Expect(composer.area.cursor, 0)
    }

    @TestCase
    func textAreaSupportsPagingControlKeysAndLineNumbers(): Unit {
        let area = TextArea(value: "one\ntwo\nthree\nfour\nfive\nsix", cursor: 0, lineNumbers: true)
        @Expect(area.handle(KeyEvent(KeyCode.PageDown)))
        @Expect(area.cursor > 0)
        @Expect(area.handle(KeyEvent(KeyCode.Home, modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, 0)
        @Expect(area.handle(KeyEvent(KeyCode.End, modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, area.value.size)
        @Expect(area.handle(KeyEvent(KeyCode.Home, modifiers: KeyModifier(ctrl: true))))
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'Z'))))
        @Expect(area.value.startsWith("Z"))
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'z'), modifiers: KeyModifier(ctrl: true))))
        @Expect(!area.value.startsWith("Z"))

        let md = TextArea(value: "- item", cursor: 6, markdownEditing: true)
        @Expect(md.handle(KeyEvent(KeyCode.Enter)))
        @Expect(md.value, "- item\n- ")
        let ordered = TextArea(value: "1. one", cursor: 6, markdownEditing: true)
        @Expect(ordered.handle(KeyEvent(KeyCode.Enter)))
        @Expect(ordered.value, "1. one\n2. ")
        let task = TextArea(value: "- [x] done", cursor: 10, markdownEditing: true)
        @Expect(task.handle(KeyEvent(KeyCode.Enter)))
        @Expect(task.value, "- [x] done\n- [ ] ")
        let emptyItem = TextArea(value: "- item\n- ", cursor: 9, markdownEditing: true)
        @Expect(emptyItem.handle(KeyEvent(KeyCode.Enter)))
        @Expect(emptyItem.value, "- item\n")
        @Expect(md.handle(KeyEvent(KeyCode.Tab)))
        @Expect(md.value, "- item\n  - ")
        @Expect(md.handle(KeyEvent(KeyCode.BackTab)))
        @Expect(md.value, "- item\n- ")
        let selectedLines = TextArea(value: "- a\n- b", cursor: 0, markdownEditing: true)
        selectedLines.select(0, selectedLines.value.size)
        @Expect(selectedLines.handle(KeyEvent(KeyCode.Tab)))
        @Expect(selectedLines.value, "  - a\n  - b")
        @Expect(selectedLines.handle(KeyEvent(KeyCode.BackTab)))
        @Expect(selectedLines.value, "- a\n- b")

        let ro = TextArea(value: "locked", cursor: 0, readOnly: true)
        @Expect(!ro.handle(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(ro.value, "locked")

        let behavior = MarkdownEditorBehavior()
        let behaviorArea = TextArea(value: "word", cursor: 0, markdownEditing: true)
        behaviorArea.select(0, 4)
        @Expect(behavior.toggleBold(behaviorArea))
        @Expect(behaviorArea.value, "**word**")
        let chineseBold = TextArea(value: "中文", cursor: 0, markdownEditing: true)
        chineseBold.select(0, chineseBold.value.size)
        @Expect(behavior.toggleBold(chineseBold))
        @Expect(chineseBold.value, "**中文**")
        behaviorArea.cursor = behaviorArea.value.size
        @Expect(behavior.handle(behaviorArea, KeyEvent(KeyCode.Char(r'['))))
        @Expect(behaviorArea.value.endsWith("[]"))
        let chineseList = TextArea(value: "- 中文", cursor: "- 中文".size, markdownEditing: true)
        @Expect(behavior.handle(chineseList, KeyEvent(KeyCode.Enter)))
        @Expect(chineseList.value, "- 中文\n- ")
        let linkWrap = TextArea(value: "docs", cursor: 0, markdownEditing: true)
        linkWrap.select(0, 4)
        @Expect(behavior.handle(linkWrap, KeyEvent(KeyCode.Char(r'['))))
        @Expect(linkWrap.value, "[docs]()")
        @Expect(linkWrap.cursor, 7)
        let chineseLink = TextArea(value: "链接", cursor: 0, markdownEditing: true)
        chineseLink.select(0, chineseLink.value.size)
        @Expect(behavior.handle(chineseLink, KeyEvent(KeyCode.Char(r'['))))
        @Expect(chineseLink.value, "[链接]()")
        @Expect(chineseLink.cursor, "[链接](".size)
        let codeWrap = TextArea(value: "code", cursor: 0, markdownEditing: true)
        codeWrap.select(0, 4)
        @Expect(behavior.handle(codeWrap, KeyEvent(KeyCode.Char(r'`'))))
        @Expect(codeWrap.value, "`code`")
        let parenWrap = TextArea(value: "x", cursor: 0, markdownEditing: true)
        parenWrap.select(0, 1)
        @Expect(behavior.handle(parenWrap, KeyEvent(KeyCode.Char(r'('))))
        @Expect(parenWrap.value, "(x)")
        let paired = TextArea(markdownEditing: true)
        @Expect(behavior.handle(paired, KeyEvent(KeyCode.Char(r'*'))))
        @Expect(behavior.handle(paired, KeyEvent(KeyCode.Char(r'*'))))
        @Expect(paired.value, "****")
        @Expect(paired.cursor, 2)
        let strike = TextArea(markdownEditing: true)
        @Expect(behavior.handle(strike, KeyEvent(KeyCode.Char(r'~'))))
        @Expect(behavior.handle(strike, KeyEvent(KeyCode.Char(r'~'))))
        @Expect(strike.value, "~~~~")
        @Expect(strike.cursor, 2)
        let image = TextArea(value: "图示", cursor: 0, markdownEditing: true)
        image.select(0, image.value.size)
        @Expect(behavior.insertImage(image, url: "img.png"))
        @Expect(image.value, "![图示](img.png)")
        let refLink = TextArea(value: "参考", cursor: 0, markdownEditing: true)
        refLink.select(0, refLink.value.size)
        @Expect(behavior.insertReferenceLink(refLink, id: "docs"))
        @Expect(refLink.value, "[参考][docs]")
        let refDef = TextArea(markdownEditing: true)
        @Expect(behavior.insertReferenceDefinition(refDef, id: "docs", url: "https://example.com", title: "Docs"))
        @Expect(refDef.value, "[docs]: https://example.com \"Docs\"\n")
        let frontmatter = TextArea(value: "# Title", cursor: 0, markdownEditing: true)
        @Expect(behavior.insertFrontmatter(frontmatter, title: "Doc"))
        @Expect(frontmatter.value.startsWith("---\ntitle: Doc\n---\n\n# Title"))
        let highlightedMd = TextArea(value: "# 标题\n- [x] 任务\n> 引用\n| 名 | 值 |\n`代码`\n[链接](url)\n```\n围栏\n```", markdownEditing: true)
        behavior.applyHighlights(highlightedMd)
        let highlightedOut = Buffer(Rect(0, 0, 20, 9))
        highlightedMd.render(highlightedOut.area, highlightedOut)
        @Expect(highlightedOut.getCell(0, 0).style, Style(fg: Color.Yellow, modifier: Modifier.strong()))
        @Expect(highlightedOut.getCell(0, 1).style, Style(fg: Color.Cyan))
        @Expect(highlightedOut.getCell(2, 1).style, Style(fg: Color.Yellow))
        @Expect(highlightedOut.getCell(0, 2).style, Style(fg: Color.Green))
        @Expect(highlightedOut.getCell(0, 3).style, Style(fg: Color.Cyan))
        @Expect(highlightedOut.getCell(0, 4).style, Style(fg: Color.Magenta))
        @Expect(highlightedOut.getCell(0, 5).style, Style(fg: Color.Blue))
        @Expect(highlightedOut.getCell(0, 7).style, Style(fg: Color.Magenta))
        let chineseTable = TextArea(value: "| 姓名 | 角色 | 状态 |\n| --- | --- | --- |\n| 张三 | 开发者 | 正常 |\n| 李四 | 测试员 | 休假 |", markdownEditing: true)
        behavior.applyHighlights(chineseTable)
        let chineseTableOut = Buffer(Rect(0, 0, 30, 4))
        chineseTable.render(chineseTableOut.area, chineseTableOut)
        @Expect(chineseTableOut.getCell(0, 0).style, Style(fg: Color.Cyan))
        @Expect(chineseTableOut.getCell(0, 1).style, Style(fg: Color.Cyan))
        @Expect(chineseTableOut.getCell(0, 2).style, Style(fg: Color.Cyan))
        @Expect(chineseTableOut.getCell(0, 3).style, Style(fg: Color.Cyan))
        let combined = TextArea(value: "***粗斜***", markdownEditing: true)
        behavior.applyHighlights(combined)
        let combinedOut = Buffer(Rect(0, 0, 20, 1))
        combined.render(combinedOut.area, combinedOut)
        @Expect(combinedOut.getCell(0, 0).style, Style(fg: Color.White, modifier: strongItalicTestModifier()))
        var largeDoc = ""
        for (i in 0..2000) {
            largeDoc += "- item ${i}\n"
        }
        let highlightCache = MarkdownHighlightCache()
        @Expect(highlightCache.visibleHighlights(largeDoc, firstLine: 1000, lineCount: 10).size, 10)
        @Expect(highlightCache.recomputeCount(), 1)
        _ = highlightCache.visibleHighlights(largeDoc, firstLine: 1010, lineCount: 10)
        @Expect(highlightCache.recomputeCount(), 1)

        let buffers = BufferSet()
        @Expect(buffers.add(EditorBuffer(path: "a.md", title: "A", value: "a", markdownEditing: true)), 0)
        @Expect(buffers.add(EditorBuffer(path: "b.md", title: "B", value: "b")), 1)
        @Expect(buffers.openOrSelect(EditorBuffer(path: "a.md", title: "A2")), 0)
        @Expect(buffers.size(), 2)
        match (buffers.activeBuffer()) {
            case Some(buffer) => @Expect(buffer.title, "A")
            case None => @Expect(false)
        }
        @Expect(buffers.tabTitles()[0], "A")
        match (buffers.next()) {
            case Some(buffer) => @Expect(buffer.title, "B")
            case None => @Expect(false)
        }
        match (buffers.previous()) {
            case Some(buffer) => @Expect(buffer.title, "A")
            case None => @Expect(false)
        }
        match (buffers.activeBuffer()) {
            case Some(buffer) =>
                buffer.setReadOnly(true)
                @Expect(buffer.textArea.readOnly)
                buffer.markSaveFailed("denied")
                match (buffer.lastError) {
                    case Some(error) => @Expect(error.message, "denied")
                    case None => @Expect(false)
                }
            case None => @Expect(false)
        }
        @Expect(buffers.recentFiles().size, 2)

        let buffer = Buffer(Rect(0, 0, 12, 2))
        area.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "1")

        area.select(0, 3)
        let clipboard = MemoryClipboard()
        @Expect(area.copySelectionTo(clipboard))
        @Expect(clipboard.getText(), "one")
        @Expect(area.cutSelectionTo(clipboard))
        area.pasteFrom(clipboard)
    }

    @TestCase
    func keyMapAndHelpViewMatchBindings(): Unit {
        let keymap = KeyMap()
        keymap.add(KeyBinding([KeyEvent(KeyCode.Char(r'j')), KeyEvent(KeyCode.Down)], "down", description: "Move down"))
        @Expect(keymap.actionFor(KeyEvent(KeyCode.Down)), Some("down"))
        let buffer = Buffer(Rect(0, 0, 20, 1))
        HelpView(keymap).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "j")
    }

    @TestCase
    func screenStackModalTabsAndViewportRender(): Unit {
        let stack = ScreenStack()
        stack.push(DemoScreen("one"))
        stack.replace(DemoScreen("two"))
        @Expect(stack.size(), 1)
        match (stack.current()) {
            case Some(_) => ()
            case None => @Expect(false)
        }

        let buffer = Buffer(Rect(0, 0, 24, 8))
        buffer.fill(buffer.area, Cell("X"))
        Modal(
            title: "M",
            body: "Hello modal",
            buttons: ["OK"],
            width: 12,
            height: 5,
            style: Style(fg: Color.White, bg: Color.Blue)
        ).render(buffer.area, buffer)
        @Expect(buffer.getCell(8, 1).symbol, "M")
        @Expect(buffer.getCell(16, 3).symbol, " ")
        @Expect(buffer.getCell(16, 3).style, Style(fg: Color.White, bg: Color.Blue))

        let tabs = Tabs(["A", "B"], selected: 0)
        @Expect(tabs.handle(KeyEvent(KeyCode.Right)))
        @Expect(tabs.selected, 1)
        tabs.render(Rect(0, 6, 10, 1), buffer)
        @Expect(buffer.getCell(4, 6).symbol, "B")

        let viewport = Viewport(["0", "1", "2"], offset: 1)
        viewport.render(Rect(12, 6, 4, 1), buffer)
        @Expect(buffer.getCell(12, 6).symbol, "1")

        let statusBuffer = Buffer(Rect(0, 0, 32, 1))
        StatusBar(
            left: "navigation",
            right: "ready",
            progress: Some(StatusBarProgress(5, total: 10, width: 10))
        ).render(statusBuffer.area, statusBuffer)
        @Expect(statusBuffer.getCell(0, 0).symbol, "n")
        @Expect(statusBuffer.getCell(16, 0).symbol, "=")
        @Expect(statusBuffer.getCell(19, 0).symbol, "5")
        @Expect(statusBuffer.getCell(21, 0).symbol, "%")
        @Expect(statusBuffer.getCell(27, 0).symbol, "r")
    }

    @TestCase
    func dataWidgetsRenderVirtualRowsTreeAndPagination(): Unit {
        let paginator = Paginator(pageSize: 2, total: 5)
        paginator.next()
        @Expect(paginator.page, 1)
        @Expect(paginator.offset(), 2)

        let table = VirtualTable(
            [TableColumn("Name", width: 5)],
            100,
            { index =>
                ["r${index}"]
            }
        )
        let tableBuffer = Buffer(Rect(0, 0, 8, 3))
        table.render(tableBuffer.area, tableBuffer)
        @Expect(tableBuffer.getCell(0, 1).symbol, "r")
        @Expect(tableBuffer.getCell(1, 2).symbol, "1")

        let child = TreeNode("child", "Child")
        let root = TreeNode("root", "Root", expanded: true, children: [child])
        let tree = Tree([root])
        let treeBuffer = Buffer(Rect(0, 0, 12, 2))
        tree.render(treeBuffer.area, treeBuffer)
        @Expect(treeBuffer.getCell(0, 1).symbol, " ")

        let picker = FilePicker(path: "tests/fixtures/file_picker", extension: ".cj")
        let pickerBuffer = Buffer(Rect(0, 0, 20, 2))
        picker.render(pickerBuffer.area, pickerBuffer)
        @Expect(pickerBuffer.getCell(1, 0).symbol, "-")
    }

    @TestCase
    func dataWidgetsHandleNavigationKeys(): Unit {
        let paginator = Paginator(pageSize: 10, total: 35)
        @Expect(paginator.handle(KeyEvent(KeyCode.End)))
        @Expect(paginator.page, 3)
        @Expect(paginator.handle(KeyEvent(KeyCode.Home)))
        @Expect(paginator.page, 0)

        let table = VirtualTable(
            [TableColumn("A", width: 4), TableColumn("B", width: 4)],
            20,
            { index => ["a${index}", "b${index}"] }
        )
        @Expect(table.handle(KeyEvent(KeyCode.PageDown), 3))
        match (table.selectedRow) {
            case Some(row) => @Expect(row, 3)
            case None => @Expect(false)
        }
        @Expect(table.offset, 1)
        @Expect(table.handle(KeyEvent(KeyCode.Right), 3))
        @Expect(table.selectedColumn, 1)

        let child = TreeNode("child", "Child")
        let root = TreeNode("root", "Root", children: [child])
        let tree = Tree([root])
        @Expect(tree.handle(KeyEvent(KeyCode.Right), 3))
        @Expect(root.expanded)
        @Expect(tree.handle(KeyEvent(KeyCode.Left), 3))
        @Expect(!root.expanded)

        let picker = FilePicker(path: "tests/fixtures/file_picker", extension: ".cj")
        @Expect(picker.handle(KeyEvent(KeyCode.End), 3))
        match (picker.selectedEntry()) {
            case Some(_) => ()
            case None => @Expect(false)
        }
    }

    @TestCase
    func advancedDataWidgetsSortFilterTreeFilePickerAndSelect(): Unit {
        let table = VirtualTable(
            [TableColumn("Name", width: 8), TableColumn("Kind", width: 6)],
            3,
            { index =>
                match (index) {
                    case 0 => ["banana", "fruit"]
                    case 1 => ["apple", "fruit"]
                    case _ => ["carrot", "veg"]
                }
            }
        )
        table.sortBy(0)
        @Expect(table.resizeColumn(0, 10))
        table.setFrozenColumns(1)
        let sorted = Buffer(Rect(0, 0, 16, 3))
        table.render(sorted.area, sorted)
        @Expect(sorted.getCell(0, 1).symbol, "a")
        @Expect(sorted.getCell(5, 0).symbol, "^")

        table.setFilter("car")
        let filtered = Buffer(Rect(0, 0, 16, 3))
        table.render(filtered.area, filtered)
        @Expect(filtered.getCell(0, 1).symbol, "c")
        @Expect(table.handle(KeyEvent(KeyCode.Home), 2))
        @Expect(table.handle(KeyEvent(KeyCode.Char(r' ')), 2))
        @Expect(table.selectedRowIndices().size, 1)
        @Expect(table.selectedRowIndices()[0], 2)

        let child = TreeNode("child", "Child")
        let root = TreeNode("root", "Root", children: [child])
        let tree = Tree([root])
        tree.expandAll()
        @Expect(tree.selectById("child"))
        @Expect(tree.selectedId(), Some("child"))
        match (tree.findById("child")) {
            case Some(node) => @Expect(node.label, "Child")
            case None => @Expect(false)
        }
        tree.collapseAll()
        @Expect(tree.selected, 0)

        let picker = FilePicker(path: "tests/fixtures/file_picker", extension: ".cj")
        picker.setSearch("lib")
        @Expect(picker.handle(KeyEvent(KeyCode.Down), 3))
        match (picker.chooseSelected()) {
            case Some(path) => @Expect(path.endsWith("lib.cj"))
            case None => @Expect(false)
        }
        picker.toggleHidden()
        match (picker.selectedInfo()) {
            case Some(info) => @Expect(!info.name.isEmpty())
            case None => @Expect(false)
        }

        let select = Select(["one", "two"])
        _ = select.handle(KeyEvent(KeyCode.Down))
        @Expect(select.handle(KeyEvent(KeyCode.Enter)), Some("two"))

        let dropdown = Dropdown(["red", "green"])
        _ = dropdown.handle(KeyEvent(KeyCode.Enter))
        @Expect(dropdown.open)
        _ = dropdown.handle(KeyEvent(KeyCode.Down))
        @Expect(dropdown.handle(KeyEvent(KeyCode.Enter)), Some("green"))
        @Expect(!dropdown.open)
    }

    @TestCase
    func filePickerUsesDeterministicFixtureForFilteringAndNavigation(): Unit {
        let picker = FilePicker(path: "tests/fixtures/file_picker", extension: ".cj")
        match (picker.selectedEntry()) {
            case Some(entry) => @Expect(entry, "..")
            case None => @Expect(false)
        }

        @Expect(picker.handle(KeyEvent(KeyCode.Down), 4))
        match (picker.selectedInfo()) {
            case Some(info) =>
                @Expect(info.name, "docs")
                @Expect(info.isDir)
            case None => @Expect(false)
        }
        @Expect(picker.enterSelected())
        @Expect(picker.path.endsWith("docs"))
        @Expect(picker.parent())
        @Expect(picker.path.endsWith("file_picker"))

        picker.setSearch("lib")
        @Expect(picker.handle(KeyEvent(KeyCode.Down), 4))
        match (picker.selectedEntry()) {
            case Some(entry) => @Expect(entry, "lib.cj")
            case None => @Expect(false)
        }
        match (picker.chooseSelected()) {
            case Some(path) => @Expect(path.endsWith("lib.cj"))
            case None => @Expect(false)
        }

        picker.setSearch("")
        picker.toggleHidden()
        picker.setSearch(".hidden")
        @Expect(picker.handle(KeyEvent(KeyCode.Down), 4))
        match (picker.selectedEntry()) {
            case Some(entry) => @Expect(entry, ".hidden.cj")
            case None => @Expect(false)
        }

        let dialog = FileDialog(path: "tests/fixtures/file_picker", extension: ".cj", title: "Fixture")
        @Expect(dialog.handle(KeyEvent(KeyCode.Down), 4))
        match (dialog.selectedPath()) {
            case Some(path) => @Expect(path.endsWith("docs"))
            case None => @Expect(false)
        }
    }

    @TestCase
    func textBufferSupportsUndoRedoAndFind(): Unit {
        let buffer = TextBuffer(text: "one")
        let pos = buffer.insert(TextPosition(0, 3), "\ntwo")
        @Expect(pos, TextPosition(1, 3))
        @Expect(buffer.text(), "one\ntwo")
        match (buffer.find("two")) {
            case Some(found) => @Expect(found, TextPosition(1, 0))
            case None => @Expect(false)
        }
        @Expect(buffer.undo())
        @Expect(buffer.text(), "one")
        @Expect(buffer.redo())
        @Expect(buffer.text(), "one\ntwo")
    }

    @TestCase
    func textBufferSupportsRangesAndWordNavigation(): Unit {
        let buffer = TextBuffer(text: "alpha beta\ngamma")
        @Expect(buffer.slice(TextRange(TextPosition(0, 6), TextPosition(1, 5))), "beta\ngamma")
        let pos = buffer.replace(TextRange(TextPosition(0, 6), TextPosition(0, 10)), "BETA")
        @Expect(pos, TextPosition(0, 10))
        @Expect(buffer.text(), "alpha BETA\ngamma")
        @Expect(buffer.wordLeft(TextPosition(0, 10)), TextPosition(0, 6))
        @Expect(buffer.wordRight(TextPosition(0, 0)), TextPosition(0, 6))
        match (buffer.findPrevious("alpha")) {
            case Some(found) => @Expect(found, TextPosition(0, 0))
            case None => @Expect(false)
        }
    }

    @TestCase
    func textBufferFindsReplacesAndGroupsUndo(): Unit {
        let buffer = TextBuffer(text: "one two one")
        let found = buffer.findAll("one")
        @Expect(found.size, 2)
        @Expect(buffer.replaceAll("one", "1"), 2)
        @Expect(buffer.text(), "1 two 1")
        @Expect(buffer.undo())
        @Expect(buffer.text(), "one two one")

        buffer.beginUndoGroup()
        _ = buffer.insert(TextPosition(0, 0), "A")
        _ = buffer.insert(TextPosition(0, 1), "B")
        buffer.endUndoGroup()
        @Expect(buffer.text(), "ABone two one")
        @Expect(buffer.undo())
        @Expect(buffer.text(), "one two one")

        let searchPanel = SearchPanel(query: "one")
        searchPanel.updateFrom(buffer)
        let replacePanel = ReplacePanel(query: "one", replacement: "ONE")
        @Expect(replacePanel.apply(buffer), 2)
        let doc = TextDocumentView(buffer.lineCount(), { i => buffer.line(i) })
        let out = Buffer(Rect(0, 0, 20, 2))
        searchPanel.render(Rect(0, 0, 20, 1), out)
        replacePanel.render(Rect(0, 1, 20, 1), out)
        doc.render(Rect(0, 0, 20, 1), out)
        @Expect(buffer.undo())
    }

    @TestCase
    func terminalCapabilitiesDebugOverlayAndTestBackendHelpers(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 12, 2))
        let caps = TerminalCapabilities.detect(backend: backend)
        @Expect(caps.size.width, 12)
        @Expect(caps.driverName, "linux-glibc")
        @Expect(caps.colorLevel >= 1)
        @Expect(caps.recommendedFps >= 1)
        @Expect(caps.mouse == caps.mouse)
        @Expect(caps.focusEvents == caps.focusEvents)
        let fallback = FallbackTerminalDriver()
        @Expect(fallback.name(), "fallback")
        @Expect(!fallback.enterRawMode())
        fallback.restore()
        match (fallback.size()) {
            case Some(area) =>
                @Expect(area.width, 80)
                @Expect(area.height, 24)
            case None => @Expect(false)
        }
        let fixedFallback = FallbackTerminalDriver(area: Rect(0, 0, 42, 7))
        let fallbackBackend = TestBackend(area: Rect(0, 0, 42, 7))
        let fallbackCaps = fixedFallback.capabilities(fallbackBackend)
        match (fixedFallback.size()) {
            case Some(area) =>
                @Expect(area.width, 42)
                @Expect(area.height, 7)
            case None => @Expect(false)
        }
        @Expect(fallbackCaps.size.width, 42)
        @Expect(fallbackCaps.size.height, 7)
        @Expect(fallbackCaps.driverName, "fallback")
        @Expect(!fallbackCaps.mouse)
        @Expect(!fallbackCaps.bracketedPaste)
        @Expect(!fallbackCaps.alternateScreen)
        let terminal = Terminal(backend)
        let metrics = AppMetrics()
        metrics.record(FrameMetrics(frameIndex: 2, fps: 62, renderMillis: 1, drawMillis: 2, totalMillis: 3, eventQueueLength: 4, dirtyCells: 3, terminalSize: Rect(0, 0, 12, 2), droppedTicks: 5, tickDeltaMillis: 16))
        terminal.draw { frame =>
            frame.renderWidget(DebugOverlay(metrics), frame.area)
        }
        @Expect(backend.snapshot().contains("fps=62"))
        @Expect(backend.snapshot().contains("rende"))
        @Expect(backend.assertSnapshot("fps=62 rende\n            "))
        @Expect(backend.assertSnapshot(withoutFinalNewline(readText("tests/golden/debug_overlay.snap"))))
        @Expect(backend.assertCell(0, 0, "f", style: Style(fg: Color.Black, bg: Color.Yellow)))

        let source = MediaSource("plot", "plot.png", alt: "plot")
        let mediaBackend = TestBackend(area: Rect(0, 0, 12, 4))
        let mediaTerminal = Terminal(mediaBackend)
        mediaTerminal.draw { frame =>
            frame.addMedia(MediaPlacement("plot", source, Rect(0, 0, 6, 2)))
        }
        @Expect(mediaBackend.assertLastMediaOpCount(1))
        mediaTerminal.draw { frame =>
            frame.addMedia(MediaPlacement("plot", source, Rect(0, 0, 6, 2)))
        }
        @Expect(mediaBackend.assertLastMediaOpCount(0))
        mediaTerminal.draw { frame =>
            frame.addMedia(MediaPlacement("plot", source, Rect(1, 0, 6, 2)))
        }
        @Expect(mediaBackend.assertLastMediaOpCount(2))
        mediaTerminal.clear()
        @Expect(mediaBackend.assertLastMediaOpCount(1))
    }

    @TestCase
    func renderMetricsAndSnapshotDiffAreObservable(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 6, 2))
        let terminal = Terminal(backend)
        // Keep diff assertions on Terminal.draw/RenderMetrics so backend diff internals can evolve.
        let first = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "abc", Style.default())
        }
        @Expect(first.fullRedraw)
        @Expect(first.dirtyCells, 12)
        @Expect(first.diffWrites, 2)
        let second = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "axc", Style.default())
        }
        @Expect(!second.fullRedraw)
        @Expect(second.dirtyCells, 1)
        @Expect(second.diffWrites, 1)
        @Expect(backend.lastDiffWrites(), 1)
        let third = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "axy", Style.default())
        }
        @Expect(!third.fullRedraw)
        @Expect(third.dirtyCells, 1)
        @Expect(third.diffWrites, 1)
        let fourth = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "123", Style.default())
        }
        @Expect(!fourth.fullRedraw)
        @Expect(fourth.dirtyCells, 3)
        @Expect(fourth.diffWrites, 1)
        backend.setSize(Rect(0, 0, 4, 2))
        let resized = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "z", Style.default())
        }
        @Expect(resized.fullRedraw)
        @Expect(resized.dirtyCells, 8)

        let fullBackend = TestBackend(area: Rect(0, 0, 3, 1))
        let fullTerminal = Terminal(fullBackend, renderMode: RenderMode.Full)
        let fullFirst = fullTerminal.draw { frame =>
            frame.canvas().drawText(0, 0, "abc", Style.default())
        }
        let fullSecond = fullTerminal.draw { frame =>
            frame.canvas().drawText(0, 0, "abc", Style.default())
        }
        @Expect(fullFirst.fullRedraw)
        @Expect(fullSecond.fullRedraw)
        @Expect(fullSecond.dirtyCells, 3)

        let diff = SnapshotDiff.text("abc\n", "axc\n")
        @Expect(!diff.passed)
        @Expect(diff.line, 0)
        @Expect(diff.column, 1)
        @Expect(diff.message.contains("snapshot mismatch"))
    }

    @TestCase
    func dirtyRectRenderSkipsUntouchedWidgets(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 12, 3))
        let terminal = Terminal(backend)
        let left = CountingWidget("left")
        let right = CountingWidget("right")

        _ = terminal.draw { frame =>
            frame.renderWidget(left, Rect(0, 0, 5, 1))
            frame.renderWidget(right, Rect(6, 0, 5, 1))
        }
        @Expect(left.renders, 1)
        @Expect(right.renders, 1)

        let dirty = DirtyRects.full(Rect(0, 0, 5, 1))
        let metrics = terminal.draw({ frame =>
            frame.renderWidget(left, Rect(0, 0, 5, 1))
            frame.renderWidget(right, Rect(6, 0, 5, 1))
        }, dirtyRects: Some(dirty))
        @Expect(left.renders, 2)
        @Expect(right.renders, 1)
        @Expect(metrics.renderedCells <= 5)
        @Expect(metrics.dirtyRects, 1)
        @Expect(backend.snapshot().contains("right"))
    }

    @TestCase
    func dirtyRectRenderClearsOnlyTouchedRegionAndPreservesRest(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 12, 2))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame =>
            frame.canvas().drawText(0, 0, "abcdefghij", Style.default())
            frame.canvas().drawText(0, 1, "stable", Style.default())
        }

        let dirty = DirtyRects.full(Rect(0, 0, 3, 1))
        let metrics = terminal.draw({ frame =>
            frame.canvas().drawText(0, 0, "xy", Style.default())
            frame.canvas().drawText(0, 1, "changed-but-outside-dirty", Style.default())
        }, dirtyRects: Some(dirty))
        @Expect(!metrics.fullRedraw)
        @Expect(metrics.renderedCells <= 3)
        @Expect(backend.assertCell(0, 0, "x"))
        @Expect(backend.assertCell(1, 0, "y"))
        @Expect(backend.assertCell(2, 0, " "))
        @Expect(backend.snapshot().contains("stable"))
        @Expect(!backend.snapshot().contains("changed"))
    }

    @TestCase
    func componentHostMountUnmountManagesComponentTimers(): Unit {
        let probe = RuntimeProbeComponent("cpu")
        probe.startTimerOnMount = true
        let host = ComponentHost().add("cpu", probe, area: Rect(0, 0, 10, 2))

        let mounted = host.mount()
        @Expect(probe.mounts, 1)
        match (mounted.command) {
            case Command.StartTimer(spec) => @Expect(spec.id, "component:cpu:sample")
            case _ => @Expect(false)
        }

        let unmounted = host.unmount()
        @Expect(probe.unmounts, 1)
        match (unmounted.command) {
            case Command.StopTimer(id) => @Expect(id, "component:cpu:sample")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func componentHostMapsLocalDirtyToGlobalRects(): Unit {
        let probe = RuntimeProbeComponent("table")
        probe.resultHandled = true
        probe.resultDirty = Dirty.LocalRows([1, 3])
        let host = ComponentHost().add("table", probe, area: Rect(5, 4, 20, 6))

        let result = host.dispatchTo("table", Event.Message("dirty"))
        match (result.dirtyRects) {
            case Some(rects) =>
                @Expect(rects.intersects(Rect(5, 5, 20, 1)))
                @Expect(rects.intersects(Rect(5, 7, 20, 1)))
                @Expect(!rects.intersects(Rect(5, 4, 20, 1)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentHostDirtyRenderSkipsUntouchedComponents(): Unit {
        let left = RuntimeProbeComponent("left", text: "left")
        let right = RuntimeProbeComponent("right", text: "right")
        let host = ComponentHost()
            .add("left", left, area: Rect(0, 0, 5, 1))
            .add("right", right, area: Rect(6, 0, 5, 1))
        let backend = TestBackend(area: Rect(0, 0, 12, 2))
        let terminal = Terminal(backend)

        _ = terminal.draw { frame => host.render(frame) }
        @Expect(left.renders, 1)
        @Expect(right.renders, 1)

        left.resultHandled = true
        left.resultDirty = Dirty.Self
        let update = host.dispatchTo("left", Event.Message("update-left"))
        let metrics = terminal.draw({ frame => host.render(frame) }, dirtyRects: update.dirtyRects)
        @Expect(left.renders, 2)
        @Expect(right.renders, 1)
        @Expect(metrics.renderedCells <= 5)
        @Expect(backend.snapshot().contains("right"))
    }

    @TestCase
    func componentHostRoutesFocusedKeysAndComponentTimers(): Unit {
        let cpu = RuntimeProbeComponent("cpu")
        let proc = RuntimeProbeComponent("proc")
        proc.resultHandled = true
        proc.resultDirty = Dirty.Local(Rect(0, 1, 8, 1))
        let host = ComponentHost()
            .add("cpu", cpu, area: Rect(0, 0, 8, 2))
            .add("proc", proc, area: Rect(0, 2, 8, 4))
        @Expect(host.focusManager().focus("proc"))

        let keyResult = host.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        @Expect(cpu.updates, 0)
        @Expect(proc.updates, 1)
        match (keyResult.dirtyRects) {
            case Some(rects) => @Expect(rects.intersects(Rect(0, 3, 8, 1)))
            case None => @Expect(false)
        }

        let tick = TimerEvent("component:cpu:sample", elapsedMillis: 10, firedCount: 1)
        let tickResult = host.update(Event.Timer(tick))
        @Expect(cpu.tickEvents, 1)
        @Expect(proc.tickEvents, 0)
        @Expect(cpu.lastEventText, "cpu:sample")
        match (tickResult.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(0, 0, 8, 2)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentHostRoutesAsyncPollerResultsAndProfilesWork(): Unit {
        let probe = RuntimeProbeComponent("data")
        let poller = AsyncPoller("refresh", { => Event.Message("loaded") })
        probe.poller = Some(poller)
        let host = ComponentHost().add("data", probe, area: Rect(2, 3, 10, 2))
        let ctx = ComponentContext("data", area: Rect(2, 3, 10, 2))

        @Expect(poller.request(ctx, nowMillis: 100))
        @Expect(poller.isPending())
        let commands = ctx.drainCommands()
        @Expect(commands.size, 1)
        match (commands[0]) {
            case Command.AsyncTask(id, _) => @Expect(id, "component-async:data:refresh")
            case _ => @Expect(false)
        }

        let result = host.update(Event.AsyncCompleted("component-async:data:refresh", Event.Message("loaded")))
        @Expect(probe.lastEventText, "refresh:loaded")
        @Expect(!poller.isPending())
        match (result.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(2, 3, 10, 2)))
            case None => @Expect(false)
        }
        match (host.componentProfile("data")) {
            case Some(profile) =>
                @Expect(profile.updateCount >= 1)
                @Expect(profile.dirtyCells >= 20)
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentDataSourceRoutesTypedReadyEventsAndProfilerOverlayWorks(): Unit {
        let probe = RuntimeProbeComponent("metrics")
        let source = DataSource<Int64>("cpu")
        let host = ComponentHost().add("metrics", probe, area: Rect(1, 2, 12, 3))
        let ctx = ComponentContext("metrics", area: Rect(1, 2, 12, 3))

        @Expect(source.refresh(ctx, { => Int64(42) }, nowMillis: 100))
        @Expect(source.isPending())
        @Expect(source.isStale())
        let commands = ctx.drainCommands()
        @Expect(commands.size, 1)
        var asyncId = ""
        var inner = Event.Message("missing")
        match (commands[0]) {
            case Command.AsyncTask(id, task) =>
                asyncId = id
                inner = task()
            case _ => @Expect(false)
        }
        @Expect(asyncId, "component-data:metrics:cpu:1")
        match (source.latest()) {
            case Some(value) => @Expect(value, 42)
            case None => @Expect(false)
        }
        @Expect(!source.isPending())
        @Expect(!source.isStale())

        let result = host.update(Event.AsyncCompleted(asyncId, inner))
        @Expect(probe.lastEventText, "cpu:1")
        match (result.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(1, 2, 12, 3)))
            case None => @Expect(false)
        }
        let overlay = ProfilerOverlay(host.profiler())
        let overlayBuffer = Buffer(Rect(0, 0, 48, 4))
        overlay.render(Rect(0, 0, 48, 4), overlayBuffer)
        let snapshot = overlay.snapshot()
        match (snapshot.hottest()) {
            case Some(entry) =>
                @Expect(entry.id, "metrics")
                @Expect(entry.asyncCount >= 1)
            case None => @Expect(false)
        }
    }

    @TestCase
    func dataSourceDebounceIdleCancelFailureAndProfilerStateAreObservable(): Unit {
        let probe = DataSourceProbeComponent()
        let host = ComponentHost().add("metrics", probe, area: Rect(1, 2, 12, 3))

        _ = host.dispatchTo("metrics", Event.Message("activity"))
        let blocked = host.dispatchTo("metrics", Event.Message("poll-idle-blocked"))
        @Expect(probe.lastEventText, "blocked")
        match (blocked.command) {
            case Command.Noop => ()
            case _ => @Expect(false)
        }

        let poll = host.dispatchTo("metrics", Event.Message("poll"))
        @Expect(probe.source.isPending())
        match (host.profilerSnapshot().find("metrics")) {
            case Some(entry) =>
                @Expect(entry.pendingDataSources, 1)
                @Expect(entry.lowPriorityDataPolls, 1)
            case None => @Expect(false)
        }
        var asyncId = ""
        match (poll.command) {
            case Command.AsyncTask(id, _) => asyncId = id
            case _ => @Expect(false)
        }
        let duplicate = host.dispatchTo("metrics", Event.Message("poll"))
        match (duplicate.command) {
            case Command.Noop => ()
            case _ => @Expect(false)
        }

        let cancel = host.dispatchTo("metrics", Event.Message("cancel"))
        @Expect(!probe.source.isPending())
        @Expect(probe.source.isStale())
        match (probe.source.error()) {
            case Some(message) => @Expect(message, "cancelled")
            case None => @Expect(false)
        }
        var cancelId = ""
        match (cancel.command) {
            case Command.CancelAsync(id) => cancelId = id
            case _ => @Expect(false)
        }
        @Expect(cancelId, asyncId)
        let cancelResult = host.update(Event.AsyncCancelled(cancelId))
        @Expect(probe.lastEventText, "proc:cancelled:1")
        match (cancelResult.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(1, 2, 12, 3)))
            case None => @Expect(false)
        }
        match (host.profilerSnapshot().find("metrics")) {
            case Some(entry) =>
                @Expect(entry.pendingDataSources, 0)
                match (entry.lastError) {
                    case Some(message) => @Expect(message, "cancelled")
                    case None => @Expect(false)
                }
            case None => @Expect(false)
        }

        let failed = probe.source.fail("boom")
        @Expect(probe.source.isStale())
        match (failed.error) {
            case Some(message) => @Expect(message, "boom")
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentProfilerSnapshotSupportsSortingLookupAndReset(): Unit {
        let host = ComponentHost()
            .add("fast", RuntimeProbeComponent("fast"), area: Rect(0, 0, 4, 1))
            .add("slow", RuntimeProbeComponent("slow"), area: Rect(0, 1, 8, 2))
        _ = host.dispatchTo("fast", Event.Message("hit"))
        _ = host.dispatchTo("slow", Event.DataFailed("load", 1, "offline"))
        let backend = TestBackend(area: Rect(0, 0, 12, 4))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => host.render(frame) }

        let snapshot = host.profilerSnapshot()
        match (snapshot.find("slow")) {
            case Some(entry) =>
                @Expect(entry.id, "slow")
                match (entry.lastError) {
                    case Some(message) => @Expect(message, "offline")
                    case None => @Expect(false)
                }
            case None => @Expect(false)
        }
        @Expect(snapshot.sortedByRender().size, 2)
        @Expect(snapshot.sortedByUpdate().size, 2)
        @Expect(snapshot.sortedByAsync().size, 2)

        host.profiler().resetFrameCounters()
        match (host.profilerSnapshot().find("slow")) {
            case Some(entry) =>
                @Expect(entry.updateCount, 0)
                @Expect(entry.renderCount, 0)
                @Expect(entry.asyncCount, 0)
            case None => @Expect(false)
        }
    }

    @TestCase
    func focusedComponentHandledKeyPrecedesGlobalKey(): Unit {
        let focused = RuntimeProbeComponent("focused")
        focused.resultHandled = true
        focused.resultDirty = Dirty.Self
        let host = ComponentHost().add("focused", focused, area: Rect(0, 0, 10, 2))
        host.addGlobalKey(KeyBinding([KeyEvent(KeyCode.Up)], "global-up"))
        @Expect(host.focusManager().focus("focused"))

        let result = host.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        @Expect(focused.updates, 1)
        match (result.command) {
            case Command.Noop => ()
            case _ => @Expect(false)
        }
        match (result.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(0, 0, 10, 2)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentContainerRenderDoesNotMutateChildLayout(): Unit {
        let child = RuntimeProbeComponent("child", text: "child")
        let childHost = ComponentHost().add("child", child, area: Rect(0, 0, 1, 1))
        let grid = DashboardGrid(1, 1, regions: [DashboardRegion("child", 0, 0)])
        let container = ComponentContainer(childHost, grid)
        let parent = ComponentHost().add("container", container, area: Rect(0, 0, 20, 4))
        _ = parent.mountAll()
        _ = parent.resizeAllComponents(Rect(0, 0, 20, 4))

        match (childHost.node("child")) {
            case Some(node) => @Expect(node.area(), Rect(0, 0, 20, 4))
            case None => @Expect(false)
        }
        let backend = TestBackend(area: Rect(0, 0, 20, 4))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => parent.renderDirty(frame) }
        match (childHost.node("child")) {
            case Some(node) => @Expect(node.area(), Rect(0, 0, 20, 4))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentHostDefaultLayoutStillSplitsVertically(): Unit {
        let host = ComponentHost()
            .add("top", RuntimeProbeComponent("top"), area: Rect(0, 0, 1, 1))
            .add("bottom", RuntimeProbeComponent("bottom"), area: Rect(0, 0, 1, 1))
        let result = host.resizeAllComponents(Rect(0, 0, 20, 5))

        match (host.node("top")) {
            case Some(node) => @Expect(node.area(), Rect(0, 0, 20, 2))
            case None => @Expect(false)
        }
        match (host.node("bottom")) {
            case Some(node) => @Expect(node.area(), Rect(0, 2, 20, 3))
            case None => @Expect(false)
        }
        match (result.dirtyRects) {
            case Some(rects) =>
                @Expect(rects.covers(Rect(0, 0, 20, 2)))
                @Expect(rects.covers(Rect(0, 2, 20, 3)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentHostCanUseCustomLayoutProvider(): Unit {
        let provider = FixedComponentLayoutProvider([
            Rect(0, 0, 6, 4),
            Rect(6, 0, 14, 3),
            Rect(6, 3, 14, 1)
        ])
        let host = ComponentHost(layoutProvider: provider)
            .add("sidebar", RuntimeProbeComponent("sidebar"), area: Rect(0, 0, 1, 1))
            .add("main", RuntimeProbeComponent("main"), area: Rect(0, 0, 1, 1))
            .add("status", RuntimeProbeComponent("status"), area: Rect(0, 0, 1, 1))
        let result = host.resizeAllComponents(Rect(0, 0, 20, 4))

        match (host.node("sidebar")) {
            case Some(node) => @Expect(node.area(), Rect(0, 0, 6, 4))
            case None => @Expect(false)
        }
        match (host.node("main")) {
            case Some(node) => @Expect(node.area(), Rect(6, 0, 14, 3))
            case None => @Expect(false)
        }
        match (host.node("status")) {
            case Some(node) => @Expect(node.area(), Rect(6, 3, 14, 1))
            case None => @Expect(false)
        }
        match (result.dirtyRects) {
            case Some(rects) =>
                @Expect(rects.covers(Rect(0, 0, 6, 4)))
                @Expect(rects.covers(Rect(6, 0, 14, 3)))
                @Expect(rects.covers(Rect(6, 3, 14, 1)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func componentWrappersExposeLocalDirtyForInputAndTextArea(): Unit {
        let input = Input()
        let inputHost = ComponentHost().add("input", InputComponent(input, focusId: Some("input")), area: Rect(0, 0, 20, 1))
        @Expect(inputHost.focusManager().focus("input"))
        let inputResult = inputHost.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'a'))))
        match (inputResult.dirtyRects) {
            case Some(rects) => @Expect(rects.covers(Rect(0, 0, 20, 1)))
            case None => @Expect(false)
        }

        let textArea = TextArea(value: "alpha\nbeta", cursor: 0)
        let textHost = ComponentHost().add("text", TextAreaComponent(textArea, focusId: Some("text")), area: Rect(0, 2, 30, 4))
        @Expect(textHost.focusManager().focus("text"))
        let textResult = textHost.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        match (textResult.dirtyRects) {
            case Some(rects) => @Expect(rects.intersects(Rect(0, 2, 30, 4)))
            case None => @Expect(false)
        }
    }

    @TestCase
    func virtualTableExposesDirtyRowsBodyHeaderAndCacheControls(): Unit {
        let rowsProvider = RuntimeTableRows()
        let table = VirtualTable(
            [TableColumn("ID", width: 4), TableColumn("Name", width: 8)],
            100,
            { index => rowsProvider.row(index) },
            offset: 10,
            selectedRow: Some(12)
        )
        let area = Rect(4, 5, 20, 6)
        let header = table.dirtyHeader(area)
        @Expect(header.covers(Rect(4, 5, 20, 1)))
        let body = table.dirtyBody(area)
        @Expect(body.covers(Rect(4, 6, 20, 5)))
        let rows = table.dirtyRows(area, [12, 14])
        @Expect(rows.intersects(Rect(4, 8, 20, 1)))
        @Expect(rows.intersects(Rect(4, 10, 20, 1)))
        let selection = table.dirtySelectionChange(area, Some(12), Some(13))
        @Expect(selection.intersects(Rect(4, 8, 20, 1)))
        @Expect(selection.intersects(Rect(4, 9, 20, 1)))

        let buffer = Buffer(area)
        table.render(area, buffer)
        @Expect(rowsProvider.calls > 0)
        @Expect(table.cachedRowCount() > 0)
        table.clearCachedRows()
        @Expect(table.cachedRowCount(), 0)
    }

    @TestCase
    func appMetricsAndHeadlessRunnerCaptureFrames(): Unit {
        let script = HeadlessScript()
            .key(KeyEvent(KeyCode.Char(r'a')))
            .expectCell(0, 0, "a")
            .resize(Rect(0, 0, 8, 2))
            .mouse(MouseEvent(MouseKind.Move, MouseButton.None, 1, 1))
            .paste("bc")
            .message("done")
            .tick(count: 2)
        let state = StringState(value: "")
        let result = AppTestRunner.run(
            script,
            { frame => frame.renderWidget(Paragraph(state.get()), frame.area) },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r) => state.set(runeToString(r))
                            case _ => ()
                        }
                    case Event.Paste(text) => state.set(state.get() + text)
                    case Event.Message(text) => state.set(text)
                    case Event.Tick(tick) => state.set("tick${tick.frameIndex}")
                    case _ => ()
                }
                UpdateResult.next()
            },
            options: HeadlessRunOptions(area: Rect(0, 0, 6, 1), tickDeltaMillis: 20)
        )
        @Expect(result.passed())
        @Expect(result.frames.size >= 7)
        @Expect(result.snapshots.size, result.frames.size)
        match (result.metrics.lastFrame()) {
            case Some(frame) =>
                @Expect(frame.fps, 50)
                @Expect(frame.terminalSize.width, 8)
            case None => @Expect(false)
        }
        @Expect(result.metrics.averageFps() > 0)
    }

    @TestCase
    func headlessRunnerCanMeasureWithoutRetainingFrameArtifacts(): Unit {
        let result = AppTestRunner.run(
            HeadlessScript().tick(count: 3).resize(Rect(0, 0, 12, 2)),
            { frame => frame.renderWidget(Paragraph("performance"), frame.area) },
            { _ => UpdateResult.next() },
            options: HeadlessRunOptions(
                area: Rect(0, 0, 8, 1),
                captureBuffers: false,
                captureSnapshots: false
            )
        )
        @Expect(result.passed())
        @Expect(result.frames.size, 0)
        @Expect(result.snapshots.size, 0)
        @Expect(result.metrics.frames().size, 5)
    }

    @TestCase
    func appUsesInjectedEventWaiterAndClosesItOnExit(): Unit {
        let waiter = CountingEventWaiter()
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let app = App(
            backend: backend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            tickEvery: Some(Duration.millisecond),
            idleSleep: Duration.millisecond,
            eventWaiter: waiter
        )
        app.run(
            { frame => frame.renderWidget(Paragraph("wait"), frame.area) },
            { event =>
                match (event) {
                    case Event.Tick(_) => ControlFlow.Exit
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(waiter.waits > 0)
        @Expect(waiter.closed)
        @Expect(waiter.lastTimeoutMillis >= 0)
        @Expect(waiter.lastPreviousReadBytes >= 0)
        @Expect(waiter.lastSourceCount, 0)
    }

    @TestCase
    func appClosesInjectedEventWaiterWhenUpdateThrows(): Unit {
        let waiter = CountingEventWaiter()
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let app = App(
            backend: backend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            eventWaiter: waiter
        )
        var caught = false
        try {
            app.run(
                { frame => frame.renderWidget(Paragraph("boom"), frame.area) },
                { _ =>
                    throw Exception("update failed")
                    ControlFlow.Continue
                }
            )
        } catch (_: Exception) {
            caught = true
        }
        @Expect(caught)
        @Expect(waiter.closed)
    }

    @TestCase
    func appClosesOnlyPtysStartedByItsOwnSession(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let runtime = FakePtyRuntime()
        match (runtime.start("external", PtySpec("/bin/sh"))) {
            case Event.PtyStarted(_) => ()
            case _ => @Expect(false)
        }
        let app = App(
            backend: backend,
            ptyRuntime: runtime,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false
        )
        app.runWithCommands(
            { frame => frame.renderWidget(Paragraph("pty"), frame.area) },
            { event =>
                match (event) {
                    case Event.Capabilities(_) => UpdateResult.withCommand(Command.Batch([
                        Command.PtyStart("owned", PtySpec("/bin/sh")),
                        Command.Quit
                    ]))
                    case _ => UpdateResult.next()
                }
            }
        )
        @Expect(runtime.activeCount(), 1)
        match (runtime.fakeProcess("external")) {
            case Some(_) => @Expect(true)
            case None => @Expect(false)
        }
        match (runtime.fakeProcess("owned")) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
        _ = runtime.close("external")
    }

    @TestCase
    func appUsesInjectedInputSourceForHighLevelLoop(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let input = ChunkedInputSource([unsafe { "q".rawData() }])
        let app = App(
            backend: backend,
            inputSource: input,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false
        )
        let sawQuit = IntState()
        app.run(
            { frame => frame.renderWidget(Paragraph("input"), frame.area) },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r'q') =>
                                sawQuit.set(1)
                                ControlFlow.Exit
                            case _ => ControlFlow.Continue
                        }
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(sawQuit.get(), 1)
    }

    @TestCase
    func appPaintsBetweenBufferedKeyEvents(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let input = ChunkedInputSource([
            unsafe { "abc".rawData() },
            unsafe { "q".rawData() }
        ])
        let app = App(
            backend: backend,
            inputSource: input,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false
        )
        let value = StringState()
        app.run(
            { frame =>
                frame.renderWidget(Paragraph(value.get()), frame.area)
            },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r'q') => ControlFlow.Exit
                            case KeyCode.Char(r) =>
                                value.set(value.get() + runeToString(r))
                                ControlFlow.Continue
                            case _ => ControlFlow.Continue
                        }
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(value.get(), "abc")
        @Expect(backend.snapshots().size, 4)
        @Expect(backend.snapshots()[1].contains("a"), true)
        @Expect(backend.snapshots()[2].contains("ab"), true)
        @Expect(backend.snapshot().contains("abc"))
    }

    @TestCase
    func appSkipsFramesForBufferedUnchangedInput(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let wheelDown = "\u{1B}[<65;3;4M"
        let input = ChunkedInputSource([
            unsafe { (wheelDown + wheelDown + wheelDown + wheelDown).rawData() },
            unsafe { "q".rawData() }
        ])
        let app = App(
            backend: backend,
            inputSource: input,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false,
            mouse: false
        )
        let wheelEvents = IntState()
        app.runWithCommands(
            { frame => frame.renderWidget(Paragraph("bottom"), frame.area) },
            { event =>
                match (event) {
                    case Event.Mouse(_) =>
                        wheelEvents.set(wheelEvents.get() + 1)
                        UpdateResult.unchanged()
                    case Event.KeyDown(key) => match (key.code) {
                        case KeyCode.Char(r'q') => UpdateResult.exit()
                        case _ => UpdateResult.next()
                    }
                    case _ => UpdateResult.next()
                }
            }
        )
        @Expect(wheelEvents.get(), 4)
        // Initial paint only: boundary wheel input is consumed without
        // repeatedly rendering the unchanged application state.
        @Expect(backend.snapshots().size, 1)
    }

    @TestCase
    func appUsesInjectedTerminalDriverForCapabilitiesAndSession(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let driver = ObservedTerminalDriver()
        let app = App(
            backend: backend,
            terminalDriver: driver,
            rawMode: true,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false
        )
        let driverName = StringState()
        app.runWithCommands(
            { frame => frame.renderWidget(Paragraph("driver"), frame.area) },
            { event =>
                match (event) {
                    case Event.Capabilities(caps) =>
                        driverName.set(caps.driverName)
                        UpdateResult.exit()
                    case _ => UpdateResult.next()
                }
            }
        )
        @Expect(driverName.get(), "observed-driver")
        @Expect(driver.rawEnters, 1)
        @Expect(driver.restores, 1)
        @Expect(driver.capabilityCalls, 1)
    }

    @TestCase
    func activeProbeDoesNotConsumeInjectedAppInputSource(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let input = ChunkedInputSource([unsafe { "q".rawData() }])
        let probe = ChunkedInputSource([unsafe { "\u{1B}[?1u".rawData() }])
        let app = App(
            backend: backend,
            inputSource: input,
            probeInputSource: probe,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false,
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: TerminalProbeMode.Active)
        )
        let sawQuit = IntState()
        app.run(
            { frame => frame.renderWidget(Paragraph("probe"), frame.area) },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r'q') =>
                                sawQuit.set(1)
                                ControlFlow.Exit
                            case _ => ControlFlow.Continue
                        }
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(sawQuit.get(), 1)
    }

    @TestCase
    func resizePollingUsesResizePollIntervalInsteadOfIdleSleep(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let waiter = ResizeChangingWaiter(backend, Rect(0, 0, 12, 3))
        let app = App(
            backend: backend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false,
            idleSleep: Duration.millisecond,
            resizePollEvery: Duration.millisecond * 250,
            eventWaiter: waiter
        )
        let sawResize = IntState()
        app.run(
            { frame => frame.renderWidget(Paragraph("resize"), frame.area) },
            { event =>
                match (event) {
                    case Event.Resize(area) =>
                        if (area.width == 12 && area.height == 3) { sawResize.set(1) }
                        ControlFlow.Exit
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(sawResize.get(), 1)
        @Expect(waiter.waits, 1)
        @Expect(waiter.lastTimeoutMillis, 250)
        @Expect(waiter.closed)
    }

    @TestCase
    func tickDeadlineStillWinsOverLongResizePollInterval(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 2))
        let waiter = CountingEventWaiter()
        let app = App(
            backend: backend,
            rawMode: false,
            alternateScreen: false,
            hideCursor: false,
            bracketedPaste: false,
            tickEvery: Some(Duration.millisecond * 5),
            idleSleep: Duration.millisecond,
            resizePollEvery: Duration.millisecond * 250,
            eventWaiter: waiter
        )
        app.run(
            { frame => frame.renderWidget(Paragraph("tick"), frame.area) },
            { event =>
                match (event) {
                    case Event.Tick(_) => ControlFlow.Exit
                    case _ => ControlFlow.Continue
                }
            }
        )
        @Expect(waiter.waits > 0)
        @Expect(waiter.lastTimeoutMillis <= 5)
        @Expect(waiter.closed)
    }

    @TestCase
    func eventScriptRunsControlFlowAndCommandUpdates(): Unit {
        let script = EventScript()
            .key(KeyEvent(KeyCode.Char(r'a')))
            .paste("x")
            .key(KeyEvent(KeyCode.CtrlC))
        let flowCounter = FlowCounter()
        let flow = script.run { event => flowCounter.update(event) }
        match (flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
        @Expect(flowCounter.seen, 3)

        let counter = CommandCounter()
        let commandFlow = EventScript(events: [Event.Message("load"), Event.Tick(TickEvent())]).runWithCommands({ event => counter.update(event) })
        match (commandFlow) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }
        @Expect(counter.messages, 1)
        @Expect(counter.ticks, 1)

        let parsed = EventScript.fromText("key:a\nmessage:load\ntick\n")
        @Expect(parsed.size(), 3)
        let parsedCounter = CommandCounter()
        let parsedFlow = parsed.runWithCommands({ event => parsedCounter.update(event) })
        match (parsedFlow) {
            case ControlFlow.Continue => ()
            case _ => @Expect(false)
        }
        @Expect(parsedCounter.messages, 1)
        @Expect(parsedCounter.ticks, 1)

        let scenarioBackend = TestBackend(area: Rect(0, 0, 8, 1))
        let scenarioState = StringState(value: "A")
        let scenario = EventScenario.fromText("scenario:basic\nkey:b\nexpect:cell:0,0,b\nexpect:flow:continue\n")
        let result = scenario.run(
            scenarioBackend,
            { frame => frame.renderWidget(Paragraph(scenarioState.get()), frame.area) },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r) => scenarioState.set(runeToString(r))
                            case _ => ()
                        }
                        UpdateResult.next()
                    case _ => UpdateResult.next()
                }
            }
        )
        @Expect(result.passed)
        @Expect(result.name, "basic")
    }

    @TestCase
    func scenarioCoversMarkdownSaveSearchAndFilePickerWorkflows(): Unit {
        let markdownBackend = TestBackend(area: Rect(0, 0, 28, 4))
        let markdown = TextArea(value: "# 标题\n\n| 姓名 | 角色 |\n| --- | --- |\n", cursor: 0, markdownEditing: true)
        let saved = StringState()
        let status = StringState(value: "edit")
        let markdownScenario = EventScenario.fromText("scenario:markdown\nkey:G\nkey:ctrl-s\nexpect:cell:0,3,s\nexpect:flow:continue\n")
        let markdownResult = markdownScenario.run(
            markdownBackend,
            { frame =>
                frame.renderWidget(markdown, frame.area)
                frame.renderWidget(Paragraph(status.get()), Rect(0, 3, 28, 1))
            },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r's') =>
                                if (key.modifiers.ctrl) {
                                    saved.set(markdown.value)
                                    status.set("saved")
                                } else {
                                    _ = markdown.handle(key)
                                }
                            case KeyCode.Char(r'G') => _ = markdown.handleVimNavigation(key)
                            case _ => _ = markdown.handle(key)
                        }
                    case _ => ()
                }
                UpdateResult.next()
            }
        )
        @Expect(markdownResult.passed)
        @Expect(saved.get().contains("姓名"))
        @Expect(markdown.cursor, markdown.value.size)

        let fileBackend = TestBackend(area: Rect(0, 0, 30, 5))
        let picker = FilePicker(path: "tests/fixtures/file_picker", extension: ".cj")
        let fileScenario = EventScenario.fromText("scenario:file\nkey:/\nkey:down\nexpect:flow:continue\n")
        let fileResult = fileScenario.run(
            fileBackend,
            { frame => frame.renderWidget(picker, frame.area) },
            { event =>
                match (event) {
                    case Event.KeyDown(key) =>
                        match (key.code) {
                            case KeyCode.Char(r'/') => picker.setSearch("lib")
                            case _ => _ = picker.handle(key, 4)
                        }
                    case _ => ()
                }
                UpdateResult.next()
            }
        )
        @Expect(fileResult.passed)
        match (picker.selectedEntry()) {
            case Some(entry) => @Expect(entry, "lib.cj")
            case None => @Expect(false)
        }
    }

    @TestCase
    func pressureScenariosCoverLargeTextVirtualTablesAndAsyncBursts(): Unit {
        var largeText = ""
        for (i in 0..1500) {
            largeText += "- item ${i} 中文内容\n"
        }
        let area = TextArea(value: largeText, cursor: largeText.size, lineNumbers: true, markdownEditing: true)
        let backend = TestBackend(area: Rect(0, 0, 40, 12))
        let terminal = Terminal(backend)
        terminal.draw { frame => frame.renderWidget(area, frame.area) }
        @Expect(backend.snapshot().contains("item"))
        @Expect(backend.snapshots().size, 1)

        let table = VirtualTable(
            [TableColumn("Name", width: 12), TableColumn("Value", width: 10)],
            10000,
            { index => ["row-${index}", "value-${index}"] }
        )
        terminal.draw { frame => frame.renderWidget(table, frame.area) }
        @Expect(backend.lastDiffOps() > 0)
        @Expect(backend.snapshots().size, 2)

        let runtime = AsyncRuntime()
        for (i in 0..16) {
            match (runtime.start("job-${i}", { => Event.Message("done") })) {
                case Event.AsyncStarted(_) => ()
                case _ => @Expect(false)
            }
        }
        var completed: Int64 = 0
        while (runtime.pendingCount() > 0) {
            for (event in runtime.drain()) {
                match (event) {
                    case Event.AsyncCompleted(_, Event.Message(text)) =>
                        if (text == "done") { completed++ }
                    case _ => ()
                }
            }
        }
        @Expect(completed, 16)
    }
}
