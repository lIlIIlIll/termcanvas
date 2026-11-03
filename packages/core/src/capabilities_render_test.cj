package core

import std.collection.ArrayList
import std.io.*
import std.sync.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

class CapabilityTestOutput <: OutputStream {
    let bytes = ArrayList<Byte>()
    public func write(buffer: Array<Byte>): Unit { for (value in buffer) { bytes.add(value) } }
    public func flush(): Unit {}
    func text(): String { unsafe { String.fromUtf8Unchecked(bytes.toArray()) } }
}

class CapabilityTestWidget <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.setString(area.x, area.y, if (buffer.capabilities().unicode) { "●" } else { "*" })
    }
}

class CapabilityTestInput <: InputSource {
    private var sent = false
    public func readAvailable(_: Int64): Array<Byte> {
        if (sent) { return [] }
        sent = true
        [b'q']
    }
}

class CapabilityTestDriver <: TerminalDriver {
    public func name(): String { "test" }
    public func enterRawMode(): Bool { false }
    public func restore(): Unit {}
    public func size(): ?Rect { Some(Rect(0, 0, 2, 1)) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities(size: backend.size(), unicode: false, trueColor: false, colorLevel: 8)
    }
}

@Test
class CapabilitiesRenderTest {
    @TestCase
    func bufferCapabilitiesSurviveCopyAndResize(): Unit {
        let buffer = Buffer(Rect(0, 0, 2, 1))
        @Expect(buffer.capabilities().unicode)
        @Expect(buffer.capabilities().trueColor)
        buffer.setCapabilities(TerminalCapabilities(unicode: false, trueColor: false, colorLevel: 8))
        @Expect(!buffer.copy().capabilities().unicode)
        @Expect(buffer.resize(Rect(0, 0, 3, 1)).capabilities().colorLevel, 8)
    }

    @TestCase
    func capabilityChangeInvalidatesFullSurface(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 4, 1))
        let terminal = Terminal(backend)
        let render = { frame: Frame => frame.renderWidget(CapabilityTestWidget(), frame.area) }
        _ = terminal.draw(render)
        @Expect(backend.assertCell(0, 0, "●"))
        terminal.setCapabilities(TerminalCapabilities(unicode: false))
        let metrics = terminal.draw(render, dirtyRects: Some(DirtyRects.full(Rect(2, 0, 1, 1))))
        @Expect(metrics.fullRedraw)
        @Expect(backend.assertCell(0, 0, "*"))
    }

    @TestCase
    func ansiOutputAdaptsStylesWithoutChangingLogicalCells(): Unit {
        let output = CapabilityTestOutput()
        let backend = AnsiBackend(output: output, fallbackArea: Rect(0, 0, 1, 1))
        let buffer = Buffer(Rect(0, 0, 1, 1))
        let color = Style(fg: Color.Rgb(123, 45, 67))
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 256))
        buffer.setCell(0, 0, Cell("X", style: color))
        backend.draw(buffer)
        @Expect(output.text().contains("38;5;"))
        @Expect(!output.text().contains("38;2;"))
        @Expect(buffer.getCell(0, 0).style == color)
    }

    @TestCase
    func ansiDiffAndMonochromeRespectCapabilities(): Unit {
        let output = CapabilityTestOutput()
        let backend = AnsiBackend(output: output, driver: FallbackTerminalDriver(area: Rect(0, 0, 1, 1)))
        let terminal = Terminal(backend)
        terminal.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 256))
        _ = terminal.draw({ frame => frame.fill(frame.area, Style(fg: Color.Rgb(123, 45, 67))) })
        _ = terminal.draw({ frame => frame.fill(frame.area, Style(fg: Color.Rgb(88, 50, 200))) })
        @Expect(output.text().contains("38;5;"))
        @Expect(!output.text().contains("38;2;"))

        let monoOutput = CapabilityTestOutput()
        let mono = Terminal(AnsiBackend(output: monoOutput, driver: FallbackTerminalDriver(area: Rect(0, 0, 1, 1))))
        mono.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 1))
        _ = mono.draw({ frame => frame.fill(frame.area, Style(fg: Color.Rgb(123, 45, 67))) })
        _ = mono.draw({ frame => frame.fill(frame.area, Style(fg: Color.Rgb(88, 50, 200))) })
        @Expect(!monoOutput.text().contains("38;5;"))
        @Expect(!monoOutput.text().contains("38;2;"))
    }

    @TestCase
    func headlessOverrideAndResetMatchTerminalBehavior(): Unit {
        let result = AppTestRunner.run(
            HeadlessScript().message("ascii").message("reset"),
            { frame => frame.renderWidget(CapabilityTestWidget(), frame.area) },
            { event => match (event) {
                case Event.Message("ascii") => UpdateResult.withCommand(
                    Command.SetCapabilitiesOverride(Some(TerminalCapabilities(unicode: false))))
                case Event.Message("reset") => UpdateResult.withCommand(Command.SetCapabilitiesOverride(Option<TerminalCapabilities>.None))
                case _ => UpdateResult.unchanged()
            } },
            options: HeadlessRunOptions(area: Rect(0, 0, 2, 1))
        )
        @Expect(result.frames.size, 3)
        @Expect(result.frames[0].getCell(0, 0).symbol, "●")
        @Expect(result.frames[1].getCell(0, 0).symbol, "*")
        @Expect(result.frames[2].getCell(0, 0).symbol, "●")
    }

    @TestCase
    func headlessCapabilityEventsUpdateBaselineWithoutReplacingOverride(): Unit {
        let script = HeadlessScript().event(Event.Capabilities(TerminalCapabilities(unicode: false)))
            .message("override").message("detect").message("reset")
        let result = AppTestRunner.run(script,
            { frame => frame.renderWidget(CapabilityTestWidget(), frame.area) },
            { event => match (event) {
                case Event.Message("override") => UpdateResult.withCommand(
                    Command.SetCapabilitiesOverride(Some(TerminalCapabilities(unicode: true))))
                case Event.Message("detect") => UpdateResult.withCommand(
                    Command.Emit(Event.Capabilities(TerminalCapabilities(unicode: false))))
                case Event.Message("reset") => UpdateResult.withCommand(
                    Command.SetCapabilitiesOverride(Option<TerminalCapabilities>.None))
                case _ => UpdateResult.unchanged()
            } }, options: HeadlessRunOptions(area: Rect(0, 0, 2, 1)))
        @Expect(result.frames.size, 5)
        @Expect(result.frames[0].getCell(0, 0).symbol, "●")
        @Expect(result.frames[1].getCell(0, 0).symbol, "*")
        @Expect(result.frames[2].getCell(0, 0).symbol, "●")
        @Expect(result.frames[3].getCell(0, 0).symbol, "●")
        @Expect(result.frames[4].getCell(0, 0).symbol, "*")
    }

    @TestCase
    func appUsesDetectedCapabilitiesBeforeFirstFrame(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 2, 1))
        App(backend: backend, inputSource: CapabilityTestInput(), terminalDriver: CapabilityTestDriver(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false)
            .runWithCommands(
                { frame => frame.renderWidget(CapabilityTestWidget(), frame.area) },
                { event => match (event) {
                    case Event.KeyDown(_) => UpdateResult.exit()
                    case _ => UpdateResult.unchanged()
                } }
            )
        @Expect(backend.assertCell(0, 0, "*"))
        @Expect(!backend.lastBuffer().getOrThrow().capabilities().unicode)
    }

    @TestCase
    func appAppliesStartupOverrideBeforeFirstFrame(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 2, 1))
        App(backend: backend, inputSource: CapabilityTestInput(), terminalDriver: CapabilityTestDriver(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false)
            .runWithCommands(
                { frame => frame.renderWidget(CapabilityTestWidget(), frame.area) },
                { event => match (event) {
                    case Event.Capabilities(_) => UpdateResult.withCommand(
                        Command.SetCapabilitiesOverride(Some(TerminalCapabilities(unicode: true))))
                    case Event.KeyDown(_) => UpdateResult.exit()
                    case _ => UpdateResult.unchanged()
                } }
            )
        @Expect(backend.assertCell(0, 0, "●"))
    }
    @TestCase
    func headlessRetainsAsyncCompletionsAcrossSourceTurns(): Unit {
        let total: Int64 = 130
        let gate = Semaphore(1)
        let ready = Semaphore(total)
        gate.acquire()
        ready.acquire(amount: total)
        let completed = ArrayList<String>()
        let finished = ArrayList<Int64>()
        let script = HeadlessScript().message("start").message("settle").tick(count: 3)
        for (_ in 0..8) { _ = script.waitMillis(25) }
        let result = AppTestRunner.run(script, { _ => }, { event =>
            match (event) {
                case Event.Message("start") =>
                    let commands = ArrayList<Command>()
                    for (index in 0..total) {
                        commands.add(Command.AsyncTask("task-${index}", { =>
                            gate.acquire()
                            gate.release()
                            ready.release()
                            Event.Message("done")
                        }))
                    }
                    UpdateResult.withCommand(Command.Batch(commands.toArray()))
                case Event.Message("settle") =>
                    gate.release()
                    var count: Int64 = 0
                    let deadline = MonoTime.now() + Duration.second * 10
                    while (count < total && MonoTime.now() < deadline) {
                        if (ready.tryAcquire()) { count++ } else { sleep(Duration.millisecond) }
                    }
                    finished.add(count)
                    // Let the released task closures finish before importing their events.
                    sleep(Duration.millisecond * 100)
                    UpdateResult.unchanged()
                case Event.AsyncCompleted(id, Event.Message("done")) =>
                    completed.add(id)
                    UpdateResult.unchanged()
                case _ => UpdateResult.unchanged()
            }
        }, options: HeadlessRunOptions(area: Rect(0, 0, 1, 1), captureBuffers: false, captureSnapshots: false))
        @Expect(result.passed())
        @Assert(finished.size, 1)
        @Expect(finished[0], total)
        @Expect(completed.size, total)
        for (index in 0..total) {
            var occurrences: Int64 = 0
            for (id in completed) { if (id == "task-${index}") { occurrences++ } }
            @Expect(occurrences, 1)
        }
    }

}
