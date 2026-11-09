package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TaskActivityOverflowTest {
    @TestCase
    func mixedProgressReportsExactHiddenCount(): Unit {
        let stages = [TaskStatus.Done, TaskStatus.Pending, TaskStatus.Failed,
            TaskStatus.Done, TaskStatus.Cancelled, TaskStatus.Running]
        let activity = TaskActivity("build", progressLabel: "Jobs", progress: Some(TaskProgress.Items(stages)))
        let backend = TestBackend(area: Rect(0, 0, 16, 3))
        _ = Terminal(backend).draw { frame => frame.renderWidget(TaskActivityView(activity), frame.area) }
        @Expect(backend.snapshot().contains("Jobs ● ◌ ✗ +3"))
        let ascii = TestBackend(area: Rect(0, 0, 16, 3))
        _ = Terminal(ascii).draw { frame => frame.renderWidget(TaskActivityView(activity, unicode: false), frame.area) }
        @Expect(ascii.snapshot().contains("Jobs + o x +3"))
    }

    @TestCase
    func textTruncationUsesGraphemeSafeMarker(): Unit {
        let title = TaskActivity("界界界界界界", status: TaskStatus.Running)
        let buffer = Buffer(Rect(0, 0, 10, 2))
        TaskActivityView(title).render(buffer.area, buffer)
        @Expect(buffer.getCell(3, 0).symbol, "界")
        @Expect(buffer.getCell(9, 0).symbol, "…")
        let compact = Buffer(Rect(0, 0, 14, 1))
        TaskActivityView(TaskActivity("job", status: TaskStatus.Cancelled), layout: TaskActivityLayout.Compact,
            unicode: false).render(compact.area, compact)
        @Expect(compact.getCell(13, 0).symbol, ".")
        let painted = Buffer(Rect(0, 0, 5, 1))
        painted.fill(painted.area, Cell("#"))
        TaskActivityView(TaskActivity("界界", id: "42")).render(painted.area, painted)
        @Expect(painted.getCell(3, 0).symbol, "…")
        @Expect(painted.getCell(4, 0).symbol, " ")
    }

    @TestCase
    func tinyWidthsAndWideAmbiguousGlyphsDoNotLoseOverflowOrOverlap(): Unit {
        let stages = [TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Pending]
        let activity = TaskActivity("task", progress: Some(TaskProgress.Items(stages)))
        let tiny = Buffer(Rect(0, 0, 1, 2))
        TaskActivityView(activity).render(tiny.area, tiny)
        @Expect(tiny.getCell(0, 1).symbol, "…")
        let wide = Buffer(Rect(0, 0, 8, 2))
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        TaskActivityView(activity).render(wide.area, wide)
        @Expect(wide.getCell(2, 1).symbol, "●")
        @Expect(wide.getCell(4, 1).symbol, " ")
        @Expect(wide.getCell(5, 1).symbol, "+")
        @Expect(wide.getCell(6, 1).symbol, "3")
        let narrowHuge = Buffer(Rect(0, 0, 3, 2))
        TaskActivityView(TaskActivity("x", progress: Some(TaskProgress.Counts(0, Int64.Max))),
            unicode: false).render(narrowHuge.area, narrowHuge)
        @Expect(narrowHuge.getCell(2, 1).symbol, ".")
    }
}
