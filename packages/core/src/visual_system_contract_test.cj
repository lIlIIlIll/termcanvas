package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class VisualSystemContractTest {
    @TestCase
    func layeredOverridesCanInheritSetAndClearIndependently(): Unit {
        var modifiers = Modifier.strong()
        modifiers.underline = true
        let base = Style(fg: Color.White, bg: Color.Blue, modifier: modifiers)
        let override = StyleOverride(bg: Some(Color.Reset), bold: Some(false), italic: Some(true))
        var expectedModifier = Modifier()
        expectedModifier.italic = true
        expectedModifier.underline = true
        @Expect(override.apply(base), Style(fg: Color.White, modifier: expectedModifier))
        @Expect(StyleOverride().apply(base), base)
        @Expect(StyleOverride(fg: Some(Color.Red)).apply(override.apply(base)),
            Style(fg: Color.Red, modifier: expectedModifier))
    }

    @TestCase
    func terminalBackgroundIsResetAndThemeBorderSurvivesAdaptation(): Unit {
        let theme = Theme.indigo().withBorderKind(BorderKind.Double).withTerminalBackground()
        @Expect(theme.canvas, Theme.indigo().canvas.withBg(Color.Reset))
        @Expect(theme.focused, Theme.indigo().focused.withBg(Color.Reset))
        let area = Rect(0, 0, 5, 3)
        let buffer = Buffer(area)
        Block(BlockOptions(theme: Some(theme.adapted(TerminalCapabilities())))).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╔")
        Block(BlockOptions(theme: Some(theme), borderKind: BorderKind.Ascii)).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        Block(BlockOptions(theme: Some(theme))).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "+")
        Block(BlockOptions(theme: Some(theme), borderKind: BorderKind.Double)).render(area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "╔")
        let noBorder = Theme.indigo().withBorderKind(BorderKind.NoBorder)
        @Expect(Block(BlockOptions(theme: Some(noBorder))).inner(area), area)
        @Expect(Block(BlockOptions(theme: Some(noBorder), border: BorderSet.ascii())).inner(area), Rect(1, 1, 3, 1))
    }

    @TestCase
    func canvasAndBlockUseSameBoundaryForNormalAndTinyAreas(): Unit {
        let areas = [Rect(1, 1, 5, 3), Rect(1, 1, 1, 3), Rect(1, 1, 5, 1), Rect(1, 1, 1, 1)]
        for (area in areas) {
            let blockBuffer = Buffer(Rect(0, 0, 8, 5))
            let canvasBuffer = Buffer(blockBuffer.area)
            Block(BlockOptions(border: BorderSet.doubleLine())).render(area, blockBuffer)
            Canvas(canvasBuffer, canvasBuffer.area).strokeBorder(area, Style.default(), border: BorderSet.doubleLine())
            for (y in 0..5) {
                for (x in 0..8) {
                    @Expect(canvasBuffer.getCell(x, y).symbol, blockBuffer.getCell(x, y).symbol)
                }
            }
        }
    }

    @TestCase
    func trueSixteenColorAdaptationKeepsBrightPalette(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 16)
        @Expect(adaptStyleForCapabilities(Style(fg: Color.Rgb(255, 255, 255),
            bg: Color.Rgb(127, 127, 127)), caps), Style(fg: Color.Indexed(15), bg: Color.Indexed(8)))
        @Expect(adaptStyleForCapabilities(Style(fg: Color.Indexed(9)), caps), Style(fg: Color.Indexed(9)))
    }

    @TestCase
    func defaultThemeAndStateOverridesAreConsistent(): Unit {
        @Expect(Theme().normal, Theme.indigo().normal)
        @Expect(Theme.default().accent, Theme.indigo().accent)
        @Expect(Theme.forCapabilities(TerminalCapabilities()).normal, Theme.indigo().normal)
        let mono = Theme.default().adapted(TerminalCapabilities(trueColor: false, colorLevel: 1))
        let all = mono.resolveState(focused: true, selected: true, error: true)
        @Assert(all.modifier.underline)
        @Assert(all.modifier.reversed)
        @Assert(all.modifier.italic)
        let cleared = mono.resolveState(focused: true, selected: true, error: true,
            override: StyleOverride(underline: Some(false), bg: Some(Color.Reset)))
        @Assert(!cleared.modifier.underline)
        @Assert(cleared.modifier.reversed && cleared.modifier.italic)
        @Expect(mono.resolveState(focused: true, selected: true, error: true, disabled: true), mono.disabled)
    }

    @TestCase
    func monochromeInputAndRadioExposeIndependentStateCues(): Unit {
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 1)
        let theme = Theme.default().adapted(caps)
        let area = Rect(0, 0, 12, 1)
        let normal = Buffer(area)
        let bad = Buffer(area)
        let focusedBad = Buffer(area)
        normal.setCapabilities(caps)
        bad.setCapabilities(caps)
        focusedBad.setCapabilities(caps)
        let input = Input(value: "hello")
        input.setVisualState(theme: Some(theme))
        input.render(area, normal)
        input.setVisualState(error: true, theme: Some(theme))
        input.render(area, bad)
        input.setVisualState(focused: true, error: true, theme: Some(theme))
        input.render(area, focusedBad)
        @Assert(!normal.getCell(1, 0).style.modifier.italic)
        @Assert(bad.getCell(1, 0).style.modifier.italic)
        @Assert(focusedBad.getCell(1, 0).style.modifier.italic)
        @Assert(focusedBad.getCell(1, 0).style.modifier.underline)
        let radio = Buffer(area)
        radio.setCapabilities(caps)
        RadioGroup(["choice"], focused: true, focusedStyle: Style.default(),
            selectedStyle: Style.default(), theme: Some(theme)).render(area, radio)
        @Assert(radio.getCell(0, 0).style.modifier.reversed)
        @Assert(radio.getCell(0, 0).style.modifier.underline)
    }
}
