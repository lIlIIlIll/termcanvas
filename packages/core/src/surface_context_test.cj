package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class SurfaceContextTest {
    @TestCase
    func createdSurfaceSnapshotsThemeCapabilitiesAndWidth(): Unit {
        let area = Rect(0, 0, 8, 2)
        let parent = Buffer(area)
        let theme = Theme(normal: Style(fg: Color.Green))
        parent.setTheme(theme)
        parent.setCapabilities(TerminalCapabilities(unicode: false))
        parent.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        let canvas = Canvas(parent, area)
        let surface = canvas.createSurface(area, zIndex: 3)
        @Expect(surface.zIndex, 3)
        @Expect(!surface.bufferView().capabilities().unicode)
        Paragraph("·X").render(area, surface.bufferView())
        canvas.composite(surface)
        @Expect(parent.getCell(0, 0).symbol, "·")
        @Expect(parent.getCell(0, 0).style, theme.normal)
        @Expect(parent.getCell(1, 0), Cell("", style: theme.normal, kind: CellKind.WideCont))
        @Expect(parent.getCell(2, 0).symbol, "X")
        parent.setTheme(Theme(normal: Style(fg: Color.Red)))
        parent.setCapabilities(TerminalCapabilities(unicode: true))
        @Expect(!surface.bufferView().capabilities().unicode)
        @Expect(surface.bufferView().resolveTheme(Option<Theme>.None).getOrThrow().normal, theme.normal)
    }

    @TestCase
    func activeParentThemeIsSnapshottedWithoutAdaptingExplicitColors(): Unit {
        let area = Rect(0, 0, 8, 2)
        let buffer = Buffer(area)
        let app = Theme(normal: Style(fg: Color.Rgb(10, 200, 10)))
        let local = Theme(normal: Style(fg: Color.Rgb(200, 10, 10)))
        let child = Theme(normal: Style(fg: Color.Blue))
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 16))
        buffer.setTheme(app)
        let surfaces = [Surface(area)]
        buffer.withParentTheme(local) { => surfaces[0] = Canvas(buffer, area).createSurface(area) }
        let surface = surfaces[0]
        @Expect(surface.bufferView().theme().getOrThrow().normal, app.normal)
        Paragraph("A").render(area, surface.bufferView())
        @Expect(surface.bufferView().getCell(0, 0).style, local.normal)
        surface.bufferView().withParentTheme(child) { => Paragraph("B").render(area, surface.bufferView()) }
        @Expect(surface.bufferView().getCell(0, 0).style, child.normal)
        Paragraph("C").render(area, surface.bufferView())
        @Expect(surface.bufferView().getCell(0, 0).style, local.normal)
        surface.bufferView().setTheme(child)
        Paragraph("D").render(area, surface.bufferView())
        @Expect(surface.bufferView().getCell(0, 0).style, child.adapted(surface.bufferView().capabilities()).normal)
        @Expect(buffer.resolveTheme(Option<Theme>.None).getOrThrow().normal, app.adapted(buffer.capabilities()).normal)
    }

    @TestCase
    func standaloneSurfaceAndBufferCopiesKeepIndependentContexts(): Unit {
        let area = Rect(0, 0, 8, 2)
        let source = Buffer(area)
        let parent = Theme(normal: Style(fg: Color.Red))
        let copies = [Buffer(area), Buffer(area)]
        source.withParentTheme(parent) { =>
            copies[0] = source.copy()
            copies[1] = source.resize(Rect(0, 0, 9, 2))
        }
        @Expect(copies[0].resolveTheme(Option<Theme>.None).getOrThrow().normal, parent.normal)
        @Expect(copies[1].resolveTheme(Option<Theme>.None).getOrThrow().normal, parent.normal)
        @Expect(source.resolveTheme(Option<Theme>.None).isNone())
        @Expect(Surface(area).bufferView().theme().isNone())
    }
}
