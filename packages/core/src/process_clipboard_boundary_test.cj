package core

import std.collection.*
import std.convert.*
import std.env.*
import std.fs.*
import std.process.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@FastNative
@When[os == "Linux"]
foreign func open(path: CString, flags: Int32): Int32

func boundaryRejectsProcess(action: () -> Unit): Bool {
    try { action(); false } catch (_: IllegalArgumentException) { true }
}

func boundaryRestoreEnvironment(name: String, value: ?String): Unit {
    match (value) { case Some(text) => setVariable(name, text); case None => removeVariable(name) }
}

class BoundaryCustomClipboard <: Clipboard {
    var text = "initial"
    var failRead = false
    var failWrite = false
    public func getText(): String { if (failRead) { throw Exception("read denied") }; text }
    public func setText(value: String): Unit { if (failWrite) { throw Exception("write denied") }; text = value }
}

class BoundarySshTtyRunner <: ClipboardCommandRunner {
    public func platform(): String { "linux" }
    public func environment(name: String): String {
        if (name == "SSH_TTY") { "/dev/pts/1" } else if (name == "TMUX") { "session" } else { "" }
    }
    public func available(_: String): Bool { false }
    public func run(_: String, _: Array<String>, _: ?String, _: Int64, _: Int64): ClipboardCommandResult {
        throw Exception("remote clipboard must not launch a local command")
    }
}

@Test
class ProcessClipboardBoundaryTest {
    @TestCase
    func processSpecificationsRejectEachInvalidLimitAndNulBoundary(): Unit {
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", timeoutMillis: -1) }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", maxOutputBytes: -1) }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", drainTimeoutMillis: 0) }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", drainTimeoutMillis: -1) }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("bad\u{0}command") }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", cwd: "bad\u{0}directory") }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", args: ["a", "bad\u{0}arg"]) }))
        @Expect(boundaryRejectsProcess({ => _ = ProcessSpec("cmd", env: ["A=ok", "B=bad\u{0}value"]) }))
        let args = ["original"]
        let env = ["KEY=original"]
        let spec = ProcessSpec("cmd", args: args, env: env, timeoutMillis: 0, maxOutputBytes: 0, drainTimeoutMillis: 1)
        args[0] = "mutated"; env[0] = "KEY=mutated"
        @Expect(spec.args[0], "original")
        @Expect(spec.env[0], "KEY=original")
        @Expect(spec.maxOutputBytes, 0)
        let unavailable = UnsupportedProcessRuntime()
        match (unavailable.start("id", spec)) { case Event.ProcessFailed("id", _) => (); case _ => @Expect(false) }
        match (unavailable.cancel("id")) { case Event.ProcessFailed("id", _) => (); case _ => @Expect(false) }
        @Expect(unavailable.sources().isEmpty())
        @Expect(unavailable.drain().isEmpty())
        @Expect(unavailable.activeCount(), 0)
        @Expect(unavailable.nextTimeoutMillis().isNone())
        @Expect(unavailable.metrics().outputBytes, 0)
        unavailable.closeAll(); unavailable.closeAll()
    }

    @TestCase
    func utf8DecoderChecksScalarEdgesAndMalformedContinuationPrefixes(): Unit {
        let valid = "\u{80}\u{7FF}\u{800}\u{D7FF}\u{E000}\u{FFFF}\u{10000}\u{10FFFF}"
        let bytes = valid.toArray()
        for (split in 0..bytes.size + 1) {
            let decoder = Utf8StreamDecoder()
            @Expect(decoder.feed(bytes[..split]) + decoder.feed([]) + decoder.feed(bytes[split..]) + decoder.finish(), valid)
        }
        let invalid: Array<Array<Byte>> = [
            [0x80], [0xBF], [0xC0], [0xC1], [0xF5], [0xFF],
            [0xC2, 0x61], [0xE0, 0x9F, 0x80], [0xF0, 0x8F, 0x80, 0x80],
            [0xF4, 0x90, 0x80, 0x80], [0xE1, 0x80, 0x61], [0xF1, 0x80, 0x61, 0x80]]
        for (data in invalid) {
            let expected = Utf8StreamDecoder().feed(data)
            @Expect(expected.contains("\u{FFFD}"))
            for (split in 0..data.size + 1) {
                let decoder = Utf8StreamDecoder()
                @Expect(decoder.feed(data[..split]) + decoder.feed(data[split..]) + decoder.finish(), expected)
            }
        }
        let partial: Array<Array<Byte>> = [[0xC2], [0xE0, 0xA0], [0xF4, 0x8F, 0xBF]]
        for (data in partial) {
            let decoder = Utf8StreamDecoder()
            @Expect(decoder.feed(data), "")
            @Expect(decoder.finish(), "\u{FFFD}")
            @Expect(decoder.finish(), "")
        }
    }

    @TestCase
    func defaultClipboardAdaptersPreserveMessagesAndDoNotMutateOnFailure(): Unit {
        let clipboard = BoundaryCustomClipboard()
        @Expect(clipboard.capabilities().backend, "custom")
        @Expect(clipboard.readText().text, "initial")
        @Expect(clipboard.writeText("new").isSuccess())
        clipboard.failRead = true
        let read = clipboard.readText()
        @Expect(!read.isSuccess())
        @Expect(read.backend, "custom")
        @Expect(read.message, "read denied")
        @Expect(read.text, "")
        clipboard.failWrite = true
        let write = clipboard.writeText("discarded")
        @Expect(!write.isSuccess())
        @Expect(write.message, "write denied")
        @Expect(clipboard.text, "new")
    }

    @TestCase
    func clipboardProbeHandlesMissingX11MacAndClampedConfiguration(): Unit {
        let runner = FakeClipboardCommandRunner()
        runner.os = "macos"; runner.commands = []
        @Expect(SystemClipboard(runner: runner).capabilities().backend, "unavailable")
        runner.os = "linux"; runner.wayland = ""; runner.display = ":0"
        @Expect(SystemClipboard(runner: runner).capabilities().backend, "unavailable")
        runner.display = ""; runner.wayland = "wayland-0"; runner.commands = []
        @Expect(SystemClipboard(runner: runner).capabilities().backend, "unavailable")
        runner.commands = ["wl-copy", "wl-paste"]
        runner.result = ClipboardCommandResult(ClipboardStatus.Success, output: "")
        let zero = SystemClipboard(runner: runner, timeoutMillis: -1, maxBytes: -1)
        @Expect(zero.getText(), "")
        zero.setText("")
        @Expect(runner.lastTimeout, 1)
        @Expect(runner.lastLimit, 0)
        @Expect(!zero.writeText("x").isSuccess())
        let large = SystemClipboard(runner: runner, timeoutMillis: Int64.Max, maxBytes: Int64.Max)
        large.setText("bounded")
        @Expect(runner.lastTimeout, 60000)
        @Expect(runner.lastLimit, 16 * 1024 * 1024)
        runner.result = ClipboardCommandResult(ClipboardStatus.Failed, output: "must not escape", message: "denied")
        @Expect(large.readText().text, "")
        var rejected = false
        try { _ = large.getText() } catch (error: Exception) { rejected = error.message == "denied" }
        @Expect(rejected)
    }

    @TestCase
    func osc52LegacyMethodsAndSshTtySelectionKeepWriteOnlyContract(): Unit {
        let output = ClipboardTestOutput()
        let clipboard = Osc52Clipboard({ text => output.text = text }, maxBytes: Int64.Max)
        clipboard.setText("abc")
        @Expect(output.text, "\u{1B}]52;c;YWJj\u{7}")
        var rejected = false
        try { _ = clipboard.getText() } catch (_: Exception) { rejected = true }
        @Expect(rejected)
        let empty = Osc52Clipboard({ text => output.text = text }, maxBytes: -1)
        @Expect(empty.writeText("").isSuccess())
        @Expect(output.text, "\u{1B}]52;c;\u{7}")
        @Expect(!empty.writeText("x").isSuccess())
        let remote = detectClipboard(runner: BoundarySshTtyRunner(), osc52Emitter: Some({ text => output.text = text }))
        @Expect(remote.capabilities().backend, "osc52")
        remote.setText("a")
        @Expect(output.text, "\u{1B}Ptmux;\u{1B}\u{1B}]52;c;YQ==\u{7}\u{1B}\\")
    }
}

@When[os != "Windows"]
@Test
class ProcessNativeBoundaryTest {
    @TestCase
    func invalidRuntimeBudgetsAndRejectedNativeStartupLeaveRuntimeReusable(): Unit {
        @Expect(boundaryRejectsProcess({ => _ = PosixProcessRuntime(maxProcesses: 0) }))
        @Expect(boundaryRejectsProcess({ => _ = PosixProcessRuntime(readBudgetBytes: 0) }))
        @Expect(boundaryRejectsProcess({ => _ = PosixProcessRuntime(maxQueuedBytes: 0) }))
        let runtime = PosixProcessRuntime(readBudgetBytes: 131072)
        try {
            match (runtime.start("empty", ProcessSpec(""))) { case Event.ProcessFailed(_, _) => (); case _ => @Expect(false) }
            // Empty environment names are rejected in the native parent,
            // before fork. Every already-open pipe must still be released.
            for (_ in 0..4) {
                match (runtime.start("bad-env", ProcessSpec("/bin/sh", env: ["=invalid"]))) {
                    case Event.ProcessFailed(_, message) => @Expect(message, "process native spawn failed")
                    case _ => @Expect(false)
                }
                @Expect(runtime.activeCount(), 0)
                @Expect(runtime.sources().isEmpty())
            }
            _ = runtime.start("after", ProcessSpec("/bin/sh", args: ["-c", "printf ok"]))
            let seen = collectProcess(runtime)
            @Expect(seen.stdoutBytes, 2)
            @Expect(seen.finishes, 1)
            @Expect(runtime.metrics().outputBytes, 2)
            @Expect(runtime.drain().isEmpty())
        } finally { runtime.closeAll() }
    }

    @TestCase
    func sourceContractCancellationAndStaleReadinessAreSafe(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            _ = runtime.start("first", ProcessSpec("/bin/sh", args: ["-c", "sleep 5 & wait"]))
            _ = runtime.start("second", ProcessSpec("/bin/sh", args: ["-c", "sleep 5 & wait"], timeoutMillis: 3000))
            let sources = runtime.sources()
            @Assert(sources.size, 4)
            @Expect(sources[0].id(), "first:stdout")
            @Expect(sources[1].id(), "first:stderr")
            for (source in sources) {
                match (source.interests()) { case EventSourceInterest.Read => (); case _ => @Expect(false) }
                @Expect(source.drain().isEmpty())
                source.onReady(false, true, false, false)
                source.onReady(false, false, true, false)
                source.onReady(false, false, false, true)
            }
            match (runtime.cancel("second")) { case Event.ProcessCancelRequested("second") => (); case _ => @Expect(false) }
            @Expect(runtime.nextTimeoutMillis().isSome())
            sources[0].close(); sources[0].close()
            runtime.closeAll()
            @Expect(runtime.activeCount(), 0)
            for (source in sources) {
                @Expect(source.fd().isNone())
                source.onReady(true, true, true, true)
                source.close()
            }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func zeroOutputLimitDistinguishesSilentSuccessFromTruncation(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            _ = runtime.start("silent", ProcessSpec("/bin/sh", args: ["-c", "exit 0"], maxOutputBytes: 0))
            let silent = collectProcess(runtime).result.getOrThrow()
            @Expect(silent.outputBytes, 0)
            @Expect(silent.outputComplete)
            match (silent.reason) { case ProcessEndReason.Exited => (); case _ => @Expect(false) }
            _ = runtime.start("limited", ProcessSpec("/bin/sh", args: ["-c", "printf x >&2"], maxOutputBytes: 0))
            let limited = collectProcess(runtime).result.getOrThrow()
            @Expect(limited.outputBytes, 0)
            @Expect(!limited.outputComplete)
            match (limited.reason) { case ProcessEndReason.OutputLimit => (); case _ => @Expect(false) }
        } finally { runtime.closeAll() }
    }

    @TestCase
    func forcedShutdownReapsTermIgnoringChildAndRetainsAcceptedOutputMetrics(): Unit {
        let runtime = PosixProcessRuntime()
        try {
            _ = runtime.start("force", ProcessSpec("/bin/sh", args: ["-c", "trap '' TERM; printf READY; while :; do :; done"]))
            let deadline = MonoTime.now() + Duration.second * 3
            var bytes: Int64 = 0
            while (bytes < 5 && MonoTime.now() < deadline) {
                for (event in runtime.drain()) {
                    match (event) { case Event.ProcessOutput(_, _, chunk) => bytes += chunk.size; case _ => () }
                }
                sleep(Duration.millisecond)
            }
            @Assert(bytes, 5)
            let started = MonoTime.now()
            runtime.closeAll()
            @Expect((MonoTime.now() - started).toMilliseconds() < 2000)
            @Expect(runtime.activeCount(), 0)
            @Expect(runtime.metrics().outputBytes, 5)
            @Expect(runtime.nextTimeoutMillis().isNone())
        } finally { runtime.closeAll() }
    }
}

@When[os != "Windows"]
@Test
class ClipboardNativeBoundaryTest {
    @TestCase
    func nativeWriteReportsExitAndLaunchErrorsAndExpiredDeadline(): Unit {
        let runner = NativeClipboardCommandRunner()
        let failed = runner.run("/bin/sh", ["-c", "exit 17"], Some(""), 1000, 0)
        match (failed.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
        @Expect(failed.exitCode, 17)
        @Expect(failed.message.contains("17"))
        let malformed = runner.run("/bin/sh", ["bad\u{0}arg"], Some("input"), 1000, 16)
        match (malformed.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
        @Expect(!malformed.message.isEmpty())
        var expired = false
        try { _ = clipboardRemaining(MonoTime.now() - Duration.second) } catch (_: TimeoutException) { expired = true }
        @Expect(expired)
        @Expect(clipboardRemaining(MonoTime.now() + Duration.second) > Duration.Zero)
        @Expect(clipboardStatusSuccess(runner.run("/bin/sh", ["-c", "exit 0"], Some(""), Int64.Max, Int64.Max).status))
    }

    @TestCase
    func unavailableTemporaryDirectoryAndRelativeExecutableAreReportedWithoutLeaks(): Unit {
        let runner = NativeClipboardCommandRunner()
        let priorPath = getVariable("PATH")
        let priorTemp = getVariable("TMPDIR")
        let priorMissing = getVariable("TERMCANVAS_UNSET_BOUNDARY_VARIABLE")
        try {
            setVariable("PATH", "")
            @Expect(!runner.available("termcanvas-no-such-relative-program"))
            removeVariable("TERMCANVAS_UNSET_BOUNDARY_VARIABLE")
            @Expect(runner.environment("TERMCANVAS_UNSET_BOUNDARY_VARIABLE"), "")
            setVariable("TMPDIR", "/termcanvas-nonexistent-temporary-directory")
            let result = runner.run("/bin/sh", ["-c", "exit 0"], Some(""), 1000, 8)
            match (result.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
            @Expect(!result.message.isEmpty())
        } finally {
            boundaryRestoreEnvironment("PATH", priorPath)
            boundaryRestoreEnvironment("TMPDIR", priorTemp)
            boundaryRestoreEnvironment("TERMCANVAS_UNSET_BOUNDARY_VARIABLE", priorMissing)
        }
    }

    @TestCase
    func nativeReadReportsExecFailureSignalAndIndependentStderrLimit(): Unit {
        let missing = clipboardReadCommand("/termcanvas-no-such-command", [], 1000, 16)
        match (missing.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
        @Expect(missing.message.contains("startup"))
        let signaled = clipboardReadCommand("/bin/sh", ["-c", "kill -KILL $$"], 1000, 16)
        match (signaled.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
        @Expect(signaled.message.contains("signal 9"))
        // stderr must be drained, but it is still bounded independently of
        // the clipboard's stdout allowance. This command has no stdout.
        let limit = clipboardReadCommand("/bin/sh", ["-c", "head -c 16777217 /dev/zero >&2"], 60000, 0)
        match (limit.status) { case ClipboardStatus.TooLarge => (); case _ => @Expect(false) }
        @Expect(limit.message, "Clipboard process output exceeds byte limit")
    }
}

@When[os == "Linux"]
@Test
class ClipboardDrainBoundaryTest {
    @TestCase
    func escapedQuietWriterReportsIncompleteDrainAndIsExplicitlyCleaned(): Unit {
        let file = File.createTemp(getTempDirectory())
        let path = file.info.path
        file.close()
        let script = "import os,time,sys\nr,w=os.pipe()\npid=os.fork()\nif pid==0:\n os.close(r)\n os.setsid()\n open(sys.argv[1],'w').write(str(os.getpid()))\n os.write(w,b'x')\n os.close(w)\n time.sleep(3)\nelse:\n os.close(w)\n os.read(r,1)\n os.close(r)\n"
        try {
            let result = clipboardReadCommand("/usr/bin/python3", ["-c", script, path.toString()], 2000, 16)
            match (result.status) { case ClipboardStatus.Failed => (); case _ => @Expect(false) }
            @Expect(result.message, "Clipboard output could not be completely collected")
        } finally {
            let text = String.fromUtf8(File.readFrom(path))
            if (!text.isEmpty()) { unsafe { _ = kill(-Int32(Int64.parse(text)), SIGKILL) } }
            _ = removeIfExists(path)
        }
    }
}

@When[os == "Linux"]
@Test
class ProcessFdBoundaryTest {
    @TestCase
    func nativePipeCreationFailureReleasesEveryPartialPipe(): Unit {
        if (getVariable("TERMCANVAS_FD_FAILURE_CHILD") != Some("1")) {
            // Isolate descriptor exhaustion from the test runner and its
            // runtime threads. The child restores every descriptor it opens.
            let script = "import os,resource,sys\n_,hard=resource.getrlimit(resource.RLIMIT_NOFILE)\nresource.setrlimit(resource.RLIMIT_NOFILE,(min(128,hard) if hard>=0 else 128,hard))\nos.environ['TERMCANVAS_FD_FAILURE_CHILD']='1'\nos.execv(sys.argv[1],[sys.argv[1],'--filter=ProcessFdBoundaryTest.nativePipeCreationFailureReleasesEveryPartialPipe'])\n"
            let child = launch("/usr/bin/python3", ["-c", script, canonicalize("/proc/self/exe").toString()],
                stdOut: ProcessRedirect.Discard, stdErr: ProcessRedirect.Discard)
            var reaped = false
            try {
                let code = child.wait(timeout: Duration.second * 15)
                reaped = true
                @Expect(code, 0)
            } finally {
                if (!reaped) {
                    try { child.terminate(force: true) } catch (_) { () }
                    try { _ = child.wait(timeout: Duration.second) } catch (_) { () }
                }
            }
            return
        }
        let baseline = auditOpenFdCount()
        let path = unsafe { LibC.mallocCString("/dev/null") }
        try {
            for (released in [0, 2, 4, 6]) {
                let runtime = PosixProcessRuntime()
                let held = ArrayList<Int32>()
                try {
                    while (true) {
                        let fd = unsafe { open(path, 0) }
                        if (fd < 0) { break }
                        held.add(fd)
                    }
                    @Assert(held.size > released)
                    for (_ in 0..released) {
                        let index = held.size - 1
                        unsafe { _ = close(held[index]) }
                        held.remove(at: index)
                    }
                    match (runtime.start("no-fds", ProcessSpec("/bin/sh"))) {
                        case Event.ProcessFailed(_, message) => @Expect(message, "process pipe creation failed")
                        case _ => @Expect(false)
                    }
                    @Expect(runtime.activeCount(), 0)
                } finally {
                    for (fd in held) { unsafe { _ = close(fd) } }
                    runtime.closeAll()
                }
                @Expect(auditOpenFdCount(), baseline)
            }
        } finally { unsafe { LibC.free(path) } }
    }
}
