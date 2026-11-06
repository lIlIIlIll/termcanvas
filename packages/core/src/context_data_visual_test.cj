package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ContextDataVisualTest {
    @TestCase
    func progressUsesApplicationThemeAndExplicitThemeWins(): Unit {
        let application = Theme(accent: Style(fg: Color.Red), secondary: Style(fg: Color.Yellow),
            progressSymbols: ProgressBarSymbols(filled: "A", empty: ".", head: "A", indeterminate: "A"))
        let explicit = Theme(accent: Style(fg: Color.Green), secondary: Style(fg: Color.Blue),
            progressSymbols: ProgressBarSymbols(filled: "B", empty: "-", head: "B", indeterminate: "B"))
        let buffer = Buffer(Rect(0, 0, 8, 1))
        buffer.setTheme(application)
        ProgressBar(1, total: 2).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "A")
        @Expect(buffer.getCell(0, 0).style, application.accent)
        @Expect(buffer.getCell(7, 0).style, application.secondary)
        ProgressBar(1, total: 2, theme: explicit).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "B")
        @Expect(buffer.getCell(0, 0).style, explicit.accent)
        ProgressBar(1, total: 2, fillStyle: Style(fg: Color.Magenta)).render(buffer.area, buffer)
        @Expect(colorEquals(buffer.getCell(0, 0).style.fg, Color.Magenta))
    }

    @TestCase
    func navigationAndTreeResolveThemeForEachRender(): Unit {
        let first = Theme(normal: Style(fg: Color.Yellow), selected: Style(fg: Color.Green))
        let second = Theme(normal: Style(fg: Color.Blue), selected: Style(fg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 18, 3))
        let tabs = Tabs(["one", "two"])
        buffer.setTheme(first)
        tabs.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, first.selected)
        buffer.setTheme(second)
        tabs.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.selected)
        tabs.setTheme(first)
        tabs.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, first.selected)
        let tree = Tree([TreeNode("1", "one")])
        tree.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.selected)
        let segment = SegmentedControl(["one", "two"])
        segment.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.selected)
        let disabled = SegmentedControl(["one"], disabled: true)
        disabled.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, second.disabled)
    }

    @TestCase
    func tableAndGraphsUseSemanticDefaultsWithExplicitStyles(): Unit {
        let theme = Theme(normal: Style(fg: Color.White), heading: Style(fg: Color.Yellow),
            selected: Style(fg: Color.Green), focused: Style(fg: Color.Blue), accent: Style(fg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 20, 3))
        buffer.setTheme(theme)
        let table = VirtualTable([TableColumn("A", width: 3), TableColumn("B", width: 3)],
            1, {_ => ["one", "two"]}, selectedRow: 0)
        table.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.heading)
        @Expect(buffer.getCell(0, 1).style, theme.focused)
        @Expect(buffer.getCell(4, 1).style, theme.selected)
        Sparkline([1], maxValue: 1).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.accent)
        Chart([1], style: Style(fg: Color.Magenta)).render(buffer.area, buffer)
        @Expect(colorEquals(buffer.getCell(0, 2).style.fg, Color.Magenta))
        StatusBar(left: "ok").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.raisedSurface)
    }

    @TestCase
    func statusBarProgressInheritsThemeSymbolsAndSurfaceUnlessExplicit(): Unit {
        let theme = Theme(accent: Style(fg: Color.Red), raisedSurface: Style(bg: Color.Blue),
            progressSymbols: ProgressBarSymbols(filled: "A", empty: ".", head: "A", indeterminate: "A"))
        let buffer = Buffer(Rect(0, 0, 20, 1))
        buffer.setTheme(theme)
        StatusBar(left: "ok", progress: StatusBarProgress(1, total: 2, width: 8,
            labelMode: ProgressBarLabelMode.Hidden)).render(buffer.area, buffer)
        @Expect(buffer.getCell(12, 0).symbol, "A")
        @Expect(buffer.getCell(12, 0).style, Style(fg: Color.Red, bg: Color.Blue))
        StatusBar(left: "ok", progress: StatusBarProgress(1, total: 2, width: 8,
            labelMode: ProgressBarLabelMode.Hidden,
            symbols: ProgressBarSymbols(filled: "X", empty: ".", head: "X"))).render(buffer.area, buffer)
        @Expect(buffer.getCell(12, 0).symbol, "X")
    }
}
