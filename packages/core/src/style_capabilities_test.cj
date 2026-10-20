package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class StyleCapabilitiesTest {
    @TestCase
    func stylePatchUsesResetAndEmptyModifierAsInheritance(): Unit {
        var baseModifier = Modifier()
        baseModifier.underline = true
        var replacementModifier = Modifier()
        replacementModifier.italic = true
        let base = Style(fg: Color.Red, bg: Color.Blue, modifier: baseModifier)

        @Expect(base.patch(Style()), base)
        @Expect(
            base.patch(Style(fg: Color.Reset, bg: Color.Green, modifier: Modifier.none())),
            Style(fg: Color.Red, bg: Color.Green, modifier: baseModifier)
        )
        @Expect(
            base.patch(Style(modifier: replacementModifier)),
            Style(fg: Color.Red, bg: Color.Blue, modifier: replacementModifier)
        )
    }

    @TestCase
    func semanticThemeFactoriesDefineGraphiteAndLightRoles(): Unit {
        let graphite = Theme.graphite(accent: Color.Magenta)
        @Expect(graphite.normal, Style(fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(18, 21, 26)))
        @Expect(graphite.focused, Style(
            fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(30, 61, 69), modifier: Modifier.strong()))
        @Expect(graphite.selected, Style(
            fg: Color.Rgb(224, 230, 237), bg: Color.Rgb(26, 43, 50), modifier: Modifier.strong()))
        @Expect(graphite.accent, Style(fg: Color.Magenta, bg: Color.Rgb(18, 21, 26)))

        let light = Theme.light(accent: Color.Red)
        @Expect(light.normal, Style(fg: Color.Rgb(31, 41, 51), bg: Color.Rgb(247, 249, 252)))
        @Expect(light.disabled, Style(fg: Color.Rgb(97, 110, 126), bg: Color.Rgb(247, 249, 252)))
        @Expect(light.accent, Style(fg: Color.Red, bg: Color.Rgb(247, 249, 252)))
    }

    @TestCase
    func capabilityTiersAdaptRgbAndIndexedColorsDeterministically(): Unit {
        var modifier = Modifier()
        modifier.bold = true
        modifier.underline = true
        let rgb = Style(fg: Color.Rgb(95, 135, 175), bg: Color.Rgb(0, 0, 0), modifier: modifier)

        let trueColor = adaptStyleForCapabilities(rgb, TerminalCapabilities(trueColor: true))
        @Expect(trueColor, rgb)

        let xterm = adaptStyleForCapabilities(rgb, TerminalCapabilities(trueColor: false, colorLevel: 256))
        @Expect(xterm, Style(fg: Color.Indexed(67), bg: Color.Indexed(0), modifier: modifier))
        @Expect(
            Style(fg: adaptStyleForCapabilities(
                Style(fg: Color.Indexed(240)),
                TerminalCapabilities(trueColor: false, colorLevel: 256)
            ).fg),
            Style(fg: Color.Indexed(240))
        )

        let ansi8 = adaptStyleForCapabilities(rgb, TerminalCapabilities(trueColor: false, colorLevel: 16))
        @Expect(ansi8, Style(fg: Color.Cyan, bg: Color.Black, modifier: modifier))
        @Expect(
            Style(fg: adaptStyleForCapabilities(
                Style(fg: Color.Indexed(67)),
                TerminalCapabilities(trueColor: false, colorLevel: 8)
            ).fg),
            Style(fg: Color.Cyan)
        )

        let monochrome = adaptStyleForCapabilities(rgb, TerminalCapabilities(trueColor: false, colorLevel: 1))
        @Expect(monochrome, Style(modifier: modifier))
        let monoTheme = Theme.forCapabilities(
            TerminalCapabilities(trueColor: false, colorLevel: 1),
            dark: false,
            accent: Color.Red
        )
        @Expect(monoTheme.normal, Style.default())
        @Expect(monoTheme.focused.modifier, Modifier.strong())
    }

    @TestCase
    func reducedTierStylesRenderOnlySupportedAnsiColorForms(): Unit {
        let source = Style(fg: Color.Rgb(95, 135, 175), bg: Color.Rgb(0, 0, 0))
        let xtermText = capabilityAnsiText(adaptStyleForCapabilities(
            source, TerminalCapabilities(trueColor: false, colorLevel: 256)))
        @Assert(xtermText.contains("38;5;67"))
        @Assert(xtermText.contains("48;5;0"))
        @Assert(!xtermText.contains(";2;"))

        let ansi8Text = capabilityAnsiText(adaptStyleForCapabilities(
            source, TerminalCapabilities(trueColor: false, colorLevel: 16)))
        @Assert(ansi8Text.contains("36"))
        @Assert(!ansi8Text.contains(";5;"))
        @Assert(!ansi8Text.contains(";2;"))

        let monoText = capabilityAnsiText(adaptStyleForCapabilities(
            source, TerminalCapabilities(trueColor: false, colorLevel: 1)))
        @Assert(!monoText.contains("38;"))
        @Assert(!monoText.contains("48;"))
    }

    @TestCase
    func themedStatePrecedenceCombinesFocusModifiersWithoutReplacingRoleColors(): Unit {
        var focusedModifier = Modifier()
        focusedModifier.bold = true
        focusedModifier.underline = true
        var selectedModifier = Modifier()
        selectedModifier.italic = true
        var errorModifier = Modifier()
        errorModifier.reversed = true
        let theme = Theme(
            normal: Style(fg: Color.White, bg: Color.Black),
            focused: Style(fg: Color.Cyan, bg: Color.Blue, modifier: focusedModifier),
            selected: Style(fg: Color.Green, bg: Color.Magenta, modifier: selectedModifier),
            disabled: Style(fg: Color.Indexed(8), bg: Color.Black),
            error: Style(fg: Color.Red, bg: Color.Yellow, modifier: errorModifier)
        )

        let selectedBuffer = Buffer(Rect(0, 0, 20, 2))
        RadioGroup(
            ["active", "other"],
            selected: 0,
            focused: true,
            focusedStyle: Style.default(),
            selectedStyle: Style.default(),
            disabledStyle: Style.default(),
            theme: Some(theme)
        ).render(selectedBuffer.area, selectedBuffer)
        var selectedCombined = Modifier()
        selectedCombined.bold = true
        selectedCombined.italic = true
        selectedCombined.underline = true
        @Expect(selectedBuffer.getCell(0, 0).style,
            Style(fg: Color.Green, bg: Color.Magenta, modifier: selectedCombined))

        let disabledBuffer = Buffer(Rect(0, 0, 20, 1))
        RadioGroup(
            ["active"],
            selected: 0,
            focused: true,
            disabled: true,
            focusedStyle: Style.default(),
            selectedStyle: Style.default(),
            disabledStyle: Style.default(),
            theme: Some(theme)
        ).render(disabledBuffer.area, disabledBuffer)
        @Expect(disabledBuffer.getCell(0, 0).style, theme.disabled)
        var errorCombined = Modifier()
        errorCombined.bold = true
        errorCombined.underline = true
        errorCombined.reversed = true
        let errorOverridesSelected = resolvedSemanticStateStyle(
            Style.default(),
            Style.default(),
            Style.default(),
            Style.default(),
            Style.default(),
            true,
            true,
            false,
            true,
            Some(theme)
        )
        @Expect(errorOverridesSelected,
            Style(fg: Color.Red, bg: Color.Yellow, modifier: errorCombined))

        let disabledOverridesAll = resolvedSemanticStateStyle(
            Style.default(),
            Style.default(),
            Style.default(),
            Style.default(),
            Style.default(),
            true,
            true,
            true,
            true,
            Some(theme)
        )
        @Expect(disabledOverridesAll, theme.disabled)

    }

    @TestCase
    func noThemeRadioGroupKeepsSelectedFocusLegacyFallback(): Unit {
        let selectedStyle = Style(fg: Color.Blue, bg: Color.White)
        let radioBuffer = Buffer(Rect(0, 0, 20, 1))
        RadioGroup(
            ["active"],
            selected: 0,
            focused: true,
            focusedStyle: Style(fg: Color.Green),
            selectedStyle: selectedStyle
        ).render(radioBuffer.area, radioBuffer)
        @Expect(radioBuffer.getCell(0, 0).style, selectedStyle)
    }
    @TestCase
    func dropdownSemanticStylesRespectSelectedStyleAndDisabledInput(): Unit {
        var focusedModifier = Modifier()
        focusedModifier.bold = true
        focusedModifier.underline = true
        var selectedModifier = Modifier()
        selectedModifier.italic = true
        let theme = Theme(
            normal: Style(fg: Color.White, bg: Color.Black),
            focused: Style(fg: Color.Cyan, bg: Color.Blue, modifier: focusedModifier),
            selected: Style(fg: Color.Green, bg: Color.Magenta, modifier: selectedModifier),
            disabled: Style(fg: Color.Indexed(8), bg: Color.Black),
            error: Style.default()
        )
        let area = Rect(0, 0, 20, 3)
        let themed = Dropdown(["active", "other"], open: true, selectedStyle: Style.default())
        themed.setVisualState(focused: true, theme: Some(theme))
        let themedBuffer = Buffer(area)
        themed.render(area, themedBuffer)
        var combined = Modifier()
        combined.bold = true
        combined.italic = true
        combined.underline = true
        @Expect(themedBuffer.getCell(0, 0).style, theme.focused)
        @Expect(themedBuffer.getCell(0, 1).style,
            Style(fg: Color.Green, bg: Color.Magenta, modifier: combined))
        @Expect(themedBuffer.getCell(0, 2).style, theme.normal)

        let explicitStyle = Style(fg: Color.Red, bg: Color.Yellow)
        let explicit = Dropdown(["active", "other"], open: true, selectedStyle: explicitStyle)
        explicit.setVisualState(theme: Some(theme))
        let explicitBuffer = Buffer(area)
        explicit.render(area, explicitBuffer)
        @Expect(explicitBuffer.getCell(0, 1).style, explicitStyle)

        let disabled = Dropdown(["active", "other"], selected: 1, open: true, selectedStyle: Style.default())
        disabled.setVisualState(disabled: true, theme: Some(theme))
        let disabledBuffer = Buffer(area)
        disabled.render(area, disabledBuffer)
        @Expect(disabledBuffer.getCell(0, 0).style, theme.disabled)
        @Expect(disabledBuffer.getCell(0, 1).style, theme.disabled)
        @Expect(disabledBuffer.getCell(0, 2).style, theme.disabled)
        @Expect(disabled.handle(KeyEvent(KeyCode.Down)).isNone())
        @Expect(disabled.selected, 1)
        @Expect(
            disabled.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 2), area).isNone()
        )
        @Expect(disabled.selected, 1)

        let disabledClosed = Dropdown(["active"])
        disabledClosed.setVisualState(disabled: true, theme: Some(theme))
        _ = disabledClosed.handle(KeyEvent(KeyCode.Enter))
        @Expect(!disabledClosed.open)
        _ = disabledClosed.handleMouse(MouseEvent(MouseKind.Down, MouseButton.Left, 1, 0), area)
        @Expect(!disabledClosed.open)
    }
}

private func capabilityAnsiText(style: Style): String {
    let output = TestOutput()
    let backend = AnsiBackend(output: output, fallbackArea: Rect(0, 0, 1, 1))
    let buffer = Buffer(Rect(0, 0, 1, 1))
    buffer.setString(0, 0, "x", style: style)
    backend.draw(buffer)
    output.text()
}
