package core

import std.collection.*
import std.time.*

/** 子进程输出流。 */
public enum ProcessOutputStream {
    /** 标准输出。 */
    | Stdout
    /** 标准错误。 */
    | Stderr
}
/** 子进程结束原因。 */
public enum ProcessEndReason {
    /** 进程退出。 */
    | Exited
    /** 请求取消。 */
    | Cancelled
    /** 运行超时。 */
    | TimedOut
    /** 达到输出上限。 */
    | OutputLimit
    /** 等待输出排空超时。 */
    | DrainTimeout
}

// The child receives EOF on stdin. Interactive terminal applications use PTY.
/** 非交互管道进程的启动参数；子进程标准输入收到 EOF。
 */
public class ProcessSpec {
    /** 可执行命令。
     */
    public let command: String
    /** 参数快照。
     */
    public let args: Array<String>
    /** 工作目录；空字符串使用默认目录。
     */
    public let cwd: String
    /** 环境项快照。
     */
    public let env: Array<String>
    /** 运行超时毫秒数；零表示不设运行超时。
     */
    public let timeoutMillis: Int64
    /** 允许接收的输出字节上限。
     */
    public let maxOutputBytes: Int64
    /** 退出后等待输出排空的超时毫秒数。
     */
    public let drainTimeoutMillis: Int64
    /** 创建配置或结果。
     * @param command 可执行命令
     * @param args 参数数组
     * @param cwd 工作目录
     * @param env 环境项数组
     * @param timeoutMillis 运行超时毫秒数；零表示不设运行超时
     * @param maxOutputBytes 输出字节上限，不能为负
     * @param drainTimeoutMillis 排空超时毫秒数，必须大于零
     */
    public init(command: String, args!: Array<String> = [], cwd!: String = "", env!: Array<String> = [],
        timeoutMillis!: Int64 = 0, maxOutputBytes!: Int64 = 16 * 1024 * 1024, drainTimeoutMillis!: Int64 = 1000) {
        if (timeoutMillis < 0 || maxOutputBytes < 0 || drainTimeoutMillis <= 0) { throw IllegalArgumentException("process limits must be non-negative") }
        this.command = command
        this.args = snapshotStrings(args)
        this.cwd = cwd
        this.env = snapshotStrings(env)
        this.timeoutMillis = timeoutMillis
        this.maxOutputBytes = maxOutputBytes
        this.drainTimeoutMillis = drainTimeoutMillis
        if (command.contains("\u{0}") || cwd.contains("\u{0}")) { throw IllegalArgumentException("process paths cannot contain NUL") }
        for (value in args) { if (value.contains("\u{0}")) { throw IllegalArgumentException("process args cannot contain NUL") } }
        for (value in env) { if (value.contains("\u{0}")) { throw IllegalArgumentException("process env cannot contain NUL") } }
    }
}

/** 子进程结束结果。
 */
public struct ProcessResult {
    /** 结束原因。
     */
    public let reason: ProcessEndReason
    /** 进程退出状态。
     */
    public let status: PtyExitStatus
    /** 已接收的输出字节数。
     */
    public let outputBytes: Int64
    /** 输出是否完整排空。
     */
    public let outputComplete: Bool
    /** 创建配置或结果。
     * @param reason 结束原因
     * @param status 退出状态
     * @param outputBytes 输出字节数
     * @param outputComplete 输出是否完整
     */
    public init(reason: ProcessEndReason, status: PtyExitStatus, outputBytes: Int64, outputComplete!: Bool = true) {
        this.reason = reason; this.status = status; this.outputBytes = outputBytes; this.outputComplete = outputComplete
    }
}

/** 进程运行时的输出及背压统计。
 */
public struct ProcessMetrics {
    /** 当前排队输出字节数。
     */
    public let queuedBytes: Int64
    /** 排队输出字节数峰值。
     */
    public let peakQueuedBytes: Int64
    /** 累计输出字节数。
     */
    public let outputBytes: Int64
    /** 背压次数。
     */
    public let backpressureCount: Int64
    /** 创建配置或结果。
     * @param queuedBytes 当前排队字节数
     * @param peakQueuedBytes 排队字节数峰值
     * @param outputBytes 累计输出字节数
     * @param backpressureCount 背压次数
     */
    public init(queuedBytes!: Int64 = 0, peakQueuedBytes!: Int64 = 0, outputBytes!: Int64 = 0, backpressureCount!: Int64 = 0) {
        this.queuedBytes = queuedBytes; this.peakQueuedBytes = peakQueuedBytes
        this.outputBytes = outputBytes; this.backpressureCount = backpressureCount
    }
}

/** 管道子进程的启动、事件排空和资源管理接口。
 */
public interface ProcessRuntime {
    /** 启动进程。
     * @param id 进程标识
     * @param spec 进程配置
     * @return 启动成功或失败事件。
     */
    func start(id: String, spec: ProcessSpec): Event
    // Cancellation is acknowledged immediately. The one Finished event is
    // emitted later, after the child has been reaped and output accounted for.
    /** 请求取消进程；完成事件在回收及处理输出后产生。
     * @param id 进程标识
     * @return 取消请求或失败事件。
     */
    func cancel(id: String): Event
    /** 获取进程相关事件源。
     * @return 事件源数组。
     */
    func sources(): Array<EventSource>
    /** 推进进程并读取可交付事件。
     * @return 进程事件数组。
     */
    func drain(): Array<Event>
    /** 获取活动进程数。
     * @return 活动进程数。
     */
    func activeCount(): Int64
    /** 获取建议的下次等待时长。
     * @return 等待毫秒数；无需唤醒时为 None。
     */
    func nextTimeoutMillis(): ?Int64
    /** 获取输出与背压统计。
     * @return 统计快照。
     */
    func metrics(): ProcessMetrics
    /** 关闭并回收所有进程。
     */
    func closeAll(): Unit
}

public class UnsupportedProcessRuntime <: ProcessRuntime {
    public init() {}
    public func start(id: String, spec: ProcessSpec): Event { Event.ProcessFailed(id, "pipe processes are unavailable for " + spec.command) }
    public func cancel(id: String): Event { Event.ProcessFailed(id, "pipe process is unavailable") }
    public func sources(): Array<EventSource> { [] }
    public func drain(): Array<Event> { [] }
    public func activeCount(): Int64 { 0 }
    public func nextTimeoutMillis(): ?Int64 { None }
    public func metrics(): ProcessMetrics { ProcessMetrics() }
    public func closeAll(): Unit {}
}

@When[os != "Windows"]
public func defaultProcessRuntime(): ProcessRuntime { PosixProcessRuntime() }
@When[os == "Windows"]
public func defaultProcessRuntime(): ProcessRuntime { UnsupportedProcessRuntime() }

@When[os != "Windows"]
class ProcessReadBudget {
    let capacity: Int64
    var remaining: Int64
    init(quantum: Int64) { capacity = max(64 * 1024, min(64 * 1024, quantum) * 2); remaining = capacity }
    func reset(): Unit { remaining = capacity }
}

// Each source reads one quantum. A full per-process buffer stops reading and
// lets the kernel pipe apply lossless backpressure until drain() consumes it.
@When[os != "Windows"]
public class PosixProcessRuntime <: ProcessRuntime {
    private let processes = ArrayList<PipeProcess>()
    private let maxProcesses: Int64
    private let readBudgetBytes: Int64
    private let maxQueuedBytes: Int64
    private let turnBudget: ProcessReadBudget
    private var drainCursor: Int64 = 0
    private var sourceStderrFirst = false
    private var totalOutput: Int64 = 0
    private var totalBackpressure: Int64 = 0
    private var peakQueued: Int64 = 0
    public init(maxProcesses!: Int64 = 32, readBudgetBytes!: Int64 = 16 * 1024, maxQueuedBytes!: Int64 = 64 * 1024) {
        if (maxProcesses <= 0 || readBudgetBytes <= 0 || maxQueuedBytes <= 0) { throw IllegalArgumentException("process runtime budgets must be positive") }
        this.maxProcesses = maxProcesses; this.readBudgetBytes = readBudgetBytes; this.maxQueuedBytes = maxQueuedBytes
        turnBudget = ProcessReadBudget(readBudgetBytes)
    }
    public func start(id: String, spec: ProcessSpec): Event {
        for (process in processes) {
            if (process.processId == id) { return Event.ProcessFailed(id, "process id is already active") }
        }
        if (processes.size >= maxProcesses) { return Event.ProcessFailed(id, "process capacity exhausted") }
        if (spec.command.isEmpty()) { return Event.ProcessFailed(id, "process command is empty") }
        let input = Array<Int32>(2, repeat: -1)
        let output = Array<Int32>(2, repeat: -1)
        let errors = Array<Int32>(2, repeat: -1)
        let startup = Array<Int32>(2, repeat: -1)
        var child: Int32 = -1
        var transferred = false
        try {
            if (!makePtyPipe(input) || !makePtyPipe(output) || !makePtyPipe(errors) || !makePtyPipe(startup)) {
                return Event.ProcessFailed(id, "process pipe creation failed")
            }
            if (!configureFd(output[0]) || !configureFd(errors[0])) {
                return Event.ProcessFailed(id, "process pipe configuration failed")
            }
            let prepared = PreparedPtyCommand(PtySpec(spec.command, args: spec.args, cwd: spec.cwd, env: spec.env))
            try {
                child = prepared.startNative(input[0], output[1], errors[1], -1, startup[1],
                    [input[0], input[1], output[0], output[1], errors[0], errors[1], startup[0]])
                if (child < 0) { return Event.ProcessFailed(id, "process native spawn failed") }
            } finally { prepared.release() }
            unsafe {
                _ = close(input[0]); input[0] = -1
                _ = close(input[1]); input[1] = -1
                _ = close(output[1]); output[1] = -1
                _ = close(errors[1]); errors[1] = -1
                _ = close(startup[1]); startup[1] = -1
            }
            let failure = readPtyStartupError(startup[0])
            if (failure != 0) { return Event.ProcessFailed(id, "process startup failed at stage ${failure}") }
            processes.add(PipeProcess(id, child, output[0], errors[0], spec, readBudgetBytes, maxQueuedBytes, turnBudget))
            transferred = true
            Event.ProcessStarted(id)
        } finally {
            unsafe {
                for (fd in input) { if (fd >= 0) { _ = close(fd) } }
                for (fd in startup) { if (fd >= 0) { _ = close(fd) } }
                if (output[1] >= 0) { _ = close(output[1]) }
                if (errors[1] >= 0) { _ = close(errors[1]) }
                if (!transferred) {
                    if (output[0] >= 0) { _ = close(output[0]) }
                    if (errors[0] >= 0) { _ = close(errors[0]) }
                    if (child > 0) {
                        _ = kill(-child, SIGKILL); _ = kill(child, SIGKILL)
                        let status = LibC.malloc<Int32>()
                        var rc = waitpid(child, status, 0)
                        while (rc < 0 && ptyErrno() == 4) { rc = waitpid(child, status, 0) }
                        LibC.free(status)
                    }
                }
            }
        }
    }
    public func cancel(id: String): Event {
        for (process in processes) {
            if (process.processId == id) { process.requestStop(ProcessEndReason.Cancelled); return Event.ProcessCancelRequested(id) }
        }
        Event.ProcessFailed(id, "process not found")
    }
    public func sources(): Array<EventSource> {
        let out = ArrayList<EventSource>()
        for (offset in 0..processes.size) {
            let process = processes[(drainCursor + offset) % processes.size]
            if (sourceStderrFirst) {
                out.add(PipeOutputSource(process, ProcessOutputStream.Stderr))
                out.add(PipeOutputSource(process, ProcessOutputStream.Stdout))
            } else {
                out.add(PipeOutputSource(process, ProcessOutputStream.Stdout))
                out.add(PipeOutputSource(process, ProcessOutputStream.Stderr))
            }
        }
        out.toArray()
    }
    public func drain(): Array<Event> {
        let out = ArrayList<Event>()
        var index = if (processes.isEmpty()) { 0 } else { drainCursor % processes.size }
        var visits = processes.size
        while (visits > 0 && !processes.isEmpty()) {
            index %= processes.size
            visits--
            let process = processes[index]
            process.advance()
            // Polling drain also works without a platform waiter, e.g. tools
            // and fixtures. Both streams always get their own read quantum.
            process.readTurn()
            process.finishDraining()
            peakQueued = max(peakQueued, queuedBytes())
            for (event in process.takeEvents()) { out.add(event) }
            if (process.finished()) {
                out.add(Event.ProcessFinished(process.processId, process.result()))
                totalOutput += process.outputBytes
                totalBackpressure += process.backpressureCount
                process.closeDescriptors()
                processes.remove(at: index)
            } else { index++ }
        }
        if (!processes.isEmpty()) { drainCursor = (drainCursor + 1) % processes.size }
        else { drainCursor = 0 }
        sourceStderrFirst = !sourceStderrFirst
        turnBudget.reset()
        out.toArray()
    }
    private func queuedBytes(): Int64 {
        var value: Int64 = 0
        for (process in processes) { value += process.queuedBytes }
        value
    }
    public func activeCount(): Int64 { processes.size }
    public func nextTimeoutMillis(): ?Int64 {
        // waitpid has no portable waitable fd. This bounded poll also services
        // cancellation escalation and deadlines when both pipes are quiet.
        if (processes.isEmpty()) { return None }
        var next: Int64 = 10
        for (process in processes) { next = min(next, process.nextWakeMillis()) }
        Some(next)
    }
    public func metrics(): ProcessMetrics {
        var output = totalOutput
        var blocked = totalBackpressure
        var peak = peakQueued
        for (process in processes) { output += process.outputBytes; blocked += process.backpressureCount; peak = max(peak, process.peakQueuedBytes) }
        ProcessMetrics(queuedBytes: queuedBytes(), peakQueuedBytes: max(peak, queuedBytes()), outputBytes: output, backpressureCount: blocked)
    }
    public func closeAll(): Unit {
        for (process in processes) { process.requestStop(ProcessEndReason.Cancelled) }
        // Shutdown owns children. Bound the grace period, then reap even when
        // the application no longer consumes output. No detached child task.
        let deadline = MonoTime.now() + Duration.millisecond * 100
        while (!processes.isEmpty() && MonoTime.now() < deadline) {
            _ = drain()
            if (!processes.isEmpty()) { sleep(Duration.millisecond) }
        }
        for (process in processes) {
            process.forceClose()
            totalOutput += process.outputBytes
            totalBackpressure += process.backpressureCount
        }
        processes.clear()
    }
}

@When[os != "Windows"]
class PipeProcess {
    let processId: String
    private let pid: Int32
    private var stdoutFd: Int32
    private var stderrFd: Int32
    private let spec: ProcessSpec
    private let readBudget: Int64
    private let maxQueued: Int64
    private let turnBudget: ProcessReadBudget
    private let events = ArrayList<Event>()
    private let started = MonoTime.now()
    private var stopAt: ?MonoTime = None
    private var reason = ProcessEndReason.Exited
    private var status: ?PtyExitStatus = None
    private var exitObserved: ?MonoTime = None
    private var stderrFirst: Bool = false
    private var lastReadAt = MonoTime.now()
    private var outputComplete: Bool = true
    var queuedBytes: Int64 = 0
    var peakQueuedBytes: Int64 = 0
    var outputBytes: Int64 = 0
    var backpressureCount: Int64 = 0
    init(id: String, pid: Int32, stdout: Int32, stderr: Int32, spec: ProcessSpec, budget: Int64, maxQueued: Int64, turnBudget: ProcessReadBudget) {
        processId = id; this.pid = pid; stdoutFd = stdout; stderrFd = stderr
        this.spec = spec; readBudget = min(budget, max(1, maxQueued / 2)); this.maxQueued = maxQueued
        this.turnBudget = turnBudget
    }
    func sourceFd(stream: ProcessOutputStream): ?Int32 {
        if (queuedBytes >= maxQueued || turnBudget.remaining <= 0) { return None }
        let fd = streamFd(stream)
        if (fd < 0) { None } else { Some(fd) }
    }
    private func streamFd(stream: ProcessOutputStream): Int32 {
        match (stream) { case ProcessOutputStream.Stdout => stdoutFd; case ProcessOutputStream.Stderr => stderrFd }
    }
    private func closeStream(stream: ProcessOutputStream): Unit {
        let fd = streamFd(stream)
        if (fd >= 0) { unsafe { _ = close(fd) } }
        match (stream) { case ProcessOutputStream.Stdout => stdoutFd = -1; case ProcessOutputStream.Stderr => stderrFd = -1 }
    }
    func requestStop(why: ProcessEndReason): Unit {
        if (stopAt.isSome()) { return }
        reason = why
        stopAt = Some(MonoTime.now())
        unsafe { _ = kill(-pid, SIGTERM) }
    }
    func nextWakeMillis(): Int64 {
        var next: Int64 = 10
        let now = MonoTime.now()
        if (spec.timeoutMillis > 0 && stopAt.isNone()) { next = min(next, max(0, spec.timeoutMillis - (now - started).toMilliseconds())) }
        match (stopAt) { case Some(since) => next = min(next, max(0, 100 - (now - since).toMilliseconds())); case None => () }
        return next
    }
    func advance(): Unit {
        let now = MonoTime.now()
        if (spec.timeoutMillis > 0 && (now - started).toMilliseconds() >= spec.timeoutMillis) {
            requestStop(ProcessEndReason.TimedOut)
        }
        match (stopAt) {
            case Some(since) => if ((now - since).toMilliseconds() >= 100) { unsafe { _ = kill(-pid, SIGKILL) } }
            case None => ()
        }
        if (status.isNone()) {
            let storage = LibC.malloc<Int32>()
            try {
                var found = unsafe { waitpid(pid, storage, WNOHANG) }
                while (found < 0 && ptyErrno() == 4) { found = unsafe { waitpid(pid, storage, WNOHANG) } }
                if (found == pid) {
                    status = Some(decodeExitStatus(unsafe { storage.read() }))
                    exitObserved = Some(now)
                }
            } finally { unsafe { LibC.free(storage) } }
        }
        // A background descendant may keep inherited pipes open after its
        // leader exits. It belongs to this command's group and cannot detach
        // the runtime's lifetime indefinitely.
        match (exitObserved) {
            case Some(since) => if ((now - since).toMilliseconds() >= 100) { unsafe { _ = kill(-pid, SIGKILL) } }
            case None => ()
        }
    }
    func readTurn(): Unit {
        if (stderrFirst) { readStream(ProcessOutputStream.Stderr); readStream(ProcessOutputStream.Stdout) }
        else { readStream(ProcessOutputStream.Stdout); readStream(ProcessOutputStream.Stderr) }
        stderrFirst = !stderrFirst
    }
    func readStream(stream: ProcessOutputStream): Unit {
        let fd = streamFd(stream)
        if (fd < 0) { return }
        var budget = readBudget
        while (budget > 0 && turnBudget.remaining > 0) {
            let capacity = min(min(min(budget, 4096), turnBudget.remaining), maxQueued - queuedBytes)
            if (capacity <= 0) { backpressureCount++; return }
            let bytes = Array<Byte>(capacity, repeat: 0)
            let n = unsafe {
                let handle = acquireArrayRawData(bytes)
                let count = read(fd, CPointer<Unit>(handle.pointer), UIntNative(capacity))
                releaseArrayRawData(handle)
                count
            }
            if (n > 0) {
                lastReadAt = MonoTime.now()
                budget -= Int64(n)
                turnBudget.remaining -= Int64(n)
                let accepted = min(Int64(n), max(0, spec.maxOutputBytes - outputBytes))
                if (accepted > 0) {
                    events.add(Event.ProcessOutput(processId, stream, bytes[..accepted]))
                    queuedBytes += accepted; outputBytes += accepted
                    peakQueuedBytes = max(peakQueuedBytes, queuedBytes)
                }
                if (accepted < Int64(n)) { outputComplete = false; requestStop(ProcessEndReason.OutputLimit) }
                continue
            }
            if (n == 0) { closeStream(stream); return }
            if (ptyErrno() == 4) { continue }
            if (ptyErrno() != PTY_EAGAIN) { closeStream(stream) }
            return
        }
    }
    func finishDraining(): Unit {
        if (status.isNone() || (stdoutFd < 0 && stderrFd < 0)) { return }
        let now = MonoTime.now()
        let expired = match (stopAt) {
            case Some(since) => (now - since).toMilliseconds() >= 250
            case None => match (exitObserved) {
                case Some(since) => (now - since).toMilliseconds() >= spec.drainTimeoutMillis ||
                    ((now - since).toMilliseconds() >= 250 && (now - lastReadAt).toMilliseconds() >= 250)
                case None => false
            }
        }
        if (expired) {
            // An escaped descendant can retain inherited pipes despite group
            // termination. Report the incomplete drain; never hang shutdown.
            if (stopAt.isNone()) { reason = ProcessEndReason.DrainTimeout }
            outputComplete = false
            closeDescriptors()
        }
    }
    func takeEvents(): Array<Event> {
        let out = events.toArray(); events.clear(); queuedBytes = 0; out
    }
    func finished(): Bool { status.isSome() && stdoutFd < 0 && stderrFd < 0 }
    func result(): ProcessResult { ProcessResult(reason, status.getOrThrow(), outputBytes, outputComplete: outputComplete) }
    func closeDescriptors(): Unit { closeStream(ProcessOutputStream.Stdout); closeStream(ProcessOutputStream.Stderr) }
    func forceClose(): Unit {
        unsafe { _ = kill(-pid, SIGKILL) }
        if (status.isNone()) {
            let storage = LibC.malloc<Int32>()
            try {
                var found = unsafe { waitpid(pid, storage, 0) }
                while (found < 0 && ptyErrno() == 4) { found = unsafe { waitpid(pid, storage, 0) } }
                if (found == pid) { status = Some(decodeExitStatus(unsafe { storage.read() })) }
            } finally { unsafe { LibC.free(storage) } }
        }
        closeDescriptors(); events.clear(); queuedBytes = 0
    }
}

@When[os != "Windows"]
class PipeOutputSource <: EventSource {
    private let process: PipeProcess
    private let stream: ProcessOutputStream
    init(process: PipeProcess, stream: ProcessOutputStream) { this.process = process; this.stream = stream }
    public func id(): String { process.processId + match (stream) { case ProcessOutputStream.Stdout => ":stdout"; case ProcessOutputStream.Stderr => ":stderr" } }
    public func fd(): ?Int32 { process.sourceFd(stream) }
    public func interests(): EventSourceInterest { EventSourceInterest.Read }
    public func onReady(readable: Bool, writable: Bool, error: Bool, hangup: Bool): Unit {
        if (readable || error || hangup) { process.readStream(stream) }
    }
    public func drain(): Array<Event> { [] }
    public func close(): Unit { process.requestStop(ProcessEndReason.Cancelled) }
}

// One decoder per output stream. Invalid bytes are replaced deterministically;
// incomplete suffixes use at most three bytes and flush once at EOF.
/** 增量解码 UTF-8 字节；每个输出流应使用独立解码器。
 */
public class Utf8StreamDecoder {
    private var pending: Array<Byte> = []
    /** 创建空解码器。
     */
    public init() {}
    /** 解码当前字节并保留不完整的尾部；无效字节替换为 U+FFFD。
     * @param bytes 输入字节
     * @return 本次解码得到的文本。
     */
    public func feed(bytes: Array<Byte>): String {
        let data = Array<Byte>(pending.size + bytes.size, repeat: 0)
        pending.copyTo(data, 0, 0, pending.size); bytes.copyTo(data, 0, pending.size, bytes.size)
        let text = StringBuilder()
        var offset: Int64 = 0
        while (offset < data.size) {
            let first = data[offset]
            let width: Int64 = if (first < 0x80) { 1 }
                else if (first >= 0xC2 && first <= 0xDF) { 2 }
                else if (first >= 0xE0 && first <= 0xEF) { 3 }
                else if (first >= 0xF0 && first <= 0xF4) { 4 }
                else { 0 }
            var invalid = width == 0
            for (i in 1..min(width, data.size - offset)) {
                if ((data[offset + i] & 0xC0) != 0x80) { invalid = true }
            }
            // Reject illegal second-byte ranges even for an incomplete scalar.
            if (data.size - offset >= 2) {
                let second = data[offset + 1]
                if ((first == 0xE0 && second < 0xA0) || (first == 0xED && second >= 0xA0) ||
                    (first == 0xF0 && second < 0x90) || (first == 0xF4 && second >= 0x90)) { invalid = true }
            }
            if (!invalid && data.size - offset < width) { break }
            if (!invalid) {
                try {
                    let (rune, length) = Rune.fromUtf8(data, offset)
                    text.append(rune.toString()); offset += length; continue
                } catch (_: IllegalArgumentException) {}
            }
            text.append("\u{FFFD}"); offset++
        }
        pending = data[offset..].clone()
        text.toString()
    }
    /** 结束输入并清除未完成尾部。
     * @return 存在不完整尾部时返回替换字符，否则返回空字符串。
     */
    public func finish(): String {
        let value = if (pending.isEmpty()) { "" } else { "\u{FFFD}" }
        pending = []; value
    }
}
