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
    @TestCase
    func iconsFollowCapabilitiesAndExplicitOverride(): Unit {
        let ascii = Buffer(Rect(0, 0, 20, 1))
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        let activity = TaskActivity("build", status: TaskStatus.Done)
        TaskActivityView(activity).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "+")
        TaskActivityView(activity, unicode: true).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "✓")
        let nerd = Buffer(Rect(0, 0, 20, 1))
        TaskActivityView(activity, theme: Theme(iconSet: IconSet.NerdFont)).render(nerd.area, nerd)
        @Expect(nerd.getCell(0, 0).symbol, "\u{f058}")
        TaskActivityView(activity, theme: Theme(iconSet: IconSet.NerdFont), unicode: false).render(nerd.area, nerd)
        @Expect(nerd.getCell(0, 0).symbol, "+")
    }

    @TestCase
    func mixedListShowsOverflowAndScrollsByTask(): Unit {
        let a = TaskActivity("alpha", status: TaskStatus.Done)
        let b = TaskActivity("beta", progress: Some(TaskProgress.Counts(1, 2)), detail: "checking")
        let c = TaskActivity("gamma", status: TaskStatus.Running)
        let entries = [TaskActivityListEntry(a, layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(b), TaskActivityListEntry(c, layout: TaskActivityLayout.Compact)]
        let buffer = Buffer(Rect(0, 0, 32, 5))
        TaskActivityList(entries).render(buffer.area, buffer)
        let backend = TestBackend(area: buffer.area)
        backend.draw(buffer)
        @Expect(backend.snapshot().contains("alpha"))
        @Expect(backend.snapshot().contains("checking"))
        @Expect(backend.snapshot().contains("gamma"))
        let clipped = Buffer(Rect(0, 0, 32, 4))
        TaskActivityList(entries).render(clipped.area, clipped)
        backend.draw(clipped)
        @Expect(backend.snapshot().contains("2 more/partial"))
        let scrolled = Buffer(Rect(0, 0, 32, 4))
        TaskActivityList(entries, offset: 1).render(scrolled.area, scrolled)
        backend.draw(scrolled)
        @Expect(backend.snapshot().contains("beta"))
        @Expect(backend.snapshot().contains("1 above | 1 more"))
        @Expect(!backend.snapshot().contains("alpha"))
        let single = Buffer(Rect(0, 0, 32, 1))
        TaskActivityList(entries, offset: Int64.Max).render(single.area, single)
        backend.draw(single)
        @Expect(backend.snapshot().contains("gamma"))
        @Expect(backend.snapshot().contains("2 above"))
        let oneLine = Buffer(Rect(0, 0, 32, 1))
        TaskActivityList(entries).render(oneLine.area, oneLine)
        backend.draw(oneLine)
        @Expect(backend.snapshot().contains("alpha"))
        @Expect(backend.snapshot().contains("2 more"))
        let twoLines = Buffer(Rect(0, 0, 32, 2))
        TaskActivityList(entries, offset: 1).render(twoLines.area, twoLines)
        backend.draw(twoLines)
        @Expect(backend.snapshot().contains("beta"))
        @Expect(backend.snapshot().contains("1 above | 2 more/partial"))
    }

    @TestCase
    func progressMarkersRemainLegibleAndIconsHaveClearSpacing(): Unit {
        let normal = Style(fg: Color.White)
        let muted = Style(fg: Color.Blue)
        let theme = Theme(normal: normal, disabled: muted)
        let activity = TaskActivity("build", status: TaskStatus.Running,
            progress: Some(TaskProgress.Items([TaskStatus.Pending, TaskStatus.Queued, TaskStatus.Done])))
        let buffer = Buffer(Rect(0, 0, 32, 3))
        buffer.fill(buffer.area, Cell("#"))
        TaskActivityView(activity, theme: theme).render(buffer.area, buffer)
        @Expect(buffer.getCell(1, 0).symbol, " ")
        @Expect(buffer.getCell(2, 0).symbol, " ")
        @Expect(buffer.getCell(3, 0).symbol, "b")
        @Expect(buffer.getCell(2, 1).style, normal)
        @Expect(buffer.getCell(4, 1).style, normal)
        let ascii = Buffer(Rect(0, 0, 32, 3))
        TaskActivityView(activity, theme: theme, unicode: false).render(ascii.area, ascii)
        @Expect(ascii.getCell(1, 0).symbol, " ")
        @Expect(ascii.getCell(2, 0).symbol, " ")
        @Expect(ascii.getCell(3, 0).symbol, "b")
        let nerd = Buffer(Rect(0, 0, 32, 3))
        TaskActivityView(activity, theme: Theme(iconSet: IconSet.NerdFont)).render(nerd.area, nerd)
        @Expect(nerd.getCell(1, 0).symbol, " ")
        @Expect(nerd.getCell(2, 0).symbol, " ")
        @Expect(nerd.getCell(3, 0).symbol, "b")
    }

    @TestCase
    func durationAlignmentHonorsWidthAndPreservesLongTitles(): Unit {
        let activity = TaskActivity("build", duration: "5s")
        let standard = Buffer(Rect(0, 0, 120, 2))
        TaskActivityView(activity).render(standard.area, standard)
        @Expect(standard.getCell(86, 0).symbol, "5")
        let custom = Buffer(Rect(0, 0, 120, 2))
        let entries = [TaskActivityListEntry(activity)]
        TaskActivityList(entries, maxHeaderWidth: 32).render(custom.area, custom)
        @Expect(custom.getCell(30, 0).symbol, "5")
        let unlimited = Buffer(Rect(0, 0, 120, 2))
        TaskActivityView(activity, maxHeaderWidth: 0).render(unlimited.area, unlimited)
        @Expect(unlimited.getCell(118, 0).symbol, "5")
        let narrow = Buffer(Rect(0, 0, 20, 2))
        TaskActivityView(activity).render(narrow.area, narrow)
        @Expect(narrow.getCell(18, 0).symbol, "5")
        let title = "012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
        let long = Buffer(Rect(0, 0, 120, 2))
        TaskActivityView(TaskActivity(title, duration: "5s")).render(long.area, long)
        let backend = TestBackend(area: long.area)
        backend.draw(long)
        @Expect(backend.snapshot().contains(title))
        @Expect(backend.snapshot().contains("5s"))
        let truncated = Buffer(Rect(0, 0, 40, 2))
        TaskActivityView(TaskActivity(title, duration: "5s")).render(truncated.area, truncated)
        backend.draw(truncated)
        @Expect(backend.snapshot().contains("01234567890123456789"))
        @Expect(!backend.snapshot().contains("5s"))
    }

}
