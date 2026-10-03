package core

import std.collection.*
import std.convert.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@FastNative
@When[os == "Linux"]
foreign func poll(fds: CPointer<Unit>, nfds: UIntNative, timeout: Int32): Int32

class ProcessObservation {
    var stdoutBytes: Int64 = 0
    var stderrBytes: Int64 = 0
    var finishes: Int64 = 0
    var result: ?ProcessResult = None
    var failure: String = ""
    var afterFinish: Bool = false
    func record(event: Event): Unit {
        match (event) {
            case Event.ProcessOutput(_, stream, bytes) =>
                if (finishes > 0) { afterFinish = true }
                match (stream) {
                    case ProcessOutputStream.Stdout => stdoutBytes += bytes.size
                    case ProcessOutputStream.Stderr => stderrBytes += bytes.size
                }
            case Event.ProcessFinished(_, value) => finishes++; result = Some(value)
            case Event.ProcessFailed(_, message) => failure = message
            case _ => ()
        }
    }
}

@When[os != "Windows"]
func collectProcess(runtime: ProcessRuntime): ProcessObservation {
    let observed = ProcessObservation()
    let deadline = MonoTime.now() + Duration.second * 5
    while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
        for (event in runtime.drain()) { observed.record(event) }
        if (runtime.activeCount() > 0) { sleep(Duration.millisecond) }
    }
    observed
}

@When[os != "Windows"]
@Test
class ProcessRuntimeTest {
    @TestCase
    func readyStreamsShareEvenASingleByteQueue(): Unit {
        let runtime = PosixProcessRuntime(maxQueuedBytes: 1)
        try {
            _ = runtime.start("tiny", ProcessSpec("/bin/sh", args: ["-c", "printf 1234567890; printf x >&2"]))
            let sources = runtime.sources()
            let pollBytes = Array<Byte>(16, repeat: 0)
            writeUInt32LE(pollBytes, 0, UInt32(sources[0].fd().getOrThrow()))
            writeUInt32LE(pollBytes, 8, UInt32(sources[1].fd().getOrThrow()))
            writeUInt16LE(pollBytes, 4, 1)
            writeUInt16LE(pollBytes, 12, 1)
            // Observe readiness without consuming either stream. Both writes
            // must be available before asserting scheduling fairness.
            var ready: Int32 = 0
            let deadline = MonoTime.now() + Duration.second * 2
            while (ready < 2 && MonoTime.now() < deadline) {
                ready = unsafe {
                    let handle = acquireArrayRawData(pollBytes)
                    let count = poll(CPointer<Unit>(handle.pointer), 2, 0)
                    releaseArrayRawData(handle)
                    count
                }
                sleep(Duration.millisecond)
            }
            @Assert(ready, 2)
            let seen = ProcessObservation()
            for (_ in 0..4) {
                for (source in runtime.sources()) { source.onReady(true, false, false, false) }
                for (event in runtime.drain()) { seen.record(event) }
            }
            @Expect(seen.stderrBytes, 1)
            @Expect(seen.stdoutBytes <= 3)
        } finally { runtime.closeAll() }
    }

    @TestCase
    func nativeLaunchPreservesArgumentsEnvironmentPathAndWorkingDirectory(): Unit {
        let runtime = PosixProcessRuntime()
        let text = StringBuilder()
        let literal = "a b;$(printf injected)\"'中"
        let seen = ProcessObservation()
        try {
            let script = "printf '%s|%s|' \"$1\" \"$TERMCANVAS_SPAWN_TEST\"; pwd"
            match (runtime.start("native", ProcessSpec("sh", args: ["-c", script, "sh", literal],
                cwd: "/", env: ["PATH=/bin:/usr/bin", "TERMCANVAS_SPAWN_TEST=old", "TERMCANVAS_SPAWN_TEST=exact"]))) {
                case Event.ProcessStarted(_) => (); case _ => @Expect(false)
            }
            let deadline = MonoTime.now() + Duration.second * 5
            while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
                for (event in runtime.drain()) {
                    seen.record(event)
                    match (event) {
                        case Event.ProcessOutput(_, ProcessOutputStream.Stdout, bytes) => text.append(String.fromUtf8(bytes))
                        case _ => ()
                    }
                }
                sleep(Duration.millisecond)
            }
            @Expect(text.toString(), literal + "|exact|/\n")
            @Expect(seen.finishes, 1)
            match (runtime.start("bad-cwd", ProcessSpec("/bin/sh", cwd: "/termcanvas-does-not-exist"))) {
                case Event.ProcessFailed(_, _) => (); case _ => @Expect(false)
            }
            @Expect(runtime.activeCount(), 0)
        } finally { runtime.closeAll() }
    }

    @TestCase
    func repeatedNativeStartsDoNotReturnThroughManagedChildCode(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            for (i in 0..20) {
                match (runtime.start("repeat", ProcessSpec("/bin/sh", args: ["-c", "printf ok"], timeoutMillis: 1000))) {
                    case Event.ProcessStarted(_) => (); case _ => @Expect(false)
                }
                let seen = collectProcess(runtime)
                @Expect(seen.stdoutBytes, 2)
                @Expect(seen.finishes, 1)
                @Expect(runtime.activeCount(), 0)
            }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func aggregateReadTurnIsBoundedAndRotatesAcrossProcesses(): Unit {
        let runtime = PosixProcessRuntime()
        let delivered = HashSet<String>()
        var finishes: Int64 = 0
        try {
            for (i in 0..8) {
                _ = runtime.start("fair-${i}", ProcessSpec("/bin/sh", args: ["-c", "head -c 131072 /dev/zero"], timeoutMillis: 4000))
            }
            let deadline = MonoTime.now() + Duration.second * 5
            while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
                var bytes: Int64 = 0
                for (event in runtime.drain()) {
                    match (event) {
                        case Event.ProcessOutput(id, _, chunk) => delivered.add(id); bytes += chunk.size
                        case Event.ProcessFinished(_, result) =>
                            finishes++
                            @Expect(result.outputBytes, 131072)
                            @Expect(result.outputComplete)
                        case _ => ()
                    }
                }
                @Expect(bytes <= 64 * 1024)
                sleep(Duration.millisecond)
            }
            @Expect(delivered.size, 8)
            @Expect(finishes, 8)
        } finally { runtime.closeAll() }
    }

    @TestCase
    func dualStreamsLargerThanPipeCapacityAreDeliveredBeforeExit(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            let started = runtime.start("dual", ProcessSpec("/bin/sh", args: ["-c", "head -c 196608 /dev/zero & head -c 196608 /dev/zero >&2 & wait"], timeoutMillis: 4000))
            match (started) { case Event.ProcessStarted("dual") => (); case _ => @Expect(false) }
            let seen = collectProcess(runtime)
            @Expect(runtime.activeCount(), 0)
            @Expect(seen.stdoutBytes, 196608)
            @Expect(seen.stderrBytes, 196608)
            @Expect(seen.finishes, 1)
            @Expect(!seen.afterFinish)
            @Expect(seen.failure, "")
            match (seen.result.getOrThrow().reason) { case ProcessEndReason.Exited => (); case _ => @Expect(false) }
            match (seen.result.getOrThrow().status) { case PtyExitStatus.Exited(0) => (); case _ => @Expect(false) }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func outputLimitPreservesExactPrefixAndReportsExplicitTermination(): Unit {
        let runtime = PosixProcessRuntime(readBudgetBytes: 1024)
        try {
            _ = runtime.start("limit", ProcessSpec("/bin/sh", args: ["-c", "head -c 32768 /dev/zero"], maxOutputBytes: 1000))
            let seen = collectProcess(runtime)
            @Expect(seen.stdoutBytes + seen.stderrBytes, 1000)
            @Expect(seen.finishes, 1)
            @Expect(seen.result.getOrThrow().outputBytes, 1000)
            match (seen.result.getOrThrow().reason) { case ProcessEndReason.OutputLimit => (); case _ => @Expect(false) }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func deadlineEscalatesTermIgnoringChildAndReaps(): Unit {
        let runtime = PosixProcessRuntime()
        let started = MonoTime.now()
        try {
            // Give the interpreter time to install the handler under loaded
            // CI. A 20 ms deadline could kill it before this tested state.
            _ = runtime.start("deadline", ProcessSpec("/bin/sh", args: ["-c", "trap '' TERM; while :; do :; done"], timeoutMillis: 250))
            let seen = collectProcess(runtime)
            @Expect(runtime.activeCount(), 0)
            @Expect(seen.finishes, 1)
            @Expect((MonoTime.now() - started).toMilliseconds() < 2000)
            match (seen.result.getOrThrow().reason) { case ProcessEndReason.TimedOut => (); case _ => @Expect(false) }
            match (seen.result.getOrThrow().status) { case PtyExitStatus.Signaled(9) => (); case _ => @Expect(false) }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func cancellationAndCapacityAreExplicitAndShutdownIsIdempotent(): Unit {
        let runtime = PosixProcessRuntime(maxProcesses: 1)
        try {
            _ = runtime.start("cancel", ProcessSpec("/bin/sh", args: ["-c", "sleep 30 & wait"]))
            match (runtime.start("extra", ProcessSpec("/bin/sh"))) { case Event.ProcessFailed(_, _) => (); case _ => @Expect(false) }
            match (runtime.cancel("cancel")) { case Event.ProcessCancelRequested("cancel") => (); case _ => @Expect(false) }
            let seen = collectProcess(runtime)
            @Expect(runtime.activeCount(), 0)
            @Expect(seen.finishes, 1)
            match (seen.result.getOrThrow().reason) { case ProcessEndReason.Cancelled => (); case _ => @Expect(false) }
        } finally { runtime.closeAll(); runtime.closeAll() }
    }

    @TestCase
    func sourceBackpressureBoundsMemoryWithoutTruncatingBytes(): Unit {
        let runtime = PosixProcessRuntime(readBudgetBytes: 1024, maxQueuedBytes: 4096)
        try {
            _ = runtime.start("bounded", ProcessSpec("/bin/sh", args: ["-c", "head -c 65536 /dev/zero"], timeoutMillis: 4000))
            let until = MonoTime.now() + Duration.second * 2
            while (MonoTime.now() < until && runtime.metrics().backpressureCount == 0) {
                for (source in runtime.sources()) { source.onReady(true, false, false, false) }
                sleep(Duration.millisecond)
            }
            @Expect(runtime.metrics().queuedBytes <= 4096)
            @Expect(runtime.metrics().backpressureCount > 0)
            let seen = collectProcess(runtime)
            @Expect(seen.stdoutBytes, 65536)
            @Expect(seen.finishes, 1)
            @Expect(runtime.metrics().peakQueuedBytes <= 4096)
        } finally { runtime.closeAll() }
    }

    @TestCase
    func duplicateIdLeavesOriginalRunningAndCloseAllReapsIt(): Unit {
        let runtime = PosixProcessRuntime()
        _ = runtime.start("same", ProcessSpec("/bin/sh", args: ["-c", "sleep 30 & wait"]))
        try {
            match (runtime.start("same", ProcessSpec("/bin/sh"))) { case Event.ProcessFailed(_, _) => (); case _ => @Expect(false) }
            @Expect(runtime.activeCount(), 1)
            _ = runtime.cancel("same")
            _ = runtime.cancel("same")
            let seen = collectProcess(runtime)
            @Expect(seen.finishes, 1)
            match (runtime.cancel("same")) { case Event.ProcessFailed(_, _) => (); case _ => @Expect(false) }
            _ = runtime.start("owned", ProcessSpec("/bin/sh", args: ["-c", "sleep 30 & wait"]))
        } finally { runtime.closeAll() }
        @Expect(runtime.activeCount(), 0)
        @Expect(runtime.nextTimeoutMillis().isNone())
    }

    @TestCase
    func invalidExecutableFailsStartupAndDoesNotRetainProcess(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            match (runtime.start("missing", ProcessSpec("/termcanvas-does-not-exist"))) {
                case Event.ProcessFailed(_, _) => (); case _ => @Expect(false)
            }
            @Expect(runtime.activeCount(), 0)
            _ = runtime.start("eof", ProcessSpec("/bin/sh", args: ["-c", "read value || printf eof"]))
            let seen = collectProcess(runtime)
            @Expect(seen.stdoutBytes, 3)
            @Expect(seen.finishes, 1)
        } finally { runtime.closeAll() }
    }

    @TestCase
    func appCommandsStreamOutputAndOwnProcessShutdown(): Unit {
        let runtime = PosixProcessRuntime()
        let seen = ProcessObservation()
        let app = App(backend: TestBackend(area: Rect(0, 0, 4, 1)), inputSource: RecordingInputSource(),
            probeInputSource: RecordingInputSource(), rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false)
        app.attachProcessRuntime(runtime)
        app.runWithCommands({_ =>}, {event =>
            seen.record(event)
            match (event) {
                case Event.Capabilities(_) => UpdateResult.withCommand(Command.ProcessStart("app", ProcessSpec("/bin/sh", args: ["-c", "printf hello; printf error >&2"], timeoutMillis: 1000)))
                case Event.ProcessFinished(_, _) | Event.ProcessFailed(_, _) => UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
        })
        @Expect(seen.stdoutBytes, 5)
        @Expect(seen.stderrBytes, 5)
        @Expect(seen.finishes, 1)
        @Expect(runtime.activeCount(), 0)
    }

    @TestCase
    func appRetainsPtyOwnershipAfterRejectedWrite(): Unit {
        let runtime = LinuxPtyRuntime()
        let app = App(backend: TestBackend(area: Rect(0, 0, 4, 1)), inputSource: RecordingInputSource(),
            probeInputSource: RecordingInputSource(), rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false)
        app.attachPtyRuntime(runtime)
        try {
            app.runWithCommands({_ =>}, {event => match (event) {
                case Event.Capabilities(_) => UpdateResult.withCommand(Command.PtyStart("owned", PtySpec("/bin/sh", args: ["-c", "sleep 30 & wait"])))
                case Event.PtyStarted(_) => UpdateResult.withCommand(Command.PtyWrite("owned", Array<Byte>(4 * 1024 * 1024 + 1, repeat: 0)))
                case Event.PtyFailed(_, _) => UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }})
            @Expect(runtime.activeCount(), 0)
        } finally { if (runtime.activeCount() > 0) { _ = runtime.close("owned") } }
    }

    @TestCase
    func ptyReadBudgetPreservesTrailingOutputAcrossExit(): Unit {
        let runtime = LinuxPtyRuntime(readBudgetBytes: 1024, maxQueuedBytes: 4096)
        var output: Int64 = 0
        var exits: Int64 = 0
        try {
            _ = runtime.start("pty-budget", PtySpec("/bin/sh", args: ["-c", "head -c 32768 /dev/zero; head -c 32768 /dev/zero >&2"]))
            let deadline = MonoTime.now() + Duration.second * 4
            while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
                for (source in runtime.sources()) { source.onReady(true, false, true, true) }
                for (event in runtime.drain()) {
                    match (event) { case Event.PtyOutput(_, _, bytes) => output += bytes.size; case Event.PtyExited(_, _) => exits++; case _ => () }
                }
                sleep(Duration.millisecond)
            }
            @Expect(output, 65536)
            @Expect(exits, 1)
            @Expect(runtime.flowMetrics().peakQueuedBytes <= 4096)
        } finally { if (runtime.activeCount() > 0) { _ = runtime.close("pty-budget") } }
    }

    @TestCase
    func aggregatePtyReadTurnRotatesWithoutLosingTailBytes(): Unit {
        let runtime = LinuxPtyRuntime()
        let totals = HashMap<String, Int64>()
        var exits: Int64 = 0
        try {
            for (i in 0..8) {
                _ = runtime.start("pty-fair-${i}", PtySpec("/bin/sh", args: ["-c", "head -c 131072 /dev/zero"]))
            }
            let deadline = MonoTime.now() + Duration.second * 5
            while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
                var bytes: Int64 = 0
                for (event in runtime.drain()) {
                    match (event) {
                        case Event.PtyOutput(id, _, chunk) =>
                            totals[id] = (totals.get(id) ?? 0) + chunk.size
                            bytes += chunk.size
                        case Event.PtyExited(_, status) =>
                            exits++
                            match (status) { case PtyExitStatus.Exited(0) => (); case _ => @Expect(false) }
                        case _ => ()
                    }
                }
                @Expect(bytes <= 64 * 1024)
                sleep(Duration.millisecond)
            }
            @Expect(totals.size, 8)
            for ((_, bytes) in totals) { @Expect(bytes, 131072) }
            @Expect(exits, 8)
        } finally {
            for (i in 0..8) { _ = runtime.close("pty-fair-${i}") }
        }
    }
}

class FairLoopState {
    var messages: Int64 = 0
    var frames: Int64 = 0
    var keySeen: Bool = false
}

@Test
class RuntimeBudgetTest {
    @TestCase
    func commandFeedbackYieldsToPresentationAndKeyboard(): Unit {
        let state = FairLoopState()
        let app = App(backend: TestBackend(area: Rect(0, 0, 4, 1)),
            inputSource: ChunkedInputSource([unsafe { "q".rawData() }]), probeInputSource: RecordingInputSource(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false,
            eventWaiter: CountingEventWaiter())
        app.runWithCommands({_ => state.frames++}, {event => match (event) {
            case Event.Capabilities(_) => UpdateResult.withCommand(Command.Message("again"))
            case Event.Message("again") =>
                state.messages++
                if (state.messages > 4096) { throw Exception("feedback starved input") }
                UpdateResult.withCommand(Command.Message("again"))
            case Event.KeyDown(_) => state.keySeen = true; UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(state.keySeen)
        @Expect(state.messages <= 1024)
        @Expect(state.frames > 0)
    }

    @TestCase
    func commandFeedbackYieldsToTimers(): Unit {
        let state = FairLoopState()
        let metrics = AppMetrics()
        let app = App(backend: TestBackend(area: Rect(0, 0, 4, 1)),
            inputSource: RecordingInputSource(), probeInputSource: RecordingInputSource(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false,
            metrics: Some(metrics), eventWaiter: CountingEventWaiter())
        app.runWithCommands({_ => state.frames++}, {event => match (event) {
            case Event.Capabilities(_) => UpdateResult.withCommand(Command.Batch([
                Command.StartTimer(TimerSpec("fair", Duration.millisecond, mode: TimerMode.OneShot)),
                Command.Message("again")]))
            case Event.Message("again") =>
                state.messages++
                if (state.messages % 256 == 0) { sleep(Duration.millisecond) }
                if (state.messages > 4096) { throw Exception("feedback starved timer") }
                UpdateResult.withCommand(Command.Message("again"))
            case Event.Timer(_) => state.keySeen = true; UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }})
        @Expect(state.keySeen)
        @Expect(state.frames > 0)
        @Expect(metrics.runtime().yieldedTurns > 0)
    }

    @TestCase
    func eventCapacityFailsExplicitlyAndRetainsAcceptedOrder(): Unit {
        let queue = RuntimeQueue<Unit>(capacity: 2)
        _ = queue.enqueueEvent(Event.Message("first"))
        _ = queue.enqueueEvent(Event.Message("second"))
        var rejected = false
        try { _ = queue.enqueueEvent(Event.Message("third")) } catch (_: IllegalStateException) { rejected = true }
        @Expect(rejected)
        @Expect(queue.overflowCount(), 1)
        @Expect(queue.size(), 2)
        match (queue.dequeue().getOrThrow().envelope) { case RuntimeEnvelope<Unit>.EventItem(Event.Message("first")) => (); case _ => @Expect(false) }
        match (queue.dequeue().getOrThrow().envelope) { case RuntimeEnvelope<Unit>.EventItem(Event.Message("second")) => (); case _ => @Expect(false) }
    }

    @TestCase
    func partialExternalImportRetainsPendingWakeAndOrder(): Unit {
        let port = ExternalPort<Int64>(capacity: 4)
        try {
            for (i in 0..4) { _ = port.tryEnqueue(i) }
            let first = port.drainEntries(maxEntries: 2)
            @Expect(first.size, 2)
            @Expect(first[0].action, 0)
            @Expect(first[1].action, 1)
            @Expect(port.size(), 2)
            let rest = port.drainEntries()
            @Expect(rest[0].action, 2)
            @Expect(rest[1].action, 3)
        } finally { port.close() }
    }
}

@Test
class Utf8StreamDecoderTest {
    @TestCase
    func decodesEverySplitOfValidUtf8AndFlushesIncompleteTail(): Unit {
        let text = "A中🙂Z"
        let bytes = unsafe { text.rawData() }
        for (split in 0..bytes.size + 1) {
            let decoder = Utf8StreamDecoder()
            @Expect(decoder.feed(bytes[..split]) + decoder.feed(bytes[split..]) + decoder.finish(), text)
        }
        let decoder = Utf8StreamDecoder()
        @Expect(decoder.feed([0xE4u8, 0xB8u8]), "")
        @Expect(decoder.finish(), "\u{FFFD}")
        @Expect(decoder.finish(), "")
    }
    @TestCase
    func invalidBytesAreDeterministicAcrossChunkBoundaries(): Unit {
        let bytes: Array<Byte> = [0xED, 0xA0, 0x80, 0xFF, 0x61]
        let whole = Utf8StreamDecoder().feed(bytes)
        for (split in 0..bytes.size + 1) {
            let decoder = Utf8StreamDecoder()
            @Expect(decoder.feed(bytes[..split]) + decoder.feed(bytes[split..]) + decoder.finish(), whole)
        }
    }
}


@When[os == "Linux"]
@Test
class ProcessDrainTest {
    @TestCase
    func escapedContinuousWriterHasFiniteExplicitIncompleteDrain(): Unit {
        let runtime = PosixProcessRuntime()
        let observed = ProcessObservation()
        let text = StringBuilder()
        var escapedPid: Int32 = 0
        // A pipe handshake makes the leader exit only after the descendant
        // has entered another session and published its PID for test cleanup.
        let script = "import os,time\nr,w=os.pipe()\npid=os.fork()\nif pid==0:\n os.close(r)\n os.setsid()\n os.write(1,(str(os.getpid())+'\\n').encode())\n os.write(w,b'x')\n os.close(w)\n while True:\n  os.write(1,b'x')\n  time.sleep(.005)\nelse:\n os.close(w)\n os.read(r,1)\n os.close(r)\n"
        try {
            match (runtime.start("escaped", ProcessSpec("/usr/bin/python3", args: ["-c", script], drainTimeoutMillis: 100))) {
                case Event.ProcessStarted(_) => (); case _ => @Expect(false)
            }
            let deadline = MonoTime.now() + Duration.second * 3
            while (runtime.activeCount() > 0 && MonoTime.now() < deadline) {
                for (event in runtime.drain()) {
                    observed.record(event)
                    match (event) {
                        case Event.ProcessOutput(_, ProcessOutputStream.Stdout, bytes) =>
                            text.append(unsafe { String.fromUtf8Unchecked(bytes) })
                            let value = text.toString()
                            if (escapedPid == 0 && value.contains("\n")) { escapedPid = Int32(Int64.parse(value.split("\n")[0])) }
                        case _ => ()
                    }
                }
                sleep(Duration.millisecond)
            }
            @Expect(escapedPid > 0)
            @Expect(observed.stdoutBytes > 0)
            @Expect(observed.finishes, 1)
            @Expect(runtime.activeCount(), 0)
            let result = observed.result.getOrThrow()
            match (result.reason) { case ProcessEndReason.DrainTimeout => (); case _ => @Expect(false) }
            match (result.status) { case PtyExitStatus.Exited(0) => (); case _ => @Expect(false) }
            @Expect(!result.outputComplete)
        } finally {
            // Escaped sessions are outside runtime process-group ownership.
            // This fixture explicitly owns and cleans its escaped descendant.
            if (escapedPid > 0) { unsafe { _ = kill(-escapedPid, SIGKILL) } }
            runtime.closeAll()
        }
    }
}
