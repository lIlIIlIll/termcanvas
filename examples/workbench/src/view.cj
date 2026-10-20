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
    var sparkText: Rect = Rect(0, 0, 0, 0)
    var sparkLine: Rect = Rect(0, 0, 0, 0)
    var pipelinePanel: Rect = Rect(0, 0, 0, 0)
    var pipelineCanvas: Rect = Rect(0, 0, 0, 0)
    var logPanel: Rect = Rect(0, 0, 0, 0)
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
        let columns = galleryColumns(area, 5, 2, 2)
        out.formLabels = [
            galleryRect(area, 0, 5, columns[0].width, 1),
            galleryRect(area, columns[1].x - area.x, 5, columns[1].width, 1),
            galleryRect(area, 0, 9, columns[0].width, 1),
            galleryRect(area, columns[1].x - area.x, 9, columns[1].width, 1)
        ]
        out.formInputs = [
            galleryRect(area, 0, 6, columns[0].width, 2),
            galleryRect(area, columns[1].x - area.x, 6, columns[1].width, 2),
            galleryRect(area, 0, 10, columns[0].width, 2),
            galleryRect(area, columns[1].x - area.x, 10, columns[1].width, 2)
        ]
        out.checkbox = galleryRect(area, 0, 13, columns[0].width, 1)
        out.select = galleryRect(area, columns[1].x - area.x, 13, columns[1].width, 4)
        out.switchControl = galleryRect(area, 0, 15, columns[0].width, 1)
        out.switchValue = galleryRect(area, 0, 16, columns[0].width, 1)
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

func workbenchLayout(area: Rect, page: WorkbenchPage): WorkbenchLayout {
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

    var content = out.body
    if (out.complete && (page == WorkbenchPage.Overview || page == WorkbenchPage.Tasks)) {
        out.projectTree = Rect(out.body.x, out.body.y, min(18, out.body.width), out.body.height)
        content = Rect(out.body.x + min(out.body.width, 19), out.body.y, max(0, out.body.width - 19), out.body.height)
    }

    if (page == WorkbenchPage.Overview) {
        out.overviewArea = content
        let topHeight = min(if (out.complete) { 6 } else { 4 }, content.height)
        out.overviewTop = Rect(content.x, content.y, content.width, topHeight)
        let gap = if (content.height > topHeight) { 1 } else { 0 }
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
        let middleHeight = min(if (out.complete) { 9 } else { 7 }, max(0, content.bottom - middleY))
        out.overviewMiddle = Rect(content.x, middleY, content.width, middleHeight)
        let middleGap = if (content.width > 1) { 1 } else { 0 }
        let halfWidth = max(0, (content.width - middleGap) / 2)
        out.chartPanel = Rect(content.x, middleY, halfWidth, middleHeight)
        out.sparkPanel = Rect(content.x + halfWidth + middleGap, middleY, max(0, content.right - (content.x + halfWidth + middleGap)), min(if (out.complete) { 4 } else { 3 }, middleHeight))
        let pipelineOffset = if (out.complete) { 5 } else { 4 }
        out.pipelinePanel = Rect(out.sparkPanel.x, middleY + min(middleHeight, pipelineOffset), out.sparkPanel.width, max(0, middleHeight - pipelineOffset))
        let chartBlock = Block(title: "Status distribution")
        let chartInner = chartBlock.inner(out.chartPanel)
        out.chartLegend = Rect(chartInner.x, chartInner.y, chartInner.width, min(1, chartInner.height))
        let chartWidth = if (out.complete) { min(10, chartInner.width) } else { chartInner.width }
        out.chartPlot = Rect(chartInner.x, chartInner.y + 1, chartWidth, max(0, chartInner.height - 1))
        if (out.complete) {
            let metersX = out.chartPlot.right + min(2, max(0, chartInner.right - out.chartPlot.right))
            out.chartMeters = Rect(metersX, out.chartPlot.y, max(0, chartInner.right - metersX), out.chartPlot.height)
        }
        let sparkBlock = Block(title: "Progress history")
        let sparkInner = sparkBlock.inner(out.sparkPanel)
        out.sparkText = Rect(sparkInner.x, sparkInner.y, sparkInner.width, min(1, sparkInner.height))
        out.sparkLine = Rect(sparkInner.x, sparkInner.y + 1, sparkInner.width, max(0, sparkInner.height - 1))
        let pipeBlock = Block(title: "Pipeline")
        out.pipelineCanvas = pipeBlock.inner(out.pipelinePanel)
        let logsY = middleY + middleHeight + if (content.bottom > middleY + middleHeight) { 1 } else { 0 }
        let bottomHeight = max(0, content.bottom - logsY)
        out.overviewBottom = Rect(content.x, logsY, content.width, bottomHeight)
        let bottomGap = if (out.complete && content.width > 60) { 1 } else { 0 }
        let activityWidth = if (bottomGap > 0) { (content.width - bottomGap) * 3 / 5 } else { content.width }
        out.logPanel = Rect(content.x, logsY, activityWidth, bottomHeight)
        if (bottomGap > 0) {
            out.queuePanel = Rect(out.logPanel.right + bottomGap, logsY, max(0, content.right - (out.logPanel.right + bottomGap)), bottomHeight)
        }
        out.logScrollbar = Rect(out.logPanel.right - min(1, out.logPanel.width), out.logPanel.y, min(1, out.logPanel.width), out.logPanel.height)
        out.logView = Rect(out.logPanel.x, out.logPanel.y, max(0, out.logPanel.width - 1), out.logPanel.height)
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
        out.taskScrollbar = Rect(tableInner.right - min(1, tableInner.width), tableInner.y, min(1, tableInner.width), tableInner.height)
        out.taskTable = Rect(tableInner.x, tableInner.y, max(0, tableInner.width - 1), tableInner.height)
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

    let editorWidth = min(88, max(0, area.width - 4))
    let editorHeight = min(22, max(0, area.height - 2))
    out.editor = centered(area, editorWidth, editorHeight)
    let editInner = Block(title: "Edit local demo task").inner(out.editor)
    out.editorName = Rect(editInner.x, editInner.y, editInner.width, min(3, editInner.height))
    let formY = editInner.y + min(4, editInner.height)
    let formHeight = min(14, max(0, editInner.bottom - formY - 2))
    let leftWidth = max(0, (editInner.width - 1) / 2)
    out.editorPriority = Rect(editInner.x, formY, leftWidth, min(3, formHeight))
    out.editorNotify = Rect(editInner.x, formY + min(4, formHeight), leftWidth, min(2, max(0, formHeight - 4)))
    out.editorTags = Rect(editInner.x, formY + min(7, formHeight), leftWidth, max(0, formHeight - min(7, formHeight)))
    out.editorNotes = Rect(editInner.x + leftWidth + min(1, editInner.width), formY, max(0, editInner.right - (editInner.x + leftWidth + 1)), formHeight)
    let buttonsY = max(editInner.y, editInner.bottom - 1)
    out.editorCancel = Rect(max(editInner.x, editInner.right - 26), buttonsY, min(12, editInner.width), min(1, editInner.height))
    out.editorSave = Rect(max(editInner.x, editInner.right - 12), buttonsY, min(12, editInner.width), min(1, editInner.height))
    let paletteWidth = min(70, max(0, area.width - 4))
    let paletteHeight = min(18, max(0, area.height - 2))
    out.palette = centered(area, paletteWidth, paletteHeight)
    out.dialog = centered(area, min(64, max(0, area.width - 4)), min(12, max(0, area.height - 2)))
    out
}


func centered(area: Rect, width: Int64, height: Int64): Rect {
    let actualWidth = min(max(0, width), area.width)
    let actualHeight = min(max(0, height), area.height)
    Rect(area.x + max(0, (area.width - actualWidth) / 2), area.y + max(0, (area.height - actualHeight) / 2), actualWidth, actualHeight)
}

func renderWorkbench(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
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
        let spinnerArea = Rect(max(layout.title.x, layout.title.right - 20), layout.title.y, min(20, layout.title.width), layout.title.height)
        frame.renderWidget(Spinner(label: "LOCAL DEMO", frame: app.spinnerFrame, style: app.theme.accent), spinnerArea)
    }
    if (frame.isDirty(layout.tabs)) {
        let pageTabs = Tabs(["Gallery", "Overview", "Tasks", "Settings"], selected: app.tabs.selected,
            selectedStyle: Style.default())
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
        let counts = "Q ${app.model.queuedCount}  R ${app.model.runningCount}  D ${app.model.doneCount}"
        let state = if (app.paused) { "PAUSED" } else { "RUNNING" }
        let right = if (layout.status.width < 100) { "Tab focus  F1 help  F2 cmds  Ctrl-C exit" }
            else { "LOCAL DEMO  ${state}  F1 help  F2 palette  F3 page  Tab focus  Ctrl-C exit" }
        frame.renderWidget(StatusBar(left: counts + "  " + app.statusMessage, right: right,
            style: app.secondaryStyle), layout.status)
    }
    let localGalleryToast = app.page == WorkbenchPage.Showcase && app.galleryTabs.selected == 5
    if (app.toastManager.count() > 0 && !localGalleryToast && frame.isDirty(layout.toast)) {
        frame.fill(layout.toast, app.theme.normal)
        frame.renderWidget(app.toastManager, layout.toast)
    }
    renderModal(app, frame)
}

func renderOverview(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (layout.projectTree.width > 0 && frame.isDirty(layout.projectTree)) {
        frame.fill(layout.projectTree, app.theme.normal)
        frame.renderWidget(app.projects, layout.projectTree)
    }
    if (frame.isDirty(layout.overviewTop)) {
        frame.fill(layout.overviewTop, app.theme.normal)
        let counts = [app.model.runningCount, app.model.queuedCount, app.model.doneCount]
        if (layout.complete) {
            let titles = ["RUNNING", "QUEUED", "COMPLETED"]
            let summaries = ["Active slots", "Ready to start", "Finished this run"]
            let details = ["concurrent jobs", "tasks waiting", "local tasks finished"]
            let styles = [app.theme.info, app.theme.warning, app.theme.success]
            for (i in 0..3) {
                let area = layout.metricCards[i]
                let card = galleryBlock(app, titles[i], BorderKind.Rounded)
                let value = if (i == 0) { "${counts[i]} / 4" } else { counts[i].toString() }
                let trend = if (i == 0) { if (app.paused) { "PAUSED" } else { "SIMULATION LIVE" } }
                    else if (i == 1) { "LOCAL QUEUE" } else { "LOCAL ONLY" }
                frame.renderWidget(card, area)
                frame.renderWidget(MetricCard(summaries[i], value, detail: details[i], trend: trend,
                    style: app.theme.normal, valueStyle: styles[i].withModifier(Modifier.strong())), card.inner(area))
            }
            let area = layout.metricCards[3]
            let card = galleryBlock(app, "TOTAL PROGRESS", BorderKind.Rounded)
            let inner = card.inner(area)
            let progress = app.model.totalProgressHundredths()
            frame.renderWidget(card, area)
            frame.renderWidget(MetricCard("Weighted average", formatPercent(progress),
                detail: "Across all 120 tasks", style: app.theme.normal,
                valueStyle: app.theme.info.withModifier(Modifier.strong())),
                Rect(inner.x, inner.y, inner.width, min(3, inner.height)))
            if (inner.height > 3) {
                frame.renderWidget(Gauge(progress, total: 10000, label: formatPercent(progress),
                    style: app.theme.normal, fillStyle: app.theme.accent),
                    Rect(inner.x, inner.y + 3, inner.width, 1))
            }
        } else {
            let titles = ["RUNNING", "QUEUED", "COMPLETED"]
            for (i in 0..3) {
                frame.renderWidget(MetricCard(titles[i], counts[i].toString(), detail: "Local demo tasks",
                    style: app.theme.normal, valueStyle: app.theme.accent), layout.metricCards[i])
            }
            let progress = app.model.totalProgressHundredths()
            frame.renderWidget(Gauge(progress, total: 10000, label: formatPercent(progress),
                style: app.theme.normal, fillStyle: app.theme.accent), layout.metricCards[3])
        }
    }
    if (frame.isDirty(layout.chartPanel)) {
        frame.fill(layout.chartPanel, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "Status distribution", BorderKind.Rounded), layout.chartPanel)
        frame.renderWidget(Legend([
            LegendItem("Queued", symbol: "o", style: app.theme.warning),
            LegendItem("Running", symbol: "o", style: app.theme.info),
            LegendItem("Done", symbol: "o", style: app.theme.success)
        ], gap: "  "), layout.chartLegend)
        frame.renderWidget(Chart([app.model.queuedCount, app.model.runningCount, app.model.doneCount],
            style: app.theme.accent), layout.chartPlot)
        if (layout.chartMeters.width > 0 && layout.chartMeters.height >= 5) {
            let meters = layout.chartMeters
            frame.renderWidget(Meter("Queued ${app.model.queuedCount}", app.model.queuedCount,
                total: 120, style: app.theme.warning, fillStyle: app.theme.warning),
                Rect(meters.x, meters.y, meters.width, 1))
            frame.renderWidget(Meter("Running ${app.model.runningCount}", app.model.runningCount,
                total: 120, style: app.theme.info, fillStyle: app.theme.info),
                Rect(meters.x, meters.y + 2, meters.width, 1))
            frame.renderWidget(Meter("Done ${app.model.doneCount}", app.model.doneCount,
                total: 120, style: app.theme.success, fillStyle: app.theme.success),
                Rect(meters.x, meters.y + 4, meters.width, 1))
        }
    }
    if (frame.isDirty(layout.sparkPanel)) {
        frame.fill(layout.sparkPanel, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "Progress history", BorderKind.Rounded), layout.sparkPanel)
        let progress = app.model.totalProgressHundredths()
        frame.renderWidget(Paragraph("Total ${formatPercent(progress)} | recent peak", style: app.theme.normal), layout.sparkText)
        frame.renderWidget(Sparkline(app.model.history(), style: app.theme.accent), layout.sparkLine)
    }
    if (frame.isDirty(layout.pipelinePanel)) {
        frame.fill(layout.pipelinePanel, app.theme.normal)
        frame.renderWidget(galleryBlock(app, "Task pipeline", BorderKind.Rounded), layout.pipelinePanel)
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
            let span = max(1, min(layout.pipelineCanvas.width, displayWidth(text)))
            let x = layout.pipelineCanvas.x + app.pipelineOffset % span
            canvas.drawText(x, layout.pipelineCanvas.y + 1, "o", app.theme.accent)
        }
    }
    if (frame.isDirty(layout.overviewBottom)) {
        frame.fill(layout.overviewBottom, app.theme.normal)
        let lines = app.model.logs()
        let viewport = max(0, layout.logView.height - 2)
        let total = lines.size
        app.logScroll.offset = max(0, min(app.logScroll.offset, max(0, total - viewport)))
        frame.renderWidget(LogView(lines, offset: app.logScroll.offset,
            block: Some(galleryBlock(app, "Activity log", BorderKind.Rounded)), style: app.theme.normal), layout.logView)
        frame.renderWidget(Scrollbar(total, offset: app.logScroll.offset, viewport: viewport,
            style: app.theme.disabled, thumbStyle: app.theme.accent), layout.logScrollbar)
        renderQueuePreview(app, frame)
    }
}

func renderQueuePreview(app: WorkbenchApp, frame: Frame): Unit {
    let area = app.layout.queuePanel
    if (area.width <= 0 || area.height <= 0) { return }
    let block = galleryBlock(app, "Ready queue", BorderKind.Rounded)
    frame.renderWidget(block, area)
    let inner = block.inner(area)
    let rows = app.model.queuePreviewRows()
    if (rows.isEmpty()) {
        frame.renderWidget(Paragraph("Queue is clear", style: app.theme.success), inner)
        return
    }
    frame.renderWidget(Table(["ID", "TASK", "PROJECT", "PRIORITY"], rows,
        widths: [8, 10, 8, 8], style: app.theme.normal, headerStyle: app.theme.accent), inner)
}

func renderTasks(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (layout.projectTree.width > 0 && frame.isDirty(layout.projectTree)) {
        frame.fill(layout.projectTree, app.theme.normal)
        frame.renderWidget(app.projects, layout.projectTree)
    }
    if (frame.isDirty(layout.taskQuery)) {
        frame.fill(layout.taskQuery, app.theme.normal)
        frame.renderWidget(app.taskSearch, layout.taskSearch)
    }
    if (frame.isDirty(layout.taskSearch) && app.focus.isFocused("task-search")) {
        frame.setCursor(app.taskSearch.cursorPosition(layout.taskSearch))
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
        let table = Table(["ID", "Name", "Project", "Status", "Progress"], app.model.visibleRows(),
            widths: app.layoutTableWidths(), state: Some(app.taskState), style: app.theme.normal,
            headerStyle: app.theme.accent, selectedStyle: app.selectedStyle())
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
                    let text = "${task.label()}\n${task.name}\n${task.project} / ${statusLabel(task.status)}\nPriority: ${task.priority}\nNotify: ${if (task.notify) { "yes" } else { "no" }}\nTags: ${joinText(task.tags, ", ")}\n${task.notes}"
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
    if (app.effectiveColorTier() > 0) {
        frame.renderWidget(app.accentPicker, area)
        return
    }

    var palette = ""
    for (i in 0..app.accentColors.size) {
        palette += workbenchAccentInitial(app.accentColors[i])
        palette += if (i == app.accentPicker.selected) { "*" } else { " " }
        palette += " "
    }
    frame.renderWidget(Paragraph(palette, style: app.theme.normal), area)
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
            if (app.editingId.isSome()) { renderEditor(app, frame) }
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
    if (!frame.isDirty(layout.editor)) { return }
    frame.fill(layout.editor, app.theme.normal)
    frame.renderWidget(galleryBlock(app, "Edit local demo task", BorderKind.Rounded), layout.editor)
    frame.renderWidget(app.editorName, layout.editorName)
    frame.renderWidget(Paragraph("Priority", style: app.theme.normal), Rect(layout.editorPriority.x, layout.editorPriority.y, layout.editorPriority.width, 1))
    frame.renderWidget(app.editorPrioritySelect, Rect(layout.editorPriority.x, layout.editorPriority.y + min(1, layout.editorPriority.height), layout.editorPriority.width, max(0, layout.editorPriority.height - 1)))
    frame.renderWidget(Checkbox("Notify on completion", checked: app.editorNotify.checked, focused: app.interaction.focus().isFocused("editor-notify"),
        style: app.theme.normal, focusedStyle: app.selectedStyle(), theme: Some(app.theme)), layout.editorNotify)
    frame.renderWidget(app.editorTags, layout.editorTags)
    frame.renderWidget(app.editorNotes, layout.editorNotes)
    frame.renderWidget(Button("Cancel", focused: app.interaction.focus().isFocused("editor-cancel"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.editorCancel)
    frame.renderWidget(Button("Save", focused: app.interaction.focus().isFocused("editor-save"),
        style: app.theme.normal, focusedStyle: app.selectedStyle()), layout.editorSave)
    if (!app.editorError.isEmpty()) {
        let errorArea = Rect(layout.editorName.x, layout.editorName.y + max(0, layout.editorName.height - 1), layout.editorName.width, 1)
        frame.renderWidget(Paragraph(app.editorError, style: app.theme.error), errorArea)
    }
    match (app.interaction.focus().current()) {
        case Some("editor-name") => frame.setCursor(app.editorName.cursorPosition(layout.editorName))
        case Some("editor-notes") => frame.setCursor(app.editorNotes.cursorPosition(layout.editorNotes))
        case _ => ()
    }
}

func statusLabel(status: WorkbenchJobStatus): String {
    match (status) {
        case WorkbenchJobStatus.Queued => "Queued"
        case WorkbenchJobStatus.Running => "Running"
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
