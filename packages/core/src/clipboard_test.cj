package core

import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

class FakeClipboardCommandRunner <: ClipboardCommandRunner {
    var os: String = "linux"
    var display: String = ""
    var wayland: String = "wayland-0"
    var ssh: String = ""
    var tmux: String = ""
    var commands: Array<String> = ["wl-copy", "wl-paste"]
    var result = ClipboardCommandResult(ClipboardStatus.Success, output: "你好\nsecond line\n", exitCode: 0)
    var calls: Int64 = 0
    var lastCommand: String = ""
    var lastArguments: Array<String> = []
    var lastInput: ?String = None
    var lastTimeout: Int64 = 0
    var lastLimit: Int64 = 0
    var fail: Bool = false
    public func platform(): String { os }
    public func environment(name: String): String {
        if (name == "WAYLAND_DISPLAY") { wayland }
        else if (name == "DISPLAY") { display }
        else if (name == "SSH_CONNECTION") { ssh }
        else if (name == "TMUX") { tmux }
        else { "" }
    }
    public func available(command: String): Bool {
        for (item in commands) { if (item == command) { return true } }
        false
    }
    public func run(command: String, arguments: Array<String>, input: ?String, timeoutMillis: Int64, maxBytes: Int64): ClipboardCommandResult {
        if (fail) { throw Exception("runner failure") }
        calls++; lastCommand = command; lastArguments = arguments; lastInput = input
        lastTimeout = timeoutMillis; lastLimit = maxBytes
        result
    }
}

class ClipboardTestOutput { var text: String = "" }

@Test
class ClipboardCapabilityTest {
    @TestCase
    func nativeAdapterPreservesUnicodeMultilineAndUsesStdin(): Unit {
        let runner = FakeClipboardCommandRunner()
        let clipboard = SystemClipboard(runner: runner, timeoutMillis: 37, maxBytes: 100)
        @Expect(clipboard.capabilities().backend, "wayland")
        let text = "你好\n$(not a command)\n"
        @Expect(clipboard.writeText(text).isSuccess())
        @Expect(runner.lastCommand, "wl-copy")
        @Expect(runner.lastInput, Some(text))
        @Expect(runner.lastArguments[0], "--type")
        @Expect(runner.lastTimeout, 37)
        @Expect(runner.lastLimit, 100)
        let read = clipboard.readText()
        @Expect(read.isSuccess())
        @Expect(read.text, "你好\nsecond line\n")
        @Expect(runner.lastCommand, "wl-paste")
        @Expect(runner.lastArguments[0], "--no-newline")
    }

    @TestCase
    func detectionSupportsX11MacWindowsAndMissingPrograms(): Unit {
        let runner = FakeClipboardCommandRunner()
        runner.wayland = ""; runner.display = ":0"; runner.commands = ["xclip"]
        let xclip = SystemClipboard(runner: runner)
        @Expect(xclip.capabilities().backend, "xclip")
        @Expect(xclip.writeText("x").isSuccess())
        @Expect(runner.lastArguments[1], "clipboard")
        runner.commands = ["xsel"]
        @Expect(SystemClipboard(runner: runner).capabilities().backend, "xsel")
        runner.os = "macos"; runner.commands = ["pbcopy", "pbpaste"]
        @Expect(SystemClipboard(runner: runner).capabilities().canRead)
        runner.os = "windows"; runner.commands = ["powershell.exe"]
        let windows = SystemClipboard(runner: runner)
        @Expect(windows.writeText("中\n文").isSuccess())
        @Expect(runner.lastCommand, "powershell.exe")
        @Expect(runner.lastArguments[3].contains("ReadToEnd"))
        @Expect(runner.lastInput, Some("中\n文"))
        runner.commands = []
        let missing = SystemClipboard(runner: runner)
        @Expect(!missing.capabilities().canRead && !missing.capabilities().canWrite)
        @Expect(!missing.readText().isSuccess())
        runner.os = "macos"; runner.commands = ["pbcopy"]
        @Expect(!SystemClipboard(runner: runner).capabilities().canRead)
        runner.commands = ["pbpaste"]
        @Expect(!SystemClipboard(runner: runner).capabilities().canWrite)
        runner.os = "windows"; runner.commands = ["pwsh.exe"]
        @Expect(SystemClipboard(runner: runner).capabilities().canWrite)
    }

    @TestCase
    func failuresLimitsAndReadOnlyDetectionStayObservable(): Unit {
        let runner = FakeClipboardCommandRunner()
        runner.commands = ["wl-paste"]
        let clipboard = SystemClipboard(runner: runner, maxBytes: 6)
        @Expect(clipboard.capabilities().canRead)
        @Expect(!clipboard.capabilities().canWrite)
        @Expect(!clipboard.writeText("x").isSuccess())
        @Expect(runner.calls, 0)
        runner.result = ClipboardCommandResult(ClipboardStatus.Timeout, message: "timeout")
        @Expect(clipboard.readText().message, "timeout")
        runner.result = ClipboardCommandResult(ClipboardStatus.Success, output: "1234567")
        @Expect(!clipboard.readText().isSuccess())
        runner.commands = ["wl-copy"]
        let bounded = SystemClipboard(runner: runner, maxBytes: 6)
        @Expect(!bounded.writeText("中文x").isSuccess())
        runner.result = ClipboardCommandResult(ClipboardStatus.Failed, exitCode: 7, message: "exit 7")
        @Expect(bounded.writeText("中文").message, "exit 7")
        runner.fail = true
        @Expect(bounded.writeText("x").message, "runner failure")
        @Expect(clipboard.readText().message, "runner failure")
        var threw = false
        try { bounded.setText("x") } catch (_: Exception) { threw = true }
        @Expect(threw)
    }

    @TestCase
    func osc52IsExplicitlyWriteOnlyAndEmitsExactUtf8Payload(): Unit {
        let output = ClipboardTestOutput()
        let clipboard = Osc52Clipboard({ text => output.text = text })
        @Expect(clipboard.writeText("你好\n").isSuccess())
        @Expect(output.text, "\u{1B}]52;c;5L2g5aW9Cg==\u{7}")
        @Expect(!clipboard.capabilities().canRead)
        @Expect(!clipboard.readText().isSuccess())
        let before = output.text
        @Expect(!Osc52Clipboard({ text => output.text = text }, maxBytes: 1).writeText("中").isSuccess())
        @Expect(output.text, before)
        let tmux = Osc52Clipboard({ text => output.text = text }, tmuxPassthrough: true)
        @Expect(tmux.writeText("a").isSuccess())
        @Expect(output.text, "\u{1B}Ptmux;\u{1B}\u{1B}]52;c;YQ==\u{7}\u{1B}\\")
        @Expect(!Osc52Clipboard({ _ => throw Exception("terminal closed") }).writeText("a").isSuccess())
        @Expect(!Osc52Clipboard({ _ => () }, enabled: false).capabilities().canWrite)
        @Expect(!Osc52Clipboard({ _ => () }, enabled: false).writeText("a").isSuccess())
        @Expect(clipboardBase64([]), "")
        @Expect(clipboardBase64("ab".toArray()), "YWI=")
        @Expect(clipboardBase64("abc".toArray()), "YWJj")
    }

    @TestCase
    func sshFactoryDoesNotPretendRemoteClipboardIsReadable(): Unit {
        let runner = FakeClipboardCommandRunner()
        runner.ssh = "client 123 server 22"
        let output = ClipboardTestOutput()
        let clipboard = detectClipboard(runner: runner, osc52Emitter: Some({ text => output.text = text }))
        @Expect(clipboard.capabilities().backend, "osc52")
        @Expect(!clipboard.capabilities().canRead)
        @Expect(clipboard.writeText("hello").isSuccess())
        @Expect(runner.calls, 0)
        @Expect(output.text.contains("]52;c;"))
        let memory: Clipboard = MemoryClipboard(text: "a\nb")
        @Expect(memory.readText().text, "a\nb")
        @Expect(memory.writeText("更新").isSuccess())
        @Expect(memory.getText(), "更新")
        runner.ssh = ""
        @Expect(detectClipboard(runner: runner).capabilities().backend, "wayland")
        runner.commands = []
        @Expect(detectClipboard(runner: runner).capabilities().backend, "unavailable")
        @Expect(detectClipboard(runner: runner, osc52Emitter: Some({ _ => () })).capabilities().backend, "osc52")
    }

}

@When[os == "Linux" || os == "macOS"]
@Test
class ClipboardNativeRunnerTest {
    @TestCase
    func nativeRunnerEnforcesRealProcessTimeoutOutputLimitAndStdin(): Unit {
        let runner = NativeClipboardCommandRunner()
        let written = runner.run("/bin/sh", ["-c", "test \"$(cat)\" = '中文\nline'"], Some("中文\nline\n"), 1000, 1024)
        @Expect(clipboardStatusSuccess(written.status))
        let output = runner.run("/bin/sh", ["-c", "printf '%s' '中文\nline\n'"], Option<String>.None, 1000, 1024)
        @Expect(clipboardStatusSuccess(output.status))
        @Expect(output.output, "中文\nline\n")
        let start = MonoTime.now()
        let timed = runner.run("/bin/sleep", ["5"], Option<String>.None, 30, 1024)
        match (timed.status) { case ClipboardStatus.Timeout => (); case _ => @Expect(false) }
        @Expect((MonoTime.now() - start).toMilliseconds() < 2000)
        let limited = runner.run("/bin/sh", ["-c", "while :; do printf '0123456789'; done"], Option<String>.None, 1000, 15)
        match (limited.status) { case ClipboardStatus.TooLarge => (); case _ => @Expect(false) }
        let failed = runner.run("/bin/sh", ["-c", "exit 7"], Option<String>.None, 1000, 1024)
        @Expect(failed.exitCode, 7)
        @Expect(!clipboardStatusSuccess(failed.status))
        @Expect(runner.available("sh"))
        @Expect(!runner.available("/tmp"))
        @Expect(!runner.available("/etc/hosts"))
        @Expect(!clipboardStatusSuccess(runner.run("/termcanvas/missing-command", [], Option<String>.None, 100, 10).status))
        @Expect(!clipboardStatusSuccess(runner.run("/bin/sh", [], Some("toolarge"), 100, 1).status))
        @Expect(!clipboardStatusSuccess(runner.run("/bin/sh", ["\u{0}"], Option<String>.None, 100, 10).status))
        let invalidUtf8 = runner.run("/bin/sh", ["-c", "printf '\\377'"], Option<String>.None, 1000, 10)
        @Expect(!clipboardStatusSuccess(invalidUtf8.status))
        let dual = runner.run("/bin/sh", ["-c", "i=0; while [ \"$i\" -lt 1024 ]; do printf 'stderr noise 0123456789\\n' >&2; printf x; i=$((i+1)); done"], Option<String>.None, 1000, 2048)
        @Expect(clipboardStatusSuccess(dual.status))
        @Expect(dual.output.size, 1024)
        let blockedWrite = runner.run("/bin/sleep", ["5"], Some(repeat("x", 1024 * 1024)), 30, 1024 * 1024)
        match (blockedWrite.status) { case ClipboardStatus.Timeout => (); case _ => @Expect(false) }
    }
}
