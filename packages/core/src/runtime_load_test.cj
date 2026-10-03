package core

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

class BatchedProcessRuntime <: ProcessRuntime {
    private var delivered = false
    private let count: Int64
    var reads: Int64 = 0
    var closed = false
    init(count!: Int64 = 8192) { this.count = count }
    public func start(id: String, _: ProcessSpec): Event { Event.ProcessStarted(id) }
    public func cancel(id: String): Event { Event.ProcessCancelRequested(id) }
    public func sources(): Array<EventSource> { [] }
    public func drain(): Array<Event> {
        reads++
        if (delivered) { return [] }
        delivered = true
        let events = ArrayList<Event>()
        for (i in 0..count) { events.add(Event.ProcessOutput("burst", ProcessOutputStream.Stdout, [UInt8(i % 251)])) }
        events.add(Event.Message("burst-finished"))
        events.toArray()
    }
    public func activeCount(): Int64 { 0 }
    public func nextTimeoutMillis(): ?Int64 { None }
    public func metrics(): ProcessMetrics { ProcessMetrics() }
    public func closeAll(): Unit { closed = true }
}

class RuntimeLoadObservation {
    var outputs: Int64 = 0
    var keys: Int64 = 0
    var frames: Int64 = 0
    var firstKeyAt: Int64 = -1
    var exited = false
    var starts: Int64 = 0
    var messages: Int64 = 0
}

class DeferredFailurePtyRuntime <: PtyRuntime {
    private let delegate = FakePtyRuntime()
    private let terminal: Bool
    private var processId = ""
    private var reported = false
    var closeCalls: Int64 = 0
    init(terminal: Bool) { this.terminal = terminal }
    public func start(id: String, spec: PtySpec): Event { processId = id; delegate.start(id, spec) }
    public func process(id: String): ?PtyProcess { delegate.process(id) }
    public func write(id: String, bytes: Array<Byte>): Event { delegate.write(id, bytes) }
    public func resize(id: String, size: PtySize): Event { delegate.resize(id, size) }
    public func signal(id: String, signal: PtySignal): Event { delegate.signal(id, signal) }
    public func close(id: String): Event { closeCalls++; delegate.close(id) }
    public func sources(): Array<EventSource> { [] }
    public func activeCount(): Int64 { delegate.activeCount() }
    public func drain(): Array<Event> {
        if (!reported && delegate.activeCount() > 0) {
            reported = true
            if (terminal) { delegate.injectFailure(processId, "terminal failure") }
            else { return [Event.PtyFailed(processId, "deferred write failed")] }
        }
        delegate.drain()
    }
}

@Test
class RuntimeLoadTest {
    @TestCase
    func deferredPtyFailureRetainsOwnershipUntilRuntimeReleasesProcess(): Unit {
        for (terminal in [false, true]) {
            let runtime = DeferredFailurePtyRuntime(terminal)
            let observed = RuntimeLoadObservation()
            let app = App(backend: TestBackend(area: Rect(0, 0, 1, 1)),
                inputSource: RecordingInputSource(), probeInputSource: RecordingInputSource(),
                rawMode: false, alternateScreen: false, bracketedPaste: false,
                hideCursor: false, resize: false, eventWaiter: CountingEventWaiter())
            app.attachPtyRuntime(runtime)
            app.runWithCommands({_ =>}, {event => match (event) {
                case Event.Capabilities(_) => UpdateResult.withCommand(Command.PtyStart("owned", PtySpec("fake")))
                case Event.PtyFailed(_, _) => observed.exited = true; UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }})
            @Expect(observed.exited)
            @Expect(runtime.activeCount(), 0)
            @Expect(runtime.closeCalls, if (terminal) { 0 } else { 1 })
        }
    }

    @TestCase
    func feedbackCannotHoldEventQueueAboveAdmissionMarkForever(): Unit {
        let source = BatchedProcessRuntime(count: 512)
        let observed = RuntimeLoadObservation()
        let app = App(backend: TestBackend(area: Rect(0, 0, 1, 1)),
            inputSource: BufferedInputSource(Array<Byte>(64, repeat: b'a')),
            probeInputSource: RecordingInputSource(), rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false, eventWaiter: CountingEventWaiter())
        app.attachProcessRuntime(source)
        app.runWithCommands({_ => observed.frames++}, {event => match (event) {
            case Event.ProcessOutput(_, _, _) =>
                observed.outputs++
                UpdateResult.withCommand(Command.Message("feedback"))
            case Event.Message("feedback") =>
                observed.messages++
                if (observed.messages > 4096) { throw Exception("feedback starved remaining source events") }
                UpdateResult.withCommand(Command.Message("feedback"))
            case Event.KeyDown(_) => observed.keys++; UpdateResult.unchanged()
            case Event.Message("burst-finished") => UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(observed.outputs, 512)
        @Expect(observed.keys, 64)
        @Expect(observed.frames > 0)
        @Expect(observed.messages > 0 && observed.messages <= 4096)
    }

    @TestCase
    func sourceSnapshotLargerThanQueueRetainsOrderAndYieldsToInput(): Unit {
        let source = BatchedProcessRuntime()
        let metrics = AppMetrics()
        let waiter = CountingEventWaiter()
        let observed = RuntimeLoadObservation()
        let app = App(backend: TestBackend(area: Rect(0, 0, 1, 1)),
            inputSource: BufferedInputSource(Array<Byte>(2000, repeat: b'a')),
            probeInputSource: RecordingInputSource(), rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false,
            metrics: Some(metrics), eventWaiter: waiter)
        app.attachProcessRuntime(source)
        app.runWithCommands({_ => observed.frames++}, {event => match (event) {
            case Event.ProcessOutput(_, _, bytes) =>
                @Expect(bytes, [UInt8(observed.outputs % 251)])
                observed.outputs++
                UpdateResult.unchanged()
            case Event.KeyDown(_) =>
                if (observed.firstKeyAt < 0) { observed.firstKeyAt = observed.outputs }
                observed.keys++
                UpdateResult.next()
            case Event.Message("burst-finished") => UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(observed.outputs, 8192)
        @Expect(observed.keys, 2000)
        @Expect(observed.firstKeyAt >= 0 && observed.firstKeyAt < 256)
        @Expect(observed.frames > 1)
        @Expect(source.reads, 1)
        @Expect(source.closed)
        @Expect(waiter.waits, 0)
        @Expect(metrics.runtime().queueOverflows, 0)
        @Expect(metrics.runtime().maxQueueDepth <= 512)
        @Expect(metrics.runtime().queueEnqueued, metrics.runtime().queueProcessed)
    }

    @TestCase
    func explicitPtyCloseRetainsLargeTailBeforeTerminalEvent(): Unit {
        let runtime = FakePtyRuntime()
        let observed = RuntimeLoadObservation()
        let app = App(backend: TestBackend(area: Rect(0, 0, 1, 1)),
            inputSource: RecordingInputSource(), probeInputSource: RecordingInputSource(),
            rawMode: false, alternateScreen: false, bracketedPaste: false,
            hideCursor: false, resize: false, eventWaiter: CountingEventWaiter())
        app.attachPtyRuntime(runtime)
        app.runWithCommands({_ =>}, {event => match (event) {
            case Event.Capabilities(_) => UpdateResult.withCommand(Command.PtyStart("tail", PtySpec("fake")))
            case Event.PtyStarted(_) =>
                for (i in 0..5000) { runtime.injectOutput("tail", [UInt8(i % 251)]) }
                UpdateResult.withCommand(Command.PtyClose("tail"))
            case Event.PtyOutput(_, _, bytes) =>
                @Expect(bytes, [UInt8(observed.outputs % 251)])
                observed.outputs++
                UpdateResult.unchanged()
            case Event.PtyExited(_, _) => observed.exited = true; UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(observed.exited)
        @Expect(observed.outputs, 5000)
        @Expect(runtime.activeCount(), 0)
    }

    @TestCase
    func replacementOwnershipSurvivesExitBeforeNewStartedCallback(): Unit {
        let runtime = FakePtyRuntime()
        let observed = RuntimeLoadObservation()
        let app = App(backend: TestBackend(area: Rect(0, 0, 1, 1)),
            inputSource: RecordingInputSource(), probeInputSource: RecordingInputSource(),
            rawMode: false, alternateScreen: false, bracketedPaste: false,
            hideCursor: false, resize: false, eventWaiter: CountingEventWaiter())
        app.attachPtyRuntime(runtime)
        app.runWithCommands({_ =>}, {event => match (event) {
            case Event.Capabilities(_) => UpdateResult.withCommand(Command.PtyStart("same", PtySpec("old")))
            case Event.PtyStarted(_) =>
                observed.starts++
                UpdateResult.withCommand(Command.PtyStart("same", PtySpec("new")))
            case Event.PtyExited(_, _) => observed.exited = true; UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(observed.exited)
        @Expect(observed.starts, 1)
        @Expect(runtime.activeCount(), 0)
    }

    @TestCase
    func boundedTimerDrainRotatesAndPreservesDeferredDeadlines(): Unit {
        let clock = TestClock()
        let timers = TimerRuntime(clock: clock)
        for (id in ["a", "b", "c"]) { timers.start(TimerSpec(id, Duration.millisecond)) }
        clock.advanceMillis(1)
        let ids = ArrayList<String>()
        for (_ in 0..6) {
            @Expect(timers.drain(maxEvents: 0).size, 0)
            let events = timers.drain(maxEvents: 1)
            @Assert(events.size, 1)
            match (events[0]) { case Event.Timer(value) => ids.add(value.id); case _ => @Expect(false) }
            clock.advanceMillis(1)
        }
        @Expect(ids.toArray(), ["a", "b", "c", "a", "b", "c"])
        @Expect(timers.stop("a"))
        @Expect(!timers.stop("missing"))
        timers.clear()
        @Expect(timers.drain(maxEvents: 1).size, 0)
        @Expect(timers.nextTimeoutMillis().isNone())
        for (id in ["first", "second", "third"]) {
            timers.start(TimerSpec(id, Duration.millisecond, mode: TimerMode.OneShot))
        }
        clock.advanceMillis(1)
        @Expect(timers.drain(maxEvents: 2).size, 2)
        @Expect(timers.nextTimeoutMillis(), Some(Int64(0)))
        @Expect(timers.drain(maxEvents: 2).size, 1)
        @Expect(timers.nextTimeoutMillis().isNone())
    }

    @TestCase
    func sourceBatchRejectsOverwriteAndAppendsAfterRemainingPrefix(): Unit {
        let batch = RuntimeEventBatch()
        @Expect(batch.size(), 0)
        @Expect(batch.take(-1).size, 0)
        batch.replace([Event.Message("one"), Event.Message("two")])
        @Expect(batch.take(0).size, 0)
        @Expect(batch.take(1).size, 1)
        var rejected = false
        try { batch.replace([]) } catch (_: IllegalStateException) { rejected = true }
        @Expect(rejected)
        batch.append([])
        batch.append([Event.Message("three")])
        let remaining = batch.take(100)
        @Assert(remaining.size, 2)
        match (remaining[0]) { case Event.Message("two") => (); case _ => @Expect(false) }
        match (remaining[1]) { case Event.Message("three") => (); case _ => @Expect(false) }
        @Expect(batch.size(), 0)
        batch.replace([])
        @Expect(batch.take(1).size, 0)
    }

    @TestCase
    func workBudgetCountsYieldOncePerTurnAndResetsMetricsEpoch(): Unit {
        let metrics = AppMetrics()
        let queue = RuntimeQueue<Unit>(metrics: Some(metrics), capacity: 1)
        queue.beginTurn(workBudget: 0)
        @Expect(queue.takeSourceTurn())
        @Expect(!queue.takeSourceTurn())
        @Expect(queue.tryConsumeWork())
        @Expect(!queue.tryConsumeWork())
        @Expect(!queue.tryConsumeWork())
        @Expect(queue.yieldedTurns(), 1)
        @Expect(metrics.runtime().yieldedTurns, 1)
        _ = queue.enqueueEvent(Event.Message("accepted"))
        var rejected = false
        try { _ = queue.enqueueEvent(Event.Message("rejected")) } catch (_: IllegalStateException) { rejected = true }
        @Expect(rejected)
        @Expect(metrics.runtime().queueOverflows, 1)
        let prior = metrics.runtime()
        metrics.reset()
        @Expect(metrics.runtime().queueOverflows, 0)
        @Expect(metrics.runtime().yieldedTurns, 0)
        @Expect(prior.queueOverflows, 1)
        queue.beginTurn(workBudget: 2)
        @Expect(queue.takeSourceTurn())
        @Expect(queue.tryConsumeWork())
        @Expect(queue.tryConsumeWork())
        @Expect(!queue.tryConsumeWork())
        @Expect(metrics.runtime().yieldedTurns, 1)
        @Expect(queue.yieldedTurns(), 2)
    }
}
