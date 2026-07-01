package cjtui_oh_my_pi_skin

import core.*

let BG = Color.Rgb(13, 13, 13)
let PANEL = Color.Rgb(22, 24, 30)
let PANEL_2 = Color.Rgb(30, 33, 41)
let STATUS_BG = Color.Rgb(18, 18, 18)
let ORANGE = Color.Rgb(249, 115, 22)
let ACCENT = Color.Rgb(254, 188, 56)
let BLUE = Color.Rgb(23, 143, 185)
let CYAN = Color.Rgb(0, 136, 250)
let GREEN = Color.Rgb(137, 210, 129)
let RED = Color.Rgb(252, 58, 75)
let MUTED = Color.Rgb(119, 125, 136)
let DIM = Color.Rgb(68, 72, 82)
let PINK = Color.Rgb(255, 92, 200)
let VIOLET = Color.Rgb(180, 110, 255)

class OhMyPiSkin {
    var caps = TerminalCapabilities()
    var tick: Int64 = 0
    var paletteOpen = false
    var showBusy = true
    var mode = "agent"
    let composer = Composer(
        value: "/review runtime#1441 --multi-round",
        slashHints: ["/review", "/model", "/theme", "/resume", "/clear"]
    )
    let palette = CommandPalette([
        MenuItem("Switch model", action: "model"),
        MenuItem("Toggle busy state", action: "busy"),
        MenuItem("Open recent session", action: "session"),
        MenuItem("Run review command", action: "review"),
        MenuItem("Quit", action: "quit")
    ])

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.Capabilities(c) =>
                caps = c
                UpdateResult.next()
            case Event.Tick(t) =>
                tick = t.frameIndex
                UpdateResult.next()
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r'/') =>
                    paletteOpen = !paletteOpen
                    UpdateResult.next()
                case KeyCode.Char(r'b') =>
                    showBusy = !showBusy
                    UpdateResult.next()
                case KeyCode.Char(r't') =>
                    mode = if (mode == "agent") { "theme" } else { "agent" }
                    UpdateResult.next()
                case KeyCode.Esc =>
                    paletteOpen = false
                    UpdateResult.next()
                case _ =>
                    if (!paletteOpen) { _ = composer.handle(key) }
                    UpdateResult.next()
            }
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let canvas = frame.canvas()
        canvas.fillRect(frame.area, Style(bg: BG))
        drawBackground(canvas, frame.area, tick)

        if (frame.area.width < 76 || frame.area.height < 21) {
            drawCompact(canvas, frame.area)
            return
        }

        let rows = Layout.vertical([
            Constraint.Length(8),
            Constraint.Min(9),
            Constraint.Length(4),
            Constraint.Length(1)
        ]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)

        drawHero(canvas, rows[0], tick)
        let cols = Layout.horizontal([Constraint.Percent(46), Constraint.Min(40)]).withGap(1).split(rows[1])
        drawWelcome(canvas, cols[0], tick)
        drawTranscript(canvas, cols[1])
        frame.renderWidget(composer, rows[2])
        drawStatus(canvas, rows[3])

        if (paletteOpen) {
            let width = min(42, max(24, frame.area.width - 8))
            let height = min(10, max(6, frame.area.height - 6))
            let popup = Rect(frame.area.x + (frame.area.width - width) / 2, frame.area.y + 3, width, height)
            canvas.fillRect(popup, Style(bg: Color.Rgb(19, 22, 28)))
            frame.renderWidget(palette, popup)
        }

        frame.setCursor(composer.area.cursorPosition(rows[2]))
    }

    private func drawBackground(canvas: Canvas, area: Rect, frame: Int64): Unit {
        let gridStyle = Style(fg: Color.Rgb(28, 32, 38), bg: BG)
        var x = area.x
        while (x < area.right) {
            var y = area.y
            while (y < area.bottom) {
                canvas.drawText(x, y, ".", gridStyle)
                y += 4
            }
            x += 8
        }
        let glowStyle = Style(fg: if (frame % 20 < 10) { ORANGE } else { ACCENT }, bg: BG)
        canvas.drawLine(area.x + 2, area.y + 2, area.x + 10, area.y + 6, "*", glowStyle)
        canvas.drawLine(area.right - 12, area.y + 2, area.right - 4, area.y + 6, "*", glowStyle)
        canvas.drawLine(area.x + 2, area.bottom - 4, area.x + 14, area.bottom - 2, ".", Style(fg: Color.Rgb(80, 45, 24), bg: BG))
        canvas.drawLine(area.right - 15, area.bottom - 2, area.right - 3, area.bottom - 4, ".", Style(fg: Color.Rgb(80, 45, 24), bg: BG))
    }

    private func drawHero(canvas: Canvas, area: Rect, frame: Int64): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(10, 12, 16)))
        drawCornerMarks(canvas, area)
        let center = Rect(area.x + area.width / 2 - 28, area.y + 1, 56, max(1, area.height - 2))
        drawPiLogo(canvas, Rect(center.x, center.y, 14, 5), frame)
        canvas.drawText(center.x + 17, center.y + 1, "oh my PI", Style(fg: Color.White, bg: Color.Rgb(10, 12, 16), modifier: Modifier.strong()))
        canvas.drawText(center.x + 17, center.y + 3, "[ ai coding agent ]", Style(fg: MUTED, bg: Color.Rgb(10, 12, 16)))
        let dot = if (showBusy) { if (frame % 12 < 6) { "*" } else { "o" } } else { "o" }
        canvas.drawText(center.x + 17, center.y + 5, dot + " MCP  LSP  Subagents  Web Search", Style(fg: if (showBusy) { GREEN } else { MUTED }, bg: Color.Rgb(10, 12, 16)))
    }

    private func drawWelcome(canvas: Canvas, area: Rect, frame: Int64): Unit {
        drawPanel(canvas, area, " oh-my-pi v16.2.6 ")
        let inner = Rect(area.x + 2, area.y + 1, max(1, area.width - 4), max(1, area.height - 2))
        let split = Layout.horizontal([Constraint.Percent(38), Constraint.Min(18)]).withGap(1).split(inner)
        let left = split[0]
        let right = split[1]
        drawCentered(canvas, left.x, left.y, left.width, "Welcome back!", Style(fg: Color.White, bg: PANEL, modifier: Modifier.strong()))
        drawPiLogo(canvas, Rect(left.x + max(0, (left.width - 14) / 2), left.y + 2, 14, 5), frame)
        drawCentered(canvas, left.x, left.y + 8, left.width, "claude-sonnet-4.5", Style(fg: MUTED, bg: PANEL))
        drawCentered(canvas, left.x, left.y + 9, left.width, "openai-compatible", Style(fg: DIM, bg: PANEL))

        canvas.drawText(right.x, right.y, "Tips", Style(fg: ACCENT, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(right.x, right.y + 1, "# prompt actions", Style(fg: MUTED, bg: PANEL))
        canvas.drawText(right.x, right.y + 2, "/ commands", Style(fg: MUTED, bg: PANEL))
        canvas.drawText(right.x, right.y + 3, "! bash   $ python", Style(fg: MUTED, bg: PANEL))
        canvas.drawText(right.x, right.y + 5, "LSP Servers", Style(fg: ACCENT, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(right.x, right.y + 6, "o cangjie ready", Style(fg: GREEN, bg: PANEL))
        canvas.drawText(right.x, right.y + 7, "o rust ready", Style(fg: BLUE, bg: PANEL))
        canvas.drawText(right.x, right.y + 9, "Recent sessions", Style(fg: ACCENT, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(right.x, right.y + 10, "- cjtui examples (now)", Style(fg: MUTED, bg: PANEL))
    }

    private func drawTranscript(canvas: Canvas, area: Rect): Unit {
        drawPanel(canvas, area, " Transcript ")
        var y = area.y + 1
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 3), "User", "写一个外观复刻版 oh-my-pi", Color.Rgb(34, 29, 26))
        y += 4
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 4), "Assistant", "I will build a terminal-native skin with welcome card, transcript, composer, and status segments.", Color.Rgb(42, 37, 48))
        y += 5
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 4), "Tool", "cjtui: Canvas + Style + Composer + CommandPalette + Tick animation", Color.Rgb(22, 26, 32))
        canvas.drawText(area.x + 4, min(area.bottom - 2, y + 3), "approval gate: ready", Style(fg: RED, bg: Color.Rgb(22, 26, 32)))
    }

    private func drawMessage(canvas: Canvas, area: Rect, title: String, body: String, bg: Color): Unit {
        canvas.fillRect(area, Style(bg: bg))
        drawBox(canvas, area, Style(fg: DIM, bg: bg))
        canvas.drawText(area.x + 2, area.y, " " + title + " ", Style(fg: Color.Rgb(178, 129, 214), bg: bg, modifier: Modifier.strong()))
        canvas.drawText(area.x + 2, area.y + 1, truncateText(body, max(1, area.width - 4)), Style(fg: Color.White, bg: bg))
        if (area.height > 3) {
            canvas.drawText(area.x + 2, area.y + 2, truncateText("status: rendered  public API only", max(1, area.width - 4)), Style(fg: MUTED, bg: bg))
        }
    }

    private func drawStatus(canvas: Canvas, area: Rect): Unit {
        canvas.fillRect(area, Style(bg: STATUS_BG))
        var x = area.x
        x = segment(canvas, x, area.y, " PI ", ORANGE, Color.Black)
        x = segment(canvas, x, area.y, " " + mode + " ", Color.Rgb(215, 135, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " examples/oh_my_pi_skin ", Color.Rgb(0, 175, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " git dirty ", Color.Rgb(215, 175, 95), STATUS_BG)
        x = segment(canvas, x, area.y, " ctx 38% ", Color.Rgb(135, 135, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " subagents 3 ", ACCENT, STATUS_BG)
        if (x < area.right) {
            canvas.drawText(x, area.y, spaces(area.right - x), Style(bg: STATUS_BG))
        }
    }

    private func segment(canvas: Canvas, x: Int64, y: Int64, text: String, fg: Color, bg: Color): Int64 {
        canvas.drawText(x, y, text, Style(fg: fg, bg: bg, modifier: Modifier.strong()))
        x + text.size
    }

    private func drawPanel(canvas: Canvas, area: Rect, title: String): Unit {
        canvas.fillRect(area, Style(bg: PANEL))
        drawBox(canvas, area, Style(fg: BLUE, bg: PANEL))
        canvas.drawText(area.x + 3, area.y, title, Style(fg: MUTED, bg: PANEL, modifier: Modifier.strong()))
    }

    private func drawPiLogo(canvas: Canvas, area: Rect, frame: Int64): Unit {
        let logo = ["▀██████████▀", " ╘██    ██  ", "  ██    ██  ", "  ██    ██  ", " ▄██▄  ▄██▄ "]
        for (i in 0..logo.size) {
            let color = gradientColor(i + frame / 2)
            canvas.drawText(area.x, area.y + i, logo[i], Style(fg: color, bg: PANEL_2, modifier: Modifier.strong()))
        }
        canvas.drawText(area.x + 8, area.y + 3, "[]", Style(fg: ORANGE, bg: PANEL_2, modifier: Modifier.strong()))
    }

    private func gradientColor(i: Int64): Color {
        match (i % 5) {
            case 0 => PINK
            case 1 => VIOLET
            case 2 => CYAN
            case 3 => Color.Rgb(120, 255, 220)
            case _ => ORANGE
        }
    }

    private func drawCornerMarks(canvas: Canvas, area: Rect): Unit {
        let style = Style(fg: Color.Rgb(80, 80, 86), bg: Color.Rgb(10, 12, 16))
        drawOpenCorner(canvas, area.x + 1, area.y + 1, "tl", style)
        drawOpenCorner(canvas, area.right - 4, area.y + 1, "tr", style)
        drawOpenCorner(canvas, area.x + 1, area.bottom - 3, "bl", style)
        drawOpenCorner(canvas, area.right - 4, area.bottom - 3, "br", style)
    }

    private func drawCompact(canvas: Canvas, area: Rect): Unit {
        let fit = SizeGuard(76, 21).fit(area)
        let box = fit.content
        canvas.fillRect(box, Style(bg: PANEL))
        drawBox(canvas, box, Style(fg: ORANGE, bg: PANEL))
        canvas.drawText(box.x + 2, box.y + 1, "oh my PI", Style(fg: ORANGE, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(box.x + 2, box.y + 3, "terminal too small for full skin", Style(fg: Color.White, bg: PANEL))
        canvas.drawText(box.x + 2, box.y + 4, "need at least 76x21 cells", Style(fg: MUTED, bg: PANEL))
    }

    private func drawCentered(canvas: Canvas, x: Int64, y: Int64, width: Int64, text: String, style: Style): Unit {
        let clipped = truncateText(text, width)
        let pad = max(0, (width - clipped.size) / 2)
        canvas.drawText(x + pad, y, clipped, style)
    }

    private func truncateText(text: String, width: Int64): String {
        if (width <= 0) { return "" }
        if (text.size <= width) { return text }
        if (width <= 3) { return text[0..width] }
        text[0..max(0, width - 3)] + "..."
    }

    private func drawBox(canvas: Canvas, area: Rect, style: Style): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let h = if (caps.unicode) { "─" } else { "-" }
        let v = if (caps.unicode) { "│" } else { "|" }
        let tl = if (caps.unicode) { "╭" } else { "+" }
        let tr = if (caps.unicode) { "╮" } else { "+" }
        let bl = if (caps.unicode) { "╰" } else { "+" }
        let br = if (caps.unicode) { "╯" } else { "+" }

        if (area.width == 1) {
            for (y in area.y..area.bottom) {
                canvas.drawText(area.x, y, v, style)
            }
            return
        }
        if (area.height == 1) {
            canvas.drawText(area.x, area.y, tl + repeatGlyph(h, area.width - 2) + tr, style)
            return
        }

        canvas.drawText(area.x, area.y, tl + repeatGlyph(h, area.width - 2) + tr, style)
        for (y in area.y + 1..area.bottom - 1) {
            canvas.drawText(area.x, y, v, style)
            canvas.drawText(area.right - 1, y, v, style)
        }
        canvas.drawText(area.x, area.bottom - 1, bl + repeatGlyph(h, area.width - 2) + br, style)
    }

    private func drawOpenCorner(canvas: Canvas, x: Int64, y: Int64, kind: String, style: Style): Unit {
        let h = if (caps.unicode) { "─" } else { "-" }
        let v = if (caps.unicode) { "│" } else { "|" }
        let tl = if (caps.unicode) { "╭" } else { "+" }
        let tr = if (caps.unicode) { "╮" } else { "+" }
        let bl = if (caps.unicode) { "╰" } else { "+" }
        let br = if (caps.unicode) { "╯" } else { "+" }
        match (kind) {
            case "tl" =>
                canvas.drawText(x, y, tl + h + h, style)
                canvas.drawText(x, y + 1, v, style)
            case "tr" =>
                canvas.drawText(x, y, h + h + tr, style)
                canvas.drawText(x + 2, y + 1, v, style)
            case "bl" =>
                canvas.drawText(x, y, v, style)
                canvas.drawText(x, y + 1, bl + h + h, style)
            case _ =>
                canvas.drawText(x + 2, y, v, style)
                canvas.drawText(x, y + 1, h + h + br, style)
        }
    }

    private func repeatGlyph(glyph: String, count: Int64): String {
        var out = ""
        for (_ in 0..max(0, count)) {
            out += glyph
        }
        out
    }

    private func spaces(width: Int64): String {
        var out = ""
        for (_ in 0..max(0, width)) {
            out += " "
        }
        out
    }
}

main(): Int64 {
    let app = OhMyPiSkin()
    App(targetFps: 12, bracketedPaste: true, hideCursor: false).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
