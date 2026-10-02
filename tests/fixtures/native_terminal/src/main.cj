package cjtui_native_terminal_probe

import core.*
import std.fs.File

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
}

class Probe {
    let mode: String
    let observation: NativeObservation
    let port = ExternalPort<Event>()
    var status = "NATIVE_READY"

    init(mode: String, observation: NativeObservation) {
        this.mode = mode
        this.observation = observation
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(Paragraph(status), frame.area)
        if (status == "NATIVE_READY") {
            if (nativeConsoleRaw()) { observation.mark("NATIVE_RAW_OK") }
            observation.mark(status)
        }
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Char(r'q') | KeyCode.CtrlC => UpdateResult.exit()
                case KeyCode.Char(r'x') =>
                    if (mode == "exception") { throw Exception("native probe expected exception") }
                    status = "NATIVE_INPUT_OK"
                    observation.mark(status)
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
                status = "NATIVE_RESIZE_${area.width}x${area.height}"
                observation.mark(status)
                UpdateResult.next()
            case Event.Message("awake") =>
                status = "NATIVE_AWAKE"
                observation.mark(status)
                UpdateResult.next()
            case _ => UpdateResult.unchanged()
        }
    }
}

main(args: Array<String>): Int64 {
    let mode = if (args.size > 0) { args[0] } else { "input" }
    let observation = NativeObservation(if (args.size > 1) { args[1] } else { "" })
    let console = NativeConsoleSnapshot()
    let probe = Probe(mode, observation)
    let app = App(
        renderMode: RenderMode.Full,
        resize: mode == "input",
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
    }
    console.assertRestored(observation)
    observation.mark("NATIVE_CLOSED")
    println("NATIVE_CLOSED")
    0
}
