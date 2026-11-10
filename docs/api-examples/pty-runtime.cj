package cjtui_api_example

import core.*

main(): Int64 {
    // FakePtyRuntime is a test double and does not start a system process.
    let runtime: PtyRuntime = FakePtyRuntime()
    let spec = PtySpec("example", args: ["--version"], size: PtySize(cols: 80, rows: 24))
    match (runtime.start("shell", spec)) {
        case Event.PtyStarted(id) => if (id != "shell") { throw IllegalStateException("PTY id failed") }
        case _ => throw IllegalStateException("PTY start failed")
    }
    match (runtime.process("shell")) {
        case Some(process) => if (!process.writeText("hello") || !process.resize(PtySize(cols: 100, rows: 30))) { throw IllegalStateException("PTY operations failed") }
        case None => throw IllegalStateException("PTY missing")
    }
    if (runtime.activeCount() != 1) { throw IllegalStateException("PTY count failed") }
    _ = runtime.close("shell")
    if (runtime.activeCount() != 0) { throw IllegalStateException("PTY close failed") }
    return 0
}
