package core

import std.collection.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

private class Audit20261003Input <: InputSource {
    private var calls: Int64 = 0

    public func readAvailable(maxBytes: Int64): Array<Byte> {
        calls++
        if (maxBytes <= 0) { return [] }
        if (calls == 1) { return unsafe { "abcde".rawData() } }
        if (calls == 3) { return unsafe { "q".rawData() } }
        []
    }
}

private class Audit20261003RenderState {
    var left: String = "a"
    var right: String = "b"
    let fullFirst: Bool

    init(fullFirst: Bool) { this.fullFirst = fullFirst }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Char(r'a') =>
                    if (fullFirst) { right = "B"; UpdateResult.next() }
                    else { left = "A"; UpdateResult.dirty(Rect(0, 0, 1, 1)) }
                case KeyCode.Char(r'b') =>
                    if (fullFirst) { left = "A"; UpdateResult.dirty(Rect(0, 0, 1, 1)) }
                    else { right = "B"; UpdateResult.next() }
                case KeyCode.Char(r'q') => UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
            case _ => UpdateResult.unchanged()
        }
    }

    func render(frame: Frame): Unit {
        frame.canvas().drawText(0, 0, left, Style.default())
        frame.canvas().drawText(7, 0, right, Style.default())
    }
}

@Test
class Audit20261003RuntimeTest {
    @TestCase
    func catchUpBudgetBoundsBacklogAndCountsDiscardedSlots(): Unit {
        for (budget in [Int64(0), Int64(1), Int64(2), Int64(100)]) {
            let clock = TestClock()
            let timers = TimerRuntime(clock: clock)
            let policy = FrameMissPolicy.CatchUp(budget)
            timers.start(TimerSpec("bounded", Duration.millisecond * 5, missPolicy: policy))
            clock.advanceMillis(103)
            var fired: Int64 = 0
            var dropped: Int64 = 0
            // Twenty scheduled firings are due at 5, 10, ..., 100 ms.
            // Allow the current firing and at most budget additional firings.
            for (_ in 0..21) {
                for (event in timers.drain()) {
                    match (event) {
                        case Event.Timer(timer) => fired++; dropped += timer.droppedFrames
                        case _ => @Fail("unexpected timer event")
                    }
                }
            }
            @Expect(fired, min(Int64(20), budget + 1))
            @Expect(dropped, max(Int64(0), 19 - budget))
            @Expect(timers.nextTimeoutMillis(), Some(2))
            let origin = MonoTime.now()
            let due = origin + Duration.millisecond * 5
            let now = origin + Duration.millisecond * 103
            let next = nextDue(now, due, Duration.millisecond * 5, policy)
            @Expect((next - origin).toMilliseconds(), 10 + 5 * max(Int64(0), 19 - budget))
            @Expect(droppedFrames(now - due, Duration.millisecond * 5, policy), max(Int64(0), 19 - budget))
        }
        let origin = MonoTime.now()
        let every = Duration.microsecond * 500
        let late = Duration.microsecond * 1950
        @Expect(droppedFrames(late, every, FrameMissPolicy.CatchUp(1)), 2)
        let next = nextDue(origin + every + late, origin + every, every, FrameMissPolicy.CatchUp(1))
        @Expect((next - origin).toMicroseconds(), 2000)
    }

    @TestCase
    func enhancedShiftTabMovesFocusBackward(): Unit {
        let focus = FocusManager()
        focus.add("one")
        focus.add("two")
        focus.add("three")
        @Assert(focus.focus("two"))
        let events = EventParser().push(unsafe { "\u{1B}[9;2u".rawData() })
        @Assert(events.size, 1)
        match (events[0]) {
            case Event.KeyDown(key) => @Expect(focus.handle(key))
            case _ => @Fail("enhanced Shift+Tab was not decoded")
        }
        @Expect(focus.current(), Some("one"))
        @Expect(focus.handle(KeyEvent(KeyCode.Tab)))
        @Expect(focus.current(), Some("two"))
        @Expect(focus.handle(KeyEvent(KeyCode.BackTab)))
        @Expect(focus.current(), Some("one"))
    }

    @TestCase
    func unrelatedOwnerCannotConsumeAnotherOperationsCompletion(): Unit {
        let runtime = AsyncOwnershipRuntime()
        let owner = runtime.acquireOwner(1)
        let unrelated = runtime.acquireOwner(2)
        let operation = match (runtime.start(owner)) {
            case Some(value) => value
            case None => throw Exception("operation was not started")
        }
        match (runtime.complete(OwnedAsyncCompletion(unrelated, operation, Event.Message("wrong owner")))) {
            case CompletionDisposition.Orphan => ()
            case _ => @Fail("mismatched owner was accepted")
        }
        match (runtime.complete(OwnedAsyncCompletion(owner, operation, Event.Message("valid")))) {
            case CompletionDisposition.Applied => ()
            case _ => @Fail("an unrelated completion settled the valid owner's operation")
        }
        match (runtime.complete(OwnedAsyncCompletion(owner, operation, Event.Message("duplicate")))) {
            case CompletionDisposition.Duplicate => ()
            case _ => @Fail("a legitimate completion was applied twice")
        }
        @Expect(runtime.orphanCompletions(), 1)
    }

    @TestCase
    func fullInvalidationSurvivesPartialUpdatesInEitherOrder(): Unit {
        for (fullFirst in [false, true]) {
            let backend = TestBackend(area: Rect(0, 0, 8, 1))
            let state = Audit20261003RenderState(fullFirst)
            let app = App(
                eventWaiter: NoopEventWaiter(),
                backend: backend,
                inputSource: Audit20261003Input(),
                rawMode: false,
                resize: false
            )
            app.runWithCommands({ frame => state.render(frame) }, { event => state.update(event) })
            @Expect(backend.assertCell(0, 0, "A"))
            @Expect(backend.assertCell(7, 0, "B"))
        }
    }

    @TestCase
    func applicationCursorKeysDecodeAcrossEveryByteSplit(): Unit {
        let suffixes: Array<Byte> = [b'A', b'B', b'C', b'D', b'H', b'F']
        let expected = [KeyCode.Up, KeyCode.Down, KeyCode.Right, KeyCode.Left, KeyCode.Home, KeyCode.End]
        for (index in 0..suffixes.size) {
            let bytes: Array<Byte> = [27, b'O', suffixes[index], b'x']
            for (split in 0..=bytes.size) {
                let parser = EventParser()
                let events = ArrayList<Event>()
                for (event in parser.push(bytes[..split])) { events.add(event) }
                for (event in parser.push(bytes[split..])) { events.add(event) }
                @Assert(events.size, 2)
                match (events[0]) {
                    case Event.KeyDown(key) => @Expect(keyCodeEquals(key.code, expected[index]))
                    case _ => @Fail("application cursor key was not decoded")
                }
                match (events[1]) {
                    case Event.KeyDown(key) => @Expect(keyCodeEquals(key.code, KeyCode.Char(r'x')))
                    case _ => @Fail("following input was lost")
                }
            }
        }
    }
}
