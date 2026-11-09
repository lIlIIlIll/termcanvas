package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TaskActivityListIndicatorTest {
    private func entries(): Array<TaskActivityListEntry> {
        [TaskActivityListEntry(TaskActivity("Checkout", status: TaskStatus.Running), layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("Build", status: TaskStatus.Running), layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("Test", status: TaskStatus.Running), layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("Package", status: TaskStatus.Running), layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("Publish", status: TaskStatus.Running), layout: TaskActivityLayout.Compact)]
    }

    @TestCase
    func oneLineKeepsCompleteTitleBeforeHiddenIndicator(): Unit {
        for (ascii in [false, true]) {
            let area = Rect(3, 2, 18, 1)
            let buffer = Buffer(Rect(0, 0, 25, 5))
            TaskActivityList(entries(), offset: 4, unicode: !ascii).render(area, buffer)
            let backend = TestBackend(area: buffer.area)
            backend.draw(buffer)
            let text = backend.snapshot()
            @Expect(text.contains("Publish"))
            @Expect(!text.contains("Publis…"))
            @Expect(!text.contains("Publis."))
            @Expect(text.contains("^4"))
        }
        let wide = Buffer(Rect(0, 0, 20, 1))
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        let entries = [TaskActivityListEntry(TaskActivity("构建", status: TaskStatus.Running), layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("界面", status: TaskStatus.Running), layout: TaskActivityLayout.Compact)]
        TaskActivityList(entries, offset: 1).render(wide.area, wide)
        @Expect(wide.getCell(4, 0).symbol, "界")
        @Expect(wide.getCell(6, 0).symbol, "面")
        let prefixed = [TaskActivityListEntry(TaskActivity("Publish", status: TaskStatus.Running, prefix: "CI"),
            layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(TaskActivity("Done"), layout: TaskActivityLayout.Compact)]
        let nerd = Buffer(Rect(0, 0, 19, 1))
        TaskActivityList(prefixed, theme: Theme(iconSet: IconSet.NerdFont)).render(nerd.area, nerd)
        let nerdBackend = TestBackend(area: nerd.area)
        nerdBackend.draw(nerd)
        @Expect(nerdBackend.snapshot().contains("CI Publish"))
    }

    @TestCase
    func narrowIndicatorKeepsBothDirectionsOrShowsOmission(): Unit {
        let area = Rect(0, 0, 12, 3)
        let buffer = Buffer(area)
        TaskActivityList(entries(), offset: 1).render(area, buffer)
        let backend = TestBackend(area: area)
        backend.draw(buffer)
        @Expect(backend.snapshot().contains("^1 v2"))
        @Expect(!backend.snapshot().contains("1 above | 2 "))
        let veryNarrow = Buffer(Rect(0, 0, 4, 3))
        TaskActivityList(entries(), offset: 1, unicode: false).render(veryNarrow.area, veryNarrow)
        @Expect(veryNarrow.getCell(0, 2).symbol, ".")
        let wide = Buffer(Rect(0, 0, 4, 3))
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        TaskActivityList(entries(), offset: 1).render(wide.area, wide)
        @Expect(wide.getCell(0, 2).symbol, ".")
    }

    @TestCase
    func partiallyShownEntryIsNotRepresentedAsAnOrdinaryCount(): Unit {
        let expanded = TaskActivityListEntry(TaskActivity("task", detail: "detail", progress: Some(TaskProgress.Counts(1, 2))))
        let buffer = Buffer(Rect(0, 0, 8, 2))
        TaskActivityList([expanded]).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 1).symbol, "…")
    }

    @TestCase
    func singleLineCountsCurrentPartialEntryAndKeepsTitle(): Unit {
        let expanded = TaskActivityListEntry(TaskActivity("Task", detail: "details", progress: Some(TaskProgress.Counts(1, 2))))
        let next = TaskActivityListEntry(TaskActivity("next"), layout: TaskActivityLayout.Compact)
        for (withNext in [false, true]) {
            let items = if (withNext) { [expanded, next] } else { [expanded] }
            let expected = if (withNext) { "2 more/partial" } else { "1 more/partial" }
            let exact = Buffer(Rect(0, 0, 22, 1))
            TaskActivityList(items).render(exact.area, exact)
            let exactBackend = TestBackend(area: exact.area)
            exactBackend.draw(exact)
            @Expect(exactBackend.snapshot().contains("Task"))
            @Expect(exactBackend.snapshot().contains(expected))
            let narrow = Buffer(Rect(0, 0, 21, 1))
            TaskActivityList(items).render(narrow.area, narrow)
            let narrowBackend = TestBackend(area: narrow.area)
            narrowBackend.draw(narrow)
            @Expect(narrowBackend.snapshot().contains("Task"))
            @Expect(narrowBackend.snapshot().contains("…"))
            @Expect(!narrowBackend.snapshot().contains("more/partial"))
        }
    }
}
