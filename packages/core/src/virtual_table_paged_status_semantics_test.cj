package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class VirtualTablePagedStatusSemanticsTest {
    private func modelWithFailedAndMissingPage(): PagedTableModel {
        let model = PagedTableModel(pageSize: 1)
        let first = model.requestViewport(0, 1)[0]
        @Assert(model.accept(first, TablePage([TableDataRow("one", ["one"])], 3)))
        let failed = model.requestViewport(1, 1)[0]
        @Assert(model.fail(failed, "failed page"))
        model
    }

    @TestCase
    func defaultPagedErrorAndLoadingUseDistinctRolesOnExistingSurface(): Unit {
        let model = modelWithFailedAndMissingPage()
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.fill(buffer.area, style: Style(bg: Color.Blue))
        buffer.setCell(1, 2, Cell(" ", style: Style(bg: Color.Magenta)))
        let theme = Theme(disabled: Style(fg: Color.White),
            error: Style(fg: Color.Yellow, modifier: Modifier.strong()))
        buffer.setTheme(theme)
        VirtualTable([TableColumn("name", width: 12)], model).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 2).symbol, "f")
        @Expect(buffer.getCell(1, 2).style, Style(fg: Color.Yellow, bg: Color.Magenta, modifier: Modifier.strong()))
        @Expect(buffer.getCell(0, 3).symbol, "L")
        @Expect(buffer.getCell(0, 3).style, Style(fg: Color.White, bg: Color.Blue))
    }

    @TestCase
    func unthemedAndExplicitStatusStylesRetainTheirContracts(): Unit {
        let model = modelWithFailedAndMissingPage()
        let plain = Buffer(Rect(0, 0, 12, 4))
        plain.fill(plain.area, style: Style(bg: Color.Blue))
        VirtualTable([TableColumn("name", width: 12)], model).render(plain.area, plain)
        @Expect(plain.getCell(0, 2).style, Style(fg: Color.Red, bg: Color.Blue))
        @Expect(plain.getCell(0, 3).style, Style(fg: Color.Indexed(8), bg: Color.Blue))

        let explicit = Buffer(Rect(0, 0, 12, 4))
        explicit.setTheme(Theme(disabled: Style(fg: Color.White, bg: Color.Magenta),
            error: Style(fg: Color.Yellow, bg: Color.Red)))
        VirtualTable([TableColumn("name", width: 12)], 0, { _ => Array<String>() },
            dataModel: Some(model), statusStyle: Style(fg: Color.Green)).render(explicit.area, explicit)
        @Expect(explicit.getCell(0, 2).style, Style(fg: Color.Green, bg: Color.Magenta))
        @Expect(explicit.getCell(0, 3).style, Style(fg: Color.Green, bg: Color.Magenta))
    }

    @TestCase
    func monochromeFailureAndLoadingHaveDifferentModifiers(): Unit {
        let model = modelWithFailedAndMissingPage()
        for (themed in [false, true]) {
            let buffer = Buffer(Rect(0, 0, 12, 4))
            let caps = TerminalCapabilities(trueColor: false, colorLevel: 1)
            buffer.setCapabilities(caps)
            if (themed) { buffer.setTheme(Theme.indigo()) }
            VirtualTable([TableColumn("name", width: 12)], model).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 2).symbol, "f")
            @Expect(buffer.getCell(0, 3).symbol, "L")
            if (themed) { @Expect(buffer.getCell(0, 2).style.modifier.italic, true) }
            @Expect(buffer.getCell(0, 2).style.modifier.underline, true)
            @Expect(buffer.getCell(0, 3).style.modifier.underline, false)
            @Expect(adaptStyleForCapabilities(buffer.getCell(0, 2).style, caps) ==
                adaptStyleForCapabilities(buffer.getCell(0, 3).style, caps), false)
        }
    }

    @TestCase
    func restrictedPaletteCollisionsRemainDistinguishable(): Unit {
        let model = modelWithFailedAndMissingPage()
        let theme = Theme(normal: Style(fg: Color.White, bg: Color.Black),
            disabled: Style(fg: Color.Rgb(140, 0, 0), bg: Color.Black),
            error: Style(fg: Color.Rgb(150, 0, 0), bg: Color.Black))
        for (level in [Int64(8), 16]) {
            let caps = TerminalCapabilities(trueColor: false, colorLevel: level)
            let adapted = theme.adapted(caps)
            @Expect(Style(fg: adapted.error.fg, modifier: adapted.error.modifier),
                Style(fg: adapted.disabled.fg, modifier: adapted.disabled.modifier))
            let buffer = Buffer(Rect(0, 0, 12, 4))
            buffer.setCapabilities(caps)
            buffer.fill(buffer.area, style: Style(bg: Color.Blue))
            buffer.setTheme(theme)
            VirtualTable([TableColumn("name", width: 12)], model).render(buffer.area, buffer)
            let failed = adaptStyleForCapabilities(buffer.getCell(0, 2).style, caps)
            let loading = adaptStyleForCapabilities(buffer.getCell(0, 3).style, caps)
            @Expect(failed == loading, false)
            @Expect(failed.modifier.underline, true)
            @Expect(loading.modifier.underline, false)
            @Expect(Style(bg: buffer.getCell(0, 2).style.bg), Style(bg: Color.Blue))

            let explicit = Buffer(Rect(0, 0, 12, 4))
            explicit.setCapabilities(caps)
            explicit.setTheme(theme)
            VirtualTable([TableColumn("name", width: 12)], 0, { _ => Array<String>() },
                dataModel: Some(model), statusStyle: Style(fg: Color.Green)).render(explicit.area, explicit)
            @Expect(explicit.getCell(0, 2).style, explicit.getCell(0, 3).style)
        }
    }

    @TestCase
    func distinctRestrictedColorsKeepTheErrorModifier(): Unit {
        let model = modelWithFailedAndMissingPage()
        let theme = Theme(disabled: Style(fg: Color.White), error: Style(fg: Color.Red))
        for (level in [Int64(8), 16, 256]) {
            let buffer = Buffer(Rect(0, 0, 12, 4))
            buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: level))
            buffer.setTheme(theme)
            VirtualTable([TableColumn("name", width: 12)], model).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 2).style.modifier, theme.error.modifier)
            @Expect(buffer.getCell(0, 2).style.modifier.underline, false)
        }
    }

    @TestCase
    func indexedPaletteCollisionAlsoKeepsFailureDistinct(): Unit {
        let model = modelWithFailedAndMissingPage()
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 256)
        let theme = Theme(normal: Style(fg: Color.White),
            disabled: Style(fg: Color.Indexed(1)), error: Style(fg: Color.Indexed(1)))
        let buffer = Buffer(Rect(0, 0, 12, 4))
        buffer.setCapabilities(caps)
        buffer.setTheme(theme)
        VirtualTable([TableColumn("name", width: 12)], model).render(buffer.area, buffer)
        @Expect(adaptStyleForCapabilities(buffer.getCell(0, 2).style, caps) ==
            adaptStyleForCapabilities(buffer.getCell(0, 3).style, caps), false)
        @Expect(buffer.getCell(0, 2).style.modifier.underline, true)
    }
}
