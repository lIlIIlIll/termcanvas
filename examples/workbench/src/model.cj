package cjtui_workbench

import std.collection.*
import std.deriving.*
import std.unicode.*

@Derive[Equatable]
enum WorkbenchJobStatus {
    | Queued
    | Running
    | Done
}

class WorkbenchJob {
    let id: Int64
    let project: String
    let durationMillis: Int64
    var status: WorkbenchJobStatus
    var elapsedMillis: Int64 = 0
    var progressPercent: Int64 = 0
    var name: String
    var priority: String = "Normal"
    var notify: Bool = true
    var tags: Array<String> = ["build"]
    var notes: String = ""
    var rowCache: Array<String> = ["", "", "", "", ""]

    init(id: Int64, project: String, status: WorkbenchJobStatus) {
        this.id = id
        this.project = project
        this.status = status
        this.durationMillis = 6000 + ((id - 1) % 5) * 2000
        this.name = "Task ${id}"
        refreshRow()
    }

    func label(): String { "job-${id}" }

    func refreshRow(): Unit {
        let statusText = match (status) {
            case WorkbenchJobStatus.Queued => "Queued"
            case WorkbenchJobStatus.Running => "Running"
            case WorkbenchJobStatus.Done => "Done"
        }
        rowCache = [label(), name, project, statusText, "${progressPercent}%"]
    }
}

class WorkbenchModel {
    let jobs = ArrayList<WorkbenchJob>()
    let activeIds = ArrayList<Int64>()
    let completedIds = ArrayList<Int64>()
    private let advancedIds = ArrayList<Int64>()


    func appendAdvancedIds(target: ArrayList<Int64>): Unit {
        for (id in advancedIds) {
            var present = false
            for (existing in target) {
                if (existing == id) { present = true; break }
            }
            if (!present) { target.add(id) }
        }
    }
    private let historyStore = WorkbenchHistoryStore()

    private var queryText: String = ""
    private var queryLower: String = ""
    private var projectFilter: ?String = None
    private var statusFilter: ?WorkbenchJobStatus = None
    var sortColumn: Int64 = 0
    var sortDescending: Bool = false
    private var visibleIdCache: Array<Int64> = []
    private var visibleRowCache: Array<Array<String>> = []
    private var queuedPreviewCache: Array<Array<String>> = []

    var queuedCount: Int64 = 119
    var runningCount: Int64 = 1
    var doneCount: Int64 = 0
    var progressSum: Int64 = 0

    init() {
        for (id in 1..121) {
            let project = match ((id - 1) % 3) {
                case 0 => "Alpha"
                case 1 => "Beta"
                case _ => "Gamma"
            }
            let initialStatus = if (id == 1) { WorkbenchJobStatus.Running } else { WorkbenchJobStatus.Queued }
            let task = WorkbenchJob(id, project, initialStatus)
            jobs.add(task)
            if (initialStatus == WorkbenchJobStatus.Running) { activeIds.add(id) }
        }
        rebuildVisible()
        rebuildQueuePreview()
    }

    func job(id: Int64): ?WorkbenchJob {
        if (id < 1 || id > jobs.size) { None } else { Some(jobs[id - 1]) }
    }

    func totalProgressHundredths(): Int64 { progressSum * 100 / jobs.size }

    func visibleIds(): Array<Int64> { visibleIdCache }

    func visibleRows(): Array<Array<String>> { visibleRowCache }

    func queuePreviewRows(): Array<Array<String>> { queuedPreviewCache }

    func logs(): Array<String> { historyStore.logs() }

    func history(): Array<Int64> { historyStore.history() }

    func recordLog(text: String): Unit { historyStore.pushLog(text) }

    func sampleHistory(value: Int64): Unit { historyStore.pushHistory(value) }

    func setQuery(text: String, project: ?String, status: ?WorkbenchJobStatus): Bool {
        if (queryText == text && projectFilter == project && statusFilter == status) { return false }
        queryText = text
        queryLower = text.toLower()
        projectFilter = project
        statusFilter = status
        rebuildVisible()
        true
    }

    func sortBy(column: Int64, descending!: Bool = false): Bool {
        if (column < 0 || column > 4) { return false }
        if (sortColumn == column && sortDescending == descending) { return false }
        sortColumn = column
        sortDescending = descending
        rebuildVisible()
        true
    }

    func refreshProgressOrder(): Bool {
        if (sortColumn != 4) { return false }
        rebuildVisible()
        true
    }

    func start(id: Int64): Bool {
        if (id < 1 || id > jobs.size || runningCount >= 4) { return false }
        let task = jobs[id - 1]
        if (task.status != WorkbenchJobStatus.Queued) { return false }
        task.status = WorkbenchJobStatus.Running
        queuedCount--
        runningCount++
        activeIds.add(id)
        task.refreshRow()
        rebuildVisible()
        rebuildQueuePreview()
        true
    }

    func reset(id: Int64): Bool {
        if (id < 1 || id > jobs.size) { return false }
        let task = jobs[id - 1]
        if (task.status == WorkbenchJobStatus.Queued) { return false }
        if (task.status == WorkbenchJobStatus.Running) {
            runningCount--
            removeActive(id)
        } else {
            doneCount--
        }
        task.status = WorkbenchJobStatus.Queued
        task.elapsedMillis = 0
        progressSum -= task.progressPercent
        task.progressPercent = 0
        queuedCount++
        task.refreshRow()
        rebuildVisible()
        rebuildQueuePreview()
        true
    }

    func advance(deltaMillis: Int64): Bool {
        completedIds.clear()
        advancedIds.clear()
        let delta = max(0, deltaMillis)
        if (delta == 0 || activeIds.isEmpty()) { return false }
        var changed = false
        var statusChanged = false
        var index: Int64 = 0
        while (index < activeIds.size) {
            let id = activeIds[index]
            let task = jobs[id - 1]
            var taskChanged = false
            let remaining = max(0, task.durationMillis - task.elapsedMillis)
            let step = min(delta, remaining)
            if (step > 0) {
                task.elapsedMillis += step
                let percent = min(100, task.elapsedMillis * 100 / task.durationMillis)
                if (percent != task.progressPercent) {
                    progressSum += percent - task.progressPercent
                    task.progressPercent = percent
                    task.refreshRow()
                    updateVisibleRow(task)
                    changed = true
                    taskChanged = true
                }
            }
            if (task.elapsedMillis >= task.durationMillis) {
                task.status = WorkbenchJobStatus.Done
                runningCount--
                doneCount++
                task.progressPercent = 100
                task.refreshRow()
                completedIds.add(id)
                activeIds.remove(at: index)
                changed = true
                statusChanged = true
                taskChanged = true
            } else {
                index++
            }
            if (taskChanged) { advancedIds.add(id) }
        }
        if (statusChanged) { rebuildVisible() }
        changed
    }

    func setMetadata(
        id: Int64,
        name: String,
        priority: String,
        notify: Bool,
        tags: Array<String>,
        notes: String
    ): Bool {
        if (id < 1 || id > jobs.size) { return false }
        let task = jobs[id - 1]
        if (task.name == name && task.priority == priority && task.notify == notify &&
            sameStrings(task.tags, tags) && task.notes == notes) { return false }
        task.name = name
        task.priority = priority
        task.notify = notify
        task.tags = copyStrings(tags)
        task.notes = notes
        task.refreshRow()
        rebuildVisible()
        rebuildQueuePreview()
        true
    }

    private func removeActive(id: Int64): Unit {
        for (index in 0..activeIds.size) {
            if (activeIds[index] == id) {
                activeIds.remove(at: index)
                return
            }
        }
    }

    private func matches(task: WorkbenchJob): Bool {
        if (let Some(project) <- projectFilter) {
            if (task.project != project) { return false }
        }
        if (let Some(status) <- statusFilter) {
            if (task.status != status) { return false }
        }
        if (queryLower.isEmpty()) { return true }
        task.name.toLower().contains(queryLower) || task.label().toLower().contains(queryLower) ||
            task.id.toString().contains(queryLower)
    }

    private func compareJobs(leftId: Int64, rightId: Int64): Int64 {
        let left = jobs[leftId - 1]
        let right = jobs[rightId - 1]
        var result: Int64 = 0
        match (sortColumn) {
            case 0 => result = compareInt(left.id, right.id)
            case 1 => result = compareString(left.name, right.name)
            case 2 => result = compareString(left.project, right.project)
            case 3 => result = compareInt(statusRank(left.status), statusRank(right.status))
            case 4 => result = compareInt(left.progressPercent, right.progressPercent)
            case _ => result = 0
        }
        if (result != 0 && sortDescending) { result = -result }
        if (result != 0) { return result }
        compareInt(left.id, right.id)
    }

    private func rebuildVisible(): Unit {
        let ids = ArrayList<Int64>()
        for (task in jobs) {
            if (!matches(task)) { continue }
            var at = ids.size
            while (at > 0 && compareJobs(task.id, ids[at - 1]) < 0) { at-- }
            ids.add(task.id, at: at)
        }
        visibleIdCache = ids.toArray()
        let rows = ArrayList<Array<String>>()
        for (id in visibleIdCache) { rows.add(jobs[id - 1].rowCache) }
        visibleRowCache = rows.toArray()
    }

    private func rebuildQueuePreview(): Unit {
        let rows = ArrayList<Array<String>>()
        for (task in jobs) {
            if (task.status != WorkbenchJobStatus.Queued) { continue }
            rows.add([task.label(), task.name, task.project, task.priority])
            if (rows.size >= 8) { break }
        }
        queuedPreviewCache = rows.toArray()
    }

    private func updateVisibleRow(task: WorkbenchJob): Unit {
        for (index in 0..visibleIdCache.size) {
            if (visibleIdCache[index] == task.id) {
                visibleRowCache[index] = task.rowCache
                return
            }
        }
    }
}

class WorkbenchHistoryStore {
    private let logCapacity: Int64 = 200
    private let historyCapacity: Int64 = 60
    private let logValues = Array<String>(200, repeat: "")
    private let historyValues = Array<Int64>(60, repeat: 0)
    private var logHead: Int64 = 0
    private var logCount: Int64 = 0
    private var historyHead: Int64 = 0
    private var historyCount: Int64 = 0
    private var logCache: Array<String> = []
    private var historyCache: Array<Int64> = []

    func pushLog(text: String): Unit {
        var index = (logHead + logCount) % logCapacity
        if (logCount == logCapacity) {
            index = logHead
            logHead = (logHead + 1) % logCapacity
        } else {
            logCount++
        }
        logValues[index] = text
        let ordered = ArrayList<String>()
        for (offset in 0..logCount) { ordered.add(logValues[(logHead + offset) % logCapacity]) }
        logCache = ordered.toArray()
    }

    func pushHistory(value: Int64): Unit {
        var index = (historyHead + historyCount) % historyCapacity
        if (historyCount == historyCapacity) {
            index = historyHead
            historyHead = (historyHead + 1) % historyCapacity
        } else {
            historyCount++
        }
        historyValues[index] = max(0, min(10000, value))
        let ordered = ArrayList<Int64>()
        for (offset in 0..historyCount) { ordered.add(historyValues[(historyHead + offset) % historyCapacity]) }
        historyCache = ordered.toArray()
    }

    func logs(): Array<String> { logCache }

    func history(): Array<Int64> { historyCache }
}

func compareInt(left: Int64, right: Int64): Int64 {
    if (left < right) { -1 } else if (left > right) { 1 } else { 0 }
}

func compareString(left: String, right: String): Int64 {
    match (left.compare(right)) {
        case Ordering.LT => -1
        case Ordering.GT => 1
        case _ => 0
    }
}

func statusRank(status: WorkbenchJobStatus): Int64 {
    match (status) {
        case WorkbenchJobStatus.Queued => 0
        case WorkbenchJobStatus.Running => 1
        case WorkbenchJobStatus.Done => 2
    }
}

func sameStrings(left: Array<String>, right: Array<String>): Bool {
    if (left.size != right.size) { return false }
    for (index in 0..left.size) { if (left[index] != right[index]) { return false } }
    true
}

func copyStrings(values: Array<String>): Array<String> {
    Array<String>(values.size, { index => values[index] })
}

