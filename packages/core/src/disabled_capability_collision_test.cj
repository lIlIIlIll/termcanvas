package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class DisabledCapabilityCollisionTest {
    @TestCase
    func builtInThemesKeepDisabledAndNormalDistinctAcrossTiers(): Unit {
        for (theme in [Theme.default(), Theme.indigo(), Theme.graphite(), Theme.light()]) {
            for (level in [1, 8, 16]) {
                let caps = TerminalCapabilities(trueColor: false, colorLevel: level)
                let adapted = theme.adapted(caps)
                @Expect(adapted.disabled != adapted.normal)
                @Expect(adapted.resolveState(disabled: true), adapted.disabled)
                @Expect(adapted.resolveState(disabled: true, focused: true), adapted.disabled)
                @Expect(adapted.resolveState(disabled: true, selected: true), adapted.disabled)
                @Expect(adapted.resolveState(disabled: true, error: true, focused: true, selected: true), adapted.disabled)
                @Expect(adapted.resolveState(focused: true), adapted.focused)
                @Expect(adapted.resolveState(selected: true), adapted.selected)
                @Expect(adapted.resolveState(error: true), adapted.error)
            }
        }
    }

    @TestCase
    func switchesShowDisabledStateWhenEightColorRolesPreviouslyCollapsed(): Unit {
        let area = Rect(0, 0, 12, 1)
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 8)
        for (theme in [Theme.default(), Theme.indigo(), Theme.graphite(), Theme.light()]) {
            let enabledBuffer = Buffer(area)
            enabledBuffer.setCapabilities(caps)
            enabledBuffer.setTheme(theme)
            let disabledBuffer = Buffer(area)
            disabledBuffer.setCapabilities(caps)
            disabledBuffer.setTheme(theme)
            let enabled = Switch("Build")
            let disabled = Switch("Build", disabled: true)
            enabled.render(area, enabledBuffer)
            disabled.render(area, disabledBuffer)
            @Expect(enabledBuffer.getCell(0, 0).symbol, disabledBuffer.getCell(0, 0).symbol)
            @Expect(enabledBuffer.getCell(0, 0).style != disabledBuffer.getCell(0, 0).style)
            @Expect(enabled.handle(KeyEvent(KeyCode.Enter)))
            @Expect(!disabled.handle(KeyEvent(KeyCode.Enter)))
        }
    }

    @TestCase
    func adaptationPreservesExplicitEqualityAndExistingModifiers(): Unit {
        var original = Modifier.none()
        original.italic = true
        let normal = Style(fg: Color.Rgb(225, 226, 235), modifier: original)
        let disabled = Style(fg: Color.Rgb(157, 160, 181), modifier: original)
        let caps = TerminalCapabilities(trueColor: false, colorLevel: 8)
        let distinct = Theme(normal: normal, disabled: disabled).adapted(caps)
        @Expect(distinct.normal.modifier, original)
        @Expect(distinct.disabled.modifier.italic)
        @Expect(distinct.disabled.modifier.underline)
        @Expect(distinct.disabled != distinct.normal)
        let cleared = distinct.resolveState(disabled: true, override: StyleOverride(underline: false))
        @Expect(cleared, distinct.normal)
        for (level in [1, 8, 16]) {
            let same = Theme(normal: normal, disabled: normal).adapted(
                TerminalCapabilities(trueColor: false, colorLevel: level))
            @Expect(same.disabled, same.normal)
            @Expect(same.disabled.modifier, original)
        }
        let alreadyDistinct = Theme.light().adapted(TerminalCapabilities(trueColor: false, colorLevel: 16))
        @Expect(alreadyDistinct.disabled, adaptStyleForCapabilities(Theme.light().disabled,
            TerminalCapabilities(trueColor: false, colorLevel: 16)))
    }

    @TestCase
    func fullySpecifiedModifiersAreNeverClearedToCreateAContrast(): Unit {
        var all = Modifier.none()
        all.bold = true
        all.italic = true
        all.underline = true
        all.reversed = true
        let normal = Style(fg: Color.Rgb(225, 226, 235), modifier: all)
        let disabled = Style(fg: Color.Rgb(157, 160, 181), modifier: all)
        let adapted = Theme(normal: normal, disabled: disabled).adapted(
            TerminalCapabilities(trueColor: false, colorLevel: 8))
        @Expect(adapted.disabled.modifier, all)
        @Expect(adapted.disabled, adapted.normal)
    }
}
