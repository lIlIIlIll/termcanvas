package core

import std.collection.*
import std.env.*
import std.fs.*
import std.io.*
import std.process.*
import std.time.*

public enum ClipboardStatus {
    | Success
    | Unavailable
    | Unsupported
    | Timeout
    | TooLarge
    | Failed
}

public class ClipboardResult {
    public let status: ClipboardStatus
    public let text: String
    public let message: String
    public let backend: String

    public init(status: ClipboardStatus, text!: String = "", message!: String = "", backend!: String = "") {
        this.status = status
        this.text = text
        this.message = message
        this.backend = backend
    }

    public func isSuccess(): Bool {
        match (status) { case ClipboardStatus.Success => true; case _ => false }
    }
}

public class ClipboardCapabilities {
    public let canRead: Bool
    public let canWrite: Bool
    public let backend: String
    public let description: String

    public init(canRead: Bool, canWrite: Bool, backend: String, description!: String = "") {
        this.canRead = canRead
        this.canWrite = canWrite
        this.backend = backend
        this.description = description
    }
}

public interface Clipboard {
    func getText(): String
    func setText(text: String): Unit
    func capabilities(): ClipboardCapabilities { ClipboardCapabilities(true, true, "custom") }
    func readText(): ClipboardResult {
        try { ClipboardResult(ClipboardStatus.Success, text: getText(), backend: capabilities().backend) }
        catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: capabilities().backend) }
    }
    func writeText(text: String): ClipboardResult {
        try {
            setText(text)
            ClipboardResult(ClipboardStatus.Success, backend: capabilities().backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: capabilities().backend) }
    }
}

public class MemoryClipboard <: Clipboard {
    private var textValue: String
    public init(text!: String = "") { textValue = text }
    public func getText(): String { textValue }
    public func setText(text: String): Unit { textValue = text }
    public func capabilities(): ClipboardCapabilities { ClipboardCapabilities(true, true, "memory") }
}

public class ClipboardCommandResult {
    public let status: ClipboardStatus
    public let output: String
    public let exitCode: Int64
    public let message: String

    public init(status: ClipboardStatus, output!: String = "", exitCode!: Int64 = -1, message!: String = "") {
        this.status = status
        this.output = output
        this.exitCode = exitCode
        this.message = message
    }
}

// No shell interpolation: clipboard contents are delivered only on stdin.
public interface ClipboardCommandRunner {
    func platform(): String
    func environment(name: String): String
    func available(command: String): Bool
    func run(command: String, arguments: Array<String>, input: ?String, timeoutMillis: Int64, maxBytes: Int64): ClipboardCommandResult
}

public class NativeClipboardCommandRunner <: ClipboardCommandRunner {
    public init() {}
    public func platform(): String { clipboardPlatform() }
    public func environment(name: String): String {
        match (getVariable(name)) { case Some(value) => value; case None => "" }
    }
    public func available(command: String): Bool {
        if (command.contains("/") || command.contains("\\")) { return clipboardExecutable(command) }
        let separator = if (platform() == "windows") { ";" } else { ":" }
        for (directory in environment("PATH").split(separator)) {
            // Empty PATH entries mean cwd. Probe exactly the same candidate
            // that process launch resolves; failures are still reported by run.
            let path = if (directory.isEmpty()) { command } else { directory + "/" + command }
            if (clipboardExecutable(path)) { return true }
        }
        false
    }

    public func run(command: String, arguments: Array<String>, input: ?String, timeoutMillis: Int64, maxBytes: Int64): ClipboardCommandResult {
        let limit = clamp(maxBytes, 0, 16 * 1024 * 1024)
        if (let Some(text) <- input) {
            if (text.size > limit) { return ClipboardCommandResult(ClipboardStatus.TooLarge, message: "Clipboard input exceeds byte limit") }
        }
        if (!available(command)) { return ClipboardCommandResult(ClipboardStatus.Unavailable, message: "Clipboard command is not executable: ${command}") }
        var inputFile: ?File = None
        try {
            let writing = input.isSome()
            let deadline = MonoTime.now() + Duration.millisecond * clamp(timeoutMillis, 1, 60000)
            if (let Some(text) <- input) {
                // SDK 1.1 exposes a non-closeable stdin wrapper. A private
                // temporary file supplies exact bytes and a real EOF.
                let file = File.createTemp(getTempDirectory())
                inputFile = Some(file)
                file.write(text.toArray())
                _ = file.seek(SeekPosition.Begin(0))
            }
            if (!writing) { return clipboardReadCommand(command, arguments, timeoutMillis, limit) }
            // Selection owners may outlive their launcher. Discard streams
            // preserve clipboard ownership without holding our pipes open.
            let process = launch(command, arguments,
                stdIn: match (inputFile) { case Some(file) => ProcessRedirect.FromFile(file); case None => ProcessRedirect.Discard },
                stdOut: ProcessRedirect.Discard, stdErr: ProcessRedirect.Discard)
            var reaped = false
            try {
                let code = process.wait(timeout: clipboardRemaining(deadline))
                reaped = true
                if (code == 0) { ClipboardCommandResult(ClipboardStatus.Success, exitCode: code) }
                else { ClipboardCommandResult(ClipboardStatus.Failed, exitCode: code, message: "Clipboard command exited with status ${code}") }
            } catch (_: TimeoutException) {
                ClipboardCommandResult(ClipboardStatus.Timeout, message: "Clipboard command timed out")
            } finally {
                if (!reaped) {
                    try { process.terminate(force: true) } catch (_) { () }
                    try { _ = process.wait(timeout: Duration.second) } catch (_) { () }
                }
            }
        } catch (error: Exception) { ClipboardCommandResult(ClipboardStatus.Failed, message: error.message) }
        finally {
            if (let Some(file) <- inputFile) {
                let path = file.info.path
                try { file.close() } catch (_) { () }
                try { _ = removeIfExists(path) } catch (_) { () }
            }
        }
    }
}

// POSIX reads use nonblocking, independently drained pipes. No blocked reader
// task survives an expired operation or a descendant retaining its stdout.
@When[os != "Windows"]
func clipboardReadCommand(command: String, arguments: Array<String>, timeoutMillis: Int64, limit: Int64): ClipboardCommandResult {
    let runtime = PosixProcessRuntime(maxProcesses: 1, readBudgetBytes: 4096, maxQueuedBytes: 8192)
    let bytes = ArrayList<Byte>()
    try {
        match (runtime.start("clipboard", ProcessSpec(command, args: arguments,
            timeoutMillis: clamp(timeoutMillis, 1, 60000), maxOutputBytes: 16 * 1024 * 1024 + limit))) {
            case Event.ProcessStarted(_) => ()
            case Event.ProcessFailed(_, message) => return ClipboardCommandResult(ClipboardStatus.Failed, message: message)
            case _ => return ClipboardCommandResult(ClipboardStatus.Failed, message: "Clipboard command did not start")
        }
        while (runtime.activeCount() > 0) {
            for (event in runtime.drain()) {
                match (event) {
                    case Event.ProcessOutput(_, ProcessOutputStream.Stdout, chunk) =>
                        if (chunk.size > limit - bytes.size) {
                            return ClipboardCommandResult(ClipboardStatus.TooLarge, message: "Clipboard output exceeds byte limit")
                        }
                        for (byte in chunk) { bytes.add(byte) }
                    case Event.ProcessFinished(_, result) =>
                        match (result.reason) {
                            case ProcessEndReason.TimedOut => return ClipboardCommandResult(ClipboardStatus.Timeout, message: "Clipboard command timed out")
                            case ProcessEndReason.OutputLimit => return ClipboardCommandResult(ClipboardStatus.TooLarge, message: "Clipboard process output exceeds byte limit")
                            case ProcessEndReason.Exited =>
                                match (result.status) {
                                    case PtyExitStatus.Exited(0) => return ClipboardCommandResult(ClipboardStatus.Success, output: String.fromUtf8(bytes.toArray()), exitCode: 0)
                                    case PtyExitStatus.Exited(code) => return ClipboardCommandResult(ClipboardStatus.Failed, exitCode: code, message: "Clipboard command exited with status ${code}")
                                    case PtyExitStatus.Signaled(signal) => return ClipboardCommandResult(ClipboardStatus.Failed, message: "Clipboard command terminated by signal ${signal}")
                                }
                            case _ => return ClipboardCommandResult(ClipboardStatus.Failed, message: "Clipboard output could not be completely collected")
                        }
                    case _ => () // stderr is drained with the same bounded queue.
                }
            }
            if (runtime.activeCount() > 0) { sleep(Duration.millisecond) }
        }
        ClipboardCommandResult(ClipboardStatus.Failed, message: "Clipboard command produced no completion event")
    } finally { runtime.closeAll() }
}

@When[os == "Windows"]
func clipboardReadCommand(command: String, arguments: Array<String>, timeoutMillis: Int64, limit: Int64): ClipboardCommandResult {
    let deadline = MonoTime.now() + Duration.millisecond * clamp(timeoutMillis, 1, 60000)
    let process = launch(command, arguments, stdIn: ProcessRedirect.Discard,
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Discard)
    let transfer: Future<ClipboardCommandResult> = spawn {
        try {
            let bytes = ArrayList<Byte>()
            let chunk = Array<Byte>(4096, repeat: 0)
            while (true) {
                let count = process.stdOutPipe.read(chunk)
                if (count <= 0) { break }
                if (count > limit - bytes.size) {
                    try { process.terminate(force: true) } catch (_) { () }
                    return ClipboardCommandResult(ClipboardStatus.TooLarge, message: "Clipboard output exceeds byte limit")
                }
                for (i in 0..count) { bytes.add(chunk[i]) }
            }
            ClipboardCommandResult(ClipboardStatus.Success, output: String.fromUtf8(bytes.toArray()))
        } catch (error: Exception) { ClipboardCommandResult(ClipboardStatus.Failed, message: error.message) }
    }
    var reaped = false
    try {
        let transferred = transfer.get(clipboardRemaining(deadline))
        if (!clipboardStatusSuccess(transferred.status)) { return transferred }
        let code = process.wait(timeout: clipboardRemaining(deadline))
        reaped = true
        if (code == 0) { ClipboardCommandResult(ClipboardStatus.Success, output: transferred.output, exitCode: code) }
        else { ClipboardCommandResult(ClipboardStatus.Failed, exitCode: code, message: "Clipboard command exited with status ${code}") }
    } catch (_: TimeoutException) {
        ClipboardCommandResult(ClipboardStatus.Timeout, message: "Clipboard command timed out")
    } finally {
        if (!reaped) {
            try { process.terminate(force: true) } catch (_) { () }
            try { _ = process.wait(timeout: Duration.second) } catch (_) { () }
        }
        try { _ = transfer.get(Duration.second) } catch (_) { () }
    }
}

func clipboardExecutable(path: String): Bool {
    try { let info = FileInfo(canonicalize(path)); info.isRegular() && info.canExecute() } catch (_) { false }
}

func clipboardRemaining(deadline: MonoTime): Duration {
    let now = MonoTime.now()
    if (now >= deadline) { throw TimeoutException("Clipboard deadline exceeded") }
    deadline - now
}

func clipboardStatusSuccess(status: ClipboardStatus): Bool {
    match (status) { case ClipboardStatus.Success => true; case _ => false }
}

@When[os == "Windows"]
func clipboardPlatform(): String { "windows" }
@When[os == "macOS"]
func clipboardPlatform(): String { "macos" }
@When[os != "Windows" && os != "macOS"]
func clipboardPlatform(): String { "linux" }

public class SystemClipboard <: Clipboard {
    private let runner: ClipboardCommandRunner
    private let timeoutMillis: Int64
    private let maxBytes: Int64
    private var backend: String = "unavailable"
    private var readCommand: String = ""
    private var writeCommand: String = ""
    private var readArguments: Array<String> = []
    private var writeArguments: Array<String> = []

    public init(runner!: ClipboardCommandRunner = NativeClipboardCommandRunner(), timeoutMillis!: Int64 = 2000, maxBytes!: Int64 = 1024 * 1024) {
        this.runner = runner
        this.timeoutMillis = clamp(timeoutMillis, 1, 60000)
        this.maxBytes = clamp(maxBytes, 0, 16 * 1024 * 1024)
        probe()
    }

    private func probe(): Unit {
        if (runner.platform() == "windows") {
            let command = if (runner.available("pwsh.exe")) { "pwsh.exe" } else { "powershell.exe" }
            if (runner.available(command)) {
                backend = "windows"
                readCommand = command
                writeCommand = command
                readArguments = ["-NoProfile", "-NonInteractive", "-Command", "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); [Console]::Write([string](Get-Clipboard -Raw))"]
                writeArguments = ["-NoProfile", "-NonInteractive", "-Command", "[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false); Set-Clipboard -Value ([Console]::In.ReadToEnd())"]
            }
        } else if (runner.platform() == "macos") {
            if (runner.available("pbcopy")) { writeCommand = "pbcopy" }
            if (runner.available("pbpaste")) { readCommand = "pbpaste" }
            if (!writeCommand.isEmpty() || !readCommand.isEmpty()) { backend = "macos" }
        } else if (!runner.environment("WAYLAND_DISPLAY").isEmpty() && (runner.available("wl-copy") || runner.available("wl-paste"))) {
            backend = "wayland"
            if (runner.available("wl-copy")) { writeCommand = "wl-copy"; writeArguments = ["--type", "text/plain;charset=utf-8"] }
            if (runner.available("wl-paste")) { readCommand = "wl-paste"; readArguments = ["--no-newline"] }
        } else if (!runner.environment("DISPLAY").isEmpty()) {
            if (runner.available("xclip")) {
                backend = "xclip"
                writeCommand = "xclip"; writeArguments = ["-selection", "clipboard", "-in"]
                readCommand = "xclip"; readArguments = ["-selection", "clipboard", "-out"]
            } else if (runner.available("xsel")) {
                backend = "xsel"
                writeCommand = "xsel"; writeArguments = ["--clipboard", "--input"]
                readCommand = "xsel"; readArguments = ["--clipboard", "--output"]
            }
        }
    }

    public func capabilities(): ClipboardCapabilities {
        ClipboardCapabilities(!readCommand.isEmpty(), !writeCommand.isEmpty(), backend,
            description: "Detected executable and display session; operations report connection, timeout and exit failures")
    }
    public func readText(): ClipboardResult {
        if (readCommand.isEmpty()) { return ClipboardResult(ClipboardStatus.Unavailable, message: "No system clipboard reader is available", backend: backend) }
        try {
            let result = runner.run(readCommand, readArguments, None, timeoutMillis, maxBytes)
            if (result.output.size > maxBytes) { return ClipboardResult(ClipboardStatus.TooLarge, message: "Clipboard output exceeds byte limit", backend: backend) }
            ClipboardResult(result.status, text: if (clipboardStatusSuccess(result.status)) { result.output } else { "" }, message: result.message, backend: backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: backend) }
    }
    public func writeText(text: String): ClipboardResult {
        if (text.size > maxBytes) { return ClipboardResult(ClipboardStatus.TooLarge, message: "Clipboard input exceeds byte limit", backend: backend) }
        if (writeCommand.isEmpty()) { return ClipboardResult(ClipboardStatus.Unavailable, message: "No system clipboard writer is available", backend: backend) }
        try {
            let result = runner.run(writeCommand, writeArguments, Some(text), timeoutMillis, maxBytes)
            ClipboardResult(result.status, message: result.message, backend: backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: backend) }
    }
    public func getText(): String { clipboardRequire(readText()).text }
    public func setText(text: String): Unit { _ = clipboardRequire(writeText(text)) }
}

public class Osc52Clipboard <: Clipboard {
    private let emit: (String) -> Unit
    private let enabled: Bool
    private let maxBytes: Int64
    private let tmuxPassthrough: Bool

    public init(emit: (String) -> Unit, enabled!: Bool = true, maxBytes!: Int64 = 100000, tmuxPassthrough!: Bool = false) {
        this.emit = emit
        this.enabled = enabled
        this.maxBytes = clamp(maxBytes, 0, 16 * 1024 * 1024)
        this.tmuxPassthrough = tmuxPassthrough
    }
    public func capabilities(): ClipboardCapabilities {
        ClipboardCapabilities(false, enabled, "osc52", description: "Write-only; success means sequence emitted, not acknowledged by the remote terminal")
    }
    public func readText(): ClipboardResult {
        ClipboardResult(ClipboardStatus.Unsupported, message: "OSC 52 reading is not supported; paste through terminal input", backend: "osc52")
    }
    public func writeText(text: String): ClipboardResult {
        if (!enabled) { return ClipboardResult(ClipboardStatus.Unavailable, message: "OSC 52 is disabled", backend: "osc52") }
        if (text.size > maxBytes) { return ClipboardResult(ClipboardStatus.TooLarge, message: "OSC 52 payload exceeds byte limit", backend: "osc52") }
        let sequence = "\u{1B}]52;c;" + clipboardBase64(text.toArray()) + "\u{7}"
        let output = if (tmuxPassthrough) { "\u{1B}Ptmux;\u{1B}" + sequence + "\u{1B}\\" } else { sequence }
        try {
            emit(output)
            ClipboardResult(ClipboardStatus.Success, message: "OSC 52 sequence emitted; terminal acknowledgement is unavailable", backend: "osc52")
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: "osc52") }
    }
    public func getText(): String { clipboardRequire(readText()).text }
    public func setText(text: String): Unit { _ = clipboardRequire(writeText(text)) }
}

public func detectClipboard(
    runner!: ClipboardCommandRunner = NativeClipboardCommandRunner(),
    osc52Emitter!: ?(String) -> Unit = None,
    timeoutMillis!: Int64 = 2000,
    maxBytes!: Int64 = 1024 * 1024
): Clipboard {
    if (let Some(emit) <- osc52Emitter) {
        if (!runner.environment("SSH_CONNECTION").isEmpty() || !runner.environment("SSH_TTY").isEmpty()) {
            return Osc52Clipboard(emit, maxBytes: min(maxBytes, 100000), tmuxPassthrough: !runner.environment("TMUX").isEmpty())
        }
    }
    let native = SystemClipboard(runner: runner, timeoutMillis: timeoutMillis, maxBytes: maxBytes)
    if (!native.capabilities().canWrite) {
        if (let Some(emit) <- osc52Emitter) { return Osc52Clipboard(emit, maxBytes: min(maxBytes, 100000)) }
    }
    native
}

func clipboardRequire(result: ClipboardResult): ClipboardResult {
    if (!result.isSuccess()) { throw Exception(result.message) }
    result
}

func clipboardBase64(bytes: Array<Byte>): String {
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let out = Array<Byte>((bytes.size + 2) / 3 * 4, repeat: b'=')
    var input: Int64 = 0
    var output: Int64 = 0
    while (input < bytes.size) {
        let b0 = UInt32(bytes[input])
        let b1 = if (input + 1 < bytes.size) { UInt32(bytes[input + 1]) } else { 0u32 }
        let b2 = if (input + 2 < bytes.size) { UInt32(bytes[input + 2]) } else { 0u32 }
        let bits = (b0 << 16) | (b1 << 8) | b2
        out[output] = alphabet[Int64((bits >> 18) & 63u32)]
        out[output + 1] = alphabet[Int64((bits >> 12) & 63u32)]
        if (input + 1 < bytes.size) { out[output + 2] = alphabet[Int64((bits >> 6) & 63u32)] }
        if (input + 2 < bytes.size) { out[output + 3] = alphabet[Int64(bits & 63u32)] }
        input += 3; output += 4
    }
    unsafe { String.fromUtf8Unchecked(out) }
}
