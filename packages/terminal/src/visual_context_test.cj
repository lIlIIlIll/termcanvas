package terminal

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalVisualContextTest {
    @TestCase
    func widthPolicyIsFixedBeforeFeedAndMismatchLeavesTargetUntouched(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let screen = TerminalScreen(cols: 8, rows: 1, textWidthOptions: wide)
        screen.feed("·X")
        let target = Buffer(Rect(0, 0, 8, 1))
        var failed = false
        try { screen.render(target.area, target) } catch (_: IllegalArgumentException) { failed = true }
        @Expect(failed, true)
        @Expect(target.getCell(0, 0).symbol, " ")
        target.setTextWidthOptions(wide)
        screen.render(target.area, target)
        @Expect(match (target.getCell(0, 0).kind) { case CellKind.WideLead => true; case _ => false }, true)
        @Expect(match (target.getCell(1, 0).kind) { case CellKind.WideCont => true; case _ => false }, true)
        @Expect(target.getCell(2, 0).symbol, "X")
        @Expect(screen.matchesTextWidthOptions(wide), true)
    }

    @TestCase
    func transcriptPassesWidePolicyAndRejectsMismatchBeforeBlock(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let transcript = TerminalTranscript(cols: 8, rows: 1, textWidthOptions: wide)
        transcript.append("·X")
        let target = Buffer(Rect(0, 0, 12, 3))
        var failed = false
        try { TerminalView(transcript, block: Block(title: "screen")).render(target.area, target) }
        catch (_: IllegalArgumentException) { failed = true }
        @Expect(failed, true)
        @Expect(target.getCell(0, 0).symbol, " ")
        target.setTextWidthOptions(wide)
        TerminalView(transcript, search: "·").render(target.area, target)
        @Expect(match (target.getCell(0, 0).kind) { case CellKind.WideLead => true; case _ => false }, true)
        @Expect(target.getCell(2, 0).symbol, "X")
        @Expect(target.getCell(0, 0).style.modifier.underline, true)
    }

    @TestCase
    func defaultHighlightUsesThemeAndPreservesAnsiWithMonochromeCue(): Unit {
        let transcript = TerminalTranscript(cols: 8, rows: 1)
        transcript.append("\u{1B}[31;44mred")
        let target = Buffer(Rect(0, 0, 8, 1))
        let theme = Theme(selected: Style(bg: Color.Green))
        target.setTheme(Some(theme))
        TerminalView(transcript, search: "red").render(target.area, target)
        @Expect(target.getCell(0, 0).style, Style(fg: Color.Red, bg: Color.Green, modifier: underline()))
        @Expect(target.getCell(0, 0).style.modifier.underline, true)
        @Expect(transcript.screen.cell(0, 0).style, Style(fg: Color.Red, bg: Color.Blue))
        target.setCapabilities(TerminalCapabilities(colorLevel: 0, trueColor: false))
        TerminalView(transcript, search: "red").render(target.area, target)
        @Expect(target.getCell(0, 0).style.modifier.underline, true)
    }

    @TestCase
    func defaultHighlightAvoidsMatchingAnsiForeground(): Unit {
        let transcript = TerminalTranscript(cols: 8, rows: 1)
        transcript.append("\u{1B}[33;44myellow")
        let target = Buffer(Rect(0, 0, 8, 1))
        TerminalView(transcript, search: "yellow").render(target.area, target)
        @Expect(target.getCell(0, 0).style, Style(fg: Color.Yellow, bg: Color.Blue,
            modifier: underline()))
    }

    private func underline(): Modifier {
        var modifier = Modifier.none()
        modifier.underline = true
        modifier
    }
}
