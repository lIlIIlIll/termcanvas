package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ProgressThemeSymbolsTest {
    @TestCase
    func themeSymbolsAreInheritedAndExplicitSymbolsOverride(): Unit {
        let theme = Theme(progressSymbols: ProgressBarSymbols(filled: "X", empty: ".", head: "H", indeterminate: "I"))
        let inherited = Buffer(Rect(0, 0, 8, 1))
        ProgressBar(1, total: 2, theme: theme).render(inherited.area, inherited)
        @Expect(inherited.getCell(0, 0).symbol, "X")
        @Expect(inherited.getCell(3, 0).symbol, "H")
        @Expect(inherited.getCell(4, 0).symbol, ".")
        let tiny = Buffer(inherited.area)
        ProgressBar(1, total: 10000, theme: theme).render(tiny.area, tiny)
        @Expect(tiny.getCell(0, 0).symbol, "X")
        let overridden = Buffer(inherited.area)
        ProgressBar(1, total: 2, theme: theme,
            symbols: ProgressBarSymbols(filled: "a", empty: "b", head: "c")).render(overridden.area, overridden)
        @Expect(overridden.getCell(0, 0).symbol, "a")
        @Expect(overridden.getCell(3, 0).symbol, "c")
        @Expect(overridden.getCell(4, 0).symbol, "b")
        let vertical = Buffer(Rect(0, 0, 1, 3))
        ProgressBar(1, total: 3, theme: theme, direction: ProgressBarDirection.Vertical).render(vertical.area, vertical)
        @Expect(vertical.getCell(0, 2).symbol, "X")
        @Expect(vertical.getCell(0, 0).symbol, ".")
        let moving = Buffer(inherited.area)
        ProgressBar(0, theme: theme, indeterminate: true, phase: 2).render(moving.area, moving)
        @Expect(moving.getCell(0, 0).symbol, "I")
    }

    @TestCase
    func unsafeThemeGlyphsFallBackWithoutDiscardingSafeAscii(): Unit {
        let symbols = ProgressBarSymbols(filled: "━", empty: "─", head: "━", indeterminate: "━")
        let theme = Theme(progressSymbols: symbols)
        let ascii = Buffer(Rect(0, 0, 8, 1))
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        ProgressBar(1, total: 2, theme: theme).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "=")
        @Expect(ascii.getCell(7, 0).symbol, "-")
        let wide = Buffer(ascii.area)
        wide.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        ProgressBar(1, total: 2, theme: theme).render(wide.area, wide)
        @Expect(wide.getCell(0, 0).symbol, "=")
        @Expect(wide.getCell(7, 0).symbol, "-")
        let safe = Theme(progressSymbols: ProgressBarSymbols(filled: "X", empty: ".", head: "X", indeterminate: "X"))
        ProgressBar(1, total: 2, theme: safe).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "X")
        let invalid = Theme(progressSymbols: ProgressBarSymbols(filled: "XX", empty: ".", head: "X", indeterminate: "X"))
        ProgressBar(1, total: 2, theme: invalid).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "=")
        ProgressBar(1, total: 2, theme: safe, symbols: symbols).render(ascii.area, ascii)
        @Expect(ascii.getCell(0, 0).symbol, "━")
        let mono = Buffer(ascii.area)
        mono.setCapabilities(TerminalCapabilities(unicode: true, trueColor: false, colorLevel: 1))
        ProgressBar(1, total: 2, theme: theme).render(mono.area, mono)
        @Expect(mono.getCell(0, 0).symbol, "━")
    }

    @TestCase
    func themeCopiesAndSerializationRetainTheSymbols(): Unit {
        let symbols = ProgressBarSymbols(filled: "#", empty: "-", head: ">", indeterminate: "+")
        let theme = Theme().withProgressSymbols(symbols)
        let serialized = "progressSymbols=1:#1:-1:>1:+"
        @Expect(theme.serialize().contains(serialized), true)
        let converted = theme.withIconSet(IconSet.Ascii).withBorderKind(BorderKind.Rounded).withTerminalBackground()
            .adapted(TerminalCapabilities(unicode: false))
        @Expect(converted.serialize().contains(serialized), true)
        let buffer = Buffer(Rect(0, 0, 8, 1))
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        ProgressBar(1, total: 2, theme: converted).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(3, 0).symbol, ">")
        @Expect(theme.withProgressSymbols(None).serialize().contains("progressSymbols=auto"), true)
        let escaped = Theme(progressSymbols: ProgressBarSymbols(filled: ":", empty: "\n", head: "界", indeterminate: "X"))
        @Expect(escaped.serialize().contains("progressSymbols=1::1:\n3:界1:X"), true)
    }
}
