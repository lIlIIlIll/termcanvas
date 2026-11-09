package termcanvas_visual_matrix

import core.*
import std.unittest.*
import std.unittest.testmacro.*

func matrixTestIconName(icon: IconSet): String {
    match (icon) {
        case IconSet.Unicode => "unicode"
        case IconSet.NerdFont => "nerd-font"
        case IconSet.Ascii => "ascii"
    }
}

@Test
class MatrixStateTest {
    @TestCase
    func defaultThemeMatchesIndigoRepresentative(): Unit {
        for (glyph in ["unicode", "nerd-font", "ascii"]) {
            for (color in ["truecolor", "256", "16", "monochrome"]) {
                let icon = if (glyph == "nerd-font") { IconSet.NerdFont } else if (glyph == "ascii") { IconSet.Ascii } else { IconSet.Unicode }
                let caps = matrixCapabilities(Rect(0, 0, 80, 24), glyph, color)
                let original = Theme.default().withIconSet(icon).adapted(caps)
                let representative = Theme.indigo().withIconSet(icon).adapted(caps)
                @Expect(original.normal, representative.normal)
                @Expect(original.focused, representative.focused)
                @Expect(original.selected, representative.selected)
                @Expect(original.disabled, representative.disabled)
                @Expect(original.error, representative.error)
                @Expect(original.accent, representative.accent)
                @Expect(original.success, representative.success)
                @Expect(original.warning, representative.warning)
                @Expect(original.info, representative.info)
                @Expect(original.canvas, representative.canvas)
                @Expect(original.surface, representative.surface)
                @Expect(original.raisedSurface, representative.raisedSurface)
                @Expect(original.heading, representative.heading)
                @Expect(original.secondary, representative.secondary)
                @Expect(original.border, representative.border)
                @Expect(original.strongBorder, representative.strongBorder)
                @Expect(original.progressSymbols.isNone(), true)
                @Expect(representative.progressSymbols.isNone(), true)
                @Expect(matrixTestIconName(original.iconSet), matrixTestIconName(representative.iconSet))
                @Expect(match (original.borderKind) { case BorderKind.Auto => true; case _ => false }, true)
                @Expect(match (representative.borderKind) { case BorderKind.Auto => true; case _ => false }, true)
            }
        }
    }

    @TestCase
    func tabsFocusedStateChangesSelectedTabAppearance(): Unit {
        let area = Rect(0, 0, 40, 3)
        let normal = Buffer(area)
        let focused = Buffer(area)
        let theme = Theme.indigo()
        tabsMatrixWidget("normal", theme).render(area, normal)
        tabsMatrixWidget("focused", theme).render(area, focused)
        @Expect(normal.getCell(8, 0).symbol, "B")
        @Expect(focused.getCell(8, 0).symbol, "B")
        @Expect(normal.getCell(8, 0).style.modifier.underline, false)
        @Expect(focused.getCell(8, 0).style.modifier.underline, true)
    }

    @TestCase
    func gameScenesRenderSpritesMapsAndCameraOffsets(): Unit {
        let area = Rect(2, 1, 8, 3)
        let bounds = Rect(0, 0, 12, 5)
        let theme = Theme.indigo()
        for (subject in ["game.SpriteRenderer.render", "game.SpriteRenderer.drawSprite"]) {
            let normal = Buffer(bounds)
            normal.setString(4, 2, ".")
            GamePrimitive(subject, "normal", theme).render(area, normal)
            @Expect(normal.getCell(3, 2).symbol, "@")
            @Expect(normal.getCell(4, 2).symbol, ".")
            @Expect(normal.getCell(5, 2).symbol, "@")
            @Expect(normal.getCell(3, 3).symbol, "#")
            let offset = Buffer(bounds)
            GamePrimitive(subject, "offset", theme).render(area, offset)
            @Expect(offset.getCell(2, 2).symbol, "@")
            @Expect(offset.getCell(4, 2).symbol, "@")
            @Expect(offset.getCell(1, 2).symbol, " ")
        }
        let map = Buffer(bounds)
        map.setTheme(theme)
        GamePrimitive("game.TileMap.render", "normal", theme).render(area, map)
        @Expect(map.getCell(2, 1).symbol, "#")
        @Expect(map.getCell(4, 2).symbol, "A")
        let shiftedMap = Buffer(bounds)
        shiftedMap.setTheme(theme)
        GamePrimitive("game.TileMap.render", "offset", theme).render(area, shiftedMap)
        @Expect(shiftedMap.getCell(3, 2).symbol, "A")
        @Expect(shiftedMap.getCell(1, 2).symbol, " ")
    }

    @TestCase
    func animationFixtureUsesDistinctFramesAndPausedStyle(): Unit {
        let area = Rect(0, 0, 20, 3)
        let theme = Theme.indigo()
        let frames = ["frame-0", "frame-1", "frame-2", "frame-3"]
        let symbols = ["|", "/", "-", "\\"]
        for (i in 0..frames.size) {
            let spinner = Buffer(area)
            Spinner(label: "Working", frame: matrixFrameIndex(frames[i]), style: theme.accent).render(area, spinner)
            @Expect(spinner.getCell(0, 0).symbol, symbols[i])
            let overlay = Buffer(area)
            LoadingOverlay(label: "Loading", frame: matrixFrameIndex(frames[i])).render(area, overlay)
            @Expect(overlay.getCell(4, 1).symbol, symbols[i])
        }
        let start = Buffer(area)
        let mid = Buffer(area)
        progressMatrixWidget("indeterminate-early", theme).render(area, start)
        progressMatrixWidget("indeterminate-mid", theme).render(area, mid)
        @Expect(start.getCell(0, 0).symbol != mid.getCell(0, 0).symbol, true)
        @Expect(start.getCell(14, 0).symbol != mid.getCell(14, 0).symbol, true)
        let playingFirst = Buffer(area)
        let playingSecond = Buffer(area)
        let pausedFirst = Buffer(area)
        let pausedSecond = Buffer(area)
        for (buffer in [playingFirst, playingSecond, pausedFirst, pausedSecond]) { buffer.setTheme(theme) }
        animationMatrixWidget("frame-0").render(area, playingFirst)
        animationMatrixWidget("frame-1").render(area, playingSecond)
        animationMatrixWidget("paused-frame-0").render(area, pausedFirst)
        animationMatrixWidget("paused-frame-1").render(area, pausedSecond)
        @Expect(playingFirst.getCell(7, 0).symbol, "1")
        @Expect(playingSecond.getCell(7, 0).symbol, "2")
        @Expect(pausedFirst.getCell(7, 0).symbol, "1")
        @Expect(pausedSecond.getCell(7, 0).symbol, "2")
        @Expect(playingFirst.getCell(0, 0).style, theme.normal)
        @Expect(pausedFirst.getCell(0, 0).style, theme.warning)
        @Expect(playingSecond.getCell(0, 0).style, theme.normal)
        @Expect(pausedSecond.getCell(0, 0).style, theme.warning)
    }

    @TestCase
    func drawReportUsesActualDrawAreaAndDeclaresWidthTarget(): Unit {
        let small = matrixWidgetArea("core.Tree", "long-name+expanded+width-42", Rect(2, 4, 16, 3))
        @Expect(matrixDrawReport(small, matrixTargetWidth("core.Tree", "long-name+expanded+width-42")),
            "{\"effective_rect\":[2,4,16,3],\"target_width\":42}")
        let enough = matrixWidgetArea("core.Tree", "long-name+expanded+width-40", Rect(2, 4, 42, 3))
        @Expect(matrixDrawReport(enough, matrixTargetWidth("core.Tree", "long-name+expanded+width-40")),
            "{\"effective_rect\":[2,4,40,3],\"target_width\":40}")
        let normal = matrixWidgetArea("core.Table", "no-selection", Rect(2, 4, 40, 10))
        @Expect(matrixDrawReport(normal, matrixTargetWidth("core.Table", "no-selection")),
            "{\"effective_rect\":[2,4,40,10],\"target_width\":0}")
        let zero = matrixWidgetArea("core.Input", "empty+focused", Rect(2, 4, 0, 0))
        @Expect(matrixDrawReport(zero, matrixTargetWidth("core.Input", "empty+focused")),
            "{\"effective_rect\":[2,4,0,0],\"target_width\":0}")
    }

    @TestCase
    func singleLineInputFixtureLimitsHeightAndPreservesStates(): Unit {
        let theme = Theme.indigo()
        for (width in [Int64(16), Int64(40)]) {
            let outer = Rect(2, 1, width, 10)
            let area = matrixWidgetArea("core.Input", "empty+focused", outer)
            @Expect(area.x, outer.x)
            @Expect(area.y, outer.y)
            @Expect(area.width, outer.width)
            @Expect(area.height, Int64(1))
            for (state in ["empty+focused", "empty+error", "empty+focused+error"]) {
                let buffer = Buffer(Rect(0, 0, width + 4, 12))
                buffer.setString(2, 2, "X")
                inputMatrixWidget(state, theme).render(matrixWidgetArea("core.Input", state, outer), buffer)
                @Expect(buffer.getCell(2, 1).symbol, "[")
                @Expect(buffer.getCell(3, 1).symbol, "T")
                @Expect(buffer.getCell(2, 2).symbol, "X")
                @Expect(buffer.getCell(2, 2).style, Style.default())
                if (state.contains("focused")) {
                    @Expect(buffer.getCell(3, 1).style.modifier.underline, true)
                }
                if (state.contains("error")) {
                    @Expect(Style(fg: buffer.getCell(3, 1).style.fg), Style(fg: theme.error.fg))
                }
            }
        }
        @Expect(matrixWidgetArea("core.Input", "empty+focused", Rect(0, 0, 16, 0)).height, Int64(0))
    }

    @TestCase
    func tableSurfaceCasesShowHeadersOnRaisedBackground(): Unit {
        let area = Rect(0, 0, 20, 4)
        let theme = Theme.indigo()
        @Expect(Style(bg: theme.raisedSurface.bg) != Style(bg: theme.canvas.bg))
        for (subject in ["core.Table", "core.VirtualTable"]) {
            let buffer = Buffer(area)
            buffer.setTheme(theme)
            buffer.fill(area, style: theme.canvas)
            let frame = Frame(area, buffer)
            matrixTableSurface(frame, area, "custom-surface", theme)
            if (subject == "core.Table") {
                frame.renderWidget(tableMatrixWidget("custom-surface", theme), area)
                @Expect(buffer.getCell(2, 0).symbol, "N")
                @Expect(Style(bg: buffer.getCell(2, 0).style.bg), Style(bg: theme.raisedSurface.bg))
                @Expect(Style(bg: buffer.getCell(0, 1).style.bg), Style(bg: theme.raisedSurface.bg))
            } else {
                frame.renderWidget(virtualTableMatrixWidget("custom-surface"), area)
                @Expect(buffer.getCell(0, 0).symbol, "N")
                @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: theme.raisedSurface.bg))
            }
            @Expect(Style(bg: buffer.getCell(19, 0).style.bg), Style(bg: theme.raisedSurface.bg))
        }
    }

    @TestCase
    func virtualTableNarrowSortCasesExposeDirectionAndGeometry(): Unit {
        let states = ["sort-asc+width-1", "sort-asc+width-2", "sort-desc+width-1", "sort-desc+width-2"]
        let widths: Array<Int64> = [1, 2, 1, 2]
        for (unicode in [true, false]) {
            for (i in 0..states.size) {
                let area = matrixWidgetArea("core.VirtualTable", states[i], Rect(2, 4, 16, 3))
                @Expect(matrixTargetWidth("core.VirtualTable", states[i]), widths[i])
                @Expect(area.width, widths[i])
                let buffer = Buffer(Rect(0, 0, 20, 8))
                buffer.setCapabilities(TerminalCapabilities(unicode: unicode))
                virtualTableMatrixWidget(states[i]).render(area, buffer)
                @Expect(buffer.getCell(area.x + area.width - 1, area.y).symbol, if (i < 2) { "^" } else { "v" })
                if (widths[i] == 2) { @Expect(buffer.getCell(area.x, area.y).symbol, if (unicode) { "…" } else { "." }) }
                @Expect(buffer.getCell(area.right, area.y).symbol, " ")
                let tooSmall = matrixWidgetArea("core.VirtualTable", states[i], Rect(2, 4, 0, 3))
                @Expect(tooSmall.width, Int64(0))
            }
        }
    }

    @TestCase
    func virtualTableStatusAndPagedFixturesShowRealStatesOnTheirSurface(): Unit {
        let area = Rect(0, 0, 40, 5)
        let theme = Theme.indigo()
        let states = ["empty", "loading", "error", "empty+custom-surface", "loading+custom-surface", "error+custom-surface"]
        let messages = ["No rows", "Loading", "Unable to load", "No rows", "Loading", "Unable to load"]
        for (i in 0..states.size) {
            let buffer = Buffer(area)
            buffer.setTheme(theme)
            buffer.fill(area, style: theme.canvas)
            matrixTableSurface(Frame(area, buffer), area, states[i], theme)
            virtualTableMatrixWidget(states[i]).render(area, buffer)
            let output = TestBackend(area: area)
            output.draw(buffer)
            @Expect(output.snapshot().contains(messages[i]))
            @Expect(!output.snapshot().contains("Alpha"))
            let expectedBg = if (i >= 3) { theme.raisedSurface.bg } else { theme.canvas.bg }
            @Expect(Style(bg: buffer.getCell(0, 1).style.bg), Style(bg: expectedBg))
            let expectedFg = if (i == 2 || i == 5) { theme.error.fg } else { theme.disabled.fg }
            @Expect(Style(fg: buffer.getCell(0, 1).style.fg), Style(fg: expectedFg))
        }
        let paged = Buffer(area)
        paged.setTheme(theme)
        paged.fill(area, style: theme.canvas)
        matrixTableSurface(Frame(area, paged), area, "paged+custom-surface", theme)
        virtualTableMatrixWidget("paged+custom-surface").render(area, paged)
        let output = TestBackend(area: area)
        output.draw(paged)
        @Expect(output.snapshot().contains("Alpha"))
        @Expect(output.snapshot().contains("Page failed"))
        @Expect(output.snapshot().contains("Loading"))
        for (row in 1..4) {
            @Expect(Style(bg: paged.getCell(0, row).style.bg), Style(bg: theme.raisedSurface.bg))
        }
    }

    @TestCase
    func workbenchInputTableAndTreeScenariosRenderTheirStates(): Unit {
        let area = Rect(0, 0, 40, 6)
        let theme = Theme.indigo()
        let focused = Buffer(area)
        let error = Buffer(area)
        let both = Buffer(area)
        inputMatrixWidget("empty+focused", theme).render(area, focused)
        inputMatrixWidget("empty+error", theme).render(area, error)
        inputMatrixWidget("empty+focused+error", theme).render(area, both)
        @Expect(focused.getCell(1, 0).symbol, "T")
        @Expect(focused.getCell(1, 0).style.modifier.underline, true)
        @Expect(Style(fg: error.getCell(1, 0).style.fg), Style(fg: theme.error.fg))
        @Expect(Style(fg: both.getCell(1, 0).style.fg), Style(fg: theme.error.fg))
        @Expect(both.getCell(1, 0).style.modifier.underline, true)
        let unselected = Buffer(area)
        tableMatrixWidget("no-selection", theme).render(area, unselected)
        @Expect(unselected.getCell(0, 2).symbol, " ")
        let scrolled = Buffer(area)
        tableMatrixWidget("scrolled+focused", theme).render(area, scrolled)
        @Expect(scrolled.getCell(0, 2).symbol, "●")
        @Expect(scrolled.getCell(2, 2).symbol, "j")
        @Expect(scrolled.getCell(6, 2).symbol, "4")
        @Expect(scrolled.getCell(2, 2).style.modifier.underline, true)
        let collapsed = Buffer(area)
        let expanded = Buffer(area)
        treeMatrixWidget("long-name+collapsed", theme).render(area, collapsed)
        treeMatrixWidget("long-name+expanded", theme).render(area, expanded)
        @Expect(collapsed.getCell(2, 0).symbol, "+")
        @Expect(expanded.getCell(2, 0).symbol, "-")
        let closedText = TestBackend(area: area)
        let openText = TestBackend(area: area)
        closedText.draw(collapsed)
        openText.draw(expanded)
        @Expect(closedText.snapshot().contains("sample.cj"), false)
        @Expect(openText.snapshot().contains("sample.cj"), true)
    }

    @TestCase
    func workbenchTinyProgressAndMixedActivityRemainMeaningful(): Unit {
        let area = Rect(0, 0, 40, 3)
        let theme = Theme.indigo()
        let progress = Buffer(area)
        progressMatrixWidget("tiny", theme).render(area, progress)
        let progressText = TestBackend(area: area)
        progressText.draw(progress)
        @Expect(progressText.snapshot().contains("0.01%"), true)
        @Expect(progress.getCell(0, 0).symbol, "╺")
        let mixed = Buffer(area)
        activityMatrixWidget("mixed-stages+expanded", theme).render(area, mixed)
        @Expect(mixed.getCell(7, 1).symbol, "●")
        @Expect(mixed.getCell(9, 1).symbol, "◐")
        @Expect(mixed.getCell(11, 1).symbol, "✗")
        @Expect(mixed.getCell(13, 1).symbol, "P")
        @Expect(mixed.getCell(15, 1).symbol, "◌")
        @Expect(mixed.getCell(17, 1).symbol, "–")
        let long = Buffer(area)
        activityMatrixWidget("long-title+duration+expanded", theme).render(area, long)
        let longText = TestBackend(area: area)
        longText.draw(long)
        @Expect(longText.snapshot().contains("Cross-platform test suite"), true)
        @Expect(longText.snapshot().contains("16m7s"), true)
        let narrowArea = Rect(0, 0, 16, 3)
        let narrow = Buffer(narrowArea)
        activityMatrixWidget("long-title+duration+expanded", theme).render(narrowArea, narrow)
        let narrowText = TestBackend(area: narrowArea)
        narrowText.draw(narrow)
        @Expect(narrowText.snapshot().contains("Cross-"), true)
        @Expect(narrowText.snapshot().contains("16m7s"), false)
    }

    @TestCase
    func tinyProgressWidthCasesKeepTheirLabelsAndStayInsideBounds(): Unit {
        let bounds = Rect(0, 0, 50, 4)
        let outer = Rect(2, 1, 40, 2)
        let states = ["tiny+width-3", "tiny+width-4", "tiny+width-8"]
        let widths: Array<Int64> = [3, 4, 8]
        let theme = Theme.indigo()
        for (unicode in [true, false]) {
            for (i in 0..states.size) {
                let area = matrixWidgetArea("core.ProgressBar", states[i], outer)
                @Expect(area.width, widths[i])
                let buffer = Buffer(bounds)
                buffer.setCapabilities(TerminalCapabilities(unicode: unicode))
                buffer.setString(area.right, area.y, "!")
                progressMatrixWidget(states[i], theme).render(area, buffer)
                @Expect(buffer.getCell(area.right, area.y).symbol, "!")
                let labelStart = if (i == 0) { area.x } else if (i == 1) { area.x + 1 } else { area.x + 3 }
                if (i < 2) {
                    @Expect(buffer.getCell(labelStart, area.y).symbol, "<")
                    @Expect(buffer.getCell(labelStart + 1, area.y).symbol, "1")
                    @Expect(buffer.getCell(labelStart + 2, area.y).symbol, "%")
                } else {
                    @Expect(buffer.getCell(area.x, area.y).symbol, if (unicode) { "╺" } else { "=" })
                    @Expect(buffer.getCell(labelStart, area.y).symbol, "0")
                    @Expect(buffer.getCell(labelStart + 2, area.y).symbol, "0")
                    @Expect(buffer.getCell(labelStart + 3, area.y).symbol, "1")
                    @Expect(buffer.getCell(labelStart + 4, area.y).symbol, "%")
                }
            }
        }
        let constrained = matrixWidgetArea("core.ProgressBar", states[2], Rect(2, 1, 4, 1))
        @Expect(constrained.width, 4)
        @Expect(matrixWidthCaption(8, constrained.width), "Width: target 8, actual 4")
    }

    @TestCase
    func treeLongNameClipsWideGlyphOnlyAtWholeCellBoundaries(): Unit {
        let bounds = Rect(0, 0, 50, 4)
        let outer = Rect(2, 1, 42, 2)
        let states = ["long-name+expanded+width-40", "long-name+expanded+width-41", "long-name+expanded+width-42"]
        let widths: Array<Int64> = [40, 41, 42]
        for (i in 0..states.size) {
            let area = matrixWidgetArea("core.Tree", states[i], outer)
            @Expect(area.width, widths[i])
            let buffer = Buffer(bounds)
            buffer.setString(area.right, area.y, "!")
            treeMatrixWidget(states[i], Theme.indigo()).render(area, buffer)
            @Expect(buffer.getCell(area.right, area.y).symbol, "!")
            if (i < 2) {
                @Expect(buffer.getCell(area.x + 39, area.y).symbol, "…")
                @Expect(match (buffer.getCell(area.x + 39, area.y).kind) { case CellKind.Normal => true; case _ => false }, true)
            } else if (i == 2) {
                @Expect(buffer.getCell(area.x + 39, area.y).symbol, "世")
                @Expect(match (buffer.getCell(area.x + 39, area.y).kind) { case CellKind.WideLead => true; case _ => false }, true)
                @Expect(match (buffer.getCell(area.x + 40, area.y).kind) { case CellKind.WideCont => true; case _ => false }, true)
                @Expect(buffer.getCell(area.x + 41, area.y).symbol, "…")
            }
        }
        let constrained = matrixWidgetArea("core.Tree", states[2], Rect(2, 1, 40, 1))
        @Expect(constrained.width, 40)
        @Expect(matrixWidthCaption(42, constrained.width), "Width: target 42, actual 40")
    }

    @TestCase
    func declaredColorModesSelectActualCapabilityLevels(): Unit {
        let area = Rect(0, 0, 80, 24)
        @Expect(matrixCapabilities(area, "ascii", "16").colorLevel, 16)
        @Expect(matrixCapabilities(area, "ascii", "256").colorLevel, 256)
        @Expect(matrixCapabilities(area, "ascii", "monochrome").colorLevel, 1)
        @Expect(matrixCapabilities(area, "unicode", "truecolor").trueColor, true)
        @ExpectThrows[IllegalArgumentException](matrixCapabilities(area, "ascii", "invalid"))
    }

    @TestCase
    func styledCasesApplyDeclaredOverrides(): Unit {
        let buffer = Buffer(Rect(0, 0, 40, 5))
        styledMatrixWidget("clear-background").render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Reset))
        @Expect(buffer.getCell(0, 0).style.modifier.bold, true)
        buffer.clear()
        styledMatrixWidget("clear-modifiers").render(buffer.area, buffer)
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Blue))
        @Expect(buffer.getCell(0, 0).style.modifier.bold, false)
        @Expect(buffer.getCell(0, 0).style.modifier.italic, false)
        @Expect(buffer.getCell(0, 0).style.modifier.underline, false)
        buffer.clear()
        styledMatrixWidget("nested").render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Green))
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Reset))
        @Expect(buffer.getCell(0, 0).style.modifier.bold, false)
        @Expect(Style(fg: buffer.getCell(20, 0).style.fg), Style(fg: Color.Red))
        @Expect(Style(bg: buffer.getCell(20, 0).style.bg), Style(bg: Color.Reset))
        @Expect(buffer.getCell(20, 0).style.modifier.bold, true)
    }

    @TestCase
    func markdownCasesApplyDeclaredThemeSyntaxAndScroll(): Unit {
        let buffer = Buffer(Rect(0, 0, 40, 5))
        buffer.setTheme(Theme(accent: Style(fg: Color.Green)))
        markdownMatrixWidget("explicit-theme").render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Magenta))
        @Expect(Style(bg: buffer.getCell(0, 0).style.bg), Style(bg: Color.Blue))
        buffer.clear()
        markdownMatrixWidget("syntax-on").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "t")
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Cyan))
        @Expect(buffer.getCell(0, 0).style.modifier.bold, true)
        buffer.clear()
        markdownMatrixWidget("syntax-on", themeName: "light").render(buffer.area, buffer)
        @Expect(Style(fg: buffer.getCell(0, 0).style.fg), Style(fg: Color.Rgb(0, 109, 129)))
        @Expect(buffer.getCell(0, 0).style.modifier.bold, true)
        buffer.clear()
        markdownMatrixWidget("syntax-off").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "t")
        @Expect(buffer.getCell(0, 0).style.modifier.bold, false)
        buffer.clear()
        markdownMatrixWidget("scroll-start").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "F")
        buffer.clear()
        markdownMatrixWidget("scroll-next").render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "S")
    }
}
