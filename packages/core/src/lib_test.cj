package core

import std.unittest.*
import std.unittest.testmacro.*
import std.io.*
import std.collection.ArrayList
import std.fs.*

class TestOutput <: OutputStream {
    let bytes = ArrayList<Byte>()

    public func write(buffer: Array<Byte>): Unit {
        for (b in buffer) {
            bytes.add(b)
        }
    }

    public func flush(): Unit {}

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
        @Expect(out.text().contains("\u{1B}[2;3H"))
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
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: TerminalProbeMode.Active)
        ).run { autoBackend.write("body") }
        @Expect(autoOut.text().contains("\u{1B}[?u\u{1B}[>1u\u{1B}[>4;2m"))
        @Expect(autoOut.text().contains("\u{1B}[<1u\u{1B}[>4;0m"))
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
    func eventRouterDispatchesGlobalKeysThenFocusedComponent(): Unit {
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
        @Expect(first.handled, 0)

        @Expect(router.focusManager().focus("second"))
        _ = router.handle(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(first.handled, 0)
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
    func commandRuntimeProcessesBatchMessagesAndQuit(): Unit {
        let queue = ArrayList<Command>()
        let counter = CommandCounter()
        let runtime = AsyncRuntime()
        @Expect(App.applyUpdateResult(UpdateResult.withCommand(Command.Batch([
            Command.Message("load"),
            Command.Async("job"),
            Command.AsyncTask("task", { => Event.Message("load") }),
            Command.AsyncExec("printf", "/usr/bin/printf ok"),
            Command.Emit(Event.Tick(TickEvent())),
            Command.StartTimer(TimerSpec("test", Duration.millisecond, mode: TimerMode.OneShot)),
            Command.StopTimer("test"),
            Command.Exec("/usr/bin/printf ok")
        ])), queue))
        @Expect(queue.size, 8)
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
        let transcript = Transcript(items: [
            TranscriptItem("one", title: "First", body: Document.plain("hello")),
            TranscriptItem("two", kind: TranscriptItemKind.Error, title: "Error", body: Document.plain("bad"), status: TranscriptItemStatus.Failed, collapsed: true)
        ])
        let view = TranscriptView(transcript, selected: 0)
        let buffer = Buffer(Rect(0, 0, 40, 12))
        view.render(Rect(0, 0, 40, 5), buffer)
        @Expect(buffer.getCell(4, 0).symbol, "F")
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

        let staleRequest = area.beginCompletion("stale")
        area.paste("!")
        let stale = Event.TextCompletion("stale", TextCompletionResult(staleRequest.requestId, staleRequest.revision, staleRequest.prefixStart, staleRequest.prefixEnd, [TextCompletionItem("ignored")]))
        @Expect(!area.handleCompletionEvent(stale))
    }

    @TestCase
    func textAreaSupportsPagingControlKeysAndLineNumbers(): Unit {
        let area = TextArea(value: "one\ntwo\nthree\nfour\nfive\nsix", cursor: 0, lineNumbers: true)
        @Expect(area.handle(KeyEvent(KeyCode.PageDown)))
        @Expect(area.cursor > 0)
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, 0)
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'e'), modifiers: KeyModifier(ctrl: true))))
        @Expect(area.cursor, area.value.size)
        @Expect(area.handle(KeyEvent(KeyCode.Char(r'a'), modifiers: KeyModifier(ctrl: true))))
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
        Modal(title: "M", body: "Hello modal", buttons: ["OK"], width: 12, height: 5).render(buffer.area, buffer)
        @Expect(buffer.getCell(8, 1).symbol, "M")

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
