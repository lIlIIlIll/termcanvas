package core

import std.collection.*
import std.time.*

public enum ProcessOutputStream { | Stdout | Stderr }
public enum ProcessEndReason { | Exited | Cancelled | TimedOut | OutputLimit | DrainTimeout }

// The child receives EOF on stdin. Interactive terminal applications use PTY.
public class ProcessSpec {
    public let command: String
    public let args: Array<String>
    public let cwd: String
    public let env: Array<String>
    public let timeoutMillis: Int64
    public let maxOutputBytes: Int64
    public let drainTimeoutMillis: Int64
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

public struct ProcessResult {
    public let reason: ProcessEndReason
    public let status: PtyExitStatus
    public let outputBytes: Int64
    public let outputComplete: Bool
    public init(reason: ProcessEndReason, status: PtyExitStatus, outputBytes: Int64, outputComplete!: Bool = true) {
        this.reason = reason; this.status = status; this.outputBytes = outputBytes; this.outputComplete = outputComplete
    }
}

public struct ProcessMetrics {
    public let queuedBytes: Int64
    public let peakQueuedBytes: Int64
    public let outputBytes: Int64
    public let backpressureCount: Int64
    public init(queuedBytes!: Int64 = 0, peakQueuedBytes!: Int64 = 0, outputBytes!: Int64 = 0, backpressureCount!: Int64 = 0) {
        this.queuedBytes = queuedBytes; this.peakQueuedBytes = peakQueuedBytes
        this.outputBytes = outputBytes; this.backpressureCount = backpressureCount
    }
}

public interface ProcessRuntime {
    func start(id: String, spec: ProcessSpec): Event
    // Cancellation is acknowledged immediately. The one Finished event is
    // emitted later, after the child has been reaped and output accounted for.
    func cancel(id: String): Event
    func sources(): Array<EventSource>
    func drain(): Array<Event>
    func activeCount(): Int64
    func nextTimeoutMillis(): ?Int64
    func metrics(): ProcessMetrics
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
        for (process in processes) { process.forceClose() }
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
public class Utf8StreamDecoder {
    private var pending: Array<Byte> = []
    public init() {}
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
    public func finish(): String {
        let value = if (pending.isEmpty()) { "" } else { "\u{FFFD}" }
        pending = []; value
    }
}
