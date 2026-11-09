package cjtui_api_example

import core.*
import terminal.*

main(): Int64 {
    let tokens = parseAnsi("A\u{1B}[31mB\u{1B}[1;1H\u{1B}[2J\u{1B}[?25l")
    if (tokens.size != 6) { throw IllegalStateException("incorrect ANSI token count") }
    let text = match (tokens[0].kind) { case AnsiTokenKind.Text => true; case _ => false }
    let sgr = match (tokens[1].kind) { case AnsiTokenKind.Sgr => true; case _ => false }
    let cursor = match (tokens[3].kind) { case AnsiTokenKind.Cursor => true; case _ => false }
    let erase = match (tokens[4].kind) { case AnsiTokenKind.Erase => true; case _ => false }
    let control = match (tokens[5].kind) { case AnsiTokenKind.Control => true; case _ => false }
    if (!text || !sgr || !cursor || !erase || !control) { throw IllegalStateException("incorrect ANSI token types") }
    let token = AnsiToken(AnsiTokenKind.Text, text: "OK")
    if (token.text != "OK") { throw IllegalStateException("incorrect token text") }

    let screen = TerminalScreen(cols: 8, rows: 2, textWidthOptions: TextWidthOptions())
    screen.feed("OK")
    if (screen.cols != 8 || screen.rows != 2 || screen.cell(0, 0).symbol != "O" || !screen.lineText(0).startsWith("OK")) {
        throw IllegalStateException("incorrect screen contents")
    }
    if (!screen.matchesTextWidthOptions(screen.textWidthOptions())) { throw IllegalStateException("incorrect width policy") }
    let buffer = Buffer(Rect(0, 0, 8, 2))
    screen.render(buffer.area, buffer)
    if (buffer.getCell(0, 0).symbol != "O") { throw IllegalStateException("incorrect screen rendering") }

    let transcript = TerminalTranscript(cols: 8, rows: 2, maxChunks: 2, followTail: true)
    transcript.append("Hi")
    transcript.followTail = false
    if (transcript.maxChunks != 2 || transcript.chunkCount() != 1 || transcript.followTail ||
        !transcript.screen.lineText(0).startsWith("Hi")) { throw IllegalStateException("incorrect transcript") }
    let view = TerminalView(transcript, search: "Hi")
    view.render(buffer.area, buffer)
    if (buffer.getCell(0, 0).symbol != "H") { throw IllegalStateException("incorrect terminal view") }
    return 0
}
