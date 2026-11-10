package cjtui_api_example

import core.*

class OutputBox {
    public var value: String = ""
}

class FakeClipboardRunner <: ClipboardCommandRunner {
    private var saved = ""
    public func platform(): String { "macos" }
    public func environment(_: String): String { "" }
    public func available(command: String): Bool { command == "pbcopy" || command == "pbpaste" }
    public func run(command: String, _: Array<String>, input: ?String, _: Int64, _: Int64): ClipboardCommandResult {
        if (command == "pbcopy") { saved = input.getOrThrow(); return ClipboardCommandResult(ClipboardStatus.Success, exitCode: 0) }
        ClipboardCommandResult(ClipboardStatus.Success, output: saved, exitCode: 0)
    }
}

main(): Int64 {
    let runner: ClipboardCommandRunner = FakeClipboardRunner()
    let system = SystemClipboard(runner: runner)
    system.setText("hello")
    if (!system.capabilities().canWrite || system.getText() != "hello" || !system.readText().isSuccess() ||
        !system.writeText("world").isSuccess() || detectClipboard(runner: runner).getText() != "world") {
        throw IllegalStateException("system clipboard adapter failed")
    }
    let sent = OutputBox()
    let osc = Osc52Clipboard({ value => sent.value = value })
    osc.setText("ok")
    if (!osc.capabilities().canWrite || osc.capabilities().canRead || !sent.value.contains("52;c;b2s=") ||
        !osc.writeText("ok").isSuccess() || osc.readText().isSuccess()) {
        throw IllegalStateException("OSC 52 adapter failed")
    }
    var unsupported = false
    try { _ = osc.getText() } catch (_: Exception) { unsupported = true }
    if (!unsupported) { throw IllegalStateException("OSC 52 read should fail") }
    let native = NativeClipboardCommandRunner()
    _ = native.platform()
    _ = native.environment("TERMCANVAS_DOC_EXAMPLE_MISSING")
    let missing = "termcanvas-example-no-such-command"
    if (native.available(missing)) { throw IllegalStateException("unexpected command") }
    let result = native.run(missing, [], Option<String>.None, 100, 1024)
    if (result.output != "" || result.exitCode != -1 || result.message.isEmpty()) {
        throw IllegalStateException("missing command result failed")
    }
    match (result.status) {
        case ClipboardStatus.Unavailable => ()
        case _ => throw IllegalStateException("missing command status failed")
    }
    return 0
}
