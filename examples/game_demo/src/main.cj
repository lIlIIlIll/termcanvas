package game_demo

import core.*
import game.*

const WORLD_W: Int64 = 58
const WORLD_H: Int64 = 18
const MOVE_SPEED: Float64 = 16.0
const BASIC_KEY_HOLD_MILLIS: Int64 = 130
const ENHANCED_KEY_HOLD_MILLIS: Int64 = 1000000
const JUMP_BUFFER_MILLIS: Int64 = 140
const COYOTE_MILLIS: Int64 = 90

class GameDemo {
    let world = EntityWorld()
    let transforms = ComponentStore<Transform2D>()
    let velocities = ComponentStore<Velocity2D>()
    let colliders = ComponentStore<Collider2D>()
    let bodies = ComponentStore<RigidBody2D>()
    let sprites = ComponentStore<Sprite2D>()
    let metrics = AppMetrics()
    let physics = PhysicsWorld(gravity: Vec2(x: 0.0, y: 42.0), maxSubSteps: 5, skin: 0.001)
    let tileMap = TileMap([
        "..........................................................",
        "..........................................................",
        "..........................................................",
        "..........................................................",
        "..............#####.......................................",
        ".............................................#####........",
        "..........................................................",
        "..........................####............................",
        "..........................................................",
        ".....#####................................................",
        "..................................#####...................",
        "..........................................................",
        "....................####..............................####",
        "..........................................................",
        "..........................................................",
        "###.............####..............####.................###",
        "##########################################################",
        "##########################################################"
    ])
    let player: EntityId
    var camera = Camera2D()
    var onGround = false
    var tick: Int64 = 0
    var lastHitCount: Int64 = 0
    var horizontalIntent: Int64 = 0
    var horizontalHoldMillis: Int64 = 0
    var jumpBufferMillis: Int64 = 0
    var coyoteMillis: Int64 = 0

    init() {
        player = world.create()
        transforms.insert(player, Transform2D(position: Vec2(x: 3.0, y: 10.0), size: Vec2(x: 1.0, y: 1.0)))
        velocities.insert(player, Velocity2D())
        colliders.insert(player, Collider2D(bounds: Aabb(width: 1.0, height: 1.0)))
        bodies.insert(player, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 1.0, damping: 0.0))
        sprites.insert(player, Sprite2D(["@"], style: Style(fg: Color.Yellow, bg: Color.Black, modifier: Modifier.strong())))
        _ = tileMap.addStaticColliders(world, transforms, colliders)
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                case _ => handleKeyDown(key)
            }
            case Event.KeyRepeat(key) => handleKeyDown(key)
            case Event.KeyHeld(key) => handleKeyDown(key)
            case Event.KeyUp(key) => handleKeyUp(key)
            case Event.FocusOut => clearControls()
            case Event.Tick(t) =>
                tick = t.frameIndex
                step(t.deltaMillis)
            case _ => ()
        }
        UpdateResult.next()
    }

    private func step(deltaMillis: Int64): Unit {
        let dt = max(1, deltaMillis)
        advanceControls(dt)
        if (onGround) { coyoteMillis = COYOTE_MILLIS }
        var velocity = match (velocities.get(player)) {
            case Some(v) => v
            case None => Velocity2D()
        }
        velocity.value.x = Float64(horizontalIntent) * MOVE_SPEED
        if (jumpBufferMillis > 0 && coyoteMillis > 0) {
            velocity.value.y = -24.0
            jumpBufferMillis = 0
            coyoteMillis = 0
            onGround = false
        }
        _ = velocities.set(player, velocity)
        let hits = physics.step(world, transforms, velocities, colliders, bodies, dt)
        lastHitCount = hits.size
        onGround = false
        for (hit in hits) {
            if (hit.entity == player && hit.normal.y < 0.0) {
                onGround = true
                coyoteMillis = COYOTE_MILLIS
            }
        }
        updateCamera()
        _ = world.advanceFrame()
    }

    private func handleKeyDown(key: KeyEvent): Unit {
        match (key.code) {
            case KeyCode.Left | KeyCode.Char(r'a') => holdHorizontal(-1, key)
            case KeyCode.Right | KeyCode.Char(r'd') => holdHorizontal(1, key)
            case KeyCode.Up | KeyCode.Char(r'w') | KeyCode.Char(r' ') => jumpBufferMillis = JUMP_BUFFER_MILLIS
            case _ => ()
        }
    }

    private func handleKeyUp(key: KeyEvent): Unit {
        match (key.code) {
            case KeyCode.Left | KeyCode.Char(r'a') =>
                if (horizontalIntent < 0) { horizontalIntent = 0 }
            case KeyCode.Right | KeyCode.Char(r'd') =>
                if (horizontalIntent > 0) { horizontalIntent = 0 }
            case _ => ()
        }
    }

    private func holdHorizontal(intent: Int64, key: KeyEvent): Unit {
        horizontalIntent = intent
        horizontalHoldMillis = match (key.protocol) {
            case KeyProtocol.Kitty => ENHANCED_KEY_HOLD_MILLIS
            case _ => BASIC_KEY_HOLD_MILLIS
        }
    }

    private func clearControls(): Unit {
        horizontalIntent = 0
        horizontalHoldMillis = 0
        jumpBufferMillis = 0
        coyoteMillis = 0
    }

    private func advanceControls(deltaMillis: Int64): Unit {
        if (horizontalHoldMillis > 0) {
            horizontalHoldMillis = max(0, horizontalHoldMillis - deltaMillis)
            if (horizontalHoldMillis == 0) { horizontalIntent = 0 }
        }
        if (jumpBufferMillis > 0) { jumpBufferMillis = max(0, jumpBufferMillis - deltaMillis) }
        if (coyoteMillis > 0) { coyoteMillis = max(0, coyoteMillis - deltaMillis) }
    }

    private func updateCamera(): Unit {
        let t = match (transforms.get(player)) {
            case Some(value) => value
            case None => return
        }
        camera.origin.x = fclamp(t.position.x - 22.0, 0.0, Float64(max(0, WORLD_W - 46)))
        camera.origin.y = 0.0
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(GameScene(this), frame.area)
    }
}

class GameScene <: Widget {
    let app: GameDemo

    init(app: GameDemo) {
        this.app = app
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        let guard = SizeGuard(62, 23)
        let fit = guard.fit(area)
        let canvas = Canvas(buffer, fit.content)
        canvas.fillRect(area, Style(bg: Color.Rgb(6, 8, 10)))
        if (fit.tooSmall) {
            canvas.drawText(area.x, area.y, "terminal too small for game_demo", Style(fg: Color.Yellow, bg: Color.Rgb(6, 8, 10)))
            return
        }
        canvas.drawText(fit.content.x, fit.content.y, "game_demo  tick=${app.tick} collisions=${app.lastHitCount}", Style(fg: Color.White, bg: Color.Rgb(6, 8, 10), modifier: Modifier.strong()))
        let worldArea = Rect(fit.content.x, fit.content.y + 2, 60, 18)
        canvas.fillRect(worldArea, Style(bg: Color.Rgb(12, 16, 20)))
        canvas.strokeRect(Rect(worldArea.x - 1, worldArea.y - 1, worldArea.width + 2, worldArea.height + 2), Style(fg: Color.Cyan, bg: Color.Rgb(6, 8, 10)))
        app.camera.viewport = worldArea
        drawTileMap(canvas, app.tileMap, app.camera, Style(fg: Color.Green, bg: Color.Rgb(12, 16, 20)))
        drawSprites(canvas, app.transforms, app.sprites, app.camera)
        canvas.drawText(fit.content.x, fit.content.y + 21, "move: hold arrows/a/d  jump: up/w/space  quit: q", Style(fg: Color.White, bg: Color.Black))
        canvas.drawText(fit.content.x, fit.content.y + 22, metricsLine(app.metrics), Style(fg: Color.Cyan, bg: Color.Black))
    }

    private func drawTileMap(canvas: Canvas, tileMap: TileMap, camera: Camera2D, style: Style): Unit {
        let originX = roundCell(camera.origin.x)
        let originY = roundCell(camera.origin.y)
        for (y in 0..camera.viewport.height) {
            let mapY = y + originY
            for (x in 0..camera.viewport.width) {
                let mapX = x + originX
                let symbol = tileMap.tileAt(mapX, mapY)
                if (!symbol.isEmpty() && symbol != ".") {
                    canvas.drawText(camera.viewport.x + x, camera.viewport.y + y, symbol, style)
                }
            }
        }
    }

    private func drawSprites(canvas: Canvas, transforms: ComponentStore<Transform2D>, sprites: ComponentStore<Sprite2D>, camera: Camera2D): Unit {
        for (id in sprites.entities()) {
            let sprite = match (sprites.get(id)) {
                case Some(value) => value
                case None => continue
            }
            let transform = match (transforms.get(id)) {
                case Some(value) => value
                case None => continue
            }
            let x = roundCell(transform.position.x - camera.origin.x) + camera.viewport.x
            let y = roundCell(transform.position.y - camera.origin.y) + camera.viewport.y
            drawSprite(canvas, x, y, sprite)
        }
    }

    private func drawSprite(canvas: Canvas, x: Int64, y: Int64, sprite: Sprite2D): Unit {
        for (row in 0..sprite.rows.size) {
            var cx = x
            for (r in sprite.rows[row].runes()) {
                let text = r.toString()
                if (text != sprite.transparent) {
                    canvas.drawText(cx, y + row, text, sprite.style)
                }
                cx += max(1, displayWidth(r))
            }
        }
    }
}

func fmin(a: Float64, b: Float64): Float64 { if (a < b) { a } else { b } }
func fmax(a: Float64, b: Float64): Float64 { if (a > b) { a } else { b } }
func fclamp(value: Float64, minValue: Float64, maxValue: Float64): Float64 {
    fmin(fmax(value, minValue), maxValue)
}
func roundCell(value: Float64): Int64 {
    if (value >= 0.0) { Int64(value + 0.5) } else { Int64(value - 0.5) }
}

func metricsLine(metrics: AppMetrics): String {
    match (metrics.lastFrame()) {
        case Some(frame) => "fps=${frame.fps} render=${frame.renderMillis}ms dirty=${frame.dirtyCells} writes=${frame.diffWrites} dropped=${frame.droppedTicks}"
        case None => "fps=0 render=0ms dirty=0 writes=0 dropped=0"
    }
}

main(): Int64 {
    let demo = GameDemo()
    App(renderMode: RenderMode.Diff, targetFps: 60, metrics: Some(demo.metrics)).runWithCommands(
        { frame => demo.render(frame) },
        { event => demo.update(event) }
    )
    0
}
