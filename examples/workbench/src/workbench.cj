package cjtui_workbench

import core.*
import std.collection.*
import std.unicode.*
import core.List as CoreList

class WorkbenchApp {
    var page: WorkbenchPage = WorkbenchPage.Showcase
    var screen: Rect = Rect(0, 0, 120, 36)
    var layout: WorkbenchLayout = workbenchLayout(Rect(0, 0, 120, 36), WorkbenchPage.Showcase)
    var model: WorkbenchModel = WorkbenchModel()
    let focus = FocusManager()
    let interaction: ModalFocusState
    let tabs = Tabs(["Gallery", "Overview", "Tasks", "Settings"])
    let galleryTabs = Tabs(["Overview", "Layout", "Forms", "Navigation", "Data", "Feedback", "Overlays", "Themes"])
    let galleryInput = Input(value: "", placeholder: "Type to edit this input")
    let galleryCheckbox = Checkbox("Compact density")
    let gallerySelect = Select(["Compact", "Normal", "Comfortable"], selected: 1)
    let galleryCapabilityPreview = Select(["Native", "xterm-256", "ANSI-8", "Monochrome"])
    let galleryNavigationTabs = Tabs(["Overview", "Sources", "Output"])
    let galleryDataTabs = Tabs(["Table", "List", "Progress"])
    let galleryMenu = Menu("Actions", [
        MenuItem("Open item", action: "open"),
        MenuItem("Rename", action: "rename"),
        MenuItem("Unavailable", action: "disabled", enabled: false)
    ])
    let galleryTreeNodes = [
        TreeNode("workspace", "workspace", expanded: true, children: [
            TreeNode("src", "src", expanded: true, children: [
                TreeNode("main", "main.cj"),
                TreeNode("test", "test.cj")
            ]),
            TreeNode("docs", "docs", expanded: true, children: [
                TreeNode("readme", "README.md")
            ])
        ])
    ]
    let galleryTree = Tree(galleryTreeNodes, selected: 2)
    let galleryTableState = TableState(selectedRow: Some(0))
    let galleryListState = ListState(selected: Some(0))
    let galleryDialog = ConfirmDialog("This is a real confirmation dialog.\nYes confirms; No declines.", selectedStyle: Style.default())
    var galleryAsciiFallback: Bool = false
    let projects = Tree([
        TreeNode("all", "All projects"),
        TreeNode("project-alpha", "Alpha"),
        TreeNode("project-beta", "Beta"),
        TreeNode("project-gamma", "Gamma")
    ], selected: 0, block: Some(Block(title: "Projects")))
    let taskSearch = Input(value: "", placeholder: "Search by task name, ID, or text", block: Block(title: "Search"))
    let taskFilter = Dropdown(["All", "Queued", "Running", "Done"], placeholder: "Status", selectedStyle: Style.default())
    let taskState = TableState(selectedRow: Some(0))
    let taskScroll = ScrollState()
    let logScroll = ScrollState()
    let capture = PointerCapture()
    let themeRadio = RadioGroup(["Dark", "Light"], selected: 0, block: Some(Block(title: "Theme")))
    let accentColors = [Color.Red, Color.Green, Color.Yellow, Color.Blue, Color.Magenta, Color.Cyan]
    let accentPicker = ColorPicker(colors: accentColors, selected: 5)
    let motionToggle = Checkbox("Motion", checked: true)
    let speedSelect = Select(["0.5x", "1x", "2x"], selected: 1)
    let editorName = Input(value: "", placeholder: "Task name", block: Block(title: "Name"))
    let editorPrioritySelect = Select(["Low", "Normal", "High", "Critical"])
    let editorNotify = Checkbox("Notify on completion", checked: true)
    var editorTags = MultiSelect(["build", "test", "docs", "release"])
    let editorNotes = TextArea(value: "", block: Block(title: "Notes"), lineNumbers: true)
    let palette = CommandPalette([
        MenuItem("Component gallery", action: "page.showcase"),
        MenuItem("Overview page", action: "page.overview"),
        MenuItem("Tasks page", action: "page.tasks"),
        MenuItem("Settings page", action: "page.settings"),
        MenuItem("Next page", action: "page.next"),
        MenuItem("Show all projects", action: "project.all"),
        MenuItem("Filter Alpha project", action: "project.alpha"),
        MenuItem("Filter Beta project", action: "project.beta"),
        MenuItem("Filter Gamma project", action: "project.gamma"),
        MenuItem("Start selected task", action: "task.start"),
        MenuItem("Edit selected task", action: "task.edit"),
        MenuItem("Reset selected task", action: "task.reset"),
        MenuItem("Pause or resume simulation", action: "simulation.pause"),
        MenuItem("Toggle motion", action: "motion.toggle"),
        MenuItem("Reset demo", action: "demo.reset"),
        MenuItem("Help", action: "help"),
        MenuItem("Quit", action: "app.quit"),
        MenuItem("Unavailable command", action: "unavailable", enabled: false)
    ],
        selectedStyle: Style.default(),
        caseSensitive: false
    )
    let helpDialog = Dialog(title: "Workbench help", body: "F1 help   F2 commands   F3 next page\nF4 edit task F5 run task F6 pause\nTab changes focus. / searches. q exits.\nGallery: Left/Right categories; click controls.\nMouse supports selection, sorting, scrolling, and modal actions.", buttons: ["Close"], width: 68, height: 10, selectedStyle: Style.default())
    let resetDialog = Dialog(title: "Reset task", body: "Return this task to the queued state?", buttons: ["Cancel", "Reset"], width: 56, height: 9, selectedStyle: Style.default())
    let demoResetDialog = Dialog(title: "Reset local demo", body: "Discard demo progress and restore all 120 tasks?", buttons: ["Cancel", "Reset"], width: 62, height: 9, selectedStyle: Style.default())

    var darkTheme: Bool = true
    var capabilities: TerminalCapabilities = TerminalCapabilities()
    var theme: Theme = Theme.default()
    var motionEnabled: Bool = true
    var surfaceStyle: Style = Style.default()
    var secondaryStyle: Style = Style.default()
    var borderStyle: Style = Style.default()
    var accentButtonStyle: Style = Style.default()
    var paused: Bool = false
    var statusMessage: String = "Ready"
    var editorError: String = ""
    var selectedId: ?Int64 = Some(1)
    var projectFilter: ?String = None
    var editingId: ?Int64 = None
    var pendingResetId: ?Int64 = None
    var spinnerFrame: Int64 = 0
    var pipelineOffset: Int64 = 0
    private var overviewFocus: ?String = None
    private var showcaseFocus: ?String = None
    private var tasksFocus: ?String = Some("task-table")
    private var settingsFocus: ?String = Some("theme-radio")
    private var simulationSpeed: Int64 = 1000
    private var speedRemainder: Int64 = 0
    private var sampleRemainder: Int64 = 0
    private var visualRemainder: Int64 = 0
    private var tweenElapsed: Int64 = 200
    private var tweenFrom: Int64 = 0
    private var tweenTarget: Int64 = 0
    private var tweenId: ?Int64 = None
    private var successId: ?Int64 = None
    private var successRemaining: Int64 = 0
    private let toastItems = ArrayList<Toast>()
    private let tickChangedIds = ArrayList<Int64>()
    private let toastAges = ArrayList<Int64>()
    private var logFollowTail: Bool = true
    var toastManager: ToastManager = ToastManager()

    init() {
        interaction = ModalFocusState(focus, keymap: KeyMap(bindings: [
            KeyBinding([KeyEvent(KeyCode.F(1))], "help"),
            KeyBinding([KeyEvent(KeyCode.F(2))], "palette"),
            KeyBinding([KeyEvent(KeyCode.F(3))], "page.next"),
            KeyBinding([KeyEvent(KeyCode.F(4))], "task.edit"),
            KeyBinding([KeyEvent(KeyCode.F(5))], "task.start"),
            KeyBinding([KeyEvent(KeyCode.F(6))], "simulation.pause")
        ]))
        taskFilter.setTransactionalSelection(enabled: true)
        refreshTheme()
        projects.expandAll()
        _ = projects.selectById("all")
        recordActivity("Local demo initialized: 120 tasks")
        model.sampleHistory(model.totalProgressHundredths())
        syncTableSelection()
        syncFocus(false)
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => updateKey(key)
            case Event.KeyUp(_) => UpdateResult.unchanged()
            case Event.Paste(text) => updatePaste(text)
            case Event.Mouse(mouse) => updateMouse(mouse)
            case Event.Tick(tick) => updateTick(tick)
            case Event.Resize(area) =>
                cancelPointerCapture()
                screen = area
                layout = workbenchLayout(screen, page)
                syncFocus(true)
                UpdateResult.next()
            case Event.FocusOut =>
                cancelPointerCapture()
                taskFilter.cancelSelection()
                statusMessage = "Terminal focus lost"
                UpdateResult.next()
            case Event.FocusIn =>
                if (statusMessage == "Terminal focus lost") {
                    statusMessage = "Ready"
                    UpdateResult.next()
                } else {
                    UpdateResult.unchanged()
                }
            case Event.Capabilities(value) =>
                capabilities = value
                refreshTheme()
                UpdateResult.next()
            case _ => UpdateResult.unchanged()
        }
    }

    func render(frame: Frame): Unit {
        if (screen.width != frame.area.width || screen.height != frame.area.height) {
            screen = frame.area
            layout = workbenchLayout(screen, page)
            syncFocus(true)
        }
        renderWorkbench(this, frame)
    }

    func perform(action: String): UpdateResult {
        match (action) {
            case "page.showcase" => switchPage(WorkbenchPage.Showcase); UpdateResult.next()
            case "page.overview" => switchPage(WorkbenchPage.Overview); UpdateResult.next()
            case "page.tasks" => switchPage(WorkbenchPage.Tasks); UpdateResult.next()
            case "page.settings" => switchPage(WorkbenchPage.Settings); UpdateResult.next()
            case "page.next" =>
                let next = match (page) {
                    case WorkbenchPage.Showcase => WorkbenchPage.Overview
                    case WorkbenchPage.Overview => WorkbenchPage.Tasks
                    case WorkbenchPage.Tasks => WorkbenchPage.Settings
                    case WorkbenchPage.Settings => WorkbenchPage.Showcase
                }
                switchPage(next)
                UpdateResult.next()
            case "project.all" =>
                projectFilter = None
                _ = projects.selectById("all")
                applyTaskFilters()
                statusMessage = "All projects"
                UpdateResult.next()
            case "project.alpha" => setProject(Some("Alpha")); UpdateResult.next()
            case "project.beta" => setProject(Some("Beta")); UpdateResult.next()
            case "project.gamma" => setProject(Some("Gamma")); UpdateResult.next()
            case "task.start" => startSelected(); UpdateResult.next()
            case "task.edit" => openEditor(); UpdateResult.next()
            case "task.reset" => openTaskReset(); UpdateResult.next()
            case "simulation.pause" =>
                paused = !paused
                statusMessage = if (paused) { "Simulation paused" } else { "Simulation resumed" }
                recordActivity(statusMessage)
                UpdateResult.next()
            case "motion.toggle" =>
                motionEnabled = !motionEnabled
                motionToggle.checked = motionEnabled
                if (!motionEnabled) { tweenElapsed = 200; tweenFrom = tweenTarget }
                statusMessage = if (motionEnabled) { "Motion enabled" } else { "Motion disabled" }
                UpdateResult.next()
            case "demo.reset" => openDemoReset(); UpdateResult.next()
            case "help" => openHelp(); UpdateResult.next()
            case "palette" => openPalette(); UpdateResult.next()
            case "app.quit" => UpdateResult.exit()
            case _ => UpdateResult.unchanged()
        }
    }

    func canRun(): Bool {
        match (selectedId) {
            case Some(id) =>
                match (model.job(id)) {
                    case Some(task) => task.status == WorkbenchJobStatus.Queued && model.runningCount < 4
                    case None => false
                }
            case None => false
        }
    }

    func canReset(): Bool {
        match (selectedId) {
            case Some(id) =>
                match (model.job(id)) {
                    case Some(task) => task.status != WorkbenchJobStatus.Queued
                    case None => false
                }
            case None => false
        }
    }

    func selectedStyle(): Style {
        theme.selected
    }

    func detailProgress(id: Int64, actual: Int64): Int64 {
        if (!motionEnabled || tweenId != Some(id) || tweenElapsed >= 200) { return actual }
        let t = tweenElapsed * 1000 / 200
        let eased = t * t * (3000 - 2 * t) / 1000000
        min(10000, max(0, tweenFrom + (tweenTarget - tweenFrom) * eased / 1000))
    }

    func isSuccess(id: Int64): Bool { successId == Some(id) && successRemaining > 0 }

    func layoutTableWidths(): Array<Int64> {
        let available = max(0, layout.taskTable.width - 4)
        let idWidth = min(8, available)
        let nameWidth = min(20, max(0, available - idWidth))
        let projectWidth = min(14, max(0, available - idWidth - nameWidth))
        let statusWidth = min(10, max(0, available - idWidth - nameWidth - projectWidth))
        let progressWidth = max(0, available - idWidth - nameWidth - projectWidth - statusWidth)
        [idWidth, nameWidth, projectWidth, statusWidth, progressWidth]
    }

    private func updateKey(key: KeyEvent): UpdateResult {
        match (key.code) {
            case KeyCode.CtrlC => return UpdateResult.exit()
            case _ => ()
        }
        if (interaction.active().isSome()) { return updateModalKey(key) }
        if (taskFilter.open) {
            match (taskFilter.handle(key)) {
                case Some(_) => applyTaskFilters(); statusMessage = "Status filter: " + filterLabel(); return UpdateResult.next()
                case None => return UpdateResult.next()
            }
        }
        if (interaction.actionFor(key) == Some("help")) { return perform("help") }
        if (interaction.actionFor(key) == Some("palette")) { return perform("palette") }
        if (interaction.actionFor(key) == Some("page.next")) { return perform("page.next") }
        if (interaction.actionFor(key) == Some("task.edit")) { return perform("task.edit") }
        if (interaction.actionFor(key) == Some("task.start")) { return perform("task.start") }
        if (interaction.actionFor(key) == Some("simulation.pause")) { return perform("simulation.pause") }
        let current = focus.current()
        if (current != Some("task-search") && current != Some("gallery-input")) {
            match (key.code) {
                case KeyCode.Char(r'/') =>
                    switchPage(WorkbenchPage.Tasks)
                    _ = focus.focus("task-search")
                    return UpdateResult.next()
                case KeyCode.Char(r'q') => return UpdateResult.exit()
                case _ => ()
            }
        }
        if (focus.handle(key)) { rememberCurrentFocus(); return UpdateResult.next() }
        if (!layout.interactive) { return UpdateResult.unchanged() }
        if (page == WorkbenchPage.Showcase) {
            match (current) {
                case Some(id) =>
                    match (updateGalleryKey(key, id)) {
                        case Some(result) => return result
                        case None => ()
                    }
                case None => ()
            }
        }
        match (current) {
            case Some("tabs") =>
                if (tabs.handle(key)) {
                    setPageFromTab()
                    return UpdateResult.next()
                }
            case Some("projects") =>
                if (projects.handle(key, layout.projectTree.height)) {
                    applyTreeProject()
                    return UpdateResult.next()
                }
            case Some("task-search") =>
                _ = taskSearch.handle(key)
                applyTaskFilters()
                return UpdateResult.next()
            case Some("task-filter") =>
                match (taskFilter.handle(key)) {
                    case Some(_) => applyTaskFilters()
                    case None => ()
                }
                return UpdateResult.next()
            case Some("task-run") =>
                if (Button("Run").handle(key)) { return perform("task.start") }
            case Some("task-edit") =>
                if (Button("Edit").handle(key)) { return perform("task.edit") }
            case Some("task-reset") =>
                if (Button("Reset").handle(key)) { return perform("task.reset") }
            case Some("task-table") => return handleTableKey(key)
            case Some("log-view") =>
                if (logScroll.handle(key, model.logs().size, max(0, layout.logView.height - 2))) {
                    syncLogFollowTail()
                    return UpdateResult.next()
                }
            case Some("theme-radio") =>
                if (themeRadio.handle(key)) { applyThemeSelection(); return UpdateResult.next() }
            case Some("accent-picker") =>
                if (accentPicker.handle(key)) { applyThemeSelection(); return UpdateResult.next() }
            case Some("setting-motion") =>
                if (motionToggle.handle(key)) { _ = perform("motion.toggle"); return UpdateResult.next() }
            case Some("setting-speed") =>
                match (speedSelect.handle(key)) {
                    case Some(value) => applySpeed(value)
                    case None => ()
                }
                return UpdateResult.next()
            case Some("setting-pause") =>
                if (Button("Pause").handle(key)) { return perform("simulation.pause") }
            case Some("setting-reset") =>
                if (Button("Reset demo").handle(key)) { return perform("demo.reset") }
            case _ => ()
        }
        UpdateResult.unchanged()
    }

    private func updateGalleryKey(key: KeyEvent, id: String): ?UpdateResult {
        if (id == "gallery-data-sample-tabs" && galleryDataTabs.handle(key)) {
            syncFocus(true)
            return Some(UpdateResult.next())
        }
        if (id == "gallery-tabs" && galleryTabs.handle(key)) {
            syncFocus(true)
            return Some(UpdateResult.next())
        }
        match (id) {
            case "gallery-overview-forms" =>
                if (galleryButton(this, "Forms", 1, id).handle(key)) { selectGalleryCategory(2); return Some(UpdateResult.next()) }
            case "gallery-overview-navigation" =>
                if (galleryButton(this, "Navigation", 1, id).handle(key)) { selectGalleryCategory(3); return Some(UpdateResult.next()) }
            case "gallery-overview-data" =>
                if (galleryButton(this, "Data", 1, id).handle(key)) { selectGalleryCategory(4); return Some(UpdateResult.next()) }
            case "gallery-overview-toast" =>
                if (galleryButton(this, "Toast", 1, id).handle(key)) { pushGalleryToast("Info"); return Some(UpdateResult.next()) }
            case "gallery-overview-dialog" =>
                if (galleryButton(this, "Dialog", 1, id).handle(key)) { openGalleryDialog(); return Some(UpdateResult.next()) }
            case "gallery-ascii-toggle" =>
                if (galleryButton(this, "ASCII fallback", 2, id).handle(key)) {
                    galleryAsciiFallback = !galleryAsciiFallback
                    statusMessage = if (galleryAsciiFallback) { "ASCII border fallback enabled" } else { "Unicode borders enabled" }
                    return Some(UpdateResult.next())
                }
            case "gallery-button-primary" | "gallery-button-secondary" | "gallery-button-ghost" | "gallery-button-danger" =>
                let label = if (id == "gallery-button-primary") { "Primary" }
                    else if (id == "gallery-button-secondary") { "Secondary" }
                    else if (id == "gallery-button-ghost") { "Ghost" } else { "Danger" }
                let variant = if (id == "gallery-button-primary") { 0 }
                    else if (id == "gallery-button-secondary") { 1 }
                    else if (id == "gallery-button-ghost") { 2 } else { 3 }
                if (galleryButton(this, label, variant, id).handle(key)) {
                    statusMessage = label + " button activated"
                    pushGalleryToast("Success")
                    return Some(UpdateResult.next())
                }
            case "gallery-input" =>
                _ = galleryInput.handle(key)
                return Some(UpdateResult.next())
            case "gallery-checkbox" =>
                if (galleryCheckbox.handle(key)) {
                    statusMessage = if (galleryCheckbox.checked) { "Compact density enabled" } else { "Normal density enabled" }
                }
                return Some(UpdateResult.next())
            case "gallery-select" =>
                match (gallerySelect.handle(key)) {
                    case Some(value) => statusMessage = "Density: " + value
                    case None => ()
                }
                return Some(UpdateResult.next())
            case "gallery-nav-tabs" =>
                if (galleryNavigationTabs.handle(key)) { return Some(UpdateResult.next()) }
            case "gallery-nav-menu" =>
                match (galleryMenu.handle(key)) {
                    case Some(action) => statusMessage = "Menu action: " + action
                    case None => ()
                }
                return Some(UpdateResult.next())
            case "gallery-nav-tree" =>
                if (galleryTree.handle(key, workbenchGalleryAreas(layout.galleryContent, 3).navTree.height)) {
                    match (galleryTree.selectedId()) {
                        case Some(id) => statusMessage = "Tree item: " + id
                        case None => ()
                    }
                    return Some(UpdateResult.next())
                }
            case "gallery-data-table" =>
                match (key.code) {
                    case KeyCode.Up => galleryTableState.move(-1, galleryTableRows().size, viewportHeight: workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected).dataTable.height - 2)
                    case KeyCode.Down => galleryTableState.move(1, galleryTableRows().size, viewportHeight: workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected).dataTable.height - 2)
                    case _ => return None
                }
                return Some(UpdateResult.next())
            case "gallery-data-list" =>
                match (key.code) {
                    case KeyCode.Up => galleryListState.move(-1, galleryListItems().size, viewportHeight: workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected).dataList.height)
                    case KeyCode.Down => galleryListState.move(1, galleryListItems().size, viewportHeight: workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected).dataList.height)
                    case _ => return None
                }
                return Some(UpdateResult.next())
            case "gallery-toast-success" => if (galleryButton(this, "Success", 0, id).handle(key)) { pushGalleryToast("Success"); return Some(UpdateResult.next()) }
            case "gallery-toast-warning" => if (galleryButton(this, "Warning", 0, id).handle(key)) { pushGalleryToast("Warning"); return Some(UpdateResult.next()) }
            case "gallery-toast-error" => if (galleryButton(this, "Error", 3, id).handle(key)) { pushGalleryToast("Error"); return Some(UpdateResult.next()) }
            case "gallery-toast-info" => if (galleryButton(this, "Info", 2, id).handle(key)) { pushGalleryToast("Info"); return Some(UpdateResult.next()) }
            case "gallery-open-palette" =>
                if (galleryButton(this, "Palette", 1, id).handle(key)) { openPalette(); return Some(UpdateResult.next()) }
            case "gallery-open-dialog" =>
                if (galleryButton(this, "Open confirmation", 1, id).handle(key)) { openGalleryDialog(); return Some(UpdateResult.next()) }
            case "gallery-theme-toggle" =>
                if (galleryButton(this, "Theme", 1, id).handle(key)) {
                    themeRadio.selected = if (darkTheme) { 1 } else { 0 }
                    applyThemeSelection()
                    return Some(UpdateResult.next())
                }
            case "gallery-accent" =>
                if (accentPicker.handle(key)) { applyThemeSelection(); return Some(UpdateResult.next()) }
            case "gallery-capability-preview" =>
                _ = galleryCapabilityPreview.handle(key)
                refreshTheme()
                return Some(UpdateResult.next())
            case _ => ()
        }
        None
    }

    private func updateModalKey(key: KeyEvent): UpdateResult {
        let before = interaction.active()
        if (interaction.actionFor(key) == Some("help")) {
            openHelp()
            return UpdateResult.next()
        }
        if (interaction.handle(key)) {
            if (before != interaction.active()) { modalClosed(before) }
            return UpdateResult.next()
        }
        match (interaction.active()) {
            case Some("help") =>
                match (helpDialog.handle(key)) {
                    case Some(_) => closeModal()
                    case None => ()
                }
                UpdateResult.next()
            case Some("palette") =>
                match (palette.handle(key)) {
                    case Some(action) =>
                        closeModal()
                        perform(action)
                    case None => UpdateResult.next()
                }
            case Some("gallery-dialog") =>
                galleryDialog.confirmed = interaction.focus().current() == Some("gallery-dialog-confirm")
                match (galleryDialog.handle(key)) {
                    case Some(accepted) => finishGalleryDialog(accepted)
                    case None =>
                        _ = interaction.focus().focus(if (galleryDialog.confirmed) { "gallery-dialog-confirm" } else { "gallery-dialog-cancel" })
                        UpdateResult.next()
                }
            case Some("editor") => updateEditorKey(key)
            case Some("reset-confirm") =>
                resetDialog.selected = if (interaction.focus().current() == Some("confirm-reset")) { 1 } else { 0 }
                match (resetDialog.handle(key)) {
                    case Some(action) => finishTaskReset(action)
                    case None =>
                        _ = interaction.focus().focus(if (resetDialog.selected == 1) { "confirm-reset" } else { "confirm-cancel" })
                        UpdateResult.next()
                }
            case Some("demo-confirm") =>
                demoResetDialog.selected = if (interaction.focus().current() == Some("demo-reset")) { 1 } else { 0 }
                match (demoResetDialog.handle(key)) {
                    case Some(action) => finishDemoReset(action)
                    case None =>
                        _ = interaction.focus().focus(if (demoResetDialog.selected == 1) { "demo-reset" } else { "demo-cancel" })
                        UpdateResult.next()
                }
            case _ => UpdateResult.unchanged()
        }
    }

    private func updateEditorKey(key: KeyEvent): UpdateResult {
        match (interaction.focus().current()) {
            case Some("editor-name") =>
                _ = editorName.handle(key)
                editorError = ""
            case Some("editor-priority") => _ = editorPrioritySelect.handle(key)
            case Some("editor-notify") => _ = editorNotify.handle(key)
            case Some("editor-tags") => _ = editorTags.handle(key)
            case Some("editor-notes") => _ = editorNotes.handle(key)
            case Some("editor-cancel") =>
                if (Button("Cancel").handle(key)) { closeModal(); return UpdateResult.next() }
            case Some("editor-save") =>
                if (Button("Save").handle(key)) { return saveEditor() }
            case _ => ()
        }
        UpdateResult.next()
    }

    private func updatePaste(text: String): UpdateResult {
        match (interaction.active()) {
            case Some("editor") =>
                match (interaction.focus().current()) {
                    case Some("editor-name") =>
                        editorName.paste(text)
                        editorError = ""
                    case Some("editor-notes") => editorNotes.paste(text)
                    case _ => ()
                }
                UpdateResult.next()
            case Some("palette") =>
                palette.paste(text)
                UpdateResult.next()
            case _ =>
                match (focus.current()) {
                    case Some("task-search") =>
                        taskSearch.paste(text)
                        applyTaskFilters()
                        UpdateResult.next()
                    case Some("gallery-input") =>
                        galleryInput.paste(text)
                        UpdateResult.next()
                    case _ => UpdateResult.unchanged()
                }
        }
    }

    private func updateMouse(mouse: MouseEvent): UpdateResult {
        if (interaction.active().isSome()) { return updateModalMouse(mouse) }
        if (!layout.interactive) { return UpdateResult.unchanged() }
        if (capture.activeOwner().isSome()) { return routeCapturedMouse(mouse) }
        if (taskFilter.open) {
            if (!widgetHitTest(mouse, layout.taskFilter)) {
                taskFilter.cancelSelection()
                return UpdateResult.next()
            }
            _ = focus.focus("task-filter")
            match (taskFilter.handleMouse(mouse, layout.taskFilter)) {
                case Some(_) => applyTaskFilters()
                case None => ()
            }
            return UpdateResult.next()
        }
        if (mouseScrollDelta(mouse) != 0) {
            if (widgetHitTest(mouse, layout.logPanel)) {
                logScroll.scroll(mouseScrollDelta(mouse) * 3, model.logs().size, max(0, layout.logView.height - 2))
                syncLogFollowTail()
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, layout.taskTableBlock)) {
                let table = Table(["ID", "Name", "Project", "Status", "Progress"], model.visibleRows(),
                    widths: layoutTableWidths(), state: Some(taskState), style: theme.normal,
                    headerStyle: theme.accent, selectedStyle: selectedStyle())
                _ = table.handleMouse(mouse, layout.taskTable)
                syncSelectedFromTable()
                taskScroll.offset = taskState.offset
                return UpdateResult.next()
            }
        }
        if (tabs.handleMouse(mouse, layout.tabs)) {
            setPageFromTab()
            _ = focus.focus("tabs")
            return UpdateResult.next()
        }
        if (page == WorkbenchPage.Showcase) { return updateGalleryMouse(mouse) }
        if (page == WorkbenchPage.Overview || page == WorkbenchPage.Tasks) {
            if (widgetHitTest(mouse, layout.projectTree)) {
                if (projects.handle(mouse, layout.projectTree)) {
                    applyTreeProject()
                    _ = focus.focus("projects")
                    return UpdateResult.next()
                }
            }
        }
        if (page == WorkbenchPage.Overview) {
            if (widgetHitTest(mouse, layout.logScrollbar) && logScrollbar().handleMouse(mouse, layout.logScrollbar, logScroll, capture, "log-scroll")) {
                syncLogFollowTail()
                _ = focus.focus("log-view")
                return UpdateResult.next()
            }
        } else if (page == WorkbenchPage.Tasks) {
            if (mouse.y == layout.taskTable.y) {
                match ((mouse.kind, mouse.button)) {
                    case (MouseKind.Down, MouseButton.Left) =>
                        let column = headerColumn(mouse.x)
                        if (column >= 0) { sortBy(column); _ = focus.focus("task-table"); return UpdateResult.next() }
                    case _ => ()
                }
            }
            if (widgetHitTest(mouse, layout.taskScrollbar) && taskScrollbar().handleMouse(mouse, layout.taskScrollbar, taskScroll, capture, "task-scroll")) {
                taskState.offset = taskScroll.offset
                _ = focus.focus("task-table")
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, layout.taskTable) && tableWidget().handleMouse(mouse, layout.taskTable)) {
                syncSelectedFromTable()
                taskScroll.offset = taskState.offset
                _ = focus.focus("task-table")
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, layout.taskSearch)) {
                if (taskSearch.handleMouse(mouse, layout.taskSearch)) {
                    _ = focus.focus("task-search")
                    applyTaskFilters()
                    return UpdateResult.next()
                }
            }
            if (widgetHitTest(mouse, layout.taskFilter)) {
                _ = focus.focus("task-filter")
                match (taskFilter.handleMouse(mouse, layout.taskFilter)) {
                    case Some(_) => applyTaskFilters()
                    case None => ()
                }
                return UpdateResult.next()
            }
            if (activateButton(mouse, layout.taskRun, "task-run", "Run")) { _ = focus.focus("task-run"); return perform("task.start") }
            if (activateButton(mouse, layout.taskEdit, "task-edit", "Edit")) { _ = focus.focus("task-edit"); return perform("task.edit") }
            if (activateButton(mouse, layout.taskReset, "task-reset", "Reset")) { _ = focus.focus("task-reset"); return perform("task.reset") }
            if (widgetHitTest(mouse, layout.taskDetailRun) && activateButton(mouse, layout.taskDetailRun, "task-run", "Run")) { return perform("task.start") }
            if (widgetHitTest(mouse, layout.taskDetailEdit) && activateButton(mouse, layout.taskDetailEdit, "task-edit", "Edit")) { return perform("task.edit") }
            if (widgetHitTest(mouse, layout.taskDetailReset) && activateButton(mouse, layout.taskDetailReset, "task-reset", "Reset")) { return perform("task.reset") }
        } else {
            if (widgetHitTest(mouse, layout.settingTheme) && themeRadio.handleMouse(mouse, layout.settingTheme)) {
                _ = focus.focus("theme-radio")
                applyThemeSelection()
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, layout.settingAccent) && accentPicker.handleMouse(mouse, Rect(layout.settingAccent.x, layout.settingAccent.y + 1, layout.settingAccent.width, max(0, layout.settingAccent.height - 1)))) {
                _ = focus.focus("accent-picker")
                applyThemeSelection()
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, layout.settingMotion) && motionToggle.handleMouse(mouse, layout.settingMotion)) {
                _ = focus.focus("setting-motion")
                motionEnabled = motionToggle.checked
                if (!motionEnabled) { tweenElapsed = 200; tweenFrom = tweenTarget }
                statusMessage = if (motionEnabled) { "Motion enabled" } else { "Motion disabled" }
                return UpdateResult.next()
            }
            let speedArea = Rect(layout.settingSpeed.x, layout.settingSpeed.y + 1, layout.settingSpeed.width, max(0, layout.settingSpeed.height - 1))
            if (widgetHitTest(mouse, speedArea)) {
                _ = focus.focus("setting-speed")
                match (speedSelect.handleMouse(mouse, speedArea)) {
                    case Some(value) => applySpeed(value)
                    case None => ()
                }
                return UpdateResult.next()
            }
            if (activateButton(mouse, layout.settingPause, "setting-pause", "Pause")) { _ = focus.focus("setting-pause"); return perform("simulation.pause") }
            if (activateButton(mouse, layout.settingReset, "setting-reset", "Reset demo")) { _ = focus.focus("setting-reset"); return perform("demo.reset") }
        }
        UpdateResult.unchanged()
    }

    private func updateGalleryMouse(mouse: MouseEvent): UpdateResult {
        if (galleryTabs.handleMouse(mouse, layout.galleryNav)) {
            _ = focus.focus("gallery-tabs")
            syncFocus(true)
            return UpdateResult.next()
        }
        let category = galleryTabs.selected
        let areas = workbenchGalleryAreas(layout.galleryContent, category, sample: galleryDataTabs.selected)
        if (category == 0) {
            let labels = ["Forms", "Navigation", "Data", "Toast", "Dialog"]
            let ids = ["gallery-overview-forms", "gallery-overview-navigation", "gallery-overview-data", "gallery-overview-toast", "gallery-overview-dialog"]
            for (index in 0..min(labels.size, areas.buttons.size)) {
                if (galleryButton(this, labels[index], 1, ids[index]).handleMouse(mouse, areas.buttons[index])) {
                    _ = focus.focus(ids[index])
                    if (index == 0) { selectGalleryCategory(2) }
                    else if (index == 1) { selectGalleryCategory(3) }
                    else if (index == 2) { selectGalleryCategory(4) }
                    else if (index == 3) { pushGalleryToast("Info") }
                    else { openGalleryDialog() }
                    return UpdateResult.next()
                }
            }
        } else if (category == 1) {
            if (galleryButton(this, "ASCII fallback", 2, "gallery-ascii-toggle").handleMouse(mouse, areas.asciiToggle)) {
                _ = focus.focus("gallery-ascii-toggle")
                galleryAsciiFallback = !galleryAsciiFallback
                statusMessage = if (galleryAsciiFallback) { "ASCII border fallback enabled" } else { "Unicode borders enabled" }
                return UpdateResult.next()
            }
        } else if (category == 2) {
            let labels = ["Primary", "Secondary", "Ghost", "Danger", "Disabled"]
            let ids = ["gallery-button-primary", "gallery-button-secondary", "gallery-button-ghost", "gallery-button-danger", "gallery-button-disabled"]
            let variants: Array<Int64> = [0, 1, 2, 3, 4]
            for (index in 0..min(labels.size, areas.buttons.size)) {
                if (galleryButton(this, labels[index], variants[index], ids[index], disabled: variants[index] == 4).handleMouse(mouse, areas.buttons[index])) {
                    _ = focus.focus(ids[index])
                    statusMessage = labels[index] + " button activated"
                    pushGalleryToast("Success")
                    return UpdateResult.next()
                }
            }
            if (galleryInput.handleMouse(mouse, areas.formInputs[1])) {
                _ = focus.focus("gallery-input")
                return UpdateResult.next()
            }
            if (galleryCheckbox.handleMouse(mouse, areas.checkbox)) {
                _ = focus.focus("gallery-checkbox")
                statusMessage = if (galleryCheckbox.checked) { "Compact density enabled" } else { "Normal density enabled" }
                return UpdateResult.next()
            }
            if (let Some(value) <- gallerySelect.handleMouse(mouse, areas.select)) {
                _ = focus.focus("gallery-select")
                statusMessage = "Density: " + value
                return UpdateResult.next()
            }
            if (widgetHitTest(mouse, areas.select)) {
                _ = focus.focus("gallery-select")
                _ = gallerySelect.handleMouse(mouse, areas.select)
                return UpdateResult.next()
            }
        } else if (category == 3) {
            if (galleryNavigationTabs.handleMouse(mouse, areas.navTabs)) {
                _ = focus.focus("gallery-nav-tabs")
                return UpdateResult.next()
            }
            let menuBlock = galleryBlock(this, "Menu", BorderKind.Rounded)
            let menuArea = menuBlock.inner(areas.navMenu)
            if (widgetHitTest(mouse, menuArea)) {
                _ = focus.focus("gallery-nav-menu")
                match (galleryMenu.handleMouse(mouse, menuArea)) {
                    case Some(action) => statusMessage = "Menu action: " + action
                    case None => ()
                }
                return UpdateResult.next()
            }
            let treeBlock = galleryBlock(this, "Tree", BorderKind.Rounded)
            let treeArea = treeBlock.inner(areas.navTree)
            if (galleryTree.handle(mouse, treeArea)) {
                _ = focus.focus("gallery-nav-tree")
                match (galleryTree.selectedId()) {
                    case Some(id) => statusMessage = "Tree item: " + id
                    case None => ()
                }
                return UpdateResult.next()
            }
        } else if (category == 4) {
            if (galleryDataTabs.handleMouse(mouse, areas.dataSampleTabs)) {
                _ = focus.focus("gallery-data-sample-tabs")
                syncFocus(true)
                return UpdateResult.next()
            }
            if (galleryDataTabs.selected == 0) {
                let tableBlock = galleryBlock(this, "Table", BorderKind.Rounded)
                let tableArea = tableBlock.inner(areas.dataTable)
                if (widgetHitTest(mouse, tableArea) && galleryTable(this, tableArea.width).handleMouse(mouse, tableArea)) {
                    _ = focus.focus("gallery-data-table")
                    return UpdateResult.next()
                }
            } else if (galleryDataTabs.selected == 1) {
                let listBlock = galleryBlock(this, "List", BorderKind.Rounded)
                let listArea = listBlock.inner(areas.dataList)
                let list = CoreList(galleryListItems(), state: Some(galleryListState),
                    style: theme.normal, selectedStyle: theme.selected)
                if (list.handleMouse(mouse, listArea)) {
                    _ = focus.focus("gallery-data-list")
                    return UpdateResult.next()
                }
            }
        } else if (category == 5) {
            let labels = ["Success", "Warning", "Error", "Info"]
            let ids = ["gallery-toast-success", "gallery-toast-warning", "gallery-toast-error", "gallery-toast-info"]
            let variants: Array<Int64> = [0, 0, 3, 2]
            for (index in 0..min(labels.size, areas.buttons.size)) {
                if (galleryButton(this, labels[index], variants[index], ids[index]).handleMouse(mouse, areas.buttons[index])) {
                    _ = focus.focus(ids[index])
                    pushGalleryToast(labels[index])
                    return UpdateResult.next()
                }
            }
        } else if (category == 6) {
            if (galleryButton(this, "Palette", 1, "gallery-open-palette").handleMouse(mouse, areas.paletteButton)) {
                _ = focus.focus("gallery-open-palette")
                openPalette()
                return UpdateResult.next()
            }
            if (galleryButton(this, "Open confirmation", 1, "gallery-open-dialog").handleMouse(mouse, areas.dialogButton)) {
                _ = focus.focus("gallery-open-dialog")
                openGalleryDialog()
                return UpdateResult.next()
            }
        } else {
            if (widgetHitTest(mouse, areas.themeCapabilityPreview)) {
                _ = focus.focus("gallery-capability-preview")
                _ = galleryCapabilityPreview.handleMouse(mouse, areas.themeCapabilityPreview)
                refreshTheme()
                return UpdateResult.next()
            }
            if (galleryButton(this, "Theme", 1, "gallery-theme-toggle").handleMouse(mouse, areas.themeToggle)) {
                _ = focus.focus("gallery-theme-toggle")
                themeRadio.selected = if (darkTheme) { 1 } else { 0 }
                applyThemeSelection()
                return UpdateResult.next()
            }
            let accentArea = galleryRect(layout.galleryContent, 0, 6, min(36, layout.galleryContent.width), 1)
            if (accentPicker.handleMouse(mouse, accentArea)) {
                _ = focus.focus("gallery-accent")
                applyThemeSelection()
                return UpdateResult.next()
            }
        }
        UpdateResult.unchanged()
    }

    private func updateModalMouse(mouse: MouseEvent): UpdateResult {
        match (interaction.active()) {
            case Some("help") =>
                match (helpDialog.handleMouse(mouse, layout.dialog)) {
                    case Some(_) => closeModal()
                    case None => ()
                }
                UpdateResult.next()
            case Some("palette") =>
                match (palette.handleMouse(mouse, layout.palette)) {
                    case Some(action) =>
                        closeModal()
                        perform(action)
                    case None => UpdateResult.next()
                }
            case Some("gallery-dialog") =>
                galleryDialog.confirmed = interaction.focus().current() == Some("gallery-dialog-confirm")
                match (galleryDialog.handleMouse(mouse, layout.dialog)) {
                    case Some(accepted) =>
                        _ = interaction.focus().focus(if (accepted) { "gallery-dialog-confirm" } else { "gallery-dialog-cancel" })
                        finishGalleryDialog(accepted)
                    case None => UpdateResult.next()
                }
            case Some("editor") => routeEditorMouse(mouse)
            case Some("reset-confirm") =>
                match (resetDialog.handleMouse(mouse, layout.dialog)) {
                    case Some(action) => finishTaskReset(action)
                    case None =>
                        _ = interaction.focus().focus(if (resetDialog.selected == 1) { "confirm-reset" } else { "confirm-cancel" })
                        UpdateResult.next()
                }
            case Some("demo-confirm") =>
                match (demoResetDialog.handleMouse(mouse, layout.dialog)) {
                    case Some(action) => finishDemoReset(action)
                    case None =>
                        _ = interaction.focus().focus(if (demoResetDialog.selected == 1) { "demo-reset" } else { "demo-cancel" })
                        UpdateResult.next()
                }
            case _ => UpdateResult.unchanged()
        }
    }

    private func routeEditorMouse(mouse: MouseEvent): UpdateResult {
        if (capture.owns("editor-notes")) { return routeCapturedMouse(mouse) }
        if (!widgetHitTest(mouse, layout.editor)) { return UpdateResult.next() }
        if (widgetHitTest(mouse, layout.editorName)) {
            if (editorName.handleMouse(mouse, layout.editorName)) { _ = interaction.focus().focus("editor-name") }
            return UpdateResult.next()
        }
        let priorityArea = Rect(layout.editorPriority.x, layout.editorPriority.y + min(1, layout.editorPriority.height), layout.editorPriority.width, max(0, layout.editorPriority.height - 1))
        if (widgetHitTest(mouse, priorityArea)) {
            _ = editorPrioritySelect.handleMouse(mouse, priorityArea)
            _ = interaction.focus().focus("editor-priority")
            return UpdateResult.next()
        }
        if (widgetHitTest(mouse, layout.editorNotify) && editorNotify.handleMouse(mouse, layout.editorNotify)) {
            _ = interaction.focus().focus("editor-notify")
            return UpdateResult.next()
        }
        if (widgetHitTest(mouse, layout.editorTags) && editorTags.handleMouse(mouse, layout.editorTags)) {
            _ = interaction.focus().focus("editor-tags")
            return UpdateResult.next()
        }
        if (widgetHitTest(mouse, layout.editorNotes)) {
            if (editorNotes.handleMouse(mouse, layout.editorNotes)) {
                match ((mouse.kind, mouse.button)) {
                    case (MouseKind.Down, MouseButton.Left) => _ = capture.begin("editor-notes", mouse, layout.editorNotes)
                    case _ => ()
                }
                _ = interaction.focus().focus("editor-notes")
            }
            return UpdateResult.next()
        }
        if (activateButton(mouse, layout.editorCancel, "editor-cancel", "Cancel")) { closeModal(); return UpdateResult.next() }
        if (activateButton(mouse, layout.editorSave, "editor-save", "Save")) { return saveEditor() }
        UpdateResult.next()
    }

    private func routeCapturedMouse(mouse: MouseEvent): UpdateResult {
        match (capture.activeOwner()) {
            case Some("editor-notes") =>
                let normalized = match ((mouse.kind, mouse.button)) {
                    case (MouseKind.Up, MouseButton.None) => MouseEvent(MouseKind.Up, MouseButton.Left, mouse.x, mouse.y, modifiers: mouse.modifiers)
                    case _ => mouse
                }
                _ = editorNotes.handleMouse(normalized, layout.editorNotes)
                match (mouse.kind) {
                    case MouseKind.Up => _ = capture.release("editor-notes", mouse)
                    case _ => ()
                }
                return UpdateResult.next()
            case Some("task-scroll") =>
                _ = taskScrollbar().handleMouse(mouse, layout.taskScrollbar, taskScroll, capture, "task-scroll")
                taskState.offset = taskScroll.offset
                return UpdateResult.next()
            case Some("log-scroll") =>
                _ = logScrollbar().handleMouse(mouse, layout.logScrollbar, logScroll, capture, "log-scroll")
                syncLogFollowTail()
                return UpdateResult.next()
            case _ =>
                capture.cancel()
                return UpdateResult.unchanged()
        }
    }

    private func handleTableKey(key: KeyEvent): UpdateResult {
        let total = model.visibleIds().size
        let viewport = max(0, layout.taskTable.height - 2)
        match (key.code) {
            case KeyCode.Up => taskState.move(-1, total, viewportHeight: viewport)
            case KeyCode.Down => taskState.move(1, total, viewportHeight: viewport)
            case KeyCode.PageUp => taskState.move(-max(1, viewport), total, viewportHeight: viewport)
            case KeyCode.PageDown => taskState.move(max(1, viewport), total, viewportHeight: viewport)
            case KeyCode.Home => taskState.select(if (total > 0) { Some(0) } else { None }); taskState.offset = 0
            case KeyCode.End => taskState.select(if (total > 0) { Some(total - 1) } else { None }); taskState.scrollToVisible(total, viewport)
            case KeyCode.Enter => return perform("task.edit")
            case KeyCode.Char(r's') => sortBy((model.sortColumn + 1) % 5)
            case KeyCode.Char(r'S') => sortBy(model.sortColumn, forceToggle: true)
            case _ => return UpdateResult.unchanged()
        }
        syncSelectedFromTable()
        taskScroll.offset = taskState.offset
        UpdateResult.next()
    }

    private func updateTick(tick: TickEvent): UpdateResult {
        let delta = min(5000, max(0, tick.deltaMillis))
        if (delta == 0) { return UpdateResult.unchanged() }

        tickChangedIds.clear()
        var result = UpdateResult.unchanged()
        var simulationChanged = false
        var statusChanged = false
        var historyChanged = false
        var progressSampled = false
        let toastChanged = tickToasts(delta)
        var toastAdded = false
        var successChanged = false

        if (successRemaining > 0) {
            successRemaining = max(0, successRemaining - delta)
            if (successRemaining == 0) {
                successId = None
                successChanged = true
            }
        }

        var remaining = delta
        while (remaining > 0) {
            let step = min(remaining, 250 - sampleRemainder)
            if (!paused) {
                let scaledNumerator = step * simulationSpeed + speedRemainder
                let simulationDelta = scaledNumerator / 1000
                speedRemainder = scaledNumerator % 1000
                if (simulationDelta > 0 && model.advance(simulationDelta)) {
                    simulationChanged = true
                    model.appendAdvancedIds(tickChangedIds)
                    if (!model.completedIds.isEmpty()) {
                        statusChanged = true
                        for (id in model.completedIds) {
                            let task = model.jobs[id - 1]
                            let message = "Completed ${task.label()}"
                            recordActivity(message)
                            if (task.notify) {
                                pushToast(message, true)
                                toastAdded = true
                            }
                            if (selectedId == Some(id)) {
                                successId = Some(id)
                                successRemaining = 700
                                successChanged = true
                            }
                        }
                    }
                }
            }
            sampleRemainder += step
            if (sampleRemainder >= 250) {
                sampleRemainder -= 250
                model.sampleHistory(model.totalProgressHundredths())
                historyChanged = true
                progressSampled = true
            }
            remaining -= step
        }

        if (statusChanged) {
            statusMessage = "Task completed"
            refreshVisibleAfterProgress()
        } else if (progressSampled && simulationChanged && page == WorkbenchPage.Tasks && model.sortColumn == 4) {
            if (model.refreshProgressOrder()) { syncTableSelection() }
        }

        if (motionEnabled) {
            visualRemainder += delta
            let frames = visualRemainder / 120
            if (frames > 0) {
                visualRemainder %= 120
                spinnerFrame = (spinnerFrame + frames) % 4
                pipelineOffset = (pipelineOffset + frames) % max(1, layout.pipelineCanvas.width)
                if (page == WorkbenchPage.Overview && model.runningCount > 0 && !paused && interaction.active().isNone()) {
                    result = addDirty(result, layout.pipelinePanel)
                }
                if (page == WorkbenchPage.Showcase && galleryTabs.selected == 4 &&
                    galleryDataTabs.selected == 2 && model.runningCount > 0 && !paused && interaction.active().isNone()) {
                    let dataAreas = workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected)
                    result = addDirty(result, dataAreas.dataProgress)
                }
                result = addDirty(result, layout.title)
            }
            if (advanceDetailTween(delta) && page == WorkbenchPage.Tasks && interaction.active().isNone()) {
                result = addDirty(result, layout.taskDetail)
            }
        }

        if (successChanged && page == WorkbenchPage.Tasks && interaction.active().isNone()) {
            result = addDirty(result, layout.taskDetail)
        }
        if (simulationChanged && interaction.active().isNone()) {
            match (page) {
                case WorkbenchPage.Showcase =>
                    if (galleryTabs.selected == 4 && galleryDataTabs.selected == 2) {
                        let dataAreas = workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected)
                        result = addDirty(result, dataAreas.dataProgress)
                    } else if (galleryTabs.selected == 0) {
                        let overviewAreas = workbenchGalleryAreas(layout.galleryContent, 0)
                        result = addDirty(result, overviewAreas.dataProgress)
                    }
                case WorkbenchPage.Overview =>
                    result = addDirty(result, layout.overviewTop)
                    result = addDirty(result, layout.sparkPanel)
                case WorkbenchPage.Tasks =>
                    if (visibleChanged(tickChangedIds)) {
                        result = addDirty(result, layout.taskTableBlock)
                    }
                    if (containsId(tickChangedIds, selectedId)) {
                        result = addDirty(result, layout.taskDetail)
                    }
                case WorkbenchPage.Settings => ()
            }
        }
        if (historyChanged && interaction.active().isNone()) {
            if (page == WorkbenchPage.Overview) {
                result = addDirty(result, layout.sparkPanel)
            } else if (page == WorkbenchPage.Showcase && galleryTabs.selected == 4 &&
                galleryDataTabs.selected == 2) {
                let dataAreas = workbenchGalleryAreas(layout.galleryContent, 4, sample: galleryDataTabs.selected)
                result = addDirty(result, dataAreas.dataProgress)
            }
        }
        if (statusChanged) {
            result = addDirty(result, layout.status)
            if (interaction.active().isNone()) {
                if (page == WorkbenchPage.Overview) {
                    result = addDirty(result, layout.overviewTop)
                    result = addDirty(result, layout.chartPanel)
                    result = addDirty(result, layout.sparkPanel)
                    result = addDirty(result, layout.overviewBottom)
                    if (model.runningCount > 0 && !paused) { result = addDirty(result, layout.pipelinePanel) }
                } else if (page == WorkbenchPage.Tasks) {
                    result = addDirty(result, layout.taskTableBlock)
                    result = addDirty(result, layout.taskDetail)
                }
            }
        }
        if (toastChanged || toastAdded) {
            result = addDirty(result, layout.toast)
            if (page == WorkbenchPage.Showcase && galleryTabs.selected == 5) {
                result = addDirty(result, layout.galleryContent)
            }
        }
        result
    }

    private func addDirty(result: UpdateResult, area: Rect): UpdateResult {
        if (area.width <= 0 || area.height <= 0) { return result }
        result.withDirty(area)
    }

    private func containsId(ids: ArrayList<Int64>, target: ?Int64): Bool {
        match (target) {
            case Some(id) =>
                for (candidate in ids) {
                    if (candidate == id) { return true }
                }
                false
            case None => false
        }
    }

    private func visibleChanged(ids: ArrayList<Int64>): Bool {
        if (ids.isEmpty()) { return false }
        let visible = model.visibleIds()
        for (id in ids) {
            for (visibleId in visible) {
                if (visibleId == id) { return true }
            }
        }
        false
    }

    private func advanceDetailTween(delta: Int64): Bool {
        match (selectedId) {
            case Some(id) =>
                match (model.job(id)) {
                    case Some(task) =>
                        let target = task.progressPercent * 100
                        let before = detailProgress(id, target)
                        if (tweenId != Some(id) || target != tweenTarget) {
                            tweenFrom = detailProgress(id, tweenTarget)
                            tweenTarget = target
                            tweenId = Some(id)
                            tweenElapsed = 0
                            return true
                        }
                        if (tweenElapsed < 200) {
                            tweenElapsed = min(200, tweenElapsed + delta)
                        }
                        detailProgress(id, target) != before
                    case None => false
                }
            case None => false
        }
    }

    private func refreshVisibleAfterProgress(): Unit {
        if (model.sortColumn == 4) { _ = model.refreshProgressOrder() }
        syncTableSelection()
    }

    private func startSelected(): Unit {
        match (selectedId) {
            case Some(id) =>
                if (model.start(id)) {
                    let message = "Started job-${id}"
                    recordActivity(message)
                    statusMessage = message
                    pushToast(message, false)
                    syncTableSelection()
                } else {
                    statusMessage = if (model.runningCount >= 4) { "At most four tasks may run" } else { "Select a queued task to start" }
                }
            case None => statusMessage = "No task selected"
        }
    }

    private func openEditor(): Unit {
        match (selectedId) {
            case Some(id) =>
                match (model.job(id)) {
                    case Some(task) =>
                        editingId = Some(id)
                        editorName.setValue(task.name)
                        editorPrioritySelect.selected = priorityIndex(task.priority)
                        editorNotify.checked = task.notify
                        let indices = ArrayList<Int64>()
                        for (tag in task.tags) {
                            let index = tagIndex(tag)
                            if (index >= 0) { indices.add(index) }
                        }
                        editorTags = MultiSelect(["build", "test", "docs", "release"], selected: indices.toArray())
                        editorNotes.setValue(task.notes)
                        editorError = ""
                        _ = interaction.open("editor", ["editor-name", "editor-priority", "editor-notify", "editor-tags", "editor-notes", "editor-cancel", "editor-save"],
                            keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.F(1))], "help")]))
                        layout = workbenchLayout(screen, page)
                    case None => statusMessage = "Task no longer exists"
                }
            case None => statusMessage = "Select a task to edit"
        }
    }

    private func saveEditor(): UpdateResult {
        let name = editorName.value.trim()
        if (name.isEmpty()) {
            editorError = "Name cannot be empty"
            _ = interaction.focus().focus("editor-name")
            return UpdateResult.next()
        }
        match (editingId) {
            case Some(id) =>
                let tags = ArrayList<String>()
                for (index in editorTags.selectedIndices()) {
                    match (index) {
                        case 0 => tags.add("build")
                        case 1 => tags.add("test")
                        case 2 => tags.add("docs")
                        case 3 => tags.add("release")
                        case _ => ()
                    }
                }
                let priority = match (editorPrioritySelect.selected) {
                    case 0 => "Low"
                    case 1 => "Normal"
                    case 2 => "High"
                    case _ => "Critical"
                }
                if (model.setMetadata(id, name, priority, editorNotify.checked, tags.toArray(), editorNotes.value)) {
                    let message = "Updated job-${id}"
                    recordActivity(message)
                    statusMessage = message
                } else {
                    statusMessage = "Task details unchanged"
                }
                selectedId = Some(id)
                closeModal()
                applyTaskFilters()
                UpdateResult.next()
            case None =>
                closeModal()
                statusMessage = "No task selected"
                UpdateResult.next()
        }
    }

    private func openTaskReset(): Unit {
        if (!canReset()) { statusMessage = "Only running or completed tasks can be reset"; return }
        pendingResetId = selectedId
        resetDialog.selected = 0
        _ = interaction.open("reset-confirm", ["confirm-cancel", "confirm-reset"])
        layout = workbenchLayout(screen, page)
    }

    private func finishTaskReset(action: String): UpdateResult {
        if (action == "Reset") {
            match (pendingResetId) {
                case Some(id) =>
                    if (model.reset(id)) {
                        let message = "Reset job-${id}"
                        recordActivity(message)
                        statusMessage = message
                        if (successId == Some(id)) { successId = None; successRemaining = 0 }
                        syncTableSelection()
                    }
                case None => ()
            }
        }
        closeModal()
        pendingResetId = None
        UpdateResult.next()
    }

    private func openDemoReset(): Unit {
        demoResetDialog.selected = 0
        _ = interaction.open("demo-confirm", ["demo-cancel", "demo-reset"])
        layout = workbenchLayout(screen, page)
    }

    private func finishDemoReset(action: String): UpdateResult {
        if (action == "Reset") {
            taskFilter.cancelSelection()
            model = WorkbenchModel()
            toastAges.clear()
            toastItems.clear()
            toastManager = ToastManager()
            logFollowTail = true
            logScroll.offset = 0
            recordActivity("Local demo initialized: 120 tasks")
            model.sampleHistory(model.totalProgressHundredths())
            taskSearch.setValue("")
            taskFilter.selected = 0
            projectFilter = None
            _ = projects.selectById("all")
            tabs.selected = 0
            page = WorkbenchPage.Overview
            paused = false
            selectedId = Some(1)
            taskState.select(Some(0))
            taskState.offset = 0
            taskScroll.offset = 0
            logScroll.offset = 0
            successId = None
            successRemaining = 0
            editingId = None
            statusMessage = "Demo reset; preferences retained"
            speedRemainder = 0
            sampleRemainder = 0
            overviewFocus = None
            tasksFocus = Some("task-table")
            settingsFocus = Some("theme-radio")
            syncTableSelection()
        }
        closeModal()
        pendingResetId = None
        UpdateResult.next()
    }

    private func openHelp(): Unit {
        _ = interaction.open("help", ["help-close"])
        layout = workbenchLayout(screen, page)
    }

    private func openPalette(): Unit {
        palette.query = ""
        palette.selected = 0
        palette.offset = 0
        _ = interaction.open("palette", ["palette"])
        layout = workbenchLayout(screen, page)
    }

    private func openGalleryDialog(): Unit {
        galleryDialog.confirmed = false
        _ = interaction.open("gallery-dialog", ["gallery-dialog-cancel", "gallery-dialog-confirm"])
        _ = interaction.focus().focus("gallery-dialog-cancel")
        layout = workbenchLayout(screen, page)
    }

    private func finishGalleryDialog(accepted: Bool): UpdateResult {
        closeModal()
        if (accepted) {
            statusMessage = "Confirmation accepted"
            pushGalleryToast("Success")
        } else {
            statusMessage = "Confirmation declined"
        }
        UpdateResult.next()
    }

    private func closeModal(): Unit {
        let closed = interaction.close()
        modalClosed(closed)
        layout = workbenchLayout(screen, page)
    }

    private func modalClosed(id: ?String): Unit {
        if (id == Some("editor")) {
            cancelPointerCapture()
            editingId = None
            editorError = ""
        }
        if (id == Some("reset-confirm")) { pendingResetId = None }
        layout = workbenchLayout(screen, page)
    }

    private func switchPage(next: WorkbenchPage): Unit {
        taskFilter.cancelSelection()
        rememberCurrentFocus()
        page = next
        tabs.selected = match (next) {
            case WorkbenchPage.Showcase => 0
            case WorkbenchPage.Overview => 1
            case WorkbenchPage.Tasks => 2
            case WorkbenchPage.Settings => 3
        }
        layout = workbenchLayout(screen, page)
        syncFocus(false)
    }

    private func setPageFromTab(): Unit {
        let next = match (tabs.selected) {
            case 1 => WorkbenchPage.Overview
            case 2 => WorkbenchPage.Tasks
            case 3 => WorkbenchPage.Settings
            case _ => WorkbenchPage.Showcase
        }
        if (next != page) { switchPage(next) }
    }

    private func selectGalleryCategory(category: Int64): Unit {
        if (category < 0 || category > 7) { return }
        galleryTabs.selected = category
        _ = focus.focus("gallery-tabs")
        syncFocus(true)
    }

    private func syncFocus(preserveCurrent: Bool): Unit {
        let old = focus.current()
        if (preserveCurrent) { rememberCurrentFocus() }
        for (id in ["tabs", "gallery-tabs", "gallery-overview-forms", "gallery-overview-navigation", "gallery-overview-data", "gallery-overview-toast", "gallery-overview-dialog", "gallery-ascii-toggle", "gallery-button-primary", "gallery-button-secondary", "gallery-button-ghost", "gallery-button-danger", "gallery-button-disabled", "gallery-input", "gallery-checkbox", "gallery-select", "gallery-nav-tabs", "gallery-nav-menu", "gallery-nav-tree", "gallery-data-sample-tabs", "gallery-data-table", "gallery-data-list", "gallery-toast-success", "gallery-toast-warning", "gallery-toast-error", "gallery-toast-info", "gallery-open-palette", "gallery-open-dialog", "gallery-theme-toggle", "gallery-accent", "gallery-capability-preview", "projects", "log-view", "task-search", "task-filter", "task-run", "task-edit", "task-reset", "task-table", "theme-radio", "accent-picker", "setting-motion", "setting-speed", "setting-pause", "setting-reset"]) {
            focus.remove(id)
        }
        if (!layout.interactive) { return }
        focus.add("tabs")
        match (page) {
            case WorkbenchPage.Showcase =>
                focus.add("gallery-tabs")
                match (galleryTabs.selected) {
                    case 0 =>
                        focus.add("gallery-overview-forms")
                        focus.add("gallery-overview-navigation")
                        focus.add("gallery-overview-data")
                        focus.add("gallery-overview-toast")
                        focus.add("gallery-overview-dialog")
                    case 1 => focus.add("gallery-ascii-toggle")
                    case 2 =>
                        focus.add("gallery-button-primary")
                        focus.add("gallery-button-secondary")
                        focus.add("gallery-button-ghost")
                        focus.add("gallery-button-danger")
                        focus.add("gallery-button-disabled", enabled: false)
                        focus.add("gallery-input")
                        focus.add("gallery-checkbox")
                        focus.add("gallery-select")
                    case 3 =>
                        focus.add("gallery-nav-tabs")
                        focus.add("gallery-nav-menu")
                        focus.add("gallery-nav-tree")
                    case 4 =>
                        focus.add("gallery-data-sample-tabs")
                        match (galleryDataTabs.selected) {
                            case 0 => focus.add("gallery-data-table")
                            case 1 => focus.add("gallery-data-list")
                            case _ => ()
                        }
                    case 5 =>
                        focus.add("gallery-toast-success")
                        focus.add("gallery-toast-warning")
                        focus.add("gallery-toast-error")
                        focus.add("gallery-toast-info")
                    case 6 =>
                        focus.add("gallery-open-palette")
                        focus.add("gallery-open-dialog")
                    case _ =>
                        focus.add("gallery-theme-toggle")
                        focus.add("gallery-accent")
                        focus.add("gallery-capability-preview")
                }
            case WorkbenchPage.Overview =>
                if (layout.projectTree.width > 0) { focus.add("projects") }
                if (layout.logView.width > 0 && layout.logView.height > 0) { focus.add("log-view") }
            case WorkbenchPage.Tasks =>
                if (layout.projectTree.width > 0) { focus.add("projects") }
                focus.add("task-search")
                focus.add("task-filter")
                focus.add("task-run", enabled: canRun())
                focus.add("task-edit", enabled: selectedId.isSome())
                focus.add("task-reset", enabled: canReset())
                focus.add("task-table")
            case WorkbenchPage.Settings =>
                focus.add("theme-radio")
                focus.add("accent-picker")
                focus.add("setting-motion")
                focus.add("setting-speed")
                focus.add("setting-pause")
                focus.add("setting-reset")
        }
        let preferred = if (preserveCurrent) { old } else { rememberedFocus() }
        match (preferred) {
            case Some(id) => if (!focus.focus(id)) { focusFirst() }
            case None => focusFirst()
        }
    }

    private func focusFirst(): Unit {
        match (page) {
            case WorkbenchPage.Showcase => _ = focus.focus("tabs")
            case WorkbenchPage.Overview => _ = focus.focus("tabs")
            case WorkbenchPage.Tasks => _ = focus.focus("tabs")
            case WorkbenchPage.Settings => _ = focus.focus("tabs")
        }
    }

    private func rememberCurrentFocus(): Unit {
        match (focus.current()) {
            case Some(id) =>
                match (page) {
                    case WorkbenchPage.Overview => overviewFocus = Some(id)
                    case WorkbenchPage.Showcase => showcaseFocus = Some(id)
                    case WorkbenchPage.Tasks => tasksFocus = Some(id)
                    case WorkbenchPage.Settings => settingsFocus = Some(id)
                }
            case None => ()
        }
    }

    private func rememberedFocus(): ?String {
        match (page) {
            case WorkbenchPage.Showcase => showcaseFocus
            case WorkbenchPage.Overview => overviewFocus
            case WorkbenchPage.Tasks => tasksFocus
            case WorkbenchPage.Settings => settingsFocus
        }
    }


    private func setProject(project: ?String): Unit {
        projectFilter = project
        let treeId = match (project) {
            case Some("Alpha") => "project-alpha"
            case Some("Beta") => "project-beta"
            case Some("Gamma") => "project-gamma"
            case _ => "all"
        }
        _ = projects.selectById(treeId)
        applyTaskFilters()
        statusMessage = match (project) {
            case Some(name) => "Project: " + name
            case None => "All projects"
        }
    }

    private func applyTreeProject(): Unit {
        let selectedProject: ?String = match (projects.selectedId()) {
            case Some("project-alpha") => Some("Alpha")
            case Some("project-beta") => Some("Beta")
            case Some("project-gamma") => Some("Gamma")
            case _ => None
        }
        setProject(selectedProject)
    }

    private func applyTaskFilters(): Unit {
        let statusFilter: ?WorkbenchJobStatus = match (taskFilter.selected) {
            case 1 => Some(WorkbenchJobStatus.Queued)
            case 2 => Some(WorkbenchJobStatus.Running)
            case 3 => Some(WorkbenchJobStatus.Done)
            case _ => None
        }
        let oldSelected = selectedId
        let changed = model.setQuery(taskSearch.value, projectFilter, statusFilter)
        if (changed) {
            match (oldSelected) {
                case Some(id) =>
                    if (visibleIndex(id) < 0) { selectedId = None }
                case None => ()
            }
            syncTableSelection()
        }
        syncFocus(true)
    }

    private func filterLabel(): String {
        match (taskFilter.selected) {
            case 1 => "Queued"
            case 2 => "Running"
            case 3 => "Done"
            case _ => "All"
        }
    }

    private func syncTableSelection(): Unit {
        let ids = model.visibleIds()
        let index = match (selectedId) {
            case Some(id) => visibleIndex(id)
            case None => -1
        }
        if (ids.isEmpty()) {
            selectedId = None
            let noRow: ?Int64 = None
            taskState.select(noRow)
            taskState.offset = 0
            taskScroll.offset = 0
            syncFocus(true)
            return
        }
        if (index < 0) {
            selectedId = Some(ids[0])
            taskState.select(Some(0))
        } else {
            taskState.select(Some(index))
        }
        taskState.scrollToVisible(ids.size, max(0, layout.taskTable.height - 2))
        taskScroll.offset = taskState.offset
        setTweenTargetForSelection()
        syncFocus(true)
    }

    private func syncSelectedFromTable(): Unit {
        let ids = model.visibleIds()
        match (taskState.selectedRow) {
            case Some(row) =>
                if (row >= 0 && row < ids.size) {
                    selectedId = Some(ids[row])
                    setTweenTargetForSelection()
                } else {
                    selectedId = None
                }
            case _ => selectedId = None
        }
        syncFocus(true)
    }

    private func setTweenTargetForSelection(): Unit {
        match (selectedId) {
            case Some(id) =>
                match (model.job(id)) {
                    case Some(task) =>
                        let target = task.progressPercent * 100
                        if (tweenId != Some(id)) {
                            tweenId = Some(id)
                            tweenFrom = target
                            tweenTarget = target
                            tweenElapsed = 200
                        } else if (tweenTarget != target) {
                            tweenFrom = detailProgress(id, tweenTarget)
                            tweenTarget = target
                            tweenElapsed = if (motionEnabled) { 0 } else { 200 }
                        }
                    case None => ()
                }
            case None => tweenId = None; tweenElapsed = 200
        }
    }

    private func visibleIndex(id: Int64): Int64 {
        let ids = model.visibleIds()
        for (index in 0..ids.size) { if (ids[index] == id) { return index } }
        -1
    }

    private func sortBy(column: Int64, forceToggle!: Bool = false): Unit {
        if (column < 0 || column > 4) { return }
        let selected = selectedId
        let descending = if (forceToggle || model.sortColumn == column) { !model.sortDescending } else { false }
        if (model.sortBy(column, descending: descending)) {
            selectedId = selected
            syncTableSelection()
            statusMessage = "Sorted by ${sortLabel(column)} ${if (descending) { "descending" } else { "ascending" }}"
        }
    }

    private func sortLabel(column: Int64): String {
        match (column) {
            case 0 => "ID"
            case 1 => "Name"
            case 2 => "Project"
            case 3 => "Status"
            case _ => "Progress"
        }
    }

    private func headerColumn(x: Int64): Int64 {
        let widths = layoutTableWidths()
        var start = layout.taskTable.x
        for (column in 0..widths.size) {
            let end = start + widths[column]
            if (x >= start && x < end) { return column }
            start = end + 1
        }
        -1
    }

    private func tableWidget(): Table {
        Table(["ID", "Name", "Project", "Status", "Progress"], model.visibleRows(),
            widths: layoutTableWidths(), state: Some(taskState), style: theme.normal,
            headerStyle: theme.accent, selectedStyle: selectedStyle())
    }

    private func taskScrollbar(): Scrollbar {
        Scrollbar(model.visibleIds().size, offset: taskScroll.offset,
            viewport: max(0, layout.taskTable.height - 2), style: theme.disabled, thumbStyle: theme.accent)
    }

    private func logScrollbar(): Scrollbar {
        Scrollbar(model.logs().size, offset: logScroll.offset,
            viewport: max(0, layout.logView.height - 2), style: theme.disabled, thumbStyle: theme.accent)
    }

    private func activateButton(mouse: MouseEvent, area: Rect, id: String, label: String): Bool {
        if (!widgetHitTest(mouse, area)) { return false }
        match (id) {
            case "task-run" => Button(label, disabled: !canRun()).handleMouse(mouse, area)
            case "task-edit" => Button(label, disabled: selectedId.isNone()).handleMouse(mouse, area)
            case "task-reset" => Button(label, disabled: !canReset()).handleMouse(mouse, area)
            case _ => Button(label).handleMouse(mouse, area)
        }
    }

    private func applyThemeSelection(): Unit {
        darkTheme = themeRadio.selected == 0
        refreshTheme()
        statusMessage = if (darkTheme) { "Dark theme" } else { "Light theme" }
    }

    private func refreshTheme(): Unit {
        let effective = effectiveCapabilities()
        let accent = selectedAccent()
        theme = Theme.forCapabilities(effective, dark: darkTheme, accent: accent)
        surfaceStyle = adaptStyleForCapabilities(workbenchSurfaceStyle(darkTheme), effective)
        secondaryStyle = adaptStyleForCapabilities(workbenchSecondaryStyle(darkTheme), effective)
        borderStyle = adaptStyleForCapabilities(workbenchBorderStyle(darkTheme), effective)
        accentButtonStyle = adaptStyleForCapabilities(
            Style(fg: accentForeground(accent), bg: accent),
            effective
        )
        palette.setTheme(Some(theme))
        galleryDialog.setTheme(Some(theme))
        helpDialog.setTheme(Some(theme))
        resetDialog.setTheme(Some(theme))
        demoResetDialog.setTheme(Some(theme))
    }

    func actualColorTier(): Int64 {
        colorCapabilityTier(capabilities)
    }

    func effectiveColorTier(): Int64 {
        let requested = match (galleryCapabilityPreview.selected) {
            case 1 => 2
            case 2 => 1
            case 3 => 0
            case _ => 3
        }
        min(actualColorTier(), requested)
    }

    private func effectiveCapabilities(): TerminalCapabilities {
        let tier = effectiveColorTier()
        if (tier == actualColorTier()) { return capabilities }
        capabilitiesForColorTier(capabilities, tier)
    }

    private func selectedAccent(): Color {
        match (accentPicker.selectedColor()) {
            case Some(color) => color
            case None => Color.Cyan
        }
    }

    private func applySpeed(value: String): Unit {
        simulationSpeed = match (value) {
            case "0.5x" => 500
            case "2x" => 2000
            case _ => 1000
        }
        speedRemainder = 0
        statusMessage = "Task speed: " + value
    }


    private func pushToast(message: String, success: Bool): Unit {
        pushStyledToast(message, if (success) { theme.success } else { theme.error })
    }

    private func pushGalleryToast(severity: String): Unit {
        let symbol = match (severity) {
            case "Success" => "+"
            case "Warning" => "!"
            case "Error" => "x"
            case _ => "i"
        }
        let style = match (severity) {
            case "Success" => theme.success
            case "Warning" => theme.warning
            case "Error" => theme.error
            case _ => theme.info
        }
        pushStyledToast(symbol + " " + severity + " notification", style)
    }

    private func pushStyledToast(message: String, style: Style): Unit {
        if (toastItems.size >= 8) {
            toastItems.remove(at: 0)
            toastAges.remove(at: 0)
        }
        toastItems.add(Toast(message, ttl: 3, style: style))
        toastAges.add(0)
        rebuildToastManager()
    }

    private func tickToasts(delta: Int64): Bool {
        if (toastItems.isEmpty() || delta <= 0) { return false }
        let elapsed = min(3000, delta)
        var index = toastItems.size
        var expired = false
        while (index > 0) {
            index--
            let age = toastAges[index] + elapsed
            if (age >= 3000) {
                toastItems.remove(at: index)
                toastAges.remove(at: index)
                expired = true
            } else {
                toastAges[index] = age
            }
        }
        if (expired) { rebuildToastManager() }
        expired
    }

    private func rebuildToastManager(): Unit {
        let visible = ArrayList<Toast>()
        for (index in 0..toastItems.size) {
            let toast = toastItems[index]
            let remaining = max(1, (3000 - toastAges[index] + 999) / 1000)
            visible.add(Toast(toast.message, ttl: remaining, style: toast.style))
        }
        toastManager = ToastManager(toasts: visible.toArray())
    }

    private func recordActivity(message: String): Unit {
        model.recordLog(message)
        if (logFollowTail) {
            let viewport = max(0, layout.logView.height - 2)
            logScroll.offset = max(0, model.logs().size - viewport)
        }
    }

    private func syncLogFollowTail(): Unit {
        let viewport = max(0, layout.logView.height - 2)
        let total = model.logs().size
        let end = max(0, total - viewport)
        logScroll.offset = max(0, min(logScroll.offset, end))
        logFollowTail = logScroll.offset >= end
    }
    private func cancelPointerCapture(): Unit {
        if (capture.owns("editor-notes")) {
            _ = editorNotes.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 0, 0), layout.editorNotes)
        }
        capture.cancel()
    }
}

func colorCapabilityTier(capabilities: TerminalCapabilities): Int64 {
    if (capabilities.trueColor) { return 3 }
    if (capabilities.colorLevel >= 256) { return 2 }
    if (capabilities.colorLevel >= 8) { return 1 }
    0
}

func colorCapabilityLabel(tier: Int64): String {
    match (tier) {
        case 3 => "true-color"
        case 2 => "xterm-256"
        case 1 => "ANSI-8"
        case _ => "monochrome"
    }
}

func capabilitiesForColorTier(source: TerminalCapabilities, tier: Int64): TerminalCapabilities {
    let trueColor = tier >= 3
    let colorLevel = if (trueColor) { 24 } else if (tier == 2) { 256 } else if (tier == 1) { 8 } else { 1 }
    TerminalCapabilities(
        size: source.size,
        trueColor: trueColor,
        colorLevel: colorLevel,
        mouse: source.mouse,
        mouseMove: source.mouseMove,
        focusEvents: source.focusEvents,
        bracketedPaste: source.bracketedPaste,
        alternateScreen: source.alternateScreen,
        unicode: source.unicode,
        kittyGraphics: source.kittyGraphics,
        sixel: source.sixel,
        osc8: source.osc8,
        keyboardProtocol: source.keyboardProtocol,
        keyUp: source.keyUp,
        keyRepeat: source.keyRepeat,
        recommendedFps: source.recommendedFps,
        cellWidthPixels: source.cellWidthPixels,
        cellHeightPixels: source.cellHeightPixels,
        driverName: source.driverName
    )
}

func workbenchSurfaceStyle(dark: Bool): Style {
    if (dark) {
        Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(27, 32, 38))
    } else {
        Style(fg: Color.Rgb(31, 41, 51), bg: Color.Rgb(255, 255, 255))
    }
}

func workbenchSecondaryStyle(dark: Bool): Style {
    if (dark) {
        Style(fg: Color.Rgb(169, 180, 191), bg: Color.Rgb(18, 21, 26))
    } else {
        Style(fg: Color.Rgb(78, 91, 106), bg: Color.Rgb(247, 249, 252))
    }
}

func workbenchBorderStyle(dark: Bool): Style {
    if (dark) {
        Style(fg: Color.Rgb(62, 76, 88), bg: Color.Rgb(18, 21, 26))
    } else {
        Style(fg: Color.Rgb(186, 198, 209), bg: Color.Rgb(247, 249, 252))
    }
}

func accentForeground(color: Color): Color {
    match (color) {
        case Color.Red | Color.Blue | Color.Magenta => Color.White
        case Color.Rgb(r, g, b) =>
            let luminance = UInt64(r) * 2126 + UInt64(g) * 7152 + UInt64(b) * 722
            if (luminance > 1400000) { Color.Black } else { Color.White }
        case _ => Color.Black
    }
}




func priorityIndex(priority: String): Int64 {
    match (priority) {
        case "Low" => 0
        case "High" => 2
        case "Critical" => 3
        case _ => 1
    }
}

func tagIndex(tag: String): Int64 {
    match (tag) {
        case "build" => 0
        case "test" => 1
        case "docs" => 2
        case "release" => 3
        case _ => -1
    }
}
