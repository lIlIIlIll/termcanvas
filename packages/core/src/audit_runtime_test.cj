package core

import std.collection.*
import std.fs.*
import std.sync.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

class AuditRuntimeInput <: InputSource {
    private let chunks: Array<Array<Byte>>
    private var position: Int64 = 0
    var reads: Int64 = 0

    init(chunks: Array<Array<Byte>>) { this.chunks = chunks }
    public func readAvailable(maxBytes: Int64): Array<Byte> {
        reads++
        if (position >= chunks.size || maxBytes <= 0) { return [] }
        let chunk = chunks[position]
        position++
        chunk
    }
}

class AuditRuntimeDriver <: TerminalDriver {
    private let failStart: Bool
    init(failStart: Bool) { this.failStart = failStart }
    public func name(): String { "audit-runtime" }
    public func enterRawMode(): Bool {
        if (failStart) { throw Exception("audit startup failure") }
        true
    }
    public func restore(): Unit {}
    public func size(): ?Rect { Some(Rect(0, 0, 8, 2)) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities(size: backend.size(), driverName: name())
    }
}

class AuditRuntimeAsyncEvents {
    var completed: Int64 = 0
    var cancelled: Int64 = 0
    var failed: Int64 = 0
    var lastCompletedPayload: String = ""
    func observe(event: Event): UpdateResult {
        match (event) {
            case Event.AsyncCompleted(_, payload) =>
                completed++
                match (payload) {
                    case Event.Message(text) => lastCompletedPayload = text
                    case _ => ()
                }
            case Event.AsyncCancelled(_) => cancelled++
            case Event.AsyncFailed(_, _) => failed++
            case _ => ()
        }
        UpdateResult.unchanged()
    }
}

class AuditRuntimeCounter {
    var value: Int64 = 0
}

func auditDrainAsync(runtime: AsyncRuntime, state: AuditRuntimeAsyncEvents, untilPending!: Int64 = 0): Unit {
    let deadline = MonoTime.now() + Duration.second * 2
    let queue = ArrayList<Command>()
    while (runtime.pendingCount() > untilPending && MonoTime.now() < deadline) {
        App.processCommands({ event => state.observe(event) }, queue, asyncRuntime: runtime)
        if (runtime.pendingCount() > untilPending) { sleep(Duration.millisecond) }
    }
}

func auditAcquireSignal(signal: Semaphore): Bool {
    let deadline = MonoTime.now() + Duration.second * 2
    while (MonoTime.now() < deadline) {
        if (signal.tryAcquire()) { return true }
        sleep(Duration.millisecond)
    }
    false
}

@Test
class AuditRuntimeTest {
    @TestCase
    func runningTaskCooperatesWithCancellationAndEmitsOneTerminalEvent(): Unit {
        let runtime = AsyncRuntime()
        let ready = Semaphore(1)
        ready.acquire()
        let state = AuditRuntimeAsyncEvents()
        try {
            runtime.start("running", { =>
                ready.release()
                let deadline = MonoTime.now() + Duration.second * 2
                while (!Thread.currentThread.hasPendingCancellation && MonoTime.now() < deadline) {
                    sleep(Duration.millisecond)
                }
                Event.Message("finished")
            })
            let deadline = MonoTime.now() + Duration.second * 2
            var started = ready.tryAcquire()
            while (!started && MonoTime.now() < deadline) {
                sleep(Duration.millisecond)
                started = ready.tryAcquire()
            }
            @Assert(started)
            @Expect(runtime.cancel("running"))
            auditDrainAsync(runtime, state)
            @Expect(state.cancelled, 1)
            @Expect(state.completed, 0)
            @Expect(runtime.pendingCount(), 0)
        } finally { runtime.eventSource().close() }
    }

    @TestCase
    func cancelledTaskEmitsOneTerminalEvent(): Unit {
        let runtime = AsyncRuntime()
        let state = AuditRuntimeAsyncEvents()
        try {
            runtime.start("task", { => Event.Message("value") })
            let commands = ArrayList<Command>()
            commands.add(Command.CancelAsync("task"))
            commands.add(Command.CancelAsync("task"))
            App.processCommands({ event => state.observe(event) }, commands, asyncRuntime: runtime)
            auditDrainAsync(runtime, state)
            @Expect(runtime.pendingCount(), 0)
            @Expect(state.cancelled, 1)
            @Expect(state.completed, 0)
            @Expect(state.failed, 0)
            @Expect(runtime.drain().size, 0)
        } finally { runtime.eventSource().close() }
    }

    @TestCase
    func replacementCancellationTargetsLatestInstance(): Unit {
        let runtime = AsyncRuntime()
        let state = AuditRuntimeAsyncEvents()
        try {
            runtime.start("slot", { => Event.Message("old") })
            runtime.start("slot", { => Event.Message("new") })
            @Expect(runtime.cancel("slot"))
            @Expect(!runtime.cancel("slot"))
            auditDrainAsync(runtime, state)
            @Expect(runtime.pendingCount(), 0)
            @Expect(state.cancelled, 1)
            @Expect(state.completed, 0)
            @Expect(state.failed, 0)
        } finally { runtime.eventSource().close() }
    }

    @TestCase
    func replacedTasksStaySilentInEitherCompletionOrder(): Unit {
        for (newFinishesFirst in [false, true]) {
            let runtime = AsyncRuntime()
            let state = AuditRuntimeAsyncEvents()
            let oldReady = Semaphore(1)
            let newReady = Semaphore(1)
            let releaseOld = Semaphore(1)
            let releaseNew = Semaphore(1)
            oldReady.acquire()
            newReady.acquire()
            releaseOld.acquire()
            releaseNew.acquire()
            try {
                runtime.start("slot", { =>
                    oldReady.release()
                    releaseOld.acquire()
                    Event.Message("old")
                })
                @Assert(auditAcquireSignal(oldReady))
                runtime.start("slot", { =>
                    newReady.release()
                    releaseNew.acquire()
                    Event.Message("new")
                })
                @Assert(auditAcquireSignal(newReady))
                @Assert(runtime.pendingCount(), 2)
                if (newFinishesFirst) { releaseNew.release() } else { releaseOld.release() }
                auditDrainAsync(runtime, state, untilPending: 1)
                @Assert(runtime.pendingCount(), 1)
                @Expect(state.completed, if (newFinishesFirst) { 1 } else { 0 })
                @Expect(state.cancelled, 0)
                @Expect(state.failed, 0)
                if (newFinishesFirst) {
                    @Expect(!runtime.cancel("slot"))
                    releaseOld.release()
                } else {
                    releaseNew.release()
                }
                auditDrainAsync(runtime, state)
                @Expect(runtime.pendingCount(), 0)
                @Expect(state.completed, 1)
                @Expect(state.lastCompletedPayload, "new")
                @Expect(state.cancelled, 0)
                @Expect(state.failed, 0)
                @Expect(runtime.drain().size, 0)
            } finally {
                releaseOld.release()
                releaseNew.release()
                runtime.eventSource().close()
            }
        }
    }

    @TestCase
    func uncancelledTasksKeepSuccessAndFailureOutcomes(): Unit {
        let runtime = AsyncRuntime()
        let state = AuditRuntimeAsyncEvents()
        try {
            runtime.start("ok", { => Event.Message("value") })
            runtime.start("failure", { => throw Exception("expected failure") })
            auditDrainAsync(runtime, state)
            @Expect(runtime.pendingCount(), 0)
            @Expect(state.completed, 1)
            @Expect(state.failed, 1)
            @Expect(state.cancelled, 0)
        } finally { runtime.eventSource().close() }
    }

    @TestCase
    func startupFailureAndNormalExitCloseExternalPort(): Unit {
        for (failStart in [false, true]) {
            let port = ExternalPort<Event>(capacity: 1)
            let app = App(backend: TestBackend(area: Rect(0, 0, 8, 2)),
                inputSource: AuditRuntimeInput([]), terminalDriver: AuditRuntimeDriver(failStart),
                rawMode: true, alternateScreen: false, bracketedPaste: false, hideCursor: false)
            var caught = false
            try {
                app.runWithExternalPort(port, { _ => }, { _ => UpdateResult.exit() })
            } catch (error: Exception) { caught = error.message.contains("audit startup failure") }
            @Expect(caught, failStart)
            let closed = match (port.tryEnqueue(Event.Message("after-run"))) {
                case ExternalEnqueueResult.Closed => true
                case _ => false
            }
            @Expect(closed)
            port.close()
        }
    }

    @TestCase
    func headlessTimerPersistsUntilItsSyntheticDeadline(): Unit {
        let timers = AuditRuntimeCounter()
        let script = HeadlessScript().message("start").tick(count: 2)
        let result = AppTestRunner.run(script, { _ => }, { event =>
            match (event) {
                case Event.Message("start") => UpdateResult.withCommand(Command.StartTimer(
                    TimerSpec("once", Duration.millisecond * 20, mode: TimerMode.OneShot)))
                case Event.Timer(_) => timers.value++; UpdateResult.unchanged()
                case _ => UpdateResult.unchanged()
            }
        }, options: HeadlessRunOptions(area: Rect(0, 0, 1, 1), tickDeltaMillis: 10))
        @Expect(result.passed())
        @Expect(timers.value, 1)
    }

    @TestCase
    func headlessWaitAndTimerCancellationShareRuntime(): Unit {
        let timers = AuditRuntimeCounter()
        let script = HeadlessScript().message("start").message("cancel").waitMillis(10)
            .message("start").waitMillis(10)
        AppTestRunner.run(script, { _ => }, { event =>
            match (event) {
                case Event.Message("start") => UpdateResult.withCommand(Command.StartTimer(
                    TimerSpec("once", Duration.millisecond * 5, mode: TimerMode.OneShot)))
                case Event.Message("cancel") => UpdateResult.withCommand(Command.StopTimer("once"))
                case Event.Timer(_) => timers.value++; UpdateResult.unchanged()
                case _ => UpdateResult.unchanged()
            }
        }, options: HeadlessRunOptions(area: Rect(0, 0, 1, 1)))
        @Expect(timers.value, 1)
    }

    @TestCase
    func headlessElapsedTimeAdvancesOnlyWithTicksAndWaits(): Unit {
        let ticks = ArrayList<Int64>()
        let deltas = ArrayList<Int64>()
        let frames = ArrayList<Int64>()
        let timers = ArrayList<String>()
        let script = HeadlessScript().message("start").render().resize(Rect(0, 0, 2, 1)).tick()
            .message("later").render().waitMillis(7).tick()
        let result = AppTestRunner.run(script, { _ => }, { event =>
            match (event) {
                case Event.Message("start") => UpdateResult.withCommand(Command.StartTimer(
                    TimerSpec("first", Duration.millisecond * 10, mode: TimerMode.OneShot)))
                case Event.Message("later") => UpdateResult.withCommand(Command.StartTimer(
                    TimerSpec("later", Duration.millisecond * 17, mode: TimerMode.OneShot)))
                case Event.Tick(tick) =>
                    ticks.add(tick.elapsedMillis)
                    deltas.add(tick.deltaMillis)
                    frames.add(tick.frameIndex)
                    UpdateResult.unchanged()
                case Event.Timer(timer) =>
                    timers.add("${timer.id}:${timer.elapsedMillis}")
                    UpdateResult.unchanged()
                case _ => UpdateResult.unchanged()
            }
        }, options: HeadlessRunOptions(area: Rect(0, 0, 1, 1), tickDeltaMillis: 10, ticks: 1))
        @Expect(result.passed())
        @Expect(ticks.toArray(), [10, 17, 27, 37])
        @Expect(deltas.toArray(), [10, 7, 10, 10])
        @Expect(frames.toArray(), [4, 7, 8, 9])
        @Expect(timers.toArray(), ["first:10", "later:17"])
    }

    @TestCase
    func terminalProbeRetriesEmptyReadsWithinBudget(): Unit {
        let reply = unsafe { "\u{1B}[?1u".rawData() }
        for (delayed in [false, true]) {
            let input = AuditRuntimeInput(if (delayed) { [[], reply] } else { [reply] })
            let result = TerminalProbe.run(TestBackend(), input,
                base: TerminalCapabilities(keyUp: false), budgetMillis: 20)
            @Expect(result.capabilities.keyUp)
            @Expect(result.consumedBytes, reply)
            @Expect(input.reads >= 2)
        }
        let empty = AuditRuntimeInput([])
        let result = TerminalProbe.run(TestBackend(), empty,
            base: TerminalCapabilities(keyUp: false), budgetMillis: 0)
        @Expect(!result.capabilities.keyUp)
        @Expect(empty.reads, 1)
    }

    @TestCase
    func terminalClearResynchronizesCursorAfterSessionRestart(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 4, 1))
        let session = TerminalSession(backend, rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: true)
        let terminal = Terminal(backend)
        session.start()
        try {
            terminal.draw { frame => frame.setCursor(Position(1, 0)) }
            session.stop()
            session.start()
            backend.clearOutput()
            terminal.clear()
            terminal.draw { frame => frame.setCursor(Position(1, 0)) }
            @Expect(backend.output().contains("\u{1B}[?25h"))
            backend.clearOutput()
            terminal.draw { frame => frame.setCursor(Position(1, 0)) }
            @Expect(!backend.output().contains("\u{1B}[?25h"))
            terminal.clear()
            backend.clearOutput()
            terminal.draw { _ => }
            @Expect(backend.output().contains("\u{1B}[?25l"))
        } finally { session.stop() }
    }
}

@When[os == "Linux"]
class AuditRuntimeCountingSource <: EventSource {
    private let name: String
    private let inner: EventSource
    var callbacks: Int64 = 0
    init(name: String, inner: EventSource) { this.name = name; this.inner = inner }
    public func id(): String { name }
    public func fd(): ?Int32 { inner.fd() }
    public func interests(): EventSourceInterest { inner.interests() }
    public func onReady(readable: Bool, writable: Bool, error: Bool, hangup: Bool): Unit {
        if (readable || writable || error || hangup) { callbacks++ }
        inner.onReady(readable, writable, error, hangup)
    }
    public func drain(): Array<Event> { inner.drain() }
    public func close(): Unit { inner.close() }
}

@When[os == "Linux"]
class AuditRuntimePtyEvents {
    var output = ""
    var stderr = ""
    var exits: Int64 = 0
    var status: Int64 = -999
    var failures: Int64 = 0
    func observe(event: Event): Unit {
        match (event) {
            case Event.PtyOutput(_, stream, bytes) =>
                let chunk = unsafe { String.fromUtf8Unchecked(bytes) }
                match (stream) {
                    case PtyOutputStream.Stdout => output += chunk
                    case PtyOutputStream.Stderr => stderr += chunk
                }
            case Event.PtyExited(_, value) =>
                exits++
                status = match (value) {
                    case PtyExitStatus.Exited(code) => Int64(code)
                    case PtyExitStatus.Signaled(number) => -Int64(number)
                }
            case Event.PtyFailed(_, _) => failures++
            case _ => ()
        }
    }
}

@When[os == "Linux"]
func auditPtyStarted(event: Event): Bool {
    match (event) { case Event.PtyStarted(_) => true; case _ => false }
}

@When[os == "Linux"]
func auditPtyFailed(event: Event): Bool {
    match (event) { case Event.PtyFailed(_, _) => true; case _ => false }
}

@When[os == "Linux"]
func auditWaitPty(runtime: LinuxPtyRuntime, waiter: LinuxEpollEventWaiter,
    state: AuditRuntimePtyEvents, done: () -> Bool): Bool {
    let deadline = MonoTime.now() + Duration.second * 3
    while (!done() && MonoTime.now() < deadline) {
        waiter.wait(20, previousReadBytes: 0, sources: runtime.sources())
        for (event in runtime.drain()) { state.observe(event) }
        if (!done()) { sleep(Duration.millisecond) }
    }
    done()
}

@When[os == "Linux"]
func auditOpenFdCount(): Int64 {
    var count: Int64 = 0
    for (_ in Directory.readFrom("/proc/self/fd")) { count++ }
    count
}

@When[os == "Linux"]
@Test
class AuditRuntimeLinuxTest {
    @TestCase
    func helperFailuresReleaseTheirWakeDescriptors(): Unit {
        let before = auditOpenFdCount()
        var caught: Int64 = 0
        for (_ in 0..10) {
            let queue = ArrayList<Command>()
            queue.add(Command.Message("failure"))
            try { App.processCommands({ _ => throw Exception("expected") }, queue) }
            catch (_: Exception) { caught++ }
            try { EventScript().message("failure").runWithCommands({ _ => throw Exception("expected") }) }
            catch (_: Exception) { caught++ }
            try { EventScenario().run(TestBackend(), { _ => throw Exception("expected") }, { _ => UpdateResult.unchanged() }) }
            catch (_: Exception) { caught++ }
            try { AppTestRunner.run(HeadlessScript(), { _ => throw Exception("expected") }, { _ => UpdateResult.unchanged() }) }
            catch (_: Exception) { caught++ }
        }
        @Expect(caught, 40)
        @Expect(auditOpenFdCount() <= before + 2)
    }

    @TestCase
    func helperInvocationsReleaseTheirWakeDescriptors(): Unit {
        let before = auditOpenFdCount()
        for (_ in 0..100) {
            App.processCommands({ _ => UpdateResult.unchanged() }, ArrayList<Command>())
            App.processCommandsWithEvents({ _ => UpdateResult.unchanged() }, ArrayList<Command>())
            EventScript().runWithCommands({ _ => UpdateResult.unchanged() })
            EventScenario().run(TestBackend(), { _ => }, { _ => UpdateResult.unchanged() })
            AppTestRunner.run(HeadlessScript(), { _ => }, { _ => UpdateResult.unchanged() },
                options: HeadlessRunOptions(area: Rect(0, 0, 1, 1), captureBuffers: false, captureSnapshots: false))
        }
        @Expect(auditOpenFdCount() <= before + 2)
    }

    @TestCase
    func epollDispatchesEveryReadyEntryInOneBatch(): Unit {
        let first = AsyncRuntime()
        let second = AsyncRuntime()
        let one = AuditRuntimeCountingSource("one", first.eventSource())
        let two = AuditRuntimeCountingSource("two", second.eventSource())
        let waiter = LinuxEpollEventWaiter()
        try {
            first.start("first", { => Event.Message("first") })
            second.start("second", { => Event.Message("second") })
            // Observe readiness separately without draining either level signal.
            for (source in [one, two]) {
                let deadline = MonoTime.now() + Duration.second * 2
                while (source.callbacks == 0 && MonoTime.now() < deadline) {
                    waiter.wait(20, previousReadBytes: 0, sources: [source])
                }
                @Assert(source.callbacks > 0)
                source.callbacks = 0
            }
            waiter.wait(0, previousReadBytes: 0, sources: [one, two])
            @Expect(one.callbacks, 1)
            @Expect(two.callbacks, 1)
            @Expect(first.drain().size, 1)
            @Expect(second.drain().size, 1)
        } finally { waiter.close(); one.close(); two.close() }
    }

    @TestCase
    func epollReregistersAReusedDescriptor(): Unit {
        let waiter = LinuxEpollEventWaiter()
        let old = AsyncRuntime()
        let oldFd = old.eventSource().fd()
        waiter.wait(0, previousReadBytes: 0, sources: [old.eventSource()])
        old.eventSource().close()
        let replacement = AsyncRuntime()
        let source = AuditRuntimeCountingSource("replacement", replacement.eventSource())
        try {
            @Assert(source.fd(), oldFd)
            replacement.start("new", { => Event.Message("new") })
            let deadline = MonoTime.now() + Duration.second * 2
            while (source.callbacks == 0 && MonoTime.now() < deadline) {
                waiter.wait(20, previousReadBytes: 0, sources: [source])
            }
            @Expect(source.callbacks > 0)
            @Expect(replacement.drain().size, 1)
        } finally { waiter.close(); source.close() }
    }

    @TestCase
    func delayedEscWakesAnOtherwiseIdleApp(): Unit {
        for (delay in [Int64(0), Int64(25)]) {
            let input = AuditRuntimeInput([[27]])
            let port = ExternalPort<Event>(capacity: 1)
            let guard = spawn {
                sleep(Duration.millisecond * 250)
                port.tryEnqueue(Event.Message("guard"))
            }
            let escapes = AuditRuntimeCounter()
            App(backend: TestBackend(area: Rect(0, 0, 1, 1)), inputSource: input,
                rawMode: false, alternateScreen: false, bracketedPaste: false, hideCursor: false,
                resize: false, keyboard: KeyboardOptions(escDelayMillis: delay))
                .runWithExternalPort(port, { _ => }, { event =>
                    match (event) {
                        case Event.KeyDown(key) => match (key.code) {
                            case KeyCode.Esc => escapes.value++; UpdateResult.exit()
                            case _ => UpdateResult.unchanged()
                        }
                        case Event.Message("guard") => UpdateResult.exit()
                        case _ => UpdateResult.unchanged()
                    }
                })
            _ = guard.get()
            @Expect(escapes.value, 1)
        }
    }

    @TestCase
    func ptyReportsExecAndCwdFailuresWithoutStartingAProcess(): Unit {
        let runtime = LinuxPtyRuntime()
        let before = auditOpenFdCount()
        for (_ in 0..8) {
            @Expect(auditPtyFailed(runtime.start("missing-exec",
                PtySpec("/cjtui-definitely-missing-executable"))))
            @Expect(auditPtyFailed(runtime.start("missing-cwd",
                PtySpec("/bin/pwd", cwd: "/cjtui-definitely-missing-directory"))))
        }
        @Expect(runtime.activeCount(), 0)
        @Expect(runtime.sources().size, 0)
        @Expect(runtime.drain().size, 0)
        @Expect(auditOpenFdCount() <= before + 2)
    }

    @TestCase
    func ptyReadinessPreservesOutputExitStatusAndRemovesRecord(): Unit {
        let runtime = LinuxPtyRuntime()
        let waiter = LinuxEpollEventWaiter()
        let state = AuditRuntimePtyEvents()
        try {
            @Assert(auditPtyStarted(runtime.start("exit", PtySpec("/bin/sh",
                args: ["-c", "printf stdout-tail; printf stderr-tail >&2; exit 7"]))))
            @Expect(auditWaitPty(runtime, waiter, state, { => state.exits > 0 }))
            @Expect(state.output, "stdout-tail")
            @Expect(state.stderr, "stderr-tail")
            @Expect(state.exits, 1)
            @Expect(state.status, 7)
            @Expect(state.failures, 0)
            @Expect(runtime.activeCount(), 0)
            @Expect(runtime.sources().size, 0)
            @Expect(runtime.drain().size, 0)
        } finally { runtime.close("exit"); waiter.close() }
    }

    @TestCase
    func ptyPollExitAndReapShareActualStatus(): Unit {
        let runtime = LinuxPtyRuntime()
        try {
            @Assert(auditPtyStarted(runtime.start("exit", PtySpec("/bin/sh", args: ["-c", "exit 17"]))))
            let process = (runtime.process("exit").getOrThrow() as LinuxPtyProcess).getOrThrow()
            let deadline = MonoTime.now() + Duration.second * 2
            while (process.pollExit().isNone() && MonoTime.now() < deadline) { sleep(Duration.millisecond) }
            let actual = match (process.reap()) {
                case PtyExitStatus.Exited(code) => Int64(code)
                case _ => Int64(-1)
            }
            @Expect(actual, 17)
            let state = AuditRuntimePtyEvents()
            for (event in runtime.drain()) { state.observe(event) }
            @Expect(state.status, 17)
            @Expect(state.exits, 1)
            @Expect(runtime.activeCount(), 0)
        } finally { runtime.close("exit") }
    }

    @TestCase
    func ptyProcessGroupReceivesSignalsAndCloseWaitsForActualExit(): Unit {
        let runtime = LinuxPtyRuntime()
        let waiter = LinuxEpollEventWaiter()
        try {
            @Assert(auditPtyStarted(runtime.start("signal", PtySpec("/bin/sleep", args: ["10"]))))
            @Expect(!auditPtyFailed(runtime.signal("signal", PtySignal.Interrupt)))
            let interrupted = AuditRuntimePtyEvents()
            @Expect(auditWaitPty(runtime, waiter, interrupted, { => interrupted.exits > 0 }))
            @Expect(interrupted.status, -2)
            @Assert(auditPtyStarted(runtime.start("close", PtySpec("/bin/sh",
                args: ["-c", "trap 'exit 23' TERM; printf READY; while :; do sleep 1; done"]))))
            let closed = AuditRuntimePtyEvents()
            @Assert(auditWaitPty(runtime, waiter, closed, { => closed.output.contains("READY") }))
            closed.observe(runtime.close("close"))
            @Expect(closed.status, 23)
            @Expect(closed.exits, 1)
            @Expect(runtime.activeCount(), 0)
        } finally { runtime.close("signal"); runtime.close("close"); waiter.close() }
    }

    @TestCase
    func ptyCloseEscalatesAfterIgnoredTerminateAndRejectsFurtherWrites(): Unit {
        let runtime = LinuxPtyRuntime()
        let waiter = LinuxEpollEventWaiter()
        let state = AuditRuntimePtyEvents()
        let program = "import signal,time,tty\ntty.setraw(0)\nsignal.signal(signal.SIGTERM,signal.SIG_IGN)\nprint('READY',flush=True)\ntime.sleep(10)\n"
        try {
            @Assert(auditPtyStarted(runtime.start("close", PtySpec("/usr/bin/python3", args: ["-c", program]))))
            @Assert(auditWaitPty(runtime, waiter, state, { => state.output.contains("READY") }))
            let process = runtime.process("close").getOrThrow()
            @Expect(process.write(Array<Byte>(1048576, repeat: b'x')))
            state.observe(runtime.close("close"))
            @Expect(state.status, -9)
            @Expect(state.exits, 1)
            @Expect(runtime.activeCount(), 0)
            @Expect(!process.write([b'x']))
            process.close()
        } finally { runtime.close("close"); waiter.close() }
    }

    @TestCase
    func ptyOwnsControllingTerminalAndAppliesResize(): Unit {
        let runtime = LinuxPtyRuntime()
        let waiter = LinuxEpollEventWaiter()
        let state = AuditRuntimePtyEvents()
        let program = "import os,tty\ntty.setraw(0)\nprint('READY GROUP='+str(os.tcgetpgrp(0)==os.getpgrp()),flush=True)\nos.read(0,1)\ns=os.get_terminal_size(0)\nprint('SIZE='+str(s.columns)+'x'+str(s.lines),flush=True)\n"
        try {
            @Assert(auditPtyStarted(runtime.start("resize", PtySpec("/usr/bin/python3", args: ["-c", program]))))
            @Assert(auditWaitPty(runtime, waiter, state, { => state.output.contains("READY") }))
            @Expect(!auditPtyFailed(runtime.resize("resize", PtySize(cols: 103, rows: 41))))
            @Expect(!auditPtyFailed(runtime.write("resize", [b'x'])))
            @Expect(auditWaitPty(runtime, waiter, state, { => state.exits > 0 }))
            @Expect(state.output.contains("GROUP=True"))
            @Expect(state.output.contains("SIZE=103x41"))
            @Expect(state.status, 0)
        } finally { runtime.close("resize"); waiter.close() }
    }

    @TestCase
    func ptyAppliesCwdAndDoesNotInheritRuntimeWakeDescriptors(): Unit {
        let wake = AsyncRuntime()
        let wakeFd = wake.eventSource().fd().getOrThrow()
        let runtime = LinuxPtyRuntime()
        let waiter = LinuxEpollEventWaiter()
        let state = AuditRuntimePtyEvents()
        let program = "import os\nprint('CWD='+os.getcwd(),flush=True)\ntry:\n os.fstat(${wakeFd})\n print('INHERITED',flush=True)\nexcept OSError:\n print('CLOSED',flush=True)\n"
        try {
            @Assert(auditPtyStarted(runtime.start("cwd", PtySpec("/usr/bin/python3", args: ["-c", program], cwd: "/tmp"))))
            @Expect(auditWaitPty(runtime, waiter, state, { => state.exits > 0 }))
            @Expect(state.output.contains("CWD=/tmp"))
            @Expect(state.output.contains("CLOSED"))
            @Expect(!state.output.contains("INHERITED"))
            @Expect(state.status, 0)
        } finally { runtime.close("cwd"); waiter.close(); wake.eventSource().close() }
    }

    @TestCase
    func ptyLargeWriteRetainsAllAcceptedBytes(): Unit {
        for (size in [Int64(8), Int64(1048576)]) {
            let runtime = LinuxPtyRuntime()
            let waiter = LinuxEpollEventWaiter()
            let state = AuditRuntimePtyEvents()
            let program = "import os,tty\ntty.setraw(0)\nprint('READY',flush=True)\ndata=b''\nwhile len(data)<${size}:\n data+=os.read(0,65536)\nprint('RECEIVED='+str(len(data))+' X='+str(data.count(b'x')),flush=True)\n"
            try {
                @Assert(auditPtyStarted(runtime.start("write", PtySpec("/usr/bin/python3", args: ["-c", program]))))
                @Assert(auditWaitPty(runtime, waiter, state, { => state.output.contains("READY") }))
                if (size == 8) {
                    @Expect(auditPtyFailed(runtime.write("write", Array<Byte>(4 * 1024 * 1024 + 1, repeat: b'y'))))
                }
                let bytes = Array<Byte>(size, repeat: b'x')
                @Expect(!auditPtyFailed(runtime.write("write", bytes)))
                bytes[bytes.size - 1] = b'y'
                @Expect(auditWaitPty(runtime, waiter, state, { => state.exits > 0 }))
                @Expect(state.output.contains("RECEIVED=${size} X=${size}"))
                @Expect(state.status, 0)
                @Expect(state.failures, 0)
                @Expect(runtime.activeCount(), 0)
            } finally { runtime.close("write"); waiter.close() }
        }
    }
}
