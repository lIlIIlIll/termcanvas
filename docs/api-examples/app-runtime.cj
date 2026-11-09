package cjtui_api_example

import core.*

class OneKey <: InputSource {
    private var sent = false
    public func readAvailable(maxBytes: Int64): Array<Byte> {
        if (sent || maxBytes <= 0) { return [] }
        sent = true
        [b'q']
    }
}

class Trace <: AppTraceSink {
    public var inputs: Int64 = 0
    public func inputReceived(event: Event, eventQueueLength: Int64): Unit { inputs++ }
    public func eventDispatchCompleted(): Unit {}
    public func stateUpdateCompleted(): Unit {}
    public func renderStarted(): Unit {}
    public func eventLoopStall(task: String, durationNanos: Int64): Unit {}
}

main(): Int64 {
    let backend = TestBackend(area: Rect(0, 0, 20, 4))
    let app = App(backend: backend, inputSource: OneKey(), terminalDriver: FallbackTerminalDriver(),
        rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false)
    let trace = Trace()
    app.attachTraceSink(trace)
    app.attachPtyRuntime(FakePtyRuntime())
    app.setTextWidthOptions(TextWidthOptions())
    app.runWithCommands({ frame => frame.renderWidget(Paragraph("Ready"), frame.area) }, { event =>
        match (event) {
            case Event.KeyDown(_) => UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }
    })
    if (trace.inputs == 0) { throw IllegalStateException("app input was not traced") }
    return 0
}
