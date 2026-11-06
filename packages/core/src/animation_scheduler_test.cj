package core

import std.collection.*
import std.io.*
import std.unittest.*
import std.unittest.testmacro.*

private class AnimationOutput <: OutputStream {
    let bytes = ArrayList<Byte>()
    public func write(buffer: Array<Byte>): Unit { for (byte in buffer) { bytes.add(byte) } }
    public func flush(): Unit {}
    func text(): String { unsafe { String.fromUtf8Unchecked(bytes.toArray()) } }
}

private class AnimationInput <: InputSource {
    var frames: Int64 = 0
    private var sent = false
    public func readAvailable(_: Int64): Array<Byte> {
        if (frames < 3 || sent) { return [] }
        sent = true
        [b'q']
    }
}

// Produce one input event per parser drain while advancing an injected clock.
private class AnimationPartialInput <: InputSource {
    private let clock: TestClock
    private var pause = false
    private var count: Int64 = 0
    public init(clock: TestClock) { this.clock = clock }
    public func readAvailable(_: Int64): Array<Byte> {
        if (pause) { pause = false; return [] }
        pause = true
        count++
        clock.advanceMillis(10)
        if (count > 30) { return [b'q'] }
        [b'x']
    }
}

@Test
class AnimationSchedulerTest {
    @TestCase
    func identityGroupsVisibilityAndCleanupAreIndependent(): Unit {
        let clock = TestClock()
        let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 20)
        @Expect(scheduler.register("one", "first", config: AnimationConfig(durationMillis: 1000), group: Some("sync")))
        @Expect(!scheduler.register("one", "first", group: Some("other")))
        clock.advanceMillis(250)
        @Expect(scheduler.register("two", "first", config: AnimationConfig(durationMillis: 2000), group: Some("sync")))
        @Expect(scheduler.register("one", "separate"))
        @Expect(scheduler.sample("two", "first").getOrThrow().elapsedMillis, 250)
        @Expect(scheduler.sample("one", "separate").getOrThrow().elapsedMillis, 0)
        @Expect(scheduler.sample("two", "first").getOrThrow().durationMillis, 2000)
        scheduler.framePresented()
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 50)
        @Expect(scheduler.setVisible("one", "first", false))
        @Expect(scheduler.setVisible("two", "first", false))
        @Expect(scheduler.setVisible("one", "separate", false))
        @Expect(scheduler.nextTimeoutMillis().isNone())
        clock.advanceMillis(800)
        @Expect(scheduler.setVisible("two", "first", true))
        let resumed = scheduler.sample("two", "first").getOrThrow()
        @Expect(resumed.elapsedMillis, 1050)
        @Expect(resumed.cycleMillis, 1050)
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 0)
        scheduler.removeScope("two")
        @Expect(scheduler.sample("two", "first").isNone())
        @Expect(scheduler.nextTimeoutMillis().isNone())
        @Expect(scheduler.remove("one", "first"))
        @Expect(!scheduler.remove("one", "first"))
        clock.advanceMillis(100)
        @Expect(scheduler.register("new", "first", group: Some("sync")))
        @Expect(scheduler.sample("new", "first").getOrThrow().elapsedMillis, 0)
    }

    @TestCase
    func componentSettingsAndFrameRateLimitAreIndependent(): Unit {
        let clock = TestClock()
        let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 24)
        @Expect(scheduler.register("scope", "one", config: AnimationConfig(framesPerSecond: 100)))
        @Expect(scheduler.register("scope", "two", config: AnimationConfig(framesPerSecond: 10)))
        scheduler.framePresented()
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 42)
        @Expect(scheduler.setConfig("scope", "one", AnimationConfig(enabled: false)))
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 100)
        clock.advanceMillis(101)
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 0)
        @Expect(!scheduler.setConfig("scope", "missing", AnimationConfig()))
        @Expect(!scheduler.setVisible("scope", "missing", true))
    }

    @TestCase
    func sharedTimeAxisDoesNotOverridePerComponentRate(): Unit {
        let clock = TestClock()
        let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 60)
        @Expect(scheduler.register("scope", "fast", config: AnimationConfig(framesPerSecond: 60), group: Some("shared")))
        @Expect(scheduler.register("scope", "slow", config: AnimationConfig(framesPerSecond: 1), group: Some("shared")))
        clock.advanceMillis(500)
        @Expect(scheduler.sample("scope", "fast").getOrThrow().elapsedMillis > 0)
        @Expect(scheduler.sample("scope", "slow").getOrThrow().elapsedMillis, 0)
        clock.advanceMillis(500)
        @Expect(scheduler.sample("scope", "slow").getOrThrow().elapsedMillis, 1000)
    }

    @TestCase
    func partialUpdatesDoNotStarveAnUnrelatedAnimation(): Unit {
        let clock = TestClock()
        let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 10)
        @Expect(scheduler.register("app", "activity", config: AnimationConfig(framesPerSecond: 10)))
        let input = AnimationPartialInput(clock)
        let samples = ArrayList<Int64>()
        let app = App(
            backend: TestBackend(area: Rect(0, 0, 4, 1)),
            inputSource: input,
            terminalDriver: FallbackTerminalDriver(area: Rect(0, 0, 4, 1)),
            probeInputSource: AnimationInput(),
            rawMode: false, alternateScreen: false, bracketedPaste: false,
            hideCursor: false, resize: false
        )
        app.attachAnimationScheduler(scheduler)
        app.runWithCommands({ frame =>
            if (frame.isDirty(Rect(3, 0, 1, 1))) {
                samples.add(scheduler.sample("app", "activity").getOrThrow().elapsedMillis)
            }
        }, { event =>
            match (event) {
                case Event.KeyDown(key) => match (key.code) {
                    case KeyCode.Char(r'q') => UpdateResult.exit()
                    case _ => UpdateResult.dirty(Rect(0, 0, 1, 1))
                }
                case _ => UpdateResult.unchanged()
            }
        })
        @Expect(samples.size >= 2)
        if (samples.size >= 2) { @Expect(samples[samples.size - 1] >= 100) }
    }

    @TestCase
    func disablingFocusedItemMovesToNextEnabledOrClearsFocus(): Unit {
        let focus = FocusManager()
        focus.add("first")
        focus.add("disabled", enabled: false)
        focus.add("last")
        @Expect(focus.current(), Some("first"))
        @Expect(focus.setEnabled("first", false))
        @Expect(focus.current(), Some("last"))
        @Expect(!focus.focus("first"))
        @Expect(focus.setEnabled("last", false))
        @Expect(focus.current().isNone())
        @Expect(focus.next().isNone())
        @Expect(focus.setEnabled("first", true))
        @Expect(focus.current(), Some("first"))
        @Expect(focus.setEnabled("last", true))
        @Expect(focus.current(), Some("first"))
        @Expect(!focus.setEnabled("missing", false))
        @Expect(focus.current(), Some("first"))
    }

    @TestCase
    func appPresentsAnimationWithoutPeriodicTicks(): Unit {
        let input = AnimationInput()
        let scheduler = AnimationScheduler(maxFramesPerSecond: 60)
        @Expect(scheduler.register("app", "activity", config: AnimationConfig(framesPerSecond: 60)))
        let app = App(
            backend: TestBackend(area: Rect(0, 0, 4, 1)),
            inputSource: input,
            terminalDriver: FallbackTerminalDriver(area: Rect(0, 0, 4, 1)),
            probeInputSource: AnimationInput(),
            rawMode: false, alternateScreen: false, bracketedPaste: false,
            hideCursor: false, resize: false
        )
        app.attachAnimationScheduler(scheduler)
        app.run({_ => input.frames++}, {event =>
            match (event) { case Event.KeyDown(_) => ControlFlow.Exit; case _ => ControlFlow.Continue }
        })
        @Expect(input.frames >= 3)
    }

    @TestCase
    func sixteenColorBackendUsesBasicAndBrightSgrCodes(): Unit {
        let output = AnimationOutput()
        let backend = AnsiBackend(output: output, fallbackArea: Rect(0, 0, 2, 1))
        let buffer = Buffer(Rect(0, 0, 2, 1))
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 16))
        buffer.setCell(0, 0, Cell("A", style: Style(fg: Color.Indexed(9), bg: Color.Indexed(12))))
        buffer.setCell(1, 0, Cell("B", style: Style(fg: Color.Indexed(3), bg: Color.Indexed(4))))
        backend.draw(buffer)
        let text = output.text()
        @Expect(text.contains("[91m"))
        @Expect(text.contains("[104m"))
        @Expect(!text.contains("38;5;"))
        @Expect(!text.contains("48;5;"))
        @Expect(!text.contains("38;2;"))
        @Expect(!text.contains("48;2;"))
    }
}
