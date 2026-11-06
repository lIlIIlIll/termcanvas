package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ProgressActivityVisualTest {
    @TestCase
    func pausedIsVisibleInBothLayoutsAndIconModes(): Unit {
        let activity = TaskActivity("build", status: TaskStatus.Paused,
            progress: Some(TaskProgress.Items([TaskStatus.Paused])))
        for (layout in [TaskActivityLayout.Compact, TaskActivityLayout.Expanded]) {
            let ascii = Buffer(Rect(0, 0, 32, 2))
            ascii.setCapabilities(TerminalCapabilities(unicode: false))
            TaskActivityView(activity, layout: layout).render(ascii.area, ascii)
            @Expect(ascii.getCell(0, 0).symbol, "P")
            match (layout) {
                case TaskActivityLayout.Expanded => @Expect(ascii.getCell(2, 1).symbol, "P")
                case TaskActivityLayout.Compact => ()
            }
            let nerd = Buffer(ascii.area)
            TaskActivityView(activity, layout: layout, theme: Theme(iconSet: IconSet.NerdFont)).render(nerd.area, nerd)
            @Expect(nerd.getCell(0, 0).symbol, "\u{f04c}")
        }
    }

    @TestCase
    func labelsRetainPercentInNarrowAreasAndCanMove(): Unit {
        let narrow = Buffer(Rect(0, 0, 4, 1))
        ProgressBar(1, total: 2, labelMode: ProgressBarLabelMode.Percent).render(narrow.area, narrow)
        @Expect(narrow.getCell(1, 0).symbol, "5")
        @Expect(narrow.getCell(3, 0).symbol, "%")
        let tiny = Buffer(Rect(0, 0, 2, 1))
        ProgressBar(1, total: 1000, labelMode: ProgressBarLabelMode.Percent).render(tiny.area, tiny)
        @Expect(tiny.getCell(0, 0).symbol, "<")
        @Expect(tiny.getCell(1, 0).symbol, "1")
        let left = Buffer(Rect(0, 0, 10, 1))
        ProgressBar(1, total: 2, labelMode: ProgressBarLabelMode.Percent,
            labelPosition: ProgressBarLabelPosition.Start).render(left.area, left)
        @Expect(left.getCell(0, 0).symbol, "5")
        @Expect(left.getCell(5, 0).symbol, "%")
        @Expect(left.getCell(7, 0).symbol, "━")
        let bottom = Buffer(Rect(0, 0, 8, 3))
        ProgressBar(1, total: 2, direction: ProgressBarDirection.Vertical,
            labelMode: ProgressBarLabelMode.Percent, labelPosition: ProgressBarLabelPosition.End).render(bottom.area, bottom)
        @Expect(bottom.getCell(0, 2).symbol, "5")
        @Expect(bottom.getCell(0, 1).symbol, "━")
    }

    @TestCase
    func themeStylesInheritAndOverridesCanClearBackground(): Unit {
        let theme = Theme(normal: Style(fg: Color.White, bg: Color.Blue),
            secondary: Style(fg: Color.Yellow, bg: Color.Blue), accent: Style(fg: Color.Green, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 10, 1))
        ProgressBar(1, total: 2, theme: theme, fillStyle: Style(fg: Color.Red),
            trackOverride: StyleOverride(bg: Color.Reset), fillOverride: StyleOverride(bg: Color.Reset)).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
        @Expect(buffer.getCell(9, 0).style, Style(fg: Color.Yellow))
        let label = Buffer(Rect(0, 0, 8, 1))
        label.fill(label.area, Cell(" ", style: Style(bg: Color.Yellow)))
        ProgressBar(1, total: 2, theme: theme, labelMode: ProgressBarLabelMode.Percent).render(label.area, label)
        @Expect(label.getCell(2, 0).style, Style(fg: Color.White, bg: Color.Yellow))
        ProgressBar(1, total: 2, theme: theme, labelMode: ProgressBarLabelMode.Percent,
            labelOverride: StyleOverride(bg: Color.Reset)).render(label.area, label)
        @Expect(label.getCell(2, 0).style, Style(fg: Color.White))
    }
}
