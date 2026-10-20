package cjtui_workbench

import core.*
import cjtui_testing.*
import cjtui_testing.TestReport as WorkbenchTestReport

func runWorkbenchHeadlessSmoke(): Int64 {
    let app = WorkbenchApp()
    let showcase = TestScenario().render().run(
        { frame => app.render(frame) },
        { event => app.update(event) },
        width: 140,
        height: 42
    )
    if (!showcase.passed ||
        !showcase.lastSnapshot().contains("Overview  /  Graphite + Cyan") ||
        !showcase.lastSnapshot().contains("Forms") ||
        !showcase.lastSnapshot().contains("Navigation") ||
        !showcase.lastSnapshot().contains("Data") ||
        !showcase.lastSnapshot().contains("Toast") ||
        !showcase.lastSnapshot().contains("Dialog") ||
        !showcase.lastSnapshot().contains("Terminal-native")) {
        return workbenchSmokeFailure("component gallery")
    }
    let forms = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Right))
        .key(KeyEvent(KeyCode.Right))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!forms.passed || app.galleryTabs.selected != 2 || app.toastManager.count() != 1 ||
        !forms.lastSnapshot().contains("Editable control states") ||
        !forms.lastSnapshot().contains("Disabled")) {
        return workbenchSmokeFailure("gallery navigation and button interaction")
    }

    let formsPaste = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .paste("q界")
        .render())
    if (!formsPaste.passed || app.galleryInput.value != "q界" ||
        app.galleryInput.cursor != "q界".size ||
        !formsPaste.lastSnapshot().contains("q界") ||
        !formsPaste.lastSnapshot().contains("Ready") ||
        !formsPaste.lastSnapshot().contains("Read only")) {
        return workbenchSmokeFailure("Forms live input paste")
    }

    let formsSwitch = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Char(r' ')))
        .render())
    if (!formsSwitch.passed || !app.gallerySwitch.checked ||
        !formsSwitch.lastSnapshot().contains("Auto sync [on]") ||
        !formsSwitch.lastSnapshot().contains("Auto sync: on")) {
        return workbenchSmokeFailure("Forms Switch value")
    }
    let navigation = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, app.layout.galleryNav.x + 26, app.layout.galleryNav.y)))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Right))
        .render())
    if (!navigation.passed || app.galleryTabs.selected != 3 ||
        app.galleryNavigationSegments.selectedValue() != Some("Comfortable") ||
        !navigation.lastSnapshot().contains("Preview density: Comfortable")) {
        return workbenchSmokeFailure("Navigation SegmentedControl keyboard value")
    }
    let navigationAreas = workbenchGalleryAreas(app.layout.galleryContent, 3)
    let separator = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, navigationAreas.navSegments.x + 9, navigationAreas.navSegments.y)))
        .render())
    if (!separator.passed || app.galleryNavigationSegments.selected != 2 ||
        !separator.lastSnapshot().contains("Preview density: Comfortable")) {
        return workbenchSmokeFailure("Navigation SegmentedControl separator")
    }
    let navigationMouse = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, navigationAreas.navSegments.x + 1, navigationAreas.navSegments.y)))
        .render())
    if (!navigationMouse.passed || app.galleryNavigationSegments.selectedValue() != Some("Compact") ||
        !navigationMouse.lastSnapshot().contains("Preview density: Compact")) {
        return workbenchSmokeFailure("Navigation SegmentedControl mouse value")
    }
    let overview = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(3)))
        .render())
    if (!overview.passed || app.page != WorkbenchPage.Overview ||
        !overview.lastSnapshot().contains("Status distribution") ||
        !overview.lastSnapshot().contains("Progress history")) {
        return workbenchSmokeFailure("overview rendering")
    }

    let tasks = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(3)))
        .key(KeyEvent(KeyCode.Down))
        .key(KeyEvent(KeyCode.F(5)))
        .event(Event.Tick(TickEvent(deltaMillis: 1000)))
        .render())
    if (!tasks.passed || app.page != WorkbenchPage.Tasks || app.selectedId != Some(2) ||
        !tasks.lastSnapshot().contains("Task 2")) {
        return workbenchSmokeFailure("task start and progress")
    }
    match (app.model.job(2)) {
        case Some(task) => if (task.status != WorkbenchJobStatus.Running || task.progressPercent == 0) {
            return workbenchSmokeFailure("running task state")
        }
        case None => return workbenchSmokeFailure("task 2 missing")
    }

    let search = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Char(r'/')))
        .paste("Task 2")
        .render())
    if (!search.passed) { return workbenchSmokeFailure("search scenario") }
    if (app.taskSearch.value != "Task 2") {
        return workbenchSmokeFailure("search text: " + app.taskSearch.value)
    }
    let searchResults = app.model.visibleIds()
    if (searchResults.size != 11 || searchResults[0] != 2) {
        return workbenchSmokeFailure("search count: ${searchResults.size}")
    }

    let filterArea = app.layout.taskFilter
    let filter = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y)))
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y + 3)))
        .render())
    if (!filter.passed || app.taskFilter.selected != 2 || app.model.visibleIds().size != 1) {
        return workbenchSmokeFailure("status filtering")
    }

    let tree = app.layout.projectTree
    let project = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, tree.x + 3, tree.y + 2)))
        .render())
    if (!project.passed || app.projectFilter != Some("Alpha") || app.model.visibleIds().size != 0) {
        return workbenchSmokeFailure("project filtering")
    }

    let clearSearch = TestScenario().key(KeyEvent(KeyCode.Char(r'/'))).key(KeyEvent(KeyCode.Home))
    for (_ in 0..6) { _ = clearSearch.key(KeyEvent(KeyCode.Delete)) }
    let cleared = runWorkbenchScenario(app, clearSearch.render())
    if (!cleared.passed || app.taskSearch.value != "" || app.model.visibleIds().size != 1 ||
        app.selectedId != Some(1)) {
        return workbenchSmokeFailure("search clearing")
    }

    let allFilterArea = app.layout.taskFilter
    let allFilter = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, allFilterArea.x + 1, allFilterArea.y)))
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, allFilterArea.x + 1, allFilterArea.y + 1)))
        .render())
    if (!allFilter.passed || app.taskFilter.selected != 0 || app.model.visibleIds().size != 40) {
        return workbenchSmokeFailure("project task list")
    }

    let taskTable = app.layout.taskTable
    let startTask = runWorkbenchScenario(app, TestScenario()
        .event(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, taskTable.x + 2, taskTable.y + 3)))
        .key(KeyEvent(KeyCode.F(5)))
        .event(Event.Tick(TickEvent(deltaMillis: 300)))
        .render())
    if (!startTask.passed) { return workbenchSmokeFailure("project task scenario") }
    match (app.selectedId) {
        case Some(4) => ()
        case Some(id) => return workbenchSmokeFailure("selected job-${id}")
        case None => return workbenchSmokeFailure("no project task selected")
    }

    let editor = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(4)))
        .paste(" details")
        .key(KeyEvent(KeyCode.F(1)))
        .key(KeyEvent(KeyCode.Esc))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!editor.passed || app.interaction.active().isSome()) {
        return workbenchSmokeFailure("editor and nested help")
    }
    match (app.model.job(4)) {
        case Some(task) => if (task.name != "Task 4 details") {
            return workbenchSmokeFailure("edited task metadata")
        }
        case None => return workbenchSmokeFailure("task 4 missing")
    }

    let paletteReturnFocus = app.focus.current()
    let emptyPalette = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(2)))
        .paste("NO-SUCH-COMMAND")
        .render())
    if (!emptyPalette.passed || app.interaction.active() != Some("palette") ||
        !emptyPalette.lastSnapshot().contains("No matches")) {
        return workbenchSmokeFailure("palette no-match state")
    }
    let escapePalette = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Esc))
        .render())
    if (!escapePalette.passed || app.interaction.active().isSome() ||
        app.focus.current() != paletteReturnFocus) {
        return workbenchSmokeFailure("palette Escape and focus restoration")
    }
    let openReset = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(2)))
        .paste("RESET SELECTED TASK")
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!openReset.passed || app.interaction.active() != Some("reset-confirm")) {
        return workbenchSmokeFailure("command palette reset")
    }
    let confirmReset = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Right))
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!confirmReset.passed || app.interaction.active().isSome()) {
        return workbenchSmokeFailure("task reset confirmation")
    }

    match (app.model.job(4)) {
        case Some(task) => if (task.status != WorkbenchJobStatus.Queued || task.progressPercent != 0) {
            return workbenchSmokeFailure("reset task state")
        }
        case None => return workbenchSmokeFailure("task 4 missing")
    }

    let settings = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.F(3)))
        .key(KeyEvent(KeyCode.Down))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Right))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Char(r' ')))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Down))
        .key(KeyEvent(KeyCode.Enter))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Enter))
        .key(KeyEvent(KeyCode.Tab))
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!settings.passed) { return workbenchSmokeFailure("settings scenario") }
    if (app.interaction.active() != Some("demo-confirm")) {
        return workbenchSmokeFailure("settings reset dialog")
    }
    if (app.darkTheme) { return workbenchSmokeFailure("theme setting") }
    if (app.motionEnabled) { return workbenchSmokeFailure("motion setting") }
    if (app.speedSelect.selected != 2) { return workbenchSmokeFailure("speed setting") }
    if (!app.paused) { return workbenchSmokeFailure("pause setting") }
    let final = runWorkbenchScenario(app, TestScenario()
        .key(KeyEvent(KeyCode.Right))
        .key(KeyEvent(KeyCode.Enter))
        .render())
    if (!final.passed || app.page != WorkbenchPage.Overview || app.paused || app.model.jobs.size != 120 ||
        app.model.runningCount != 1 || app.darkTheme || app.motionEnabled || app.speedSelect.selected != 2 ||
        !final.lastSnapshot().contains("Termcanvas Workbench") ||
        !final.lastSnapshot().contains("Status distribution") ||
        !final.lastSnapshot().contains("Local demo initialized: 120 tasks")) {
        return workbenchSmokeFailure("demo reset and final overview")
    }

    println("workbench headless smoke ok")
    0
}

func runWorkbenchScenario(app: WorkbenchApp, scenario: TestScenario): WorkbenchTestReport {
    scenario.run(
        { frame => app.render(frame) },
        { event => app.update(event) },
        width: 120,
        height: 36
    )
}

func workbenchSmokeFailure(stage: String): Int64 {
    println("workbench headless smoke failed: " + stage)
    1
}
