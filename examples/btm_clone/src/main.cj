package cjtui_btm_clone

import core.*
import std.collection.*
import std.fs.*
import std.sort.*
import std.time.*

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

let PAGE_BYTES: Int64 = 4096
let MAX_PROCESSES: Int64 = 200
let HISTORY_CAPACITY: Int64 = 120

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
    private var previousProc = HashMap<Int64, ProcPrev>()
    private var lastCpuTotalDelta: Int64 = 1
    private var initialized = false

    func sample(sortMode: SortMode, filter: String): MetricSnapshot {
        let start = MonoTime.now()
        var error = ""
        let cpu = sampleCpu()
        let mem = sampleMem()
        let net = sampleNet()
        let disks = sampleDisks()
        let (processes, scanned, skipped) = sampleProcesses(lastCpuTotalDelta, max(1, mem.totalKb), sortMode, filter)
        initialized = true
        let elapsed = max(0, (MonoTime.now() - start).toMilliseconds())
        if (cpu.cores.size == 0) { error = "cpu unavailable" }
        MetricSnapshot(cpu, mem, net, disks, processes, scanned, skipped, elapsed, error)
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
                MemSnapshot(total, max(0, total - available), swapTotal, max(0, swapTotal - swapFree))
        }
    }

    private func sampleNet(): NetSnapshot {
        match (readTextSafe("/proc/net/dev")) {
            case None => NetSnapshot()
            case Some(body) =>
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
                let rxRate = if (initialized) { max(0, rx - previousNet.rx) } else { 0 }
                let txRate = if (initialized) { max(0, tx - previousNet.tx) } else { 0 }
                previousNet = NetCounters(rx, tx)
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
                match (readProcess(pid, totalDelta, memTotalKb)) {
                    case Some(proc) =>
                        nextPrev.add(pid, ProcPrev(proc.cpuTotal, proc.startTime))
                        if (filter.isEmpty() || proc.name.contains(filter) || proc.command.contains(filter) || "${proc.pid}".contains(filter)) {
                            rows.add(proc)
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
        (rows.toArray(), scanned, skipped)
    }

    private func readProcess(pid: Int64, totalDelta: Int64, memTotalKb: Int64): ?ProcessSample {
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
                        let cmd = processCommand(pid, raw.name)
                        let memPercent100 = clampLocal(raw.rssBytes * 10000 / max(1, memTotalKb * 1024), 0, 10000)
                        Some(ProcessSample(pid, raw.name, cmd, raw.state, cpuPercent100, memPercent100, raw.virtBytes, raw.rssBytes, raw.startTime, raw.cpuTotal))
                }
        }
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

class BtmClone <: Widget {
    private let sampler = ProcFsSampler()
    private var snapshot = MetricSnapshot()
    private var frame: Int64 = 0
    private var selected: Int64 = 0
    private var processOffset: Int64 = 0
    private var sortMode = SortMode.Cpu
    private var paused = false
    private var filtering = false
    private var filter = ""
    private var showDetail = false
    private let cpuHistory = HistoryRing(HISTORY_CAPACITY)
    private let memHistory = HistoryRing(HISTORY_CAPACITY)
    private let netHistory = HistoryRing(HISTORY_CAPACITY)

    init() {
        refresh()
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => handleKey(key)
            case Event.Tick(tick) =>
                frame = tick.frameIndex
                UpdateResult.next()
            case Event.Timer(timer) =>
                if (timer.id == "sample" && !paused) { refresh() }
                UpdateResult.next()
            case Event.Capabilities(_) =>
                UpdateResult.withCommand(Command.StartTimer(TimerSpec("sample", Duration.second)))
            case _ => UpdateResult.next()
        }
    }

    private func handleKey(key: KeyEvent): UpdateResult {
        if (filtering) {
            match (key.code) {
                case KeyCode.Esc =>
                    filtering = false
                    if (!filter.isEmpty()) {
                        filter = ""
                        refresh()
                    }
                case KeyCode.Enter =>
                    filtering = false
                    refresh()
                case KeyCode.Backspace =>
                    if (!filter.isEmpty()) {
                        filter = filter[..max(0, filter.size - 1)]
                        refresh()
                    }
                case KeyCode.Char(ch) =>
                    filter += ch.toString()
                    refresh()
                case _ => ()
            }
            return UpdateResult.next()
        }
        match (key.code) {
            case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
            case KeyCode.Down | KeyCode.Char(r'j') =>
                selected = min(max(0, snapshot.processes.size - 1), selected + 1)
                UpdateResult.next()
            case KeyCode.Up | KeyCode.Char(r'k') =>
                selected = max(0, selected - 1)
                UpdateResult.next()
            case KeyCode.Char(r'c') => setSort(SortMode.Cpu)
            case KeyCode.Char(r'm') => setSort(SortMode.Memory)
            case KeyCode.Char(r'p') => setSort(SortMode.Pid)
            case KeyCode.Char(r'n') => setSort(SortMode.Name)
            case KeyCode.Char(r'/') =>
                filtering = true
                UpdateResult.next()
            case KeyCode.Char(r' ') =>
                paused = !paused
                UpdateResult.next()
            case KeyCode.Enter =>
                showDetail = !showDetail
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    private func setSort(mode: SortMode): UpdateResult {
        sortMode = mode
        refresh()
        UpdateResult.next()
    }

    private func refresh(): Unit {
        snapshot = sampler.sample(sortMode, filter)
        selected = clampLocal(selected, 0, max(0, snapshot.processes.size - 1))
        processOffset = clampLocal(processOffset, 0, max(0, snapshot.processes.size - 1))
        cpuHistory.push(snapshot.cpu.usage)
        memHistory.push(snapshot.mem.percent())
        netHistory.push(snapshot.net.percent())
    }

    public func render(area: Rect, buffer: Buffer): Unit {
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
        renderTopBar(canvas, rows[0])
        renderCpu(canvas, rows[1])
        let mid = Layout.horizontal([Constraint.Percent(34), Constraint.Percent(33), Constraint.Min(24)]).withGap(1).split(rows[2])
        renderMemory(canvas, mid[0])
        renderNetwork(canvas, mid[1])
        renderDisks(canvas, mid[2])
        renderProcesses(canvas, rows[3])
        renderBottomBar(canvas, rows[4])
    }

    private func renderSmall(canvas: Canvas, area: Rect): Unit {
        canvas.drawText(area.x + 1, area.y + 1, "btm_clone needs at least 86x26", Style(fg: TEXT, bg: BG))
        canvas.drawText(area.x + 1, area.y + 3, "resize terminal, q quits", Style(fg: MUTED, bg: BG))
    }

    private func renderTopBar(canvas: Canvas, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        canvas.fillRect(area, Style(bg: bg))
        let mode = if (paused) { "PAUSED" } else { "LIVE" }
        canvas.drawText(area.x + 1, area.y, " btm  cpu  mem  net  disk  proc ", Style(fg: BG, bg: CYAN, modifier: Modifier.strong()))
        canvas.drawText(area.x + 34, area.y, mode, Style(fg: if (paused) { YELLOW } else { GREEN }, bg: bg, modifier: Modifier.strong()))
        canvas.drawText(max(area.x + 1, area.right - 56), area.y, "cpu ${snapshot.cpu.usage}%  mem ${snapshot.mem.percent()}%  scan ${snapshot.sampleMillis}ms  pids ${snapshot.scanned}", Style(fg: MUTED, bg: bg))
    }

    private func renderCpu(canvas: Canvas, area: Rect): Unit {
        let inner = panel(canvas, area, " CPU ")
        drawGraph(canvas, inner, cpuHistory.toArray(), 100, CYAN, "CPU", "%")
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

    private func renderMemory(canvas: Canvas, area: Rect): Unit {
        let inner = panel(canvas, area, " Memory ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 4)), memHistory.toArray(), 100, GREEN, "RAM", "%")
        let y = inner.bottom - 3
        drawMeter(canvas, inner.x + 1, y, max(8, inner.width - 2), snapshot.mem.percent(), GREEN, "RAM " + bytesText(snapshot.mem.usedKb * 1024) + " / " + bytesText(snapshot.mem.totalKb * 1024))
        drawMeter(canvas, inner.x + 1, y + 1, max(8, inner.width - 2), snapshot.mem.swapPercent(), BLUE, "SWP " + bytesText(snapshot.mem.swapUsedKb * 1024) + " / " + bytesText(snapshot.mem.swapTotalKb * 1024))
    }

    private func renderNetwork(canvas: Canvas, area: Rect): Unit {
        let inner = panel(canvas, area, " Network ")
        drawGraph(canvas, Rect(inner.x, inner.y, inner.width, max(3, inner.height - 3)), netHistory.toArray(), 100, BLUE, "NET", "%")
        let y = inner.bottom - 2
        canvas.drawText(inner.x + 1, y, "RX " + rateText(snapshot.net.rxRate), Style(fg: BLUE, bg: PANEL))
        canvas.drawText(inner.x + max(18, inner.width / 2), y, "TX " + rateText(snapshot.net.txRate), Style(fg: CYAN, bg: PANEL))
    }

    private func renderDisks(canvas: Canvas, area: Rect): Unit {
        let inner = panel(canvas, area, " Disks ")
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

    private func renderProcesses(canvas: Canvas, area: Rect): Unit {
        let inner = panel(canvas, area, " Processes ")
        canvas.drawText(inner.x + 1, inner.y, " PID      CPU%       MEM(RSS)     VIRT   S  COMMAND", Style(fg: CYAN, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(inner.x + 1, inner.y + 1, repeatLocal("-", max(1, inner.width - 2)), Style(fg: GRID, bg: PANEL))
        let detailRows = if (showDetail) { 4 } else { 0 }
        let visibleRows = max(0, inner.height - 2 - detailRows)
        ensureProcessVisible(visibleRows)
        let limit = min(max(0, snapshot.processes.size - processOffset), visibleRows)
        for (i in 0..limit) {
            let rowIndex = processOffset + i
            let proc = snapshot.processes[rowIndex]
            let style = if (rowIndex == selected) { Style(fg: BG, bg: CYAN, modifier: Modifier.strong()) } else { Style(fg: TEXT, bg: PANEL) }
            canvas.drawText(inner.x + 1, inner.y + 2 + i, processRow(proc, inner.width - 2), style)
        }
        if (showDetail && selected < snapshot.processes.size) {
            renderProcessDetail(canvas, Rect(inner.x + 1, inner.bottom - 4, inner.width - 2, 4), snapshot.processes[selected])
        }
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

    private func renderProcessDetail(canvas: Canvas, area: Rect, proc: ProcessSample): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(7, 12, 19)))
        canvas.strokeRect(area, Style(fg: GRID, bg: Color.Rgb(7, 12, 19)))
        canvas.drawText(area.x + 2, area.y, " detail ", Style(fg: CYAN, bg: Color.Rgb(7, 12, 19), modifier: Modifier.strong()))
        canvas.drawText(area.x + 2, area.y + 1, "pid ${proc.pid}  cpu " + percent2(proc.cpuPercent100) + "%  mem " + percent2(proc.memPercent100) + "%  rss " + bytesText(proc.rssBytes) + "  virt " + bytesText(proc.virtBytes), Style(fg: TEXT, bg: Color.Rgb(7, 12, 19)))
        canvas.drawText(area.x + 2, area.y + 2, truncateLocal(proc.command, max(1, area.width - 4)), Style(fg: MUTED, bg: Color.Rgb(7, 12, 19)))
    }

    private func renderBottomBar(canvas: Canvas, area: Rect): Unit {
        let bg = Color.Rgb(14, 20, 30)
        canvas.fillRect(area, Style(bg: bg))
        let search = if (filtering) { "search: " + filter + "_" } else if (!filter.isEmpty()) { "filter: " + filter } else { "" }
        let left = "q quit  j/k move  c/m/p/n sort  / search  space pause  enter detail"
        canvas.drawText(area.x + 1, area.y, truncateLocal(left, max(1, area.width - 30)), Style(fg: TEXT, bg: bg))
        canvas.drawText(max(area.x + 1, area.right - 28), area.y, truncateLocal(search + " " + sortLabel(), 27), Style(fg: CYAN, bg: bg))
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

func processRow(proc: ProcessSample, width: Int64): String {
    let mem = percent2(proc.memPercent100) + "%(" + bytesText(proc.rssBytes) + ")"
    let row = padLeft("${proc.pid}", 5) + " " +
        padLeft(percent2(proc.cpuPercent100), 7) + " " +
        padLeft(mem, 14) + " " +
        padLeft(bytesText(proc.virtBytes), 8) + " " +
        padRight(proc.state, 2) + " " +
        proc.command
    fitRow(row, width)
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

func panel(canvas: Canvas, area: Rect, title: String): Rect {
    canvas.fillRect(area, Style(bg: PANEL))
    canvas.strokeRect(area, Style(fg: GRID, bg: PANEL))
    if (area.width > 4) {
        canvas.drawText(area.x + 2, area.y, title, Style(fg: CYAN, bg: PANEL, modifier: Modifier.strong()))
    }
    if (area.width < 2 || area.height < 2) {
        return Rect(area.x, area.y, 0, 0)
    }
    Rect(area.x + 1, area.y + 1, area.width - 2, area.height - 2)
}

func drawMeter(canvas: Canvas, x: Int64, y: Int64, width: Int64, percent: Int64, color: Color, label: String): Unit {
    let w = max(6, width)
    let barW = max(4, w - 28)
    let fill = clampLocal(percent, 0, 100) * barW / 100
    canvas.drawText(x, y, truncateLocal(label, 26), Style(fg: TEXT, bg: PANEL))
    canvas.drawText(x + 27, y, "[" + repeatLocal("=", fill) + repeatLocal(" ", max(0, barW - fill)) + "]", Style(fg: color, bg: PANEL))
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

func padRight(text: String, width: Int64): String {
    if (text.size >= width) { text } else { text + repeatLocal(" ", width - text.size) }
}

func truncateLocal(text: String, width: Int64): String {
    if (width <= 0) { "" } else if (text.size <= width) { text } else { text[0..width] }
}

func fitRow(text: String, width: Int64): String {
    if (text.size >= width) { truncateLocal(text, width) } else { text + repeatLocal(" ", width - text.size) }
}

main(): Int64 {
    let app = BtmClone()
    App(targetFps: 10, rawMode: true, alternateScreen: true, hideCursor: true).runWithCommands(
        { frame => frame.renderWidget(app, frame.area) },
        { event => app.update(event) }
    )
    0
}
