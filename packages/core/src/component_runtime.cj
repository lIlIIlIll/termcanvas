package core

import std.collection.*
import std.time.*
public struct ComponentId {
    public let value: String

    public init(value: String) {
        this.value = value
    }
}

public enum Dirty {
    | Clean
    | Self
    | Local(Rect)
    | LocalRows(Array<Int64>)
    | Global(DirtyRects)
}

public struct ComponentTimerSpec {
    public let componentId: String
    public let timerId: String
    public let every: Duration
    public let mode: TimerMode
    public let missPolicy: FrameMissPolicy
    public let priority: TimerPriority

    public init(
        componentId: String,
        timerId: String,
        every: Duration,
        mode!: TimerMode = TimerMode.Repeating,
        missPolicy!: FrameMissPolicy = FrameMissPolicy.Drop,
        priority!: TimerPriority = TimerPriority.Normal
    ) {
        this.componentId = componentId
        this.timerId = timerId
        this.every = every
        this.mode = mode
        this.missPolicy = missPolicy
        this.priority = priority
    }

    public func globalId(): String {
        componentTimerKey(componentId, timerId)
    }

    public func toTimerSpec(): TimerSpec {
        TimerSpec(globalId(), every, mode: mode, missPolicy: missPolicy)
    }
}

public class ComponentContext {
    public let componentId: String
    public let area: Rect
    private let commands = ArrayList<Command>()
    private let startedTimers = ArrayList<String>()
    private let stoppedTimers = ArrayList<String>()
    private var dataPollsStarted: Int64 = 0
    private var lowPriorityDataPollsStarted: Int64 = 0
    private var staleValue: Bool = false

    public init(componentId: String, area!: Rect = Rect(0, 0, 0, 0)) {
        this.componentId = componentId
        this.area = area
    }

    public func startTimer(timerId: String, every: Duration, mode!: TimerMode = TimerMode.Repeating, missPolicy!: FrameMissPolicy = FrameMissPolicy.Drop, priority!: TimerPriority = TimerPriority.Normal): Unit {
        let spec = ComponentTimerSpec(componentId, timerId, every, mode: mode, missPolicy: missPolicy, priority: priority)
        startedTimers.add(spec.globalId())
        commands.add(Command.StartTimer(spec.toTimerSpec()))
    }

    public func stopTimer(timerId: String): Unit {
        let id = componentTimerKey(componentId, timerId)
        stoppedTimers.add(id)
        commands.add(Command.StopTimer(id))
    }

    public func emit(command: Command): Unit {
        commands.add(command)
    }

    public func pollAsync(id: String, task: () -> Event): Unit {
        staleValue = true
        commands.add(Command.AsyncTask(componentAsyncKey(componentId, id), task))
    }

    public func pollData(id: String, version: Int64, task: () -> Event, lowPriority!: Bool = false): Unit {
        staleValue = true
        dataPollsStarted++
        if (lowPriority) {
            lowPriorityDataPollsStarted++
        }
        commands.add(Command.AsyncTask(componentDataKey(componentId, id, version), task))
    }

    public func cancelData(id: String, version: Int64): Unit {
        commands.add(Command.CancelAsync(componentDataKey(componentId, id, version)))
    }

    public func markStale(): Unit {
        staleValue = true
    }

    public func isStale(): Bool {
        staleValue
    }

    public func drainCommands(): Array<Command> {
        let out = commands.toArray()
        while (commands.size > 0) { commands.remove(at: 0) }
        out
    }

    func drainStartedTimers(): Array<String> {
        let out = startedTimers.toArray()
        while (startedTimers.size > 0) { startedTimers.remove(at: 0) }
        out
    }

    func drainStoppedTimers(): Array<String> {
        let out = stoppedTimers.toArray()
        while (stoppedTimers.size > 0) { stoppedTimers.remove(at: 0) }
        out
    }

    func drainDataPollsStarted(): Int64 {
        let out = dataPollsStarted
        dataPollsStarted = 0
        out
    }

    func drainLowPriorityDataPollsStarted(): Int64 {
        let out = lowPriorityDataPollsStarted
        lowPriorityDataPollsStarted = 0
        out
    }
}

public enum AsyncRefreshMode {
    | Immediate
    | Debounced
    | Idle
}

public class DataEvent<T> {
    public let sourceId: String
    public let version: Int64
    public let value: ?T
    public let error: ?String

    public init(sourceId: String, version: Int64, value!: ?T = None, error!: ?String = None) {
        this.sourceId = sourceId
        this.version = max(0, version)
        this.value = value
        this.error = error
    }

    public static func ready(sourceId: String, version: Int64, value: T): DataEvent<T> {
        DataEvent(sourceId, version, value: Some(value))
    }

    public static func failed(sourceId: String, version: Int64, message: String): DataEvent<T> {
        DataEvent(sourceId, version, error: Some(message))
    }
}

public class DataSource<T> {
    public let id: String
    private var latestValue: ?T = None
    private var versionValue: Int64 = 0
    private var staleValue: Bool = true
    private var errorValue: ?String = None
    private var pending: Bool = false
    private var lastStartedMillis: Int64 = -1
    private let debounceMillis: Int64
    private let idleMillis: Int64
    private var lastActivityMillis: Int64 = 0

    public init(id: String, initial!: ?T = None, debounceMillis!: Int64 = 0, idleMillis!: Int64 = 0) {
        this.id = id
        this.latestValue = initial
        this.staleValue = match (initial) {
            case Some(_) => false
            case None => true
        }
        this.debounceMillis = max(0, debounceMillis)
        this.idleMillis = max(0, idleMillis)
    }

    public func latest(): ?T { latestValue }
    public func version(): Int64 { versionValue }
    public func isStale(): Bool { staleValue }
    public func error(): ?String { errorValue }
    public func isPending(): Bool { pending }

    public func markStale(): Unit {
        staleValue = true
    }

    public func markActivity(nowMillis: Int64): Unit {
        lastActivityMillis = max(0, nowMillis)
    }

    public func set(value: T): DataEvent<T> {
        versionValue++
        latestValue = Some(value)
        staleValue = false
        errorValue = None
        pending = false
        DataEvent.ready(id, versionValue, value)
    }

    public func fail(message: String): DataEvent<T> {
        versionValue++
        staleValue = true
        errorValue = Some(message)
        pending = false
        DataEvent.failed(id, versionValue, message)
    }

    public func refresh(ctx: ComponentContext, loader: () -> T, nowMillis!: Int64 = 0, lowPriority!: Bool = false): Bool {
        if (pending) { return false }
        if (debounceMillis > 0 && lastStartedMillis >= 0 && nowMillis - lastStartedMillis < debounceMillis) {
            return false
        }
        if (idleMillis > 0 && nowMillis - lastActivityMillis < idleMillis) {
            return false
        }
        pending = true
        staleValue = true
        lastStartedMillis = max(0, nowMillis)
        let nextVersion = versionValue + 1
        ctx.pollData(id, nextVersion, { =>
            try {
                let value = loader()
                latestValue = Some(value)
                versionValue = nextVersion
                staleValue = false
                errorValue = None
                pending = false
                Event.DataReady(id, nextVersion)
            } catch (e: Exception) {
                versionValue = nextVersion
                staleValue = true
                errorValue = Some(e.message)
                pending = false
                Event.DataFailed(id, nextVersion, e.message)
            }
        }, lowPriority: lowPriority)
        true
    }

    public func cancel(ctx: ComponentContext): Unit {
        if (pending) {
            versionValue++
            staleValue = true
            errorValue = Some("cancelled")
            pending = false
            ctx.cancelData(id, versionValue)
        }
    }
}

public class AsyncDataSource<T> {
    private let source: DataSource<T>
    private let loader: () -> T
    private let lowPriority: Bool

    public init(id: String, loader: () -> T, initial!: ?T = None, debounceMillis!: Int64 = 0, idleMillis!: Int64 = 0, lowPriority!: Bool = false) {
        source = DataSource<T>(id, initial: initial, debounceMillis: debounceMillis, idleMillis: idleMillis)
        this.loader = loader
        this.lowPriority = lowPriority
    }

    public func dataSource(): DataSource<T> { source }
    public func latest(): ?T { source.latest() }
    public func version(): Int64 { source.version() }
    public func isStale(): Bool { source.isStale() }
    public func error(): ?String { source.error() }
    public func isPending(): Bool { source.isPending() }
    public func markStale(): Unit { source.markStale() }
    public func markActivity(nowMillis: Int64): Unit { source.markActivity(nowMillis) }

    public func refresh(ctx: ComponentContext, nowMillis!: Int64 = 0): Bool {
        source.refresh(ctx, loader, nowMillis: nowMillis, lowPriority: lowPriority)
    }

    public func cancel(ctx: ComponentContext): Unit {
        source.cancel(ctx)
    }
}

public class AsyncPoller {
    public let id: String
    private let task: () -> Event
    private let mode: AsyncRefreshMode
    private let debounceMillis: Int64
    private var pending: Bool = false
    private var lastStartedMillis: Int64 = -1

    public init(id: String, task: () -> Event, mode!: AsyncRefreshMode = AsyncRefreshMode.Immediate, debounceMillis!: Int64 = 0) {
        this.id = id
        this.task = task
        this.mode = mode
        this.debounceMillis = max(0, debounceMillis)
    }

    public func request(ctx: ComponentContext, nowMillis!: Int64 = 0): Bool {
        if (pending) { return false }
        match (mode) {
            case AsyncRefreshMode.Debounced =>
                if (lastStartedMillis >= 0 && nowMillis - lastStartedMillis < debounceMillis) {
                    return false
                }
            case _ => ()
        }
        pending = true
        lastStartedMillis = max(0, nowMillis)
        ctx.pollAsync(id, task)
        true
    }

    public func complete(): Unit {
        pending = false
    }

    public func isPending(): Bool {
        pending
    }
}

public class IdleTask {
    private let id: String
    private let task: () -> Event
    private let quietMillis: Int64
    private var lastActivityMillis: Int64 = 0
    private var pending: Bool = false

    public init(id: String, task: () -> Event, quietMillis!: Int64 = 120) {
        this.id = id
        this.task = task
        this.quietMillis = max(0, quietMillis)
    }

    public func markActivity(nowMillis: Int64): Unit {
        lastActivityMillis = max(0, nowMillis)
    }

    public func requestIfIdle(ctx: ComponentContext, nowMillis: Int64): Bool {
        if (pending || nowMillis - lastActivityMillis < quietMillis) { return false }
        pending = true
        ctx.pollAsync(id, task)
        true
    }

    public func complete(): Unit {
        pending = false
    }
}

public class ComponentProfile {
    public let id: String
    public var updateCount: Int64 = 0
    public var renderCount: Int64 = 0
    public var timerCount: Int64 = 0
    public var asyncCount: Int64 = 0
    public var updateMillis: Int64 = 0
    public var renderMillis: Int64 = 0
    public var timerMillis: Int64 = 0
    public var asyncMillis: Int64 = 0
    public var dirtyCells: Int64 = 0
    public var dirtyRects: Int64 = 0
    public var skippedRenders: Int64 = 0
    public var eventQueueLatencyMillis: Int64 = 0
    public var pendingDataSources: Int64 = 0
    public var lowPriorityDataPolls: Int64 = 0
    public var lastError: ?String = None

    public init(id: String) {
        this.id = id
    }
}

public class ProfilerEntry {
    public let id: String
    public let updateCount: Int64
    public let renderCount: Int64
    public let timerCount: Int64
    public let asyncCount: Int64
    public let updateMillis: Int64
    public let renderMillis: Int64
    public let timerMillis: Int64
    public let asyncMillis: Int64
    public let dirtyCells: Int64
    public let dirtyRects: Int64
    public let skippedRenders: Int64
    public let eventQueueLatencyMillis: Int64
    public let pendingDataSources: Int64
    public let lowPriorityDataPolls: Int64
    public let lastError: ?String

    public init(profile: ComponentProfile) {
        id = profile.id
        updateCount = profile.updateCount
        renderCount = profile.renderCount
        timerCount = profile.timerCount
        asyncCount = profile.asyncCount
        updateMillis = profile.updateMillis
        renderMillis = profile.renderMillis
        timerMillis = profile.timerMillis
        asyncMillis = profile.asyncMillis
        dirtyCells = profile.dirtyCells
        dirtyRects = profile.dirtyRects
        skippedRenders = profile.skippedRenders
        eventQueueLatencyMillis = profile.eventQueueLatencyMillis
        pendingDataSources = profile.pendingDataSources
        lowPriorityDataPolls = profile.lowPriorityDataPolls
        lastError = profile.lastError
    }

    public func totalMillis(): Int64 {
        updateMillis + renderMillis + timerMillis + asyncMillis
    }
}

public class ProfilerSnapshot {
    public let entries: Array<ProfilerEntry>

    public init(entries: Array<ProfilerEntry>) {
        this.entries = entries
    }

    public func hottest(): ?ProfilerEntry {
        var best: ?ProfilerEntry = None
        for (entry in entries) {
            match (best) {
                case Some(current) =>
                    if (entry.totalMillis() > current.totalMillis()) { best = Some(entry) }
                case None => best = Some(entry)
            }
        }
        best
    }

    public func find(id: String): ?ProfilerEntry {
        for (entry in entries) {
            if (entry.id == id) { return Some(entry) }
        }
        None
    }

    public func sortedByTotal(): Array<ProfilerEntry> {
        sortProfilerEntries(entries, ProfilerSortKey.Total)
    }

    public func sortedByRender(): Array<ProfilerEntry> {
        sortProfilerEntries(entries, ProfilerSortKey.Render)
    }

    public func sortedByUpdate(): Array<ProfilerEntry> {
        sortProfilerEntries(entries, ProfilerSortKey.Update)
    }

    public func sortedByAsync(): Array<ProfilerEntry> {
        sortProfilerEntries(entries, ProfilerSortKey.Async)
    }

    public func text(): String {
        let lines = ArrayList<String>()
        for (entry in entries) {
            let err = match (entry.lastError) {
                case Some(message) => " error=${message}"
                case None => ""
            }
            lines.add("${entry.id} u=${entry.updateCount}/${entry.updateMillis}ms r=${entry.renderCount}/${entry.renderMillis}ms t=${entry.timerCount}/${entry.timerMillis}ms a=${entry.asyncCount}/${entry.asyncMillis}ms dirty=${entry.dirtyCells} rects=${entry.dirtyRects} pending=${entry.pendingDataSources} skipped=${entry.skippedRenders}${err}")
        }
        join(lines.toArray(), "\n")
    }
}

enum ProfilerSortKey {
    | Total
    | Render
    | Update
    | Async
}

public class ComponentProfiler {
    private let profiles = ArrayList<ComponentProfile>()

    public init() {}

    public func add(id: String): Unit {
        match (profile(id)) {
            case Some(_) => ()
            case None => profiles.add(ComponentProfile(id))
        }
    }

    public func profile(id: String): ?ComponentProfile {
        for (profile in profiles) {
            if (profile.id == id) { return Some(profile) }
        }
        None
    }

    public func profilesArray(): Array<ComponentProfile> {
        profiles.toArray()
    }

    public func snapshot(): ProfilerSnapshot {
        let entries = ArrayList<ProfilerEntry>()
        for (profile in profiles) {
            entries.add(ProfilerEntry(profile))
        }
        ProfilerSnapshot(entries.toArray())
    }

    public func reset(): Unit {
        for (profile in profiles) {
            profile.updateCount = 0
            profile.renderCount = 0
            profile.timerCount = 0
            profile.asyncCount = 0
            profile.updateMillis = 0
            profile.renderMillis = 0
            profile.timerMillis = 0
            profile.asyncMillis = 0
            profile.dirtyCells = 0
            profile.dirtyRects = 0
            profile.skippedRenders = 0
            profile.eventQueueLatencyMillis = 0
            profile.pendingDataSources = 0
            profile.lowPriorityDataPolls = 0
            profile.lastError = None
        }
    }

    public func resetFrameCounters(): Unit {
        reset()
    }
}

public class ProfilerOverlay <: Widget {
    private let profiler: ComponentProfiler
    private let style: Style

    public init(profiler: ComponentProfiler, style!: Style = Style(fg: Color.White, bg: Color.Black)) {
        this.profiler = profiler
        this.style = style
    }

    public func snapshot(): ProfilerSnapshot {
        profiler.snapshot()
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.fill(area, style: style)
        let snapshot = profiler.snapshot()
        let header = match (snapshot.hottest()) {
            case Some(entry) => "profiler hottest=${entry.id} total=${entry.totalMillis()}ms dirty=${entry.dirtyCells} pending=${entry.pendingDataSources} skipped=${entry.skippedRenders}"
            case None => "profiler no component samples"
        }
        buffer.setString(area.x, area.y, truncate(header, area.width), style: style)
        let rows = snapshot.sortedByTotal()
        let limit = min(area.height - 1, rows.size)
        for (i in 0..limit) {
            let entry = rows[i]
            let marker = match (entry.lastError) {
                case Some(_) => "!"
                case None => if (entry.pendingDataSources > 0) { "*" } else { " " }
            }
            let line = "${marker}${entry.id} u${entry.updateCount}/${entry.updateMillis} r${entry.renderCount}/${entry.renderMillis} t${entry.timerCount}/${entry.timerMillis} a${entry.asyncCount}/${entry.asyncMillis} d${entry.dirtyCells} p${entry.pendingDataSources} s${entry.skippedRenders}"
            buffer.setString(area.x, area.y + 1 + i, truncate(line, area.width), style: style)
        }
    }
}

public struct ComponentResult {
    public let handled: Bool
    public let flow: ControlFlow
    public let command: Command
    public let dirty: Dirty
    public let propagation: EventPropagation

    public init(
        handled!: Bool = false,
        flow!: ControlFlow = ControlFlow.Continue,
        command!: Command = Command.Noop,
        dirty!: Dirty = Dirty.Clean,
        propagation!: EventPropagation = EventPropagation.Continue
    ) {
        this.handled = handled
        this.flow = flow
        this.command = command
        this.dirty = dirty
        this.propagation = propagation
    }

    public static func ignored(): ComponentResult {
        ComponentResult()
    }

    public static func consumed(dirty!: Dirty = Dirty.Clean, command!: Command = Command.Noop): ComponentResult {
        ComponentResult(handled: true, command: command, dirty: dirty, propagation: EventPropagation.Stop)
    }

    public static func withDirty(dirty: Dirty): ComponentResult {
        ComponentResult(handled: true, dirty: dirty, propagation: EventPropagation.Stop)
    }

    public static func exit(): ComponentResult {
        ComponentResult(handled: true, flow: ControlFlow.Exit, propagation: EventPropagation.Exit)
    }

    public static func fromHandle(result: HandleResult): ComponentResult {
        ComponentResult(
            handled: result.handled,
            flow: result.flow,
            command: result.command,
            propagation: if (result.handled) { EventPropagation.Stop } else { EventPropagation.Continue }
        )
    }
}

public interface RuntimeComponent {
    func mount(ctx: ComponentContext): ComponentResult
    func unmount(ctx: ComponentContext): ComponentResult
    func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult
    func update(event: Event, ctx: ComponentContext): ComponentResult
    func render(frame: Frame, area: Rect): Unit
    func focusId(): ?String
}

public class WidgetComponent <: RuntimeComponent {
    private let id: String
    private let widget: Widget
    private let focus: ?String

    public init(id: String, widget: Widget, focusId!: ?String = None) {
        this.id = id
        this.widget = widget
        this.focus = focusId
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        match (event) {
            case Event.Resize(_) => ComponentResult.withDirty(Dirty.Self)
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(widget, area)
    }

    public func focusId(): ?String {
        focus
    }
}

public class ListComponent <: RuntimeComponent {
    private let list: List
    private let state: ListState
    private let total: Int64
    private let focus: ?String

    public init(list: List, state: ListState, total: Int64, focusId!: ?String = None) {
        this.list = list
        this.state = state
        this.total = max(0, total)
        this.focus = focusId
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.Up =>
                        let dirty = state.moveWithDirty(-1, total, ctx.area.height, ctx.area)
                        ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case KeyCode.Down =>
                        let dirty = state.moveWithDirty(1, total, ctx.area.height, ctx.area)
                        ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case KeyCode.PageUp =>
                        let dirty = state.moveWithDirty(-max(1, ctx.area.height), total, ctx.area.height, ctx.area)
                        ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case KeyCode.PageDown =>
                        let dirty = state.moveWithDirty(max(1, ctx.area.height), total, ctx.area.height, ctx.area)
                        ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case _ => ComponentResult.ignored()
                }
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(list, area)
    }

    public func focusId(): ?String { focus }
}

public class InputComponent <: RuntimeComponent {
    private let input: Input
    private let focus: ?String

    public init(input: Input, focusId!: ?String = None) {
        this.input = input
        this.focus = focusId
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (input.handleWithDirty(key, ctx.area)) {
                    case Some(dirty) => ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case None => ComponentResult.ignored()
                }
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(input, area)
    }

    public func focusId(): ?String { focus }
}

public class TextAreaComponent <: RuntimeComponent {
    private let textArea: TextArea
    private let focus: ?String

    public init(textArea: TextArea, focusId!: ?String = None) {
        this.textArea = textArea
        this.focus = focusId
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }
    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (textArea.handleWithDirty(key, ctx.area)) {
                    case Some(dirty) => ComponentResult.consumed(dirty: Dirty.Global(dirty))
                    case None => ComponentResult.ignored()
                }
            case _ => ComponentResult.ignored()
        }
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(textArea, area)
    }

    public func focusId(): ?String { focus }
}

public class LegacyComponentAdapter <: RuntimeComponent {
    private let component: Component

    public init(component: Component) {
        this.component = component
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func unmount(ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.ignored()
    }

    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty() || oldArea == newArea) { return ComponentResult.ignored() }
        ComponentResult.withDirty(Dirty.Self)
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        ComponentResult.fromHandle(component.handle(event))
    }

    public func render(frame: Frame, area: Rect): Unit {
        component.render(frame, area)
    }

    public func focusId(): ?String {
        component.focusId()
    }
}

public class ComponentNode {
    public let id: String
    private let component: RuntimeComponent
    private var areaValue: Rect
    private var mountedValue: Bool = false
    private let timers = ArrayList<String>()

    public init(id: String, component: RuntimeComponent, area!: Rect = Rect(0, 0, 0, 0)) {
        this.id = id
        this.component = component
        this.areaValue = area
    }

    public func area(): Rect { areaValue }
    public func isMounted(): Bool { mountedValue }
    public func focusId(): ?String { component.focusId() }

    func setArea(area: Rect): Rect {
        let old = areaValue
        areaValue = area
        old
    }

    func markMounted(value: Bool): Unit {
        mountedValue = value
    }

    func rememberTimers(started: Array<String>, stopped: Array<String>): Unit {
        for (id in stopped) {
            var i: Int64 = 0
            while (i < timers.size) {
                if (timers[i] == id) {
                    timers.remove(at: i)
                    continue
                }
                i++
            }
        }
        for (id in started) {
            if (!containsString(timers, id)) {
                timers.add(id)
            }
        }
    }

    func activeTimers(): Array<String> {
        timers.toArray()
    }

    func clearTimers(): Unit {
        while (timers.size > 0) { timers.remove(at: 0) }
    }

    func mount(ctx: ComponentContext): ComponentResult { component.mount(ctx) }
    func unmount(ctx: ComponentContext): ComponentResult { component.unmount(ctx) }
    func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult { component.resize(oldArea, newArea, ctx) }
    func update(event: Event, ctx: ComponentContext): ComponentResult { component.update(event, ctx) }

    public func render(frame: Frame): Unit {
        component.render(frame, areaValue)
    }
}

public interface ComponentLayoutProvider {
    func split(area: Rect, count: Int64): Array<Rect>
}

public class VerticalComponentLayoutProvider <: ComponentLayoutProvider {
    public init() {}

    public func split(area: Rect, count: Int64): Array<Rect> {
        if (count <= 0) { return [] }
        let rects = ArrayList<Rect>()
        let perHeight = max(0, area.height / count)
        var y = area.y
        for (i in 0..count) {
            let height = if (i == count - 1) { max(0, area.bottom - y) } else { min(perHeight, max(0, area.bottom - y)) }
            rects.add(Rect(area.x, y, area.width, height))
            y += height
        }
        rects.toArray()
    }
}

public class ComponentHost {
    private let nodes = ArrayList<ComponentNode>()
    private let focus = FocusManager()
    private let globalKeys = KeyMap()
    private let profilerValue = ComponentProfiler()
    private let layoutProvider: ComponentLayoutProvider
    private var modalId: ?String = None

    public init(layoutProvider!: ComponentLayoutProvider = VerticalComponentLayoutProvider()) {
        this.layoutProvider = layoutProvider
    }

    public func add(id: String, component: RuntimeComponent, area!: Rect = Rect(0, 0, 0, 0), focused!: Bool = true): ComponentHost {
        let node = ComponentNode(id, component, area: area)
        nodes.add(node)
        profilerValue.add(id)
        match (node.focusId()) {
            case Some(focusId) => focus.add(focusId, enabled: focused)
            case None => ()
        }
        this
    }

    public func addWidget(id: String, widget: Widget, area!: Rect = Rect(0, 0, 0, 0), focusId!: ?String = None): ComponentHost {
        add(id, WidgetComponent(id, widget, focusId: focusId), area: area)
    }

    public func addLegacy(id: String, component: Component, area!: Rect = Rect(0, 0, 0, 0)): ComponentHost {
        add(id, LegacyComponentAdapter(component), area: area)
    }

    public func size(): Int64 { nodes.size }

    public func componentProfiles(): Array<ComponentProfile> {
        profilerValue.profilesArray()
    }

    public func componentProfile(id: String): ?ComponentProfile {
        profilerValue.profile(id)
    }

    public func profiler(): ComponentProfiler {
        profilerValue
    }

    public func profilerSnapshot(): ProfilerSnapshot {
        profilerValue.snapshot()
    }

    public func focusManager(): FocusManager { focus }

    public func addGlobalKey(binding: KeyBinding): Unit {
        globalKeys.add(binding)
    }

    public func setModal(id: ?String): Unit {
        modalId = id
    }

    public func node(id: String): ?ComponentNode {
        for (node in nodes) {
            if (node.id == id) { return Some(node) }
        }
        None
    }

    public func setArea(id: String, area: Rect): UpdateResult {
        match (node(id)) {
            case Some(item) =>
                let old = item.setArea(area)
                if (old != area) {
                    applyComponentResult(item, item.resize(old, area, ComponentContext(item.id, area: area)))
                } else {
                    UpdateResult.next()
                }
            case None => UpdateResult.next()
        }
    }

    public func mount(): UpdateResult {
        let commands = ArrayList<Command>()
        for (node in nodes) {
            if (!node.isMounted()) {
                let ctx = ComponentContext(node.id, area: node.area())
                let result = node.mount(ctx)
                node.markMounted(true)
                collectCommands(commands, result.command, ctx.drainCommands())
                node.rememberTimers(ctx.drainStartedTimers(), ctx.drainStoppedTimers())
            }
        }
        UpdateResult(command: batchCommand(commands.toArray()))
    }

    public func mountAll(): UpdateResult {
        mount()
    }

    public func unmount(): UpdateResult {
        let commands = ArrayList<Command>()
        for (node in nodes) {
            if (node.isMounted()) {
                let ctx = ComponentContext(node.id, area: node.area())
                let result = node.unmount(ctx)
                node.markMounted(false)
                collectCommands(commands, result.command, ctx.drainCommands())
                node.rememberTimers(ctx.drainStartedTimers(), ctx.drainStoppedTimers())
                for (timerId in node.activeTimers()) {
                    commands.add(Command.StopTimer(timerId))
                }
                node.clearTimers()
            }
        }
        UpdateResult(command: batchCommand(commands.toArray()))
    }

    public func unmountAll(): UpdateResult {
        unmount()
    }

    public func resizeAllComponents(area: Rect): UpdateResult {
        resizeAll(area)
    }

    public func updateRoute(event: Event): UpdateResult {
        update(event)
    }

    public func update(event: Event): UpdateResult {
        match (event) {
            case Event.AsyncCompleted(id, inner) =>
                match (componentDataTarget(id)) {
                    case Some((componentId, sourceId, _)) =>
                        match (inner) {
                            case Event.DataReady(_, version) =>
                                return dispatchTo(componentId, Event.DataReady(sourceId, version))
                            case Event.DataFailed(_, version, message) =>
                                return dispatchTo(componentId, Event.DataFailed(sourceId, version, message))
                            case _ => ()
                        }
                    case None => ()
                }
                match (componentAsyncTarget(id)) {
                    case Some((componentId, asyncId)) =>
                        return dispatchTo(componentId, Event.AsyncCompleted(asyncId, inner))
                    case None => ()
                }
            case Event.AsyncFailed(id, message) =>
                match (componentDataTarget(id)) {
                    case Some((componentId, sourceId, version)) =>
                        return dispatchTo(componentId, Event.DataFailed(sourceId, version, message))
                    case None => ()
                }
                match (componentAsyncTarget(id)) {
                    case Some((componentId, asyncId)) =>
                        return dispatchTo(componentId, Event.AsyncFailed(asyncId, message))
                    case None => ()
                }
            case Event.AsyncCancelled(id) =>
                match (componentDataTarget(id)) {
                    case Some((componentId, sourceId, version)) =>
                        return dispatchTo(componentId, Event.DataCancelled(sourceId, version))
                    case None => ()
                }
                match (componentAsyncTarget(id)) {
                    case Some((componentId, asyncId)) =>
                        return dispatchTo(componentId, Event.AsyncCancelled(asyncId))
                    case None => ()
                }
            case Event.Timer(timer) =>
                match (componentTimerTarget(timer.id)) {
                    case Some((componentId, timerId)) =>
                        return dispatchTo(componentId, Event.ComponentTick(ComponentTickEvent(componentId, timerId, timer)))
                    case None => ()
                }
            case Event.Resize(area) => return resizeAll(area)
            case Event.KeyDown(key) =>
                match (modalId) {
                    case Some(id) => return dispatchTo(id, event)
                    case None => ()
                }
                if (focus.handle(key)) { return UpdateResult.next() }
                match (dispatchFocused(event)) {
                    case Some(result) =>
                        if (hasEffect(result)) { return result }
                    case None => ()
                }
                match (globalKeys.actionFor(key)) {
                    case Some(action) => return UpdateResult(command: Command.Message(action))
                    case None => ()
                }
            case _ => ()
        }
        match (dispatchFocused(event)) {
            case Some(result) =>
                if (hasEffect(result)) { return result }
            case None => ()
        }
        for (node in nodes) {
            let result = dispatchNode(node, event)
            if (hasEffect(result)) { return result }
        }
        UpdateResult.next()
    }

    public func dispatchTo(id: String, event: Event): UpdateResult {
        match (node(id)) {
            case Some(item) => dispatchNode(item, event)
            case None => UpdateResult.next()
        }
    }

    public func render(frame: Frame): Unit {
        for (node in nodes) {
            if (frame.isDirty(node.area())) {
                let start = MonoTime.now()
                frame.renderComponent(node)
                recordRender(this, node.id, durationMillis(MonoTime.now() - start), node.area().width * node.area().height)
            } else {
                recordSkippedRender(this, node.id)
            }
        }
    }

    public func renderDirty(frame: Frame): Unit {
        render(frame)
    }

    private func dispatchFocused(event: Event): ?UpdateResult {
        match (focus.current()) {
            case Some(id) =>
                for (node in nodes) {
                    match (node.focusId()) {
                        case Some(focusId) =>
                            if (focusId == id) { return Some(dispatchNode(node, event)) }
                        case None => ()
                    }
                }
            case None => ()
        }
        None
    }

    private func resizeAll(area: Rect): UpdateResult {
        if (nodes.size == 0) { return UpdateResult.next() }
        let areas = layoutProvider.split(area, nodes.size)
        let dirty = DirtyRects()
        let commands = ArrayList<Command>()
        for (i in 0..nodes.size) {
            let next = if (i < areas.size) { areas[i] } else { Rect(area.x, area.y, 0, 0) }
            let old = nodes[i].setArea(next)
            dirty.add(old)
            dirty.add(next)
            let ctx = ComponentContext(nodes[i].id, area: next)
            let result = nodes[i].resize(old, next, ctx)
            collectCommands(commands, result.command, ctx.drainCommands())
            nodes[i].rememberTimers(ctx.drainStartedTimers(), ctx.drainStoppedTimers())
        }
        UpdateResult(command: batchCommand(commands.toArray()), dirtyRects: Some(dirty))
    }

    private func dispatchNode(node: ComponentNode, event: Event): UpdateResult {
        let ctx = ComponentContext(node.id, area: node.area())
        let start = MonoTime.now()
        let result = node.update(event, ctx)
        recordUpdate(this, node.id, event, durationMillis(MonoTime.now() - start), result, node.area())
        applyComponentResult(node, result, ctx: ctx)
    }

    private func applyComponentResult(node: ComponentNode, result: ComponentResult, ctx!: ?ComponentContext = None): UpdateResult {
        let commands = ArrayList<Command>()
        collectCommands(commands, result.command, match (ctx) {
            case Some(context) => context.drainCommands()
            case None => []
        })
        match (ctx) {
            case Some(context) =>
                node.rememberTimers(context.drainStartedTimers(), context.drainStoppedTimers())
                recordDataPolls(this, node.id, context.drainDataPollsStarted(), context.drainLowPriorityDataPollsStarted())
            case None => ()
        }
        UpdateResult(flow: result.flow, command: batchCommand(commands.toArray()), dirtyRects: dirtyToGlobal(result.dirty, node.area()))
    }
}

func recordUpdate(host: ComponentHost, id: String, event: Event, elapsedMillis: Int64, result: ComponentResult, area: Rect): Unit {
    if (result.handled || elapsedMillis >= 0) {
        match (host.componentProfile(id)) {
            case Some(profile) =>
                profile.updateCount++
                profile.updateMillis += max(0, elapsedMillis)
                match (event) {
                    case Event.ComponentTick(_) =>
                        profile.timerCount++
                        profile.timerMillis += max(0, elapsedMillis)
                    case Event.AsyncCompleted(_, _) | Event.AsyncFailed(_, _) | Event.AsyncCancelled(_) =>
                        profile.asyncCount++
                        profile.asyncMillis += max(0, elapsedMillis)
                    case Event.DataReady(_, _) =>
                        profile.asyncCount++
                        profile.asyncMillis += max(0, elapsedMillis)
                        profile.pendingDataSources = max(0, profile.pendingDataSources - 1)
                        profile.lastError = None
                    case Event.DataFailed(_, _, message) =>
                        profile.asyncCount++
                        profile.asyncMillis += max(0, elapsedMillis)
                        profile.pendingDataSources = max(0, profile.pendingDataSources - 1)
                        profile.lastError = Some(message)
                    case Event.DataCancelled(_, _) =>
                        profile.asyncCount++
                        profile.asyncMillis += max(0, elapsedMillis)
                        profile.pendingDataSources = max(0, profile.pendingDataSources - 1)
                        profile.lastError = Some("cancelled")
                    case _ => ()
                }
                match (dirtyToGlobal(result.dirty, area)) {
                    case Some(rects) =>
                        profile.dirtyCells += rects.cellCount()
                        profile.dirtyRects += rects.rects().size
                    case None => ()
                }
            case None => ()
        }
    }
}

func recordDataPolls(host: ComponentHost, id: String, polls: Int64, lowPriorityPolls: Int64): Unit {
    if (polls <= 0 && lowPriorityPolls <= 0) { return }
    match (host.componentProfile(id)) {
        case Some(profile) =>
            profile.pendingDataSources += max(0, polls)
            profile.lowPriorityDataPolls += max(0, lowPriorityPolls)
        case None => ()
    }
}

func recordRender(host: ComponentHost, id: String, elapsedMillis: Int64, cells: Int64): Unit {
    match (host.componentProfile(id)) {
        case Some(profile) =>
            profile.renderCount++
            profile.renderMillis += max(0, elapsedMillis)
            profile.dirtyCells += max(0, cells)
        case None => ()
    }
}

func recordSkippedRender(host: ComponentHost, id: String): Unit {
    match (host.componentProfile(id)) {
        case Some(profile) => profile.skippedRenders++
        case None => ()
    }
}

func sortProfilerEntries(entries: Array<ProfilerEntry>, key: ProfilerSortKey): Array<ProfilerEntry> {
    let out = ArrayList<ProfilerEntry>()
    for (entry in entries) { out.add(entry) }
    if (out.size <= 1) { return out.toArray() }
    for (i in 0..out.size) {
        var best = i
        var j = i + 1
        while (j < out.size) {
            if (profilerScore(out[j], key) > profilerScore(out[best], key)) {
                best = j
            }
            j++
        }
        if (best != i) {
            let tmp = out[i]
            out[i] = out[best]
            out[best] = tmp
        }
    }
    out.toArray()
}

func profilerScore(entry: ProfilerEntry, key: ProfilerSortKey): Int64 {
    match (key) {
        case ProfilerSortKey.Total => entry.totalMillis()
        case ProfilerSortKey.Render => entry.renderMillis
        case ProfilerSortKey.Update => entry.updateMillis
        case ProfilerSortKey.Async => entry.asyncMillis
    }
}

public class DashboardRegion {
    public let id: String
    public let row: Int64
    public let column: Int64
    public let rowSpan: Int64
    public let columnSpan: Int64

    public init(id: String, row: Int64, column: Int64, rowSpan!: Int64 = 1, columnSpan!: Int64 = 1) {
        this.id = id
        this.row = max(0, row)
        this.column = max(0, column)
        this.rowSpan = max(1, rowSpan)
        this.columnSpan = max(1, columnSpan)
    }
}

public class DashboardGrid {
    private let rows: Int64
    private let columns: Int64
    private let gap: Int64
    private let regions = ArrayList<DashboardRegion>()

    public init(rows: Int64, columns: Int64, gap!: Int64 = 0, regions!: Array<DashboardRegion> = []) {
        this.rows = max(1, rows)
        this.columns = max(1, columns)
        this.gap = max(0, gap)
        for (region in regions) { this.regions.add(region) }
    }

    public func add(region: DashboardRegion): DashboardGrid {
        regions.add(region)
        this
    }

    public func layout(area: Rect): Array<(String, Rect)> {
        let out = ArrayList<(String, Rect)>()
        let totalGapX = gap * max(0, columns - 1)
        let totalGapY = gap * max(0, rows - 1)
        let cellW = max(0, (area.width - totalGapX) / columns)
        let cellH = max(0, (area.height - totalGapY) / rows)
        for (region in regions) {
            let x = area.x + region.column * (cellW + gap)
            let y = area.y + region.row * (cellH + gap)
            let w = cellW * region.columnSpan + gap * max(0, region.columnSpan - 1)
            let h = cellH * region.rowSpan + gap * max(0, region.rowSpan - 1)
            out.add((region.id, Rect(x, y, min(w, area.right - x), min(h, area.bottom - y))))
        }
        out.toArray()
    }

    public func apply(host: ComponentHost, area: Rect): UpdateResult {
        let dirty = DirtyRects()
        let commands = ArrayList<Command>()
        for ((id, rect) in layout(area)) {
            match (host.node(id)) {
                case Some(node) =>
                    let old = node.area()
                    let result = host.setArea(id, rect)
                    collectCommands(commands, result.command, [])
                    dirty.add(old)
                    dirty.add(rect)
                case None => ()
            }
        }
        UpdateResult(command: batchCommand(commands.toArray()), dirtyRects: Some(dirty))
    }
}

public class ComponentContainer <: RuntimeComponent {
    private let host: ComponentHost
    private let grid: DashboardGrid

    public init(host: ComponentHost, grid: DashboardGrid) {
        this.host = host
        this.grid = grid
    }

    public func mount(ctx: ComponentContext): ComponentResult {
        ctx.emit(grid.apply(host, ctx.area).command)
        ctx.emit(host.mount().command)
        ComponentResult.ignored()
    }

    public func unmount(ctx: ComponentContext): ComponentResult {
        ctx.emit(host.unmount().command)
        ComponentResult.ignored()
    }

    public func resize(oldArea: Rect, newArea: Rect, ctx: ComponentContext): ComponentResult {
        if (oldArea != newArea) {
            ctx.emit(grid.apply(host, newArea).command)
            ComponentResult.withDirty(Dirty.Self)
        } else {
            ComponentResult.ignored()
        }
    }

    public func update(event: Event, ctx: ComponentContext): ComponentResult {
        if (ctx.componentId.isEmpty()) { return ComponentResult.ignored() }
        let result = host.update(event)
        ComponentResult(handled: hasEffect(result), flow: result.flow, command: result.command, dirty: match (result.dirtyRects) {
            case Some(rects) => Dirty.Global(rects)
            case None => Dirty.Clean
        }, propagation: if (hasEffect(result)) { EventPropagation.Stop } else { EventPropagation.Continue })
    }

    public func render(frame: Frame, area: Rect): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        host.render(frame)
    }

    public func focusId(): ?String { None }
}

func dirtyToGlobal(dirty: Dirty, area: Rect): ?DirtyRects {
    match (dirty) {
        case Dirty.Clean => None
        case Dirty.Self => Some(DirtyRects.full(area))
        case Dirty.Local(rect) =>
            let out = DirtyRects()
            out.add(Rect(area.x + rect.x, area.y + rect.y, rect.width, rect.height))
            Some(out)
        case Dirty.LocalRows(rows) =>
            let out = DirtyRects()
            for (row in rows) {
                if (row >= 0 && row < area.height) {
                    out.add(Rect(area.x, area.y + row, area.width, 1))
                }
            }
            Some(out)
        case Dirty.Global(rects) => Some(rects.copy())
    }
}

func batchCommand(commands: Array<Command>): Command {
    let filtered = ArrayList<Command>()
    for (command in commands) {
        match (command) {
            case Command.Noop => ()
            case Command.Batch(items) =>
                for (item in items) { filtered.add(item) }
            case other => filtered.add(other)
        }
    }
    if (filtered.size == 0) {
        Command.Noop
    } else if (filtered.size == 1) {
        filtered[0]
    } else {
        Command.Batch(filtered.toArray())
    }
}

func collectCommands(out: ArrayList<Command>, command: Command, commands: Array<Command>): Unit {
    match (command) {
        case Command.Noop => ()
        case other => out.add(other)
    }
    for (item in commands) {
        match (item) {
            case Command.Noop => ()
            case other => out.add(other)
        }
    }
}

func containsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) { return true }
    }
    false
}

func componentTimerKey(componentId: String, timerId: String): String {
    "component:" + componentId + ":" + timerId
}

func componentAsyncKey(componentId: String, asyncId: String): String {
    "component-async:" + componentId + ":" + asyncId
}

func componentDataKey(componentId: String, sourceId: String, version: Int64): String {
    "component-data:" + componentId + ":" + sourceId + ":" + "${max(0, version)}"
}

func componentTimerTarget(id: String): ?(String, String) {
    let prefix = "component:"
    if (!id.startsWith(prefix)) { return None }
    let rest = id[prefix.size..]
    let sep = rest.indexOf(":")
    match (sep) {
        case Some(index) =>
            let componentId = rest[..index]
            let timerId = rest[(index + 1)..]
            Some((componentId, timerId))
        case None => None
    }
}

func componentAsyncTarget(id: String): ?(String, String) {
    let prefix = "component-async:"
    if (!id.startsWith(prefix)) { return None }
    splitComponentKey(id[prefix.size..])
}

func componentDataTarget(id: String): ?(String, String, Int64) {
    let prefix = "component-data:"
    if (!id.startsWith(prefix)) { return None }
    let rest = id[prefix.size..]
    let first = rest.indexOf(":")
    match (first) {
        case Some(componentEnd) =>
            let componentId = rest[..componentEnd]
            let tail = rest[(componentEnd + 1)..]
            let second = tail.indexOf(":")
            match (second) {
                case Some(sourceEnd) =>
                    let sourceId = tail[..sourceEnd]
                    let versionText = tail[(sourceEnd + 1)..]
                    Some((componentId, sourceId, parsePositiveInt(versionText)))
                case None => None
            }
        case None => None
    }
}

func parsePositiveInt(text: String): Int64 {
    var value: Int64 = 0
    for (ch in unsafe { text.rawData() }) {
        if (ch >= b'0' && ch <= b'9') {
            value = value * 10 + Int64(ch - b'0')
        }
    }
    value
}

func splitComponentKey(rest: String): ?(String, String) {
    let sep = rest.indexOf(":")
    match (sep) {
        case Some(index) =>
            let componentId = rest[..index]
            let itemId = rest[(index + 1)..]
            Some((componentId, itemId))
        case None => None
    }
}

func hasEffect(result: UpdateResult): Bool {
    if (isExit(result.flow)) { return true }
    match (result.command) {
        case Command.Noop => ()
        case _ => return true
    }
    match (result.dirtyRects) {
        case Some(rects) => !rects.isEmpty()
        case None => false
    }
}
