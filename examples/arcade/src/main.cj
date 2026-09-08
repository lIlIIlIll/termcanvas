package termcanvas_arcade

import core.*

const WORLD_W: Int64 = 46
const WORLD_H: Int64 = 15
const PLAYER_STEP_MS: Int64 = 85
const COIN_STEP_MS: Int64 = 220

class ArcadeApp {
    let input = InputState()
    let metrics = AppMetrics()
    var playerX: Int64 = WORLD_W / 2
    var coinX: Int64 = 8
    var coinY: Int64 = 5
    var score: Int64 = 0
    var tick: Int64 = 0
    var playerMoveMillis: Int64 = 0
    var coinFallMillis: Int64 = 0

    func update(event: Event): UpdateResult {
        for (generated in input.handle(event)) {
            _ = input.handle(generated)
        }
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                case _ => ()
            }
            case Event.Tick(t) =>
                tick = t.frameIndex
                _ = input.advance(t.deltaMillis)
                step(t.deltaMillis)
            case _ => ()
        }
        UpdateResult.next()
    }

    private func step(deltaMillis: Int64): Unit {
        let elapsed = max(0, deltaMillis)
        playerMoveMillis += elapsed
        coinFallMillis += elapsed
        while (playerMoveMillis >= PLAYER_STEP_MS) {
            movePlayer()
            playerMoveMillis -= PLAYER_STEP_MS
        }
        while (coinFallMillis >= COIN_STEP_MS) {
            fallCoin()
            coinFallMillis -= COIN_STEP_MS
        }
    }

    private func movePlayer(): Unit {
        if (input.isPressed(KeyEvent(KeyCode.Left)) || input.isPressed(KeyEvent(KeyCode.Char(r'a')))) {
            playerX = max(1, playerX - 1)
        }
        if (input.isPressed(KeyEvent(KeyCode.Right)) || input.isPressed(KeyEvent(KeyCode.Char(r'd')))) {
            playerX = min(WORLD_W - 2, playerX + 1)
        }
    }

    private func fallCoin(): Unit {
        coinY++
        if (coinY >= WORLD_H - 2) {
            if (coinX >= playerX - 2 && coinX <= playerX + 2) { score++ }
            coinY = 2
            coinX = 4 + ((coinX + 11 + score * 3) % (WORLD_W - 8))
        }
    }

    func render(frame: Frame): Unit {
        renderScene(frame.area, frame.canvas())
    }

    private func renderScene(area: Rect, canvas: Canvas): Unit {
        let guard = SizeGuard(WORLD_W + 2, WORLD_H + 3)
        let fit = guard.fit(area)
        canvas.fillRect(area, Style(bg: Color.Rgb(8, 12, 18)))
        let content = canvas.withClip(fit.content)
        content.drawText(fit.content.x, fit.content.y, "arcade  score=${score} tick=${tick}", Style(fg: Color.White, bg: Color.Rgb(8, 12, 18)))
        let world = Rect(fit.content.x, fit.content.y + 1, min(WORLD_W + 2, fit.content.width), min(WORLD_H, max(1, fit.content.height - 2)))
        content.strokeRect(world, Style(fg: Color.Cyan, bg: Color.Rgb(8, 12, 18)))
        renderCoin(content, world)
        content.drawText(world.x + playerX - 2, world.bottom - 2, "<===>", Style(fg: Color.Black, bg: Color.Green, modifier: Modifier.strong()))
        content.drawText(fit.content.x, fit.content.bottom - 1, "hold arrows/a/d  q quit", Style(fg: Color.White, bg: Color.Black))
        if (fit.tooSmall) {
            canvas.drawText(area.x, area.y, "terminal too small for arcade", Style(fg: Color.Yellow, bg: Color.Rgb(8, 12, 18)))
        }
    }

    private func renderCoin(canvas: Canvas, world: Rect): Unit {
        let x = world.x + coinX
        let y = world.y + coinY
        let nextY = min(world.bottom - 2, y + 1)
        let phase = (coinFallMillis * 4) / COIN_STEP_MS
        let coinStyle = Style(fg: Color.Yellow, bg: Color.Rgb(8, 12, 18), modifier: Modifier.strong())
        let trailStyle = Style(fg: Color.Rgb(180, 150, 42), bg: Color.Rgb(8, 12, 18))
        match (phase) {
            case 0 =>
                canvas.drawText(x, y, "$", coinStyle)
            case 1 =>
                canvas.drawText(x, y, "$", coinStyle)
                if (nextY > y) { canvas.drawText(x, nextY, ".", trailStyle) }
            case 2 =>
                canvas.drawText(x, y, ".", trailStyle)
                if (nextY > y) { canvas.drawText(x, nextY, "$", coinStyle) }
            case _ =>
                if (nextY > y) { canvas.drawText(x, nextY, "$", coinStyle) } else { canvas.drawText(x, y, "$", coinStyle) }
        }
    }
}

main(): Int64 {
    let app = ArcadeApp()
    App(targetFps: 30, metrics: Some(app.metrics)).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
