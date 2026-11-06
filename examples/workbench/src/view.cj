package cjtui_workbench

import core.*
import std.deriving.*
import std.collection.*

@Derive[Equatable]
enum WorkbenchPage {
    | Showcase
    | Overview
    | Tasks
    | Settings
}

class WorkbenchLayout {
    let area: Rect
    var interactive: Bool = false
    var complete: Bool = false
    var title: Rect = Rect(0, 0, 0, 0)
    var tabs: Rect = Rect(0, 0, 0, 0)
    var body: Rect = Rect(0, 0, 0, 0)
    var status: Rect = Rect(0, 0, 0, 0)
    var guardText: Rect = Rect(0, 0, 0, 0)
    var toast: Rect = Rect(0, 0, 0, 0)
    var projectTree: Rect = Rect(0, 0, 0, 0)
    var overviewArea: Rect = Rect(0, 0, 0, 0)
    var overviewBottom: Rect = Rect(0, 0, 0, 0)
    var overviewTop: Rect = Rect(0, 0, 0, 0)
    var metricCards: Array<Rect> = []
    var overviewMiddle: Rect = Rect(0, 0, 0, 0)
    var chartPanel: Rect = Rect(0, 0, 0, 0)
    var chartLegend: Rect = Rect(0, 0, 0, 0)
    var chartPlot: Rect = Rect(0, 0, 0, 0)
    var chartMeters: Rect = Rect(0, 0, 0, 0)
    var sparkPanel: Rect = Rect(0, 0, 0, 0)
    var pipelinePanel: Rect = Rect(0, 0, 0, 0)
    var pipelineCanvas: Rect = Rect(0, 0, 0, 0)
    var logPanel: Rect = Rect(0, 0, 0, 0)
    var overviewTask: Rect = Rect(0, 0, 0, 0)
    var queuePanel: Rect = Rect(0, 0, 0, 0)
    var galleryNav: Rect = Rect(0, 0, 0, 0)
    var galleryContent: Rect = Rect(0, 0, 0, 0)
    var logView: Rect = Rect(0, 0, 0, 0)
    var logScrollbar: Rect = Rect(0, 0, 0, 0)
    var tasksArea: Rect = Rect(0, 0, 0, 0)
    var tasksMain: Rect = Rect(0, 0, 0, 0)
    var taskQuery: Rect = Rect(0, 0, 0, 0)
    var taskSearch: Rect = Rect(0, 0, 0, 0)
    var taskFilter: Rect = Rect(0, 0, 0, 0)
    var taskActions: Rect = Rect(0, 0, 0, 0)
    var taskRun: Rect = Rect(0, 0, 0, 0)
    var taskEdit: Rect = Rect(0, 0, 0, 0)
    var taskReset: Rect = Rect(0, 0, 0, 0)
    var taskTableBlock: Rect = Rect(0, 0, 0, 0)
    var taskTable: Rect = Rect(0, 0, 0, 0)
    var taskScrollbar: Rect = Rect(0, 0, 0, 0)
    var taskDetail: Rect = Rect(0, 0, 0, 0)
    var taskDetailRun: Rect = Rect(0, 0, 0, 0)
    var taskDetailEdit: Rect = Rect(0, 0, 0, 0)
    var taskDetailReset: Rect = Rect(0, 0, 0, 0)
    var settingsArea: Rect = Rect(0, 0, 0, 0)
    var settingsLeft: Rect = Rect(0, 0, 0, 0)
    var settingsRight: Rect = Rect(0, 0, 0, 0)
    var settingTheme: Rect = Rect(0, 0, 0, 0)
    var settingAccent: Rect = Rect(0, 0, 0, 0)
    var settingMotion: Rect = Rect(0, 0, 0, 0)
    var settingSpeed: Rect = Rect(0, 0, 0, 0)
    var settingPause: Rect = Rect(0, 0, 0, 0)
    var settingReset: Rect = Rect(0, 0, 0, 0)
    var editor: Rect = Rect(0, 0, 0, 0)
    var editorName: Rect = Rect(0, 0, 0, 0)
    var editorPriority: Rect = Rect(0, 0, 0, 0)
    var editorNotify: Rect = Rect(0, 0, 0, 0)
    var editorTags: Rect = Rect(0, 0, 0, 0)
    var editorNotes: Rect = Rect(0, 0, 0, 0)
    var editorCancel: Rect = Rect(0, 0, 0, 0)
    var editorSave: Rect = Rect(0, 0, 0, 0)
    var palette: Rect = Rect(0, 0, 0, 0)
    var dialog: Rect = Rect(0, 0, 0, 0)

    init(area: Rect) { this.area = area }
}

class WorkbenchGalleryAreas {
    var title: Rect = Rect(0, 0, 0, 0)
    var description: Rect = Rect(0, 0, 0, 0)
    var buttons: Array<Rect> = []
    var formLabels: Array<Rect> = []
    var formInputs: Array<Rect> = []
    var checkbox: Rect = Rect(0, 0, 0, 0)
    var select: Rect = Rect(0, 0, 0, 0)
    var switchControl: Rect = Rect(0, 0, 0, 0)
    var switchValue: Rect = Rect(0, 0, 0, 0)
    var dateLabel: Rect = Rect(0, 0, 0, 0)
    var datePicker: Rect = Rect(0, 0, 0, 0)
    var datePreviousYear: Rect = Rect(0, 0, 0, 0)
    var dateNextYear: Rect = Rect(0, 0, 0, 0)
    var panels: Array<Rect> = []
    var asciiToggle: Rect = Rect(0, 0, 0, 0)
    var layoutSample: Rect = Rect(0, 0, 0, 0)
    var navTabs: Rect = Rect(0, 0, 0, 0)
    var navSegments: Rect = Rect(0, 0, 0, 0)
    var navSegmentValue: Rect = Rect(0, 0, 0, 0)
    var navMenu: Rect = Rect(0, 0, 0, 0)
    var navTree: Rect = Rect(0, 0, 0, 0)
    var dataTable: Rect = Rect(0, 0, 0, 0)
    var dataSampleTabs: Rect = Rect(0, 0, 0, 0)
    var dataList: Rect = Rect(0, 0, 0, 0)
    var dataProgress: Rect = Rect(0, 0, 0, 0)
    var toasts: Rect = Rect(0, 0, 0, 0)
    var badge: Rect = Rect(0, 0, 0, 0)
    var paletteButton: Rect = Rect(0, 0, 0, 0)
    var dialogButton: Rect = Rect(0, 0, 0, 0)
    var themeToggle: Rect = Rect(0, 0, 0, 0)
    var themeAccent: Rect = Rect(0, 0, 0, 0)
    var themeCapabilityLabel: Rect = Rect(0, 0, 0, 0)
    var themeCapabilityPreview: Rect = Rect(0, 0, 0, 0)
    var themeSamples: Array<Rect> = []
}

func workbenchGalleryAreas(area: Rect, category: Int64, sample!: Int64 = 0): WorkbenchGalleryAreas {
    let out = WorkbenchGalleryAreas()
    out.title = galleryRect(area, 0, 0, area.width, 1)
    out.description = galleryRect(area, 0, 1, area.width, 1)
    out.buttons = galleryColumns(area, 3, 1, 5)
    if (category == 0) {
        out.panels = galleryColumns(area, 5, min(7, max(0, area.height - 5)), 3)
        out.dataProgress = galleryRect(area, 0, 13, area.width, 1)
    } else if (category == 1) {
        out.panels = galleryColumns(area, 3, min(7, max(0, area.height - 3)), 3)
        out.asciiToggle = galleryRect(area, 0, 11, min(26, area.width), 1)
        out.layoutSample = galleryRect(area, 0, 13, area.width, max(0, area.height - 13))
    } else if (category == 2) {
        let formArea = workbenchFormsArea(area)
        out.buttons = galleryColumns(formArea, 3, 1, 5)
        let columns = galleryColumns(formArea, 5, 2, 2)
        out.formLabels = [
            galleryRect(formArea, 0, 5, columns[0].width, 1),
            galleryRect(formArea, columns[1].x - formArea.x, 5, columns[1].width, 1),
            galleryRect(formArea, 0, 9, columns[0].width, 1),
            galleryRect(formArea, columns[1].x - formArea.x, 9, columns[1].width, 1)
        ]
        out.formInputs = [
            galleryRect(formArea, 1, 7, max(0, columns[0].width - 2), 1),
            galleryRect(formArea, columns[1].x - formArea.x + 1, 7, max(0, columns[1].width - 2), 1),
            galleryRect(formArea, 1, 11, max(0, columns[0].width - 2), 1),
            galleryRect(formArea, columns[1].x - formArea.x + 1, 11, max(0, columns[1].width - 2), 1)
        ]
        out.checkbox = galleryRect(formArea, 0, 13, columns[0].width, 1)
        out.select = galleryRect(formArea, columns[1].x - formArea.x, 13, columns[1].width, 4)
        out.switchControl = galleryRect(formArea, 0, 15, columns[0].width, 1)
        out.switchValue = galleryRect(formArea, 0, 16, columns[0].width, 1)
        out.dateLabel = galleryRect(formArea, 0, 17, 6, 1)
        out.datePicker = galleryRect(formArea, 6, 17, min(10, max(0, columns[0].width - 6)), 1)
        let yearButtonWidth = min(10, max(0, (formArea.width - 17) / 2))
        out.datePreviousYear = galleryRect(formArea, 17, 17, yearButtonWidth, 1)
        out.dateNextYear = galleryRect(formArea, 17 + yearButtonWidth, 17, yearButtonWidth, 1)
    } else if (category == 3) {
        out.navTabs = galleryRect(area, 0, 3, area.width, 1)
        out.navSegments = galleryRect(area, 0, 4, area.width, 1)
        out.navSegmentValue = galleryRect(area, 0, 5, area.width, 1)
        let halves = galleryColumns(area, 6, max(0, area.height - 6), 2)
        out.navMenu = halves[0]
        out.navTree = halves[1]
    } else if (category == 4) {
        out.dataSampleTabs = galleryRect(area, 0, 3, area.width, 1)
        let sampleY = Int64(5)
        let sampleHeight = max(0, area.height - sampleY)
        let sampleArea = galleryRect(area, 0, sampleY, area.width, sampleHeight)
        if (sample == 0) {
            out.dataTable = sampleArea
        } else if (sample == 1) {
            out.dataList = sampleArea
        } else {
            out.dataProgress = sampleArea
        }
    } else if (category == 5) {
        out.buttons = galleryColumns(area, 3, 1, 4)
        out.badge = galleryRect(area, 0, 4, area.width, 1)
        out.toasts = galleryRect(area, 0, 5, area.width, min(5, max(0, area.height - 5)))
    } else if (category == 6) {
        out.paletteButton = galleryRect(area, 0, 3, min(22, area.width), 1)
        out.dialogButton = galleryRect(area, min(24, area.width), 3, min(22, max(0, area.width - 24)), 1)
    } else {
        out.themeToggle = galleryRect(area, 0, 3, min(24, area.width), 1)
        out.themeAccent = galleryRect(area, 0, 5, min(36, area.width), 1)
        out.themeCapabilityLabel = galleryRect(area, 0, 8, area.width, 1)
        out.themeCapabilityPreview = galleryRect(area, 0, 9, min(40, area.width), 4)
        out.themeSamples = galleryColumns(area, 13, 1, 5)
    }
    out
}

func workbenchFormsArea(area: Rect): Rect {
    let width = min(120, area.width)
    Rect(area.x + max(0, (area.width - width) / 2), area.y, width, area.height)
}

func galleryRect(area: Rect, x: Int64, y: Int64, width: Int64, height: Int64): Rect {
    let left = min(area.right, max(area.x, area.x + max(0, x)))
    let top = min(area.bottom, max(area.y, area.y + max(0, y)))
    let right = min(area.right, max(left, left + max(0, width)))
    let bottom = min(area.bottom, max(top, top + max(0, height)))
    Rect(left, top, right - left, bottom - top)
}

func galleryColumns(area: Rect, y: Int64, height: Int64, count: Int64): Array<Rect> {
    let out = ArrayList<Rect>()
    if (count <= 0) { return out.toArray() }
    let gap = if (area.width >= count * 2 - 1) { Int64(1) } else { Int64(0) }
    let width = max(0, (area.width - gap * (count - 1)) / count)
    for (index in 0..count) {
        let x = index * (width + gap)
        let cellWidth = if (index == count - 1) { max(0, area.width - x) } else { width }
        out.add(galleryRect(area, x, y, cellWidth, height))
    }
    out.toArray()
}

func workbenchLayout(area: Rect, page: WorkbenchPage, product!: Bool = false): WorkbenchLayout {
    let out = WorkbenchLayout(area)
    out.interactive = area.width >= 80 && area.height >= 24
    out.complete = area.width >= 120 && area.height >= 32
    out.guardText = area
    let marginX = min(1, area.width)
    let marginY = min(1, area.height)
    let innerWidth = max(0, area.width - 2)
    let innerHeight = max(0, area.height - 2)
    out.title = Rect(area.x + marginX, area.y + marginY, innerWidth, min(1, innerHeight))
    out.tabs = Rect(area.x + marginX, area.y + marginY + 1, innerWidth, if (innerHeight > 1) { 1 } else { 0 })
    out.body = Rect(area.x + marginX, area.y + marginY + 2, innerWidth, max(0, innerHeight - 3))
    out.status = Rect(area.x + marginX, area.y + marginY + max(0, innerHeight - 1), innerWidth, if (innerHeight > 0) { 1 } else { 0 })
    out.toast = Rect(out.body.right - min(48, out.body.width), out.body.bottom - min(3, out.body.height), min(48, out.body.width), min(3, out.body.height))

    if (page == WorkbenchPage.Overview && out.body.width > 140) {
        let shift = (out.body.width - 140) / 2
        out.body = Rect(out.body.x + shift, out.body.y, 140, out.body.height)
        out.title = Rect(out.title.x + shift, out.title.y, 140, out.title.height)
        out.tabs = Rect(out.tabs.x + shift, out.tabs.y, 140, out.tabs.height)
        out.status = Rect(out.status.x + shift, out.status.y, 140, out.status.height)
        out.toast = Rect(out.body.right - min(48, out.body.width), out.body.bottom - min(3, out.body.height),
            min(48, out.body.width), min(3, out.body.height))
    }
    if (product && out.body.height > 0) {
        // Product notifications have a dedicated row outside every content panel.
        out.toast = Rect(out.body.x, out.body.bottom - 1, out.body.width, 1)
        out.body = Rect(out.body.x, out.body.y, out.body.width, out.body.height - 1)
    }
    var content = out.body
    if (out.complete && (page == WorkbenchPage.Overview || page == WorkbenchPage.Tasks)) {
        out.projectTree = Rect(out.body.x, out.body.y, min(18, out.body.width), out.body.height)
        content = Rect(out.body.x + min(out.body.width, 19), out.body.y, max(0, out.body.width - 19), out.body.height)
    }

    if (page == WorkbenchPage.Overview) {
        out.overviewArea = content
        let topHeight = min(4, content.height)
        out.overviewTop = Rect(content.x, content.y, content.width, topHeight)
        let gap = if (out.complete && content.height > topHeight) { 1 } else { 0 }
        let metricGap = if (content.width >= 4) { 1 } else { 0 }
        let metricWidth = max(0, (content.width - metricGap * 3) / 4)
        let cards = ArrayList<Rect>()
        for (index in 0..4) {
            let x = content.x + index * (metricWidth + metricGap)
            let width = if (index == 3) { max(0, content.right - x) } else { metricWidth }
            cards.add(Rect(x, content.y, width, topHeight))
        }
        out.metricCards = cards.toArray()
        let middleY = content.y + topHeight + gap
        let middleHeight = min(if (out.complete) { 9 } else { 8 }, max(0, content.bottom - middleY))
        out.overviewMiddle = Rect(content.x, middleY, content.width, middleHeight)
        let middleGap = if (content.width > 1) { 1 } else { 0 }
        let halfWidth = max(0, (content.width - middleGap) / 2)
        out.chartPanel = Rect(content.x, middleY, halfWidth, middleHeight)
        out.sparkPanel = Rect(content.x + halfWidth + middleGap, middleY, max(0, content.right - (content.x + halfWidth + middleGap)), min(4, middleHeight))
        let pipelineOffset = Int64(5)
        out.pipelinePanel = Rect(out.sparkPanel.x, middleY + min(middleHeight, pipelineOffset), out.sparkPanel.width, max(0, middleHeight - pipelineOffset))
        let chartBlock = Block(title: "Status distribution")
        let chartInner = chartBlock.inner(out.chartPanel)
        out.chartLegend = Rect(chartInner.x, chartInner.y, chartInner.width, min(1, chartInner.height))
        out.chartMeters = Rect(chartInner.x, chartInner.y + min(1, chartInner.height),
            chartInner.width, max(0, chartInner.height - 1))
        let pipeBlock = Block(title: "Pipeline")
        out.pipelineCanvas = pipeBlock.inner(out.pipelinePanel)
        let logsY = middleY + middleHeight + if (content.bottom > middleY + middleHeight) { 1 } else { 0 }
        let bottomHeight = max(0, content.bottom - logsY)
        out.overviewBottom = Rect(content.x, logsY, content.width, bottomHeight)
        let bottomGap = if (content.width >= 70) { 1 } else { 0 }
        let activityWidth = if (bottomGap > 0) { (content.width - bottomGap) * 3 / 5 } else { content.width }
        out.logPanel = Rect(content.x, logsY, activityWidth, min(7, bottomHeight))
        let remaining = max(0, bottomHeight - out.logPanel.height - 1)
        if (remaining >= 6) {
            let extraDetail = min(3, max(0, area.height - 36) / 3)
            out.overviewTask = Rect(content.x, out.logPanel.bottom + 1, activityWidth, min(7 + extraDetail, remaining))
        }
        if (bottomGap > 0) {
            let queueHeight = if (out.overviewTask.height > 0) {
                min(bottomHeight, out.overviewTask.bottom - logsY)
            } else { bottomHeight }
            out.queuePanel = Rect(out.logPanel.right + bottomGap, logsY,
                max(0, content.right - (out.logPanel.right + bottomGap)), queueHeight)
        }
        let logInner = Block(title: "").inner(out.logPanel)
        let logY = logInner.y + min(1, logInner.height)
        out.logScrollbar = Rect(logInner.right - min(1, logInner.width), logY, min(1, logInner.width), max(0, logInner.bottom - logY))
        out.logView = Rect(logInner.x, logY, max(0, logInner.width - 1), max(0, logInner.bottom - logY))
    } else if (page == WorkbenchPage.Tasks) {
        out.tasksArea = out.body
        out.tasksMain = content
        let filterWidth = min(18, content.width)
        out.taskQuery = Rect(content.x, content.y, content.width, min(3, content.height))
        out.taskFilter = Rect(max(content.x, content.right - filterWidth), content.y, filterWidth, min(5, content.height))
        out.taskSearch = Rect(content.x, content.y, max(0, content.width - filterWidth - if (content.width > filterWidth) { 1 } else { 0 }), min(3, content.height))
        let actionsY = content.y + min(3, content.height)
        out.taskActions = Rect(content.x, actionsY, content.width, if (content.bottom > actionsY) { 1 } else { 0 })
        let buttonWidth = min(12, max(0, content.width / 3))
        out.taskRun = Rect(content.x, actionsY, buttonWidth, out.taskActions.height)
        out.taskEdit = Rect(content.x + buttonWidth, actionsY, buttonWidth, out.taskActions.height)
        out.taskReset = Rect(content.x + buttonWidth * 2, actionsY, max(0, content.right - (content.x + buttonWidth * 2)), out.taskActions.height)
        let tableY = content.y + min(5, content.height)
        let tableHeight = max(0, content.bottom - tableY)
        let detailWidth = if (out.complete) { min(30, content.width) } else { Int64(0) }
        let detailGap = if (detailWidth > 0 && content.width > detailWidth) { 1 } else { 0 }
        let tableWidth = max(0, content.width - detailWidth - detailGap)
        out.taskTableBlock = Rect(content.x, tableY, tableWidth, tableHeight)
        let tableInner = Block(title: "Tasks").inner(out.taskTableBlock)
        // Keep a blank gutter between the table and scroll indicator; the
        // indicator tracks data rows rather than covering the header/rule.
        let scrollY = tableInner.y + min(2, tableInner.height)
        out.taskScrollbar = Rect(tableInner.right - min(1, tableInner.width), scrollY,
            min(1, tableInner.width), max(0, tableInner.bottom - scrollY))
        out.taskTable = Rect(tableInner.x, tableInner.y, max(0, tableInner.width - min(2, tableInner.width)), tableInner.height)
        if (detailWidth > 0) {
            out.taskDetail = Rect(content.right - detailWidth, tableY, detailWidth, tableHeight)
            let inner = Block(title: "Selected task").inner(out.taskDetail)
            let buttonsY = inner.y + min(11, inner.height)
            let buttonWidth = max(0, (inner.width - 2) / 3)
            out.taskDetailRun = Rect(inner.x, buttonsY, buttonWidth, min(1, max(0, inner.bottom - buttonsY)))
            out.taskDetailEdit = Rect(inner.x + buttonWidth, buttonsY, buttonWidth, min(1, max(0, inner.bottom - buttonsY)))
            out.taskDetailReset = Rect(inner.x + buttonWidth * 2, buttonsY, max(0, inner.width - buttonWidth * 2), min(1, max(0, inner.bottom - buttonsY)))
        }
    } else if (page == WorkbenchPage.Showcase) {
        out.galleryNav = Rect(content.x, content.y, content.width, min(1, content.height))
        let galleryY = content.y + min(1, content.height)
        out.galleryContent = Rect(content.x, galleryY, content.width, max(0, content.bottom - galleryY))
    } else {
        out.settingsArea = out.body
        let gap = if (out.body.width >= 2) { 2 } else { 0 }
        let leftWidth = max(0, (out.body.width - gap) / 2)
        out.settingsLeft = Rect(out.body.x, out.body.y, leftWidth, out.body.height)
        out.settingsRight = Rect(out.body.x + leftWidth + gap, out.body.y, max(0, out.body.right - (out.body.x + leftWidth + gap)), out.body.height)
        out.settingTheme = Rect(out.settingsLeft.x, out.settingsLeft.y + min(1, out.settingsLeft.height), out.settingsLeft.width, min(5, max(0, out.settingsLeft.height - 1)))
        out.settingAccent = Rect(out.settingsLeft.x, out.settingsLeft.y + min(6, out.settingsLeft.height), out.settingsLeft.width, min(3, max(0, out.settingsLeft.bottom - (out.settingsLeft.y + 6))))
        out.settingMotion = Rect(out.settingsLeft.x, out.settingsLeft.y + min(10, out.settingsLeft.height), out.settingsLeft.width, if (out.settingsLeft.bottom > out.settingsLeft.y + 10) { 1 } else { 0 })
        out.settingSpeed = Rect(out.settingsRight.x, out.settingsRight.y + min(1, out.settingsRight.height), out.settingsRight.width, min(5, max(0, out.settingsRight.height - 1)))
        out.settingPause = Rect(out.settingsRight.x, out.settingsRight.y + min(7, out.settingsRight.height), out.settingsRight.width, if (out.settingsRight.bottom > out.settingsRight.y + 7) { 1 } else { 0 })
        out.settingReset = Rect(out.settingsRight.x, out.settingsRight.y + min(10, out.settingsRight.height), out.settingsRight.width, if (out.settingsRight.bottom > out.settingsRight.y + 10) { 1 } else { 0 })
    }

    if (product && page == WorkbenchPage.Overview) { configureCiOverview(out) }

    let editorWidth = min(88, max(0, area.width - 4))
    let editorHeight = min(22, max(0, area.height - 2))
    out.editor = centered(area, editorWidth, editorHeight)
    let editInner = Block(title: "").inner(out.editor)
    out.editorName = Rect(editInner.x + 2, editInner.y + 4, max(0, editInner.width - 4), 1)
    let formY = editInner.y + min(7, editInner.height)
    let formHeight = min(10, max(0, editInner.bottom - formY - 2))
    let leftWidth = max(0, (editInner.width - 3) / 2)
    out.editorPriority = Rect(editInner.x + 1, formY, leftWidth, min(3, formHeight))
    out.editorNotify = Rect(editInner.x + 1, formY + min(4, formHeight), leftWidth, min(1, max(0, formHeight - 4)))
    out.editorTags = Rect(editInner.x + 1, formY + min(6, formHeight), leftWidth, max(0, formHeight - min(6, formHeight)))
    out.editorNotes = Rect(editInner.x + leftWidth + 3, formY + min(2, formHeight),
        max(0, editInner.width - leftWidth - 5), max(0, formHeight - 3))
    let buttonsY = max(editInner.y, editInner.bottom - 1)
    out.editorCancel = Rect(max(editInner.x, editInner.right - 26), buttonsY, min(12, editInner.width), min(1, editInner.height))
    out.editorSave = Rect(max(editInner.x, editInner.right - 12), buttonsY, min(12, editInner.width), min(1, editInner.height))
    let paletteWidth = min(70, max(0, area.width - 4))
    let paletteHeight = min(18, max(0, area.height - 2))
    out.palette = centered(area, paletteWidth, paletteHeight)
    out.dialog = centered(area, min(64, max(0, area.width - 4)), min(12, max(0, area.height - 2)))
    out
}


// Product overview gives the running pipeline and its log most of the screen.
// The project filter remains available on the Tasks page and command palette.
func configureCiOverview(out: WorkbenchLayout): Unit {
    let body = out.body
    out.projectTree = Rect(0, 0, 0, 0)
    out.overviewArea = body
    out.overviewTop = Rect(body.x, body.y, body.width, min(3, body.height))
    let metricWidth = max(0, (body.width - 3) / 4)
    let cards = ArrayList<Rect>()
    for (index in 0..4) {
        let x = body.x + index * (metricWidth + 1)
        let width = if (index == 3) { max(0, body.right - x) } else { metricWidth }
        cards.add(Rect(x, body.y, width, out.overviewTop.height))
    }
    out.metricCards = cards.toArray()
    let compact = body.width < 100 || body.height < 27
    let top = min(body.bottom, out.overviewTop.bottom + if (compact) { 0 } else { 1 })
    let available = max(0, body.bottom - top)
    let pipelineHeight = if (compact) { min(9, max(0, available - 6)) }
        else { min(12, max(0, available - 11)) }
    let sideWidth = if (!compact) { max(30, body.width / 3) } else { Int64(0) }
    let gap = if (sideWidth > 0) { Int64(1) } else { Int64(0) }
    out.overviewTask = Rect(body.x, top, max(0, body.width - sideWidth - gap), pipelineHeight)
    out.chartPanel = Rect(out.overviewTask.right + gap, top, sideWidth, min(7, pipelineHeight))
    out.sparkPanel = Rect(out.chartPanel.x, min(body.bottom, out.chartPanel.bottom + 1), sideWidth,
        max(0, pipelineHeight - out.chartPanel.height - 1))
    let chartInner = Block(title: "").inner(out.chartPanel)
    out.chartLegend = Rect(chartInner.x, chartInner.y, chartInner.width, min(1, chartInner.height))
    out.chartMeters = Rect(chartInner.x, chartInner.y + min(1, chartInner.height), chartInner.width,
        max(0, chartInner.height - 1))
    let afterPipeline = min(body.bottom, out.overviewTask.bottom + if (compact) { 0 } else { 1 })
    let remaining = max(0, body.bottom - afterPipeline)
    // Reserve a readable activity log, then use available rows for real tasks.
    let feedHeight = if (compact) { Int64(0) } else { min(11, max(0, remaining - 7)) }
    out.queuePanel = Rect(body.x, afterPipeline, body.width, feedHeight)
    let logY = min(body.bottom, out.queuePanel.bottom + if (feedHeight > 0) { 1 } else { 0 })
    out.overviewBottom = Rect(body.x, logY, body.width, max(0, body.bottom - logY))
    out.logPanel = out.overviewBottom
    let logInner = Block(title: "").inner(out.logPanel)
    let logYInner = logInner.y + min(1, logInner.height)
    out.logView = Rect(logInner.x, logYInner, logInner.width, max(0, logInner.bottom - logYInner))
    out.logScrollbar = Rect(0, 0, 0, 0)
    out.pipelinePanel = Rect(0, 0, 0, 0)
    out.pipelineCanvas = Rect(0, 0, 0, 0)
}


func centered(area: Rect, width: Int64, height: Int64): Rect {
    let actualWidth = min(max(0, width), area.width)
    let actualHeight = min(max(0, height), area.height)
    Rect(area.x + max(0, (area.width - actualWidth) / 2), area.y + max(0, (area.height - actualHeight) / 2), actualWidth, actualHeight)
}

func renderWorkbench(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    // Paint the canvas as well as the content. Box-drawing glyphs occupy whole
    // cells, so a different terminal background would show around their strokes.
    frame.fill(frame.area, app.theme.normal)
    if (!layout.interactive) {
        if (frame.isDirty(layout.guardText)) {
            frame.fill(layout.guardText, app.theme.normal)
            frame.renderWidget(Paragraph("Need at least 80x24\nCtrl-C exits", style: app.theme.normal), layout.guardText)
        }
        return
    }
    if (frame.isDirty(layout.title)) {
        frame.fill(layout.title, app.theme.normal)
        let title = "Termcanvas Workbench"
        let titleStyle = app.theme.accent.withModifier(Modifier.strong())
        frame.renderWidget(Paragraph(title, style: titleStyle), layout.title)
        let labelArea = Rect(max(layout.title.x, layout.title.right - 20), layout.title.y, min(20, layout.title.width), layout.title.height)
        frame.renderWidget(Paragraph("SIMULATED / MEMORY", style: app.secondaryStyle), labelArea)
    }
    if (frame.isDirty(layout.tabs)) {
        let pageTabs = Tabs(["Gallery", "Overview", "Tasks", "Settings"], selected: app.tabs.selected)
        pageTabs.setTheme(Some(app.theme))
        pageTabs.setFocused(app.focus.isFocused("tabs"))
        frame.renderWidget(pageTabs, layout.tabs)
    }
    if (app.toastManager.count() == 0 && frame.isDirty(layout.toast)) {
        frame.fill(layout.toast, app.theme.normal)
    }
    match (app.page) {
        case WorkbenchPage.Showcase => renderShowcase(app, frame)
        case WorkbenchPage.Overview => renderOverview(app, frame)
        case WorkbenchPage.Tasks => renderTasks(app, frame)
        case WorkbenchPage.Settings => renderSettings(app, frame)
    }
    if (frame.isDirty(layout.status)) {
        frame.fill(layout.status, app.theme.normal)
        let other = app.model.jobs.size - app.model.queuedCount - app.model.runningCount - app.model.doneCount
        let counts = "Q ${app.model.queuedCount}  R ${app.model.runningCount}  D ${app.model.doneCount}  Other ${other}"
        let state = if (app.paused) { "PAUSED" } else { "RUNNING" }
        let right = if (app.productMode) { "F1 help  F2 cmds  Tab focus  Ctrl-C exit" }
            else if (layout.status.width < 100) { "Tab focus  F1 help  F2 cmds  Ctrl-C exit" }
            else { "LOCAL DEMO  ${state}  F1 help  F2 palette  F3 page  Tab focus  Ctrl-C exit" }
        let status = if (app.productMode && (app.statusMessage == "Ready" || app.statusMessage == "Terminal focus lost")) {
            counts
        } else { counts + "  " + app.statusMessage }
        frame.renderWidget(StatusBar(left: status, right: right, style: app.secondaryStyle), layout.status)
    }
    let localGalleryToast = app.page == WorkbenchPage.Showcase && app.galleryTabs.selected == 5
    if (app.toastManager.count() > 0 && !localGalleryToast && frame.isDirty(layout.toast)) {
        frame.fill(layout.toast, app.theme.normal)
        frame.renderWidget(app.toastManager, layout.toast)
    }
    renderModal(app, frame)
}

func workbenchProjectRows(area: Rect): Rect {
    Rect(area.x + min(1, area.width), area.y + min(1, area.height),
        max(0, area.width - 1), max(0, area.height - 1))
}

func renderProjectSidebar(app: WorkbenchApp, frame: Frame, area: Rect): Unit {
    frame.fill(area, app.theme.normal)
    frame.renderWidget(Paragraph("PROJECTS", style: app.secondaryStyle),
        Rect(area.x + 1, area.y, max(0, area.width - 1), 1))
    let rows = workbenchProjectRows(area)
    let tree = Tree(app.projectNodes, selected: app.projects.selected, offset: app.projects.offset,
        style: app.theme.normal, focused: app.focus.isFocused("projects"), theme: Some(app.theme))
    frame.renderWidget(tree, rows)
}

func renderStatusMeter(app: WorkbenchApp, frame: Frame, area: Rect, label: String,
    value: Int64, total: Int64, fillStyle: Style): Unit {
    if (area.width <= 0 || area.height <= 0) { return }
    let labelWidth = min(14, max(0, area.width - 8))
    frame.renderWidget(Paragraph(label, style: app.secondaryStyle), Rect(area.x, area.y, labelWidth, 1))
    frame.renderWidget(ProgressBar(value, total: total, style: app.borderStyle, fillStyle: fillStyle,
        labelMode: ProgressBarLabelMode.Percent, labelStyle: app.theme.normal),
        Rect(area.x + labelWidth, area.y, max(0, area.width - labelWidth), 1))
}

func renderOverview(app: WorkbenchApp, frame: Frame): Unit {
    if (app.productMode) { renderCiOverview(app, frame); return }
    let layout = app.layout
    if (layout.projectTree.width > 0 && frame.isDirty(layout.projectTree)) {
        renderProjectSidebar(app, frame, layout.projectTree)
    }
    if (frame.isDirty(layout.overviewTop)) {
        frame.fill(layout.overviewTop, app.theme.normal)
        let counts = [app.model.runningCount, app.model.queuedCount, app.model.doneCount]
        let titles = ["RUNNING", "QUEUED", "COMPLETED"]
        let runningSummary = if (app.paused) { "PAUSED: ${counts[0]} held" } else { "Active slots" }
        let summaries = [runningSummary, "Ready to start", "Finished this run"]
        for (i in 0..3) {
            let area = layout.metricCards[i]
            let value = if (i == 0) { "${counts[i]} / 4" } else { counts[i].toString() }
            frame.renderWidget(MetricCard(titles[i], value, detail: summaries[i],
                style: app.secondaryStyle,
                valueStyle: if (i == 0) { app.theme.accent.withModifier(Modifier.strong()) } else { app.theme.normal.withModifier(Modifier.strong()) }), area)
        }
        let progress = app.model.totalProgressHundredths()
        let area = layout.metricCards[3]
        frame.renderWidget(MetricCard("TOTAL PROGRESS", formatPercent(progress), detail: "Across ${app.model.jobs.size} tasks",
            style: app.secondaryStyle, valueStyle: app.theme.normal.withModifier(Modifier.strong())), area)
        if (area.height > 3) {
            frame.renderWidget(ProgressBar(progress, total: 10000, style: app.borderStyle,
                fillStyle: app.theme.accent), Rect(area.x, area.y + 3, area.width, 1))
        }
    }
    if (frame.isDirty(layout.chartPanel)) {
        frame.fill(layout.chartPanel, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded), layout.chartPanel)
        frame.renderWidget(Paragraph("Status distribution", style: app.secondaryStyle), layout.chartLegend)
        let meters = layout.chartMeters
        let other = app.model.jobs.size - app.model.queuedCount - app.model.runningCount - app.model.doneCount
        let spacing = if (meters.height >= 5 && (other == 0 || meters.height >= 7)) { Int64(2) } else { Int64(1) }
        if (meters.height >= 3) {
            let total = app.model.jobs.size
            renderStatusMeter(app, frame, Rect(meters.x, meters.y, meters.width, 1),
                "Queued ${app.model.queuedCount}", app.model.queuedCount, total, app.secondaryStyle)
            renderStatusMeter(app, frame, Rect(meters.x, meters.y + spacing, meters.width, 1),
                "Running ${app.model.runningCount}", app.model.runningCount, total, app.theme.accent)
            renderStatusMeter(app, frame, Rect(meters.x, meters.y + spacing * 2, meters.width, 1),
                "Done ${app.model.doneCount}", app.model.doneCount, total, app.theme.success)
            if (other > 0 && meters.height > spacing * 3) {
                renderStatusMeter(app, frame, Rect(meters.x, meters.y + spacing * 3, meters.width, 1),
                    "Other ${other}", other, total, app.theme.warning)
            }
        }
    }
    if (frame.isDirty(layout.sparkPanel)) {
        frame.fill(layout.sparkPanel, app.theme.normal)
        let historyBlock = galleryBlock(app, "", BorderKind.Rounded)
        frame.renderWidget(historyBlock, layout.sparkPanel)
        let inner = historyBlock.inner(layout.sparkPanel)
        let allHistory = app.model.history()
        let visibleHistory = ArrayList<Int64>()
        var peak: Int64 = 0
        for (index in max(0, allHistory.size - inner.width)..allHistory.size) {
            let value = allHistory[index]
            visibleHistory.add(value)
            peak = max(peak, value)
        }
        let fullTitle = "Relative | sample peak ${formatPercent(peak)} | ${visibleHistory.size} samples, 250ms apart"
        let mediumTitle = "Rel. peak ${formatPercent(peak)} | ${visibleHistory.size} samples, 250ms apart"
        let shortTitle = "Rel. peak ${formatPercent(peak)} | ${visibleHistory.size}pts, 250ms apart"
        let title = if (visibleHistory.size < 2) { "Relative trend | collecting samples" }
            else if (displayWidth(fullTitle) <= inner.width) { fullTitle }
            else if (displayWidth(mediumTitle) <= inner.width) { mediumTitle } else { shortTitle }
        frame.renderWidget(Paragraph(title, style: app.secondaryStyle),
            Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
        frame.renderWidget(Sparkline(visibleHistory.toArray(), maxValue: peak, style: app.theme.accent),
            Rect(inner.x, inner.y + min(1, inner.height), inner.width, max(0, inner.height - 1)))
    }
    if (frame.isDirty(layout.pipelinePanel)) {
        frame.fill(layout.pipelinePanel, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded), layout.pipelinePanel)
        let canvas = frame.canvas(area: layout.pipelineCanvas)
        let text = "QUEUED -> RUNNING -> DONE"
        if (layout.complete && layout.pipelineCanvas.width >= 25) {
            canvas.drawText(layout.pipelineCanvas.x, layout.pipelineCanvas.y, "QUEUED", app.theme.warning)
            canvas.drawText(layout.pipelineCanvas.x + 7, layout.pipelineCanvas.y, "->", app.theme.normal)
            canvas.drawText(layout.pipelineCanvas.x + 10, layout.pipelineCanvas.y, "RUNNING", app.theme.info)
            canvas.drawText(layout.pipelineCanvas.x + 18, layout.pipelineCanvas.y, "->", app.theme.normal)
            canvas.drawText(layout.pipelineCanvas.x + 21, layout.pipelineCanvas.y, "DONE", app.theme.success)
        } else {
            canvas.drawText(layout.pipelineCanvas.x, layout.pipelineCanvas.y, text, app.theme.normal)
        }
        if (app.model.runningCount > 0 && !app.paused && layout.pipelineCanvas.width > 0 && layout.pipelineCanvas.height > 1) {
            let spinner = ["|", "/", "-", "\\"][app.spinnerFrame % 4]
            canvas.drawText(layout.pipelineCanvas.x, layout.pipelineCanvas.y + 1, "Running: " + spinner, app.theme.accent)
        }
    }
    if (frame.isDirty(layout.overviewBottom)) {
        frame.fill(layout.overviewBottom, app.theme.normal)
        let lines = app.model.logs()
        let viewport = layout.logView.height
        let total = lines.size
        app.logScroll.offset = max(0, min(app.logScroll.offset, max(0, total - viewport)))
        let block = galleryBlock(app, "", BorderKind.Rounded)
        frame.renderWidget(block, layout.logPanel)
        let inner = block.inner(layout.logPanel)
        frame.renderWidget(Paragraph("Activity log", style: app.secondaryStyle),
            Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
        frame.renderWidget(LogView(lines, offset: app.logScroll.offset, style: app.theme.normal), layout.logView)
        frame.renderWidget(Scrollbar(total, offset: app.logScroll.offset, viewport: viewport,
            style: app.theme.disabled, thumbStyle: app.theme.accent), layout.logScrollbar)
        renderQueuePreview(app, frame)
        renderOverviewTask(app, frame)
    }
}

func renderCiOverview(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (frame.isDirty(layout.overviewTop)) {
        frame.fill(layout.overviewTop, app.theme.normal)
        let values = ["${app.model.runningCount} / 4", app.model.queuedCount.toString(),
            app.model.doneCount.toString(), formatPercent(app.model.totalProgressHundredths())]
        let titles = ["RUNNING", "QUEUED", "COMPLETED", "TOTAL PROGRESS"]
        let details = [if (app.paused) { "Simulation paused" } else { "Active slots" },
            "Ready to start", "Finished this run", "Across ${app.model.jobs.size} tasks"]
        for (index in 0..4) {
            frame.renderWidget(MetricCard(titles[index], values[index], detail: details[index],
                style: app.secondaryStyle, valueStyle: if (index == 0) { app.theme.accent } else { app.theme.normal }),
                layout.metricCards[index])
        }
    }
    if (frame.isDirty(layout.overviewTask)) {
        let area = layout.overviewTask
        frame.fill(area, app.theme.normal)
        let block = galleryBlock(app, "", BorderKind.Rounded)
        frame.renderWidget(block, area)
        let inner = block.inner(area)
        frame.renderWidget(Paragraph("SELECTED PIPELINE  /  simulated", style: app.secondaryStyle),
            Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
        match (app.selectedId) {
            case Some(id) =>
                match (app.model.job(id)) {
                    case Some(task) =>
                        let stages = Array<TaskStatus>(5, { index => workbenchStageStatus(task, index) })
                        let current = min(4, task.progressPercent / 20)
                        let item = TaskActivity(task.name, status: workbenchActivityStatus(task.status), id: task.label(),
                            prefix: "CI", duration: "${task.elapsedMillis / 1000}s",
                            progressLabel: "Stages", progress: Some(TaskProgress.Items(stages)),
                            detail: "${statusLabel(task.status)} / ${task.project} / ${task.progressPercent}%  |  ${workbenchStageName(current)} ${current + 1}/5")
                        let body = Rect(inner.x, inner.y + min(1, inner.height), inner.width, max(0, inner.height - 1))
                        frame.renderWidget(TaskActivityView(item, activityFrame: app.spinnerFrame, theme: app.theme),
                            Rect(body.x, body.y, body.width, min(3, body.height)))
                        let stageArea = Rect(body.x + min(2, body.width), body.y + min(3, body.height),
                            max(0, body.width - 2), max(0, body.height - 3))
                        renderCiStageList(app, frame, task, stageArea)
                    case None => frame.renderWidget(Paragraph("No task selected", style: app.secondaryStyle), inner)
                }
            case None => frame.renderWidget(Paragraph("No task selected", style: app.secondaryStyle), inner)
        }
    }
    if (layout.chartPanel.width > 0 && frame.isDirty(layout.chartPanel)) {
        let area = layout.chartPanel
        frame.fill(area, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded), area)
        frame.renderWidget(Paragraph("STATUS", style: app.secondaryStyle), layout.chartLegend)
        let meters = layout.chartMeters
        let total = app.model.jobs.size
        let other = total - app.model.queuedCount - app.model.runningCount - app.model.doneCount
        if (meters.height >= 3) {
            renderStatusMeter(app, frame, Rect(meters.x, meters.y, meters.width, 1),
                "Queued ${app.model.queuedCount}", app.model.queuedCount, total, app.secondaryStyle)
            renderStatusMeter(app, frame, Rect(meters.x, meters.y + 1, meters.width, 1),
                "Running ${app.model.runningCount}", app.model.runningCount, total, app.theme.accent)
            renderStatusMeter(app, frame, Rect(meters.x, meters.y + 2, meters.width, 1),
                "Done ${app.model.doneCount}", app.model.doneCount, total, app.theme.success)
            if (other > 0 && meters.height >= 4) {
                renderStatusMeter(app, frame, Rect(meters.x, meters.y + 3, meters.width, 1),
                    "Other ${other}", other, total, app.theme.warning)
            }
        }
    }
    if (layout.sparkPanel.width > 0 && frame.isDirty(layout.sparkPanel)) {
        let area = layout.sparkPanel
        frame.fill(area, app.theme.normal)
        let block = galleryBlock(app, "", BorderKind.Rounded)
        frame.renderWidget(block, area)
        let inner = block.inner(area)
        let all = app.model.history()
        let samples = ArrayList<Int64>()
        var peak: Int64 = 0
        for (index in max(0, all.size - inner.width)..all.size) {
            samples.add(all[index])
            peak = max(peak, all[index])
        }
        let fullTitle = "PROGRESS / sampled peak ${formatPercent(peak)}"
        let shortTitle = "sample peak ${formatPercent(peak)}"
        let title = if (displayWidth(fullTitle) <= inner.width) { fullTitle } else { shortTitle }
        frame.renderWidget(Paragraph(title, style: app.secondaryStyle),
            Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
        frame.renderWidget(Sparkline(samples.toArray(), maxValue: peak, style: app.theme.accent),
            Rect(inner.x, inner.y + min(1, inner.height), inner.width, max(0, inner.height - 1)))
    }
    if (layout.queuePanel.height > 0 && frame.isDirty(layout.queuePanel)) {
        renderCiTaskFeed(app, frame)
    }
    if (frame.isDirty(layout.overviewBottom)) {
        let area = layout.logPanel
        frame.fill(area, app.theme.normal)
        let block = galleryBlock(app, "", BorderKind.Rounded)
        frame.renderWidget(block, area)
        let inner = block.inner(area)
        let lines = app.model.logs()
        app.logScroll.offset = max(0, min(app.logScroll.offset, max(0, lines.size - layout.logView.height)))
        let title = if (lines.size > layout.logView.height) { "ACTIVITY / simulated log  ·  Tab then Up/Down to scroll" }
            else { "ACTIVITY / simulated log" }
        frame.renderWidget(Paragraph(title, style: app.secondaryStyle),
            Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
        frame.renderWidget(LogView(lines, offset: app.logScroll.offset, style: app.theme.normal), layout.logView)
    }
}

func renderCiStageList(app: WorkbenchApp, frame: Frame, task: WorkbenchJob, area: Rect): Unit {
    let current = min(4, task.progressPercent / 20)
    let visible = if (area.height >= 5) { Int64(5) } else { max(1, area.height - 1) }
    let first = max(0, min(5 - visible, current - visible / 2))
    let entries = ArrayList<TaskActivityListEntry>()
    for (index in 0..5) {
        let description = if (index == current && task.status == WorkbenchJobStatus.Running) { "in progress" }
            else if (index < current || task.status == WorkbenchJobStatus.Done) { "complete" }
            else { "waiting" }
        let label = if (index == current && task.status != WorkbenchJobStatus.Queued) {
            statusLabel(task.status)
        } else { description }
        let stage = TaskActivity(workbenchStageName(index), status: workbenchStageStatus(task, index), statusText: label)
        entries.add(TaskActivityListEntry(stage, layout: TaskActivityLayout.Compact))
    }
    frame.renderWidget(TaskActivityList(entries.toArray(), offset: first,
        activityFrame: app.spinnerFrame, theme: app.theme), area)
}

func renderCiTaskFeed(app: WorkbenchApp, frame: Frame): Unit {
    let area = app.layout.queuePanel
    frame.fill(area, app.theme.normal)
    let block = galleryBlock(app, "", BorderKind.Rounded)
    frame.renderWidget(block, area)
    let inner = block.inner(area)
    frame.renderWidget(Paragraph("OTHER TASKS  /  simulated", style: app.secondaryStyle),
        Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
    let rows = max(0, inner.height - 1)
    let expanded = rows >= 9
    let entries = ArrayList<TaskActivityListEntry>()
    for (task in app.model.jobs) {
        if (app.selectedId == Some(task.id)) { continue }
        let stages = Array<TaskStatus>(5, { index => workbenchStageStatus(task, index) })
        let stage = workbenchStageName(min(4, task.progressPercent / 20))
        let item = TaskActivity(task.name, status: workbenchActivityStatus(task.status), id: task.label(),
            statusText: statusLabel(task.status), duration: "${task.elapsedMillis / 1000}s",
            detail: "${task.project} / ${stage} / ${task.progressPercent}%", progressLabel: "Stages",
            progress: Some(TaskProgress.Items(stages)))
        entries.add(TaskActivityListEntry(item,
            layout: if (expanded) { TaskActivityLayout.Expanded } else { TaskActivityLayout.Compact }))
    }
    let feed = Rect(inner.x, inner.y + min(1, inner.height), inner.width, rows)
    if (entries.isEmpty() && rows > 0) {
        frame.renderWidget(Paragraph("No other tasks", style: app.secondaryStyle),
            Rect(feed.x, feed.y, feed.width, 1))
    } else {
        frame.renderWidget(TaskActivityList(entries.toArray(), activityFrame: app.spinnerFrame, theme: app.theme), feed)
    }
}

func workbenchStageStatus(task: WorkbenchJob, index: Int64): TaskStatus {
    if (task.status == WorkbenchJobStatus.Done) { return TaskStatus.Done }
    let current = min(4, task.progressPercent / 20)
    if (index < current) { return TaskStatus.Done }
    if (index > current) { return TaskStatus.Pending }
    workbenchActivityStatus(task.status)
}

func renderOverviewTask(app: WorkbenchApp, frame: Frame): Unit {
    let area = app.layout.overviewTask
    if (area.width <= 0 || area.height <= 0) { return }
    let block = galleryBlock(app, "", BorderKind.Rounded)
    frame.renderWidget(block, area)
    let inner = block.inner(area)
    frame.renderWidget(Paragraph("Selected task", style: app.secondaryStyle),
        Rect(inner.x, inner.y, inner.width, min(1, inner.height)))
    let body = Rect(inner.x, inner.y + min(1, inner.height), inner.width, max(0, inner.height - 1))
    match (app.selectedId) {
        case Some(id) =>
            match (app.model.job(id)) {
                case Some(task) =>
                    if (app.productMode) {
                        let item = TaskActivity(task.name, status: workbenchActivityStatus(task.status), id: task.label(),
                            prefix: "CI", statusText: statusLabel(task.status),
                            duration: "${task.elapsedMillis / 1000}s", detail: "${statusLabel(task.status)} / ${task.project} / ${task.progressPercent}%",
                            progressLabel: "Progress", progress: Some(TaskProgress.Counts(task.progressPercent / 20, 5)))
                        frame.renderWidget(TaskActivityView(item, activityFrame: app.spinnerFrame, theme: app.theme), body)
                        return
                    }
                    let progress = if (body.height >= 5) { "\nProgress: ${task.progressPercent}%" } else { "" }
                    let tags = if (body.height >= 6) { "\nTags: ${joinText(task.tags, ", ")}" } else { "" }
                    let notify = if (body.height >= 7) { "\nNotify: ${if (task.notify) { "yes" } else { "no" }}" } else { "" }
                    let lines = "${task.label()}  ${task.name}\n${task.project} / ${task.priority} / ${statusLabel(task.status)}" +
                        progress + tags + notify + "\nF4 edit task"
                    frame.renderWidget(Paragraph(lines, style: app.theme.normal), body)
                case None => frame.renderWidget(Paragraph("No task selected", style: app.secondaryStyle), body)
            }
        case None => frame.renderWidget(Paragraph("No task selected", style: app.secondaryStyle), body)
    }
}

func renderQueuePreview(app: WorkbenchApp, frame: Frame): Unit {
    let area = app.layout.queuePanel
    if (area.width <= 0 || area.height <= 0) { return }
    let block = galleryBlock(app, "", BorderKind.Rounded)
    frame.renderWidget(block, area)
    let panelInner = block.inner(area)
    let inner = Rect(panelInner.x, panelInner.y + min(1, panelInner.height), panelInner.width, max(0, panelInner.height - 1))
    let rows = app.model.queuePreviewRows()
    let compact = inner.width < 38 || inner.height < 4
    let visible = min(rows.size, if (compact) { inner.height } else { max(0, inner.height - 2) })
    let title = if (panelInner.width >= 34) { "Ready queue ${visible}/${app.model.queuedCount}  |  F3: Tasks" }
        else { "Ready queue ${visible}/${app.model.queuedCount}" }
    frame.renderWidget(Paragraph(title, style: app.secondaryStyle),
        Rect(panelInner.x, panelInner.y, panelInner.width, min(1, panelInner.height)))
    if (rows.isEmpty()) {
        frame.renderWidget(Paragraph("Queue is clear", style: app.theme.success), inner)
        return
    }
    if (compact) {
        let lines = ArrayList<String>()
        for (row in rows) { lines.add(row[0] + "  " + row[1] + "  " + row[2]) }
        frame.renderWidget(Paragraph(joinText(lines.toArray(), "\n"), style: app.theme.normal), inner)
    } else {
        frame.renderWidget(Table(["ID", "TASK", "PROJECT", "PRIORITY"], rows,
            widths: [8, 10, 8, 8], style: app.theme.normal, headerStyle: app.theme.accent), inner)
    }
}

func renderTasks(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (layout.projectTree.width > 0 && frame.isDirty(layout.projectTree)) {
        renderProjectSidebar(app, frame, layout.projectTree)
    }
    if (frame.isDirty(layout.taskQuery)) {
        frame.fill(layout.taskQuery, app.theme.normal)
        frame.renderWidget(app.taskSearch, layout.taskSearch)
    }
    if (app.interaction.active().isNone() && app.focus.isFocused("task-search")) {
        frame.setCursor(app.taskSearch.cursorPosition(layout.taskSearch, options: frame.textWidthOptions()))
    }
    if (frame.isDirty(layout.taskActions)) {
        frame.fill(layout.taskActions, app.theme.normal)
        frame.renderWidget(Button("Run", focused: app.focus.isFocused("task-run"), disabled: !app.canRun(),
            style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), layout.taskRun)
        frame.renderWidget(Button("Edit", focused: app.focus.isFocused("task-edit"), disabled: !app.selectedId.isSome(),
            style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), layout.taskEdit)
        frame.renderWidget(Button("Reset", focused: app.focus.isFocused("task-reset"), disabled: !app.canReset(),
            style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), layout.taskReset)
    }
    if (frame.isDirty(layout.taskTableBlock)) {
        frame.fill(layout.taskTableBlock, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "Tasks", BorderKind.Rounded), layout.taskTableBlock)
        let visible = app.model.visibleIds()
        let options = frame.textWidthOptions()
        let selectionMarker = if (app.capabilities.unicode && displayWidth("●", options: options) == 1) { "●" } else { "*" }
        let table = Table(["ID", "Name", "Project", "Status", "Progress"], app.taskRows(options),
            widths: app.layoutTableWidths(), state: Some(app.taskState), style: app.theme.normal,
            headerStyle: app.theme.accent, selectedStyle: app.selectedStyle(), selectionMarker: selectionMarker)
        frame.renderWidget(table, layout.taskTable)
        let viewport = max(0, layout.taskTable.height - 2)
        frame.renderWidget(Scrollbar(visible.size, offset: app.taskScroll.offset, viewport: viewport,
            style: app.theme.disabled, thumbStyle: app.theme.accent), layout.taskScrollbar)
    }
    if (layout.taskDetail.width > 0) { renderTaskDetail(app, frame) }
    if (frame.isDirty(layout.taskFilter)) {
        frame.fill(layout.taskFilter, app.theme.normal)
        app.taskFilter.setVisualState(
            focused: app.focus.current() == Some("task-filter"),
            theme: Some(app.theme)
        )
        frame.renderWidget(app.taskFilter, layout.taskFilter)
    }
}

func renderTaskDetail(app: WorkbenchApp, frame: Frame): Unit {
    let area = app.layout.taskDetail
    if (!frame.isDirty(area)) { return }
    frame.fill(area, app.theme.normal)
    frame.renderWidget(galleryBlock(app, "Selected task", BorderKind.Rounded), area)
    let inner = galleryBlock(app, "Selected task", BorderKind.Rounded).inner(area)
    match (app.selectedId) {
        case Some(id) =>
            match (app.model.job(id)) {
                case Some(task) =>
                    let lastEvent = if (task.events.isEmpty()) { "" } else { task.events[task.events.size - 1] }
                    let text = "${task.label()}\n${task.name}\n${task.project} / ${statusLabel(task.status)}\nPriority: ${task.priority}\nNotify: ${if (task.notify) { "yes" } else { "no" }}\nTags: ${joinText(task.tags, ", ")}\n${task.notes}\nLast: ${lastEvent}"
                    frame.renderWidget(Paragraph(text, style: app.theme.normal), Rect(inner.x, inner.y, inner.width, min(8, inner.height)))
                    let progress = app.detailProgress(id, task.progressPercent * 100)
                    frame.renderWidget(ProgressBar(progress, total: 10000, label: formatPercent(progress),
                        style: app.theme.disabled, fillStyle: if (app.isSuccess(id)) { app.theme.success } else { app.theme.accent }),
                        Rect(inner.x, inner.y + min(9, inner.height), inner.width, 1))
                    frame.renderWidget(Button("Run", focused: app.focus.isFocused("task-run"), disabled: !app.canRun(),
                        style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), app.layout.taskDetailRun)
                    frame.renderWidget(Button("Edit", focused: app.focus.isFocused("task-edit"), disabled: !app.selectedId.isSome(),
                        style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), app.layout.taskDetailEdit)
                    frame.renderWidget(Button("Reset", focused: app.focus.isFocused("task-reset"), disabled: !app.canReset(),
                        style: app.theme.normal, focusedStyle: app.selectedStyle(), disabledStyle: app.theme.disabled), app.layout.taskDetailReset)
                case None => frame.renderWidget(Paragraph("No task selected", style: app.theme.disabled), inner)
            }
        case None => frame.renderWidget(Paragraph("No task selected", style: app.theme.disabled), inner)
    }
}

func workbenchAccentInitial(color: Color): String {
    match (color) {
        case Color.Red => "R"
        case Color.Green => "G"
        case Color.Yellow => "Y"
        case Color.Blue => "B"
        case Color.Magenta => "M"
        case Color.Cyan => "C"
        case _ => "?"
    }
}


func renderWorkbenchAccentPicker(app: WorkbenchApp, frame: Frame, area: Rect): Unit {
    app.accentPicker.setVisualState(
        focused: app.focus.isFocused("gallery-accent") || app.focus.isFocused("accent-picker"),
        theme: Some(app.theme)
    )
    if (app.effectiveColorTier() > 0) {
        frame.renderWidget(app.accentPicker, area)
    } else {
        var palette = ""
        for (i in 0..app.accentColors.size) {
            palette += workbenchAccentInitial(app.accentColors[i])
            palette += if (i == app.accentPicker.selected) { "*" } else { " " }
            palette += " "
        }
        frame.renderWidget(Paragraph(palette, style: app.theme.normal), area)
    }
}


func renderSettings(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (!frame.isDirty(layout.settingsArea)) { return }
    frame.fill(layout.settingsArea, app.theme.normal)
    frame.renderWidget(galleryBlock(app, "Appearance", BorderKind.Rounded), layout.settingsLeft)
    frame.renderWidget(galleryBlock(app, "Simulation", BorderKind.Rounded), layout.settingsRight)
    frame.renderWidget(app.themeRadio, layout.settingTheme)
    frame.renderWidget(Paragraph("Accent color", style: app.theme.normal), Rect(layout.settingAccent.x, layout.settingAccent.y, layout.settingAccent.width, 1))
    renderWorkbenchAccentPicker(app, frame, Rect(layout.settingAccent.x, layout.settingAccent.y + min(1, layout.settingAccent.height), layout.settingAccent.width, max(0, layout.settingAccent.height - 1)))
    frame.renderWidget(Checkbox("Motion", checked: app.motionEnabled, focused: app.focus.isFocused("setting-motion"),
        style: app.theme.normal, focusedStyle: app.selectedStyle(), theme: Some(app.theme)), layout.settingMotion)
    frame.renderWidget(Paragraph("Task speed", style: app.theme.normal), Rect(layout.settingSpeed.x, layout.settingSpeed.y, layout.settingSpeed.width, 1))
    frame.renderWidget(app.speedSelect, Rect(layout.settingSpeed.x, layout.settingSpeed.y + min(1, layout.settingSpeed.height), layout.settingSpeed.width, max(0, layout.settingSpeed.height - 1)))
    frame.renderWidget(Button(if (app.paused) { "Resume" } else { "Pause" }, focused: app.focus.isFocused("setting-pause"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.settingPause)
    frame.renderWidget(Button("Reset demo…", focused: app.focus.isFocused("setting-reset"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.settingReset)
}

func renderModal(app: WorkbenchApp, frame: Frame): Unit {
    match (app.interaction.active()) {
        case Some("editor") => renderEditor(app, frame)
        case Some("details") =>
            if (frame.isDirty(app.layout.dialog)) {
                frame.fill(app.layout.dialog, app.theme.normal)
                frame.renderWidget(app.detailsDialog, app.layout.dialog)
            }
        case Some("palette") =>
            if (frame.isDirty(app.layout.palette)) {
                frame.fill(app.layout.palette, app.theme.normal)
                frame.renderWidget(app.palette, app.layout.palette)
            }
        case Some("gallery-dialog") =>
            if (frame.isDirty(app.layout.dialog)) {
                frame.fill(app.layout.dialog, app.theme.normal)
                app.galleryDialog.confirmed = app.interaction.focus().current() == Some("gallery-dialog-confirm")
                frame.renderWidget(app.galleryDialog, app.layout.dialog)
            }
        case Some("help") =>
            if (app.editingId.isSome() || app.editorCreating) { renderEditor(app, frame) }
            if (frame.isDirty(app.layout.dialog)) {
                frame.fill(app.layout.dialog, app.theme.normal)
                frame.renderWidget(app.helpDialog, app.layout.dialog)
            }
        case Some("reset-confirm") =>
            if (frame.isDirty(app.layout.dialog)) {
                frame.fill(app.layout.dialog, app.theme.normal)
                frame.renderWidget(app.resetDialog, app.layout.dialog)
            }
        case Some("demo-confirm") =>
            if (frame.isDirty(app.layout.dialog)) {
                frame.fill(app.layout.dialog, app.theme.normal)
                frame.renderWidget(app.demoResetDialog, app.layout.dialog)
            }
        case _ => ()
    }
}

func renderEditor(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (app.interaction.active() == Some("editor")) {
        match (app.interaction.focus().current()) {
            case Some("editor-name") => frame.setCursor(app.editorName.cursorPosition(layout.editorName, options: frame.textWidthOptions()))
            case Some("editor-notes") => frame.setCursor(app.editorNotes.cursorPosition(layout.editorNotes, options: frame.textWidthOptions()))
            case _ => ()
        }
    }
    if (!frame.isDirty(layout.editor)) { return }
    frame.fill(layout.editor, app.theme.normal)
    frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded), layout.editor)
    let inner = Block(title: "").inner(layout.editor)
    frame.renderWidget(Paragraph(if (app.editorCreating) { "NEW TASK  /  Simulated" } else { "EDIT TASK  /  Simulated" }, style: app.theme.normal.withModifier(Modifier.strong())),
        Rect(inner.x + 1, inner.y, max(0, inner.width - 2), 1))
    let nameMarker = if (app.interaction.focus().isFocused("editor-name")) { "> " }
        else if (app.hovered == Some("editor-name")) { "~ " } else { "" }
    frame.renderWidget(Paragraph(nameMarker + "Name", style: app.secondaryStyle),
        Rect(layout.editorName.x, layout.editorName.y - 2, layout.editorName.width, 1))
    let nameFrame = Rect(layout.editorName.x - 1, layout.editorName.y - 1, layout.editorName.width + 2, 3)
    frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded,
        focused: app.interaction.focus().isFocused("editor-name")), nameFrame)
    app.editorName.setVisualState(focused: app.interaction.focus().isFocused("editor-name"),
        error: !app.editorError.isEmpty(), theme: Some(app.theme))
    frame.renderWidget(app.editorName, layout.editorName)
    let priorityMarker = if (app.interaction.focus().isFocused("editor-priority")) { "> " }
        else if (app.hovered == Some("editor-priority")) { "~ " } else { "" }
    frame.renderWidget(Paragraph(priorityMarker + "Priority", style: app.secondaryStyle), Rect(layout.editorPriority.x, layout.editorPriority.y, layout.editorPriority.width, 1))
    frame.renderWidget(app.editorPrioritySelect, Rect(layout.editorPriority.x, layout.editorPriority.y + min(1, layout.editorPriority.height), layout.editorPriority.width, max(0, layout.editorPriority.height - 1)))
    let notifyMarker = if (app.interaction.focus().isFocused("editor-notify")) { "> " }
        else if (app.hovered == Some("editor-notify")) { "~ " } else { "" }
    frame.renderWidget(Checkbox(notifyMarker + "Notify on completion", checked: app.editorNotify.checked, focused: app.interaction.focus().isFocused("editor-notify"),
        style: app.theme.normal, focusedStyle: app.selectedStyle(), theme: Some(app.theme)), layout.editorNotify)
    let tagsMarker = if (app.interaction.focus().isFocused("editor-tags")) { "> " }
        else if (app.hovered == Some("editor-tags")) { "~ " } else { "" }
    frame.renderWidget(Paragraph(tagsMarker + "Tags", style: app.secondaryStyle),
        Rect(layout.editorTags.x, layout.editorTags.y - 1, layout.editorTags.width, 1))
    frame.renderWidget(app.editorTags, layout.editorTags)
    let notesMarker = if (app.interaction.focus().isFocused("editor-notes")) { "> " }
        else if (app.hovered == Some("editor-notes")) { "~ " } else { "" }
    frame.renderWidget(Paragraph(notesMarker + "Notes", style: app.secondaryStyle),
        Rect(layout.editorNotes.x, layout.editorNotes.y - 2, layout.editorNotes.width, 1))
    let notesFrame = Rect(layout.editorNotes.x - 1, layout.editorNotes.y - 1,
        layout.editorNotes.width + 2, layout.editorNotes.height + 2)
    frame.renderWidget(galleryBlock(app, "", BorderKind.Rounded,
        focused: app.interaction.focus().isFocused("editor-notes")), notesFrame)
    frame.renderWidget(app.editorNotes, layout.editorNotes)
    let cancelMarker = if (app.interaction.focus().isFocused("editor-cancel")) { "> " }
        else if (app.hovered == Some("editor-cancel")) { "~ " } else { "" }
    let saveMarker = if (app.interaction.focus().isFocused("editor-save")) { "> " }
        else if (app.hovered == Some("editor-save")) { "~ " } else { "" }
    frame.renderWidget(Button(cancelMarker + "Cancel", focused: app.interaction.focus().isFocused("editor-cancel"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.editorCancel)
    frame.renderWidget(Button(saveMarker + "Save", focused: app.interaction.focus().isFocused("editor-save"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.editorSave)
    if (!app.editorError.isEmpty()) {
        let errorArea = Rect(layout.editorName.x, layout.editorName.y + 2, layout.editorName.width, 1)
        frame.renderWidget(Paragraph(app.editorError, style: app.theme.error), errorArea)
    }
}

func workbenchActivityStatus(status: WorkbenchJobStatus): TaskStatus {
    match (status) {
        case WorkbenchJobStatus.Queued => TaskStatus.Queued
        case WorkbenchJobStatus.Running => TaskStatus.Running
        case WorkbenchJobStatus.Paused => TaskStatus.Paused
        case WorkbenchJobStatus.Cancelled => TaskStatus.Cancelled
        case WorkbenchJobStatus.Failed => TaskStatus.Failed
        case WorkbenchJobStatus.Done => TaskStatus.Done
    }
}

func statusLabel(status: WorkbenchJobStatus): String {
    match (status) {
        case WorkbenchJobStatus.Queued => "Queued"
        case WorkbenchJobStatus.Running => "Running"
        case WorkbenchJobStatus.Paused => "Paused"
        case WorkbenchJobStatus.Cancelled => "Cancelled"
        case WorkbenchJobStatus.Failed => "Failed"
        case WorkbenchJobStatus.Done => "Done"
    }
}

func formatPercent(value: Int64): String {
    let bounded = min(10000, max(0, value))
    let whole = bounded / 100
    let fraction = bounded % 100
    "${whole}.${if (fraction < 10) { "0" } else { "" }}${fraction}%"
}
func joinText(values: Array<String>, separator: String): String {
    var result = ""
    for (index in 0..values.size) {
        if (index > 0) { result += separator }
        result += values[index]
    }
    result
}
