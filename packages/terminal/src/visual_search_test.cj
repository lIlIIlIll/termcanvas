package terminal

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalSearchStyleTest {
    @TestCase
    func searchOverridePreservesAnsiAndCanResetBackground(): Unit {
        let transcript = TerminalTranscript(cols: 6, rows: 1)
        transcript.append("\u{1B}[31;44m中x")
        let buffer = Buffer(Rect(0, 0, 6, 1))
        let theme = Theme(selected: Style(bg: Color.Green))
        TerminalView(transcript, search: "中", searchStyle: StyleOverride(bg: Some(theme.selected.bg)))
            .render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0), Cell("中", style: Style(fg: Color.Red, bg: Color.Green), kind: CellKind.WideLead))
        @Expect(buffer.getCell(1, 0), Cell("", style: Style(fg: Color.Red, bg: Color.Green), kind: CellKind.WideCont))
        @Expect(buffer.getCell(2, 0), Cell("x", style: Style(fg: Color.Red, bg: Color.Blue)))
        TerminalView(transcript, search: "x", searchStyle: StyleOverride(bg: Some(Color.Reset)))
            .render(buffer.area, buffer)
        @Expect(buffer.getCell(2, 0), Cell("x", style: Style(fg: Color.Red)))
        @Expect(transcript.screen.cell(2, 0), Cell("x", style: Style(fg: Color.Red, bg: Color.Blue)))
    }
}
