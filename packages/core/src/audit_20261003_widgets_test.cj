package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003WidgetsTest {
    @TestCase
    func progressScalingAcceptsLargeCounters(): Unit {
        let horizontal = Buffer(Rect(0, 0, 10, 1))
        ProgressBar(Int64.Max, total: Int64.Max).render(horizontal.area, horizontal)
        @Expect(auditWidgetRow(horizontal, 0), "##########")
        let vertical = Buffer(Rect(0, 0, 1, 4))
        ProgressBar(Int64.Max / 2, total: Int64.Max, direction: ProgressBarDirection.Vertical).render(vertical.area, vertical)
        @Expect(vertical.getCell(0, 2).symbol, "-")
        @Expect(vertical.getCell(0, 3).symbol, "#")
        let label = Buffer(Rect(0, 0, 10, 1))
        ProgressBar(Int64.Max, total: Int64.Max, labelMode: ProgressBarLabelMode.Percent).render(label.area, label)
        @Expect(auditWidgetRow(label, 0).contains("100%"))
    }

    @TestCase
    func progressSegmentsScaleAndClipLargeValues(): Unit {
        let buffer = Buffer(Rect(0, 0, 8, 1))
        ProgressBar(0, total: Int64.Max, segments: [ProgressBarSegment(Int64.Max, symbol: "=")]).render(buffer.area, buffer)
        @Expect(auditWidgetRow(buffer, 0), "========")
    }

    @TestCase
    func progressCustomSymbolsStayInsideTheAssignedArea(): Unit {
        let area = Rect(2, 2, 3, 2)
        for (direction in [ProgressBarDirection.Horizontal, ProgressBarDirection.Vertical]) {
            let buffer = auditWidgetSentinels()
            ProgressBar(1, total: 3, direction: direction,
                symbols: ProgressBarSymbols(filled: "XX", empty: "..", head: "YY", indeterminate: ">>")
            ).render(area, buffer)
            @Expect(auditWidgetOutsideChanges(buffer, area), 0)
        }
        let segmented = auditWidgetSentinels()
        ProgressBar(1, total: 1, segments: [ProgressBarSegment(1, symbol: "XY")]).render(area, segmented)
        @Expect(auditWidgetOutsideChanges(segmented, area), 0)
    }

    @TestCase
    func chartAndSparklineScaleLargeAndNegativeSamples(): Unit {
        let area = Rect(2, 2, 3, 2)
        let chart = auditWidgetSentinels()
        Chart([Int64.Max, Int64.Max / 2, Int64.Min]).render(area, chart)
        @Expect(auditWidgetOutsideChanges(chart, area), 0)
        @Expect(chart.getCell(2, 2).symbol, "#")
        let sparkline = Buffer(Rect(0, 0, 3, 1))
        Sparkline([Int64.Max, Int64.Max / 2, Int64.Min]).render(sparkline.area, sparkline)
        @Expect(auditWidgetRow(sparkline, 0), "#. ")
    }

    @TestCase
    func paginatorCeilingDivisionDoesNotOverflow(): Unit {
        let paginator = Paginator(pageSize: 2, total: Int64.Max)
        @Expect(paginator.pageCount(), 4611686018427387904)
        @Expect(paginator.handle(KeyEvent(KeyCode.End)))
        @Expect(paginator.offset(), Int64.Max - 1)
        let onePage = Paginator(pageSize: Int64.Max, total: 1)
        @Expect(onePage.pageCount(), 1)
    }

    @TestCase
    func frozenColumnsReserveSpaceForTheSelectedScrollingColumn(): Unit {
        let table = VirtualTable([TableColumn("A", width: 3), TableColumn("B", width: 3), TableColumn("C", width: 3)],
            1, { _ => ["aaa", "bbb", "ccc"] }, selectedColumn: 2)
        table.setFrozenColumns(1)
        let buffer = Buffer(Rect(0, 0, 8, 2))
        table.render(buffer.area, buffer)
        @Expect(table.columnOffset, 2)
        @Expect(auditWidgetRow(buffer, 1), "aaa ccc ")
    }

    @TestCase
    func multiselectInitialSelectionIsASetOfValidIndices(): Unit {
        let selector = MultiSelect(["zero", "one"], selected: [0, 0, -1, 2])
        @Expect(selector.selectedIndices(), [0])
        selector.toggle()
        @Expect(selector.selectedIndices().size, 0)
    }

    @TestCase
    func filePickerCanNavigateAboveTheDefaultRelativeDirectory(): Unit {
        let picker = FilePicker()
        @Expect(picker.selectedPath(), Some(".."))
        @Expect(picker.parent())
        @Expect(picker.path, "..")
        @Expect(picker.parent())
        @Expect(picker.path, "../..")
    }

    @TestCase
    func oneRowDialogDoesNotPaintButtonsAboveItsArea(): Unit {
        let buffer = auditWidgetSentinels()
        let area = Rect(2, 3, 6, 1)
        Dialog(buttons: ["OK"]).render(area, buffer)
        @Expect(auditWidgetOutsideChanges(buffer, area), 0)
    }

    @TestCase
    func emptyHeightMenuAndAlertDoNotPaint(): Unit {
        let buffer = auditWidgetSentinels()
        let area = Rect(2, 3, 6, 0)
        Menu("Title", [MenuItem("one")]).render(area, buffer)
        InlineAlert("warning").render(area, buffer)
        @Expect(auditWidgetOutsideChanges(buffer, area), 0)
    }

    @TestCase
    func legendUsesDisplayColumnsForUnicodeGaps(): Unit {
        let buffer = Buffer(Rect(0, 0, 14, 1))
        Legend([LegendItem("a"), LegendItem("b")], gap: "界").render(buffer.area, buffer)
        @Expect(buffer.getCell(5, 0).symbol, "#")
        @Expect(buffer.getCell(7, 0).symbol, "b")
    }
    @TestCase
    func composerAcceptsCompletionBeforeSubmitting(): Unit {
        let composer = Composer(value: "pri")
        composer.area.cursor = 3
        let request = composer.area.beginCompletion("audit-complete")
        @Expect(composer.area.handleCompletionEvent(Event.TextCompletion(
            request.requestId,
            TextCompletionResult(request.requestId, request.revision, request.prefixStart, request.prefixEnd,
                [TextCompletionItem("print"), TextCompletionItem("private")])
        )))
        @Expect(composer.handle(KeyEvent(KeyCode.Down)).isNone())
        @Expect(composer.handle(KeyEvent(KeyCode.Enter)).isNone())
        @Expect(composer.area.value, "private")
        @Expect(!composer.completionVisible())
        match (composer.handle(KeyEvent(KeyCode.Enter))) {
            case Some(submit) => @Expect(submit.text, "private")
            case None => @Expect(false)
        }
    }

    @TestCase
    func clippedTableColumnDoesNotOverflowItsNextPosition(): Unit {
        let table = VirtualTable([TableColumn("A", width: Int64.Max)], 1, { _ => ["row"] })
        let buffer = Buffer(Rect(0, 0, 4, 2))
        table.render(buffer.area, buffer)
        @Expect(auditWidgetRow(buffer, 1), "row ")
    }

    @TestCase
    func oversizedContainerGapsDoNotOverflow(): Unit {
        let area = Rect(0, 0, 4, 2)
        let horizontal = Buffer(area)
        HBox([InlineAlert("a"), InlineAlert("b"), InlineAlert("c")], gap: Int64.Max).render(area, horizontal)
        @Expect(auditWidgetRow(horizontal, 0), "    ")
        let vertical = Buffer(area)
        VBox([InlineAlert("a"), InlineAlert("b"), InlineAlert("c")], gap: Int64.Max).render(area, vertical)
        @Expect(auditWidgetRow(vertical, 0), "    ")
        @Expect(auditWidgetRow(vertical, 1), "    ")
    }

}
