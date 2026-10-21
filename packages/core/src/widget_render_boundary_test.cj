package core

import std.unittest.*
import std.unittest.testmacro.*

func renderBoundaryRow(buffer: Buffer, row: Int64): String {
    let text = StringBuilder()
    for (column in buffer.area.x..buffer.area.right) { text.append(buffer.getCell(column, row).symbol) }
    text.toString()
}

func renderBoundarySentinels(): Buffer {
    let buffer = Buffer(Rect(0, 0, 16, 12))
    for (row in 0..12) { buffer.setString(0, row, "ssssssssssssssss") }
    buffer
}

func renderBoundaryWideSentinels(): Buffer {
    let buffer = Buffer(Rect(0, 0, 32, 12))
    for (row in 0..12) { buffer.setString(0, row, "ssssssssssssssssssssssssssssssss") }
    buffer
}

func renderBoundaryOutsideChanges(buffer: Buffer, area: Rect): Int64 {
    var changed: Int64 = 0
    for (row in 0..buffer.area.height) {
        for (column in 0..buffer.area.width) {
            if (column < area.x || column >= area.right || row < area.y || row >= area.bottom) {
                if (buffer.getCell(column, row).symbol != "s") { changed++ }
            }
        }
    }
    changed
}

@Test
class WidgetRenderBoundaryTest {
    @TestCase
    func dialogMouseUsesCenteredButtonRowsAndDisplayWidth(): Unit {
        let area = Rect(2, 3, 30, 12)
        let dialog = Dialog(title: "Confirm", body: "Continue?", buttons: ["No", "是"], width: 20, height: 7)
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 8, 10), area), Some("No"))
        @Expect(dialog.selected, 0)
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 14, 10), area), Some("是"))
        @Expect(dialog.selected, 1)
        // The gap, border, body, and trailing blank do not activate a button.
        for ((x, y) in [(Int64(12), Int64(10)), (7, 10), (14, 7), (22, 10), (40, 10)]) {
            @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, x, y), area).isNone())
        }
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 8, 10), area).isNone())
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, 8, 10), area).isNone())
        @Expect(dialog.selected, 1)
        @Expect(dialog.handle(KeyEvent(KeyCode.Left)).isNone())
        @Expect(dialog.selected, 0)
        @Expect(dialog.handle(KeyEvent(KeyCode.Left)).isNone())
        @Expect(dialog.handle(KeyEvent(KeyCode.Esc)).isNone())
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some("No"))
    }

    @TestCase
    func dialogClipsButtonsAfterResizeAndEmptyDialogCannotActivate(): Unit {
        let area = Rect(2, 2, 6, 4)
        let buffer = renderBoundarySentinels()
        let dialog = Dialog(buttons: ["Long", "Other"], width: 20, height: 7)
        dialog.render(area, buffer)
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)
        @Expect(buffer.getCell(3, 4).symbol, "[")
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4), area), Some("Long"))
        @Expect(dialog.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 7, 4), area).isNone())
        let empty = Dialog(buttons: [])
        @Expect(empty.handle(KeyEvent(KeyCode.Right)).isNone())
        @Expect(empty.handle(KeyEvent(KeyCode.Left)).isNone())
        @Expect(empty.handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(empty.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4), area).isNone())
        let unchanged = renderBoundarySentinels()
        dialog.render(Rect(2, 2, 0, 3), unchanged)
        dialog.render(Rect(2, 2, 3, 0), unchanged)
        @Expect(renderBoundaryOutsideChanges(unchanged, Rect(0, 0, 0, 0)), 0)
    }

    @TestCase
    func dialogClampsPublicSelectionBeforeActionsAndRendering(): Unit {
        let area = Rect(0, 0, 40, 7)
        let dialog = Dialog(buttons: ["No", "Yes"])
        dialog.selected = 99
        @Expect(dialog.handle(KeyEvent(KeyCode.Enter)), Some("Yes"))
        @Expect(dialog.selected, 1)
        dialog.selected = -5
        _ = dialog.handle(KeyEvent(KeyCode.Left))
        @Expect(dialog.selected, 0)
        dialog.selected = 99
        dialog.render(area, Buffer(area))
        @Expect(dialog.selected, 1)
    }

    @TestCase
    func dialogThemeIsOptInAndExplicitSelectedStyleWins(): Unit {
        let area = Rect(0, 0, 40, 7)
        let normalRole = Style(fg: Color.Blue, bg: Color.Black)
        let selectedRole = Style(fg: Color.Green, bg: Color.Magenta, modifier: Modifier.strong())
        let theme = Theme(normal: normalRole, selected: selectedRole)
        let customNormal = Style(fg: Color.Red)
        let dialog = Dialog(body: "Body", buttons: ["No", "Yes"], style: customNormal, selectedStyle: Style.default())

        let legacy = Buffer(area)
        dialog.render(area, legacy)
        @Expect(legacy.getCell(1, 5).style, Style.default())
        @Expect(legacy.getCell(1, 1).style, customNormal)

        dialog.setTheme(Some(theme))
        let themed = Buffer(area)
        dialog.render(area, themed)
        @Expect(themed.getCell(1, 1).style, normalRole.patch(customNormal))
        @Expect(themed.getCell(1, 5).style, selectedRole)
        @Expect(themed.getCell(6, 5).style, normalRole.patch(customNormal))

        let explicit = Style(fg: Color.Yellow, bg: Color.Red)
        let overridden = Dialog(buttons: ["No"], selectedStyle: explicit, theme: Some(theme))
        let explicitBuffer = Buffer(area)
        overridden.render(area, explicitBuffer)
        @Expect(explicitBuffer.getCell(1, 5).style, explicit)
    }

    @TestCase
    func confirmDialogMapsKeyboardAndRenderedMouseHitsToBooleans(): Unit {
        let area = Rect(0, 0, 80, 24)
        let selected = Style(fg: Color.Green, bg: Color.Blue)
        let confirm = ConfirmDialog("Proceed?", selectedStyle: Style.default(), theme: Some(Theme(selected: selected)))
        @Expect(confirm.handle(KeyEvent(KeyCode.Enter)), Some(false))
        @Expect(confirm.confirmed, false)
        @Expect(confirm.handle(KeyEvent(KeyCode.Right)).isNone())
        @Expect(confirm.confirmed, true)
        @Expect(confirm.handle(KeyEvent(KeyCode.Enter)), Some(true))

        confirm.confirmed = false
        let buffer = Buffer(area)
        confirm.render(area, buffer)
        @Expect(buffer.getCell(21, 13).style, selected)
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 27, 13), area), Some(true))
        @Expect(confirm.confirmed, true)
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 22, 13), area), Some(false))
        @Expect(confirm.confirmed, false)

        confirm.confirmed = true
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 25, 13), area).isNone())
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 20, 13), area).isNone())
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 22, 10), area).isNone())
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, 27, 13), area).isNone())
        @Expect(confirm.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 27, 13), area).isNone())
        @Expect(confirm.confirmed, true)
    }

    @TestCase
    func requestAndDecisionDialogsForwardThemeOptions(): Unit {
        let area = Rect(0, 0, 40, 12)
        let normal = Style(fg: Color.Cyan, bg: Color.Black)
        let selected = Style(fg: Color.Yellow, bg: Color.Blue)
        let theme = Theme(normal: normal, selected: selected)
        let customNormal = Style(fg: Color.Red)
        let request = RequestDialog(body: "Run?", buttons: ["No", "Yes"], selected: 1, style: customNormal, selectedStyle: Style.default())
        request.setTheme(Some(theme))
        let requestBuffer = Buffer(area)
        request.render(area, requestBuffer)
        @Expect(requestBuffer.getCell(1, 3).style, normal.patch(customNormal))
        @Expect(requestBuffer.getCell(6, 7).style, selected)

        let decision = DecisionDialog(body: "Approve?", buttons: ["No", "Yes"], selected: 1, selectedStyle: Style.default(), theme: Some(theme))
        let decisionBuffer = Buffer(area)
        decision.render(area, decisionBuffer)
        @Expect(decisionBuffer.getCell(6, 7).style, selected)
    }

    @TestCase
    func menuBarRendersSelectedStylesAndClipsAtDisplayColumns(): Unit {
        let normal = Style(fg: Color.Green)
        let selected = Style(fg: Color.Red)
        let menu = MenuBar(["文", "Edit", "Last"], selected: 1, style: normal, selectedStyle: selected)
        let area = Rect(2, 2, 10, 2)
        let buffer = renderBoundarySentinels()
        menu.render(area, buffer)
        @Expect(buffer.getCell(3, 2).symbol, "文")
        @Expect(buffer.getCell(2, 2).style, normal)
        @Expect(buffer.getCell(6, 2).style, selected)
        @Expect(buffer.getCell(7, 2).symbol, "E")
        @Expect(buffer.getCell(2, 3).symbol, "s")
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)
        for (width in [Int64(1), 2, 3]) {
            let narrow = renderBoundarySentinels()
            let clipped = Rect(2, 2, width, 1)
            menu.render(clipped, narrow)
            @Expect(renderBoundaryOutsideChanges(narrow, clipped), 0)
        }
        let empty = renderBoundarySentinels()
        MenuBar([]).render(area, empty)
        menu.render(Rect(2, 2, 0, 3), empty)
        menu.render(Rect(2, 2, 3, 0), empty)
        @Expect(renderBoundaryOutsideChanges(empty, Rect(0, 0, 0, 0)), 0)
    }

    @TestCase
    func menuBarNavigationClampsAtBothEnds(): Unit {
        let menu = MenuBar(["one", "two", "three"], selected: 2)
        @Expect(menu.handle(KeyEvent(KeyCode.Left)))
        @Expect(menu.selected, 1)
        @Expect(menu.handle(KeyEvent(KeyCode.Home)))
        @Expect(menu.selected, 0)
        @Expect(menu.handle(KeyEvent(KeyCode.Left)))
        @Expect(menu.selected, 0)
        @Expect(menu.handle(KeyEvent(KeyCode.End)))
        @Expect(menu.selected, 2)
        @Expect(menu.handle(KeyEvent(KeyCode.Right)))
        @Expect(menu.selected, 2)
        @Expect(!menu.handle(KeyEvent(KeyCode.Enter)))
        @Expect(!MenuBar([]).handle(KeyEvent(KeyCode.Left)))
    }

    @TestCase
    func tabsMouseHonorsWideLabelsSingleRowAndButtons(): Unit {
        let tabs = Tabs(["文", "Edit"])
        let area = Rect(2, 3, 14, 2)
        @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3), area))
        @Expect(tabs.selected, 0)
        @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 3), area))
        @Expect(tabs.selected, 1)
        @Expect(!tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 13, 3), area))
        @Expect(!tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 4), area))
        @Expect(!tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 3), area))
        @Expect(!tabs.handleMouse(MouseEvent(MouseKind.Up, MouseButton.Left, 6, 3), area))
        @Expect(!tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Right, 6, 3), area))
        @Expect(!Tabs([]).handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 3), area))
        @Expect(tabs.selected, 1)
    }
    @TestCase
    func tabsScrollAndTruncateWithMatchingMouseHitAreas(): Unit {
        let tabs = Tabs(["Overview", "Layout", "Forms", "Long navigation"], selected: 3,
            style: Style(fg: Color.Indexed(8)), selectedStyle: Style(fg: Color.White, bg: Color.Blue))
        tabs.setFocused(true)
        let area = Rect(2, 2, 5, 2)
        let buffer = renderBoundarySentinels()
        tabs.render(area, buffer)
        @Expect(buffer.getCell(2, 2).style.modifier.bold)
        @Expect(buffer.getCell(2, 2).style.modifier.underline)
        @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 2), area))
        @Expect(tabs.selected, 3)
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)

        tabs.selected = 2
        let narrow = Rect(3, 4, 1, 1)
        let narrowBuffer = renderBoundarySentinels()
        tabs.render(narrow, narrowBuffer)
        @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4), narrow))
        @Expect(tabs.selected, 2)
        @Expect(renderBoundaryOutsideChanges(narrowBuffer, narrow), 0)
        @Expect(!Tabs([]).handle(KeyEvent(KeyCode.Left)))
    }

    @TestCase
    func tabsThemeIsOptInAndFocusedSelectionKeepsModifiers(): Unit {
        let theme = Theme(
            normal: Style(fg: Color.Yellow, bg: Color.Blue),
            selected: Style(fg: Color.White, bg: Color.Green)
        )
        let legacyNormal = Style(fg: Color.Red)
        let legacySelected = Style(fg: Color.White, bg: Color.Magenta)
        let legacyTabs = Tabs(["A", "B"], selected: 1, style: legacyNormal, selectedStyle: legacySelected)
        legacyTabs.setTheme(Some(theme))
        let legacyBuffer = Buffer(Rect(0, 0, 8, 1))
        legacyTabs.render(legacyBuffer.area, legacyBuffer)
        @Expect(legacyBuffer.getCell(1, 0).style, legacyNormal)
        @Expect(legacyBuffer.getCell(4, 0).style, legacySelected)

        let tabs = Tabs(["A", "B"], selected: 1, selectedStyle: Style.default())
        tabs.setTheme(Some(theme))
        tabs.setFocused(true)
        let themedSelectedBase = theme.selected
        var themedSelectedModifier = themedSelectedBase.modifier
        themedSelectedModifier.bold = true
        themedSelectedModifier.underline = true
        let focusedThemedSelected = themedSelectedBase.withModifier(themedSelectedModifier)
        let themedBuffer = Buffer(Rect(0, 0, 8, 1))
        tabs.render(themedBuffer.area, themedBuffer)
        @Expect(themedBuffer.getCell(1, 0).style, theme.normal)
        let selectedCell = themedBuffer.getCell(4, 0)
        @Expect(selectedCell.style, focusedThemedSelected)
        @Expect(selectedCell.style.modifier.bold)
        @Expect(selectedCell.style.modifier.underline)

        tabs.setTheme(Option<Theme>.None)
        let defaultSelectedBase = Style.default()
        var defaultSelectedModifier = defaultSelectedBase.modifier
        defaultSelectedModifier.bold = true
        defaultSelectedModifier.underline = true
        let focusedDefaultSelected = defaultSelectedBase.withModifier(defaultSelectedModifier)
        let clearedBuffer = Buffer(Rect(0, 0, 8, 1))
        tabs.render(clearedBuffer.area, clearedBuffer)
        @Expect(clearedBuffer.getCell(1, 0).style, Style.default())
        @Expect(clearedBuffer.getCell(4, 0).style, focusedDefaultSelected)
        @Expect(clearedBuffer.getCell(4, 0).style.modifier.bold)
        @Expect(clearedBuffer.getCell(4, 0).style.modifier.underline)
    }

    @TestCase
    func tabsNormalizePublicSelectionBeforeKeysAndRender(): Unit {
        let tabs = Tabs(["A", "B", "C"])
        tabs.selected = -1
        @Expect(tabs.handle(KeyEvent(KeyCode.Right)))
        @Expect(tabs.selected, 1)

        tabs.selected = 9223372036854775807i64
        @Expect(tabs.handle(KeyEvent(KeyCode.Right)))
        @Expect(tabs.selected, 2)
        let tiny = Rect(2, 2, 0, 1)
        let buffer = renderBoundarySentinels()
        tabs.selected = 9223372036854775807i64
        tabs.render(tiny, buffer)
        @Expect(tabs.selected, 2)
        tabs.selected = -1
        tabs.render(tiny, buffer)
        @Expect(tabs.selected, 0)
        @Expect(renderBoundaryOutsideChanges(buffer, Rect(0, 0, 0, 0)), 0)

        let empty = Tabs([])
        empty.selected = 9223372036854775807i64
        @Expect(!empty.handle(KeyEvent(KeyCode.Right)))
        @Expect(empty.selected, 0)
        empty.selected = 9223372036854775807i64
        empty.render(Rect(0, 0, 0, 0), buffer)
        @Expect(empty.selected, 0)
    }

    @TestCase
    func tabsUnicodeViewportAndHitAreasStayAlignedAcrossResizes(): Unit {
        let tabs = Tabs(
            ["界面选择", "😀工作台", "Final"],
            selected: 2,
            style: Style(fg: Color.Red),
            selectedStyle: Style(fg: Color.White, bg: Color.Blue)
        )
        tabs.setFocused(true)
        let selectedBase = Style(fg: Color.White, bg: Color.Blue)
        var selectedModifier = selectedBase.modifier
        selectedModifier.bold = true
        selectedModifier.underline = true
        let focusedSelectedStyle = selectedBase.withModifier(selectedModifier)
        for (width in [Int64(1), 5, 28]) {
            tabs.selected = 2
            let area = Rect(2, 2, width, 2)
            let buffer = renderBoundaryWideSentinels()
            tabs.render(area, buffer)
            @Expect(tabs.selected, 2)
            var selectedVisible = false
            for (column in area.x..area.right) {
                if (buffer.getCell(column, area.y).style == focusedSelectedStyle) { selectedVisible = true }
            }
            @Expect(selectedVisible)
            @Expect(renderBoundaryOutsideChanges(buffer, area), 0)

            if (width == 28) {
                var cjkColumn: Int64 = -1
                var emojiColumn: Int64 = -1
                var finalColumn: Int64 = -1
                for (column in area.x..area.right) {
                    let symbol = buffer.getCell(column, area.y).symbol
                    if (symbol == "界") { cjkColumn = column }
                    if (symbol == "😀") { emojiColumn = column }
                    if (symbol == "F") { finalColumn = column }
                }
                @Assert(cjkColumn >= area.x)
                @Assert(emojiColumn >= area.x)
                @Assert(finalColumn >= area.x)
                @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, cjkColumn, area.y), area))
                @Expect(tabs.selected, 0)
                tabs.selected = 2
                @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, emojiColumn, area.y), area))
                @Expect(tabs.selected, 1)
                tabs.selected = 2
                @Expect(tabs.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, finalColumn, area.y), area))
                @Expect(tabs.selected, 2)
            }
        }
    }

    @TestCase
    func verticalIndeterminateProgressMovesAndWrapsWithinItsArea(): Unit {
        let area = Rect(3, 2, 2, 6)
        // A two-row window enters from below, crosses the viewport, then wraps.
        let cases: Array<(Int64, Array<Int64>)> = [(0, [7]), (1, [6, 7]), (6, [2]), (7, []), (8, [7])]
        for ((phase, rows) in cases) {
            let buffer = renderBoundarySentinels()
            ProgressBar(0, direction: ProgressBarDirection.Vertical, indeterminate: true, phase: phase,
                symbols: ProgressBarSymbols(empty: ".", indeterminate: ">")).render(area, buffer)
            for (row in area.y..area.bottom) {
                var active = false
                for (expected in rows) { if (row == expected) { active = true } }
                @Expect(buffer.getCell(3, row).symbol, if (active) { ">" } else { "." })
                @Expect(buffer.getCell(4, row).symbol, if (active) { ">" } else { "." })
            }
            @Expect(renderBoundaryOutsideChanges(buffer, area), 0)
        }
        let narrow = Buffer(Rect(0, 0, 1, 1))
        ProgressBar(0, direction: ProgressBarDirection.Vertical, indeterminate: true, phase: 1).render(narrow.area, narrow)
        @Expect(narrow.getCell(0, 0).symbol, "-")
    }

    @TestCase
    func progressLabelsClampValuesAndOverrideGeneratedText(): Unit {
        for ((mode, expected) in [(ProgressBarLabelMode.Value, "7"), (ProgressBarLabelMode.Ratio, "7/10"),
            (ProgressBarLabelMode.Percent, "70%"), (ProgressBarLabelMode.Text("ready"), "ready")]) {
            for (direction in [ProgressBarDirection.Horizontal, ProgressBarDirection.Vertical]) {
                let buffer = Buffer(Rect(0, 0, 12, 5))
                let labelStyle = Style(fg: Color.Red)
                ProgressBar(7, total: 10, direction: direction, labelMode: mode, labelStyle: labelStyle).render(buffer.area, buffer)
                let row = match (direction) { case ProgressBarDirection.Horizontal => Int64(0); case ProgressBarDirection.Vertical => Int64(2) }
                @Expect(renderBoundaryRow(buffer, row).contains(expected))
                @Expect(buffer.getCell((12 - expected.size) / 2, row).style, labelStyle)
            }
        }
        let capped = Buffer(Rect(0, 0, 8, 1))
        ProgressBar(20, total: 10, labelMode: ProgressBarLabelMode.Ratio).render(capped.area, capped)
        @Expect(renderBoundaryRow(capped, 0).contains("10/10"))
        let override = Buffer(Rect(0, 0, 8, 1))
        ProgressBar(7, total: 10, label: "done", labelMode: ProgressBarLabelMode.Value).render(override.area, override)
        @Expect(renderBoundaryRow(override, 0).contains("done"))
        let unicode = renderBoundarySentinels()
        let narrow = Rect(2, 2, 1, 3)
        ProgressBar(0, direction: ProgressBarDirection.Vertical, labelMode: ProgressBarLabelMode.Text("界")).render(narrow, unicode)
        @Expect(renderBoundaryOutsideChanges(unicode, narrow), 0)
    }

    @TestCase
    func zeroWidthSegmentsFallBackToValueAndOversizedSegmentsStop(): Unit {
        let tiny = Buffer(Rect(0, 0, 5, 1))
        ProgressBar(1, total: 100, segments: [ProgressBarSegment(0), ProgressBarSegment(1)]).render(tiny.area, tiny)
        @Expect(renderBoundaryRow(tiny, 0), "#----")
        let empty = Buffer(Rect(0, 0, 5, 1))
        ProgressBar(0, total: 100, segments: [ProgressBarSegment(0)]).render(empty.area, empty)
        @Expect(renderBoundaryRow(empty, 0), "-----")
        let full = Buffer(Rect(0, 0, 5, 1))
        ProgressBar(0, total: 10, segments: [ProgressBarSegment(10, symbol: "A"), ProgressBarSegment(10, symbol: "B")]).render(full.area, full)
        @Expect(renderBoundaryRow(full, 0), "AAAAA")
    }

    @TestCase
    func loadingOverlayAndSkeletonRespectRequestedRows(): Unit {
        let overlay = Buffer(Rect(0, 0, 12, 5))
        LoadingOverlay(label: "Busy", frame: 2).render(overlay.area, overlay)
        @Expect(renderBoundaryRow(overlay, 2).contains("- Busy"))
        @Expect(renderBoundaryRow(overlay, 0), "            ")
        let skeleton = Buffer(Rect(0, 0, 5, 4))
        Skeleton(rows: 3).render(skeleton.area, skeleton)
        @Expect(renderBoundaryRow(skeleton, 0), "-----")
        @Expect(renderBoundaryRow(skeleton, 1), "---- ")
        @Expect(renderBoundaryRow(skeleton, 2), "---  ")
        @Expect(renderBoundaryRow(skeleton, 3), "     ")
        let untouched = renderBoundarySentinels()
        Skeleton(rows: 0).render(Rect(2, 2, 3, 2), untouched)
        Skeleton(rows: 3).render(Rect(2, 2, 0, 2), untouched)
        @Expect(renderBoundaryOutsideChanges(untouched, Rect(0, 0, 0, 0)), 0)
    }

    @TestCase
    func dashboardErrorAndAlertStylesExposeTheirSemanticState(): Unit {
        let error = Buffer(Rect(0, 0, 20, 6))
        ErrorBox("Failed", detail: "Retry").render(error.area, error)
        @Expect(renderBoundaryRow(error, 2).contains("Failed"))
        @Expect(renderBoundaryRow(error, 3).contains("Retry"))
        @Expect(error.getCell(7, 2).style, Style(fg: Color.Red))
        for ((state, expected) in [(StyleState.Error, Style(fg: Color.Red)),
            (StyleState.Disabled, Style(fg: Color.Indexed(8))), (StyleState.Selected, Style(fg: Color.Green)),
            (StyleState.Focused, Style(fg: Color.Cyan)), (StyleState.Accent, Style(fg: Color.Yellow)),
            (StyleState.Normal, Style.default())]) {
            let buffer = Buffer(Rect(0, 0, 5, 1))
            InlineAlert("Alert", state: state).render(buffer.area, buffer)
            @Expect(renderBoundaryRow(buffer, 0), "Alert")
            @Expect(buffer.getCell(0, 0).style, expected)
        }
    }
    @TestCase
    func badgeUsesNormalThemeRoleAndPatchesExplicitStyleWithoutFillingArea(): Unit {
        let area = Rect(3, 2, 7, 2)
        let buffer = renderBoundarySentinels()
        let normal = Style(fg: Color.Blue, bg: Color.Indexed(8))
        let theme = Theme(normal: normal)
        let patch = Style(fg: Color.Yellow)
        let expected = normal.patch(patch)
        Badge("OK", style: patch, theme: Some(theme)).render(area, buffer)
        @Expect(buffer.getCell(3, 2).symbol, "[")
        @Expect(buffer.getCell(6, 2).symbol, "]")
        for (x in 3..7) { @Expect(buffer.getCell(x, 2).style, expected) }
        for (x in 7..area.right) {
            @Expect(buffer.getCell(x, 2).symbol, "s")
            @Expect(buffer.getCell(x, 2).style, Style.default())
        }
        for (x in area.x..area.right) { @Expect(buffer.getCell(x, 3).symbol, "s") }
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)

        let themed = renderBoundarySentinels()
        Badge("OK", theme: Some(theme)).render(Rect(2, 1, 4, 1), themed)
        for (x in 2..6) { @Expect(themed.getCell(x, 1).style, normal) }

        let unthemed = renderBoundarySentinels()
        Badge("OK", style: patch).render(Rect(2, 1, 4, 1), unthemed)
        for (x in 2..6) { @Expect(unthemed.getCell(x, 1).style, patch) }
    }

    @TestCase
    func badgeHandlesZeroAndOneColumnAreasAndEmptyLabels(): Unit {
        let buffer = renderBoundarySentinels()
        let emptyStyle = Style(fg: Color.Green)
        Badge("OK").render(Rect(2, 2, 0, 1), buffer)
        @Expect(buffer.getCell(2, 2).symbol, "s")

        Badge("OK").render(Rect(4, 2, 1, 1), buffer)
        @Expect(buffer.getCell(4, 2).symbol, "[")
        @Expect(buffer.getCell(5, 2).symbol, "s")

        Badge("", style: emptyStyle).render(Rect(7, 2, 2, 1), buffer)
        @Expect(buffer.getCell(7, 2).symbol, "[")
        @Expect(buffer.getCell(8, 2).symbol, "]")
        @Expect(buffer.getCell(7, 2).style, emptyStyle)
        @Expect(buffer.getCell(8, 2).style, emptyStyle)

        Badge("skip").render(Rect(11, 2, 3, 0), buffer)
        @Expect(buffer.getCell(11, 2).symbol, "s")
        @Expect(renderBoundaryOutsideChanges(buffer, Rect(2, 2, 9, 1)), 0)
    }

    @TestCase
    func badgeKeepsUnicodeCellsWholeAndClipsAtAreaEnd(): Unit {
        let style = Style(fg: Color.Magenta)
        let buffer = renderBoundarySentinels()
        let area = Rect(5, 5, 4, 1)
        Badge("界", style: style).render(area, buffer)
        @Expect(buffer.getCell(5, 5).symbol, "[")
        @Expect(buffer.getCell(6, 5), Cell("界", style: style, kind: CellKind.WideLead))
        @Expect(buffer.getCell(7, 5), Cell("", style: style, kind: CellKind.WideCont))
        @Expect(buffer.getCell(8, 5).symbol, "]")
        @Expect(renderBoundaryOutsideChanges(buffer, area), 0)

        let clipped = renderBoundarySentinels()
        let narrow = Rect(8, 4, 2, 1)
        Badge("界", style: style).render(narrow, clipped)
        @Expect(clipped.getCell(8, 4).symbol, "[")
        @Expect(clipped.getCell(9, 4).symbol, "s")
        @Expect(clipped.getCell(9, 4).style, Style.default())
        @Expect(renderBoundaryOutsideChanges(clipped, narrow), 0)
    }

}
