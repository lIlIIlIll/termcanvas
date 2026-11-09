package core

import std.unittest.*
import std.unittest.testmacro.*

class ThemeContextInput <: InputSource {
    private var sent = false
    public func readAvailable(_: Int64): Array<Byte> {
        if (sent) { return [] }
        sent = true
        [b'q']
    }
}

class ThemeSwitchInput <: InputSource {
    private var sent = false
    public func readAvailable(_: Int64): Array<Byte> {
        if (sent) { return [] }
        sent = true
        [b'a', b'q']
    }
}

class ThemeContextDriver <: TerminalDriver {
    public func name(): String { "test" }
    public func enterRawMode(): Bool { false }
    public func restore(): Unit {}
    public func size(): ?Rect { Some(Rect(0, 0, 8, 1)) }
    public func capabilities(backend: Backend): TerminalCapabilities { TerminalCapabilities(size: backend.size()) }
}

@Test
class AppThemeContextTest {
    @TestCase
    func appPassesThemeToOrdinaryComponents(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 1))
        let app = App(backend: backend, inputSource: ThemeContextInput(), terminalDriver: ThemeContextDriver(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false)
        let theme = Theme(focused: Style(fg: Color.Yellow, bg: Color.Blue))
        app.setTheme(theme)
        app.runWithCommands(
            { frame => frame.renderWidget(Button("OK", focused: true), frame.area) },
            { event => match (event) { case Event.KeyDown(_) => UpdateResult.exit(); case _ => UpdateResult.unchanged() } }
        )
        let result = backend.lastBuffer().getOrThrow()
        var modifier = Modifier.strong()
        modifier.underline = true
        @Expect(result.getCell(3, 0).style, theme.focused.withModifier(modifier))
        @Expect(result.theme().isSome())
    }

    @TestCase
    func updateCanSwitchThemeWithoutReturningChanged(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 8, 1))
        let metrics = AppMetrics()
        let app = App(backend: backend, inputSource: ThemeSwitchInput(), terminalDriver: ThemeContextDriver(),
            rawMode: false, alternateScreen: false, hideCursor: false, bracketedPaste: false, resize: false, metrics: metrics)
        let first = Theme(focused: Style(fg: Color.Yellow, bg: Color.Blue))
        let second = Theme(focused: Style(fg: Color.White, bg: Color.Green))
        app.setTheme(first)
        app.runWithCommands(
            { frame => frame.renderWidget(Button("OK", focused: true), frame.area) },
            { event => match (event) {
                case Event.KeyDown(key) => match (key.code) {
                    case KeyCode.Char(r'a') => app.setTheme(second); UpdateResult.unchanged()
                    case KeyCode.Char(r'q') => UpdateResult.exit()
                    case _ => UpdateResult.unchanged()
                }
                case _ => UpdateResult.unchanged()
            } }
        )
        var modifier = Modifier.strong()
        modifier.underline = true
        @Expect(metrics.frames().size >= 2)
        @Expect(backend.lastBuffer().getOrThrow().getCell(3, 0).style, second.focused.withModifier(modifier))
    }

    @TestCase
    func terminalThemeChangeForcesRedrawAndExplicitThemeWins(): Unit {
        let backend = TestBackend(area: Rect(0, 0, 12, 1))
        let terminal = Terminal(backend)
        let first = Theme(focused: Style(fg: Color.Yellow, bg: Color.Blue))
        let second = Theme(focused: Style(fg: Color.White, bg: Color.Green))
        let explicit = Theme(focused: Style(fg: Color.White, bg: Color.Red))
        let render = { frame: Frame =>
            frame.renderWidget(Button("A", focused: true), Rect(0, 0, 6, 1))
            frame.renderWidget(Button("B", focused: true, theme: explicit), Rect(6, 0, 6, 1))
        }
        terminal.setTheme(first)
        _ = terminal.draw(render)
        var modifier = Modifier.strong()
        modifier.underline = true
        let initial = backend.lastBuffer().getOrThrow()
        @Expect(initial.getCell(2, 0).style, first.focused.withModifier(modifier))
        @Expect(initial.getCell(8, 0).style, explicit.focused.withModifier(modifier))
        terminal.setTheme(second)
        let metrics = terminal.draw(render, dirtyRects: DirtyRects.full(Rect(0, 0, 1, 1)))
        @Expect(metrics.fullRedraw)
        let result = backend.lastBuffer().getOrThrow()
        @Expect(result.getCell(2, 0).style, second.focused.withModifier(modifier))
        @Expect(result.getCell(8, 0).style, explicit.focused.withModifier(modifier))
        terminal.setTheme(Option<Theme>.None)
        let clearedMetrics = terminal.draw(render, dirtyRects: DirtyRects.full(Rect(0, 0, 1, 1)))
        @Expect(clearedMetrics.fullRedraw)
        let cleared = backend.lastBuffer().getOrThrow()
        @Expect(cleared.getCell(2, 0).style, Style(fg: Color.Black, bg: Color.White, modifier: modifier))
        @Expect(cleared.getCell(8, 0).style, explicit.focused.withModifier(modifier))
    }

    @TestCase
    func inheritedThemeTracksTerminalCapabilitiesAndExplicitOverride(): Unit {
        let theme = Theme(iconSet: IconSet.NerdFont, focused: Style(fg: Color.Yellow, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 8, 2))
        buffer.setTheme(theme)
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        let inheritedAscii = match (buffer.resolveTheme(Option<Theme>.None).getOrThrow().iconSet) {
            case IconSet.Ascii => true
            case _ => false
        }
        @Expect(inheritedAscii)
        let explicitNerd = match (buffer.resolveTheme(theme).getOrThrow().iconSet) {
            case IconSet.NerdFont => true
            case _ => false
        }
        @Expect(explicitNerd)
        buffer.setCapabilities(TerminalCapabilities(unicode: true))
        let inheritedNerd = match (buffer.resolveTheme(Option<Theme>.None).getOrThrow().iconSet) {
            case IconSet.NerdFont => true
            case _ => false
        }
        @Expect(inheritedNerd)
        Checkbox("ok", focused: true).render(Rect(0, 0, 8, 1), buffer)
        @Expect(buffer.getCell(0, 0).style, theme.focused)
        Checkbox("ok", focused: true, focusedStyle: Style(fg: Color.Red)).render(Rect(0, 1, 8, 1), buffer)
        @Expect(buffer.getCell(0, 1).style, theme.focused.patch(Style(fg: Color.Red)))
    }

    @TestCase
    func copiedBuffersAndBlocksKeepContextAndBorderGeometry(): Unit {
        let theme = Theme(borderKind: BorderKind.NoBorder, canvas: Style(bg: Color.Blue),
            focused: Style(fg: Color.Yellow, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 10, 4))
        buffer.setTheme(theme)
        let area = Rect(1, 1, 8, 3)
        let block = Block()
        @Expect(block.inner(area, theme: theme), area)
        @Expect(block.renderInner(area, buffer), area)
        @Expect(block.inner(area), area)
        @Expect(buffer.getCell(1, 1).style, theme.canvas)
        let copy = buffer.copy()
        let resized = buffer.resize(Rect(0, 0, 12, 4))
        @Expect(copy.resolveTheme(Option<Theme>.None).getOrThrow().canvas, theme.canvas)
        @Expect(resized.resolveTheme(Option<Theme>.None).getOrThrow().canvas, theme.canvas)
        let explicit = Block(BlockOptions(theme: Theme(borderKind: BorderKind.Ascii)))
        @Expect(explicit.inner(area, theme: theme), Rect(2, 2, 6, 1))
    }
}
