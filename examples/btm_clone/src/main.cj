package termcanvas_btm_clone

import core.*
import std.collection.*
import std.deriving.*
import std.fs.*
import std.sort.*
import std.sync.*
import std.time.*

@FastNative
@When[os != "Windows"]
foreign func statvfs(path: CString, buf: CPointer<StatVfs>): Int32

@C
@When[os != "Windows"]
struct StatVfs {
    StatVfs(
        let f_bsize: UIntNative,
        let f_frsize: UIntNative,
        let f_blocks: UIntNative,
        let f_bfree: UIntNative,
        let f_bavail: UIntNative,
        let f_files: UIntNative,
        let f_ffree: UIntNative,
        let f_favail: UIntNative,
        let f_fsid: UIntNative,
        let f_flag: Int32,
        let f_namemax: UIntNative,
        let f_spare0: Int32,
        let f_spare1: Int32,
        let f_spare2: Int32,
        let f_spare3: Int32,
        let f_spare4: Int32,
        let f_spare5: Int32
    ) {}
}

let BG = Color.Rgb(5, 8, 13)
let PANEL = Color.Rgb(9, 14, 22)
let GRID = Color.Rgb(31, 46, 62)
let TEXT = Color.Rgb(214, 225, 234)
let MUTED = Color.Rgb(118, 138, 156)
let CYAN = Color.Rgb(64, 210, 225)
let BLUE = Color.Rgb(74, 137, 255)
let GREEN = Color.Rgb(91, 218, 129)
let YELLOW = Color.Rgb(235, 192, 85)
let RED = Color.Rgb(238, 91, 91)
let MAGENTA = Color.Rgb(198, 127, 255)
let PROCESS_NORMAL_STYLE = Style(fg: TEXT, bg: PANEL)
let PROCESS_SELECTED_STYLE = Style(fg: BG, bg: CYAN, modifier: Modifier.strong())

let PAGE_BYTES: Int64 = 4096
let MAX_PROCESSES: Int64 = 200
let HISTORY_CAPACITY: Int64 = 120
let MIN_REFRESH_MILLIS: Int64 = 250
let MAX_REFRESH_MILLIS: Int64 = 5000
let REFRESH_STEP_MILLIS: Int64 = 250

@Derive[Equatable]
enum SortMode {
    | Cpu
    | Memory
    | Pid
    | Name
}

class HistoryRing {
    private let values = ArrayList<Int64>()
    private let capacity: Int64

    init(capacity: Int64) {
        this.capacity = max(1, capacity)
    }

    func push(value: Int64): Unit {
        values.add(clampLocal(value, 0, 100))
        while (values.size > capacity) {
            values.remove(at: 0)
        }
    }

    func toArray(): Array<Int64> {
        values.toArray()
    }
}

class CpuCounters {
    let total: Int64
    let idle: Int64

    init() {
        this.total = 0
        this.idle = 0
    }

    init(total: Int64, idle: Int64) {
        this.total = total
        this.idle = idle
    }
}

class ProcPrev {
    let total: Int64
    let startTime: Int64

    init(total: Int64, startTime: Int64) {
        this.total = total
        this.startTime = startTime
    }
}

class CpuSnapshot {
    let usage: Int64
    let cores: Array<Int64>

    init() {
        this.usage = 0
        this.cores = []
    }

    init(usage: Int64, cores: Array<Int64>) {
        this.usage = usage
        this.cores = cores
    }
}

class MemSnapshot {
    let totalKb: Int64
    let usedKb: Int64
    let swapTotalKb: Int64
    let swapUsedKb: Int64

    init() {
        this.totalKb = 0
        this.usedKb = 0
        this.swapTotalKb = 0
        this.swapUsedKb = 0
    }

    init(totalKb: Int64, usedKb: Int64, swapTotalKb: Int64, swapUsedKb: Int64) {
        this.totalKb = totalKb
        this.usedKb = usedKb
        this.swapTotalKb = swapTotalKb
        this.swapUsedKb = swapUsedKb
    }

    func percent(): Int64 {
        percentOf(usedKb, totalKb)
    }

    func swapPercent(): Int64 {
        percentOf(swapUsedKb, swapTotalKb)
    }
}

class NetSnapshot {
    let rxRate: Int64
    let txRate: Int64

    init() {
        this.rxRate = 0
        this.txRate = 0
    }

    init(rxRate: Int64, txRate: Int64) {
        this.rxRate = rxRate
        this.txRate = txRate
    }

    func percent(): Int64 {
        clampLocal(max(rxRate, txRate) / max(1, 1024 * 1024), 0, 100)
    }
}

class NetCounters {
    let rx: Int64
    let tx: Int64

    init() {
        this.rx = 0
        this.tx = 0
    }

    init(rx: Int64, tx: Int64) {
        this.rx = rx
        this.tx = tx
    }
}

class ProcessSnapshotResult {
    let requestId: Int64
    let sortMode: SortMode
    let filter: String
    let snapshot: MetricSnapshot

    init(requestId: Int64, sortMode: SortMode, filter: String, snapshot: MetricSnapshot) {
        this.requestId = requestId
        this.sortMode = sortMode
        this.filter = filter
        this.snapshot = snapshot
    }
}

class DiskSample {
    let mount: String
    let usedBytes: Int64
    let totalBytes: Int64

    init(mount: String) {
        this.mount = mount
        this.usedBytes = 0
        this.totalBytes = 0
    }

    init(mount: String, usedBytes: Int64, totalBytes: Int64) {
        this.mount = mount
        this.usedBytes = usedBytes
        this.totalBytes = totalBytes
    }

    func percent(): Int64 {
        percentOf(usedBytes, totalBytes)
    }
}

class ProcessSample {
    let pid: Int64
    let name: String
    let command: String
    let state: String
    let cpuPercent100: Int64
    let memPercent100: Int64
    let virtBytes: Int64
    let rssBytes: Int64
    let startTime: Int64
    let cpuTotal: Int64

    init(
        pid: Int64,
        name: String,
        command: String,
        state: String,
        cpuPercent100: Int64,
        memPercent100: Int64,
        virtBytes: Int64,
        rssBytes: Int64,
        startTime: Int64,
        cpuTotal: Int64
    ) {
        this.pid = pid
        this.name = name
        this.command = command
        this.state = state
        this.cpuPercent100 = cpuPercent100
        this.memPercent100 = memPercent100
        this.virtBytes = virtBytes
        this.rssBytes = rssBytes
        this.startTime = startTime
        this.cpuTotal = cpuTotal
    }
}

class ProcessDisplayRow {
    let pid: String
    let cpu: String
    let mem: String
    let virt: String
    let state: String
    let command: String

    init(proc: ProcessSample, commandWidth: Int64) {
        this.pid = padLeft("${proc.pid}", 5)
        this.cpu = padLeft(percent2(proc.cpuPercent100), 7)
        this.mem = padLeft(percent2(proc.memPercent100) + "%(" + bytesText(proc.rssBytes) + ")", 14)
        this.virt = padLeft(bytesText(proc.virtBytes), 8)
        this.state = truncateLocal(proc.state, 2)
        this.command = truncateLocal(proc.command, commandWidth)
    }

    func columns(): Array<String> {
        [pid, cpu, mem, virt, state, command]
    }
}

class MetricSnapshot {
    let cpu: CpuSnapshot
    let mem: MemSnapshot
    let net: NetSnapshot
    let disks: Array<DiskSample>
    let processes: Array<ProcessSample>
    let scanned: Int64
    let skipped: Int64
    let sampleMillis: Int64
    let error: String

    init() {
        this.cpu = CpuSnapshot()
        this.mem = MemSnapshot()
        this.net = NetSnapshot()
        this.disks = []
        this.processes = []
        this.scanned = 0
        this.skipped = 0
        this.sampleMillis = 0
        this.error = "waiting for first sample"
    }

    init(
        cpu: CpuSnapshot,
        mem: MemSnapshot,
        net: NetSnapshot,
        disks: Array<DiskSample>,
        processes: Array<ProcessSample>,
        scanned: Int64,
        skipped: Int64,
        sampleMillis: Int64,
        error: String
    ) {
        this.cpu = cpu
        this.mem = mem
        this.net = net
        this.disks = disks
        this.processes = processes
        this.scanned = scanned
        this.skipped = skipped
        this.sampleMillis = sampleMillis
        this.error = error
    }
}

class ProcFsSampler {
    private var previousCpu = CpuCounters()
    private var previousCores: Array<CpuCounters> = []
    private var previousNet = NetCounters()
    private var previousNetTime: ?MonoTime = None
    private var previousProc = HashMap<Int64, ProcPrev>()
    private var lastCpuTotalDelta: Int64 = 1
    private var lastCpuCoreCount: Int64 = 1
    private var lastMemTotalKb: Int64 = 1
    private var initialized = false
    private var netInitialized = false

    func sample(sortMode: SortMode, filter: String): MetricSnapshot {
        let start = MonoTime.now()
        var error = ""
        let cpu = sampleCpu()
        let mem = sampleMem()
        let net = sampleNet()
        let disks = sampleDisks()
        lastMemTotalKb = max(1, mem.totalKb)
        let (processes, scanned, skipped) = sampleProcesses(processCpuDelta(), lastMemTotalKb, sortMode, filter)
        initialized = true
        let elapsed = max(0, (MonoTime.now() - start).toMilliseconds())
        if (cpu.cores.size == 0) { error = "cpu unavailable" }
        MetricSnapshot(cpu, mem, net, disks, processes, scanned, skipped, elapsed, error)
    }

    func sampleCpuOnly(): CpuSnapshot {
        sampleCpu()
    }

    func sampleMemoryOnly(): MemSnapshot {
        sampleMem()
    }

    func sampleNetworkOnly(): NetSnapshot {
        sampleNet()
    }

    func sampleDisksOnly(): Array<DiskSample> {
        sampleDisks()
    }

    func sampleProcessesOnly(sortMode: SortMode, filter: String): MetricSnapshot {
        let start = MonoTime.now()
        let cpu = sampleCpuTotalsOnly()
        let memTotalKb = sampleMemTotalKbOnly()
        let (processes, scanned, skipped) = sampleProcesses(processCpuDelta(), memTotalKb, sortMode, filter)
        let elapsed = max(0, (MonoTime.now() - start).toMilliseconds())
        let error = if (cpu.cores.size == 0) { "cpu unavailable" } else { "" }
        MetricSnapshot(CpuSnapshot(), MemSnapshot(), NetSnapshot(), [], processes, scanned, skipped, elapsed, error)
    }

    private func sampleCpu(): CpuSnapshot {
        let text = readTextSafe("/proc/stat")
        match (text) {
            case None => return CpuSnapshot()
            case Some(body) =>
                let lines = splitBy(body, b'\n')
                var total = CpuCounters()
                let cores = ArrayList<CpuCounters>()
                for (line in lines) {
                    if (line.startsWith("cpu ")) {
                        total = parseCpuLine(line)
                    } else if (line.startsWith("cpu") && line.size > 3 && isDigit(line[3])) {
                        cores.add(parseCpuLine(line))
                    }
                }
                lastCpuTotalDelta = max(1, total.total - previousCpu.total)
                lastCpuCoreCount = max(1, cores.size)
                let usage = cpuUsage(total, previousCpu)
                let coreUsages = ArrayList<Int64>()
                for (i in 0..cores.size) {
                    let prev = if (i < previousCores.size) { previousCores[i] } else { CpuCounters() }
                    coreUsages.add(cpuUsage(cores[i], prev))
                }
                previousCpu = total
                previousCores = cores.toArray()
                CpuSnapshot(usage, coreUsages.toArray())
        }
    }

    private func sampleCpuTotalsOnly(): CpuSnapshot {
        let text = readTextSafe("/proc/stat")
        match (text) {
            case None => return CpuSnapshot()
            case Some(body) =>
                var total = CpuCounters()
                var cores: Int64 = 0
                for (line in splitBy(body, b'\n')) {
                    if (line.startsWith("cpu ")) {
                        total = parseCpuLine(line)
                    } else if (line.startsWith("cpu") && line.size > 3 && isDigit(line[3])) {
                        cores++
                    }
                    if (cores > 0 && !line.startsWith("cpu")) { break }
                }
                let usage = cpuUsage(total, previousCpu)
                lastCpuTotalDelta = max(1, total.total - previousCpu.total)
                lastCpuCoreCount = max(1, cores)
                previousCpu = total
                CpuSnapshot(usage, [])
        }
    }

    private func processCpuDelta(): Int64 {
        max(1, lastCpuTotalDelta / max(1, lastCpuCoreCount))
    }

    private func sampleMem(): MemSnapshot {
        match (readTextSafe("/proc/meminfo")) {
            case None => MemSnapshot()
            case Some(body) =>
                var total: Int64 = 0
                var available: Int64 = 0
                var swapTotal: Int64 = 0
                var swapFree: Int64 = 0
                for (line in splitBy(body, b'\n')) {
                    let fields = words(line)
                    if (fields.size < 2) { continue }
                    let value = parseInt(fields[1])
                    match (fields[0]) {
                        case "MemTotal:" => total = value
                        case "MemAvailable:" => available = value
                        case "SwapTotal:" => swapTotal = value
                        case "SwapFree:" => swapFree = value
                        case _ => ()
                    }
                }
                lastMemTotalKb = max(1, total)
                MemSnapshot(total, max(0, total - available), swapTotal, max(0, swapTotal - swapFree))
        }
    }

    private func sampleMemTotalKbOnly(): Int64 {
        match (readTextSafe("/proc/meminfo")) {
            case None => lastMemTotalKb
            case Some(body) =>
                for (line in splitBy(body, b'\n')) {
                    if (!line.startsWith("MemTotal:")) { continue }
                    let fields = words(line)
                    if (fields.size >= 2) {
                        lastMemTotalKb = max(1, parseInt(fields[1]))
                        return lastMemTotalKb
                    }
                }
                lastMemTotalKb
        }
    }

    private func sampleNet(): NetSnapshot {
        match (readTextSafe("/proc/net/dev")) {
            case None => NetSnapshot()
            case Some(body) =>
                let now = MonoTime.now()
                var rx: Int64 = 0
                var tx: Int64 = 0
                for (line in splitBy(body, b'\n')) {
                    if (!line.contains(":")) { continue }
                    let parts = splitBy(line, b':')
                    if (parts.size < 2) { continue }
                    let name = trimAscii(parts[0])
                    if (name == "lo" || name.isEmpty()) { continue }
                    let fields = words(parts[1])
                    if (fields.size >= 16) {
                        rx += parseInt(fields[0])
                        tx += parseInt(fields[8])
                    }
                }
                let elapsedMillis = match (previousNetTime) {
                    case Some(prev) => max(1, (now - prev).toMilliseconds())
                    case None => 1000
                }
                let ready = initialized || netInitialized
                let rxRate = if (ready) { max(0, rx - previousNet.rx) * 1000 / elapsedMillis } else { 0 }
                let txRate = if (ready) { max(0, tx - previousNet.tx) * 1000 / elapsedMillis } else { 0 }
                previousNet = NetCounters(rx, tx)
                previousNetTime = Some(now)
                netInitialized = true
                NetSnapshot(rxRate, txRate)
        }
    }

    private func sampleDisks(): Array<DiskSample> {
        let out = ArrayList<DiskSample>()
        match (readTextSafe("/proc/self/mountinfo")) {
            case None => return out.toArray()
            case Some(body) =>
                for (line in splitBy(body, b'\n')) {
                    let fields = words(line)
                    if (fields.size < 10) { continue }
                    let mount = unescapeMount(fields[4])
                    let fsType = fsTypeFromMountInfo(fields)
                    if (!interestingMount(mount, fsType)) { continue }
                    if (containsDisk(out, mount)) { continue }
                    let disk = statDisk(mount)
                    out.add(disk)
                    if (out.size >= 6) { break }
                }
        }
        out.toArray()
    }

    private func sampleProcesses(totalDelta: Int64, memTotalKb: Int64, sortMode: SortMode, filter: String): (Array<ProcessSample>, Int64, Int64) {
        let rows = ArrayList<ProcessSample>()
        var scanned: Int64 = 0
        var skipped: Int64 = 0
        let nextPrev = HashMap<Int64, ProcPrev>()
        try {
            for (entry in Directory.readFrom("/proc")) {
                let pid = parsePid(entry.name)
                if (pid < 0) { continue }
                scanned++
                match (readProcess(pid, totalDelta, memTotalKb, false)) {
                    case Some(proc) =>
                        nextPrev.add(pid, ProcPrev(proc.cpuTotal, proc.startTime))
                        if (filter.isEmpty() || proc.name.contains(filter) || "${proc.pid}".contains(filter)) {
                            rows.add(proc)
                        } else {
                            let cmd = processCommand(pid, proc.name)
                            if (cmd.contains(filter)) {
                                rows.add(ProcessSample(proc.pid, proc.name, cmd, proc.state, proc.cpuPercent100, proc.memPercent100, proc.virtBytes, proc.rssBytes, proc.startTime, proc.cpuTotal))
                            }
                        }
                    case None => skipped++
                }
            }
        } catch (_) {
            skipped++
        }
        previousProc = nextPrev
        sortProcesses(rows, sortMode)
        while (rows.size > MAX_PROCESSES) {
            rows.remove(at: rows.size - 1)
        }
        let enriched = ArrayList<ProcessSample>()
        for (proc in rows) {
            enriched.add(withDisplayCommand(proc))
        }
        (enriched.toArray(), scanned, skipped)
    }

    private func readProcess(pid: Int64, totalDelta: Int64, memTotalKb: Int64, includeCommand: Bool): ?ProcessSample {
        match (readTextSafe("/proc/${pid}/stat")) {
            case None => return None
            case Some(stat) =>
                match (parseProcStat(stat)) {
                    case None => return None
                    case Some(raw) =>
                        let previous = previousProc.get(pid)
                        var cpuPercent100 = 0
                        match (previous) {
                            case Some(prev) =>
                                if (prev.startTime == raw.startTime) {
                                    cpuPercent100 = clampLocal((raw.cpuTotal - prev.total) * 10000 / max(1, totalDelta), 0, 99900)
                                }
                            case None => ()
                        }
                        let cmd = if (includeCommand) { processCommand(pid, raw.name) } else { raw.name }
                        let memPercent100 = clampLocal(raw.rssBytes * 10000 / max(1, memTotalKb * 1024), 0, 10000)
                        Some(ProcessSample(pid, raw.name, cmd, raw.state, cpuPercent100, memPercent100, raw.virtBytes, raw.rssBytes, raw.startTime, raw.cpuTotal))
                }
        }
    }

    private func withDisplayCommand(proc: ProcessSample): ProcessSample {
        if (proc.command != proc.name) { return proc }
        let cmd = processCommand(proc.pid, proc.name)
        ProcessSample(proc.pid, proc.name, cmd, proc.state, proc.cpuPercent100, proc.memPercent100, proc.virtBytes, proc.rssBytes, proc.startTime, proc.cpuTotal)
    }
}

class RawProcStat {
    let name: String
    let state: String
    let cpuTotal: Int64
    let startTime: Int64
    let virtBytes: Int64
    let rssBytes: Int64

    init(name: String, state: String, cpuTotal: Int64, startTime: Int64, virtBytes: Int64, rssBytes: Int64) {
        this.name = name
        this.state = state
        this.cpuTotal = cpuTotal
        this.startTime = startTime
        this.virtBytes = virtBytes
        this.rssBytes = rssBytes
    }
}

class BtmPanelCounters {
    let id: String
    var updateCount: Int64 = 0
    var renderCount: Int64 = 0

    init(id: String) {
        this.id = id
    }
}

class BtmClone <: Widget {
    private let interactiveProcessSampler = ProcFsSampler()
    private let backgroundProcessSampler = ProcFsSampler()
    private let cpuSampler = ProcFsSampler()
    private let memorySampler = ProcFsSampler()
    private let networkSampler = ProcFsSampler()
    private let diskSampler = ProcFsSampler()
    private let metrics: AppMetrics
    private let completionLock = Mutex()
    private var completedProcess: ?ProcessSnapshotResult = None
    private var completedCpu: ?CpuSnapshot = None
    private var completedMemory: ?MemSnapshot = None
    private var completedNetwork: ?NetSnapshot = None
    private var completedDisks: ?Array<DiskSample> = None
    private var processPending = false
    private var cpuPending = false
    private var memoryPending = false
    private var networkPending = false
    private var diskPending = false
    private var processLastActivity: Int64 = 0
    private let panelCounters = ArrayList<BtmPanelCounters>()
    private var snapshot = MetricSnapshot()
    private var processRows: Array<ProcessDisplayRow> = []
    private var processRowsCommandWidth: Int64 = -1
    private var selected: Int64 = 0
    private var processOffset: Int64 = 0
    private var sortMode = SortMode.Cpu
    private var paused = false
    private var filtering = false
    private let filterInput = Input()
    private var showDetail = false
    private var showProfiler = false
    private let cpuHistory = HistoryRing(HISTORY_CAPACITY)
    private let memHistory = HistoryRing(HISTORY_CAPACITY)
    private let netHistory = HistoryRing(HISTORY_CAPACITY)
    private var cpuValues: Array<Int64> = []
    private var memValues: Array<Int64> = []
    private var netValues: Array<Int64> = []
    private var lastArea: ?Rect = None
    private var lastProcessArea: ?Rect = None
    private var lastProcessVisibleRows: Int64 = 0
    private var dataClock: Int64 = 0
    private var processRequestId: Int64 = 0
    private var latestAppliedProcessRequestId: Int64 = 0
    private var refreshMillis: Int64 = 1000
    private var headerArea = Rect(0, 0, 0, 0)
    private var cpuArea = Rect(0, 0, 0, 0)
    private var memoryArea = Rect(0, 0, 0, 0)
    private var networkArea = Rect(0, 0, 0, 0)
    private var diskArea = Rect(0, 0, 0, 0)
    private var processesArea = Rect(0, 0, 0, 0)
    private var footerArea = Rect(0, 0, 0, 0)

    init(metrics!: AppMetrics = AppMetrics()) {
        this.metrics = metrics
        for (id in ["header", "cpu", "memory", "network", "disk", "processes", "footer"]) {
            panelCounters.add(BtmPanelCounters(id))
        }
        refresh()
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                if (filtering) {
                    return handleKey(key)
                }
                match (key.code) {
                    case KeyCode.Down | KeyCode.Char(r'j') =>
                        recordPanelUpdate("processes")
                        moveProcessSelection(1)
                    case KeyCode.Up | KeyCode.Char(r'k') =>
                        recordPanelUpdate("processes")
                        moveProcessSelection(-1)
                    case KeyCode.Enter =>
                        recordPanelUpdate("processes")
                        toggleProcessDetail()
                    case _ => handleKey(key)
                }
            case Event.Tick(_) => UpdateResult.next()
            case Event.Timer(timer) =>
                match (timer.id) {
                    case "cpu" | "memory" | "network" | "disk" => requestMetricSample(timer.id)
                    case "proc" => requestProcessSample()
                    case _ => UpdateResult.next()
                }
            case Event.AsyncCompleted(id, _) => applyAsyncCompletion(id)
            case Event.AsyncFailed(id, _) => applyAsyncFailure(id)
            case Event.AsyncCancelled(id) => applyAsyncFailure(id)
            case Event.Capabilities(_) => UpdateResult(command: startRefreshTimers())
            case Event.Resize(_) => dirtyKnownArea()
            case _ => UpdateResult.next()
        }
    }

    private func handleKey(key: KeyEvent): UpdateResult {
        if (filtering) {
            var changed = false
            match (key.code) {
                case KeyCode.Esc =>
                    filtering = false
                    if (!filterInput.value.isEmpty()) {
                        filterInput.clear()
                        refreshProcessesOnly()
                        changed = true
                    }
                case KeyCode.Enter =>
                    filtering = false
                    refreshProcessesOnly()
                    changed = true
                case KeyCode.Backspace =>
                    if (!filterInput.value.isEmpty()) {
                        _ = filterInput.handle(key)
                        refreshProcessesOnly()
                        changed = true
                    }
                case KeyCode.Char(ch) =>
                    _ = filterInput.handle(KeyEvent(KeyCode.Char(ch)))
                    refreshProcessesOnly()
                    changed = true
                case _ => ()
            }
            if (changed) {
                return dirtyHeaderFooterProcesses()
            }
            return dirtyFooterArea()
        }
        match (key.code) {
            case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
            case KeyCode.Char(r'c') => setSort(SortMode.Cpu)
            case KeyCode.Char(r'm') => setSort(SortMode.Memory)
            case KeyCode.Char(r'p') => setSort(SortMode.Pid)
            case KeyCode.Char(r'n') => setSort(SortMode.Name)
            case KeyCode.Char(r'/') =>
                filtering = true
                filterInput.moveToEnd()
                UpdateResult.next()
            case KeyCode.Char(r' ') =>
                paused = !paused
                dirtyKnownArea()
            case KeyCode.Char(r'd') =>
                showProfiler = !showProfiler
                dirtyKnownArea()
            case KeyCode.Char(r'+') | KeyCode.Char(r'=') => adjustRefreshInterval(-REFRESH_STEP_MILLIS)
            case KeyCode.Char(r'-') | KeyCode.Char(r'_') => adjustRefreshInterval(REFRESH_STEP_MILLIS)
            case KeyCode.Enter =>
                showDetail = !showDetail
                dirtyProcessesArea()
            case _ => UpdateResult.next()
        }
    }

    private func setSort(mode: SortMode): UpdateResult {
        sortMode = mode
        refreshProcessesOnly()
        dirtyHeaderFooterProcesses()
    }

    public func refreshInterval(): Duration {
        Duration.millisecond * refreshMillis
    }

    private func adjustRefreshInterval(deltaMillis: Int64): UpdateResult {
        let next = clampLocal(refreshMillis + deltaMillis, MIN_REFRESH_MILLIS, MAX_REFRESH_MILLIS)
        if (next == refreshMillis) {
            return dirtyFooterArea()
        }
        refreshMillis = next
        UpdateResult(command: restartRefreshTimers(), dirtyRects: dirtyFooterRects())
    }

    private func restartRefreshTimers(): Command {
        Command.Batch([
            Command.RestartTimer(TimerSpec("cpu", refreshInterval())),
            Command.RestartTimer(TimerSpec("memory", refreshInterval())),
            Command.RestartTimer(TimerSpec("network", refreshInterval())),
            Command.RestartTimer(TimerSpec("disk", refreshInterval())),
            Command.RestartTimer(TimerSpec("proc", refreshInterval()))
        ])
    }

    private func startRefreshTimers(): Command {
        Command.Batch([
            Command.StartTimer(TimerSpec("cpu", refreshInterval())),
            Command.StartTimer(TimerSpec("memory", refreshInterval())),
            Command.StartTimer(TimerSpec("network", refreshInterval())),
            Command.StartTimer(TimerSpec("disk", refreshInterval())),
            Command.StartTimer(TimerSpec("proc", refreshInterval()))
        ])
    }

    public func refresh(): Unit {
        snapshot = interactiveProcessSampler.sample(sortMode, filterInput.value)
        invalidateProcessRows()
        selected = clampLocal(selected, 0, max(0, snapshot.processes.size - 1))
        processOffset = clampLocal(processOffset, 0, max(0, snapshot.processes.size - 1))
        updateHistory()
    }

    private func refreshProcessesOnly(): Unit {
        let next = interactiveProcessSampler.sampleProcessesOnly(sortMode, filterInput.value)
        snapshot = MetricSnapshot(snapshot.cpu, snapshot.mem, snapshot.net, snapshot.disks, next.processes, next.scanned, next.skipped, next.sampleMillis, next.error)
        invalidateProcessRows()
        selected = clampLocal(selected, 0, max(0, snapshot.processes.size - 1))
        processOffset = clampLocal(processOffset, 0, max(0, snapshot.processes.size - 1))
    }

    private func updateHistory(): Unit {
        cpuHistory.push(snapshot.cpu.usage)
        memHistory.push(snapshot.mem.percent())
        netHistory.push(snapshot.net.percent())
        updateHistoryArrays()
    }

    private func updateHistoryArrays(): Unit {
        cpuValues = cpuHistory.toArray()
        memValues = memHistory.toArray()
        netValues = netHistory.toArray()
    }

    private func nextDataClock(): Int64 {
        dataClock++
        dataClock
    }

    private func markNavigation(): Unit {
        processLastActivity = nextDataClock()
    }

    private func nextProcessRequestId(): Int64 {
        processRequestId++
        processRequestId
    }

    private func requestMetricSample(panelId: String): UpdateResult {
        if (paused) { return UpdateResult.next() }
        _ = nextDataClock()
        match (panelId) {
            case "cpu" =>
                if (cpuPending) { return UpdateResult.next() }
                cpuPending = true
                recordPanelUpdate("cpu")
                UpdateResult(command: Command.AsyncTask("btm:cpu", { =>
                    publishCpu(cpuSampler.sampleCpuOnly())
                    Event.Message("btm:cpu-ready")
                }))
            case "memory" =>
                if (memoryPending) { return UpdateResult.next() }
                memoryPending = true
                recordPanelUpdate("memory")
                UpdateResult(command: Command.AsyncTask("btm:memory", { =>
                    publishMemory(memorySampler.sampleMemoryOnly())
                    Event.Message("btm:memory-ready")
                }))
            case "network" =>
                if (networkPending) { return UpdateResult.next() }
                networkPending = true
                recordPanelUpdate("network")
                UpdateResult(command: Command.AsyncTask("btm:network", { =>
                    publishNetwork(networkSampler.sampleNetworkOnly())
                    Event.Message("btm:network-ready")
                }))
            case "disk" =>
                if (diskPending) { return UpdateResult.next() }
                diskPending = true
                recordPanelUpdate("disk")
                UpdateResult(command: Command.AsyncTask("btm:disk", { =>
                    publishDisks(diskSampler.sampleDisksOnly())
                    Event.Message("btm:disk-ready")
                }))
            case _ => UpdateResult.next()
        }
    }

    private func requestProcessSample(): UpdateResult {
        if (paused || processPending) { return UpdateResult.next() }
        let now = nextDataClock()
        if (now - processLastActivity < 2) { return UpdateResult.next() }
        processPending = true
        recordPanelUpdate("processes")
        let requestId = nextProcessRequestId()
        let requestSort = sortMode
        let requestFilter = filterInput.value
        UpdateResult(command: Command.AsyncTask("btm:processes", { =>
            publishProcess(ProcessSnapshotResult(
                requestId,
                requestSort,
                requestFilter,
                backgroundProcessSampler.sampleProcessesOnly(requestSort, requestFilter)
            ))
            Event.Message("btm:processes-ready")
        }))
    }

    private func applyAsyncCompletion(id: String): UpdateResult {
        match (id) {
            case "btm:cpu" =>
                cpuPending = false
                match (takeCpu()) {
                    case Some(cpu) =>
                        snapshot = MetricSnapshot(cpu, snapshot.mem, snapshot.net, snapshot.disks, snapshot.processes, snapshot.scanned, snapshot.skipped, snapshot.sampleMillis, snapshot.error)
                        cpuHistory.push(cpu.usage)
                        updateHistoryArrays()
                    case None => ()
                }
                recordPanelUpdate("cpu")
                dirtyMetricPanel("cpu")
            case "btm:memory" =>
                memoryPending = false
                match (takeMemory()) {
                    case Some(mem) =>
                        snapshot = MetricSnapshot(snapshot.cpu, mem, snapshot.net, snapshot.disks, snapshot.processes, snapshot.scanned, snapshot.skipped, snapshot.sampleMillis, snapshot.error)
                        memHistory.push(mem.percent())
                        updateHistoryArrays()
                    case None => ()
                }
                recordPanelUpdate("memory")
                dirtyMetricPanel("memory")
            case "btm:network" =>
                networkPending = false
                match (takeNetwork()) {
                    case Some(net) =>
                        snapshot = MetricSnapshot(snapshot.cpu, snapshot.mem, net, snapshot.disks, snapshot.processes, snapshot.scanned, snapshot.skipped, snapshot.sampleMillis, snapshot.error)
                        netHistory.push(net.percent())
                        updateHistoryArrays()
                    case None => ()
                }
                recordPanelUpdate("network")
                dirtyMetricPanel("network")
            case "btm:disk" =>
                diskPending = false
                match (takeDisks()) {
                    case Some(disks) => snapshot = MetricSnapshot(snapshot.cpu, snapshot.mem, snapshot.net, disks, snapshot.processes, snapshot.scanned, snapshot.skipped, snapshot.sampleMillis, snapshot.error)
                    case None => ()
                }
                recordPanelUpdate("disk")
                dirtyMetricPanel("disk")
            case "btm:processes" =>
                processPending = false
                match (takeProcess()) {
                    case Some(next) => applyProcessCompletion(next)
                    case None => ()
                }
                recordPanelUpdate("processes")
                dirtyHeaderFooterProcesses()
            case _ => UpdateResult.next()
        }
    }

    private func applyAsyncFailure(id: String): UpdateResult {
        match (id) {
            case "btm:cpu" => cpuPending = false
            case "btm:memory" => memoryPending = false
            case "btm:network" => networkPending = false
            case "btm:disk" => diskPending = false
            case "btm:processes" => processPending = false
            case _ => return UpdateResult.next()
        }
        dirtyPanelArea(if (id == "btm:processes") { "processes" } else { id[4..] })
    }

    private func applyProcessCompletion(next: ProcessSnapshotResult): Unit {
        if (next.requestId < latestAppliedProcessRequestId || next.sortMode != sortMode || next.filter != filterInput.value) {
            return
        }
        latestAppliedProcessRequestId = next.requestId
        let processSnapshot = next.snapshot
        snapshot = MetricSnapshot(snapshot.cpu, snapshot.mem, snapshot.net, snapshot.disks, processSnapshot.processes, processSnapshot.scanned, processSnapshot.skipped, processSnapshot.sampleMillis, processSnapshot.error)
        invalidateProcessRows()
        selected = clampLocal(selected, 0, max(0, snapshot.processes.size - 1))
        processOffset = clampLocal(processOffset, 0, max(0, snapshot.processes.size - 1))
    }

    // Background tasks publish immutable samples into these app-local slots.
    // Only update(Event) consumes them and mutates the canonical application state.
    private func publishCpu(value: CpuSnapshot): Unit {
        completionLock.lock()
        try { completedCpu = Some(value) } finally { completionLock.unlock() }
    }

    private func publishMemory(value: MemSnapshot): Unit {
        completionLock.lock()
        try { completedMemory = Some(value) } finally { completionLock.unlock() }
    }

    private func publishNetwork(value: NetSnapshot): Unit {
        completionLock.lock()
        try { completedNetwork = Some(value) } finally { completionLock.unlock() }
    }

    private func publishDisks(value: Array<DiskSample>): Unit {
        completionLock.lock()
        try { completedDisks = Some(value) } finally { completionLock.unlock() }
    }

    private func publishProcess(value: ProcessSnapshotResult): Unit {
        completionLock.lock()
        try { completedProcess = Some(value) } finally { completionLock.unlock() }
    }

    private func takeCpu(): ?CpuSnapshot {
        completionLock.lock()
        try {
            let value = completedCpu
            completedCpu = None
            value
        } finally { completionLock.unlock() }
    }

    private func takeMemory(): ?MemSnapshot {
        completionLock.lock()
        try {
            let value = completedMemory
            completedMemory = None
            value
        } finally { completionLock.unlock() }
    }

    private func takeNetwork(): ?NetSnapshot {
        completionLock.lock()
        try {
            let value = completedNetwork
            completedNetwork = None
            value
        } finally { completionLock.unlock() }
    }

    private func takeDisks(): ?Array<DiskSample> {
        completionLock.lock()
        try {
            let value = completedDisks
            completedDisks = None
            value
        } finally { completionLock.unlock() }
    }

    private func takeProcess(): ?ProcessSnapshotResult {
        completionLock.lock()
        try {
            let value = completedProcess
            completedProcess = None
            value
        } finally { completionLock.unlock() }
    }

    private func panelProfile(id: String): ?BtmPanelCounters {
        for (profile in panelCounters) {
            if (profile.id == id) { return Some(profile) }
        }
        None
    }

    private func recordPanelUpdate(id: String): Unit {
        match (panelProfile(id)) {
            case Some(profile) => profile.updateCount++
            case None => ()
        }
    }

    private func recordPanelRender(id: String): Unit {
        match (panelProfile(id)) {
            case Some(profile) => profile.renderCount++
            case None => ()
        }
    }

    func panelUpdateCount(id: String): Int64 {
        match (panelProfile(id)) {
            case Some(profile) => profile.updateCount
            case None => -1
        }
    }

    func panelRenderCount(id: String): Int64 {
        match (panelProfile(id)) {
            case Some(profile) => profile.renderCount
            case None => -1
        }
    }

    func appliedProcessRequestId(): Int64 {
        latestAppliedProcessRequestId
    }

    public func moveProcessSelection(delta: Int64): UpdateResult {
        let beforeSelected = selected
        let beforeOffset = processOffset
        selected = clampLocal(selected + delta, 0, max(0, snapshot.processes.size - 1))
        markNavigation()
        selectionDirty(beforeSelected, beforeOffset)
    }

    public func toggleProcessDetail(): UpdateResult {
        showDetail = !showDetail
        dirtyProcessesArea()
    }

    private func invalidateProcessRows(): Unit {
        processRows = []
        processRowsCommandWidth = -1
    }

    private func ensureProcessRows(commandWidth: Int64): Unit {
        if (processRowsCommandWidth == commandWidth && processRows.size == snapshot.processes.size) { return }
        let rows = ArrayList<ProcessDisplayRow>()
        for (proc in snapshot.processes) {
            rows.add(ProcessDisplayRow(proc, commandWidth))
        }
        processRows = rows.toArray()
        processRowsCommandWidth = commandWidth
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        lastArea = Some(area)
        let canvas = Canvas(buffer, area)
        canvas.fillRect(area, Style(bg: BG))
        if (area.width < 86 || area.height < 26) {
            renderSmall(canvas, area)
            return
        }
        let rows = Layout.vertical([
            Constraint.Length(1),
            Constraint.Percent(42),
            Constraint.Percent(25),
            Constraint.Min(8),
            Constraint.Length(1)
        ]).withGap(1).split(area)
        renderTopBar(buffer, rows[0])
        renderCpu(buffer, canvas, rows[1])
        let mid = Layout.horizontal([Constraint.Percent(34), Constraint.Percent(33), Constraint.Min(24)]).withGap(1).split(rows[2])
        renderMemory(buffer, canvas, mid[0])
        renderNetwork(buffer, canvas, mid[1])
        renderDisks(buffer, canvas, mid[2])
        renderProcesses(buffer, canvas, rows[3])
        renderBottomBar(buffer, rows[4])
    }

    public func renderFrame(frame: Frame): Unit {
        let area = frame.area
        lastArea = Some(area)
        for (dirty in frame.dirtyRects()) {
            let target = intersectLocal(area, dirty)
            if (target.width > 0 && target.height > 0) {
                frame.fill(target, Style(bg: BG))
            }
        }
        let canvas = frame.canvas(area: area)
        if (area.width < 86 || area.height < 26) {
            if (frame.isDirty(area)) {
                renderSmall(canvas, area)
            }
            return
        }
        let rows = Layout.vertical([
            Constraint.Length(1),
            Constraint.Percent(42),
            Constraint.Percent(25),
            Constraint.Min(8),
            Constraint.Length(1)
        ]).withGap(1).split(area)
        let mid = Layout.horizontal([Constraint.Percent(34), Constraint.Percent(33), Constraint.Min(24)]).withGap(1).split(rows[2])
        headerArea = rows[0]
        cpuArea = rows[1]
        memoryArea = mid[0]
        networkArea = mid[1]
        diskArea = mid[2]
        processesArea = rows[3]
        footerArea = rows[4]
        if (frame.isDirty(headerArea)) {
            renderTopBarFrame(frame, headerArea)
            recordPanelRender("header")
        }
        if (frame.isDirty(cpuArea)) {
            renderCpuFrame(frame, cpuArea)
            recordPanelRender("cpu")
        }
        if (frame.isDirty(memoryArea)) {
            renderMemoryFrame(frame, memoryArea)
            recordPanelRender("memory")
        }
        if (frame.isDirty(networkArea)) {
            renderNetworkFrame(frame, networkArea)
            recordPanelRender("network")
        }
        if (frame.isDirty(diskArea)) {
            renderDisksFrame(frame, diskArea)
            recordPanelRender("disk")
        }
        if (frame.isDirty(processesArea)) {
            renderProcessesFrame(frame, processesArea)
            recordPanelRender("processes")
        }
        if (frame.isDirty(footerArea)) {
            renderBottomBarFrame(frame, footerArea)
            recordPanelRender("footer")
        }
        if (showProfiler) {
            frame.renderWidget(
                DebugOverlay(metrics),
                Rect(area.x + 2, area.y + 2, min(area.width - 4, 72), 1)
            )
        }
    }

    private func renderSmall(canvas: Canvas, area: Rect): Unit {
        canvas.drawText(area.x + 1, area.y + 1, "btm_clone needs at least 86x26", Style(fg: TEXT, bg: BG))
        canvas.drawText(area.x + 1, area.y + 3, "resize terminal, q quits", Style(fg: MUTED, bg: BG))
    }

    private func renderTopBar(buffer: Buffer, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        let mode = if (paused) { "PAUSED" } else { "LIVE" }
        HeaderBar(
            "btm " + mode,
            left: "cpu  mem  net  disk  proc",
            right: "cpu ${snapshot.cpu.usage}%  mem ${snapshot.mem.percent()}%  scan ${snapshot.sampleMillis}ms  pids ${snapshot.scanned}",
            style: Style(fg: TEXT, bg: bg, modifier: Modifier.strong())
        ).render(area, buffer)
    }

    public func renderTopBarFrame(frame: Frame, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        let mode = if (paused) { "PAUSED" } else { "LIVE" }
        frame.renderWidget(HeaderBar(
            "btm " + mode,
            left: "cpu  mem  net  disk  proc",
            right: "cpu ${snapshot.cpu.usage}%  mem ${snapshot.mem.percent()}%  scan ${snapshot.sampleMillis}ms  pids ${snapshot.scanned}",
            style: Style(fg: TEXT, bg: bg, modifier: Modifier.strong())
        ), area)
    }

    private func renderCpu(buffer: Buffer, canvas: Canvas, area: Rect): Unit {
        let inner = panel(buffer, area, " CPU ")
        drawGraph(canvas, inner, cpuValues, 100, CYAN, "CPU", "%")
        let side = Rect(inner.right - 24, inner.y + 1, 22, min(10, inner.height - 2))
        canvas.fillRect(side, Style(bg: Color.Rgb(7, 12, 19)))
        canvas.strokeRect(side, Style(fg: GRID, bg: Color.Rgb(7, 12, 19)))
        let cores = snapshot.cpu.cores
        let limit = min(6, cores.size)
        for (i in 0..limit) {
            canvas.drawText(side.x + 2, side.y + 1 + i, "CPU${i}  ${padLeft("${cores[i]}", 3)}%", Style(fg: colorForIndex(i), bg: Color.Rgb(7, 12, 19)))
        }
        if (cores.size == 0) {
            canvas.drawText(side.x + 2, side.y + 1, "cpu unavailable", Style(fg: RED, bg: Color.Rgb(7, 12, 19)))
        }
    }

    public func renderCpuFrame(frame: Frame, area: Rect): Unit {
        let canvas = frame.canvas(area: area)
        let inner = panelFrame(frame, area, " CPU ")
        drawGraph(canvas, inner, cpuValues, 100, CYAN, "CPU", "%")
        let side = Rect(inner.right - 24, inner.y + 1, 22, min(10, inner.height - 2))
        canvas.fillRect(side, Style(bg: Color.Rgb(7, 12, 19)))
        canvas.strokeRect(side, Style(fg: GRID, bg: Color.Rgb(7, 12, 19)))
        let cores = snapshot.cpu.cores
        let limit = min(6, cores.size)
        for (i in 0..limit) {
            canvas.drawText(side.x + 2, side.y + 1 + i, "CPU${i}  ${padLeft("${cores[i]}", 3)}%", Style(fg: colorForIndex(i), bg: Color.Rgb(7, 12, 19)))
        }
        if (cores.size == 0) {
            canvas.drawText(side.x + 2, side.y + 1, "cpu unavailable", Style(fg: RED, bg: Color.Rgb(7, 12, 19)))
        }
    }

    private func renderMemory(buffer: Buffer, canvas: Canvas, area: Rect): Unit {
        let inner = panel(buffer, area, " Memory ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 4)), memValues, 100, GREEN, "RAM", "%")
        let y = inner.bottom - 3
        drawMeter(buffer, inner.x + 1, y, max(8, inner.width - 2), snapshot.mem.percent(), GREEN, "RAM " + bytesText(snapshot.mem.usedKb * 1024) + " / " + bytesText(snapshot.mem.totalKb * 1024))
        drawMeter(buffer, inner.x + 1, y + 1, max(8, inner.width - 2), snapshot.mem.swapPercent(), BLUE, "SWP " + bytesText(snapshot.mem.swapUsedKb * 1024) + " / " + bytesText(snapshot.mem.swapTotalKb * 1024))
    }

    public func renderMemoryFrame(frame: Frame, area: Rect): Unit {
        let canvas = frame.canvas(area: area)
        let inner = panelFrame(frame, area, " Memory ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 4)), memValues, 100, GREEN, "RAM", "%")
        let y = inner.bottom - 3
        drawMeterFrame(frame, inner.x + 1, y, max(8, inner.width - 2), snapshot.mem.percent(), GREEN, "RAM " + bytesText(snapshot.mem.usedKb * 1024) + " / " + bytesText(snapshot.mem.totalKb * 1024))
        drawMeterFrame(frame, inner.x + 1, y + 1, max(8, inner.width - 2), snapshot.mem.swapPercent(), BLUE, "SWP " + bytesText(snapshot.mem.swapUsedKb * 1024) + " / " + bytesText(snapshot.mem.swapTotalKb * 1024))
    }

    private func renderNetwork(buffer: Buffer, canvas: Canvas, area: Rect): Unit {
        let inner = panel(buffer, area, " Network ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 3)), netValues, 100, BLUE, "NET", "%")
        let y = inner.bottom - 2
        canvas.drawText(inner.x + 1, y, "RX " + rateText(snapshot.net.rxRate), Style(fg: BLUE, bg: PANEL))
        canvas.drawText(inner.x + max(18, inner.width / 2), y, "TX " + rateText(snapshot.net.txRate), Style(fg: CYAN, bg: PANEL))
    }

    public func renderNetworkFrame(frame: Frame, area: Rect): Unit {
        let canvas = frame.canvas(area: area)
        let inner = panelFrame(frame, area, " Network ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 3)), netValues, 100, BLUE, "NET", "%")
        let y = inner.bottom - 2
        canvas.drawText(inner.x + 1, y, "RX " + rateText(snapshot.net.rxRate), Style(fg: BLUE, bg: PANEL))
        canvas.drawText(inner.x + max(18, inner.width / 2), y, "TX " + rateText(snapshot.net.txRate), Style(fg: CYAN, bg: PANEL))
    }

    private func renderDisks(buffer: Buffer, canvas: Canvas, area: Rect): Unit {
        let inner = panel(buffer, area, " Disks ")
        let limit = min(snapshot.disks.size, max(0, (inner.height - 1) / 2))
        for (i in 0..limit) {
            let disk = snapshot.disks[i]
            let label = disk.mount + " " + if (disk.totalBytes > 0) { bytesText(disk.usedBytes) + "/" + bytesText(disk.totalBytes) } else { "unknown" }
            drawDisk(canvas, inner.x + 1, inner.y + 1 + i * 2, inner.width - 2, disk.percent(), label, colorForIndex(i))
        }
        if (limit == 0) {
            canvas.drawText(inner.x + 1, inner.y + 1, "no mount data", Style(fg: MUTED, bg: PANEL))
        }
    }

    public func renderDisksFrame(frame: Frame, area: Rect): Unit {
        let canvas = frame.canvas(area: area)
        let inner = panelFrame(frame, area, " Disks ")
        let limit = min(snapshot.disks.size, max(0, (inner.height - 1) / 2))
        for (i in 0..limit) {
            let disk = snapshot.disks[i]
            let label = disk.mount + " " + if (disk.totalBytes > 0) { bytesText(disk.usedBytes) + "/" + bytesText(disk.totalBytes) } else { "unknown" }
            drawDisk(canvas, inner.x + 1, inner.y + 1 + i * 2, inner.width - 2, disk.percent(), label, colorForIndex(i))
        }
        if (limit == 0) {
            canvas.drawText(inner.x + 1, inner.y + 1, "no mount data", Style(fg: MUTED, bg: PANEL))
        }
    }

    private func renderProcesses(buffer: Buffer, canvas: Canvas, area: Rect): Unit {
        let inner = panel(buffer, area, " Processes ")
        let detailRows = if (showDetail) { 4 } else { 0 }
        let tableArea = Rect(inner.x + 1, inner.y, max(1, inner.width - 2), max(0, inner.height - detailRows))
        let visibleRows = max(0, tableArea.height - 1)
        lastProcessArea = Some(tableArea)
        lastProcessVisibleRows = visibleRows
        ensureProcessVisible(visibleRows)
        let commandWidth = max(12, tableArea.width - 44)
        ensureProcessRows(commandWidth)
        let table = VirtualTable(
            [
                TableColumn("PID", width: 5, align: TextAlign.Right),
                TableColumn("CPU%", width: 7, align: TextAlign.Right),
                TableColumn("MEM(RSS)", width: 14, align: TextAlign.Right),
                TableColumn("VIRT", width: 8, align: TextAlign.Right),
                TableColumn("S", width: 2),
                TableColumn("COMMAND", width: commandWidth)
            ],
            snapshot.processes.size,
            { index => processRows[index].columns() },
            offset: processOffset,
            selectedRow: Some(selected),
            style: PROCESS_NORMAL_STYLE,
            selectedStyle: PROCESS_SELECTED_STYLE,
            cellStyle: PROCESS_SELECTED_STYLE
        )
        table.render(tableArea, buffer)
        if (showDetail && selected < snapshot.processes.size) {
            renderProcessDetail(canvas, Rect(inner.x + 1, inner.bottom - 4, inner.width - 2, 4), snapshot.processes[selected])
        }
    }

    public func renderProcessesFrame(frame: Frame, area: Rect): Unit {
        let block = panelBlock(" Processes ")
        let inner = block.inner(area)
        let detailRows = if (showDetail) { 4 } else { 0 }
        let tableArea = Rect(inner.x + 1, inner.y, max(1, inner.width - 2), max(0, inner.height - detailRows))
        let visibleRows = max(0, tableArea.height - 1)
        lastProcessArea = Some(tableArea)
        lastProcessVisibleRows = visibleRows
        ensureProcessVisible(visibleRows)
        if (isProcessRowOnlyDirty(frame, tableArea)) {
            renderProcessRows(frame, tableArea)
            return
        }
        frame.renderWidget(Panel(block: block), area)
        let commandWidth = max(12, tableArea.width - 44)
        ensureProcessRows(commandWidth)
        let table = VirtualTable(
            [
                TableColumn("PID", width: 5, align: TextAlign.Right),
                TableColumn("CPU%", width: 7, align: TextAlign.Right),
                TableColumn("MEM(RSS)", width: 14, align: TextAlign.Right),
                TableColumn("VIRT", width: 8, align: TextAlign.Right),
                TableColumn("S", width: 2),
                TableColumn("COMMAND", width: commandWidth)
            ],
            snapshot.processes.size,
            { index => processRows[index].columns() },
            offset: processOffset,
            selectedRow: Some(selected),
            style: PROCESS_NORMAL_STYLE,
            selectedStyle: PROCESS_SELECTED_STYLE,
            cellStyle: PROCESS_SELECTED_STYLE
        )
        frame.renderWidget(table, tableArea)
        if (showDetail && selected < snapshot.processes.size) {
            renderProcessDetail(frame.canvas(area: area), Rect(inner.x + 1, inner.bottom - 4, inner.width - 2, 4), snapshot.processes[selected])
        }
    }

    private func isProcessRowOnlyDirty(frame: Frame, tableArea: Rect): Bool {
        var hit = false
        for (dirty in frame.dirtyRects()) {
            let target = intersectLocal(dirty, tableArea)
            if (target.width <= 0 || target.height <= 0) { continue }
            hit = true
            if (target.x < tableArea.x || target.right > tableArea.right) { return false }
            if (target.y <= tableArea.y || target.bottom > tableArea.bottom) { return false }
        }
        hit
    }

    private func renderProcessRows(frame: Frame, tableArea: Rect): Unit {
        frame.renderWidget(ProcessRowsWidget(this, frame.dirtyRects(), tableArea), tableArea)
    }

    public func renderProcessRowsBuffer(buffer: Buffer, tableArea: Rect, dirtyRects: Array<Rect>): Unit {
        let commandWidth = max(12, tableArea.width - 44)
        ensureProcessRows(commandWidth)
        for (dirty in dirtyRects) {
            let target = intersectLocal(dirty, tableArea)
            if (target.width <= 0 || target.height <= 0) { continue }
            for (y in target.y..target.bottom) {
                let visible = y - tableArea.y - 1
                if (visible < 0) { continue }
                let index = processOffset + visible
                if (index >= 0 && index < processRows.size) {
                    renderProcessRowBuffer(buffer, tableArea, y, processRows[index], index == selected)
                }
            }
        }
    }

    private func renderProcessRowBuffer(buffer: Buffer, tableArea: Rect, y: Int64, row: ProcessDisplayRow, active: Bool): Unit {
        let style = if (active) { PROCESS_SELECTED_STYLE } else { PROCESS_NORMAL_STYLE }
        buffer.fillRect(tableArea.x, y, tableArea.width, 1, style: style)
        var x = tableArea.x
        buffer.writeAsciiSpanUnchecked(x, y, row.pid, style: style)
        x += 6
        buffer.writeAsciiSpanUnchecked(x, y, row.cpu, style: style)
        x += 8
        buffer.writeAsciiSpanUnchecked(x, y, row.mem, style: style)
        x += 15
        buffer.writeAsciiSpanUnchecked(x, y, row.virt, style: style)
        x += 9
        buffer.writeAsciiSpanUnchecked(x, y, row.state, style: style)
        x += 3
        writeAsciiOrText(buffer, x, y, row.command, style)
    }

    private func ensureProcessVisible(visibleRows: Int64): Unit {
        let count = snapshot.processes.size
        selected = clampLocal(selected, 0, max(0, count - 1))
        if (count == 0 || visibleRows <= 0) {
            processOffset = 0
            return
        }
        if (selected < processOffset) {
            processOffset = selected
        }
        if (selected >= processOffset + visibleRows) {
            processOffset = selected - visibleRows + 1
        }
        processOffset = clampLocal(processOffset, 0, max(0, count - visibleRows))
    }

    private func selectionDirty(beforeSelected: Int64, beforeOffset: Int64): UpdateResult {
        if (lastProcessVisibleRows > 0) {
            ensureProcessVisible(lastProcessVisibleRows)
        }
        match (lastProcessArea) {
            case Some(area) =>
                let dirty = DirtyRects()
                if (beforeOffset != processOffset) {
                    dirty.add(area)
                } else {
                    addProcessRowDirty(dirty, area, beforeSelected, processOffset)
                    addProcessRowDirty(dirty, area, selected, processOffset)
                    if (showDetail) {
                        dirty.add(Rect(area.x, area.bottom, area.width, 4))
                    }
                }
                UpdateResult(dirtyRects: Some(dirty))
            case None => UpdateResult.next()
        }
    }

    public func dirtyProcessesArea(): UpdateResult {
        if (processesArea.width > 0 && processesArea.height > 0) {
            return UpdateResult.dirty(processesArea)
        }
        match (lastProcessArea) {
            case Some(area) => UpdateResult.dirty(area)
            case None => UpdateResult.next()
        }
    }

    private func dirtyKnownArea(): UpdateResult {
        match (lastArea) {
            case Some(area) => UpdateResult.dirty(area)
            case None => UpdateResult.next()
        }
    }

    private func dirtyFooterRects(): ?DirtyRects {
        if (footerArea.width <= 0 || footerArea.height <= 0) { return None }
        let dirty = DirtyRects()
        dirty.add(footerArea)
        Some(dirty)
    }

    private func dirtyFooterArea(): UpdateResult {
        match (dirtyFooterRects()) {
            case Some(dirty) => UpdateResult(dirtyRects: Some(dirty))
            case None => dirtyKnownArea()
        }
    }

    private func dirtyHeaderFooterProcesses(): UpdateResult {
        let dirty = DirtyRects()
        for (area in [headerArea, processesArea, footerArea]) {
            if (area.width > 0 && area.height > 0) { dirty.add(area) }
        }
        if (dirty.isEmpty()) { dirtyKnownArea() } else { UpdateResult(dirtyRects: Some(dirty)) }
    }

    private func panelArea(id: String): Rect {
        match (id) {
            case "header" => headerArea
            case "cpu" => cpuArea
            case "memory" => memoryArea
            case "network" => networkArea
            case "disk" => diskArea
            case "processes" => processesArea
            case "footer" => footerArea
            case _ => Rect(0, 0, 0, 0)
        }
    }

    private func dirtyPanelArea(id: String): UpdateResult {
        let area = panelArea(id)
        if (area.width > 0 && area.height > 0) { UpdateResult.dirty(area) } else { UpdateResult.next() }
    }

    private func dirtyMetricPanel(id: String): UpdateResult {
        let dirty = DirtyRects()
        let area = panelArea(id)
        if (area.width > 0 && area.height > 0) { dirty.add(area) }
        if (headerArea.width > 0 && headerArea.height > 0) { dirty.add(headerArea) }
        if (dirty.isEmpty()) { dirtyKnownArea() } else { UpdateResult(dirtyRects: Some(dirty)) }
    }

    private func renderProcessDetail(canvas: Canvas, area: Rect, proc: ProcessSample): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(7, 12, 19)))
        canvas.strokeRect(area, Style(fg: GRID, bg: Color.Rgb(7, 12, 19)))
        canvas.drawText(area.x + 2, area.y, " detail ", Style(fg: CYAN, bg: Color.Rgb(7, 12, 19), modifier: Modifier.strong()))
        canvas.drawText(area.x + 2, area.y + 1, "pid ${proc.pid}  cpu " + percent2(proc.cpuPercent100) + "%  mem " + percent2(proc.memPercent100) + "%  rss " + bytesText(proc.rssBytes) + "  virt " + bytesText(proc.virtBytes), Style(fg: TEXT, bg: Color.Rgb(7, 12, 19)))
        canvas.drawText(area.x + 2, area.y + 2, truncateLocal(proc.command, max(1, area.width - 4)), Style(fg: MUTED, bg: Color.Rgb(7, 12, 19)))
    }

    private func renderBottomBar(buffer: Buffer, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        let search = if (filtering) { "search: " + filterInput.value + "_" } else if (!filterInput.value.isEmpty()) { "filter: " + filterInput.value } else { "" }
        FooterBar(
            left: "q quit  j/k move  +/- refresh  c/m/p/n sort  / search  space pause  enter detail  d profiler",
            right: search + " " + sortLabel() + "  refresh: " + refreshLabel(),
            style: Style(fg: TEXT, bg: bg)
        ).render(area, buffer)
    }

    public func renderBottomBarFrame(frame: Frame, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        let search = if (filtering) { "search: " + filterInput.value + "_" } else if (!filterInput.value.isEmpty()) { "filter: " + filterInput.value } else { "" }
        frame.renderWidget(FooterBar(
            left: "q quit  j/k move  +/- refresh  c/m/p/n sort  / search  space pause  enter detail  d profiler",
            right: search + " " + sortLabel() + "  refresh: " + refreshLabel(),
            style: Style(fg: TEXT, bg: bg)
        ), area)
    }

    private func refreshLabel(): String {
        if (refreshMillis % 1000 == 0) {
            "${refreshMillis / 1000}s"
        } else {
            "${refreshMillis}ms"
        }
    }

    private func sortLabel(): String {
        match (sortMode) {
            case SortMode.Cpu => "sort: CPU"
            case SortMode.Memory => "sort: MEM"
            case SortMode.Pid => "sort: PID"
            case SortMode.Name => "sort: NAME"
        }
    }
}

class ProcessRowsWidget <: Widget {
    private let owner: BtmClone
    private let dirtyRects: Array<Rect>
    private let tableArea: Rect

    init(owner: BtmClone, dirtyRects: Array<Rect>, tableArea: Rect) {
        this.owner = owner
        this.dirtyRects = dirtyRects
        this.tableArea = tableArea
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        owner.renderProcessRowsBuffer(buffer, tableArea, dirtyRects)
    }
}

func parseCpuLine(line: String): CpuCounters {
    let fields = words(line)
    var total: Int64 = 0
    var idle: Int64 = 0
    for (i in 1..fields.size) {
        let value = parseInt(fields[i])
        total += value
        if (i == 4 || i == 5) {
            idle += value
        }
    }
    CpuCounters(total, idle)
}

func cpuUsage(now: CpuCounters, prev: CpuCounters): Int64 {
    let totalDelta = now.total - prev.total
    let idleDelta = now.idle - prev.idle
    if (totalDelta <= 0) { return 0 }
    clampLocal((totalDelta - idleDelta) * 100 / totalDelta, 0, 100)
}

func parseProcStat(text: String): ?RawProcStat {
    let open = indexOfByte(text, b'(')
    let close = lastIndexOfByte(text, b')')
    if (open < 0 || close <= open || close + 2 >= text.size) { return None }
    let name = text[open + 1..close]
    let fields = words(text[close + 2..])
    if (fields.size < 22) { return None }
    let state = fields[0]
    let utime = parseInt(fields[11])
    let stime = parseInt(fields[12])
    let startTime = parseInt(fields[19])
    let virt = parseInt(fields[20])
    let rss = parseInt(fields[21]) * PAGE_BYTES
    Some(RawProcStat(name, state, utime + stime, startTime, virt, rss))
}

func processCommand(pid: Int64, fallback: String): String {
    match (readTextSafe("/proc/${pid}/cmdline")) {
        case Some(raw) =>
            let text = replaceNulWithSpace(raw)
            if (!trimAscii(text).isEmpty()) { return trimAscii(text) }
        case None => ()
    }
    fallback
}

func sortProcesses(rows: ArrayList<ProcessSample>, mode: SortMode): Unit {
    match (mode) {
        case SortMode.Cpu => sort(rows, by: { l: ProcessSample, r: ProcessSample => r.cpuPercent100.compare(l.cpuPercent100) })
        case SortMode.Memory => sort(rows, by: { l: ProcessSample, r: ProcessSample => r.rssBytes.compare(l.rssBytes) })
        case SortMode.Pid => sort(rows, by: { l: ProcessSample, r: ProcessSample => l.pid.compare(r.pid) })
        case SortMode.Name => sort(rows, by: { l: ProcessSample, r: ProcessSample => l.name.compare(r.name) })
    }
}

func statDisk(mount: String): DiskSample {
    statDiskUnix(mount)
}

@When[os != "Windows"]
func statDiskUnix(mount: String): DiskSample {
    var result = DiskSample(mount)
    try (path = unsafe { LibC.mallocCString(mount).asResource() }) {
        let info = LibC.malloc<StatVfs>(count: 1)
        if (!info.isNull()) {
            try {
                let rc = unsafe { statvfs(path.value, info) }
                if (rc == 0) {
                    let raw = unsafe { info.read() }
                    let blockSize = max(1, Int64(raw.f_frsize))
                    let totalBlocks = Int64(raw.f_blocks)
                    let availableBlocks = Int64(raw.f_bavail)
                    let usedBlocks = max(0, totalBlocks - availableBlocks)
                    result = DiskSample(mount, usedBlocks * blockSize, totalBlocks * blockSize)
                }
            } finally {
                unsafe { LibC.free(info) }
            }
        }
    } catch (_) {
        result = DiskSample(mount)
    }
    result
}

@When[os == "Windows"]
func statDiskUnix(mount: String): DiskSample {
    DiskSample(mount)
}

func fsTypeFromMountInfo(fields: Array<String>): String {
    for (i in 0..fields.size) {
        if (fields[i] == "-" && i + 1 < fields.size) { return fields[i + 1] }
    }
    ""
}

func interestingMount(mount: String, fsType: String): Bool {
    if (mount == "/" || mount == "/home") { return true }
    if (mount.startsWith("/proc") || mount.startsWith("/sys") || mount.startsWith("/run") || mount.startsWith("/dev")) { return false }
    if (fsType == "proc" || fsType == "sysfs" || fsType == "tmpfs" || fsType == "devtmpfs" || fsType == "cgroup2" || fsType == "overlay") { return false }
    mount.startsWith("/")
}

func containsDisk(disks: ArrayList<DiskSample>, mount: String): Bool {
    for (disk in disks) {
        if (disk.mount == mount) { return true }
    }
    false
}

func unescapeMount(value: String): String {
    var out = ""
    var i: Int64 = 0
    while (i < value.size) {
        if (i + 3 < value.size && value[i] == b'\\' && value[i + 1] == b'0' && value[i + 2] == b'4' && value[i + 3] == b'0') {
            out += " "
            i += 4
        } else {
            out += byteString(value[i])
            i++
        }
    }
    out
}

func readTextSafe(path: String): ?String {
    try {
        Some(unsafe { String.fromUtf8Unchecked(File.readFrom(path)) })
    } catch (_) {
        None
    }
}

func words(text: String): Array<String> {
    let out = ArrayList<String>()
    var start: Int64 = -1
    var i: Int64 = 0
    while (i < text.size) {
        if (isSpace(text[i])) {
            if (start >= 0) {
                out.add(text[start..i])
                start = -1
            }
        } else if (start < 0) {
            start = i
        }
        i++
    }
    if (start >= 0) { out.add(text[start..]) }
    out.toArray()
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

func trimAscii(text: String): String {
    var start: Int64 = 0
    var end: Int64 = text.size
    while (start < end && isSpace(text[start])) { start++ }
    while (end > start && isSpace(text[end - 1])) { end-- }
    text[start..end]
}

func parseInt(value: String): Int64 {
    var out: Int64 = 0
    var sign: Int64 = 1
    var i: Int64 = 0
    if (value.size > 0 && value[0] == b'-') {
        sign = -1
        i = 1
    }
    while (i < value.size) {
        let b = value[i]
        if (b < b'0' || b > b'9') { break }
        out = out * 10 + Int64(b - b'0')
        i++
    }
    out * sign
}

func parsePid(value: String): Int64 {
    if (value.isEmpty()) { return -1 }
    for (b in unsafe { value.rawData() }) {
        if (!isDigit(b)) { return -1 }
    }
    parseInt(value)
}

func indexOfByte(text: String, needle: Byte): Int64 {
    for (i in 0..text.size) {
        if (text[i] == needle) { return i }
    }
    -1
}

func lastIndexOfByte(text: String, needle: Byte): Int64 {
    var i = text.size - 1
    while (i >= 0) {
        if (text[i] == needle) { return i }
        i--
    }
    -1
}

func replaceNulWithSpace(text: String): String {
    var out = ""
    for (b in unsafe { text.rawData() }) {
        out += if (b == 0) { " " } else { byteString(b) }
    }
    out
}

func writeAsciiOrText(buffer: Buffer, x: Int64, y: Int64, text: String, style: Style): Unit {
    if (!buffer.writeAsciiSpan(x, y, text, style: style)) {
        buffer.setString(x, y, text, style: style)
    }
}

func addProcessRowDirty(dirty: DirtyRects, area: Rect, selected: Int64, offset: Int64): Unit {
    let row = selected - offset + 1
    if (row >= 1 && row < area.height) {
        dirty.add(Rect(area.x, area.y + row, area.width, 1))
    }
}

func percent2(value100: Int64): String {
    let value = max(0, value100)
    let whole = value / 100
    let frac = value % 100
    "${whole}." + twoDigits(frac)
}

func twoDigits(value: Int64): String {
    if (value < 10) { "0${value}" } else { "${value}" }
}

func drawGraph(canvas: Canvas, area: Rect, values: Array<Int64>, maxValue: Int64, color: Color, label: String, unit: String): Unit {
    if (area.width <= 4 || area.height <= 2) { return }
    let style = Style(fg: GRID, bg: PANEL)
    for (y in area.y..area.bottom) {
        if ((y - area.y) % 2 == 0) {
            canvas.drawText(area.x, y, repeatLocal(".", area.width), style)
        }
    }
    if (values.size == 0) {
        canvas.drawText(area.x + 1, area.y, "${label} waiting", Style(fg: MUTED, bg: PANEL))
        return
    }
    let usableW = max(1, area.width - 2)
    let usableH = max(1, area.height - 2)
    let count = min(usableW, values.size)
    var prevX = area.x + 1
    var prevY = area.bottom - 2
    for (i in 0..count) {
        let source = values.size - count + i
        let value = clampLocal(values[source], 0, maxValue)
        let x = area.x + 1 + i
        let y = area.bottom - 2 - value * usableH / max(1, maxValue)
        if (i > 0) {
            canvas.drawLine(prevX, prevY, x, y, "*", Style(fg: color, bg: PANEL, modifier: Modifier.strong()))
        }
        canvas.drawText(x, y, "*", Style(fg: color, bg: PANEL, modifier: Modifier.strong()))
        prevX = x
        prevY = y
    }
    canvas.drawText(area.x + 1, area.y, "${label} ${values[values.size - 1]}${unit}", Style(fg: color, bg: PANEL, modifier: Modifier.strong()))
    canvas.drawText(area.right - 8, area.y, "${maxValue}", Style(fg: MUTED, bg: PANEL))
    canvas.drawText(area.right - 6, area.bottom - 1, "0", Style(fg: MUTED, bg: PANEL))
}

func panel(buffer: Buffer, area: Rect, title: String): Rect {
    Panel(panelBlockOptions(title)).renderInner(area, buffer)
}

func panelFrame(frame: Frame, area: Rect, title: String): Rect {
    let block = panelBlock(title)
    frame.renderWidget(Panel(block: block), area)
    block.inner(area)
}

func panelBlock(title: String): Block {
    Block(panelBlockOptions(title))
}

func panelBlockOptions(title: String): BlockOptions {
    BlockOptions(
        title: title,
        backgroundStyle: Style(bg: PANEL),
        borderStyle: Style(fg: GRID, bg: PANEL),
        titleStyle: Style(fg: CYAN, bg: PANEL, modifier: Modifier.strong())
    )
}

func drawMeter(buffer: Buffer, x: Int64, y: Int64, width: Int64, percent: Int64, color: Color, label: String): Unit {
    Meter(
        truncateLocal(label, 26),
        clampLocal(percent, 0, 100),
        total: 100,
        style: Style(fg: TEXT, bg: PANEL),
        fillStyle: Style(fg: color, bg: PANEL)
    ).render(Rect(x, y, max(1, width), 1), buffer)
}

func drawMeterFrame(frame: Frame, x: Int64, y: Int64, width: Int64, percent: Int64, color: Color, label: String): Unit {
    frame.renderWidget(Meter(
        truncateLocal(label, 26),
        clampLocal(percent, 0, 100),
        total: 100,
        style: Style(fg: TEXT, bg: PANEL),
        fillStyle: Style(fg: color, bg: PANEL)
    ), Rect(x, y, max(1, width), 1))
}

func drawDisk(canvas: Canvas, x: Int64, y: Int64, width: Int64, percent: Int64, label: String, color: Color): Unit {
    let barW = max(4, width - 30)
    let fill = clampLocal(percent, 0, 100) * barW / 100
    canvas.drawText(x, y, truncateLocal(label, 28), Style(fg: TEXT, bg: PANEL))
    canvas.drawText(x + 29, y, repeatLocal("#", fill) + repeatLocal(".", max(0, barW - fill)), Style(fg: color, bg: PANEL))
}

func bytesText(bytes: Int64): String {
    if (bytes <= 0) { return "0B" }
    let kb = bytes / 1024
    if (kb < 1024) { return "${kb}K" }
    let mb = kb / 1024
    if (mb < 1024) { return "${mb}M" }
    let gb10 = mb * 10 / 1024
    "${gb10 / 10}.${gb10 % 10}G"
}

func rateText(bytes: Int64): String {
    bytesText(bytes) + "/s"
}

func percentOf(value: Int64, total: Int64): Int64 {
    if (total <= 0) { 0 } else { clampLocal(value * 100 / total, 0, 100) }
}

func colorForIndex(i: Int64): Color {
    match (i % 6) {
        case 0 => CYAN
        case 1 => GREEN
        case 2 => YELLOW
        case 3 => MAGENTA
        case 4 => BLUE
        case _ => RED
    }
}

func isSpace(b: Byte): Bool {
    b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
}

func isDigit(b: Byte): Bool {
    b >= b'0' && b <= b'9'
}

func byteString(b: Byte): String {
    unsafe { String.fromUtf8Unchecked([b]) }
}

func clampLocal(value: Int64, low: Int64, high: Int64): Int64 {
    min(max(value, low), high)
}

func intersectLocal(left: Rect, right: Rect): Rect {
    let x1 = max(left.x, right.x)
    let y1 = max(left.y, right.y)
    let x2 = min(left.right, right.right)
    let y2 = min(left.bottom, right.bottom)
    Rect(x1, y1, max(0, x2 - x1), max(0, y2 - y1))
}

func repeatLocal(text: String, count: Int64): String {
    var out = ""
    var i: Int64 = 0
    while (i < count) {
        out += text
        i++
    }
    out
}

func padLeft(text: String, width: Int64): String {
    if (text.size >= width) { text } else { repeatLocal(" ", width - text.size) + text }
}

func truncateLocal(text: String, width: Int64): String {
    if (width <= 0) { "" } else if (text.size <= width) { text } else { text[0..width] }
}

func dirtyRectCount(result: UpdateResult): Int64 {
    match (result.dirtyRects) {
        case Some(rects) => rects.rects().size
        case None => -1
    }
}

func dirtyRectText(result: UpdateResult): String {
    match (result.dirtyRects) {
        case Some(rects) =>
            var out = ""
            for (rect in rects.rects()) {
                if (!out.isEmpty()) { out += ";" }
                out += "${rect.x},${rect.y},${rect.width},${rect.height}"
            }
            out
        case None => "none"
    }
}

func runAsyncCommand(app: BtmClone, command: Command): UpdateResult {
    match (command) {
        case Command.AsyncTask(id, task) =>
            app.update(Event.AsyncCompleted(id, task()))
        case Command.Batch(items) =>
            var out = UpdateResult.next()
            for (item in items) {
                out = runAsyncCommand(app, item)
            }
            out
        case _ => UpdateResult.next()
    }
}

func commandHasAsyncTask(command: Command): Bool {
    match (command) {
        case Command.AsyncTask(_, _) => true
        case Command.Batch(items) =>
            for (item in items) {
                if (commandHasAsyncTask(item)) { return true }
            }
            false
        case _ => false
    }
}

func commandHasRestartTimer(command: Command): Bool {
    match (command) {
        case Command.RestartTimer(_) => true
        case Command.Batch(items) =>
            for (item in items) {
                if (commandHasRestartTimer(item)) { return true }
            }
            false
        case _ => false
    }
}

func commandStartsTimer(command: Command, id: String): Bool {
    match (command) {
        case Command.StartTimer(spec) => spec.id == id
        case Command.Batch(items) =>
            for (item in items) {
                if (commandStartsTimer(item, id)) { return true }
            }
            false
        case _ => false
    }
}

func btmSmokeFail(message: String): Int64 {
    eprintln("btm_clone headless smoke failed: " + message)
    1
}

func runBtmCloneHeadlessSmoke(): Int64 {
    let app = BtmClone()
    let area = Rect(0, 0, 100, 32)
    let backend = TestBackend(area: area)
    let terminal = Terminal(backend, renderMode: RenderMode.Diff)
    _ = terminal.draw { frame => app.renderFrame(frame) }
    if (!backend.snapshot().contains("btm LIVE")) {
        return btmSmokeFail("initial snapshot missing header")
    }
    if (backend.snapshot().contains("unknown")) {
        return btmSmokeFail("disk panel still has unknown capacity")
    }

    let startup = app.update(Event.Capabilities(TerminalCapabilities(size: area)))
    for (timerId in ["cpu", "memory", "network", "disk", "proc"]) {
        if (!commandStartsTimer(startup.command, timerId)) {
            return btmSmokeFail("startup did not register application timer ${timerId}")
        }
    }

    let slower = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'-'))))
    if (!commandHasRestartTimer(slower.command)) {
        return btmSmokeFail("refresh interval shortcut did not restart timers")
    }
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: slower.dirtyRects)
    if (!backend.snapshot().contains("refresh: 1250ms")) {
        return btmSmokeFail("refresh interval did not increase in footer")
    }
    let faster = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'+'))))
    if (!commandHasRestartTimer(faster.command)) {
        return btmSmokeFail("refresh interval restore did not restart timers")
    }
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: faster.dirtyRects)
    if (!backend.snapshot().contains("refresh: 1s")) {
        return btmSmokeFail("refresh interval did not restore in footer")
    }

    let showDebug = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'd'))))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: showDebug.dirtyRects)
    if (!backend.snapshot().contains("fps=")) {
        return btmSmokeFail("primary AppMetrics debug overlay did not render")
    }
    let hideDebug = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'd'))))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: hideDebug.dirtyRects)

    let beforeCpuUpdate = app.panelUpdateCount("cpu")
    let beforeCpuProcessRender = app.panelRenderCount("processes")
    let cpuPoll = app.update(Event.Timer(TimerEvent("cpu", elapsedMillis: 500)))
    if (!commandHasAsyncTask(cpuPoll.command)) {
        return btmSmokeFail("cpu timer did not start async datasource")
    }
    let cpuReady = runAsyncCommand(app, cpuPoll.command)
    let cpuMetrics = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: cpuReady.dirtyRects)
    if (app.panelUpdateCount("cpu") <= beforeCpuUpdate) {
        return btmSmokeFail("cpu datasource did not update cpu panel")
    }
    if (app.panelRenderCount("processes") != beforeCpuProcessRender) {
        return btmSmokeFail("processes rendered during cpu datasource before=${beforeCpuProcessRender} after=${app.panelRenderCount("processes")} dirty=${dirtyRectCount(cpuReady)} rects=${dirtyRectText(cpuReady)} drawDirty=${cpuMetrics.dirtyRects} rendered=${cpuMetrics.renderedCells} full=${cpuMetrics.fullRedraw}")
    }

    let beforeNavUpdate = app.panelUpdateCount("processes")
    let beforeNavCpu = app.panelRenderCount("cpu")
    let beforeNavMemory = app.panelRenderCount("memory")
    let beforeNavNetwork = app.panelRenderCount("network")
    let beforeNavDisk = app.panelRenderCount("disk")
    let nav = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: nav.dirtyRects)
    if (app.panelUpdateCount("processes") <= beforeNavUpdate) {
        return btmSmokeFail("process table did not receive navigation")
    }
    if (app.panelRenderCount("cpu") != beforeNavCpu) {
        return btmSmokeFail("cpu rendered during process navigation")
    }
    if (app.panelRenderCount("memory") != beforeNavMemory) {
        return btmSmokeFail("memory rendered during process navigation")
    }
    if (app.panelRenderCount("network") != beforeNavNetwork) {
        return btmSmokeFail("network rendered during process navigation")
    }
    if (app.panelRenderCount("disk") != beforeNavDisk) {
        return btmSmokeFail("disk rendered during process navigation")
    }

    let beforeScrollCpu = app.panelRenderCount("cpu")
    let beforeScrollMemory = app.panelRenderCount("memory")
    let beforeScrollNetwork = app.panelRenderCount("network")
    let beforeScrollDisk = app.panelRenderCount("disk")
    var scrollI: Int64 = 0
    while (scrollI < 80) {
        let scroll = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        let scrollMetrics = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: scroll.dirtyRects)
        if (scrollMetrics.fullRedraw) {
            return btmSmokeFail("process navigation triggered full redraw")
        }
        scrollI++
    }
    if (app.panelRenderCount("cpu") != beforeScrollCpu) {
        return btmSmokeFail("cpu rendered during continuous process navigation")
    }
    if (app.panelRenderCount("memory") != beforeScrollMemory) {
        return btmSmokeFail("memory rendered during continuous process navigation")
    }
    if (app.panelRenderCount("network") != beforeScrollNetwork) {
        return btmSmokeFail("network rendered during continuous process navigation")
    }
    if (app.panelRenderCount("disk") != beforeScrollDisk) {
        return btmSmokeFail("disk rendered during continuous process navigation")
    }

    let startFilter = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: startFilter.dirtyRects)
    let beforeFilterProcessUpdate = app.panelUpdateCount("processes")
    let typeJ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'j'))))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: typeJ.dirtyRects)
    if (!backend.snapshot().contains("search: j_")) {
        return btmSmokeFail("filter input did not capture j")
    }
    if (app.panelUpdateCount("processes") != beforeFilterProcessUpdate) {
        return btmSmokeFail("filter input was routed through process table")
    }
    let finishFilter = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: finishFilter.dirtyRects)

    let detailOpen = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: detailOpen.dirtyRects)
    if (!backend.snapshot().contains(" detail ")) {
        return btmSmokeFail("process detail did not render")
    }
    let detailClose = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: detailClose.dirtyRects)
    if (backend.snapshot().contains(" detail ")) {
        return btmSmokeFail("process detail remained after close")
    }

    var stalePoll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 900)))
    if (!commandHasAsyncTask(stalePoll.command)) {
        stalePoll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 900)))
    }
    if (!commandHasAsyncTask(stalePoll.command)) {
        return btmSmokeFail("stale process sample setup did not start")
    }
    let beforeStaleApply = app.appliedProcessRequestId()
    let changeSort = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'm'))))
    _ = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: changeSort.dirtyRects)
    _ = runAsyncCommand(app, stalePoll.command)
    if (app.appliedProcessRequestId() != beforeStaleApply) {
        return btmSmokeFail("stale process completion replaced newer application state")
    }

    let beforeProcUpdate = app.panelUpdateCount("processes")
    let beforeProcCpuRender = app.panelRenderCount("cpu")
    var procPoll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
    if (!commandHasAsyncTask(procPoll.command)) {
        procPoll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
    }
    if (!commandHasAsyncTask(procPoll.command)) {
        return btmSmokeFail("proc datasource polling did not start after idle retry")
    }
    let procReady = runAsyncCommand(app, procPoll.command)
    let procMetrics = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: procReady.dirtyRects)
    if (app.panelUpdateCount("processes") <= beforeProcUpdate) {
        return btmSmokeFail("proc datasource did not update process panel")
    }
    if (app.panelRenderCount("cpu") != beforeProcCpuRender) {
        return btmSmokeFail("cpu rendered during proc datasource completion before=${beforeProcCpuRender} after=${app.panelRenderCount("cpu")} dirty=${dirtyRectCount(procReady)} rects=${dirtyRectText(procReady)} drawDirty=${procMetrics.dirtyRects} rendered=${procMetrics.renderedCells} full=${procMetrics.fullRedraw}")
    }


    let resizedBackend = TestBackend(area: Rect(0, 0, 120, 40))
    let resizedTerminal = Terminal(resizedBackend, renderMode: RenderMode.Diff)
    _ = resizedTerminal.draw({ frame => app.renderFrame(frame) })
    if (!resizedBackend.snapshot().contains("btm LIVE") || !resizedBackend.snapshot().contains("Processes")) {
        return btmSmokeFail("resize/layout render lost primary monitor regions")
    }

    println("btm_clone headless smoke ok")
    0
}

func runBtmCloneHeadlessBench(iterations: Int64): Int64 {
    let app = BtmClone()
    let area = Rect(0, 0, 100, 32)
    let backend = TestBackend(area: area)
    let terminal = Terminal(backend, renderMode: RenderMode.Diff)
    _ = terminal.draw({ frame => app.renderFrame(frame) })

    let total = max(1, iterations)
    var i: Int64 = 0
    var direction: Int64 = 1
    var dirtyCells: Int64 = 0
    var renderedCells: Int64 = 0
    var diffWrites: Int64 = 0
    var fullRedraws: Int64 = 0
    let start = MonoTime.now()
    while (i < total) {
        let keyCode = if (direction > 0) { KeyCode.Down } else { KeyCode.Up }
        let result = app.update(Event.KeyDown(KeyEvent(keyCode)))
        let metrics = terminal.draw({ frame => app.renderFrame(frame) }, dirtyRects: result.dirtyRects)
        dirtyCells += metrics.dirtyCells
        renderedCells += metrics.renderedCells
        diffWrites += metrics.diffWrites
        if (metrics.fullRedraw) { fullRedraws++ }
        if (i % 80 == 79) { direction = -direction }
        i++
    }
    let elapsed = max(1, (MonoTime.now() - start).toMilliseconds())
    println("btm_clone headless bench iterations=${total} elapsed_ms=${elapsed} avg_us=${elapsed * 1000 / total} dirty_cells=${dirtyCells} rendered_cells=${renderedCells} diff_writes=${diffWrites} full_redraws=${fullRedraws}")
    0
}

main(args: Array<String>): Int64 {
    if (args.size > 0 && args[0] == "--headless-smoke") {
        return runBtmCloneHeadlessSmoke()
    }
    if (args.size > 0 && args[0] == "--headless-bench") {
        let iterations = if (args.size > 1) { parseInt(args[1]) } else { Int64(5000) }
        return runBtmCloneHeadlessBench(iterations)
    }
    let metrics = AppMetrics()
    let app = BtmClone(metrics: metrics)
    App(rawMode: true, alternateScreen: true, hideCursor: true, metrics: Some(metrics)).runWithCommands(
        { frame => app.renderFrame(frame) },
        { event => app.update(event) }
    )
    0
}
