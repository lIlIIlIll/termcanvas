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
}
