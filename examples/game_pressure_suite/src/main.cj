package game_pressure_suite

import core.*

const APP_W: Int64 = 92
const APP_H: Int64 = 31

class GamePressureSuite {
    let metrics = AppMetrics()
    var tick: Int64 = 0
    var focus: Int64 = 0
    var rogueX: Int64 = 3
    var rogueY: Int64 = 3
    var rogueLoot: Int64 = 0
    var snakeX: Int64 = 5
    var snakeY: Int64 = 3
    var snakeDir: Int64 = 1
    var snakeScore: Int64 = 0
    var snakeStepMillis: Int64 = 0
    var slideCount: Int64 = 0
    var mineX: Int64 = 2
    var mineY: Int64 = 1
    var revealed: Int64 = 0
    var strategyX: Int64 = 2
    var strategyY: Int64 = 2
    var turn: Int64 = 1
    var selectedUnit: Int64 = 0
    var shipX: Int64 = 8
    var astX: Int64 = 13
    var astY: Int64 = 1
    var actionScore: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                    case KeyCode.Tab => focus = (focus + 1) % 6
                    case KeyCode.Char(r'1') => focus = 0
                    case KeyCode.Char(r'2') => focus = 1
                    case KeyCode.Char(r'3') => focus = 2
                    case KeyCode.Char(r'4') => focus = 3
                    case KeyCode.Char(r'5') => focus = 4
                    case KeyCode.Char(r'6') => focus = 5
                    case KeyCode.Char(r' ') => activate()
                    case KeyCode.Enter => activate()
                    case KeyCode.Left => move(-1, 0)
                    case KeyCode.Right => move(1, 0)
                    case KeyCode.Up => move(0, -1)
                    case KeyCode.Down => move(0, 1)
                    case KeyCode.Char(r'a') => move(-1, 0)
                    case KeyCode.Char(r'd') => move(1, 0)
                    case KeyCode.Char(r'w') => move(0, -1)
                    case KeyCode.Char(r's') => move(0, 1)
                    case _ => ()
                }
            case Event.Tick(t) =>
                tick = t.frameIndex
                step(t.deltaMillis)
            case _ => ()
        }
        UpdateResult.next()
    }

    private func activate(): Unit {
        match (focus) {
            case 0 => rogueLoot++
            case 1 => snakeScore++
            case 2 => slideCount++
            case 3 => revealed = min(20, revealed + 1)
            case 4 =>
                selectedUnit = (selectedUnit + 1) % 3
                turn++
            case 5 => actionScore++
            case _ => ()
        }
    }

    private func move(dx: Int64, dy: Int64): Unit {
        match (focus) {
            case 0 =>
                rogueX = clamp(rogueX + dx, 1, 12)
                rogueY = clamp(rogueY + dy, 1, 6)
            case 1 =>
                if (dx < 0) { snakeDir = 3 }
                if (dx > 0) { snakeDir = 1 }
                if (dy < 0) { snakeDir = 0 }
                if (dy > 0) { snakeDir = 2 }
            case 2 => slideCount++
            case 3 =>
                mineX = clamp(mineX + dx, 0, 4)
                mineY = clamp(mineY + dy, 0, 3)
            case 4 =>
                strategyX = clamp(strategyX + dx, 0, 5)
                strategyY = clamp(strategyY + dy, 0, 3)
            case 5 => shipX = clamp(shipX + dx, 1, 16)
            case _ => ()
        }
    }

    private func step(deltaMillis: Int64): Unit {
        let elapsed = max(1, deltaMillis)
        snakeStepMillis += elapsed
        while (snakeStepMillis >= 160) {
            advanceSnake()
            snakeStepMillis -= 160
        }
        astY++
        if (astY > 5) {
            astY = 1
            astX = 2 + ((astX + 7 + actionScore) % 15)
            actionScore++
        }
    }

    private func advanceSnake(): Unit {
        match (snakeDir) {
            case 0 => snakeY--
            case 1 => snakeX++
            case 2 => snakeY++
            case 3 => snakeX--
            case _ => ()
        }
        if (snakeX < 1) { snakeX = 14 }
        if (snakeX > 14) { snakeX = 1 }
        if (snakeY < 1) { snakeY = 6 }
        if (snakeY > 6) { snakeY = 1 }
        if (snakeX == 10 && snakeY == 4) { snakeScore++ }
    }

    func render(frame: Frame): Unit {
        let canvas = frame.canvas()
        canvas.fillRect(frame.area, Style(bg: Color.Rgb(6, 9, 13)))
        let guard = SizeGuard(APP_W, APP_H)
        let fit = guard.fit(frame.area)
        if (fit.tooSmall) {
            canvas.drawText(frame.area.x, frame.area.y, "terminal too small for game_pressure_suite", Style(fg: Color.Yellow, bg: Color.Rgb(6, 9, 13)))
            return
        }
        let x = fit.content.x
        let y = fit.content.y
        canvas.drawText(x, y, "game_pressure_suite  focus=${focus + 1}  tick=${tick}  tab/1-6 focus  arrows move  space action  q quit", Style(fg: Color.White, bg: Color.Rgb(6, 9, 13), modifier: Modifier.strong()))
        renderRoguelike(canvas, Rect(x, y + 2, 29, 9))
        renderSnake(canvas, Rect(x + 31, y + 2, 29, 9))
        render2048(canvas, Rect(x + 62, y + 2, 29, 9))
        renderMinesweeper(canvas, Rect(x, y + 13, 29, 9))
        renderStrategy(canvas, Rect(x + 31, y + 13, 29, 9))
        renderAction(canvas, Rect(x + 62, y + 13, 29, 9))
        canvas.drawText(x, y + 24, "covers: roguelike, snake, 2048, minesweeper, turn-based strategy, lightweight real-time action", Style(fg: Color.Cyan, bg: Color.Rgb(6, 9, 13)))
        canvas.drawText(x, y + 26, metricsLine(metrics), Style(fg: Color.Rgb(170, 210, 255), bg: Color.Rgb(6, 9, 13)))
    }

    private func renderRoguelike(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 0, "1 roguelike")
        drawGrid(canvas, area.x + 1, area.y + 2, 14, 6)
        drawAt(canvas, area.x + 1 + rogueX, area.y + 2 + rogueY, "@", Color.Yellow)
        drawAt(canvas, area.x + 10, area.y + 4, "$", Color.Green)
        drawAt(canvas, area.x + 5, area.y + 6, "#", Color.Rgb(120, 120, 130))
        canvas.drawText(area.x + 1, area.y + 8, "loot=${rogueLoot}", panelText())
    }

    private func renderSnake(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 1, "2 snake")
        drawGrid(canvas, area.x + 1, area.y + 2, 16, 6)
        drawAt(canvas, area.x + 1 + snakeX, area.y + 2 + snakeY, "O", Color.Green)
        drawAt(canvas, area.x + 1 + wrap(snakeX - 1, 1, 14), area.y + 2 + snakeY, "o", Color.Rgb(120, 220, 120))
        drawAt(canvas, area.x + 11, area.y + 6, "*", Color.Red)
        canvas.drawText(area.x + 1, area.y + 8, "score=${snakeScore} dir=${snakeDir}", panelText())
    }

    private func render2048(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 2, "3 2048")
        for (row in 0..4) {
            for (col in 0..4) {
                let value = tileValue(row, col, slideCount)
                let label = if (value == 0) { "." } else { "${value}" }
                canvas.drawText(area.x + 2 + col * 5, area.y + 2 + row, label, Style(fg: Color.White, bg: Color.Rgb(26, 34, 44)))
            }
        }
        canvas.drawText(area.x + 1, area.y + 8, "slides=${slideCount}", panelText())
    }

    private func renderMinesweeper(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 3, "4 minesweeper")
        for (row in 0..4) {
            for (col in 0..5) {
                let marker = if (col == mineX && row == mineY) { "[]" } else if ((row * 5 + col) < revealed) { "1 " } else { ". " }
                canvas.drawText(area.x + 2 + col * 3, area.y + 2 + row, marker, panelText())
            }
        }
        canvas.drawText(area.x + 1, area.y + 8, "revealed=${revealed}", panelText())
    }

    private func renderStrategy(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 4, "5 turn-based strategy")
        drawGrid(canvas, area.x + 1, area.y + 2, 18, 5)
        drawAt(canvas, area.x + 2, area.y + 3, "A", Color.Cyan)
        drawAt(canvas, area.x + 8, area.y + 5, "B", Color.Magenta)
        drawAt(canvas, area.x + 15, area.y + 4, "C", Color.Yellow)
        drawAt(canvas, area.x + 1 + strategyX * 3, area.y + 2 + strategyY, "+", Color.White)
        canvas.drawText(area.x + 1, area.y + 8, "turn=${turn} unit=${selectedUnit + 1}", panelText())
    }

    private func renderAction(canvas: Canvas, area: Rect): Unit {
        panel(canvas, area, 5, "6 lightweight real-time action")
        drawGrid(canvas, area.x + 1, area.y + 2, 18, 6)
        drawAt(canvas, area.x + 1 + shipX, area.y + 7, "^", Color.Cyan)
        drawAt(canvas, area.x + 1 + astX, area.y + 2 + astY, "!", Color.Red)
        canvas.drawText(area.x + 1, area.y + 8, "dodges=${actionScore}", panelText())
    }

    private func panel(canvas: Canvas, area: Rect, index: Int64, title: String): Unit {
        let active = focus == index
        let border = if (active) { Style(fg: Color.Yellow, bg: Color.Rgb(6, 9, 13), modifier: Modifier.strong()) } else { Style(fg: Color.Rgb(80, 120, 150), bg: Color.Rgb(6, 9, 13)) }
        canvas.strokeRect(area, border)
        canvas.drawText(area.x + 1, area.y, title, border)
    }
}

func drawGrid(canvas: Canvas, x: Int64, y: Int64, w: Int64, h: Int64): Unit {
    for (row in 0..h) {
        for (col in 0..w) {
            canvas.drawText(x + col, y + row, ".", Style(fg: Color.Rgb(50, 64, 80), bg: Color.Rgb(12, 16, 22)))
        }
    }
}

func drawAt(canvas: Canvas, x: Int64, y: Int64, text: String, fg: Color): Unit {
    canvas.drawText(x, y, text, Style(fg: fg, bg: Color.Rgb(12, 16, 22), modifier: Modifier.strong()))
}

func panelText(): Style {
    Style(fg: Color.White, bg: Color.Rgb(6, 9, 13))
}

func tileValue(row: Int64, col: Int64, slideCount: Int64): Int64 {
    let seed = row * 4 + col
    match ((seed + slideCount) % 7) {
        case 0 => 2
        case 1 => 4
        case 2 => 8
        case 3 => 16
        case _ => 0
    }
}

func clamp(value: Int64, lo: Int64, hi: Int64): Int64 {
    min(hi, max(lo, value))
}

func wrap(value: Int64, lo: Int64, hi: Int64): Int64 {
    if (value < lo) { return hi }
    if (value > hi) { return lo }
    value
}

func metricsLine(metrics: AppMetrics): String {
    match (metrics.lastFrame()) {
        case Some(frame) => "fps=${frame.fps} render=${frame.renderMillis}ms dirty=${frame.dirtyCells} writes=${frame.diffWrites}"
        case None => "fps=0 render=0ms dirty=0 writes=0"
    }
}

main(): Int64 {
    let app = GamePressureSuite()
    App(renderMode: RenderMode.Diff, targetFps: 30, metrics: Some(app.metrics)).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
