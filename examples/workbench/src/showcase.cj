package cjtui_workbench

import core.*
import std.collection.*
import core.List as CoreList

func renderShowcase(app: WorkbenchApp, frame: Frame): Unit {
    let layout = app.layout
    if (frame.isDirty(layout.galleryNav)) {
        frame.fill(layout.galleryNav, app.theme.normal)
        let categories = Tabs(
            ["Overview", "Layout", "Forms", "Navigation", "Data", "Feedback", "Overlays", "Themes"],
            selected: app.galleryTabs.selected,
            selectedStyle: Style.default()
        )
        categories.setTheme(Some(app.theme))
        categories.setFocused(app.focus.isFocused("gallery-tabs"))
        frame.renderWidget(categories, layout.galleryNav)
    }
    if (!frame.isDirty(layout.galleryContent) || layout.galleryContent.width <= 0 || layout.galleryContent.height <= 0) { return }
    frame.fill(layout.galleryContent, app.theme.normal)
    let areas = workbenchGalleryAreas(layout.galleryContent, app.galleryTabs.selected, sample: app.galleryDataTabs.selected)
    frame.renderWidget(Paragraph(galleryCategoryTitle(app.galleryTabs.selected), style: app.theme.accent), areas.title)
    frame.renderWidget(Paragraph(galleryCategoryDescription(app.galleryTabs.selected), style: app.secondaryStyle), areas.description)
    match (app.galleryTabs.selected) {
        case 0 => renderGalleryOverview(app, frame, areas)
        case 1 => renderGalleryLayout(app, frame, areas)
        case 2 => renderGalleryForms(app, frame, areas)
        case 3 => renderGalleryNavigation(app, frame, areas)
        case 4 => renderGalleryData(app, frame, areas)
        case 5 => renderGalleryFeedback(app, frame, areas)
        case 6 => renderGalleryOverlays(app, frame, areas)
        case _ => renderGalleryThemes(app, frame, areas)
    }
    if (app.galleryTabs.selected == 2 && app.focus.current() == Some("gallery-input")) {
        frame.setCursor(app.galleryInput.cursorPosition(areas.formInputs[1]))
    }
}

func galleryCategoryTitle(category: Int64): String {
    match (category) {
        case 0 => "Overview  /  Graphite + Cyan"
        case 1 => "Layout  /  Borders and surfaces"
        case 2 => "Forms  /  Editable control states"
        case 3 => "Navigation  /  Segments, tabs, menu, tree"
        case 4 => "Data  /  Table, list, progress"
        case 5 => "Feedback  /  Toast lifecycle"
        case 6 => "Overlays  /  ConfirmDialog and command palette"
        case _ => "Themes  /  palette and terminal color tiers"
    }
}

func galleryCategoryDescription(category: Int64): String {
    match (category) {
        case 0 => "Semantic colors, comfortable density, and real component previews."
        case 1 => "Rounded Unicode panels, borderless surfaces, and an ASCII fallback toggle."
        case 2 => "Tab to controls; toggle the checkbox or Switch, type in the field, or change the select."
        case 3 => "Select a density with Segments; the preview value follows keyboard or mouse input."
        case 5 => "Semantic severity markers use Theme roles and the shared three-second toast lifetime."
        case 6 => "Open a real confirmation; Escape closes it, Tab moves between actions."
        case _ => "Switch dark/light and accent; preview only the terminal's actual or lower color tier."
    }
}

func renderGalleryOverview(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    let labels = ["Forms", "Navigation", "Data", "Toast", "Dialog"]
    let ids = ["gallery-overview-forms", "gallery-overview-navigation", "gallery-overview-data", "gallery-overview-toast", "gallery-overview-dialog"]
    for (index in 0..min(labels.size, areas.buttons.size)) {
        frame.renderWidget(galleryButton(app, labels[index], 1, ids[index]), areas.buttons[index])
    }
    let panelText = ["Accent-led controls\nFocused and disabled states", "Rounded panels\nSubtle cell borders", "Clipped to cells\nUnicode and ASCII paths"]
    for (index in 0..min(panelText.size, areas.panels.size)) {
        let panel = Panel(
            block: galleryBlock(app, ["Forms", "Surfaces", "Terminal-native"][index], BorderKind.Rounded),
            child: Some(Paragraph(panelText[index], style: app.theme.normal))
        )
        frame.renderWidget(panel, areas.panels[index])
    }
    let progress = app.model.totalProgressHundredths()
    frame.renderWidget(Gauge(progress, total: 10000, label: formatPercent(progress),
        style: app.theme.disabled, fillStyle: app.theme.info), areas.dataProgress)
}

func renderGalleryLayout(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    let titles = ["Rounded", "No border", "ASCII fallback"]
    let kinds = [BorderKind.Rounded, BorderKind.NoBorder, BorderKind.Unicode]
    let descriptions = ["Unicode corners", "Surface only", if (app.galleryAsciiFallback) { "ASCII: on" } else { "ASCII: off" }]
    for (index in 0..min(areas.panels.size, titles.size)) {
        let block = galleryBlock(app, titles[index], kinds[index], asciiFallback: index == 2 && app.galleryAsciiFallback)
        frame.renderWidget(Panel(block: block, child: Some(Paragraph(descriptions[index], style: app.theme.normal))), areas.panels[index])
    }
    frame.renderWidget(galleryButton(app, if (app.galleryAsciiFallback) { "ASCII fallback: on" } else { "ASCII fallback: off" },
        2, "gallery-ascii-toggle"), areas.asciiToggle)
    let panel = Panel(
        block: galleryBlock(app, "Panel composition", BorderKind.Rounded),
        child: Some(Paragraph("Panel = Block + child widget; clipping stays inside the terminal-cell rectangle.", style: app.theme.normal))
    )
    frame.renderWidget(panel, areas.layoutSample)
}

func renderGalleryForms(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    renderGalleryButtonRow(app, frame, areas, ["Primary", "Secondary", "Ghost", "Danger", "Disabled"],
        ["gallery-button-primary", "gallery-button-secondary", "gallery-button-ghost", "gallery-button-danger", "gallery-button-disabled"], [0, 1, 2, 3, 4])
    let labels = ["Normal · preview", "Focused · editable", "Error · preview", "Disabled · preview"]
    for (index in 0..min(labels.size, areas.formLabels.size)) {
        frame.renderWidget(Paragraph(labels[index], style: app.theme.disabled), areas.formLabels[index])
    }
    let normalInput = Input(value: "Ready", placeholder: "Normal")
    normalInput.setVisualState(theme: Some(app.theme))
    frame.renderWidget(normalInput, areas.formInputs[0])

    app.galleryInput.setVisualState(focused: app.focus.isFocused("gallery-input"), theme: Some(app.theme))
    frame.renderWidget(app.galleryInput, areas.formInputs[1])

    let errorInput = Input(value: "Check this value", placeholder: "Error")
    errorInput.setVisualState(error: true, theme: Some(app.theme))
    frame.renderWidget(errorInput, areas.formInputs[2])

    let disabledInput = Input(value: "Read only", placeholder: "Disabled")
    disabledInput.setVisualState(disabled: true, theme: Some(app.theme))
    frame.renderWidget(disabledInput, areas.formInputs[3])
    frame.renderWidget(Checkbox("Compact density", checked: app.galleryCheckbox.checked,
        focused: app.focus.isFocused("gallery-checkbox"), style: app.theme.normal,
        focusedStyle: app.theme.focused, disabledStyle: app.theme.disabled, theme: Some(app.theme)), areas.checkbox)
    let select = Select(["Compact", "Normal", "Comfortable"], selected: app.gallerySelect.selected,
        style: app.theme.normal, selectedStyle: app.theme.selected)
    frame.renderWidget(select, areas.select)
    app.gallerySwitch.setVisualState(focused: app.focus.isFocused("gallery-switch"), theme: Some(app.theme))
    frame.renderWidget(app.gallerySwitch, areas.switchControl)
    let switchState = if (app.gallerySwitch.checked) { "on" } else { "off" }
    frame.renderWidget(Paragraph("Auto sync: ${switchState}", style: app.secondaryStyle), areas.switchValue)
}

func renderGalleryNavigation(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    let tabs = Tabs(["Overview", "Sources", "Output"], selected: app.galleryNavigationTabs.selected,
        selectedStyle: Style.default())
    tabs.setTheme(Some(app.theme))
    tabs.setFocused(app.focus.isFocused("gallery-nav-tabs"))
    frame.renderWidget(tabs, areas.navTabs)
    app.galleryNavigationSegments.setVisualState(
        focused: app.focus.isFocused("gallery-nav-segments"),
        theme: Some(app.theme)
    )
    frame.renderWidget(app.galleryNavigationSegments, areas.navSegments)
    let density = match (app.galleryNavigationSegments.selectedValue()) {
        case Some(value) => value
        case None => "none"
    }
    frame.renderWidget(Paragraph("Preview density: " + density, style: app.secondaryStyle), areas.navSegmentValue)

    let menuBlock = galleryBlock(app, "Menu", BorderKind.Rounded, focused: app.focus.isFocused("gallery-nav-menu"))
    let menuArea = menuBlock.inner(areas.navMenu)
    frame.renderWidget(menuBlock, areas.navMenu)
    let menu = Menu("Actions", [
        MenuItem("Open item", action: "open"),
        MenuItem("Rename", action: "rename"),
        MenuItem("Unavailable", action: "disabled", enabled: false)
    ], selected: app.galleryMenu.selected, style: app.theme.normal, selectedStyle: app.theme.selected, disabledStyle: app.theme.disabled)
    frame.renderWidget(menu, menuArea)

    let treeBlock = galleryBlock(app, "Tree", BorderKind.Rounded, focused: app.focus.isFocused("gallery-nav-tree"))
    let treeArea = treeBlock.inner(areas.navTree)
    frame.renderWidget(treeBlock, areas.navTree)
    let tree = Tree(app.galleryTreeNodes, selected: app.galleryTree.selected, style: app.theme.normal, selectedStyle: app.theme.selected)
    frame.renderWidget(tree, treeArea)
}

func renderGalleryData(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    let sampleTabs = Tabs(["Table", "List", "Progress"], selected: app.galleryDataTabs.selected,
        selectedStyle: Style.default())
    sampleTabs.setTheme(Some(app.theme))
    sampleTabs.setFocused(app.focus.isFocused("gallery-data-sample-tabs"))
    frame.renderWidget(sampleTabs, areas.dataSampleTabs)

    if (app.galleryDataTabs.selected == 0) {
        let tableBlock = galleryBlock(app, "Table", BorderKind.Rounded, focused: app.focus.isFocused("gallery-data-table"))
        let tableArea = tableBlock.inner(areas.dataTable)
        frame.renderWidget(tableBlock, areas.dataTable)
        frame.renderWidget(galleryTable(app, tableArea.width), tableArea)
    } else if (app.galleryDataTabs.selected == 1) {
        let listBlock = galleryBlock(app, "List", BorderKind.Rounded, focused: app.focus.isFocused("gallery-data-list"))
        let listArea = listBlock.inner(areas.dataList)
        frame.renderWidget(listBlock, areas.dataList)
        let list = CoreList(galleryListItems(), state: Some(app.galleryListState),
            style: app.theme.normal, selectedStyle: app.theme.selected)
        frame.renderWidget(list, listArea)
    } else {
        let dataProgress = areas.dataProgress
        let progress = app.model.totalProgressHundredths()
        if (dataProgress.height > 0) {
            frame.renderWidget(Gauge(progress, total: 10000, label: formatPercent(progress),
                style: app.theme.disabled, fillStyle: app.theme.accent),
                Rect(dataProgress.x, dataProgress.y, dataProgress.width, 1))
        }
        if (dataProgress.height > 1) {
            frame.renderWidget(Paragraph("Weighted progress · all 120 local tasks", style: app.theme.disabled),
                Rect(dataProgress.x, dataProgress.y + 1, dataProgress.width, 1))
        }
        if (dataProgress.height > 2) {
            frame.renderWidget(Sparkline(app.model.history(), style: app.theme.accent),
                Rect(dataProgress.x, dataProgress.y + 2, dataProgress.width, 1))
        }
    }
}

func galleryTableRows(): Array<Array<String>> {
    [
        ["01", "Button", "Ready"],
        ["02", "Input", "Focused"],
        ["03", "Tabs", "Active"],
        ["04", "Toast", "Idle"],
        ["05", "Block", "Rounded"],
        ["06", "Checkbox", "Checked"],
        ["07", "Select", "Selected"],
        ["08", "Menu", "Enabled"],
        ["09", "Tree", "Expanded"],
        ["10", "Table", "Selected"],
        ["11", "List", "Selected"],
        ["12", "Gauge", "83%"],
        ["13", "Dialog", "Modal"],
        ["14", "Palette", "Ready"],
        ["15", "Theme", "Cyan"],
        ["16", "Canvas", "Styled"],
        ["17", "Command", "Ready"],
        ["18", "Spinner", "Idle"],
        ["19", "Prompt", "Normal"],
        ["20", "Progress", "0.83%"]
    ]
}

func galleryListItems(): Array<String> {
    ["Runtime", "Standard library", "Samples", "Docs", "Tests", "Block", "Button",
        "Input", "Checkbox", "Select", "Tabs", "Menu", "Tree", "Table", "List",
        "Gauge", "Toast", "Dialog", "Palette", "Canvas"]
}

func galleryTable(app: WorkbenchApp, width: Int64): Table {
    let innerWidth = max(0, width)
    let nameWidth = min(12, max(0, innerWidth - 12))
    let stateWidth = max(0, innerWidth - 13 - nameWidth)
    Table(["ID", "Component", "State"], galleryTableRows(),
        widths: [min(6, innerWidth), nameWidth, stateWidth], state: Some(app.galleryTableState),
        style: app.theme.normal, headerStyle: app.theme.accent, selectedStyle: app.theme.selected)
}

func renderGalleryFeedback(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    renderGalleryButtonRow(app, frame, areas, ["Success", "Warning", "Error", "Info"],
        ["gallery-toast-success", "gallery-toast-warning", "gallery-toast-error", "gallery-toast-info"], [0, 1, 3, 2])
    let toastBlock = galleryBlock(app, "ToastManager · 3s", BorderKind.Rounded)
    let toastArea = toastBlock.inner(areas.toasts)
    frame.renderWidget(toastBlock, areas.toasts)
    if (app.toastManager.count() == 0) {
        frame.renderWidget(Paragraph("Choose a severity to create a real toast.", style: app.theme.disabled), toastArea)
    } else {
        frame.renderWidget(app.toastManager, toastArea)
    }
}

func renderGalleryOverlays(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    frame.renderWidget(galleryButton(app, "Palette · F2", 1, "gallery-open-palette"), areas.paletteButton)
    frame.renderWidget(galleryButton(app, "Open confirmation", 1, "gallery-open-dialog"), areas.dialogButton)
    frame.renderWidget(Paragraph("F2 search ignores case; disabled commands stay visible.", style: app.theme.normal),
        galleryRect(app.layout.galleryContent, 0, 5, app.layout.galleryContent.width, 1))
    frame.renderWidget(Paragraph("No matches is explicit; ConfirmDialog closes its focus scope.", style: app.theme.disabled),
        galleryRect(app.layout.galleryContent, 0, 6, app.layout.galleryContent.width, 1))
}

func renderGalleryThemes(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas): Unit {
    frame.renderWidget(galleryButton(app, if (app.darkTheme) { "Switch to Light" } else { "Switch to Graphite" },
        1, "gallery-theme-toggle"), areas.themeToggle)
    frame.renderWidget(Paragraph("Accent", style: app.theme.disabled), areas.themeAccent)
    renderWorkbenchAccentPicker(app, frame, galleryRect(app.layout.galleryContent, 0, 6, min(36, app.layout.galleryContent.width), 1))
    frame.renderWidget(
        Paragraph(
            "Terminal: ${colorCapabilityLabel(app.actualColorTier())} · preview: ${colorCapabilityLabel(app.effectiveColorTier())}",
            style: app.secondaryStyle
        ),
        areas.themeCapabilityLabel
    )
    let capabilityPreview = Select(
        ["Native", "xterm-256", "ANSI-8", "Monochrome"],
        selected: app.galleryCapabilityPreview.selected,
        style: app.theme.normal,
        selectedStyle: app.theme.selected
    )
    frame.renderWidget(capabilityPreview, areas.themeCapabilityPreview)
    let labels = ["Primary text", "Secondary text", "Disabled", "Success", "Warning"]
    let styles = [app.theme.normal, app.secondaryStyle, app.theme.disabled,
        app.theme.success, app.theme.warning]
    for (index in 0..min(areas.themeSamples.size, labels.size)) {
        frame.renderWidget(Paragraph(labels[index], style: styles[index]), areas.themeSamples[index])
    }
}

func renderGalleryButtonRow(app: WorkbenchApp, frame: Frame, areas: WorkbenchGalleryAreas,
    labels: Array<String>, ids: Array<String>, variants: Array<Int64>): Unit {
    let count = min(labels.size, min(ids.size, min(variants.size, areas.buttons.size)))
    for (index in 0..count) {
        frame.renderWidget(galleryButton(app, labels[index], variants[index], ids[index], disabled: variants[index] == 4), areas.buttons[index])
    }
}

func galleryButton(app: WorkbenchApp, label: String, variant: Int64, id: String, disabled!: Bool = false): Button {
    let style = match (variant) {
        case 0 => app.accentButtonStyle
        case 1 => app.surfaceStyle
        case 2 => app.theme.normal
        case 3 => app.theme.error
        case _ => app.theme.disabled
    }
    Button(label, focused: app.focus.isFocused(id), disabled: disabled || variant == 4, style: style,
        focusedStyle: app.theme.focused, disabledStyle: app.theme.disabled, theme: Some(app.theme))
}

func galleryBlock(app: WorkbenchApp, title: String, border: BorderKind,
    focused!: Bool = false, asciiFallback!: Bool = false): Block {
    Block(BlockOptions(title: title, borderKind: border,
        backgroundStyle: app.surfaceStyle,
        borderStyle: if (focused) { app.theme.focused } else { app.borderStyle },
        contentStyle: app.theme.normal, titleStyle: app.theme.accent,
        state: if (focused) { BoxState.Focused } else { BoxState.Normal },
        asciiFallback: asciiFallback || !app.capabilities.unicode))
}
