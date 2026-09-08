package core

import std.collection.*
import std.time.*

@FastNative
@When[os != "Windows"]
foreign func forkpty(amaster: CPointer<Int32>, name: CPointer<UInt8>, termp: CPointer<Unit>, winp: CPointer<Unit>): Int32

@FastNative
@When[os != "Windows"]
foreign func openpty(amaster: CPointer<Int32>, aslave: CPointer<Int32>, name: CPointer<UInt8>, termp: CPointer<Unit>, winp: CPointer<Unit>): Int32

@FastNative
@When[os != "Windows"]
foreign func fork(): Int32

@FastNative
@When[os != "Windows"]
foreign func setsid(): Int32

@FastNative
@When[os == "Linux"]
foreign func __errno_location(): CPointer<Int32>

@FastNative
@When[os == "macOS"]
foreign func __error(): CPointer<Int32>

@When[os == "Linux"]
func ptyErrno(): Int32 { unsafe { __errno_location().read() } }
@When[os == "macOS"]
func ptyErrno(): Int32 { unsafe { __error().read() } }

@FastNative
@When[os != "Windows"]
foreign func dup2(oldfd: Int32, newfd: Int32): Int32

@FastNative
@When[os != "Windows"]
foreign func pipe(pipefd: CPointer<Int32>): Int32

@FastNative
@When[os != "Windows"]
foreign func execvp(file: CString, argv: CPointer<CString>): Int32

@FastNative
@When[os != "Windows"]
foreign func chdir(path: CString): Int32

@FastNative
@When[os != "Windows"]
foreign func putenv(str: CString): Int32

@FastNative
@When[os != "Windows"]
foreign func fcntl(fd: Int32, cmd: Int32, value: Int32): Int32

@FastNative
@When[os != "Windows"]
foreign func kill(pid: Int32, sig: Int32): Int32

@FastNative
@When[os != "Windows"]
foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32

@FastNative
@When[os != "Windows"]
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): IntNative

@When[os != "Windows"]
const F_GETFL: Int32 = 3
@When[os != "Windows"]
const F_SETFL: Int32 = 4
@When[os != "Windows"]
const F_GETFD: Int32 = 1
@When[os != "Windows"]
const F_SETFD: Int32 = 2
@When[os != "Windows"]
const FD_CLOEXEC: Int32 = 1
@When[os == "Linux"]
const O_NONBLOCK: Int32 = 0x800
@When[os == "macOS"]
const O_NONBLOCK: Int32 = 0x4
@When[os != "Windows"]
const WNOHANG: Int32 = 1
@When[os != "Windows"]
const SIGINT: Int32 = 2
@When[os != "Windows"]
const SIGTERM: Int32 = 15
@When[os != "Windows"]
const SIGKILL: Int32 = 9
@When[os != "Windows"]
const SIGWINCH: Int32 = 28
@When[os == "Linux"]
const TIOCSWINSZ: UInt64 = 0x5414
@When[os == "macOS"]
const TIOCSWINSZ: UInt64 = 0x80087467
@When[os == "Linux"]
const TIOCSCTTY: UInt64 = 0x540E
@When[os == "macOS"]
const TIOCSCTTY: UInt64 = 0x20007461
@When[os == "Linux"]
const PTY_EAGAIN: Int32 = 11
@When[os == "macOS"]
const PTY_EAGAIN: Int32 = 35
@When[os != "Windows"]
const WINSIZE_BYTES: Int64 = 8
const PTY_READ_BYTES: Int64 = 4096
@When[os != "Windows"]
const STDERR_FILENO: Int32 = 2

public enum PtyOutputStream {
    | Stdout
    | Stderr
}

public struct PtySize {
    public let cols: Int64
    public let rows: Int64

    public init(cols!: Int64 = 80, rows!: Int64 = 24) {
        this.cols = max(1, cols)
        this.rows = max(1, rows)
    }
}

func snapshotStrings(values: Array<String>): Array<String> {
    let snapshot = ArrayList<String>()
    for (value in values) {
        snapshot.add(value)
    }
    snapshot.toArray()
}

public class PtySpec {
    public let command: String
    public let args: Array<String>
    public let cwd: String
    public let env: Array<String>
    public let size: PtySize

    public init(
        command: String,
        args!: Array<String> = [],
        cwd!: String = "",
        env!: Array<String> = [],
        size!: PtySize = PtySize()
    ) {
        this.command = command
        this.args = snapshotStrings(args)
        this.cwd = cwd
        this.env = snapshotStrings(env)
        this.size = size
    }
}

public enum PtySignal {
    | Interrupt
    | Terminate
    | Kill
}

public enum PtyExitStatus {
    | Exited(Int64)
    | Signaled(Int32)
}

public interface PtyProcess {
    func id(): String
    // Success accepts the complete byte request. Native PTYs keep a snapshot
    // while the descriptor is blocked; their EventSources must keep being
    // serviced. Native queues reject requests beyond 4 MiB pending data.
    func write(bytes: Array<Byte>): Bool
    func writeText(text: String): Bool
    func resize(size: PtySize): Bool
    func signal(signal: PtySignal): Bool
    // Closing a native PTY terminates its process group, waits for the actual
    // child status, and discards bytes still queued for writing.
    func close(): Unit
}

public interface PtyRuntime {
    // App closes and drains an existing instance before starting the same id.
    func start(id: String, spec: PtySpec): Event
    func process(id: String): ?PtyProcess
    func write(id: String, bytes: Array<Byte>): Event
    func resize(id: String, size: PtySize): Event
    func signal(id: String, signal: PtySignal): Event
    // Output collected while closing remains in drain(). Deliver that output
    // before this returned terminal event; App command dispatch does so.
    func close(id: String): Event
    func sources(): Array<EventSource>
    func drain(): Array<Event>
    func activeCount(): Int64
}

public enum EventSourceInterest {
    | Read
    | Write
    | ReadWrite
}

public interface EventSource {
    func id(): String
    func fd(): ?Int32
    // Windows wait handles are orthogonal to Unix file descriptors. The
    // default keeps all existing PTY sources source-compatible.
    func waitHandle(): ?CPointer<Unit> { None }
    func interests(): EventSourceInterest
    func onReady(readable: Bool, writable: Bool, error: Bool, hangup: Bool): Unit
    func drain(): Array<Event>
    func close(): Unit
}

public class FakePtyProcess <: PtyProcess {
    private let processId: String
    public var lastWrite: Array<Byte> = []
    public var lastSize: PtySize
    public var lastSignal: ?PtySignal = None
    public var closed: Bool = false

    public init(id: String, size!: PtySize = PtySize()) {
        this.processId = id
        this.lastSize = size
    }

    public func id(): String { processId }

    public func write(bytes: Array<Byte>): Bool {
        lastWrite = bytes
        true
    }

    public func writeText(text: String): Bool {
        write(unsafe { text.rawData() })
    }

    public func resize(size: PtySize): Bool {
        lastSize = size
        true
    }

    public func signal(signal: PtySignal): Bool {
        lastSignal = Some(signal)
        true
    }

    public func close(): Unit {
        closed = true
    }
}

public class FakePtyRuntime <: PtyRuntime {
    private let processes = ArrayList<FakePtyProcess>()
    private let events = ArrayList<Event>()

    public init() {}

    public func start(id: String, spec: PtySpec): Event {
        close(id)
        let process = FakePtyProcess(id, size: spec.size)
        processes.add(process)
        Event.PtyStarted(id)
    }

    public func process(id: String): ?PtyProcess {
        match (fakeProcess(id)) {
            case Some(process) => Some(process)
            case None => None
        }
    }

    public func fakeProcess(id: String): ?FakePtyProcess {
        let index = findIndex(id)
        if (index < 0) { None } else { Some(processes[index]) }
    }

    public func sources(): Array<EventSource> { [] }

    public func injectOutput(id: String, bytes: Array<Byte>, stream!: PtyOutputStream = PtyOutputStream.Stdout): Unit {
        events.add(Event.PtyOutput(id, stream, bytes))
    }

    public func injectText(id: String, text: String, stream!: PtyOutputStream = PtyOutputStream.Stdout): Unit {
        injectOutput(id, unsafe { text.rawData() }, stream: stream)
    }

    public func injectExit(id: String, status: PtyExitStatus): Unit {
        events.add(Event.PtyExited(id, status))
        remove(id)
    }

    public func injectFailure(id: String, message: String): Unit {
        events.add(Event.PtyFailed(id, message))
        remove(id)
    }

    public func write(id: String, bytes: Array<Byte>): Event {
        match (fakeProcess(id)) {
            case Some(process) =>
                if (process.write(bytes)) { Event.Message("pty-write:" + id) } else { Event.PtyFailed(id, "write failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func resize(id: String, size: PtySize): Event {
        match (fakeProcess(id)) {
            case Some(process) =>
                if (process.resize(size)) { Event.Message("pty-resize:" + id) } else { Event.PtyFailed(id, "resize failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func signal(id: String, signal: PtySignal): Event {
        match (fakeProcess(id)) {
            case Some(process) =>
                if (process.signal(signal)) { Event.Message("pty-signal:" + id) } else { Event.PtyFailed(id, "signal failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func close(id: String): Event {
        let index = findIndex(id)
        if (index < 0) {
            Event.PtyFailed(id, "pty not found")
        } else {
            processes[index].close()
            processes.remove(at: index)
            Event.PtyExited(id, PtyExitStatus.Exited(0))
        }
    }

    public func drain(): Array<Event> {
        let out = events.toArray()
        while (events.size > 0) {
            events.remove(at: 0)
        }
        out
    }

    public func activeCount(): Int64 {
        processes.size
    }

    private func findIndex(id: String): Int64 {
        for (i in 0..processes.size) {
            if (processes[i].id() == id) { return i }
        }
        -1
    }

    private func remove(id: String): Unit {
        let index = findIndex(id)
        if (index >= 0) {
            processes[index].close()
            processes.remove(at: index)
        }
    }
}

public class UnsupportedPtyRuntime <: PtyRuntime {
    public init() {}

    public func start(id: String, spec: PtySpec): Event {
        Event.PtyFailed(id, "pty runtime is not configured for " + spec.command)
    }

    public func process(id: String): ?PtyProcess {
        if (id.isEmpty()) { return None }
        None
    }

    public func write(id: String, bytes: Array<Byte>): Event {
        Event.PtyFailed(id, "pty runtime is not configured for write " + "${bytes.size}")
    }

    public func resize(id: String, size: PtySize): Event {
        Event.PtyFailed(id, "pty runtime is not configured for resize ${size.cols}x${size.rows}")
    }

    public func signal(id: String, signal: PtySignal): Event {
        Event.PtyFailed(id, "pty runtime is not configured for " + ptySignalName(signal))
    }

    public func close(id: String): Event {
        Event.PtyFailed(id, "pty runtime is not configured")
    }

    public func sources(): Array<EventSource> { [] }

    public func drain(): Array<Event> { [] }

    public func activeCount(): Int64 { 0 }
}

@When[os != "Windows"]
public class LinuxPtyRuntime <: PtyRuntime {
    private let processes = ArrayList<LinuxPtyProcess>()
    private let events = ArrayList<Event>()

    public init() {}

    public func start(id: String, spec: PtySpec): Event {
        _ = close(id)
        if (spec.command.isEmpty()) { return Event.PtyFailed(id, "pty command is empty") }
        let masterPtr = LibC.malloc<Int32>()
        let slavePtr = LibC.malloc<Int32>()
        let stderrPipe = Array<Int32>(2, repeat: -1)
        let startupPipe = Array<Int32>(2, repeat: -1)
        var master: Int32 = -1
        var slave: Int32 = -1
        var child: Int32 = -1
        var transferred = false
        try {
            let sizeBytes = makeWinsize(spec.size)
            let opened = unsafe {
                let handle = acquireArrayRawData(sizeBytes)
                let rc = openpty(masterPtr, slavePtr, CPointer<UInt8>(), CPointer<Unit>(), CPointer<Unit>(handle.pointer))
                releaseArrayRawData(handle)
                rc
            }
            if (opened != 0) { return Event.PtyFailed(id, "openpty failed") }
            master = unsafe { masterPtr.read() }
            slave = unsafe { slavePtr.read() }
            if (!makePtyPipe(stderrPipe) || !makePtyPipe(startupPipe)) {
                return Event.PtyFailed(id, "pty pipe failed")
            }
            if (!configureFd(master) || !configureFd(stderrPipe[0])) {
                return Event.PtyFailed(id, "pty fd configuration failed")
            }
            let command = PreparedPtyCommand(spec)
            try {
                child = unsafe { fork() }
                if (child < 0) { return Event.PtyFailed(id, "fork failed") }
                if (child == 0) {
                    unsafe { _ = close(startupPipe[0]) }
                    childExecWithStreams(command, master, slave, stderrPipe[0], stderrPipe[1], startupPipe[1])
                }
            } finally {
                // The child exits/execs without returning to this parent path.
                command.release()
            }
            unsafe { _ = close(slave); _ = close(stderrPipe[1]); _ = close(startupPipe[1]) }
            slave = -1
            stderrPipe[1] = -1
            startupPipe[1] = -1
            let startupError = readPtyStartupError(startupPipe[0])
            if (startupError != 0) {
                return Event.PtyFailed(id, "pty startup failed at stage ${startupError}")
            }
            processes.add(LinuxPtyProcess(id, master, stderrPipe[0], child, spec.size, events))
            transferred = true
            Event.PtyStarted(id)
        } finally {
            unsafe {
                LibC.free(masterPtr)
                LibC.free(slavePtr)
                if (slave >= 0) { _ = close(slave) }
                if (stderrPipe[1] >= 0) { _ = close(stderrPipe[1]) }
                for (fd in startupPipe) { if (fd >= 0) { _ = close(fd) } }
                if (!transferred) {
                    if (master >= 0) { _ = close(master) }
                    if (stderrPipe[0] >= 0) { _ = close(stderrPipe[0]) }
                    if (child > 0) {
                        _ = kill(child, SIGKILL)
                        let status = LibC.malloc<Int32>()
                        var rc = waitpid(child, status, 0)
                        while (rc < 0 && ptyErrno() == 4) { rc = waitpid(child, status, 0) }
                        LibC.free(status)
                    }
                }
            }
        }
    }

    public func process(id: String): ?PtyProcess {
        match (linuxProcess(id)) {
            case Some(process) => Some(process)
            case None => None
        }
    }

    public func write(id: String, bytes: Array<Byte>): Event {
        match (linuxProcess(id)) {
            case Some(process) =>
                if (process.write(bytes)) { Event.Message("pty-write:" + id) } else { Event.PtyFailed(id, "pty write failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func resize(id: String, size: PtySize): Event {
        match (linuxProcess(id)) {
            case Some(process) =>
                if (process.resize(size)) { Event.Message("pty-resize:" + id) } else { Event.PtyFailed(id, "pty resize failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func signal(id: String, signal: PtySignal): Event {
        match (linuxProcess(id)) {
            case Some(process) =>
                if (process.signal(signal)) { Event.Message("pty-signal:" + id) } else { Event.PtyFailed(id, "pty signal failed") }
            case None => Event.PtyFailed(id, "pty not found")
        }
    }

    public func close(id: String): Event {
        let index = findIndex(id)
        if (index < 0) { return Event.PtyFailed(id, "pty not found") }
        let process = processes[index]
        try {
            process.close()
            let status = process.reap()
            processes.remove(at: index)
            Event.PtyExited(id, status)
        } catch (error: Exception) {
            process.closeFdOnly()
            processes.remove(at: index)
            Event.PtyFailed(id, error.message)
        }
    }

    public func sources(): Array<EventSource> {
        let out = ArrayList<EventSource>()
        for (process in processes) {
            out.add(process)
            out.add(process.stderrSource())
        }
        out.toArray()
    }

    public func drain(): Array<Event> {
        let out = ArrayList<Event>()
        for (event in events) { out.add(event) }
        while (events.size > 0) { events.remove(at: 0) }
        var index: Int64 = 0
        while (index < processes.size) {
            let process = processes[index]
            match (process.pollExit()) {
                case Some(status) =>
                    process.drainRemaining()
                    for (event in events) { out.add(event) }
                    while (events.size > 0) { events.remove(at: 0) }
                    out.add(Event.PtyExited(process.id(), status))
                    process.closeFdOnly()
                    processes.remove(at: index)
                case None => index++
            }
        }
        out.toArray()
    }

    public func activeCount(): Int64 { processes.size }

    private func linuxProcess(id: String): ?LinuxPtyProcess {
        let index = findIndex(id)
        if (index < 0) { None } else { Some(processes[index]) }
    }

    private func findIndex(id: String): Int64 {
        for (i in 0..processes.size) {
            if (processes[i].id() == id) { return i }
        }
        -1
    }
}

@When[os != "Windows"]
public class LinuxPtyProcess <: PtyProcess & EventSource {
    private let processId: String
    private let masterFd: Int32
    private let stderrFd: Int32
    private let childPid: Int32
    private let eventQueue: ArrayList<Event>
    private var currentSize: PtySize
    private var closed: Bool = false
    private var stderrClosed: Bool = false
    private var exitStatus: ?PtyExitStatus = None
    private var pendingWrite: Array<Byte> = []
    private var writeOffset: Int64 = 0

    public init(id: String, fd: Int32, stderrFd: Int32, pid: Int32, size: PtySize, events: ArrayList<Event>) {
        this.processId = id
        this.masterFd = fd
        this.stderrFd = stderrFd
        this.childPid = pid
        this.currentSize = size
        this.eventQueue = events
    }

    public func id(): String { processId }

    public func fd(): ?Int32 {
        if (closed) { None } else { Some(masterFd) }
    }

    public func interests(): EventSourceInterest {
        if (writeOffset < pendingWrite.size) { EventSourceInterest.ReadWrite } else { EventSourceInterest.Read }
    }

    public func stderrSource(): EventSource { LinuxPtyStderrSource(this) }

    public func onReady(readable: Bool, writable: Bool, error: Bool, hangup: Bool): Unit {
        if (closed) { return }
        if ((writable || readable) && !flushWrites()) {
            eventQueue.add(Event.PtyFailed(processId, "pty write failed"))
        }
        if (readable || error || hangup) { readAvailable(masterFd, PtyOutputStream.Stdout) }
        // Runtime.drain owns terminal event delivery and record removal.
    }

    public func write(bytes: Array<Byte>): Bool {
        if (closed) { return false }
        let remaining = pendingWrite.size - writeOffset
        // A successful write owns a snapshot of the complete request. Reject
        // before accepting any bytes when the bounded queue is full.
        if (bytes.size > 4 * 1024 * 1024 - remaining) { return false }
        let next = Array<Byte>(remaining + bytes.size, repeat: 0)
        pendingWrite.copyTo(next, writeOffset, 0, remaining)
        bytes.copyTo(next, 0, remaining, bytes.size)
        pendingWrite = next
        writeOffset = 0
        flushWrites()
    }

    private func flushWrites(): Bool {
        while (writeOffset < pendingWrite.size) {
            let written = unsafe {
                let handle = acquireArrayRawData(pendingWrite)
                let rc = write(masterFd, CPointer<Unit>(handle.pointer + writeOffset), UIntNative(pendingWrite.size - writeOffset))
                releaseArrayRawData(handle)
                rc
            }
            if (written > 0) { writeOffset += Int64(written); continue }
            if (written < 0 && ptyErrno() == 4) { continue }
            if (written < 0 && ptyErrno() == PTY_EAGAIN) { return true }
            pendingWrite = []
            writeOffset = 0
            return false
        }
        pendingWrite = []
        writeOffset = 0
        true
    }

    public func writeText(text: String): Bool {
        write(unsafe { text.rawData() })
    }

    public func resize(size: PtySize): Bool {
        if (closed) { return false }
        let bytes = makeWinsize(size)
        var ok = false
        unsafe {
            let handle = acquireArrayRawData(bytes)
            ok = ioctl(masterFd, TIOCSWINSZ, CPointer<Unit>(handle.pointer)) == 0
            releaseArrayRawData(handle)
        }
        if (ok) {
            currentSize = size
            unsafe { _ = kill(-childPid, SIGWINCH) }
        }
        ok
    }

    public func signal(signal: PtySignal): Bool {
        if (closed) { return false }
        unsafe { kill(-childPid, signalNumber(signal)) == 0 }
    }

    public func close(): Unit {
        if (closed) { return }
        try {
            if (pollExit().isNone()) {
                unsafe { _ = kill(-childPid, SIGTERM) }
                let deadline = MonoTime.now() + Duration.millisecond * 100
                while (pollExit().isNone() && MonoTime.now() < deadline) {
                    sleep(Duration.millisecond)
                }
                if (pollExit().isNone()) { unsafe { _ = kill(-childPid, SIGKILL) } }
            }
            _ = reap()
            drainRemaining()
        } finally {
            closeFdOnly()
        }
    }

    func closeFdOnly(): Unit {
        pendingWrite = []
        writeOffset = 0
        if (!closed) {
            unsafe { _ = close(masterFd) }
            closed = true
        }
        closeStderrFdOnly()
    }

    func stderrFdValue(): ?Int32 {
        if (stderrClosed || closed) { None } else { Some(stderrFd) }
    }

    func onStderrReady(readable: Bool, error: Bool, hangup: Bool): Unit {
        if (stderrClosed || closed) { return }
        if (readable) { readAvailable(stderrFd, PtyOutputStream.Stderr) }
        if (error || hangup) { closeStderrFdOnly() }
    }

    func closeStderrFdOnly(): Unit {
        if (!stderrClosed) {
            unsafe { _ = close(stderrFd) }
            stderrClosed = true
        }
    }

    func drainRemaining(): Unit {
        if (!closed) { readAvailable(masterFd, PtyOutputStream.Stdout) }
        if (!stderrClosed) { readAvailable(stderrFd, PtyOutputStream.Stderr) }
    }

    public func drain(): Array<Event> { [] }

    public func pollExit(): ?PtyExitStatus {
        if (exitStatus.isSome()) { return exitStatus }
        let status = LibC.malloc<Int32>()
        try {
            var pid = unsafe { waitpid(childPid, status, WNOHANG) }
            while (pid < 0 && ptyErrno() == 4) { pid = unsafe { waitpid(childPid, status, WNOHANG) } }
            if (pid == childPid) { exitStatus = Some(decodeExitStatus(unsafe { status.read() })) }
            exitStatus
        } finally { unsafe { LibC.free(status) } }
    }

    public func reap(): PtyExitStatus {
        if (let Some(status) <- exitStatus) { return status }
        let status = LibC.malloc<Int32>()
        try {
            var pid = unsafe { waitpid(childPid, status, 0) }
            while (pid < 0 && ptyErrno() == 4) { pid = unsafe { waitpid(childPid, status, 0) } }
            if (pid != childPid) { throw Exception("pty waitpid failed: ${ptyErrno()}") }
            let value = decodeExitStatus(unsafe { status.read() })
            exitStatus = Some(value)
            value
        } finally { unsafe { LibC.free(status) } }
    }

    private func readAvailable(fd: Int32, stream: PtyOutputStream): Unit {
        match (stream) {
            case PtyOutputStream.Stdout =>
                if (closed) { return }
            case PtyOutputStream.Stderr =>
                if (stderrClosed) { return }
        }
        while (!closed) {
            let bytes = Array<Byte>(PTY_READ_BYTES, repeat: 0)
            var n: IntNative = 0
            unsafe {
                let handle = acquireArrayRawData(bytes)
                n = read(fd, CPointer<Unit>(handle.pointer), UIntNative(bytes.size))
                releaseArrayRawData(handle)
            }
            if (n > 0) {
                eventQueue.add(Event.PtyOutput(processId, stream, bytes[..Int64(n)]))
            } else {
                return
            }
        }
    }
}

@When[os != "Windows"]
class LinuxPtyStderrSource <: EventSource {
    private let process: LinuxPtyProcess

    init(process: LinuxPtyProcess) {
        this.process = process
    }

    public func id(): String { process.id() + ":stderr" }
    public func fd(): ?Int32 { process.stderrFdValue() }
    public func interests(): EventSourceInterest { EventSourceInterest.Read }

    public func onReady(readable: Bool, writable: Bool, error: Bool, hangup: Bool): Unit {
        if (writable) { () }
        process.onStderrReady(readable, error, hangup)
    }

    public func drain(): Array<Event> { [] }
    public func close(): Unit { process.closeStderrFdOnly() }
}

func ptySignalName(signal: PtySignal): String {
    match (signal) {
        case PtySignal.Interrupt => "interrupt"
        case PtySignal.Terminate => "terminate"
        case PtySignal.Kill => "kill"
    }
}

@When[os != "Windows"]
// Prepare native storage before fork. The child only borrows its forked copy
// for POSIX calls, then execs or _exits; the parent releases its own copy.
class PreparedPtyCommand {
    let cwd: CString
    let hasCwd: Bool
    let env: CPointer<CString>
    let envCount: Int64
    let argv: CPointer<CString>
    let argvCount: Int64
    let errorByte = LibC.malloc<Byte>()

    init(spec: PtySpec) {
        cwd = unsafe { LibC.mallocCString(spec.cwd) }
        hasCwd = !spec.cwd.isEmpty()
        envCount = spec.env.size
        env = LibC.malloc<CString>(count: max(1, envCount))
        argvCount = spec.args.size + 1
        argv = LibC.malloc<CString>(count: argvCount + 1)
        unsafe {
            for (i in 0..envCount) { (env + i).write(LibC.mallocCString(spec.env[i])) }
            argv.write(LibC.mallocCString(spec.command))
            for (i in 0..spec.args.size) { (argv + i + 1).write(LibC.mallocCString(spec.args[i])) }
            (argv + argvCount).write(CString(CPointer<UInt8>()))
        }
    }

    func release(): Unit {
        unsafe {
            LibC.free(cwd)
            for (i in 0..envCount) { LibC.free((env + i).read()) }
            for (i in 0..argvCount) { LibC.free((argv + i).read()) }
            LibC.free(env)
            LibC.free(argv)
            LibC.free(errorByte)
        }
    }
}

@When[os != "Windows"]
func childPtyFailure(command: PreparedPtyCommand, fd: Int32, stage: Byte): Unit {
    unsafe {
        command.errorByte.write(stage)
        var rc = write(fd, CPointer<Unit>(command.errorByte), 1)
        while (rc < 0 && ptyErrno() == 4) { rc = write(fd, CPointer<Unit>(command.errorByte), 1) }
        _exit(127)
    }
    while (true) {}
}

@When[os != "Windows"]
func childExecWithStreams(command: PreparedPtyCommand, masterFd: Int32, slaveFd: Int32, stderrReadFd: Int32, stderrWriteFd: Int32, errorFd: Int32): Unit {
    unsafe {
        _ = close(masterFd)
        _ = close(stderrReadFd)
        if (setsid() < 0 || ioctl(slaveFd, TIOCSCTTY, CPointer<Unit>()) != 0) { childPtyFailure(command, errorFd, 1) }
        if (dup2(slaveFd, STDIN_FILENO) < 0 || dup2(slaveFd, STDOUT_FILENO) < 0 || dup2(stderrWriteFd, STDERR_FILENO) < 0) {
            childPtyFailure(command, errorFd, 2)
        }
        if (slaveFd > STDERR_FILENO) { _ = close(slaveFd) }
        if (stderrWriteFd > STDERR_FILENO) { _ = close(stderrWriteFd) }
        if (command.hasCwd && chdir(command.cwd) != 0) { childPtyFailure(command, errorFd, 3) }
        for (i in 0..command.envCount) {
            if (putenv((command.env + i).read()) != 0) { childPtyFailure(command, errorFd, 4) }
        }
        _ = execvp(command.argv.read(), command.argv)
        childPtyFailure(command, errorFd, 5)
    }
}

@When[os != "Windows"]
func makePtyPipe(fds: Array<Int32>): Bool {
    unsafe {
        let handle = acquireArrayRawData(fds)
        let rc = pipe(handle.pointer)
        releaseArrayRawData(handle)
        if (rc != 0) { return false }
        for (fd in fds) {
            if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) { return false }
        }
    }
    true
}

@When[os != "Windows"]
func readPtyStartupError(fd: Int32): Int64 {
    let bytes = Array<Byte>(1, repeat: 0)
    while (true) {
        let count = unsafe {
            let handle = acquireArrayRawData(bytes)
            let rc = read(fd, CPointer<Unit>(handle.pointer), 1)
            releaseArrayRawData(handle)
            rc
        }
        if (count == 0) { return 0 }
        if (count > 0) { return Int64(bytes[0]) }
        if (ptyErrno() != 4) { return -1 }
    }
    -1
}

@When[os != "Windows"]
func configureFd(fd: Int32): Bool {
    unsafe {
        let flags = fcntl(fd, F_GETFL, 0)
        if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) { return false }
        let fdFlags = fcntl(fd, F_GETFD, 0)
        fdFlags >= 0 && fcntl(fd, F_SETFD, fdFlags | FD_CLOEXEC) >= 0
    }
}

@When[os != "Windows"]
func makeWinsize(size: PtySize): Array<UInt8> {
    let out = Array<UInt8>(WINSIZE_BYTES, repeat: 0)
    writeUInt16LE(out, 0, UInt16(size.rows))
    writeUInt16LE(out, 2, UInt16(size.cols))
    out
}

@When[os != "Windows"]
func writeUInt16LE(bytes: Array<UInt8>, offset: Int64, value: UInt16): Unit {
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
}

@When[os != "Windows"]
func signalNumber(signal: PtySignal): Int32 {
    match (signal) {
        case PtySignal.Interrupt => SIGINT
        case PtySignal.Terminate => SIGTERM
        case PtySignal.Kill => SIGKILL
    }
}

@When[os != "Windows"]
func decodeExitStatus(raw: Int32): PtyExitStatus {
    let signal = raw & 0x7F
    if (signal == 0) {
        PtyExitStatus.Exited(Int64((raw >> 8) & 0xFF))
    } else {
        PtyExitStatus.Signaled(signal)
    }
}
