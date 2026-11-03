package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TaskActivityViewTest {
    @TestCase
    func statesAndAnimationUseProvidedTheme(): Unit {
        let states = [TaskStatus.Pending, TaskStatus.Queued, TaskStatus.Running,
            TaskStatus.Done, TaskStatus.Failed, TaskStatus.Cancelled]
        let marks = ["o", "-", "/", "+", "x", "-"]
        let styles = [Style(fg: Color.Blue), Style(fg: Color.Blue), Style(fg: Color.Cyan),
            Style(fg: Color.Green), Style(fg: Color.Red), Style(fg: Color.Yellow)]
        let theme = Theme(disabled: styles[0], accent: styles[2], success: styles[3],
            error: styles[4], warning: styles[5])
        for (i in 0..states.size) {
            let buffer = Buffer(Rect(0, 0, 30, 2))
            let activity = TaskActivity("task", status: states[i])
            TaskActivityView(activity, activityFrame: 1, theme: theme, unicode: false).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 0).symbol, marks[i])
            @Expect(buffer.getCell(0, 0).style, styles[i])
        }
        let first = Buffer(Rect(0, 0, 10, 1))
        let second = Buffer(Rect(0, 0, 10, 1))
        let running = TaskActivity("job", status: TaskStatus.Running)
        TaskActivityView(running, activityFrame: -1).render(first.area, first)
        TaskActivityView(running, activityFrame: 1).render(second.area, second)
        @Expect(first.getCell(0, 0).symbol, "◐")
        @Expect(second.getCell(0, 0).symbol, "◓")
    }

    @TestCase
    func individualProgressIsSnapshottedAndRetainsOrder(): Unit {
        let items = [TaskStatus.Done, TaskStatus.Pending, TaskStatus.Failed, TaskStatus.Done, TaskStatus.Cancelled]
        let activity = TaskActivity("构建", status: TaskStatus.Running, id: "42", prefix: "runner",
            duration: "3s", progressLabel: "Jobs", progress: Some(TaskProgress.Items(items)), detail: "Building")
        items[0] = TaskStatus.Failed
        let backend = TestBackend(area: Rect(0, 0, 80, 8))
        let terminal = Terminal(backend)
        _ = terminal.draw { frame => frame.renderWidget(TaskActivityView(activity), Rect(3, 2, 70, 3)) }
        let result = backend.snapshot()
        @Expect(result.contains("runner 构"))
        @Expect(result.contains("42"))
        @Expect(result.contains("3s"))
        @Expect(result.contains("Jobs ● ◌ ✗ ● –"))
        @Expect(result.contains("Building"))
    }

    @TestCase
    func countProgressClampsAndOnlyDrawsVisibleCells(): Unit {
        let negative = Buffer(Rect(0, 0, 12, 3))
        let over = Buffer(Rect(0, 0, 12, 3))
        let huge = Buffer(Rect(0, 0, 12, 3))
        let a = TaskActivity("job", progress: Some(TaskProgress.Counts(-1, 2)))
        let b = TaskActivity("job", progress: Some(TaskProgress.Counts(9, 2)))
        let c = TaskActivity("job", progress: Some(TaskProgress.Counts(1, Int64.Max)))
        TaskActivityView(a).render(negative.area, negative)
        TaskActivityView(b).render(over.area, over)
        TaskActivityView(c).render(huge.area, huge)
        @Expect(negative.getCell(2, 1).symbol, "◌")
        @Expect(negative.getCell(4, 1).symbol, "◌")
        @Expect(over.getCell(2, 1).symbol, "●")
        @Expect(over.getCell(4, 1).symbol, "●")
        @Expect(huge.getCell(2, 1).symbol, "●")
        @Expect(huge.getCell(10, 1).symbol, "◌")
        let empty = Buffer(Rect(0, 0, 12, 3))
        TaskActivityView(TaskActivity("job", progress: Some(TaskProgress.Counts(5, -2)))).render(empty.area, empty)
        @Expect(empty.getCell(2, 1).symbol, " ")
    }

    @TestCase
    func compactAndExpandedLayoutsDisplayCallerText(): Unit {
        let compact = Buffer(Rect(0, 0, 70, 3))
        let activity = TaskActivity("build", status: TaskStatus.Done, statusText: "finished", duration: "2s", detail: "all good")
        TaskActivityView(activity, layout: TaskActivityLayout.Compact).render(compact.area, compact)
        let backend = TestBackend(area: compact.area)
        backend.draw(compact)
        @Expect(backend.snapshot().contains("build finished 2s all good"))
        let expanded = Buffer(Rect(0, 0, 70, 3))
        TaskActivityView(activity).render(expanded.area, expanded)
        @Expect(expanded.getCell(2, 1).symbol, "a")
    }

    @TestCase
    func clipsSmallAreasWithoutDamagingOutsideWideCells(): Unit {
        let buffer = Buffer(Rect(0, 0, 35, 7))
        buffer.fill(buffer.area, Cell("#"))
        buffer.setString(4, 2, "界")
        let original = buffer.copy()
        let activity = TaskActivity("界界 long title", status: TaskStatus.Running,
            progress: Some(TaskProgress.Counts(1, Int64.Max)), detail: "detail")
        TaskActivityView(activity).render(Rect(5, 2, 8, 1), buffer)
        TaskActivityView(activity).render(Rect(18, 3, 8, 0), buffer)
        for (y in 0..7) {
            for (x in 0..35) {
                if (y != 2 || x < 5 || x >= 13) { @Expect(buffer.getCell(x, y), original.getCell(x, y)) }
            }
        }
        @Expect(buffer.getCell(5, 2), original.getCell(5, 2))
    }
}
