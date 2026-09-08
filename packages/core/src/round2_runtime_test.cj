package core

import std.collection.ArrayList
import std.io.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

class Round2RuntimeInput <: InputSource {
    private let probes: Array<Array<Array<Byte>>>
    private let normal: Array<Array<Byte>>
    private var probing = false
    private var index: Int64 = 0
    private var offset: Int64 = 0
    private var finished = false
    var cycles: Int64 = 0

    init(probes: Array<Array<Array<Byte>>>, normal!: Array<Array<Byte>> = []) {
        this.probes = probes
        this.normal = normal
    }

    func beginProbe(): Unit { probing = true; index = 0; offset = 0; cycles++ }
    func endProbe(): Unit { probing = false; index = 0; offset = 0; finished = false }

    public func readAvailable(maxBytes: Int64): Array<Byte> {
        let chunks = if (probing && cycles <= probes.size) { probes[cycles - 1] }
            else if (probing) { Array<Array<Byte>>() } else { normal }
        if (maxBytes <= 0) { return [] }
        if (index >= chunks.size) {
            // A final key in the same stream ends the fixture only after all
            // earlier input, without depending on rendering speed or ticks.
            if (!probing && !finished) { finished = true; return [b'!'] }
            return []
        }
        let chunk = chunks[index]
        let count = min(maxBytes, chunk.size - offset)
        let bytes = Array<Byte>(count, { position => chunk[offset + position] })
        offset += count
        if (offset >= chunk.size) { index++; offset = 0 }
        bytes
    }
}

class Round2RuntimeOutput <: OutputStream {
    private let input: Round2RuntimeInput
    init(input: Round2RuntimeInput) { this.input = input }
    public func write(bytes: Array<Byte>): Unit {
        let text = unsafe { String.fromUtf8Unchecked(bytes) }
        if (text.contains("\u{1B}[?u")) { input.beginProbe() }
        if (text.contains("\u{1B}[>1u")) { input.endProbe() }
    }
    public func flush(): Unit {}
}

class Round2RuntimeDriver <: TerminalDriver {
    private let keyUp: Bool
    init(keyUp!: Bool = false) { this.keyUp = keyUp }
    public func name(): String { "round2-driver" }
    public func enterRawMode(): Bool { true }
    public func restore(): Unit {}
    public func size(): ?Rect { Some(Rect(0, 0, 1, 1)) }
    public func capabilities(backend: Backend): TerminalCapabilities {
        TerminalCapabilities(size: backend.size(), trueColor: false, osc8: false,
            keyUp: keyUp, driverName: name())
    }
}

class Round2RuntimeInputEvents {
    let keys = ArrayList<String>()
    let pastes = ArrayList<String>()
    var capabilities: ?TerminalCapabilities = None
    var stoppedOnEndKey = false
    private var ticks: Int64 = 0

    func observe(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Char(r'!') => stoppedOnEndKey = true; return UpdateResult.exit()
                case KeyCode.Char(value) => keys.add(value.toString())
                case KeyCode.Up => keys.add("up")
                case KeyCode.Esc => keys.add("esc")
                case _ => keys.add("other")
            }
            case Event.Paste(value) => pastes.add(value)
            case Event.Capabilities(value) => capabilities = Some(value)
            case Event.Tick(_) =>
                ticks++
                if (ticks >= 100) { return UpdateResult.exit() }
            case _ => ()
        }
        UpdateResult.unchanged()
    }
}

func round2RunInput(input: Round2RuntimeInput, mode!: TerminalProbeMode = TerminalProbeMode.Active,
    keyUp!: Bool = false): Round2RuntimeInputEvents {
    let events = Round2RuntimeInputEvents()
    let backend = AnsiBackend(output: Round2RuntimeOutput(input), fallbackArea: Rect(0, 0, 1, 1))
    App(backend: backend, inputSource: input, probeInputSource: input,
        terminalDriver: Round2RuntimeDriver(keyUp: keyUp), rawMode: false,
        alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false,
        tickEvery: Some(Duration.millisecond * 10),
        keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: mode, probeBudgetMillis: 20))
        .runWithCommands({ _ => }, { event => events.observe(event) })
    if (!events.stoppedOnEndKey) { throw Exception("input fixture reached tick limit before final key") }
    events
}

class Round2RuntimePtyEvents {
    let order = ArrayList<String>()
    var ready = false
    func observe(event: Event, stopOnExit!: Bool = false): UpdateResult {
        match (event) {
            case Event.PtyStarted(_) => order.add("started")
            case Event.PtyOutput(_, stream, bytes) =>
                let text = unsafe { String.fromUtf8Unchecked(bytes) }
                if (text.contains("READY")) { ready = true }
                let prefix = match (stream) { case PtyOutputStream.Stdout => "out:"; case PtyOutputStream.Stderr => "err:" }
                order.add(prefix + text)
            case Event.PtyExited(_, status) =>
                let code = match (status) { case PtyExitStatus.Exited(value) => Int64(value); case _ => Int64(-1) }
                order.add("exited:${code}")
                if (stopOnExit) { return UpdateResult.exit() }
            case Event.PtyFailed(_, _) => order.add("failed")
            case _ => ()
        }
        UpdateResult.unchanged()
    }
}

@Test
class Round2RuntimeTest {
    @TestCase
    func waitMetricsUseTheDispatchedTickDelta(): Unit {
        let ticks = ArrayList<Int64>()
        let elapsed = ArrayList<Int64>()
        let result = AppTestRunner.run(HeadlessScript().waitMillis(7).tick().waitMillis(3).waitMillis(0),
            { _ => }, { event =>
                match (event) {
                    case Event.Tick(value) => ticks.add(value.deltaMillis); elapsed.add(value.elapsedMillis)
                    case _ => ()
                }
                UpdateResult.unchanged()
            }, options: HeadlessRunOptions(area: Rect(0, 0, 1, 1), tickDeltaMillis: 10))
        @Expect(ticks.toArray(), [7, 10, 3, 0])
        @Expect(elapsed.toArray(), [7, 17, 20, 20])
        let frames = result.metrics.frames()
        @Assert(frames.size, 5)
        for (index in 0..ticks.size) { @Expect(frames[index + 1].tickDeltaMillis, ticks[index]) }
        @Expect(frames[1].fps, 142)
        @Expect(frames[2].fps, 100)
        @Expect(frames[3].fps, 333)
        @Expect(frames[4].fps, 0)
    }

    @TestCase
    func explicitPtyCloseDeliversBufferedOutputBeforeExit(): Unit {
        for (stopOnExit in [false, true]) {
            let runtime = FakePtyRuntime()
            runtime.start("slot", PtySpec("fake"))
            runtime.injectText("slot", "TAIL")
            let events = Round2RuntimePtyEvents()
            let commands = ArrayList<Command>()
            commands.add(Command.PtyClose("slot"))
            let running = App.processCommands({ event => events.observe(event, stopOnExit: stopOnExit) },
                commands, ptyRuntime: runtime)
            @Expect(running, !stopOnExit)
            @Expect(events.order.toArray(), ["out:TAIL", "exited:0"])
            @Expect(runtime.activeCount(), 0)
            @Expect(runtime.drain().size, 0)
        }
    }

    @TestCase
    func replacementDeliversOldLifecycleBeforeNewStarted(): Unit {
        for (alreadyExited in [false, true]) {
            let runtime = FakePtyRuntime()
            runtime.start("slot", PtySpec("old"))
            runtime.injectText("slot", "TAIL")
            if (alreadyExited) { runtime.injectExit("slot", PtyExitStatus.Exited(0)) }
            let events = Round2RuntimePtyEvents()
            let commands = ArrayList<Command>()
            commands.add(Command.PtyStart("slot", PtySpec("new")))
            @Expect(App.processCommands({ event => events.observe(event) }, commands, ptyRuntime: runtime))
            @Expect(events.order.toArray(), ["out:TAIL", "exited:0", "started"])
            @Expect(runtime.activeCount(), 1)
            runtime.close("slot")
        }
    }

    @TestCase
    func activeProbeReplaysOrdinaryInputAfterAnEmptyRead(): Unit {
        let delayed = Round2RuntimeInput([[[], [b'a']]])
        let active = round2RunInput(delayed)
        let disabled = round2RunInput(Round2RuntimeInput([], normal: [[b'a']]), mode: TerminalProbeMode.Disabled)
        @Expect(active.keys.toArray(), ["a"])
        @Expect(active.keys.toArray(), disabled.keys.toArray())
        @Expect(!active.capabilities.getOrThrow().keyUp)
    }

    @TestCase
    func activeProbePreservesMixedReplyAndUtf8ByteOrder(): Unit {
        let input = Round2RuntimeInput([[
            [b'a', 27], [b'[', b'?', b'1'], [b'u', b'b', 0xE4], [0xB8]
        ]], normal: [[0xAD, b'c']])
        let events = round2RunInput(input)
        @Expect(events.keys.toArray(), ["a", "b", "中", "c"])
        @Expect(events.capabilities.getOrThrow().keyUp)
        @Expect(events.pastes.size, 0)
    }

    @TestCase
    func activeProbeRetainsPastePayloadAndIncompleteInput(): Unit {
        let bytes = unsafe { "a\u{1B}[?1ub\u{1B}[200~x\u{1B}[?1uy\u{1B}[201~c".rawData() }
        let pasted = round2RunInput(Round2RuntimeInput([[bytes]]))
        @Expect(pasted.keys.toArray(), ["a", "b", "c"])
        @Expect(pasted.pastes.toArray(), ["x\u{1B}[?1uy"])
        @Expect(pasted.capabilities.getOrThrow().keyUp)
        let split = round2RunInput(Round2RuntimeInput([[[27, b'[']]], normal: [[b'A', b'q']]))
        @Expect(split.keys.toArray(), ["up", "q"])
        @Expect(!split.capabilities.getOrThrow().keyUp)
    }

    @TestCase
    func capabilitiesPublishProbeResultAndPreserveDriverFallback(): Unit {
        let reply = unsafe { "\u{1B}[?1u".rawData() }
        let probed = round2RunInput(Round2RuntimeInput([[reply]]))
        let capabilities = probed.capabilities.getOrThrow()
        @Expect(capabilities.keyUp)
        @Expect(!capabilities.trueColor)
        @Expect(!capabilities.osc8)
        @Expect(capabilities.driverName, "round2-driver")
        match (capabilities.keyboardProtocol) { case KeyProtocol.Kitty => (); case _ => @Expect(false) }
        for (keyUp in [false, true]) {
            for (mode in [TerminalProbeMode.Disabled, TerminalProbeMode.EnvOnly, TerminalProbeMode.Active]) {
                let fallback = round2RunInput(Round2RuntimeInput([]), mode: mode, keyUp: keyUp)
                @Expect(fallback.capabilities.getOrThrow().keyUp, keyUp)
            }
        }
        @Expect(probed.keys.size, 0)
    }

    @TestCase
    func sessionProbesEachStartAndKeepsCapturedBytes(): Unit {
        let first = unsafe { "a\u{1B}[?1u".rawData() }
        let second = unsafe { "b\u{1B}[".rawData() }
        let input = Round2RuntimeInput([[first], [second]])
        let session = TerminalSession(AnsiBackend(output: Round2RuntimeOutput(input)),
            driver: Round2RuntimeDriver(), probeInputSource: input,
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false,
            keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto, probe: TerminalProbeMode.Active, probeBudgetMillis: 20))
        try {
            @Assert(session.start())
            @Expect(session.probeResult().getOrThrow().capabilities.keyUp)
            @Expect(session.probeResult().getOrThrow().consumedBytes, first)
            session.stop()
            @Assert(session.start())
            @Expect(!session.probeResult().getOrThrow().capabilities.keyUp)
            @Expect(session.probeResult().getOrThrow().consumedBytes, second)
            @Expect(input.cycles, 2)
        } finally { session.stop() }
    }
}

@When[os == "Linux"]
func round2StartReadyPty(runtime: LinuxPtyRuntime, waiter: LinuxEpollEventWaiter): Bool {
    let program = "import os,signal,time\ndef end(sig,frame):\n os.write(1,b'TAIL')\n os.write(2,b'ERR')\n raise SystemExit(0)\nsignal.signal(signal.SIGTERM,end)\nos.write(1,b'READY')\nwhile True: time.sleep(1)\n"
    match (runtime.start("slot", PtySpec("/usr/bin/python3", args: ["-c", program]))) {
        case Event.PtyStarted(_) => ()
        case _ => return false
    }
    let events = Round2RuntimePtyEvents()
    let deadline = MonoTime.now() + Duration.second * 3
    while (!events.ready && MonoTime.now() < deadline) {
        waiter.wait(50, previousReadBytes: 0, sources: runtime.sources())
        for (event in runtime.drain()) { events.observe(event) }
    }
    events.ready
}

@When[os == "Linux"]
@Test
class Round2RuntimeLinuxTest {
    @TestCase
    func explicitCloseCollectsBothStreamsBeforeTheExitCallback(): Unit {
        for (stopOnExit in [false, true]) {
            let runtime = LinuxPtyRuntime()
            let waiter = LinuxEpollEventWaiter()
            try {
                @Assert(round2StartReadyPty(runtime, waiter))
                let events = Round2RuntimePtyEvents()
                let commands = ArrayList<Command>()
                commands.add(Command.PtyClose("slot"))
                @Expect(App.processCommands({ event => events.observe(event, stopOnExit: stopOnExit) },
                    commands, ptyRuntime: runtime), !stopOnExit)
                @Expect(events.order.toArray(), ["out:TAIL", "err:ERR", "exited:0"])
                @Expect(runtime.activeCount(), 0)
                @Expect(runtime.drain().size, 0)
            } finally { runtime.close("slot"); waiter.close() }
        }
    }

    @TestCase
    func sameIdReplacementCompletesOldLifecycleBeforeItsResult(): Unit {
        for (valid in [true, false]) {
            let runtime = LinuxPtyRuntime()
            let waiter = LinuxEpollEventWaiter()
            try {
                @Assert(round2StartReadyPty(runtime, waiter))
                let oldProcess = runtime.process("slot").getOrThrow()
                let events = Round2RuntimePtyEvents()
                let commands = ArrayList<Command>()
                let spec = if (valid) { PtySpec("/bin/sleep", args: ["10"]) } else { PtySpec("") }
                commands.add(Command.PtyStart("slot", spec))
                @Expect(App.processCommands({ event => events.observe(event) }, commands, ptyRuntime: runtime))
                @Expect(events.order.toArray(), ["out:TAIL", "err:ERR", "exited:0", if (valid) { "started" } else { "failed" }])
                @Expect(runtime.activeCount(), if (valid) { 1 } else { 0 })
                @Expect(!oldProcess.write([b'x']))
            } finally { runtime.close("slot"); waiter.close() }
        }
    }
}
