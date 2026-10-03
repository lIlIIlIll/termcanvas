package cjtui_native_terminal_probe

import core.*
import std.fs.File
import std.sync.*
import std.collection.ArrayList

// ConPTY translates stdout into screen diffs. Sidecar markers record events
// after the application handles them, independently of that presentation.
class NativeObservation {
    let directory: String
    init(directory: String) { this.directory = directory }
    func mark(value: String): Unit {
        if (!directory.isEmpty()) {
            File.writeTo("${directory}/${value}", value.toArray())
        }
    }
    func report(value: String): Unit {
        if (!directory.isEmpty()) {
            File.writeTo("${directory}/NATIVE_LOAD_COUNTS.json", value.toArray())
        }
    }
}

// Only the producer owns the sequence counter. Full is explicit backpressure:
// retry the same value, then join before checking that every accepted value
// reached App.update. The stop flag is independent of a potentially full port.
class NativeLoad {
    let port: ExternalPort<Event>
    let lock = Mutex()
    var stopping = false
    var worker: ?Future<Int64> = None

    init(port: ExternalPort<Event>) { this.port = port }

    func stopped(): Bool {
        lock.lock()
        try { stopping } finally { lock.unlock() }
    }

    func start(): Unit {
        worker = Some(spawn {
            var accepted: Int64 = 0
            while (!stopped()) {
                match (port.tryEnqueue(Event.Message("load:${accepted + 1}"))) {
                    case ExternalEnqueueResult.Accepted => accepted++
                    case ExternalEnqueueResult.Full => sleep(Duration.microsecond * 100)
                    case ExternalEnqueueResult.Closed => return accepted
                }
            }
            accepted
        })
    }

    func stop(): Int64 {
        lock.lock()
        try { stopping = true } finally { lock.unlock() }
        match (worker) { case Some(value) => value.get(); case None => 0 }
    }
}

class Probe {
    let mode: String
    let observation: NativeObservation
    let port = ExternalPort<Event>(capacity: 64)
    let load: NativeLoad
    let metrics = AppMetrics()
    var status = "NATIVE_READY"
    var loadStarted = false
    var received: Int64 = 0
    var accepted: Int64 = -1
    var ticks: Int64 = 0
    var frames: Int64 = 0
    var inputs: Int64 = 0
    var resizes: Int64 = 0
    var reported = false

    init(mode: String, observation: NativeObservation) {
        this.mode = mode
        this.observation = observation
        this.load = NativeLoad(port)
    }

    func render(frame: Frame): Unit {
        if (loadStarted && accepted < 0) { frames++ }
        frame.renderWidget(Paragraph(status), frame.area)
        if (status == "NATIVE_READY") {
            if (nativeConsoleRaw()) { observation.mark("NATIVE_RAW_OK") }
            observation.mark(status)
        }
        if (accepted >= 0 && received == accepted && !reported) {
            let runtime = metrics.runtime()
            observation.report("{\"accepted\":${accepted},\"received\":${received}," +
                "\"ticks\":${ticks},\"frames\":${frames},\"inputs\":${inputs},\"resizes\":${resizes}," +
                "\"backpressure\":${port.fullCount()},\"queue_max\":${runtime.maxQueueDepth}," +
                "\"queue_overflows\":${runtime.queueOverflows}}")
            observation.mark("NATIVE_LOAD_DRAINED")
            reported = true
        }
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Char(r'q') | KeyCode.CtrlC => UpdateResult.exit()
                case KeyCode.Char(r'界') =>
                    observation.mark("NATIVE_UNICODE_BMP_OK")
                    UpdateResult.unchanged()
                case KeyCode.Char(r'😀') =>
                    observation.mark("NATIVE_UNICODE_PAIR_OK")
                    UpdateResult.unchanged()
                case KeyCode.Up =>
                    observation.mark("NATIVE_ARROW_OK")
                    UpdateResult.unchanged()
                case KeyCode.Char(r'x') =>
                    if (mode == "exception") { throw Exception("native probe expected exception") }
                    if (mode == "load" && loadStarted && accepted < 0) { inputs++ }
                    status = if (mode == "load") { "NATIVE_LOAD_INPUT_OK" } else { "NATIVE_INPUT_OK" }
                    observation.mark(status)
                    UpdateResult.next()
                case KeyCode.Char(r'l') =>
                    if (mode != "load" || loadStarted) { return UpdateResult.unchanged() }
                    loadStarted = true
                    status = "NATIVE_LOAD_STARTED"
                    load.start()
                    UpdateResult.next()
                case KeyCode.Char(r's') =>
                    if (mode != "load" || !loadStarted) { return UpdateResult.unchanged() }
                    accepted = load.stop()
                    UpdateResult.next()
                case KeyCode.Char(r'w') =>
                    status = "NATIVE_ARMED"
                    let destination = port
                    spawn {
                        sleep(Duration.millisecond * 150)
                        _ = destination.tryEnqueue(Event.Message("awake"))
                    }
                    UpdateResult.next()
                case _ => UpdateResult.unchanged()
            }
            case Event.Resize(area) =>
                if (mode == "load" && loadStarted && accepted < 0) { resizes++ }
                status = "NATIVE_RESIZE_${area.width}x${area.height}"
                observation.mark(status)
                UpdateResult.next()
            case Event.Message("awake") =>
                status = "NATIVE_AWAKE"
                observation.mark(status)
                UpdateResult.next()
            case Event.Message(value) =>
                if (mode != "load") { return UpdateResult.unchanged() }
                if (value != "load:${received + 1}") {
                    throw Exception("load sequence lost or reordered at ${received + 1}: ${value}")
                }
                received++
                if (received == 1024) { observation.mark("NATIVE_LOAD_ACTIVE") }
                // Keep a deterministically saturated source across many App
                // turns while real input, resize, ticks and draws progress.
                if (received % 16 == 0) { sleep(Duration.millisecond) }
                UpdateResult.next()
            case Event.Tick(_) =>
                if (mode == "load" && loadStarted && accepted < 0) {
                    ticks++
                    if (ticks == 2) { observation.mark("NATIVE_LOAD_TICKS_OK") }
                }
                UpdateResult.unchanged()
            case _ => UpdateResult.unchanged()
        }
    }
}

main(args: Array<String>): Int64 {
    let mode = if (args.size > 0) { args[0] } else { "input" }
    if (mode == "redirected") {
        let input = StdinInputSource()
        let bytes = ArrayList<Byte>()
        for (_ in 0..100) {
            let chunk = input.readAvailable(2)
            bytes.add(all: chunk)
            if (bytes.size == "A界😀Z".size) {
                let text = unsafe { String.fromUtf8Unchecked(bytes.toArray()) }
                if (text == "A界😀Z") { println("NATIVE_REDIRECTED_OK"); return 0 }
                return 19
            }
            sleep(Duration.millisecond)
        }
        return 19
    }
    let observation = NativeObservation(if (args.size > 1) { args[1] } else { "" })
    let console = NativeConsoleSnapshot()
    let probe = Probe(mode, observation)
    let app = App(
        renderMode: RenderMode.Full,
        resize: mode == "input" || mode == "load",
        tickEvery: if (mode == "load") { Some(Duration.millisecond * 20) } else { None },
        metrics: Some(probe.metrics),
        idleSleep: Duration.second * 5,
        resizePollEvery: Duration.millisecond * 50
    )
    try {
        app.runWithExternalPort(probe.port,
            { frame => probe.render(frame) }, { event => probe.update(event) }
        )
    } catch (error: Exception) {
        if (mode == "exception" && error.message == "native probe expected exception") {
            console.assertRestored(observation)
            observation.mark("NATIVE_EXPECTED_EXCEPTION")
            println("NATIVE_EXPECTED_EXCEPTION")
            return 17
        }
        throw error
    } finally {
        _ = probe.load.stop()
    }
    console.assertRestored(observation)
    observation.mark("NATIVE_CLOSED")
    println("NATIVE_CLOSED")
    0
}
