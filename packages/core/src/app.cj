package core

import std.collection.*
import std.process.*
import std.time.*

@FastNative
@When[os == "Linux"]
foreign func epoll_create1(flags: Int32): Int32

@FastNative
@When[os == "Linux"]
foreign func epoll_ctl(epfd: Int32, op: Int32, fd: Int32, event: CPointer<Unit>): Int32

@FastNative
@When[os == "Linux"]
foreign func epoll_wait(epfd: Int32, events: CPointer<Unit>, maxevents: Int32, timeout: Int32): Int32

@FastNative
@When[os == "macOS"]
foreign func poll(fds: CPointer<Unit>, nfds: UInt32, timeout: Int32): Int32

@FastNative
@When[os == "Windows"]
foreign func WaitForSingleObject(handle: CPointer<Unit>, milliseconds: UInt32): UInt32

@FastNative
foreign func close(fd: Int32): Int32

@FastNative
@When[os != "Windows"]
foreign func getpid(): Int32

@When[os == "Linux"]
const APP_SIGTSTP: Int32 = 20
@When[os == "macOS"]
const APP_SIGTSTP: Int32 = 18

@When[os == "Linux"]
let EPOLL_CTL_ADD: Int32 = 1
@When[os == "Linux"]
let EPOLL_CTL_DEL: Int32 = 2
@When[os == "Linux"]
let EPOLL_CTL_MOD: Int32 = 3
@When[os == "Linux"]
let EPOLLIN: UInt32 = 0x001
@When[os == "Linux"]
let EPOLLOUT: UInt32 = 0x004
@When[os == "Linux"]
let EPOLLERR: UInt32 = 0x008
@When[os == "Linux"]
let EPOLLHUP: UInt32 = 0x010
@When[os == "Linux"]
let EPOLLET: UInt32 = 0x8000_0000u32
@When[os == "Linux"]
let EPOLL_EVENT_BYTES: Int64 = 16
@When[os == "macOS"]
let POLLIN_FLAG: Int16 = 0x0001
@When[os == "macOS"]
let POLLOUT_FLAG: Int16 = 0x0004
@When[os == "macOS"]
let POLLERR_FLAG: Int16 = 0x0008
@When[os == "macOS"]
let POLLHUP_FLAG: Int16 = 0x0010
@When[os == "macOS"]
let POLLFD_BYTES: Int64 = 8
@When[os == "Windows"]
let WAIT_TIMEOUT_MILLIS: UInt32 = 0x0000_0102u32
@When[os == "Windows"]
let WAIT_FAILED_RESULT: UInt32 = 0xFFFF_FFFFu32
@When[os == "Windows"]
let INFINITE_WAIT: UInt32 = 0xFFFF_FFFFu32

public enum ControlFlow {
    | Continue
    | Exit
}

// Optional, low-overhead hooks for end-to-end latency tracing.  The default
// App path keeps this disabled; applications opt in explicitly when running a
// diagnostic session.
public interface AppTraceSink {
    func inputReceived(event: Event, eventQueueLength: Int64): Unit
    func eventDispatchCompleted(): Unit
    func stateUpdateCompleted(): Unit
    func renderStarted(): Unit
    func eventLoopStall(task: String, durationNanos: Int64): Unit
}

public struct TimerSpec {
    public let id: String
    public let every: Duration
    public let mode: TimerMode
    public let missPolicy: FrameMissPolicy

    public init(id: String, every: Duration, mode!: TimerMode = TimerMode.Repeating, missPolicy!: FrameMissPolicy = FrameMissPolicy.Drop) {
        this.id = id
        this.every = if (every <= Duration.Zero) { Duration.millisecond } else { every }
        this.mode = mode
        this.missPolicy = missPolicy
    }
}

public enum Command {
    | Noop
    | Quit
    | Emit(Event)
    | Message(String)
    | Async(String)
    | AsyncTask(String, () -> Event)
    | AsyncExec(String, String)
    | AsyncExecArgs(String, String, Array<String>)
    | CancelAsync(String)
    | PtyStart(String, PtySpec)
    | PtyWrite(String, Array<Byte>)
    | PtyResize(String, PtySize)
    | PtySendSignal(String, PtySignal)
    | PtyClose(String)
    | StartTimer(TimerSpec)
    | StopTimer(String)
    | RestartTimer(TimerSpec)
    | Exec(String)
    | ExecArgs(String, String, Array<String>)
    | ResetTerminal
    | Suspend
    | Batch(Array<Command>)
}

class TerminalLifecycleRequests {
    var resetRequested: Bool = false
    var suspendRequested: Bool = false
    private let ownedPtys = ArrayList<String>()

    func trackPty(id: String): Unit {
        for (owned in ownedPtys) {
            if (owned == id) { return }
        }
        ownedPtys.add(id)
    }

    func releasePty(id: String): Unit {
        var index: Int64 = 0
        while (index < ownedPtys.size) {
            if (ownedPtys[index] == id) {
                ownedPtys.remove(at: index)
                return
            }
            index++
        }
    }

    func closeOwnedPtys(runtime: PtyRuntime): Unit {
        var index = ownedPtys.size
        while (index > 0) {
            index--
            let id = ownedPtys[index]
            try {
                _ = runtime.close(id)
            } catch (_: Exception) {
                // Session shutdown is best effort.  Continue closing the
                // remaining PTYs and preserve the primary application error.
            }
        }
        ownedPtys.clear()
    }
}

public struct FrameMetrics {
    public let frameIndex: Int64
    public let fps: Int64
    public let renderMillis: Int64
    public let drawMillis: Int64
    public let totalMillis: Int64
    public let eventQueueLength: Int64
    public let dirtyCells: Int64
    public let diffWrites: Int64
    public let terminalSize: Rect
    public let droppedTicks: Int64
    public let tickDeltaMillis: Int64
    public let renderedCells: Int64
    public let dirtyRects: Int64

    public init(
        frameIndex!: Int64 = 0,
        fps!: Int64 = 0,
        renderMillis!: Int64 = 0,
        drawMillis!: Int64 = 0,
        totalMillis!: Int64 = 0,
        eventQueueLength!: Int64 = 0,
        dirtyCells!: Int64 = 0,
        diffWrites!: Int64 = 0,
        terminalSize!: Rect = Rect(0, 0, 0, 0),
        droppedTicks!: Int64 = 0,
        tickDeltaMillis!: Int64 = 0,
        renderedCells!: Int64 = 0,
        dirtyRects!: Int64 = 0
    ) {
        this.frameIndex = max(0, frameIndex)
        this.fps = max(0, fps)
        this.renderMillis = max(0, renderMillis)
        this.drawMillis = max(0, drawMillis)
        this.totalMillis = max(0, totalMillis)
        this.eventQueueLength = max(0, eventQueueLength)
        this.dirtyCells = max(0, dirtyCells)
        this.diffWrites = max(0, diffWrites)
        this.terminalSize = terminalSize
        this.droppedTicks = max(0, droppedTicks)
        this.tickDeltaMillis = max(0, tickDeltaMillis)
        this.renderedCells = max(0, renderedCells)
        this.dirtyRects = max(0, dirtyRects)
    }
}

public class AppMetrics {
    private let values = ArrayList<FrameMetrics>()

    public init() {}

    public func record(frame: FrameMetrics): Unit {
        values.add(frame)
    }

    public func record(
        render: RenderMetrics,
        frameIndex!: Int64 = 0,
        eventQueueLength!: Int64 = 0,
        droppedTicks!: Int64 = 0,
        tickDeltaMillis!: Int64 = 0
    ): Unit {
        let fps = if (tickDeltaMillis > 0) { 1000 / tickDeltaMillis } else { 0 }
        record(FrameMetrics(
            frameIndex: frameIndex,
            fps: fps,
            renderMillis: render.renderMillis,
            drawMillis: render.drawMillis,
            totalMillis: render.totalMillis,
            eventQueueLength: eventQueueLength,
            dirtyCells: render.dirtyCells,
            diffWrites: render.diffWrites,
            terminalSize: render.size,
            droppedTicks: droppedTicks,
            tickDeltaMillis: tickDeltaMillis,
            renderedCells: render.renderedCells,
            dirtyRects: render.dirtyRects
        ))
    }

    public func lastFrame(): ?FrameMetrics {
        if (values.size == 0) { return None }
        Some(values[values.size - 1])
    }

    public func frames(): Array<FrameMetrics> {
        values.toArray()
    }

    public func averageFps(): Int64 {
        var total: Int64 = 0
        var count: Int64 = 0
        for (frame in values) {
            if (frame.fps > 0) {
                total += frame.fps
                count++
            }
        }
        if (count == 0) { return 0 }
        total / count
    }

    public func droppedTicks(): Int64 {
        match (lastFrame()) {
            case Some(frame) => frame.droppedTicks
            case None => 0
        }
    }

    public func reset(): Unit {
        while (values.size > 0) {
            values.remove(at: 0)
        }
    }
}

class TimerState {
    let spec: TimerSpec
    var nextDue: MonoTime
    var startedAt: MonoTime
    var firedCount: Int64 = 0

    init(spec: TimerSpec, now: MonoTime) {
        this.spec = spec
        this.startedAt = now
        this.nextDue = now + spec.every
    }
}

public class TimerRuntime {
    private let timers = ArrayList<TimerState>()

    func start(spec: TimerSpec, now: MonoTime): Unit {
        stop(spec.id)
        timers.add(TimerState(spec, now))
    }

    func stop(id: String): Bool {
        var i: Int64 = 0
        while (i < timers.size) {
            if (timers[i].spec.id == id) {
                timers.remove(at: i)
                return true
            }
            i++
        }
        false
    }

    func drain(now: MonoTime): Array<Event> {
        let out = ArrayList<Event>()
        var i: Int64 = 0
        while (i < timers.size) {
            let timer = timers[i]
            if (now >= timer.nextDue) {
                let late = now - timer.nextDue
                let missed = droppedFrames(late, timer.spec.every, timer.spec.missPolicy)
                timer.firedCount++
                out.add(Event.Timer(TimerEvent(
                    timer.spec.id,
                    elapsedMillis: durationMillis(now - timer.startedAt),
                    firedCount: timer.firedCount,
                    droppedFrames: missed
                )))
                match (timer.spec.mode) {
                    case TimerMode.OneShot =>
                        timers.remove(at: i)
                        continue
                    case TimerMode.Repeating =>
                        timer.nextDue = nextDue(now, timer.nextDue, timer.spec.every, timer.spec.missPolicy)
                }
            }
            i++
        }
        out.toArray()
    }

    func nextTimeoutMillis(now: MonoTime): ?Int64 {
        var best: ?Int64 = None
        for (timer in timers) {
            let wait = if (timer.nextDue <= now) { Int64(0) } else { durationMillis(timer.nextDue - now) }
            best = match (best) {
                case Some(value) => Some(min(value, wait))
                case None => Some(wait)
            }
        }
        best
    }

    func clear(): Unit {
        timers.clear()
    }
}

func durationMillis(duration: Duration): Int64 {
    max(0, duration.toMilliseconds())
}

func droppedFrames(late: Duration, every: Duration, policy: FrameMissPolicy): Int64 {
    if (late <= Duration.Zero || every <= Duration.Zero) { return 0 }
    let missed = late.toMilliseconds() / max(1, every.toMilliseconds())
    match (policy) {
        case FrameMissPolicy.Drop => missed
        case FrameMissPolicy.CatchUp(maxCatchUp) => min(max(0, maxCatchUp), missed)
    }
}

func nextDue(now: MonoTime, previous: MonoTime, every: Duration, policy: FrameMissPolicy): MonoTime {
    match (policy) {
        case FrameMissPolicy.Drop => now + every
        case FrameMissPolicy.CatchUp(_) => previous + every
    }
}

class AsyncTaskState {
    let id: String
    let future: Future<Event>
    var cancelRequested: Bool = false

    init(id: String, future: Future<Event>) {
        this.id = id
        this.future = future
    }
}

public class AsyncRuntime {
    private let tasks = ArrayList<AsyncTaskState>()

    public init() {}

    public func start(id: String, task: () -> Event): Event {
        cancel(id)
        let future = spawn {
            try {
                task()
            } catch (e: Exception) {
                Event.AsyncFailed(id, e.message)
            }
        }
        tasks.add(AsyncTaskState(id, future))
        Event.AsyncStarted(id)
    }

    public func startExec(id: String, commandLine: String): Event {
        start(id, { => App.executeCommand(commandLine) })
    }

    public func startExecArgs(id: String, program: String, args: Array<String>): Event {
        start(id, { => App.executeCommandArgs(id, program, args) })
    }

    public func cancel(id: String): Bool {
        for (task in tasks) {
            if (task.id == id) {
                task.cancelRequested = true
                task.future.cancel()
                return true
            }
        }
        false
    }

    public func drain(): Array<Event> {
        let out = ArrayList<Event>()
        var index: Int64 = 0
        while (index < tasks.size) {
            let task = tasks[index]
            match (task.future.tryGet()) {
                case Some(event) =>
                    tasks.remove(at: index)
                    if (task.cancelRequested) {
                        out.add(Event.AsyncCancelled(task.id))
                    } else {
                        match (event) {
                            case Event.AsyncFailed(_, message) => out.add(Event.AsyncFailed(task.id, message))
                            case _ => out.add(Event.AsyncCompleted(task.id, event))
                        }
                    }
                case None => index++
            }
        }
        out.toArray()
    }

    public func pendingCount(): Int64 {
        tasks.size
    }

    func cancelAll(): Unit {
        for (task in tasks) {
            task.cancelRequested = true
            task.future.cancel()
        }
    }
}

public class Subscription {
    public let interval: Int64
    public let event: Event
    private var elapsed: Int64 = 0

    public init(interval: Int64, event: Event) {
        this.interval = max(1, interval)
        this.event = event
    }

    public func poll(step!: Int64 = 1): ?Event {
        elapsed += max(1, step)
        if (elapsed >= interval) {
            elapsed = 0
            Some(event)
        } else {
            None
        }
    }
}

public interface EventWaiter {
    func wait(timeoutMillis: Int64, previousReadBytes!: Int64, sources!: Array<EventSource>): Unit
    func close(): Unit
}

public class NoopEventWaiter <: EventWaiter {
    public init() {}

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64, sources!: Array<EventSource>): Unit {
        if (timeoutMillis < -1 && previousReadBytes < -1 && sources.size < 0) { return }
    }

    public func close(): Unit {}
}

@When[os == "Linux"]
public func defaultEventWaiter(): EventWaiter {
    LinuxEpollEventWaiter()
}

@When[os == "macOS"]
public func defaultEventWaiter(): EventWaiter {
    MacOSPollEventWaiter()
}

@When[os == "Windows"]
public func defaultEventWaiter(): EventWaiter {
    WindowsConsoleEventWaiter()
}

@When[os == "Windows"]
public class WindowsConsoleEventWaiter <: EventWaiter {
    private var closed: Bool = false

    public init() {}

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64 = 1, sources!: Array<EventSource> = []): Unit {
        if (closed) { return }
        if (previousReadBytes > 0) { return }
        let timeout = windowsWaitTimeout(timeoutMillis)
        let input = unsafe { GetStdHandle(STD_INPUT_HANDLE) }
        let result = unsafe { WaitForSingleObject(input, timeout) }
        if (result == WAIT_FAILED_RESULT || result == WAIT_TIMEOUT_MILLIS) { return }
        if (sources.size < 0) { return }
    }

    public func close(): Unit {
        closed = true
    }
}

public struct UpdateResult {
    public let flow: ControlFlow
    public let command: Command
    public let dirtyRects: ?DirtyRects
    // Most existing update handlers mutate state and rely on the app loop's
    // compatibility full redraw when no dirty rectangles are supplied.  Keep
    // that default, but let boundary/no-op handlers explicitly suppress a
    // frame so buffered input cannot build an expensive redraw backlog.
    public let renderRequested: Bool

    public init(
        flow!: ControlFlow = ControlFlow.Continue,
        command!: Command = Command.Noop,
        dirtyRects!: ?DirtyRects = None,
        renderRequested!: Bool = true
    ) {
        this.flow = flow
        this.command = command
        this.dirtyRects = dirtyRects
        this.renderRequested = renderRequested
    }

    public static func next(): UpdateResult {
        UpdateResult()
    }

    public static func unchanged(): UpdateResult {
        UpdateResult(renderRequested: false)
    }

    public static func exit(): UpdateResult {
        UpdateResult(flow: ControlFlow.Exit)
    }

    public static func withCommand(command: Command): UpdateResult {
        UpdateResult(command: command)
    }

    public static func dirty(area: Rect): UpdateResult {
        UpdateResult(dirtyRects: Some(DirtyRects.full(area)))
    }

    public func withDirty(area: Rect): UpdateResult {
        let rects = match (dirtyRects) {
            case Some(existing) => existing.copy()
            case None => DirtyRects()
        }
        rects.add(area)
        UpdateResult(flow: flow, command: command, dirtyRects: Some(rects), renderRequested: true)
    }
}

public struct HandleResult {
    public let handled: Bool
    public let flow: ControlFlow
    public let command: Command

    public init(handled!: Bool = false, flow!: ControlFlow = ControlFlow.Continue, command!: Command = Command.Noop) {
        this.handled = handled
        this.flow = flow
        this.command = command
    }

    public static func ignored(): HandleResult {
        HandleResult()
    }

    public static func consumed(command!: Command = Command.Noop): HandleResult {
        HandleResult(handled: true, command: command)
    }

    public static func exit(): HandleResult {
        HandleResult(handled: true, flow: ControlFlow.Exit)
    }

    public static func withCommand(command: Command): HandleResult {
        HandleResult(handled: true, command: command)
    }

    public func toUpdateResult(): UpdateResult {
        UpdateResult(flow: flow, command: command)
    }
}

public interface Component {
    func render(frame: Frame, area: Rect): Unit
    func handle(event: Event): HandleResult
    func focusId(): ?String
}

public enum EventPhase {
    | Capture
    | Target
    | Bubble
}

public enum EventPropagation {
    | Continue
    | Stop
    | Exit
}

public class EventContext {
    public let event: Event
    public let phase: EventPhase
    public let targetId: String
    public let currentId: String
    private var stopped: Bool = false

    public init(event: Event, phase: EventPhase, targetId!: String = "", currentId!: String = "") {
        this.event = event
        this.phase = phase
        this.targetId = targetId
        this.currentId = currentId
    }

    public func stopPropagation(): Unit {
        stopped = true
    }

    public func isStopped(): Bool {
        stopped
    }
}

public class StringState {
    private var value: String
    private var dirty: Bool = false

    public init(value!: String = "") {
        this.value = value
    }

    public func get(): String { value }

    public func set(value: String): Unit {
        if (this.value != value) {
            this.value = value
            dirty = true
        }
    }

    public func isDirty(): Bool { dirty }
    public func clearDirty(): Unit { dirty = false }
}

public class IntState {
    private var value: Int64
    private var dirty: Bool = false

    public init(value!: Int64 = 0) {
        this.value = value
    }

    public func get(): Int64 { value }

    public func set(value: Int64): Unit {
        if (this.value != value) {
            this.value = value
            dirty = true
        }
    }

    public func isDirty(): Bool { dirty }
    public func clearDirty(): Unit { dirty = false }
}

public class ViewNode {
    public let id: String
    public var tag: String
    public let classes = ArrayList<String>()
    private let component: ?Component
    private let children = ArrayList<ViewNode>()
    private let states = ArrayList<String>()
    private var parent: ?ViewNode = None
    private var part: String = ""
    private var text: String = ""
    private var media: ?MediaSource = None
    private var inlineDeclarations: StyleDeclaration = StyleDeclaration()
    private var computed: ComputedStyle = ComputedStyle.default()
    private var area: Rect = Rect(0, 0, 0, 0)
    private var layout: Rect = Rect(0, 0, 0, 0)
    private var dirty: Bool = true

    public init(
        id: String,
        tag!: String = "node",
        component!: ?Component = None,
        area!: Rect = Rect(0, 0, 0, 0),
        classes!: Array<String> = [],
        inlineStyle!: StyleDeclaration = StyleDeclaration(),
        part!: String = ""
    ) {
        this.id = id
        this.tag = tag
        this.component = component
        this.area = area
        this.layout = area
        this.inlineDeclarations = inlineStyle
        this.part = part
        for (name in classes) {
            this.classes.add(name)
        }
    }

    public func add(child: ViewNode): ViewNode {
        child.parent = Some(this)
        children.add(child)
        this
    }

    public func setText(text: String): ViewNode {
        this.text = text
        invalidate()
        this
    }

    public func setMedia(source: MediaSource): ViewNode {
        this.media = Some(source)
        invalidate()
        this
    }

    public func clearMedia(): ViewNode {
        this.media = None
        invalidate()
        this
    }

    public func textContent(): String {
        text
    }

    public func addClass(name: String): ViewNode {
        if (!hasClass(name)) {
            classes.add(name)
            invalidate()
        }
        this
    }

    public func removeClass(name: String): ViewNode {
        for (i in 0..classes.size) {
            if (classes[i] == name) {
                classes.remove(at: i)
                invalidate()
                return this
            }
        }
        this
    }

    public func hasClass(name: String): Bool {
        for (className in classes) {
            if (className == name) { return true }
        }
        false
    }

    public func setState(name: String, enabled!: Bool = true): ViewNode {
        if (enabled) {
            if (!hasState(name)) {
                states.add(name)
                invalidate()
            }
        } else {
            for (i in 0..states.size) {
                if (states[i] == name) {
                    states.remove(at: i)
                    invalidate()
                    return this
                }
            }
        }
        this
    }

    public func hasState(name: String): Bool {
        for (state in states) {
            if (state == name) { return true }
        }
        false
    }

    public func setInlineStyle(style: StyleDeclaration): ViewNode {
        inlineDeclarations = style
        invalidate()
        this
    }

    public func inlineStyle(): StyleDeclaration {
        inlineDeclarations
    }

    public func setComputedStyle(style: ComputedStyle): Unit {
        computed = style
    }

    public func computedStyle(): ComputedStyle {
        computed
    }

    public func setPart(name: String): ViewNode {
        part = name
        invalidate()
        this
    }

    public func partName(): String {
        part
    }

    public func parentNode(): ?ViewNode {
        parent
    }

    public func setArea(area: Rect): Unit {
        if (this.area != area) {
            this.area = area
            this.layout = area
            invalidate()
        }
    }

    public func setLayoutBox(area: Rect): Unit {
        layout = area
    }

    public func layoutBox(): Rect {
        layout
    }

    public func invalidate(): Unit {
        dirty = true
    }

    public func clearDirty(): Unit {
        dirty = false
        for (child in children) {
            child.clearDirty()
        }
    }

    public func isDirty(): Bool {
        if (dirty) { return true }
        for (child in children) {
            if (child.isDirty()) { return true }
        }
        false
    }

    public func childNodes(): Array<ViewNode> {
        children.toArray()
    }

    public func render(frame: Frame): Unit {
        if (!cssDisplayIsHidden(computed.display)) {
            frame.fill(layout, computed.style)
        }
        if (!text.isEmpty() && layout.width > 0 && layout.height > 0) {
            frame.renderWidget(Paragraph(text, style: computed.style, wrap: WrapMode.Word), layout)
        }
        match (media) {
            case Some(source) =>
                if (layout.width > 0 && layout.height > 0) {
                    frame.addMedia(MediaPlacement("dom:${id}", source, layout, fit: computed.objectFit))
                }
            case None => ()
        }
        match (component) {
            case Some(c) => c.render(frame, layout)
            case None => ()
        }
        for (child in children) {
            child.render(frame)
        }
    }

    public func render(frame: Frame, sheet: StyleSheet): Unit {
        sheet.apply(this, area)
        render(frame)
    }

    public func dispatch(event: Event, focusId!: ?String = None): ControlFlow {
        dispatchResult(event, focusId: focusId).flow
    }

    public func dispatchResult(event: Event, focusId!: ?String = None): HandleResult {
        match (dispatchCapture(event)) {
            case EventPropagation.Exit => return HandleResult.exit()
            case EventPropagation.Stop => return HandleResult.consumed()
            case EventPropagation.Continue => ()
        }
        let target: ?ViewNode = match (focusId) {
            case Some(id) => find(id)
            case None => None
        }
        match (target) {
            case Some(node) =>
                match (node.dispatchTarget(event)) {
                    case EventPropagation.Exit => return HandleResult.exit()
                    case EventPropagation.Stop => return HandleResult.consumed()
                    case EventPropagation.Continue => ()
                }
            case None => ()
        }
        match (dispatchBubble(event)) {
            case EventPropagation.Exit => HandleResult.exit()
            case EventPropagation.Stop => HandleResult.consumed()
            case _ => HandleResult.ignored()
        }
    }

    public func find(id: String): ?ViewNode {
        if (this.id == id) { return Some(this) }
        for (child in children) {
            match (child.find(id)) {
                case Some(node) => return Some(node)
                case None => ()
            }
        }
        None
    }

    public func queryByClass(name: String): Array<ViewNode> {
        let out = ArrayList<ViewNode>()
        collectByClass(name, out)
        out.toArray()
    }

    private func collectByClass(name: String, out: ArrayList<ViewNode>): Unit {
        for (className in classes) {
            if (className == name) {
                out.add(this)
                break
            }
        }
        for (child in children) {
            child.collectByClass(name, out)
        }
    }

    private func dispatchCapture(event: Event): EventPropagation {
        let result = invoke(event)
        if (isExit(result.flow)) { return EventPropagation.Exit }
        if (result.handled) { return EventPropagation.Stop }
        for (child in children) {
            match (child.dispatchCapture(event)) {
                case EventPropagation.Continue => ()
                case other => return other
            }
        }
        EventPropagation.Continue
    }

    private func dispatchTarget(event: Event): EventPropagation {
        eventPropagationFromHandle(invoke(event))
    }

    private func dispatchBubble(event: Event): EventPropagation {
        var i = children.size - 1
        while (i >= 0) {
            match (children[i].dispatchBubble(event)) {
                case EventPropagation.Continue => ()
                case other => return other
            }
            i--
        }
        eventPropagationFromHandle(invoke(event))
    }

    private func invoke(event: Event): HandleResult {
        match (component) {
            case Some(c) => c.handle(event)
            case None => HandleResult.ignored()
        }
    }
}

public class EventRouter {
    private let focus: FocusManager
    private let globalKeys: KeyMap
    private let components = ArrayList<Component>()

    public init(focus!: FocusManager = FocusManager(), globalKeys!: KeyMap = KeyMap()) {
        this.focus = focus
        this.globalKeys = globalKeys
    }

    public func add(component: Component, focused!: Bool = true): Unit {
        components.add(component)
        match (component.focusId()) {
            case Some(id) => focus.add(id, enabled: focused)
            case None => ()
        }
    }

    public func focusManager(): FocusManager {
        focus
    }

    public func componentCount(): Int64 {
        components.size
    }

    public func render(frame: Frame, areas: Array<Rect>): Unit {
        let limit = min(components.size, areas.size)
        for (i in 0..limit) {
            components[i].render(frame, areas[i])
        }
    }

    public func handle(event: Event): ControlFlow {
        handleResult(event, { _ => HandleResult.ignored() }).flow
    }

    public func handle(event: Event, actionHandler: (String) -> ControlFlow): ControlFlow {
        handleResult(event, { action => HandleResult(handled: true, flow: actionHandler(action)) }).flow
    }

    public func handleResult(event: Event): HandleResult {
        handleResult(event, { _ => HandleResult.ignored() })
    }

    public func handleResult(event: Event, actionHandler: (String) -> HandleResult): HandleResult {
        match (event) {
            case Event.KeyDown(key) =>
                if (focus.handle(key)) { return HandleResult.consumed() }
                let focused = routeToFocused(event)
                if (focused.handled || !isContinueFlow(focused.flow) || !isNoopCommand(focused.command)) {
                    return focused
                }
                match (globalKeys.actionFor(key)) {
                    case Some(action) => return actionHandler(action)
                    case None => ()
                }
                return focused
            case _ => ()
        }
        routeToFocused(event)
    }

    private func routeToFocused(event: Event): HandleResult {
        match (focus.current()) {
            case Some(id) =>
                for (component in components) {
                    match (component.focusId()) {
                        case Some(candidate) =>
                            if (candidate == id) { return component.handle(event) }
                        case None => ()
                    }
                }
                HandleResult.ignored()
            case None => HandleResult.ignored()
        }
    }
}

func isContinueFlow(flow: ControlFlow): Bool {
    match (flow) {
        case ControlFlow.Continue => true
        case ControlFlow.Exit => false
    }
}

func isNoopCommand(command: Command): Bool {
    match (command) {
        case Command.Noop => true
        case _ => false
    }
}

@When[os == "Windows"]
func windowsWaitTimeout(timeoutMillis: Int64): UInt32 {
    if (timeoutMillis < 0) { return INFINITE_WAIT }
    UInt32(min(timeoutMillis, Int64(0xFFFF_FFFEu32)))
}

public class EventScript {
    private let events = ArrayList<Event>()

    public init(events!: Array<Event> = []) {
        for (event in events) {
            this.events.add(event)
        }
    }

    public func add(event: Event): EventScript {
        events.add(event)
        this
    }

    public func key(key: KeyEvent): EventScript {
        add(Event.KeyDown(key))
    }

    public func paste(text: String): EventScript {
        add(Event.Paste(text))
    }

    public func message(text: String): EventScript {
        add(Event.Message(text))
    }

    public func tick(): EventScript {
        add(Event.Tick(TickEvent()))
    }

    public func resize(area: Rect): EventScript {
        add(Event.Resize(area))
    }

    public func size(): Int64 {
        events.size
    }

    public static func fromText(text: String): EventScript {
        let script = EventScript()
        for (line in splitLines(text)) {
            let trimmed = trimAscii(line)
            if (trimmed.isEmpty()) { continue }
            if (trimmed == "tick") {
                script.tick()
            } else if (trimmed == "ctrl-c") {
                script.key(KeyEvent(KeyCode.CtrlC))
            } else if (trimmed.startsWith("message:")) {
                script.message(trimmed[8..])
            } else if (trimmed.startsWith("paste:")) {
                script.paste(trimmed[6..])
            } else if (trimmed.startsWith("key:")) {
                match (parseScriptKey(trimmed[4..])) {
                    case Some(key) => script.key(key)
                    case None => ()
                }
            } else if (trimmed.startsWith("resize:")) {
                match (parseScriptSize(trimmed[7..])) {
                    case Some(area) => script.resize(area)
                    case None => ()
                }
            }
        }
        script
    }

    public func run(update: (Event) -> ControlFlow): ControlFlow {
        for (event in events) {
            match (update(event)) {
                case ControlFlow.Continue => ()
                case ControlFlow.Exit => return ControlFlow.Exit
            }
        }
        ControlFlow.Continue
    }

    public func runWithCommands(update: (Event) -> UpdateResult): ControlFlow {
                let commandQueue = ArrayList<Command>()
        let asyncRuntime = AsyncRuntime()
        for (event in events) {
            if (!App.applyUpdateResult(update(event), commandQueue)) {
                return ControlFlow.Exit
            }
            if (!App.processCommands(update, commandQueue, asyncRuntime: asyncRuntime)) {
                return ControlFlow.Exit
            }
        }
        while (asyncRuntime.pendingCount() > 0) {
            if (!App.processCommands(update, commandQueue, asyncRuntime: asyncRuntime)) {
                return ControlFlow.Exit
            }
        }
        ControlFlow.Continue
    }
}

public enum ScenarioStep {
    | Input(Event)
    | ExpectFlow(ControlFlow)
    | ExpectSnapshot(String)
    | ExpectCell(Int64, Int64, String)
}

public class ScenarioResult {
    public let name: String
    public let passed: Bool
    public let failures: Array<String>
    public let flow: ControlFlow

    public init(name: String, passed: Bool, failures: Array<String>, flow: ControlFlow) {
        this.name = name
        this.passed = passed
        this.failures = failures
        this.flow = flow
    }
}

public struct SnapshotDiffResult {
    public let passed: Bool
    public let line: Int64
    public let column: Int64
    public let expectedLine: String
    public let actualLine: String
    public let message: String

    public init(
        passed: Bool,
        line!: Int64 = -1,
        column!: Int64 = -1,
        expectedLine!: String = "",
        actualLine!: String = "",
        message!: String = ""
    ) {
        this.passed = passed
        this.line = line
        this.column = column
        this.expectedLine = expectedLine
        this.actualLine = actualLine
        this.message = message
    }
}

public class SnapshotDiff {
    public static func text(expected: String, actual: String): SnapshotDiffResult {
        if (expected == actual) {
            return SnapshotDiffResult(true, message: "snapshots match")
        }
        let expectedLines = splitLines(expected)
        let actualLines = splitLines(actual)
        let count = max(expectedLines.size, actualLines.size)
        for (line in 0..count) {
            let e = if (line < expectedLines.size) { expectedLines[line] } else { "" }
            let a = if (line < actualLines.size) { actualLines[line] } else { "" }
            if (e != a) {
                let column = firstDiffColumn(e, a)
                return SnapshotDiffResult(
                    false,
                    line: line,
                    column: column,
                    expectedLine: e,
                    actualLine: a,
                    message: "snapshot mismatch at ${line}:${column}\nexpected: ${e}\nactual: ${a}"
                )
            }
        }
        SnapshotDiffResult(false, message: "snapshot mismatch")
    }

    public static func buffer(expected: Buffer, actual: Buffer): SnapshotDiffResult {
        text(bufferSnapshot(expected), bufferSnapshot(actual))
    }
}

func firstDiffColumn(expected: String, actual: String): Int64 {
    let limit = min(expected.size, actual.size)
    var i: Int64 = 0
    while (i < limit) {
        if (expected[i] != actual[i]) { return i }
        i++
    }
    i
}

public class EventScenario {
    public let name: String
    private let steps = ArrayList<ScenarioStep>()

    public init(name!: String = "scenario") {
        this.name = name
    }

    public func add(step: ScenarioStep): EventScenario {
        steps.add(step)
        this
    }

    public func event(event: Event): EventScenario {
        add(ScenarioStep.Input(event))
    }

    public func key(key: KeyEvent): EventScenario {
        event(Event.KeyDown(key))
    }

    public func paste(text: String): EventScenario {
        event(Event.Paste(text))
    }

    public func message(text: String): EventScenario {
        event(Event.Message(text))
    }

    public func tick(): EventScenario {
        event(Event.Tick(TickEvent()))
    }

    public func expectFlow(flow: ControlFlow): EventScenario {
        add(ScenarioStep.ExpectFlow(flow))
    }

    public func expectSnapshot(snapshot: String): EventScenario {
        add(ScenarioStep.ExpectSnapshot(snapshot))
    }

    public func expectCell(x: Int64, y: Int64, symbol: String): EventScenario {
        add(ScenarioStep.ExpectCell(x, y, symbol))
    }

    public func size(): Int64 {
        steps.size
    }

    public static func fromText(text: String): EventScenario {
        var scenario = EventScenario()
        for (line in splitLines(text)) {
            let trimmed = trimAscii(line)
            if (trimmed.isEmpty()) { continue }
            if (trimmed.startsWith("scenario:")) {
                scenario = EventScenario(name: trimmed[9..])
            } else if (trimmed == "tick") {
                scenario.tick()
            } else if (trimmed == "ctrl-c") {
                scenario.key(KeyEvent(KeyCode.CtrlC))
            } else if (trimmed.startsWith("message:")) {
                scenario.message(trimmed[8..])
            } else if (trimmed.startsWith("paste:")) {
                scenario.paste(trimmed[6..])
            } else if (trimmed.startsWith("key:")) {
                match (parseScriptKey(trimmed[4..])) {
                    case Some(key) => scenario.key(key)
                    case None => ()
                }
            } else if (trimmed.startsWith("resize:")) {
                match (parseScriptSize(trimmed[7..])) {
                    case Some(area) => scenario.event(Event.Resize(area))
                    case None => ()
                }
            } else if (trimmed.startsWith("expect:flow:")) {
                match (trimmed[12..]) {
                    case "exit" => scenario.expectFlow(ControlFlow.Exit)
                    case _ => scenario.expectFlow(ControlFlow.Continue)
                }
            } else if (trimmed.startsWith("expect:snapshot:")) {
                scenario.expectSnapshot(trimmed[16..])
            } else if (trimmed.startsWith("expect:cell:")) {
                let parts = splitBy(trimmed[12..], b',')
                if (parts.size >= 3) {
                    scenario.expectCell(parseIntOrZero(parts[0]), parseIntOrZero(parts[1]), parts[2])
                }
            }
        }
        scenario
    }

    public func run(backend: TestBackend, render: (Frame) -> Unit, update: (Event) -> UpdateResult): ScenarioResult {
        let terminal = Terminal(backend)
        let commandQueue = ArrayList<Command>()
        let asyncRuntime = AsyncRuntime()
        let failures = ArrayList<String>()
        var flow = ControlFlow.Continue
        terminal.draw(render)
        for (step in steps) {
            match (step) {
                case ScenarioStep.Input(inputEvent) =>
                    if (isContinue(flow)) {
                        if (!App.applyUpdateResult(update(inputEvent), commandQueue)) {
                            flow = ControlFlow.Exit
                        }
                        if (isContinue(flow) && !App.processCommands(update, commandQueue, asyncRuntime: asyncRuntime)) {
                            flow = ControlFlow.Exit
                        }
                        terminal.draw(render)
                    }
                case ScenarioStep.ExpectFlow(expected) =>
                    if (!sameFlow(flow, expected)) {
                        failures.add("flow mismatch")
                    }
                case ScenarioStep.ExpectSnapshot(expected) =>
                    let diff = SnapshotDiff.text(expected, backend.snapshot())
                    if (!diff.passed) {
                        failures.add(diff.message)
                    }
                case ScenarioStep.ExpectCell(x, y, symbol) =>
                    if (!backend.assertCell(x, y, symbol)) {
                        failures.add("cell mismatch at ${x},${y}")
                    }
            }
        }
        ScenarioResult(name, failures.size == 0, failures.toArray(), flow)
    }
}

public enum HeadlessStep {
    | Input(Event)
    | Tick(Int64)
    | WaitMillis(Int64)
    | Resize(Rect)
    | Render
    | ExpectSnapshot(String)
    | ExpectCell(Int64, Int64, String)
}

public class HeadlessScript {
    private let items = ArrayList<HeadlessStep>()

    public init(steps!: Array<HeadlessStep> = []) {
        for (step in steps) {
            items.add(step)
        }
    }

    public func add(step: HeadlessStep): HeadlessScript {
        items.add(step)
        this
    }

    public func event(event: Event): HeadlessScript { add(HeadlessStep.Input(event)) }
    public func key(key: KeyEvent): HeadlessScript { event(Event.KeyDown(key)) }
    public func mouse(event: MouseEvent): HeadlessScript { this.event(Event.Mouse(event)) }
    public func paste(text: String): HeadlessScript { event(Event.Paste(text)) }
    public func message(text: String): HeadlessScript { event(Event.Message(text)) }
    public func resize(area: Rect): HeadlessScript { add(HeadlessStep.Resize(area)) }
    public func tick(count!: Int64 = 1): HeadlessScript { add(HeadlessStep.Tick(count)) }
    public func waitMillis(milliseconds: Int64): HeadlessScript {
        add(HeadlessStep.WaitMillis(max(0, milliseconds)))
    }
    public func render(): HeadlessScript { add(HeadlessStep.Render) }
    public func expectSnapshot(snapshot: String): HeadlessScript { add(HeadlessStep.ExpectSnapshot(snapshot)) }
    public func expectCell(x: Int64, y: Int64, symbol: String): HeadlessScript { add(HeadlessStep.ExpectCell(x, y, symbol)) }

    public func steps(): Array<HeadlessStep> {
        items.toArray()
    }
}

public struct HeadlessRunOptions {
    public let area: Rect
    public let ticks: Int64
    public let tickDeltaMillis: Int64
    public let captureBuffers: Bool
    public let captureSnapshots: Bool

    public init(
        area!: Rect = Rect(0, 0, 80, 24),
        ticks!: Int64 = 0,
        tickDeltaMillis!: Int64 = 16,
        captureBuffers!: Bool = true,
        captureSnapshots!: Bool = true
    ) {
        this.area = area
        this.ticks = max(0, ticks)
        this.tickDeltaMillis = max(1, tickDeltaMillis)
        this.captureBuffers = captureBuffers
        this.captureSnapshots = captureSnapshots
    }
}

public class HeadlessRunResult {
    public let flow: ControlFlow
    public let frames: Array<Buffer>
    public let snapshots: Array<String>
    public let metrics: AppMetrics
    public let failures: Array<String>

    public init(flow: ControlFlow, frames: Array<Buffer>, snapshots: Array<String>, metrics: AppMetrics, failures: Array<String>) {
        this.flow = flow
        this.frames = frames
        this.snapshots = snapshots
        this.metrics = metrics
        this.failures = failures
    }

    public func passed(): Bool {
        failures.size == 0
    }
}

public class AppTestRunner {
    public static func run(script: HeadlessScript, render: (Frame) -> Unit, update: (Event) -> UpdateResult, options!: HeadlessRunOptions = HeadlessRunOptions()): HeadlessRunResult {
        let backend = TestBackend(
            area: options.area,
            captureSnapshots: options.captureSnapshots
        )
        let terminal = Terminal(backend)
        let commandQueue = ArrayList<Command>()
        let asyncRuntime = AsyncRuntime()
        let frames = ArrayList<Buffer>()
        let snapshots = ArrayList<String>()
        let metrics = AppMetrics()
        let failures = ArrayList<String>()
        var flow = ControlFlow.Continue
        var frameIndex: Int64 = 0
        var droppedTicks: Int64 = 0
        var lastTickDelta: Int64 = 0

        AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
        for (step in script.steps()) {
            match (step) {
                case HeadlessStep.Input(event) =>
                    flow = AppTestRunner.dispatch(event, update, commandQueue, asyncRuntime, flow)
                    frameIndex++
                    AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
                case HeadlessStep.Tick(count) =>
                    for (_ in 0..max(0, count)) {
                        frameIndex++
                        lastTickDelta = options.tickDeltaMillis
                        flow = AppTestRunner.dispatch(Event.Tick(TickEvent(deltaMillis: options.tickDeltaMillis, elapsedMillis: frameIndex * options.tickDeltaMillis, frameIndex: frameIndex)), update, commandQueue, asyncRuntime, flow)
                        AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
                    }
                case HeadlessStep.WaitMillis(milliseconds) =>
                    sleep(Duration.millisecond * milliseconds)
                    frameIndex++
                    flow = AppTestRunner.dispatch(
                        Event.Tick(TickEvent(
                            deltaMillis: milliseconds,
                            elapsedMillis: frameIndex * options.tickDeltaMillis,
                            frameIndex: frameIndex
                        )),
                        update,
                        commandQueue,
                        asyncRuntime,
                        flow
                    )
                    AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
                case HeadlessStep.Resize(area) =>
                    backend.setSize(area)
                    frameIndex++
                    flow = AppTestRunner.dispatch(Event.Resize(area), update, commandQueue, asyncRuntime, flow)
                    AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
                case HeadlessStep.Render =>
                    frameIndex++
                    AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
                case HeadlessStep.ExpectSnapshot(expected) =>
                    let diff = SnapshotDiff.text(expected, backend.snapshot())
                    if (!diff.passed) { failures.add(diff.message) }
                case HeadlessStep.ExpectCell(x, y, symbol) =>
                    if (!backend.assertCell(x, y, symbol)) {
                        failures.add("cell mismatch at ${x},${y}")
                    }
            }
        }
        for (_ in 0..options.ticks) {
            frameIndex++
            lastTickDelta = options.tickDeltaMillis
            flow = AppTestRunner.dispatch(Event.Tick(TickEvent(deltaMillis: options.tickDeltaMillis, elapsedMillis: frameIndex * options.tickDeltaMillis, frameIndex: frameIndex)), update, commandQueue, asyncRuntime, flow)
            AppTestRunner.capture(terminal, backend, render, options, frames, snapshots, metrics, frameIndex, commandQueue.size, droppedTicks, lastTickDelta)
        }
        HeadlessRunResult(flow, frames.toArray(), snapshots.toArray(), metrics, failures.toArray())
    }

    private static func dispatch(event: Event, update: (Event) -> UpdateResult, commandQueue: ArrayList<Command>, asyncRuntime: AsyncRuntime, flow: ControlFlow): ControlFlow {
        if (!isContinue(flow)) { return flow }
        if (!App.applyUpdateResult(update(event), commandQueue)) {
            return ControlFlow.Exit
        }
        if (!App.processCommands(update, commandQueue, asyncRuntime: asyncRuntime)) {
            return ControlFlow.Exit
        }
        ControlFlow.Continue
    }

    private static func capture(
        terminal: Terminal,
        backend: TestBackend,
        render: (Frame) -> Unit,
        options: HeadlessRunOptions,
        frames: ArrayList<Buffer>,
        snapshots: ArrayList<String>,
        metrics: AppMetrics,
        frameIndex: Int64,
        eventQueueLength: Int64,
        droppedTicks: Int64,
        tickDeltaMillis: Int64
    ): Unit {
        let renderMetrics = terminal.draw(render)
        metrics.record(renderMetrics, frameIndex: frameIndex, eventQueueLength: eventQueueLength, droppedTicks: droppedTicks, tickDeltaMillis: tickDeltaMillis)
        if (options.captureBuffers) {
            match (backend.lastBuffer()) {
                case Some(buffer) => frames.add(buffer.copy())
                case None => ()
            }
        }
        if (options.captureSnapshots) {
            snapshots.add(backend.snapshot())
        }
    }
}

func trimAscii(text: String): String {
    var start: Int64 = 0
    var end: Int64 = text.size
    while (start < end && isTrimByte(text[start])) { start++ }
    while (end > start && isTrimByte(text[end - 1])) { end-- }
    text[start..end]
}

func parseScriptKey(value: String): ?KeyEvent {
    match (value) {
        case "enter" => Some(KeyEvent(KeyCode.Enter))
        case "esc" => Some(KeyEvent(KeyCode.Esc))
        case "tab" => Some(KeyEvent(KeyCode.Tab))
        case "backtab" => Some(KeyEvent(KeyCode.BackTab))
        case "up" => Some(KeyEvent(KeyCode.Up))
        case "down" => Some(KeyEvent(KeyCode.Down))
        case "left" => Some(KeyEvent(KeyCode.Left))
        case "right" => Some(KeyEvent(KeyCode.Right))
        case "home" => Some(KeyEvent(KeyCode.Home))
        case "end" => Some(KeyEvent(KeyCode.End))
        case "pageup" => Some(KeyEvent(KeyCode.PageUp))
        case "pagedown" => Some(KeyEvent(KeyCode.PageDown))
        case "ctrl-s" => Some(KeyEvent(KeyCode.Char(r's'), modifiers: KeyModifier(ctrl: true)))
        case "ctrl-z" => Some(KeyEvent(KeyCode.Char(r'z'), modifiers: KeyModifier(ctrl: true)))
        case "ctrl-y" => Some(KeyEvent(KeyCode.Char(r'y'), modifiers: KeyModifier(ctrl: true)))
        case _ =>
            if (!value.isEmpty()) {
                let (r, _) = Rune.fromUtf8(unsafe { value.rawData() }, 0)
                Some(KeyEvent(KeyCode.Char(r)))
            } else {
                None
            }
    }
}

func parseScriptSize(value: String): ?Rect {
    let parts = splitBy(value, b'x')
    if (parts.size != 2) { return None }
    Some(Rect(0, 0, parseIntOrZero(parts[0]), parseIntOrZero(parts[1])))
}

func splitBy(value: String, sep: Byte): Array<String> {
    let parts = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < value.size) {
        if (value[i] == sep) {
            parts.add(value[start..i])
            start = i + 1
        }
        i++
    }
    parts.add(value[start..])
    parts.toArray()
}

func parseIntOrZero(value: String): Int64 {
    var out: Int64 = 0
    for (b in unsafe { value.rawData() }) {
        if (b < b'0' || b > b'9') { return out }
        out = out * 10 + Int64(b - b'0')
    }
    out
}

func isTrimByte(b: Byte): Bool {
    b == b' ' || b == b'\t' || b == b'\r' || b == b'\n'
}

func isContinue(flow: ControlFlow): Bool {
    match (flow) {
        case ControlFlow.Continue => true
        case ControlFlow.Exit => false
    }
}

func isExit(flow: ControlFlow): Bool {
    !isContinue(flow)
}

func eventPropagationFromHandle(result: HandleResult): EventPropagation {
    if (isExit(result.flow)) { return EventPropagation.Exit }
    if (result.handled) { return EventPropagation.Stop }
    EventPropagation.Continue
}

func sameFlow(left: ControlFlow, right: ControlFlow): Bool {
    match (left) {
        case ControlFlow.Continue =>
            match (right) {
                case ControlFlow.Continue => true
                case ControlFlow.Exit => false
            }
        case ControlFlow.Exit =>
            match (right) {
                case ControlFlow.Exit => true
                case ControlFlow.Continue => false
            }
    }
}

public class App {
    private let backend: Backend
    private let inputSource: InputSource
    private let terminalDriver: TerminalDriver
    private let probeInputSource: InputSource
    private let rawMode: Bool
    private let alternateScreen: Bool
    private let mouse: Bool
    private let mouseMove: Bool
    private let focusEvents: Bool
    private let bracketedPaste: Bool
    private let hideCursor: Bool
    private let keyboard: KeyboardOptions
    private let resize: Bool
    private let tickEvery: ?Duration
    private let missPolicy: FrameMissPolicy
    private let idleSleep: Duration
    private let resizePollEvery: Duration
    private let ptyRuntime: PtyRuntime
    private let eventWaiter: EventWaiter
    private let metrics: ?AppMetrics
    private let renderMode: RenderMode
    private let traceSink: ?AppTraceSink

    public init(
        backend!: Backend = AnsiBackend(),
        inputSource!: InputSource = StdinInputSource(),
        terminalDriver!: TerminalDriver = defaultTerminalDriver(),
        probeInputSource!: InputSource = StdinInputSource(),
        renderMode!: RenderMode = RenderMode.Diff,
        rawMode!: Bool = true,
        alternateScreen!: Bool = true,
        mouse!: Bool = false,
        mouseMove!: Bool = false,
        focusEvents!: Bool = false,
        bracketedPaste!: Bool = true,
        hideCursor!: Bool = true,
        keyboard!: KeyboardOptions = KeyboardOptions(),
        resize!: Bool = true,
        tickEvery!: ?Duration = None,
        targetFps!: ?Int64 = None,
        missPolicy!: FrameMissPolicy = FrameMissPolicy.Drop,
        idleSleep!: Duration = Duration.millisecond * 10,
        resizePollEvery!: Duration = Duration.millisecond * 250,
        ptyRuntime!: PtyRuntime = UnsupportedPtyRuntime(),
        eventWaiter!: EventWaiter = defaultEventWaiter(),
        metrics!: ?AppMetrics = None,
        traceSink!: ?AppTraceSink = None
    ) {
        this.backend = backend
        this.inputSource = inputSource
        this.terminalDriver = terminalDriver
        this.probeInputSource = probeInputSource
        this.renderMode = renderMode
        this.rawMode = rawMode
        this.alternateScreen = alternateScreen
        this.mouse = mouse
        this.mouseMove = mouseMove
        this.focusEvents = focusEvents
        this.bracketedPaste = bracketedPaste
        this.hideCursor = hideCursor
        this.keyboard = keyboard
        this.resize = resize
        this.tickEvery = App.resolveTickEvery(tickEvery, targetFps)
        this.missPolicy = missPolicy
        this.idleSleep = if (idleSleep <= Duration.Zero) { Duration.Zero } else { idleSleep }
        this.resizePollEvery = if (resizePollEvery <= Duration.Zero) { Duration.millisecond * 250 } else { resizePollEvery }
        this.ptyRuntime = ptyRuntime
        this.eventWaiter = eventWaiter
        this.metrics = metrics
        this.traceSink = traceSink
    }

    public func run(render: (Frame) -> Unit, update: (Event) -> ControlFlow): Unit {
        runWithCommands(render, { event => UpdateResult(flow: update(event)) })
    }

    public func runWithCommands(render: (Frame) -> Unit, update: (Event) -> UpdateResult): Unit {
        let terminal = Terminal(backend, renderMode: renderMode)
        let parser = EventParser(inputSource: inputSource)
        let commandQueue = ArrayList<Command>()
        let pendingInputEvents = ArrayList<Event>()
        let asyncRuntime = AsyncRuntime()
        let timerRuntime = TimerRuntime()
        let lifecycle = TerminalLifecycleRequests()
        let session = TerminalSession(
            backend,
            driver: terminalDriver,
            probeInputSource: probeInputSource,
            rawMode: rawMode,
            alternateScreen: alternateScreen,
            mouse: mouse,
            mouseMove: mouseMove,
            focusEvents: focusEvents,
            bracketedPaste: bracketedPaste,
            hideCursor: hideCursor,
            keyboard: keyboard
        )
        session.run {
            try {
                var running = true
                var pendingInputIndex: Int64 = 0
                var lastSize = backend.size()
                var dirty = true
                let pendingDirty = DirtyRects()
                var frameIndex: Int64 = 0
                var droppedTickCount: Int64 = 0
                var lastTickDelta: Int64 = 0
                let startedAt = MonoTime.now()
                var lastLoopStartedAt = startedAt
                var lastLoopTask = "startup"
                var lastTick = startedAt
                var nextTick: ?MonoTime = match (tickEvery) {
                    case Some(every) => Some(startedAt + every)
                    case None => None
                }
                running = App.applyUpdateResult(
                    dispatchUpdate(
                        update,
                        Event.Capabilities(terminalDriver.capabilities(backend)),
                        commandQueue.size
                    ),
                    commandQueue,
                    dirtySink: Some(pendingDirty)
                )
                if (running) {
                    let (nextRunning, changed) = App.processCommandsWithLifecycle(
                        {event => dispatchUpdate(update, event, commandQueue.size)},
                        commandQueue,
                        asyncRuntime,
                        ptyRuntime,
                        timerRuntime,
                        Some(pendingDirty),
                        Some(lifecycle)
                    )
                    running = nextRunning
                    if (changed) { dirty = true }
                }
                while (running) {
                    let loopStartedAt = MonoTime.now()
                    let loopInterval = (loopStartedAt - lastLoopStartedAt).toNanoseconds()
                    // A deliberate blocking wait is idle time, not an event
                    // loop stall. Reporting every normal 250 ms wait creates
                    // diagnostic traffic while the application is otherwise
                    // quiescent and obscures actual render/update stalls.
                    if (lastLoopTask != "event_wait" && loopInterval > 100_000_000) {
                        match (traceSink) {
                            case Some(trace) => trace.eventLoopStall(lastLoopTask, loopInterval)
                            case None => ()
                        }
                    }
                    lastLoopStartedAt = loopStartedAt
                    lastLoopTask = "event_processing"
                    if (lifecycle.suspendRequested) {
                        lifecycle.suspendRequested = false
                        session.stop()
                        App.suspendCurrentProcess()
                        _ = session.start()
                        terminal.clear()
                        pendingDirty.clear()
                        dirty = true
                    }
                    if (lifecycle.resetRequested) {
                        lifecycle.resetRequested = false
                        terminal.clear()
                        pendingDirty.clear()
                        dirty = true
                    }
                    let now = MonoTime.now()
                    let currentSize = backend.size()
                    if (resize && currentSize != lastSize) {
                        pendingDirty.clear()
                        running = App.applyUpdateResult(
                            dispatchUpdate(update, Event.Resize(currentSize), commandQueue.size),
                            commandQueue,
                            dirtySink: Some(pendingDirty)
                        )
                        if (running) {
                            let (nextRunning, _) = App.processCommandsWithLifecycle(
                                {event => dispatchUpdate(update, event, commandQueue.size)},
                                commandQueue,
                                asyncRuntime,
                                ptyRuntime,
                                timerRuntime,
                                Some(pendingDirty),
                                Some(lifecycle)
                            )
                            running = nextRunning
                        }
                        dirty = true
                        lastSize = currentSize
                    }
                    for (event in timerRuntime.drain(now)) {
                        if (running) {
                            running = App.applyUpdateResult(
                                dispatchUpdate(update, event, commandQueue.size),
                                commandQueue,
                                dirtySink: Some(pendingDirty)
                            )
                            dirty = true
                            if (running) {
                                let (nextRunning, _) = App.processCommandsWithLifecycle(
                                    {event => dispatchUpdate(update, event, commandQueue.size)},
                                    commandQueue,
                                    asyncRuntime,
                                    ptyRuntime,
                                    timerRuntime,
                                    Some(pendingDirty),
                                    Some(lifecycle)
                                )
                                running = nextRunning
                            }
                        }
                    }
                    if (dirty) {
                        match (traceSink) {
                            case Some(trace) => trace.renderStarted()
                            case None => ()
                        }
                        let renderMetrics = if (pendingDirty.isEmpty()) {
                            terminal.draw(render)
                        } else {
                            terminal.draw(render, dirtyRects: Some(pendingDirty.copy()))
                        }
                        match (metrics) {
                            case Some(m) => m.record(
                                renderMetrics,
                                frameIndex: frameIndex,
                                eventQueueLength: max(0, pendingInputEvents.size - pendingInputIndex) + commandQueue.size,
                                droppedTicks: droppedTickCount,
                                tickDeltaMillis: lastTickDelta
                            )
                            case None => ()
                        }
                        dirty = false
                        pendingDirty.clear()
                    }
                    match (nextTick) {
                        case Some(due) =>
                            if (running && now >= due) {
                                let every = match (tickEvery) {
                                    case Some(value) => value
                                    case None => Duration.millisecond
                                }
                                let dropped = droppedFrames(now - due, every, missPolicy)
                                frameIndex++
                                droppedTickCount += dropped
                                lastTickDelta = durationMillis(now - lastTick)
                                running = App.applyUpdateResult(
                                    dispatchUpdate(
                                        update,
                                        Event.Tick(TickEvent(
                                            deltaMillis: lastTickDelta,
                                            elapsedMillis: durationMillis(now - startedAt),
                                            frameIndex: frameIndex,
                                            droppedFrames: dropped
                                        )),
                                        commandQueue.size
                                    ),
                                    commandQueue,
                                    dirtySink: Some(pendingDirty)
                                )
                                lastTick = now
                                nextTick = Some(nextDue(now, due, every, missPolicy))
                                dirty = true
                                if (running) {
                                    let (nextRunning, _) = App.processCommandsWithLifecycle(
                                        {event => dispatchUpdate(update, event, commandQueue.size)},
                                        commandQueue,
                                        asyncRuntime,
                                        ptyRuntime,
                                        timerRuntime,
                                        Some(pendingDirty),
                                        Some(lifecycle)
                                    )
                                    running = nextRunning
                                }
                            } else if (running) {
                                let (nextRunning, changed) = App.processCommandsWithLifecycle(
                                    {event => dispatchUpdate(update, event, commandQueue.size)},
                                    commandQueue,
                                    asyncRuntime,
                                    ptyRuntime,
                                    timerRuntime,
                                    Some(pendingDirty),
                                    Some(lifecycle)
                                )
                                running = nextRunning
                                dirty = dirty || changed
                            }
                        case None =>
                            if (running) {
                                let (nextRunning, changed) = App.processCommandsWithLifecycle(
                                    {event => dispatchUpdate(update, event, commandQueue.size)},
                                    commandQueue,
                                    asyncRuntime,
                                    ptyRuntime,
                                    timerRuntime,
                                    Some(pendingDirty),
                                    Some(lifecycle)
                                )
                                running = nextRunning
                                dirty = dirty || changed
                            }
                    }
                    if (pendingInputIndex >= pendingInputEvents.size) {
                        pendingInputEvents.clear()
                        pendingInputIndex = 0
                        for (event in coalescePendingScrollReversal(parser.readEvents())) {
                            pendingInputEvents.add(event)
                        }
                    }
                    if (pendingInputIndex < pendingInputEvents.size) {
                        // Paint between buffered input events.  Draining the
                        // complete parser batch before rendering makes key
                        // repeat appear as groups of characters even when each
                        // individual composer update is fast.
                        // Keep a cursor instead of shifting the ArrayList for
                        // every repeated key.  Large terminal bursts therefore
                        // remain linear rather than quadratic.
                        let event = pendingInputEvents[pendingInputIndex]
                        pendingInputIndex++
                        let result = dispatchUpdate(
                            update,
                            event,
                            max(0, pendingInputEvents.size - pendingInputIndex) + commandQueue.size
                        )
                        running = App.applyUpdateResult(result, commandQueue, dirtySink: Some(pendingDirty))
                        dirty = dirty || result.renderRequested
                        if (running) {
                            let (nextRunning, changed) = App.processCommandsWithLifecycle(
                                {event => dispatchUpdate(update, event, commandQueue.size)},
                                commandQueue,
                                asyncRuntime,
                                ptyRuntime,
                                timerRuntime,
                                Some(pendingDirty),
                                Some(lifecycle)
                            )
                            running = nextRunning
                            dirty = dirty || changed
                        }
                        // A large decoded burst can otherwise force a full
                        // render after every queued event.  Once the backlog
                        // crosses the high-water mark, preserve event order
                        // but consume the current decoded snapshot (up to a
                        // fixed fairness cap) before the next paint. A time
                        // slice here can repeatedly interleave an expensive
                        // paint with a growing backlog, so it does not provide
                        // fairness in practice. Small interactive bursts retain
                        // the existing paint-between-keys behavior.
                        if (running && pendingInputEvents.size - pendingInputIndex >= 4) {
                            var batchCount: Int64 = 0
                            while (
                                running &&
                                pendingInputIndex < pendingInputEvents.size &&
                                batchCount < 256
                            ) {
                                let queuedEvent = pendingInputEvents[pendingInputIndex]
                                pendingInputIndex++
                                batchCount++
                                let queuedResult = dispatchUpdate(
                                    update,
                                    queuedEvent,
                                    max(0, pendingInputEvents.size - pendingInputIndex) + commandQueue.size
                                )
                                running = App.applyUpdateResult(
                                    queuedResult,
                                    commandQueue,
                                    dirtySink: Some(pendingDirty)
                                )
                                dirty = dirty || queuedResult.renderRequested
                                if (running) {
                                    let (nextRunning, changed) = App.processCommandsWithLifecycle(
                                        {event => dispatchUpdate(update, event, commandQueue.size)},
                                        commandQueue,
                                        asyncRuntime,
                                        ptyRuntime,
                                        timerRuntime,
                                        Some(pendingDirty),
                                        Some(lifecycle)
                                    )
                                    running = nextRunning
                                    dirty = dirty || changed
                                }
                            }
                        }
                    } else {
                            var flushed = false
                            let escPolls = max(1, keyboard.escDelayMillis / max(1, durationMillis(idleSleep)))
                            for (event in parser.flushEscAfterPolls(escPolls)) {
                                flushed = true
                                if (running) {
                                    let result = dispatchUpdate(update, event, commandQueue.size)
                                    running = App.applyUpdateResult(result, commandQueue, dirtySink: Some(pendingDirty))
                                    dirty = dirty || result.renderRequested
                                    if (running) {
                                        let (nextRunning, changed) = App.processCommandsWithLifecycle(
                                            {event => dispatchUpdate(update, event, commandQueue.size)},
                                            commandQueue,
                                            asyncRuntime,
                                            ptyRuntime,
                                            timerRuntime,
                                            Some(pendingDirty),
                                            Some(lifecycle)
                                        )
                                        running = nextRunning
                                        dirty = dirty || changed
                                    }
                                }
                            }
                            if (running && !flushed && commandQueue.size == 0 && !parser.hasPendingInputDrain()) {
                                lastLoopTask = "event_wait"
                                eventWaiter.wait(waitTimeoutMillis(asyncRuntime, timerRuntime, nextTick), previousReadBytes: parser.lastReadBytes(), sources: ptyRuntime.sources())
                            }
                    }
                }
            } finally {
                timerRuntime.clear()
                asyncRuntime.cancelAll()
                lifecycle.closeOwnedPtys(ptyRuntime)
                try {
                    eventWaiter.close()
                } catch (_: Exception) {
                    // Do not replace the application/session failure with a
                    // best-effort waiter cleanup failure.
                }
            }
        }
    }

    private func dispatchUpdate(
        update: (Event) -> UpdateResult,
        event: Event,
        eventQueueLength: Int64
    ): UpdateResult {
        let started = MonoTime.now()
        match (traceSink) {
            case Some(trace) =>
                trace.inputReceived(event, max(0, eventQueueLength))
                trace.eventDispatchCompleted()
            case None => ()
        }
        let result = update(event)
        let elapsed = (MonoTime.now() - started).toNanoseconds()
        match (traceSink) {
            case Some(trace) =>
                trace.stateUpdateCompleted()
                if (elapsed > 100_000_000) {
                    trace.eventLoopStall("state_update", elapsed)
                }
            case None => ()
        }
        result
    }

    private func waitTimeoutMillis(asyncRuntime: AsyncRuntime, timerRuntime: TimerRuntime, nextTick: ?MonoTime): Int64 {
        let now = MonoTime.now()
        var wait: ?Int64 = match (nextTick) {
            case Some(due) => Some(if (due <= now) { Int64(0) } else { durationMillis(due - now) })
            case None => None
        }
        match (timerRuntime.nextTimeoutMillis(now)) {
            case Some(value) =>
                wait = match (wait) {
                    case Some(current) => Some(min(current, value))
                    case None => Some(value)
                }
            case None => ()
        }
        if (resize) {
            wait = match (wait) {
                case Some(current) => Some(min(current, durationMillis(resizePollEvery)))
                case None => Some(durationMillis(resizePollEvery))
            }
        }
        if (asyncRuntime.pendingCount() > 0) {
            wait = match (wait) {
                case Some(current) => Some(min(current, durationMillis(idleSleep)))
                case None => Some(durationMillis(idleSleep))
            }
        }
        match (wait) {
            case Some(value) => max(0, value)
            case None => -1
        }
    }

    public static func applyUpdateResult(result: UpdateResult, commandQueue: ArrayList<Command>, dirtySink!: ?DirtyRects = None): Bool {
        App.enqueue(result.command, commandQueue)
        match ((dirtySink, result.dirtyRects)) {
            case (Some(sink), Some(rects)) => sink.addAll(rects)
            case _ => ()
        }
        match (result.flow) {
            case ControlFlow.Continue => true
            case ControlFlow.Exit => false
        }
    }

    public static func processCommands(
        update: (Event) -> UpdateResult,
        commandQueue: ArrayList<Command>,
        asyncRuntime!: AsyncRuntime = AsyncRuntime(),
        ptyRuntime!: PtyRuntime = UnsupportedPtyRuntime(),
        timerRuntime!: TimerRuntime = TimerRuntime()
    ): Bool {
        let (running, _) = App.processCommandsWithEvents(update, commandQueue, asyncRuntime: asyncRuntime, ptyRuntime: ptyRuntime, timerRuntime: timerRuntime)
        running
    }

    public static func processCommandsWithEvents(
        update: (Event) -> UpdateResult,
        commandQueue: ArrayList<Command>,
        asyncRuntime!: AsyncRuntime = AsyncRuntime(),
        ptyRuntime!: PtyRuntime = UnsupportedPtyRuntime(),
        timerRuntime!: TimerRuntime = TimerRuntime(),
        dirtySink!: ?DirtyRects = None
    ): (Bool, Bool) {
        App.processCommandsWithLifecycle(
            update,
            commandQueue,
            asyncRuntime,
            ptyRuntime,
            timerRuntime,
            dirtySink,
            None
        )
    }

    private static func processCommandsWithLifecycle(
        update: (Event) -> UpdateResult,
        commandQueue: ArrayList<Command>,
        asyncRuntime: AsyncRuntime,
        ptyRuntime: PtyRuntime,
        timerRuntime: TimerRuntime,
        dirtySink: ?DirtyRects,
        lifecycle: ?TerminalLifecycleRequests
    ): (Bool, Bool) {
        var changed = false
        while (commandQueue.size > 0) {
            let command = commandQueue[0]
            commandQueue.remove(at: 0)
            match (command) {
                case Command.Noop => ()
                case Command.Quit => return (false, changed)
                case Command.Emit(event) =>
                    changed = true
                    if (!App.applyUpdateResult(update(event), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.Message(text) =>
                    changed = true
                    if (!App.applyUpdateResult(update(Event.Message(text)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.Async(name) =>
                    changed = true
                    if (!App.applyUpdateResult(update(asyncRuntime.start(name, { => Event.Message("async:" + name) })), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.AsyncTask(id, task) =>
                    changed = true
                    if (!App.applyUpdateResult(update(asyncRuntime.start(id, task)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.AsyncExec(id, commandLine) =>
                    changed = true
                    if (!App.applyUpdateResult(update(asyncRuntime.startExec(id, commandLine)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.AsyncExecArgs(id, program, args) =>
                    changed = true
                    if (!App.applyUpdateResult(update(asyncRuntime.startExecArgs(id, program, args)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.CancelAsync(id) =>
                    if (asyncRuntime.cancel(id)) {
                        changed = true
                        if (!App.applyUpdateResult(update(Event.AsyncCancelled(id)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                    }
                case Command.PtyStart(id, spec) =>
                    changed = true
                    let event = ptyRuntime.start(id, spec)
                    match (event) {
                        case Event.PtyStarted(_) => match (lifecycle) {
                            case Some(requests) => requests.trackPty(id)
                            case None => ()
                        }
                        case _ => ()
                    }
                    if (!App.applyUpdateResult(update(event), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.PtyWrite(id, bytes) =>
                    changed = true
                    if (!App.applyUpdateResult(update(ptyRuntime.write(id, bytes)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.PtyResize(id, size) =>
                    changed = true
                    if (!App.applyUpdateResult(update(ptyRuntime.resize(id, size)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.PtySendSignal(id, signal) =>
                    changed = true
                    if (!App.applyUpdateResult(update(ptyRuntime.signal(id, signal)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.PtyClose(id) =>
                    changed = true
                    let event = ptyRuntime.close(id)
                    match (event) {
                        case Event.PtyExited(_, _) => match (lifecycle) {
                            case Some(requests) => requests.releasePty(id)
                            case None => ()
                        }
                        case _ => ()
                    }
                    if (!App.applyUpdateResult(update(event), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.StartTimer(spec) =>
                    timerRuntime.start(spec, MonoTime.now())
                case Command.StopTimer(id) =>
                    _ = timerRuntime.stop(id)
                case Command.RestartTimer(spec) =>
                    _ = timerRuntime.stop(spec.id)
                    timerRuntime.start(spec, MonoTime.now())
                case Command.Exec(commandLine) =>
                    changed = true
                    if (!App.applyUpdateResult(update(App.executeCommand(commandLine)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.ExecArgs(id, program, args) =>
                    changed = true
                    if (!App.applyUpdateResult(update(App.executeCommandArgs(id, program, args)), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
                case Command.ResetTerminal =>
                    changed = true
                    match (lifecycle) {
                        case Some(requests) => requests.resetRequested = true
                        case None => ()
                    }
                case Command.Suspend =>
                    changed = true
                    match (lifecycle) {
                        case Some(requests) => requests.suspendRequested = true
                        case None => ()
                    }
                case Command.Batch(commands) =>
                    for (item in commands) {
                        App.enqueue(item, commandQueue)
                    }
            }
        }
        for (event in asyncRuntime.drain()) {
            changed = true
            if (!App.applyUpdateResult(update(event), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
        }
        for (event in ptyRuntime.drain()) {
            changed = true
            match (event) {
                case Event.PtyExited(id, _) => match (lifecycle) {
                    case Some(requests) => requests.releasePty(id)
                    case None => ()
                }
                case Event.PtyFailed(id, _) => match (lifecycle) {
                    case Some(requests) => requests.releasePty(id)
                    case None => ()
                }
                case _ => ()
            }
            if (!App.applyUpdateResult(update(event), commandQueue, dirtySink: dirtySink)) { return (false, changed) }
        }
        if (commandQueue.size > 0) {
            let (running, nestedChanged) = App.processCommandsWithLifecycle(update, commandQueue, asyncRuntime, ptyRuntime, timerRuntime, dirtySink, lifecycle)
            return (running, changed || nestedChanged)
        }
        (true, changed)
    }

    @When[os != "Windows"]
    private static func suspendCurrentProcess(): Unit {
        unsafe { _ = kill(getpid(), APP_SIGTSTP) }
    }

    @When[os == "Windows"]
    private static func suspendCurrentProcess(): Unit {}

    private static func resolveTickEvery(
        explicit: ?Duration,
        targetFps: ?Int64
    ): ?Duration {
        match (explicit) {
            case Some(value) => return Some(if (value <= Duration.Zero) { Duration.millisecond } else { value })
            case None => ()
        }
        match (targetFps) {
            case Some(fps) =>
                let clamped = max(1, fps)
                return Some(Duration.millisecond * max(1, 1000 / clamped))
            case None => ()
        }
        None
    }

    public static func executeCommand(commandLine: String): Event {
        let parts = splitCommandLine(commandLine)
        if (parts.size == 0) {
            return Event.ExecResult(commandLine, 127, "empty command")
        }
        App.executeCommandArgs(commandLine, parts[0], parts[1..])
    }

    public static func executeCommandArgs(id: String, program: String, args: Array<String>): Event {
        if (program.isEmpty()) {
            return Event.ExecResult(id, 127, "empty command")
        }
        try {
            let (code, out, err) = executeWithOutput(program, args)
            let stdout = unsafe { String.fromUtf8Unchecked(out) }
            let stderr = unsafe { String.fromUtf8Unchecked(err) }
            Event.ExecResult(id, code, stdout + stderr)
        } catch (e: Exception) {
            Event.ExecResult(id, 127, e.message)
        }
    }

    private static func enqueue(command: Command, commandQueue: ArrayList<Command>): Unit {
        match (command) {
            case Command.Noop => ()
            case Command.Batch(commands) =>
                for (item in commands) {
                    App.enqueue(item, commandQueue)
                }
            case _ => commandQueue.add(command)
        }
    }

}

// Input in one parser batch has not been painted yet.  If a contiguous wheel
// burst reverses direction, retaining the older direction makes the UI replay
// stale movement before reacting to the user's latest intent.  Keep only the
// final direction in that burst; all non-wheel events remain ordered and form
// hard coalescing boundaries.
func coalescePendingScrollReversal(events: Array<Event>): Array<Event> {
    let result = ArrayList<Event>()
    var scrollStart: Int64 = -1
    var scrollDirection: Int64 = 0
    for (event in events) {
        let direction = match (event) {
            case Event.Mouse(mouse) => match ((mouse.kind, mouse.button)) {
                case (MouseKind.Scroll, MouseButton.WheelUp) => 1
                case (MouseKind.Scroll, MouseButton.WheelDown) => -1
                case _ => 0
            }
            case _ => 0
        }
        if (direction == 0) {
            scrollStart = -1
            scrollDirection = 0
            result.add(event)
            continue
        }
        if (scrollStart < 0) {
            scrollStart = result.size
            scrollDirection = direction
        } else if (direction != scrollDirection) {
            while (result.size > scrollStart) {
                result.remove(at: result.size - 1)
            }
            scrollDirection = direction
        }
        result.add(event)
    }
    result.toArray()
}

public func defaultApp(): App {
    App()
}

public func runApp(render: (Frame) -> Unit, update: (Event) -> ControlFlow): Unit {
    defaultApp().run(render, update)
}

public func runAppWithCommands(render: (Frame) -> Unit, update: (Event) -> UpdateResult): Unit {
    defaultApp().runWithCommands(render, update)
}

@When[os == "Linux"]
public class LinuxEpollEventWaiter <: EventWaiter {
    private var epfd: Int32
    private var active: Bool = false
    private var closed: Bool = false
    private let registeredSources = ArrayList<EpollRegisteredSource>()

    public init() {
        epfd = unsafe { epoll_create1(0) }
        if (epfd >= 0) {
            let event = Array<UInt8>(EPOLL_EVENT_BYTES, repeat: 0)
            // Linux raw mode uses VMIN=0 so an empty read returns zero rather
            // than blocking.  Level-triggered epoll can consequently report
            // stdin as readable again after the parser has already drained
            // it.  Use edge-triggering and keep stdin registered: removing it
            // after an empty read silently degrades input to the 250 ms resize
            // poll, which makes key repeat and Backspace arrive in groups.
            writeUInt32LE(event, 0, EPOLLIN | EPOLLERR | EPOLLHUP | EPOLLET)
            writeInt32LE(event, 4, STDIN_FILENO)
            var added = false
            unsafe {
                let handle = acquireArrayRawData(event)
                added = epoll_ctl(epfd, EPOLL_CTL_ADD, STDIN_FILENO, CPointer<Unit>(handle.pointer)) == 0
                releaseArrayRawData(handle)
            }
            if (!added) {
                active = false
            } else {
                active = true
            }
        }
    }

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64 = 1, sources!: Array<EventSource> = []): Unit {
        if (epfd < 0) { return }
        reconcileSources(sources)
        let timeout = if (timeoutMillis < 0) {
            if (active) { Int32(-1) } else { Int32(1000) }
        } else {
            Int32(min(timeoutMillis, 1000))
        }
        let maxEvents = Int32(max(1, sources.size + 1))
        let events = Array<UInt8>(EPOLL_EVENT_BYTES * Int64(maxEvents), repeat: 0)
        var n: Int32 = 0
        unsafe {
            let handle = acquireArrayRawData(events)
            n = epoll_wait(epfd, CPointer<Unit>(handle.pointer), maxEvents, timeout)
            releaseArrayRawData(handle)
        }
        if (n > 0) {
            for (i in 0..Int64(n)) {
                let offset = i * EPOLL_EVENT_BYTES
                let flags = readUInt32LE(events, offset)
                let fd = readInt32LE(events, offset + 4)
                if (fd == STDIN_FILENO) {
                    if ((flags & (EPOLLERR | EPOLLHUP)) != 0) {
                        removeStdin()
                    }
                } else {
                    notifySource(sources, fd, flags)
                }
            }
        }
        if (previousReadBytes < -1) { return }
    }

    private func reconcileSources(sources: Array<EventSource>): Unit {
        if (epfd < 0) { return }
        let desired = desiredSourceRegistrations(sources)
        var index: Int64 = 0
        while (index < registeredSources.size) {
            let registered = registeredSources[index]
            if (!hasDesiredSource(desired, registered.fd)) {
                removeSourceFd(registered.fd)
                registeredSources.remove(at: index)
                continue
            }
            index++
        }
        for (source in desired) {
            let registeredIndex = registeredSourceIndex(source.fd)
            if (registeredIndex < 0) {
                if (addSourceFd(source.fd, source.events)) {
                    registeredSources.add(source)
                }
            } else if (registeredSources[registeredIndex].events != source.events) {
                if (modifySourceFd(source.fd, source.events)) {
                    registeredSources[registeredIndex].events = source.events
                } else {
                    removeSourceFd(source.fd)
                    if (addSourceFd(source.fd, source.events)) {
                        registeredSources[registeredIndex].events = source.events
                    } else {
                        registeredSources.remove(at: registeredIndex)
                    }
                }
            }
        }
    }

    private func desiredSourceRegistrations(sources: Array<EventSource>): ArrayList<EpollRegisteredSource> {
        let desired = ArrayList<EpollRegisteredSource>()
        for (source in sources) {
            match (source.fd()) {
                case Some(fd) =>
                    if (fd == STDIN_FILENO || hasDesiredSource(desired, fd)) {
                        continue
                    }
                    desired.add(EpollRegisteredSource(fd, interestsToEpoll(source.interests()) | EPOLLERR | EPOLLHUP))
                case None => ()
            }
        }
        desired
    }

    private func addSourceFd(fd: Int32, events: UInt32): Bool {
        epollCtlSource(EPOLL_CTL_ADD, fd, events)
    }

    private func modifySourceFd(fd: Int32, events: UInt32): Bool {
        epollCtlSource(EPOLL_CTL_MOD, fd, events)
    }

    private func removeSourceFd(fd: Int32): Bool {
        unsafe { epoll_ctl(epfd, EPOLL_CTL_DEL, fd, CPointer<Unit>()) == 0 }
    }

    private func epollCtlSource(op: Int32, fd: Int32, events: UInt32): Bool {
        let event = Array<UInt8>(EPOLL_EVENT_BYTES, repeat: 0)
        writeUInt32LE(event, 0, events)
        writeInt32LE(event, 4, fd)
        var ok = false
        unsafe {
            let handle = acquireArrayRawData(event)
            ok = epoll_ctl(epfd, op, fd, CPointer<Unit>(handle.pointer)) == 0
            releaseArrayRawData(handle)
        }
        ok
    }

    private func notifySource(sources: Array<EventSource>, fd: Int32, flags: UInt32): Unit {
        for (source in sources) {
            match (source.fd()) {
                case Some(sourceFd) =>
                    if (sourceFd == fd) {
                        source.onReady(
                            (flags & EPOLLIN) != 0,
                            (flags & EPOLLOUT) != 0,
                            (flags & EPOLLERR) != 0,
                            (flags & EPOLLHUP) != 0
                        )
                        return
                    }
                case None => ()
            }
        }
    }

    private func interestsToEpoll(interest: EventSourceInterest): UInt32 {
        match (interest) {
            case EventSourceInterest.Read => EPOLLIN
            case EventSourceInterest.Write => EPOLLOUT
            case EventSourceInterest.ReadWrite => EPOLLIN | EPOLLOUT
        }
    }

    public func close(): Unit {
        if (!closed && epfd >= 0) {
            unsafe { _ = close(epfd) }
            epfd = -1
            active = false
            while (registeredSources.size > 0) {
                registeredSources.remove(at: 0)
            }
            closed = true
        }
    }

    private func removeStdin(): Unit {
        if (!active || epfd < 0) { return }
        unsafe { _ = epoll_ctl(epfd, EPOLL_CTL_DEL, STDIN_FILENO, CPointer<Unit>()) }
        active = false
    }

    private func hasDesiredSource(sources: ArrayList<EpollRegisteredSource>, fd: Int32): Bool {
        for (source in sources) {
            if (source.fd == fd) { return true }
        }
        false
    }

    private func registeredSourceIndex(fd: Int32): Int64 {
        var index: Int64 = 0
        for (registered in registeredSources) {
            if (registered.fd == fd) { return index }
            index++
        }
        -1
    }
}

@When[os == "macOS"]
public class MacOSPollEventWaiter <: EventWaiter {
    private var closed: Bool = false

    public init() {}

    public func wait(timeoutMillis: Int64, previousReadBytes!: Int64 = 1, sources!: Array<EventSource> = []): Unit {
        if (closed) { return }
        let entries = pollEntries(sources)
        if (entries.size == 0) { return }
        let bytes = Array<UInt8>(POLLFD_BYTES * entries.size, repeat: 0)
        for (i in 0..entries.size) {
            let entry = entries[i]
            let offset = i * POLLFD_BYTES
            writeInt32LE(bytes, offset, entry.fd)
            writeInt16LE(bytes, offset + 4, entry.events)
            writeInt16LE(bytes, offset + 6, 0)
        }
        let timeout = if (timeoutMillis < 0) { Int32(-1) } else { Int32(min(timeoutMillis, 1000)) }
        var ready: Int32 = 0
        unsafe {
            let handle = acquireArrayRawData(bytes)
            ready = poll(CPointer<Unit>(handle.pointer), UInt32(entries.size), timeout)
            releaseArrayRawData(handle)
        }
        if (ready <= 0) { return }
        for (i in 0..entries.size) {
            let revents = readInt16LE(bytes, i * POLLFD_BYTES + 6)
            if (revents == 0) { continue }
            let entry = entries[i]
            match (entry.source) {
                case Some(source) => source.onReady(
                    (revents & POLLIN_FLAG) != 0,
                    (revents & POLLOUT_FLAG) != 0,
                    (revents & POLLERR_FLAG) != 0,
                    (revents & POLLHUP_FLAG) != 0
                )
                case None => ()
            }
        }
        if (previousReadBytes < -1) { return }
    }

    public func close(): Unit {
        closed = true
    }

    private func pollEntries(sources: Array<EventSource>): Array<PollRegisteredSource> {
        let entries = ArrayList<PollRegisteredSource>()
        entries.add(PollRegisteredSource(STDIN_FILENO, POLLIN_FLAG | POLLERR_FLAG | POLLHUP_FLAG))
        for (source in sources) {
            match (source.fd()) {
                case Some(fd) =>
                    if (fd == STDIN_FILENO || hasPollEntry(entries, fd)) { continue }
                    entries.add(PollRegisteredSource(fd, interestsToPoll(source.interests()) | POLLERR_FLAG | POLLHUP_FLAG, source: Some(source)))
                case None => ()
            }
        }
        entries.toArray()
    }

    private func hasPollEntry(entries: ArrayList<PollRegisteredSource>, fd: Int32): Bool {
        for (entry in entries) {
            if (entry.fd == fd) { return true }
        }
        false
    }

    private func interestsToPoll(interest: EventSourceInterest): Int16 {
        match (interest) {
            case EventSourceInterest.Read => POLLIN_FLAG
            case EventSourceInterest.Write => POLLOUT_FLAG
            case EventSourceInterest.ReadWrite => POLLIN_FLAG | POLLOUT_FLAG
        }
    }
}

@When[os == "Linux"]
class EpollRegisteredSource {
    let fd: Int32
    var events: UInt32

    init(fd: Int32, events: UInt32) {
        this.fd = fd
        this.events = events
    }
}

@When[os == "macOS"]
class PollRegisteredSource {
    let fd: Int32
    let events: Int16
    let source: ?EventSource

    init(fd: Int32, events: Int16, source!: ?EventSource = None) {
        this.fd = fd
        this.events = events
        this.source = source
    }
}

@When[os != "Windows"]
func writeUInt32LE(bytes: Array<UInt8>, offset: Int64, value: UInt32): Unit {
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
}

@When[os != "Windows"]
func writeInt32LE(bytes: Array<UInt8>, offset: Int64, value: Int32): Unit {
    writeUInt32LE(bytes, offset, UInt32(value))
}

@When[os == "macOS"]
func writeInt16LE(bytes: Array<UInt8>, offset: Int64, value: Int16): Unit {
    let raw = UInt16(value)
    bytes[offset] = UInt8(raw & 0xFF)
    bytes[offset + 1] = UInt8((raw >> 8) & 0xFF)
}

@When[os == "Linux"]
func readUInt32LE(bytes: Array<UInt8>, offset: Int64): UInt32 {
    UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
}

@When[os == "Linux"]
func readInt32LE(bytes: Array<UInt8>, offset: Int64): Int32 {
    Int32(readUInt32LE(bytes, offset))
}

@When[os == "macOS"]
func readInt16LE(bytes: Array<UInt8>, offset: Int64): Int16 {
    Int16(UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
}

func splitCommandLine(commandLine: String): Array<String> {
    let parts = ArrayList<String>()
    var current = ""
    var inQuote = false
    let bytes = unsafe { commandLine.rawData() }
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let (r, len) = Rune.fromUtf8(bytes, offset)
        if (r == r'"') {
            inQuote = !inQuote
        } else if (!inQuote && (r == r' ' || r == r'\t')) {
            if (!current.isEmpty()) {
                parts.add(current)
                current = ""
            }
        } else {
            current += runeToString(r)
        }
        offset += len
    }
    if (!current.isEmpty()) {
        parts.add(current)
    }
    parts.toArray()
}

public class FocusManager {
    private let ids = ArrayList<String>()
    private let enabled = ArrayList<Bool>()
    private var currentIndex: Int64 = -1

    public init() {}

    public func add(id: String, enabled!: Bool = true): Unit {
        ids.add(id)
        this.enabled.add(enabled)
        if (currentIndex < 0 && enabled) {
            currentIndex = ids.size - 1
        }
    }

    public func remove(id: String): Unit {
        let index = indexOf(id)
        if (index < 0) { return }
        ids.remove(at: index)
        enabled.remove(at: index)
        if (ids.size == 0) {
            currentIndex = -1
        } else if (currentIndex == index) {
            currentIndex = firstEnabledFrom(index)
        } else if (currentIndex > index) {
            currentIndex--
        }
    }

    public func focus(id: String): Bool {
        let index = indexOf(id)
        if (index < 0 || !enabled[index]) { return false }
        currentIndex = index
        true
    }

    public func current(): ?String {
        if (currentIndex < 0 || currentIndex >= ids.size) { return None }
        Some(ids[currentIndex])
    }

    public func isFocused(id: String): Bool {
        match (current()) {
            case Some(v) => v == id
            case None => false
        }
    }

    public func next(): ?String {
        move(1)
    }

    public func previous(): ?String {
        move(-1)
    }

    public func handle(key: KeyEvent): Bool {
        match (key.code) {
            case KeyCode.Tab =>
                _ = next()
                true
            case KeyCode.BackTab =>
                _ = previous()
                true
            case _ => false
        }
    }

    private func move(delta: Int64): ?String {
        if (ids.size == 0) { return None }
        var index = if (currentIndex < 0) { 0 } else { currentIndex }
        for (_ in 0..ids.size) {
            index = (index + delta + ids.size) % ids.size
            if (enabled[index]) {
                currentIndex = index
                return Some(ids[index])
            }
        }
        None
    }

    private func firstEnabledFrom(start: Int64): Int64 {
        if (ids.size == 0) { return -1 }
        for (i in 0..ids.size) {
            let index = (start + i) % ids.size
            if (enabled[index]) { return index }
        }
        -1
    }

    private func indexOf(id: String): Int64 {
        for (i in 0..ids.size) {
            if (ids[i] == id) { return i }
        }
        -1
    }
}
