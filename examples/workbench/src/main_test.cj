package cjtui_workbench

import core.*
import cjtui_testing.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class WorkbenchInteractionTest {
    @TestCase
    func shortcutsFocusAndActiveTaskLimit(): Unit {
        let app = WorkbenchApp()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(3))))
        @Expect(app.page, WorkbenchPage.Overview)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(3))))
        @Expect(app.page, WorkbenchPage.Tasks)
        @Expect(app.focus.current(), Some("task-table"))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.selectedId, Some(2))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        @Expect(app.model.runningCount, 2)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.selectedId, Some(5))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        @Expect(app.model.runningCount, 4)
        match (app.model.job(5)) {
            case Some(task) => @Expect(task.status, WorkbenchJobStatus.Queued)
            case None => @Expect(false)
        }

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(1))))
        @Expect(app.interaction.active(), Some("help"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(app.interaction.active().isNone())
        @Expect(app.focus.current(), Some("task-table"))
        let exitResult = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (exitResult.flow) {
            case ControlFlow.Exit => @Expect(true)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func mouseStatusFilterAndProjectTreeUpdateVisibleRows(): Unit {
        let app = WorkbenchApp()
        _ = app.perform("page.tasks")
        let filterArea = app.layout.taskFilter
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y)))
        @Expect(app.taskFilter.open)
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y + 4)))
        @Expect(!app.taskFilter.open)
        @Expect(app.taskFilter.selected, 3)
        @Expect(app.model.visibleIds().size, 0)
        @Expect(app.selectedId.isNone())

        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y)))
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, filterArea.x + 1, filterArea.y + 1)))
        @Expect(app.taskFilter.selected, 0)
        @Expect(app.model.visibleIds().size, 120)

        let tree = app.layout.projectTree
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, tree.x + 3, tree.y + 2)))
        @Expect(app.projectFilter, Some("Alpha"))
        @Expect(app.model.visibleIds().size, 40)
        let widths = app.layoutTableWidths()
        let nameHeaderX = app.layout.taskTable.x + widths[0] + 1
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, nameHeaderX, app.layout.taskTable.y)))
        @Expect(app.model.sortColumn, 1)
        @Expect(app.selectedId, Some(1))
    }

    @TestCase
    func editorHelpPasteValidationAndMetadataPreservation(): Unit {
        let app = WorkbenchApp()
        _ = app.model.advance(1200)
        _ = app.perform("page.tasks")
        _ = app.perform("task.edit")
        @Expect(app.interaction.active(), Some("editor"))
        _ = app.update(Event.Paste(" revised"))
        @Expect(app.editorName.value, "Task 1 revised")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(1))))
        @Expect(app.interaction.active(), Some("help"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(app.interaction.active(), Some("editor"))

        app.editorName.setValue("   ")
        for (_ in 0..6) { _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab))) }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.interaction.active(), Some("editor"))
        @Expect(app.editorError, "Name cannot be empty")
        @Expect(app.interaction.focus().current(), Some("editor-name"))

        app.editorName.setValue("Preserved task")
        for (_ in 0..6) { _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab))) }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.interaction.active().isNone())
        match (app.model.job(1)) {
            case Some(task) =>
                @Expect(task.name, "Preserved task")
                @Expect(task.status, WorkbenchJobStatus.Running)
                @Expect(task.progressPercent, 20)
            case None => @Expect(false)
        }
    }

    @TestCase
    func taskResetAndDemoResetKeepOnlyIntendedState(): Unit {
        let app = WorkbenchApp()
        _ = app.model.advance(2000)
        _ = app.perform("task.reset")
        @Expect(app.interaction.active(), Some("reset-confirm"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.interaction.active().isNone())
        match (app.model.job(1)) {
            case Some(task) =>
                @Expect(task.status, WorkbenchJobStatus.Queued)
                @Expect(task.progressPercent, 0)
            case None => @Expect(false)
        }

        app.themeRadio.selected = 1
        app.darkTheme = false
        app.motionEnabled = false
        app.motionToggle.checked = false
        app.speedSelect.selected = 2
        app.paused = true
        _ = app.perform("page.tasks")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.Paste("Task 9"))
        @Expect(app.model.visibleIds().size > 0)
        _ = app.perform("demo.reset")
        @Expect(app.interaction.active(), Some("demo-confirm"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.interaction.active().isNone())
        @Expect(app.page, WorkbenchPage.Overview)
        @Expect(app.paused, false)
        @Expect(app.motionEnabled, false)
        @Expect(app.darkTheme, false)
        @Expect(app.themeRadio.selected, 1)
        @Expect(app.speedSelect.selected, 2)
        @Expect(app.taskSearch.value, "")
        @Expect(app.taskFilter.selected, 0)
        @Expect(app.model.jobs.size, 120)
        @Expect(app.model.queuedCount, 119)
        @Expect(app.model.runningCount, 1)
        @Expect(app.model.doneCount, 0)
        @Expect(app.model.visibleIds().size, 120)
    }

    @TestCase
    func simulationPauseAndSpeedControlChangeElapsedProgress(): Unit {
        let app = WorkbenchApp()
        _ = app.perform("page.settings")
        for (_ in 0..3) { _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab))) }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.End)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 1000)))
        match (app.model.job(1)) {
            case Some(task) => @Expect(task.progressPercent, 33)
            case None => @Expect(false)
        }
        _ = app.perform("simulation.pause")
        let progress = match (app.model.job(1)) { case Some(task) => task.progressPercent; case None => -1 }
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 1000)))
        match (app.model.job(1)) {
            case Some(task) => @Expect(task.progressPercent, progress)
            case None => @Expect(false)
        }
    }
}

@Test
class WorkbenchMotionRenderingTest {
    @TestCase
    func longTicksRetainIntermediateSamplesAndDirtyOnlyVisibleOverview(): Unit {
        let app = WorkbenchApp()
        _ = app.perform("page.overview")
        let result = app.update(Event.Tick(TickEvent(deltaMillis: 5000)))
        @Expect(app.model.history().size, 21)
        @Expect(app.model.history()[1] < app.model.history()[2])
        @Expect(app.model.history()[19] < app.model.history()[20])
        match (result.dirtyRects) {
            case Some(rects) =>
                @Expect(rects.intersects(app.layout.overviewTop), true)
                @Expect(rects.intersects(app.layout.sparkPanel), true)
                @Expect(rects.intersects(app.layout.title), true)
                @Expect(rects.intersects(app.layout.chartPanel), false)
                @Expect(rects.intersects(app.layout.projectTree), false)
            case None => @Expect(false)
        }

        let settings = WorkbenchApp()
        _ = settings.perform("page.settings")
        let hidden = settings.update(Event.Tick(TickEvent(deltaMillis: 100)))
        match (settings.model.job(1)) {
            case Some(task) => @Expect(task.progressPercent, 1)
            case None => @Expect(false)
        }
        @Expect(hidden.renderRequested, false)
        @Expect(hidden.dirtyRects.isNone(), true)
        let spinner = settings.update(Event.Tick(TickEvent(deltaMillis: 20)))
        match (spinner.dirtyRects) {
            case Some(rects) =>
                @Expect(rects.intersects(settings.layout.title), true)
                @Expect(rects.intersects(settings.layout.settingsArea), false)
            case None => @Expect(false)
        }
    }

    @TestCase
    func galleryOverviewTickKeepsPartialAndFullFramesEqual(): Unit {
        let area = Rect(0, 0, 120, 36)
        let partialApp = WorkbenchApp()
        let fullApp = WorkbenchApp()
        let partialBackend = TestBackend(area: area, captureSnapshots: false)
        let fullBackend = TestBackend(area: area, captureSnapshots: false)
        let partial = Terminal(partialBackend, renderMode: RenderMode.Diff)
        let full = Terminal(fullBackend, renderMode: RenderMode.Full)
        _ = partial.draw { frame => partialApp.render(frame) }
        _ = full.draw { frame => fullApp.render(frame) }
        let progressBefore = partialApp.model.totalProgressHundredths()
        let partialResult = partialApp.update(Event.Tick(TickEvent(deltaMillis: 250)))
        let fullResult = fullApp.update(Event.Tick(TickEvent(deltaMillis: 250)))
        @Expect(partialApp.model.totalProgressHundredths() != progressBefore, true)
        let overview = workbenchGalleryAreas(partialApp.layout.galleryContent, 0)
        match (partialResult.dirtyRects) {
            case Some(rects) => @Expect(rects.intersects(overview.dataProgress), true)
            case None => @Expect(false)
        }
        _ = partial.draw({ frame => partialApp.render(frame) }, dirtyRects: partialResult.dirtyRects)
        _ = full.draw({ frame => fullApp.render(frame) }, dirtyRects: fullResult.dirtyRects)
        @Expect(partialBackend.lastBuffer().getOrThrow().diff(fullBackend.lastBuffer().getOrThrow()).size, 0)
    }


    @TestCase
    func completionToastGetsItsFullLifetimeAfterLongTick(): Unit {
        let app = WorkbenchApp()
        @Expect(app.model.advance(5000), true)
        let completion = app.update(Event.Tick(TickEvent(deltaMillis: 5000)))
        @Expect(app.model.doneCount, 1)
        @Expect(app.toastManager.count(), 1)
        match (completion.dirtyRects) {
            case Some(rects) => @Expect(rects.intersects(app.layout.toast), true)
            case None => @Expect(false)
        }

        _ = app.update(Event.Tick(TickEvent(deltaMillis: 2999)))
        @Expect(app.toastManager.count(), 1)
        let expiry = app.update(Event.Tick(TickEvent(deltaMillis: 1)))
        @Expect(app.toastManager.count(), 0)
        match (expiry.dirtyRects) {
            case Some(rects) => @Expect(rects.intersects(app.layout.toast), true)
            case None => @Expect(false)
        }
    }
}

func workbenchGalleryKey(app: WorkbenchApp, code: KeyCode): Unit {
    _ = app.update(Event.KeyDown(KeyEvent(code)))
}

func workbenchRectContained(outer: Rect, inner: Rect): Bool {
    inner.width <= 0 || inner.height <= 0 ||
        (inner.x >= outer.x && inner.y >= outer.y && inner.right <= outer.right && inner.bottom <= outer.bottom)
}

@Test
class WorkbenchGalleryInteractionTest {
    @TestCase
    func formsPreviewAndLiveInputReflectActualFocus(): Unit {
        let app = WorkbenchApp()
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Right)
        workbenchGalleryKey(app, KeyCode.Right)
        workbenchGalleryKey(app, KeyCode.Tab)
        @Expect(app.focus.current(), Some("gallery-button-primary"))

        let backend = TestBackend(area: app.screen, captureSnapshots: false)
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        let galleryAreas = workbenchGalleryAreas(app.layout.galleryContent, 2)
        let firstBuffer = backend.lastBuffer().getOrThrow()
        let inputArea = galleryAreas.formInputs[1]
        let previewStyle = firstBuffer.getCell(inputArea.x, inputArea.y).style
        @Expect(previewStyle == app.theme.disabled.withBg(app.theme.normal.bg), true)
        @Expect(firstBuffer.getCell(galleryAreas.formInputs[0].x, galleryAreas.formInputs[0].y).style ==
            app.theme.normal, true)
        @Expect(firstBuffer.getCell(galleryAreas.formInputs[2].x, galleryAreas.formInputs[2].y).style ==
            app.theme.error, true)
        @Expect(firstBuffer.getCell(galleryAreas.formInputs[3].x, galleryAreas.formInputs[3].y).style ==
            app.theme.disabled, true)
        @Expect(firstBuffer.getCell(galleryAreas.buttons[0].x, galleryAreas.buttons[0].y).style ==
            app.theme.focused, true)

        for (_ in 0..4) { workbenchGalleryKey(app, KeyCode.Tab) }
        @Expect(app.focus.current(), Some("gallery-input"))
        _ = terminal.draw { frame => app.render(frame) }
        let rendered = backend.lastBuffer().getOrThrow()
        let focusedStyle = rendered.getCell(inputArea.x, inputArea.y).style
        @Expect(focusedStyle == app.theme.disabled.withBg(app.theme.focused.bg), true)
        let buttonStyles = [
            app.accentButtonStyle,
            app.surfaceStyle,
            app.theme.normal,
            app.theme.error,
            app.theme.disabled
        ]
        for (index in 0..min(galleryAreas.buttons.size, buttonStyles.size)) {
            let area = galleryAreas.buttons[index]
            @Expect(rendered.getCell(area.x, area.y).style == buttonStyles[index], true)
        }
    }

    @TestCase
    func tabsThemeIsAppliedAcrossWorkbenchNavigation(): Unit {
        let app = WorkbenchApp()
        workbenchGalleryKey(app, KeyCode.Tab)
        @Expect(app.focus.current(), Some("gallery-tabs"))
        app.galleryTabs.selected = 3

        let backend = TestBackend(area: app.screen, captureSnapshots: false)
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        let navigationBuffer = backend.lastBuffer().getOrThrow()
        let categoryArea = app.layout.galleryNav
        let focusedCategory = navigationBuffer.getCell(categoryArea.x + 26, categoryArea.y).style
        let categorySelectedBase = app.theme.selected
        var categorySelectedModifier = categorySelectedBase.modifier
        categorySelectedModifier.bold = true
        categorySelectedModifier.underline = true
        let focusedCategoryStyle = categorySelectedBase.withModifier(categorySelectedModifier)
        @Expect(focusedCategory, focusedCategoryStyle)
        @Expect(focusedCategory.modifier.bold)
        @Expect(focusedCategory.modifier.underline)
        @Expect(navigationBuffer.getCell(categoryArea.x + 11, categoryArea.y).style, app.theme.normal)

        let navigationAreas = workbenchGalleryAreas(app.layout.galleryContent, 3)
        @Expect(navigationBuffer.getCell(navigationAreas.navTabs.x + 1, navigationAreas.navTabs.y).style,
            app.theme.selected)
        @Expect(navigationBuffer.getCell(navigationAreas.navTabs.x + 11, navigationAreas.navTabs.y).style,
            app.theme.normal)

        app.galleryTabs.selected = 4
        _ = terminal.draw { frame => app.render(frame) }
        let dataBuffer = backend.lastBuffer().getOrThrow()
        let dataAreas = workbenchGalleryAreas(app.layout.galleryContent, 4)
        @Expect(dataBuffer.getCell(dataAreas.dataSampleTabs.x + 1, dataAreas.dataSampleTabs.y).style,
            app.theme.selected)
        @Expect(dataBuffer.getCell(dataAreas.dataSampleTabs.x + 8, dataAreas.dataSampleTabs.y).style,
            app.theme.normal)
        let pageTabsArea = app.layout.tabs
        @Expect(dataBuffer.getCell(pageTabsArea.x + 1, pageTabsArea.y).style, app.theme.selected)
    }
    @TestCase
    func keyboardNavigationActivatesControlsAndKeepsInputEditableAfterFocusRestore(): Unit {
        let app = WorkbenchApp()
        workbenchGalleryKey(app, KeyCode.Tab)
        @Expect(app.focus.current(), Some("gallery-tabs"))
        workbenchGalleryKey(app, KeyCode.Right)
        workbenchGalleryKey(app, KeyCode.Right)
        @Expect(app.galleryTabs.selected, 2)
        workbenchGalleryKey(app, KeyCode.Tab)
        @Expect(app.focus.current(), Some("gallery-button-primary"))
        workbenchGalleryKey(app, KeyCode.Enter)
        @Expect(app.toastManager.count(), 1)

        let areas = workbenchGalleryAreas(app.layout.galleryContent, 2)
        let disabled = areas.buttons[4]
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, disabled.right - 1, disabled.y)))
        @Expect(app.toastManager.count(), 1)
        let primary = areas.buttons[0]
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, primary.right - 1, primary.y)))
        @Expect(app.toastManager.count(), 2)

        for (_ in 0..4) { workbenchGalleryKey(app, KeyCode.Tab) }
        @Expect(app.focus.current(), Some("gallery-input"))
        workbenchGalleryKey(app, KeyCode.Char(r'q'))
        _ = app.update(Event.Paste("界"))
        @Expect(app.galleryInput.value, "q界")
        _ = app.update(Event.FocusOut)
        @Expect(app.focus.current(), Some("gallery-input"))
        _ = app.update(Event.FocusIn)
        workbenchGalleryKey(app, KeyCode.Char(r'/'))
        @Expect(app.galleryInput.value, "q界/")

        let rendered = TestScenario().render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(rendered.passed, true)
        let inputArea = workbenchGalleryAreas(app.layout.galleryContent, 2).formInputs[1]
        let renderedBuffer = rendered.frames[rendered.frames.size - 1]
        @Expect(renderedBuffer.getCell(inputArea.x, inputArea.y).symbol, "q")
        @Expect(renderedBuffer.getCell(inputArea.x + 1, inputArea.y).symbol, "界")
        @Expect(renderedBuffer.getCell(inputArea.x + 3, inputArea.y).symbol, "/")
    }

    @TestCase
    func galleryCategoryAndCheckboxRespondToMouse(): Unit {
        let app = WorkbenchApp()
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, app.layout.galleryNav.x + 21, app.layout.galleryNav.y)))
        @Expect(app.galleryTabs.selected, 2)
        let areas = workbenchGalleryAreas(app.layout.galleryContent, 2)
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, areas.checkbox.x + 1, areas.checkbox.y)))
        @Expect(app.galleryCheckbox.checked, true)
        @Expect(app.focus.current(), Some("gallery-checkbox"))
    }

    @TestCase
    func dataGallerySupportsKeyboardAndMouseSelection(): Unit {
        let app = WorkbenchApp()
        workbenchGalleryKey(app, KeyCode.Tab)
        for (_ in 0..4) { workbenchGalleryKey(app, KeyCode.Right) }
        @Expect(app.galleryTabs.selected, 4)
        workbenchGalleryKey(app, KeyCode.Tab)
        @Expect(app.focus.current(), Some("gallery-data-sample-tabs"))
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Down)
        @Expect(app.galleryTableState.selectedRow, Some(1))
        for (_ in 0..12) { workbenchGalleryKey(app, KeyCode.Down) }
        @Expect(app.galleryTableState.selectedRow, Some(13))

        workbenchGalleryKey(app, KeyCode.BackTab)
        @Expect(app.focus.current(), Some("gallery-data-sample-tabs"))
        workbenchGalleryKey(app, KeyCode.Right)
        @Expect(app.galleryDataTabs.selected, 1)
        @Expect(app.galleryTableState.selectedRow, Some(13))
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Down)
        @Expect(app.galleryListState.selected, Some(1))

        let areas = workbenchGalleryAreas(app.layout.galleryContent, 4, sample: app.galleryDataTabs.selected)
        let listArea = galleryBlock(app, "List", BorderKind.Rounded).inner(areas.dataList)
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, listArea.x, listArea.y + 2)))
        @Expect(app.galleryListState.selected, Some(2))
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, listArea.x, listArea.y + 5)))
        @Expect(app.galleryListState.selected, Some(5))

        let backend = TestBackend(area: app.screen, captureSnapshots: false)
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        let selectedRow = backend.lastBuffer().getOrThrow().getCell(listArea.x, listArea.y + 5)
        @Expect(selectedRow.symbol, ">")
        @Expect(selectedRow.style == app.theme.selected, true)
        @Expect(backend.lastBuffer().getOrThrow().getCell(listArea.x + 2, listArea.y + 5).symbol, "B")
        for (_ in 0..14) { workbenchGalleryKey(app, KeyCode.Down) }
        @Expect(app.galleryListState.selected, Some(19))
    }

    @TestCase
    func dataSampleNavigationPreservesFocusAndValuesAcrossResponsiveSizes(): Unit {
        for (area in [Rect(0, 0, 80, 24), Rect(0, 0, 120, 36), Rect(0, 0, 160, 45)]) {
            let app = WorkbenchApp()
            _ = app.update(Event.Resize(area))
            @Expect(app.layout.interactive, true)
            let backend = TestBackend(area: area, captureSnapshots: false)
            let terminal = Terminal(backend, renderMode: RenderMode.Full)
            _ = terminal.draw { frame => app.render(frame) }

            workbenchGalleryKey(app, KeyCode.Tab)
            for (_ in 0..4) { workbenchGalleryKey(app, KeyCode.Right) }
            @Expect(app.galleryTabs.selected, 4)
            workbenchGalleryKey(app, KeyCode.Tab)
            @Expect(app.focus.current(), Some("gallery-data-sample-tabs"))
            workbenchGalleryKey(app, KeyCode.Right)
            @Expect(app.galleryDataTabs.selected, 1)
            workbenchGalleryKey(app, KeyCode.Tab)
            @Expect(app.focus.current(), Some("gallery-data-list"))
            workbenchGalleryKey(app, KeyCode.Down)
            @Expect(app.galleryListState.selected, Some(1))

            let listArea = galleryBlock(app, "List", BorderKind.Rounded).inner(
                workbenchGalleryAreas(app.layout.galleryContent, 4, sample: app.galleryDataTabs.selected).dataList)
            _ = terminal.draw { frame => app.render(frame) }
            @Expect(backend.lastBuffer().getOrThrow().getCell(listArea.x + 2, listArea.y + 1).symbol, "S")

            workbenchGalleryKey(app, KeyCode.BackTab)
            workbenchGalleryKey(app, KeyCode.Right)
            @Expect(app.galleryDataTabs.selected, 2)
            @Expect(app.galleryListState.selected, Some(1))
            workbenchGalleryKey(app, KeyCode.Left)
            @Expect(app.galleryDataTabs.selected, 1)
            workbenchGalleryKey(app, KeyCode.Tab)
            @Expect(app.focus.current(), Some("gallery-data-list"))
            @Expect(app.galleryListState.selected, Some(1))

            _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(1))))
            @Expect(app.interaction.active(), Some("help"))
            _ = terminal.draw { frame => app.render(frame) }
            @Expect(backend.snapshot().contains("Workbench help"), true)
            workbenchGalleryKey(app, KeyCode.Esc)
            @Expect(app.interaction.active().isNone(), true)
            @Expect(app.focus.current(), Some("gallery-data-list"))
        }
    }

    @TestCase
    func feedbackUsesToastManagerLifecycleAndSeverityStyle(): Unit {
        let app = WorkbenchApp()
        app.paused = true
        workbenchGalleryKey(app, KeyCode.Tab)
        for (_ in 0..5) { workbenchGalleryKey(app, KeyCode.Right) }
        @Expect(app.galleryTabs.selected, 5)
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Enter)
        @Expect(app.toastManager.count(), 1)

        let rendered = TestScenario().render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(rendered.passed, true)
        @Assert(rendered.lastSnapshot().contains("+ Success notification"))
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 2999)))
        @Expect(app.toastManager.count(), 1)
        _ = app.update(Event.Tick(TickEvent(deltaMillis: 1)))
        @Expect(app.toastManager.count(), 0)
    }

    @TestCase
    func dialogPaletteAndThemeControlsUseExistingInteractionScopes(): Unit {
        let app = WorkbenchApp()
        workbenchGalleryKey(app, KeyCode.Tab)
        for (_ in 0..6) { workbenchGalleryKey(app, KeyCode.Right) }
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Tab)
        workbenchGalleryKey(app, KeyCode.Enter)
        @Expect(app.interaction.active(), Some("gallery-dialog"))
        workbenchGalleryKey(app, KeyCode.Right)
        @Expect(app.interaction.focus().current(), Some("gallery-dialog-confirm"))
        workbenchGalleryKey(app, KeyCode.Enter)
        @Expect(app.interaction.active().isNone())
        @Expect(app.statusMessage, "Dialog confirmed")

        let areas = workbenchGalleryAreas(app.layout.galleryContent, 6)
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, areas.paletteButton.x + 1, areas.paletteButton.y)))
        @Expect(app.interaction.active(), Some("palette"))
        workbenchGalleryKey(app, KeyCode.Esc)
        @Expect(app.interaction.active().isNone())

        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, areas.dialogButton.right - 1, areas.dialogButton.y)))
        @Expect(app.interaction.active(), Some("gallery-dialog"))
        let modal = app.layout.dialog
        let outerX = modal.x + (modal.width - 52) / 2
        let outerY = modal.y + (modal.height - 9) / 2
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, outerX + 10, outerY + 7)))
        @Expect(app.interaction.active().isNone())
        @Expect(app.statusMessage, "Dialog confirmed")

        let themed = WorkbenchApp()
        workbenchGalleryKey(themed, KeyCode.Tab)
        for (_ in 0..7) { workbenchGalleryKey(themed, KeyCode.Right) }
        workbenchGalleryKey(themed, KeyCode.Tab)
        workbenchGalleryKey(themed, KeyCode.Enter)
        @Expect(themed.darkTheme, false)
        @Expect(themed.theme.normal, Style(fg: Color.Rgb(31, 41, 51), bg: Color.Rgb(247, 249, 252)))
        workbenchGalleryKey(themed, KeyCode.Tab)
        workbenchGalleryKey(themed, KeyCode.Left)
        @Expect(themed.theme.accent, Style(fg: Color.Magenta, bg: Color.Rgb(247, 249, 252)))
    }

    @TestCase
    func galleryRendersAllCategoriesWithinSupportedTerminalSizes(): Unit {
        let app = WorkbenchApp()
        for ((width, height) in [(Int64(80), Int64(24)), (120, 36), (160, 45)]) {
            let screen = Rect(0, 0, width, height)
            _ = app.update(Event.Resize(screen))
            @Expect(app.layout.interactive, true)
            @Assert(workbenchRectContained(screen, app.layout.galleryNav))
            @Assert(workbenchRectContained(screen, app.layout.galleryContent))
            for (category in 0..8) {
                app.galleryTabs.selected = category
                let sampleCount = if (category == 4) { Int64(3) } else { Int64(1) }
                for (sample in 0..sampleCount) {
                    app.galleryDataTabs.selected = sample
                    let areas = workbenchGalleryAreas(app.layout.galleryContent, category, sample: sample)
                    @Assert(workbenchRectContained(app.layout.galleryContent, areas.title))
                    @Assert(workbenchRectContained(app.layout.galleryContent, areas.description))
                    for (rect in areas.buttons) {
                        @Assert(workbenchRectContained(app.layout.galleryContent, rect))
                    }
                    for (rect in areas.panels) {
                        @Assert(workbenchRectContained(app.layout.galleryContent, rect))
                    }
                    for (rect in areas.formInputs) {
                        @Assert(workbenchRectContained(app.layout.galleryContent, rect))
                    }
                    for (rect in [areas.checkbox, areas.select, areas.asciiToggle, areas.layoutSample,
                        areas.navTabs, areas.navMenu, areas.navTree, areas.dataSampleTabs,
                        areas.dataTable, areas.dataList, areas.dataProgress, areas.toasts,
                        areas.paletteButton, areas.dialogButton, areas.themeToggle, areas.themeAccent,
                        areas.themeCapabilityLabel, areas.themeCapabilityPreview]) {
                    }
                    if (category == 4) {
                        @Assert(areas.dataSampleTabs.width == app.layout.galleryContent.width)
                        if (sample == 0) {
                            @Assert(areas.dataTable.height > 0)
                            @Assert(areas.dataList.height == 0)
                            @Assert(areas.dataProgress.height == 0)
                            if (width == 160) { @Assert(areas.dataTable.height >= 24) }
                        } else if (sample == 1) {
                            @Assert(areas.dataTable.height == 0)
                            @Assert(areas.dataList.height > 0)
                            @Assert(areas.dataProgress.height == 0)
                            if (width == 160) { @Assert(areas.dataList.height >= 24) }
                        } else {
                            @Assert(areas.dataTable.height == 0)
                            @Assert(areas.dataList.height == 0)
                            @Assert(areas.dataProgress.height >= 3)
                            @Assert(areas.dataProgress.y > areas.dataSampleTabs.bottom)
                        }
                    }
                    let rendered = TestScenario().render().run(
                        { frame => app.render(frame) },
                        { event => app.update(event) },
                        width: width,
                        height: height
                    )
                    @Expect(rendered.passed, true)
                    @Assert(rendered.lastSnapshot().contains(galleryCategoryTitle(category)))
                    @Assert(!rendered.lastSnapshot().contains("Need at least"))
                    if (category == 7) {
                        @Assert(rendered.lastSnapshot().contains("Terminal: true-color · preview: true-color"))
                        @Assert(rendered.lastSnapshot().contains("Monochrome"))
                    }
                }

            }
        }

    }

    @TestCase
    func galleryAsciiFallbackToggleSelectsAsciiBorderRendering(): Unit {
        let app = WorkbenchApp()
        app.galleryTabs.selected = 1
        let areas = workbenchGalleryAreas(app.layout.galleryContent, 1)
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, areas.asciiToggle.right - 1, areas.asciiToggle.y)))
        @Expect(app.galleryAsciiFallback, true)
        let rendered = TestScenario().render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(rendered.passed, true)
        @Assert(rendered.lastSnapshot().contains("ASCII: on"))
    }
}

@Test
class WorkbenchProgressFormattingTest {
    @TestCase
    func progressUnitsLabelsAndSaturationAgree(): Unit {
        let model = WorkbenchModel()
        @Expect(model.totalProgressHundredths(), 0)
        @Expect(formatPercent(0), "0.00%")
        @Expect(formatPercent(5000), "50.00%")
        @Expect(formatPercent(10000), "100.00%")
        @Expect(formatPercent(-1), "0.00%")
        @Expect(formatPercent(10001), "100.00%")
        @Expect(formatPercent(Int64.Max), "100.00%")

        _ = model.advance(6000)
        let progress = model.totalProgressHundredths()
        @Expect(model.doneCount, 1)
        @Expect(progress, 83)
        @Expect(formatPercent(progress), "0.83%")
        let lowResolution = Buffer(Rect(0, 0, 120, 1))
        Gauge(progress, total: 10000, label: formatPercent(progress)).render(
            lowResolution.area, lowResolution)
        @Expect(lowResolution.getCell(0, 0).symbol, "-")
        @Expect(lowResolution.getCell(119, 0).symbol, "-")

        let saturated = Buffer(Rect(0, 0, 10, 1))
        Gauge(10001, total: 10000).render(saturated.area, saturated)
        @Expect(saturated.getCell(0, 0).symbol, "#")
        @Expect(saturated.getCell(9, 0).symbol, "#")
    }
}

@Test
class WorkbenchThemeTest {
    @TestCase
    func graphiteCyanThemeDefinesSemanticColorRoles(): Unit {
        let dark = Theme.graphite(accent: Color.Cyan)
        @Expect(dark.normal, Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(18, 21, 26)))
        @Expect(dark.focused, Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(30, 61, 69), modifier: Modifier.strong()))
        @Expect(dark.selected, Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(26, 43, 50), modifier: Modifier.strong()))
        @Expect(dark.disabled, Style(fg: Color.Rgb(145, 157, 169), bg: Color.Rgb(18, 21, 26)))
        @Expect(dark.error, Style(fg: Color.Rgb(255, 119, 125), bg: Color.Rgb(18, 21, 26)))
        @Expect(dark.success, Style(fg: Color.Rgb(103, 216, 166), bg: Color.Rgb(18, 21, 26)))
        @Expect(dark.warning, Style(fg: Color.Rgb(255, 200, 105), bg: Color.Rgb(18, 21, 26)))
        @Expect(dark.info, Style(fg: Color.Rgb(80, 203, 221), bg: Color.Rgb(18, 21, 26)))

        let light = Theme.light(accent: Color.Cyan)
        @Expect(light.normal, Style(fg: Color.Rgb(31, 41, 51), bg: Color.Rgb(247, 249, 252)))
        @Expect(light.selected, Style(fg: Color.Rgb(31, 41, 51), bg: Color.Rgb(229, 239, 243), modifier: Modifier.strong()))
    }
}

@Test
class WorkbenchCapabilityPreviewTest {
    @TestCase
    func capabilityEventsAndGalleryPreviewNeverUpgradeTheDetectedTier(): Unit {
        let app = WorkbenchApp()
        app.galleryTabs.selected = 7
        _ = app.update(Event.Resize(Rect(0, 0, 120, 36)))
        _ = app.focus.focus("gallery-capability-preview")
        workbenchGalleryKey(app, KeyCode.Down)
        @Expect(app.galleryCapabilityPreview.selected, 1)
        @Expect(app.actualColorTier(), 3)
        @Expect(app.effectiveColorTier(), 2)
        match (app.theme.normal.fg) {
            case Color.Indexed(_) => @Expect(true)
            case _ => @Expect(false)
        }

        app.accentPicker.selected = 0
        _ = app.update(Event.Capabilities(TerminalCapabilities(
            trueColor: false,
            colorLevel: 16,
            unicode: false
        )))
        @Expect(app.actualColorTier(), 1)
        @Expect(app.effectiveColorTier(), 1)
        @Expect(app.accentPicker.selected, 0)
        @Expect(app.theme.normal, Style(fg: Color.White, bg: Color.Black))

        let blockBuffer = Buffer(Rect(0, 0, 12, 3))
        galleryBlock(app, "Capabilities", BorderKind.Rounded).render(blockBuffer.area, blockBuffer)
        @Expect(blockBuffer.getCell(0, 0).symbol, "+")

        workbenchGalleryKey(app, KeyCode.Home)
        @Expect(app.galleryCapabilityPreview.selected, 0)
        @Expect(app.effectiveColorTier(), 1)
        _ = app.update(Event.Capabilities(TerminalCapabilities(
            trueColor: true,
            colorLevel: 24,
            unicode: true
        )))
        @Expect(app.actualColorTier(), 3)
        @Expect(app.effectiveColorTier(), 3)
        @Expect(app.theme.normal, Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(18, 21, 26)))
        let previewArea = workbenchGalleryAreas(app.layout.galleryContent, 7).themeCapabilityPreview
        _ = app.update(Event.Mouse(MouseEvent(
            MouseKind.Down, MouseButton.Left, previewArea.x + 1, previewArea.y + 3)))
        @Expect(app.galleryCapabilityPreview.selected, 3)
        @Expect(app.effectiveColorTier(), 0)
        @Expect(app.theme.normal, Style.default())
    }

    @TestCase
    func monochromePreviewKeepsPaletteValueAndMatchesFullRender(): Unit {
        let area = Rect(0, 0, 120, 36)
        let partialApp = WorkbenchApp()
        let fullApp = WorkbenchApp()
        partialApp.galleryTabs.selected = 7
        fullApp.galleryTabs.selected = 7
        partialApp.accentPicker.selected = 2
        fullApp.accentPicker.selected = 2
        _ = partialApp.update(Event.Resize(area))
        _ = fullApp.update(Event.Resize(area))
        _ = partialApp.focus.focus("gallery-capability-preview")
        _ = fullApp.focus.focus("gallery-capability-preview")

        let partialBackend = TestBackend(area: area, captureSnapshots: false)
        let fullBackend = TestBackend(area: area, captureSnapshots: false)
        let partial = Terminal(partialBackend, renderMode: RenderMode.Diff)
        let full = Terminal(fullBackend, renderMode: RenderMode.Full)
        _ = partial.draw { frame => partialApp.render(frame) }
        _ = full.draw { frame => fullApp.render(frame) }

        let ansi8 = TerminalCapabilities(trueColor: false, colorLevel: 16, unicode: false)
        _ = partialApp.update(Event.Capabilities(ansi8))
        _ = fullApp.update(Event.Capabilities(ansi8))
        for (_ in 0..3) {
            workbenchGalleryKey(partialApp, KeyCode.Down)
            workbenchGalleryKey(fullApp, KeyCode.Down)
        }
        @Expect(partialApp.galleryCapabilityPreview.selected, 3)
        @Expect(partialApp.actualColorTier(), 1)
        @Expect(partialApp.effectiveColorTier(), 0)
        @Expect(partialApp.accentPicker.selected, 2)

        _ = partial.draw { frame => partialApp.render(frame) }
        _ = full.draw { frame => fullApp.render(frame) }
        let partialBuffer = partialBackend.lastBuffer().getOrThrow()
        let fullBuffer = fullBackend.lastBuffer().getOrThrow()
        @Expect(partialBuffer.diff(fullBuffer).size, 0)

        let paletteArea = galleryRect(partialApp.layout.galleryContent, 0, 6, 36, 1)
        @Expect(partialBuffer.getCell(paletteArea.x + 6, paletteArea.y).symbol, "Y")
        @Expect(partialBuffer.getCell(paletteArea.x + 7, paletteArea.y).symbol, "*")
        for (x in paletteArea.x..paletteArea.right) {
            let style = partialBuffer.getCell(x, paletteArea.y).style
            @Expect(style, Style.default())
        }
    }


}


@Test
class WorkbenchRenderTest {
    @TestCase
    func overviewAndTaskScreensRenderLiveData(): Unit {
        let app = WorkbenchApp()
        let showcase = TestScenario().render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 140,
            height: 42
        )
        @Expect(showcase.passed, true)
        let showcaseSnapshot = showcase.lastSnapshot()
        @Assert(showcaseSnapshot.contains("Overview  /  Graphite + Cyan"))
        @Assert(showcaseSnapshot.contains("Accent-led controls"))
        @Assert(showcaseSnapshot.contains("Terminal-native"))
        @Assert(showcaseSnapshot.contains("Forms"))
        @Assert(showcaseSnapshot.contains("Navigation"))
        @Assert(showcaseSnapshot.contains("Data"))
        @Assert(showcaseSnapshot.contains("Toast"))
        @Assert(showcaseSnapshot.contains("Dialog"))
        @Assert(showcaseSnapshot.contains("0.00%"))
        let compactShowcase = TestScenario().render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(compactShowcase.passed, true)
        @Assert(compactShowcase.lastSnapshot().contains("Graphite + Cyan"))
        _ = app.perform("page.overview")
        let overview = TestScenario().resize(120, 36).render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(overview.passed, true)
        @Assert(overview.lastSnapshot().contains("Status distribution"))
        @Assert(overview.lastSnapshot().contains("Progress history"))
        @Assert(overview.lastSnapshot().contains("RUNNING"))
        @Assert(overview.lastSnapshot().contains("Active slots"))
        @Assert(overview.lastSnapshot().contains("Ready queue"))
        @Assert(overview.lastSnapshot().contains("job-2"))

        let tasks = TestScenario().key(KeyEvent(KeyCode.F(3))).render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(tasks.passed, true)
        @Assert(tasks.lastSnapshot().contains("Tasks"))
        @Assert(tasks.lastSnapshot().contains("job-1"))
        @Assert(tasks.lastSnapshot().contains("Selected task"))
        @Assert(tasks.lastSnapshot().contains("Progress"))
    }

    @TestCase
    func readyQueuePreviewTracksTaskStarts(): Unit {
        let app = WorkbenchApp()
        _ = app.perform("page.tasks")
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        _ = app.perform("page.overview")

        let overview = TestScenario().resize(120, 36).render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(overview.passed, true)
        let snapshot = overview.lastSnapshot()
        @Assert(snapshot.contains("Ready queue"))
        @Assert(snapshot.contains("job-3"))
        @Assert(snapshot.contains("Started job-2"))
    }

    @TestCase
    func settingsScreenKeepsControlsInsideTheirPanels(): Unit {
        let app = WorkbenchApp()
        _ = app.perform("page.settings")
        let settings = TestScenario().resize(120, 36).render().run(
            { frame => app.render(frame) },
            { event => app.update(event) },
            width: 120,
            height: 36
        )
        @Expect(settings.passed, true)
        let snapshot = settings.lastSnapshot()
        @Assert(snapshot.contains("Appearance"))
        @Assert(snapshot.contains("Simulation"))
        @Assert(snapshot.contains("Task speed"))
    }
}
