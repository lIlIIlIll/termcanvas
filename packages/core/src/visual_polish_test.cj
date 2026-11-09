package core

import std.unittest.*
import std.unittest.testmacro.*

func visualPolishRow(buffer: Buffer, y: Int64): String {
    var result = ""
    for (x in buffer.area.x..buffer.area.right) { result += buffer.getCell(x, y).symbol }
    result
}

@Test
class VisualPolishTest {
    @TestCase
    func progressLabelsStayOutsideTrackAndRepresentTinyValues(): Unit {
        let zero = Buffer(Rect(0, 0, 18, 1))
        ProgressBar(0, total: Int64.Max, labelMode: ProgressBarLabelMode.Percent).render(zero.area, zero)
        @Expect(visualPolishRow(zero, 0), "──────────── 0.00%")
        let tiny = Buffer(zero.area)
        ProgressBar(1, total: Int64.Max, labelMode: ProgressBarLabelMode.Percent).render(tiny.area, tiny)
        @Expect(visualPolishRow(tiny, 0), "╺────────── <0.01%")
        let full = Buffer(zero.area)
        ProgressBar(Int64.Max, total: Int64.Max, labelMode: ProgressBarLabelMode.Percent).render(full.area, full)
        @Expect(visualPolishRow(full, 0), "━━━━━━━━━━ 100.00%")
        let narrow = Buffer(Rect(0, 0, 4, 1))
        ProgressBar(1, total: 2, labelMode: ProgressBarLabelMode.Percent).render(narrow.area, narrow)
        @Expect(visualPolishRow(narrow, 0), " 50%")
        let rounded = Buffer(Rect(0, 0, 14, 1))
        ProgressBar(119, total: 120, labelMode: ProgressBarLabelMode.Percent).render(rounded.area, rounded)
        @Expect(visualPolishRow(rounded, 0), "━━━━━━─ 99.17%")
        let wide = Buffer(Rect(0, 0, 2, 1))
        ProgressBar(1, label: "界界").render(wide.area, wide)
        @Expect(visualPolishRow(wide, 0), " …")
    }

    @TestCase
    func progressUsesAsciiFallbackAndRespectsExplicitSymbols(): Unit {
        let ascii = Buffer(Rect(0, 0, 8, 1))
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        ProgressBar(1, total: 100).render(ascii.area, ascii)
        @Expect(visualPolishRow(ascii, 0), "=-------")
        let custom = Buffer(ascii.area)
        custom.setCapabilities(TerminalCapabilities(unicode: false))
        ProgressBar(1, total: 2, symbols: ProgressBarSymbols(filled: "x", empty: ".", head: "x")).render(custom.area, custom)
        @Expect(visualPolishRow(custom, 0), "xxxx....")
        let vertical = Buffer(Rect(0, 0, 8, 3))
        ProgressBar(1, total: 2, direction: ProgressBarDirection.Vertical, labelMode: ProgressBarLabelMode.Percent).render(vertical.area, vertical)
        @Expect(visualPolishRow(vertical, 0), "50.00%  ")
        @Expect(visualPolishRow(vertical, 1), "────────")
        @Expect(visualPolishRow(vertical, 2), "━━━━━━━━")
    }

    @TestCase
    func sparklineShowsSelectedWindowAndAdaptsSymbols(): Unit {
        let latest = Buffer(Rect(0, 0, 3, 1))
        Sparkline([100, 0, 1, 2], maxValue: 2).render(latest.area, latest)
        @Expect(visualPolishRow(latest, 0), " ▄█")
        let earliest = Buffer(latest.area)
        Sparkline([100, 0, 1, 2], maxValue: 2, latest: false).render(earliest.area, earliest)
        @Expect(visualPolishRow(earliest, 0), "█ ▄")
        let automatic = Buffer(latest.area)
        Sparkline([100, 0, 1, 2]).render(automatic.area, automatic)
        @Expect(visualPolishRow(automatic, 0), " ▄█")
        let tiny = Buffer(latest.area)
        Sparkline([0, 1, Int64.Max]).render(tiny.area, tiny)
        @Expect(visualPolishRow(tiny, 0), " ▁█")
        let ascii = Buffer(latest.area)
        ascii.setCapabilities(TerminalCapabilities(unicode: false))
        Sparkline([0, 1, 2], maxValue: 2).render(ascii.area, ascii)
        @Expect(visualPolishRow(ascii, 0), " -#")
        let custom = Buffer(latest.area)
        Sparkline([0, 1, 2], maxValue: 2, symbols: Some(["a", "b", "c"]), style: Style(fg: Color.Red)).render(custom.area, custom)
        @Expect(visualPolishRow(custom, 0), "abc")
        @Expect(custom.getCell(1, 0).style, Style(fg: Color.Red))
    }
}
