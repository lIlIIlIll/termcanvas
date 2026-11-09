package diff

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DiffThemeTest {
    private func document(): DiffDocument {
        let hunk = DiffHunk("@@ changes @@", lines: [
            DiffLine(DiffLineKind.Context, " same", oldLine: 1, newLine: 1),
            DiffLine(DiffLineKind.Delete, "-old", oldLine: 2),
            DiffLine(DiffLineKind.Add, "+new", newLine: 2),
            DiffLine(DiffLineKind.Header, "header")
        ])
        DiffDocument([DiffFile("a.txt", "a.txt", hunks: [hunk])])
    }

    @TestCase
    func themedRolesInheritSurfaceAndPreserveBothLayouts(): Unit {
        let base = Style(bg: Color.Blue)
        let theme = Theme(surface: base, normal: Style(fg: Color.White),
            accent: Style(fg: Color.Yellow), info: Style(fg: Color.Cyan),
            success: Style(fg: Color.Green), error: Style(fg: Color.Red),
            heading: Style(fg: Color.Magenta))
        for (sideBySide in [false, true]) {
            let buffer = Buffer(Rect(0, 0, 40, 6))
            DiffView(document(), sideBySide: sideBySide, theme: theme).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Yellow, bg: Color.Blue))
            @Expect(buffer.getCell(0, 1).style, Style(fg: Color.Cyan, bg: Color.Blue))
            @Expect(buffer.getCell(0, 2).style, Style(fg: Color.White, bg: Color.Blue))
            @Expect(buffer.getCell(0, 3).style, Style(fg: Color.Red, bg: Color.Blue))
            @Expect(buffer.getCell(if (sideBySide) { 20 } else { 0 }, if (sideBySide) { 3 } else { 4 }).style,
                Style(fg: Color.Green, bg: Color.Blue))
            @Expect(buffer.getCell(0, if (sideBySide) { 4 } else { 5 }).style, Style(fg: Color.Magenta, bg: Color.Blue))
        }
    }

    @TestCase
    func overridesCanClearBackgroundWithoutAffectingOtherRoles(): Unit {
        let theme = Theme(surface: Style(bg: Color.Blue), success: Style(fg: Color.Green))
        let styles = DiffViewStyles(add: StyleOverride(fg: Color.Yellow, bg: Color.Reset))
        let buffer = Buffer(Rect(0, 0, 40, 6))
        DiffView(document(), theme: theme, styles: styles).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 4).style, Style(fg: Color.Yellow))
        @Expect(buffer.getCell(0, 3).style, theme.error.withBg(Color.Blue))
    }

    @TestCase
    func terminalBackgroundAndAsciiKeepContentAndResetBackground(): Unit {
        let theme = Theme.indigo().withTerminalBackground()
        let buffer = Buffer(Rect(0, 0, 40, 6))
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        DiffView(document(), theme: theme).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(buffer.getCell(10, 3).symbol, "-")
        @Expect(buffer.getCell(10, 4).symbol, "+")
        @Expect(buffer.getCell(0, 0).style, theme.accent)
        @Expect(buffer.getCell(0, 3).style, theme.error)
        @Expect(buffer.getCell(0, 4).style, theme.success)
    }
    @TestCase
    func contextualAndExplicitThemeUseSurfaceBackground(): Unit {
        let contextual = Theme(surface: Style(bg: Color.Blue), accent: Style(fg: Color.Green, bg: Color.Red))
        let explicit = Theme(surface: Style(bg: Color.Magenta), accent: Style(fg: Color.Yellow, bg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 40, 6))
        buffer.setTheme(Some(contextual))
        DiffView(document()).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Green, bg: Color.Blue))
        DiffView(document(), theme: Some(explicit)).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Yellow, bg: Color.Magenta))
        buffer.withParentTheme(Some(explicit)) { => DiffView(document()).render(buffer.area, buffer) }
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Yellow, bg: Color.Magenta))
    }

    @TestCase
    func wideAmbiguousTextDoesNotOverflowSideBySideColumn(): Unit {
        let hunk = DiffHunk("@@", lines: [DiffLine(DiffLineKind.Context, " ·X", oldLine: 1, newLine: 1)])
        let doc = DiffDocument([DiffFile("a", "a", hunks: [hunk])])
        let buffer = Buffer(Rect(0, 0, 16, 3))
        buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        DiffView(doc, sideBySide: true).render(buffer.area, buffer)
        @Expect(buffer.getCell(6, 2).symbol, "·")
        @Expect(buffer.getCell(7, 2).symbol, "")
        @Expect(buffer.getCell(14, 2).symbol, "·")
        @Expect(buffer.getCell(15, 2).symbol, "")
    }

    @TestCase
    func themedSurfaceFillsContentButNotBlockOrExplicitTextOverrides(): Unit {
        let theme = Theme(surface: Style(bg: Color.Blue), normal: Style(fg: Color.White),
            accent: Style(fg: Color.Yellow), border: Style(fg: Color.Magenta))
        let buffer = Buffer(Rect(0, 0, 32, 10))
        buffer.fill(buffer.area, Cell("#", style: Style(bg: Color.Green)))
        let area = Rect(2, 1, 28, 8)
        let styles = DiffViewStyles(context: StyleOverride(bg: Color.Reset))
        DiffView(document(), block: Block(title: "diff"), theme: theme, styles: styles).render(area, buffer)
        @Expect(buffer.getCell(0, 0), Cell("#", style: Style(bg: Color.Green)))
        @Expect(buffer.getCell(2, 1).symbol != " ", true)
        @Expect(buffer.getCell(28, 2), Cell(" ", style: theme.surface))
        @Expect(buffer.getCell(3, 4).style, Style(fg: Color.White))
        @Expect(buffer.getCell(28, 4), Cell(" ", style: theme.surface))
        @Expect(buffer.getCell(28, 7), Cell(" ", style: theme.surface))
        @Expect(buffer.getCell(30, 7), Cell("#", style: Style(bg: Color.Green)))
    }

    @TestCase
    func themedSurfaceProtectsWideGlyphsAtClippedEdges(): Unit {
        let theme = Theme(surface: Style(bg: Color.Blue))
        for (sideBySide in [false, true]) {
            let buffer = Buffer(Rect(0, 0, 16, 4))
            buffer.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
            for (row in 0..4) {
                buffer.setString(0, row, "·", style: Style(bg: Color.Green))
                buffer.setString(12, row, "中", style: Style(bg: Color.Green))
            }
            DiffView(document(), theme: theme, sideBySide: sideBySide).render(Rect(1, 0, 12, 4), buffer)
            for (row in 0..4) {
                @Expect(buffer.getCell(0, row), Cell("·", style: Style(bg: Color.Green), kind: CellKind.WideLead))
                @Expect(buffer.getCell(1, row), Cell("", style: Style(bg: Color.Green), kind: CellKind.WideCont))
                @Expect(buffer.getCell(12, row), Cell("中", style: Style(bg: Color.Green), kind: CellKind.WideLead))
                @Expect(buffer.getCell(13, row), Cell("", style: Style(bg: Color.Green), kind: CellKind.WideCont))
            }
        }
    }

    @TestCase
    func emptyThemedViewFillsItsContentAndUnthemedViewPreservesIt(): Unit {
        let empty = DiffDocument([])
        let buffer = Buffer(Rect(0, 0, 6, 3))
        let sentinel = Cell("#", style: Style(bg: Color.Green))
        buffer.fill(buffer.area, sentinel)
        let target = Rect(1, 1, 4, 1)
        DiffView(empty).render(target, buffer)
        @Expect(buffer.getCell(1, 1), sentinel)
        let theme = Theme(surface: Style(bg: Color.Blue))
        DiffView(empty, theme: theme).render(target, buffer)
        @Expect(buffer.getCell(1, 1), Cell(" ", style: theme.surface))
        @Expect(buffer.getCell(0, 1), sentinel)
        @Expect(buffer.getCell(5, 1), sentinel)
    }

}
