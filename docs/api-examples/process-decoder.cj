package cjtui_api_example

import core.*

// A test double: no operating-system process is started.
class ExampleRuntime <: ProcessRuntime {
    public func start(id: String, spec: ProcessSpec): Event { Event.ProcessStarted(id) }
    public func cancel(id: String): Event { Event.ProcessCancelRequested(id) }
    public func sources(): Array<EventSource> { [] }
    public func drain(): Array<Event> { [] }
    public func activeCount(): Int64 { 0 }
    public func nextTimeoutMillis(): ?Int64 { None }
    public func metrics(): ProcessMetrics { ProcessMetrics() }
    public func closeAll(): Unit {}
}

main(): Int64 {
    let spec = ProcessSpec("example", args: ["--version"], timeoutMillis: 500)
    let runtime: ProcessRuntime = ExampleRuntime()
    match (runtime.start("sample", spec)) {
        case Event.ProcessStarted(id) => if (id != "sample") { throw IllegalStateException("runtime id failed") }
        case _ => throw IllegalStateException("runtime start failed")
    }
    runtime.closeAll()
    let metrics = ProcessMetrics(queuedBytes: 2)
    if (spec.args.size != 1 || spec.timeoutMillis != 500 || metrics.queuedBytes != 2) { throw IllegalStateException("process configuration failed") }
    let decoder = Utf8StreamDecoder()
    if (decoder.feed([0xE4, 0xB8]) != "" || decoder.feed([0xAD]) != "中" || decoder.finish() != "") {
        throw IllegalStateException("UTF-8 stream decoding failed")
    }
    let truncated = Utf8StreamDecoder()
    _ = truncated.feed([0xE4])
    if (truncated.finish() != "�") { throw IllegalStateException("UTF-8 finalization failed") }
    return 0
}
