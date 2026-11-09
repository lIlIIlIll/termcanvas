package core

import std.collection.*
import std.env.*
import std.fs.*
import std.io.*
import std.process.*
import std.time.*

/** 剪贴板操作状态。 */
public enum ClipboardStatus {
    /** 操作成功。 */
    | Success
    /** 所需剪贴板后端不可用。 */
    | Unavailable
    /** 操作不受支持。 */
    | Unsupported
    /** 操作超时。 */
    | Timeout
    /** 内容超过大小限制。 */
    | TooLarge
    /** 操作失败。 */
    | Failed
}

/** 剪贴板操作的状态、文本和诊断信息。 */
public class ClipboardResult {
    /** 操作状态。 */
    public let status: ClipboardStatus
    /** 读取到的文本。 */
    public let text: String
    /** 附加诊断信息。 */
    public let message: String
    /** 使用的后端标识。 */
    public let backend: String

    /** 创建剪贴板结果。
     * @param status 操作状态
     * @param text 读取文本
     * @param message 诊断信息
     * @param backend 后端标识
     */
    public init(status: ClipboardStatus, text!: String = "", message!: String = "", backend!: String = "") {
        this.status = status
        this.text = text
        this.message = message
        this.backend = backend
    }

    /** 判断操作是否成功。
     * @return 状态为 Success 时为 true
     */
    public func isSuccess(): Bool {
        match (status) { case ClipboardStatus.Success => true; case _ => false }
    }
}

/** 剪贴板后端支持的读写能力。 */
public class ClipboardCapabilities {
    /** 是否支持读取。 */
    public let canRead: Bool
    /** 是否支持写入。 */
    public let canWrite: Bool
    /** 后端标识。 */
    public let backend: String
    /** 后端说明。 */
    public let description: String

    /** 创建能力说明。
     * @param canRead 是否支持读取
     * @param canWrite 是否支持写入
     * @param backend 后端标识
     * @param description 后端说明
     */
    public init(canRead: Bool, canWrite: Bool, backend: String, description!: String = "") {
        this.canRead = canRead
        this.canWrite = canWrite
        this.backend = backend
        this.description = description
    }
}

/** 提供文本剪贴板读写及结构化结果的接口。 */
public interface Clipboard {
    /** 读取剪贴板文本。
     * @return 剪贴板文本
     */
    func getText(): String
    /** 写入剪贴板文本。
     * @param text 要写入的文本
     */
    func setText(text: String): Unit
    /** 获取后端能力；默认声明可读可写。
     * @return 能力说明
     */
    func capabilities(): ClipboardCapabilities { ClipboardCapabilities(true, true, "custom") }
    /** 读取文本并转换异常为失败结果。
     * @return 读取结果
     */
    func readText(): ClipboardResult {
        try { ClipboardResult(ClipboardStatus.Success, text: getText(), backend: capabilities().backend) }
        catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: capabilities().backend) }
    }
    /** 写入文本并转换异常为失败结果。
     * @param text 要写入的文本
     * @return 写入结果
     */
    func writeText(text: String): ClipboardResult {
        try {
            setText(text)
            ClipboardResult(ClipboardStatus.Success, backend: capabilities().backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: capabilities().backend) }
    }
}

/** 只在内存中保存文本的剪贴板实现。 */
public class MemoryClipboard <: Clipboard {
    private var textValue: String
    /** 创建内存剪贴板。
     * @param text 初始文本
     */
    public init(text!: String = "") { textValue = text }
    /** 获取当前内存文本。
     * @return 剪贴板文本
     */
    public func getText(): String { textValue }
    /** 替换内存文本。
     * @param text 要保存的文本
     */
    public func setText(text: String): Unit { textValue = text }
    /** 获取内存剪贴板的读写能力。
     * @return 能力说明
     */
    public func capabilities(): ClipboardCapabilities { ClipboardCapabilities(true, true, "memory") }
}

/** 剪贴板后端命令的执行结果。 */
public class ClipboardCommandResult {
    /** 执行状态。 */
    public let status: ClipboardStatus
    /** 命令输出文本。 */
    public let output: String
    /** 进程退出码；不可用时默认为 -1。 */
    public let exitCode: Int64
    /** 诊断信息。 */
    public let message: String

    /** 创建命令结果。
     * @param status 执行状态
     * @param output 输出文本
     * @param exitCode 退出码
     * @param message 诊断信息
     */
    public init(status: ClipboardStatus, output!: String = "", exitCode!: Int64 = -1, message!: String = "") {
        this.status = status
        this.output = output
        this.exitCode = exitCode
        this.message = message
    }
}

// No shell interpolation: clipboard contents are delivered only on stdin.
/** 用于探测和执行剪贴板命令的可替换接口。 */
public interface ClipboardCommandRunner {
    /** 获取平台标识。
     * @return 平台标识
     */
    func platform(): String
    /** 读取环境变量；未设置时可返回空字符串。
     * @param name 环境变量名
     * @return 环境变量值
     */
    func environment(name: String): String
    /** 判断命令是否可用。
     * @param command 命令名称或路径
     * @return 可用时为 true
     */
    func available(command: String): Bool
    /** 执行剪贴板命令。
     * @param command 命令名称或路径
     * @param arguments 参数数组
     * @param input 可选标准输入文本
     * @param timeoutMillis 超时毫秒数
     * @param maxBytes 输入输出字节上限
     * @return 命令结果
     */
    func run(command: String, arguments: Array<String>, input: ?String, timeoutMillis: Int64, maxBytes: Int64): ClipboardCommandResult
}

/** 通过本机环境和进程执行剪贴板命令。 */
public class NativeClipboardCommandRunner <: ClipboardCommandRunner {
    /** 创建本机命令执行器。 */
    public init() {}
    /** 获取本机平台标识。
     * @return windows、macos 或 linux
     */
    public func platform(): String { clipboardPlatform() }
    /** 读取环境变量；未设置时返回空字符串。
     * @param name 环境变量名
     * @return 环境变量值
     */
    public func environment(name: String): String {
        match (getVariable(name)) { case Some(value) => value; case None => "" }
    }
    /** 检查命令路径或 PATH 中的可执行文件。
     * @param command 命令名称或路径
     * @return 存在可执行文件时为 true
     */
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

    /** 不经 shell 执行命令；输入通过标准输入提供，超时和大小限制有界。
     * @param command 命令名称或路径
     * @param arguments 参数数组
     * @param input 可选标准输入文本
     * @param timeoutMillis 超时毫秒数，限制为 1 到 60000
     * @param maxBytes 输入输出字节上限，限制为 0 到 16 MiB
     * @return 命令结果
     */
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

/** 根据平台、会话环境和可执行程序探测系统剪贴板后端。 */
public class SystemClipboard <: Clipboard {
    private let runner: ClipboardCommandRunner
    private let timeoutMillis: Int64
    private let maxBytes: Int64
    private var backend: String = "unavailable"
    private var readCommand: String = ""
    private var writeCommand: String = ""
    private var readArguments: Array<String> = []
    private var writeArguments: Array<String> = []

    /** 创建并探测系统剪贴板。
     * @param runner 命令执行器
     * @param timeoutMillis 操作超时毫秒数，限制为 1 到 60000
     * @param maxBytes 文本字节上限，限制为 0 到 16 MiB
     */
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

    /** 获取探测到的读写能力；实际操作仍可能失败。
     * @return 后端能力
     */
    public func capabilities(): ClipboardCapabilities {
        ClipboardCapabilities(!readCommand.isEmpty(), !writeCommand.isEmpty(), backend,
            description: "Detected executable and display session; operations report connection, timeout and exit failures")
    }
    /** 读取系统剪贴板并返回结构化状态。
     * @return 读取结果
     */
    public func readText(): ClipboardResult {
        if (readCommand.isEmpty()) { return ClipboardResult(ClipboardStatus.Unavailable, message: "No system clipboard reader is available", backend: backend) }
        try {
            let result = runner.run(readCommand, readArguments, None, timeoutMillis, maxBytes)
            if (result.output.size > maxBytes) { return ClipboardResult(ClipboardStatus.TooLarge, message: "Clipboard output exceeds byte limit", backend: backend) }
            ClipboardResult(result.status, text: if (clipboardStatusSuccess(result.status)) { result.output } else { "" }, message: result.message, backend: backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: backend) }
    }
    /** 写入系统剪贴板并返回结构化状态。
     * @param text 要写入的文本
     * @return 写入结果
     */
    public func writeText(text: String): ClipboardResult {
        if (text.size > maxBytes) { return ClipboardResult(ClipboardStatus.TooLarge, message: "Clipboard input exceeds byte limit", backend: backend) }
        if (writeCommand.isEmpty()) { return ClipboardResult(ClipboardStatus.Unavailable, message: "No system clipboard writer is available", backend: backend) }
        try {
            let result = runner.run(writeCommand, writeArguments, Some(text), timeoutMillis, maxBytes)
            ClipboardResult(result.status, message: result.message, backend: backend)
        } catch (error: Exception) { ClipboardResult(ClipboardStatus.Failed, message: error.message, backend: backend) }
    }
    /** 读取文本；操作不成功时抛出异常。
     * @return 读取的文本
     */
    public func getText(): String { clipboardRequire(readText()).text }
    /** 写入文本；操作不成功时抛出异常。
     * @param text 要写入的文本
     */
    public func setText(text: String): Unit { _ = clipboardRequire(writeText(text)) }
}

/** 通过回调发送 OSC 52 序列的只写剪贴板。 */
public class Osc52Clipboard <: Clipboard {
    private let emit: (String) -> Unit
    private let enabled: Bool
    private let maxBytes: Int64
    private let tmuxPassthrough: Bool

    /** 创建 OSC 52 剪贴板。
     * @param emit 发送终端序列的回调
     * @param enabled 是否允许写入
     * @param maxBytes 文本字节上限，限制为 0 到 16 MiB
     * @param tmuxPassthrough 是否使用 tmux 透传包装
     */
    public init(emit: (String) -> Unit, enabled!: Bool = true, maxBytes!: Int64 = 100000, tmuxPassthrough!: Bool = false) {
        this.emit = emit
        this.enabled = enabled
        this.maxBytes = clamp(maxBytes, 0, 16 * 1024 * 1024)
        this.tmuxPassthrough = tmuxPassthrough
    }
    /** 获取只写能力。
     * @return 后端能力
     */
    public func capabilities(): ClipboardCapabilities {
        ClipboardCapabilities(false, enabled, "osc52", description: "Write-only; success means sequence emitted, not acknowledged by the remote terminal")
    }
    /** 报告不支持读取；终端粘贴应通过输入事件接收。
     * @return Unsupported 结果
     */
    public func readText(): ClipboardResult {
        ClipboardResult(ClipboardStatus.Unsupported, message: "OSC 52 reading is not supported; paste through terminal input", backend: "osc52")
    }
    /** 编码文本并调用发送回调；成功仅表示序列已发送，不代表终端确认。
     * @param text 要写入的文本
     * @return 写入结果
     */
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
    /** 读取操作不受支持，会抛出异常。
     * @return 不会正常返回
     */
    public func getText(): String { clipboardRequire(readText()).text }
    /** 发送文本；操作不成功时抛出异常。
     * @param text 要写入的文本
     */
    public func setText(text: String): Unit { _ = clipboardRequire(writeText(text)) }
}

/** 根据系统后端、远程会话及可选 OSC 52 回调选择剪贴板。
 * @param runner 命令执行器
 * @param osc52Emitter 可选的 OSC 52 序列发送回调
 * @param timeoutMillis 系统后端操作超时
 * @param maxBytes 文本字节上限
 * @return 所选剪贴板；系统后端不可用且未提供回调时返回不可用的系统后端
 */
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
