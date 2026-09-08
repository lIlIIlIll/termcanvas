package termcanvas_crystal_caves

import core.*
import game.*
import std.collection.*

const VIEW_W: Int64 = 74
const VIEW_H: Int64 = 23
const WORLD_VIEW_H: Int64 = 17
const KIND_PLAYER: Int64 = 1
const KIND_GEM: Int64 = 2
const KIND_KEY: Int64 = 3
const KIND_EXIT: Int64 = 4
const KIND_HAZARD: Int64 = 5
const KIND_ENEMY: Int64 = 6
const LAYER_PLAYER: Int64 = 1
const LAYER_SENSOR: Int64 = 2
const PLAYER_SPEED: Float64 = 18.0
const JUMP_SPEED: Float64 = -26.0

struct LevelDef {
    let name: String
    let rows: Array<String>
    let sky: Color
    let rock: Color
    let accent: Color

    init(name: String, rows: Array<String>, sky: Color, rock: Color, accent: Color) {
        this.name = name
        this.rows = rows
        this.sky = sky
        this.rock = rock
        this.accent = accent
    }
}

struct Patrol {
    var minX: Float64
    var maxX: Float64
    var speed: Float64
    var dir: Float64

    init(minX: Float64, maxX: Float64, speed!: Float64 = 5.5, dir!: Float64 = 1.0) {
        this.minX = minX
        this.maxX = maxX
        this.speed = speed
        this.dir = dir
    }
}

let LEVELS = [
    LevelDef(
        "Moonlit Gate",
        [
            "................................................................................................",
            "................................................................................................",
            ".........................................................................................G......",
            "....................................................................................#####.......",
            "..............G.........................G.......................................................X",
            "............#####.................############.......................G.......................#####",
            ".....P............................................................#####..........................",
            "########............M.....................^^^^.............M................K....................",
            "########.........########.............############......########...........#####.................",
            "########..........................G.............................................................",
            "########......................########..............................M............................",
            "########.........................................................########.......................",
            "########...........G............................G...............................................",
            "########........########....................########.............................................",
            "########..............................M.............................^^^^.........................",
            "##########################....#############################....#################################",
            "##########################....#############################....#################################"
        ],
        Color.Rgb(8, 18, 34),
        Color.Rgb(69, 82, 113),
        Color.Rgb(102, 224, 255)
    ),
    LevelDef(
        "Ember Shafts",
        [
            "................................................................................................",
            "................................................................................................",
            "..................G.................................................................G...........",
            "...............########......................G.................................########.........X",
            ".....P...................................########............................................####",
            "########.................M....................................K....................M............",
            "########..............########..............^^^^.............#####..............########.........",
            "########..................................########..............................................",
            "########.......G..........................................................G....................",
            "########....########.............M.................................############..................",
            "########.....................########..............G............................................",
            "########.......................................########.................^^^^.....................",
            "########.............G...............M................................########..................",
            "########..........########.......########...................M...................................",
            "########.................................................########...............................",
            "###########################...##################...##################...########################",
            "###########################...##################...##################...########################"
        ],
        Color.Rgb(31, 12, 24),
        Color.Rgb(111, 70, 58),
        Color.Rgb(255, 174, 64)
    ),
    LevelDef(
        "Star Vault",
        [
            "................................................................................................",
            "........................................................................................G.......",
            "......................G..........................................................############..",
            "...................########.........................G..........................................X",
            ".....P...........................................########.................................######.",
            "########.................M........................................K.............................",
            "########..............########.............G....................#####............M..............",
            "########...............................########..............................########...........",
            "########........G...........................................G...................................",
            "########.....########.......M...........................########...............................",
            "########................########......................................^^^^......................",
            "########................................M..........................########....................",
            "########..........G.................########...................................................",
            "########.......########...................................M.....................G..............",
            "########.................................^^^^..........########..............########...........",
            "########################....####################....#################....#######################",
            "########################....####################....#################....#######################"
        ],
        Color.Rgb(7, 16, 40),
        Color.Rgb(65, 70, 125),
        Color.Rgb(190, 143, 255)
    )
]

class CrystalCaves {
    var world = EntityWorld()
    var transforms = ComponentStore<Transform2D>()
    var velocities = ComponentStore<Velocity2D>()
    var colliders = ComponentStore<Collider2D>()
    var bodies = ComponentStore<RigidBody2D>()
    var sprites = ComponentStore<Sprite2D>()
    var kinds = ComponentStore<Int64>()
    var patrols = ComponentStore<Patrol>()
    let input = GameInputState()
    let metrics = AppMetrics()
    let physics = PhysicsWorld(gravity: Vec2(x: 0.0, y: 52.0), maxSubSteps: 6, skin: 0.001)
    let renderer = SpriteRenderer()
    var camera = Camera2D()
    var tileMap = TileMap(LEVELS[0].rows)
    var player = EntityId(0)
    var playerAnim = SpriteAnimation([
        SpriteFrame(Sprite2D(["o ", "/>"], style: Style(fg: Color.Rgb(214, 242, 255), bg: Color.Black, modifier: Modifier.strong())), durationMillis: 130),
        SpriteFrame(Sprite2D(["o ", "<\\"], style: Style(fg: Color.Rgb(214, 242, 255), bg: Color.Black, modifier: Modifier.strong())), durationMillis: 130)
    ])
    var gemAnim = SpriteAnimation([
        SpriteFrame(Sprite2D(["*"], style: Style(fg: Color.Rgb(102, 224, 255), bg: Color.Black, modifier: Modifier.strong())), durationMillis: 180),
        SpriteFrame(Sprite2D(["+"], style: Style(fg: Color.Rgb(255, 255, 160), bg: Color.Black, modifier: Modifier.strong())), durationMillis: 180)
    ])
    var levelIndex: Int64 = 0
    var score: Int64 = 0
    var totalGems: Int64 = 0
    var lives: Int64 = 3
    var keys: Int64 = 0
    var onGround = false
    var coyoteMillis: Int64 = 0
    var jumpBufferMillis: Int64 = 0
    var invulnerableMillis: Int64 = 0
    var message = "find the key, grab crystals, reach the gate"
    var won = false
    var tick: Int64 = 0

    init() {
        loadLevel(0)
    }

    func update(event: Event): UpdateResult {
        input.handle(event)
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                case KeyCode.Char(r'r') => restartLevel()
                case _ => ()
            }
            case Event.Tick(t) =>
                tick = t.frameIndex
                step(t.deltaMillis)
            case _ => ()
        }
        UpdateResult.next()
    }

    private func loadLevel(index: Int64): Unit {
        levelIndex = clampInt(index, 0, LEVELS.size - 1)
        world = EntityWorld()
        transforms = ComponentStore<Transform2D>()
        velocities = ComponentStore<Velocity2D>()
        colliders = ComponentStore<Collider2D>()
        bodies = ComponentStore<RigidBody2D>()
        sprites = ComponentStore<Sprite2D>()
        kinds = ComponentStore<Int64>()
        patrols = ComponentStore<Patrol>()
        tileMap = TileMap(LEVELS[levelIndex].rows)
        _ = tileMap.addStaticColliders(world, transforms, colliders)
        totalGems = tileMap.find("G").size
        score = 0
        keys = 0
        lives = 3
        won = false
        message = "level ${levelIndex + 1}: ${LEVELS[levelIndex].name}"
        spawnMarkers()
    }

    private func restartLevel(): Unit {
        let keepLevel = levelIndex
        loadLevel(keepLevel)
    }

    private func spawnMarkers(): Unit {
        let markers = tileMap.findAny(["P", "G", "K", "X", "^", "M"])
        for (marker in markers) {
            match (marker.symbol) {
                case "P" => spawnPlayer(marker.x, marker.y)
                case "G" => spawnSensor(marker.x, marker.y, KIND_GEM, gemAnim.current(), 0.8, 0.8)
                case "K" => spawnSensor(marker.x, marker.y, KIND_KEY, Sprite2D(["k"], style: Style(fg: Color.Yellow, bg: Color.Black, modifier: Modifier.strong())), 0.8, 0.8)
                case "X" => spawnSensor(marker.x, marker.y - 1, KIND_EXIT, Sprite2D(["[]", "[]"], style: Style(fg: Color.Rgb(112, 255, 173), bg: Color.Black, modifier: Modifier.strong())), 2.0, 2.0)
                case "^" => spawnSensor(marker.x, marker.y, KIND_HAZARD, Sprite2D(["^"], style: Style(fg: Color.Rgb(255, 84, 84), bg: Color.Black, modifier: Modifier.strong())), 1.0, 0.8)
                case "M" => spawnEnemy(marker.x, marker.y - 1)
                case _ => ()
            }
        }
    }

    private func spawnPlayer(x: Int64, y: Int64): Unit {
        player = world.create()
        transforms.insert(player, Transform2D(position: Vec2(x: Float64(x), y: Float64(y - 1)), size: Vec2(x: 2.0, y: 2.0)))
        velocities.insert(player, Velocity2D())
        colliders.insert(player, Collider2D(bounds: Aabb(width: 1.8, height: 2.0), layer: LAYER_PLAYER, mask: Int64.Max))
        bodies.insert(player, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 1.0, damping: 0.0))
        sprites.insert(player, playerAnim.current())
        kinds.insert(player, KIND_PLAYER)
    }

    private func spawnSensor(x: Int64, y: Int64, kind: Int64, sprite: Sprite2D, width: Float64, height: Float64): EntityId {
        let id = world.create()
        transforms.insert(id, Transform2D(position: Vec2(x: Float64(x), y: Float64(y)), size: Vec2(x: width, y: height)))
        colliders.insert(id, Collider2D(kind: ColliderKind.Sensor, bounds: Aabb(width: width, height: height), layer: LAYER_SENSOR, mask: LAYER_PLAYER))
        sprites.insert(id, sprite)
        kinds.insert(id, kind)
        id
    }

    private func spawnEnemy(x: Int64, y: Int64): Unit {
        let id = spawnSensor(x, y, KIND_ENEMY, Sprite2D(["mm"], style: Style(fg: Color.Rgb(255, 120, 180), bg: Color.Black, modifier: Modifier.strong())), 2.0, 1.0)
        patrols.insert(id, Patrol(Float64(max(1, x - 5)), Float64(min(tileMap.width - 3, x + 5))))
    }

    private func step(deltaMillis: Int64): Unit {
        if (won) {
            input.beginFrame()
            return
        }
        let dt = max(1, deltaMillis)
        if (invulnerableMillis > 0) { invulnerableMillis = max(0, invulnerableMillis - dt) }
        if (jumpBufferMillis > 0) { jumpBufferMillis = max(0, jumpBufferMillis - dt) }
        if (coyoteMillis > 0) { coyoteMillis = max(0, coyoteMillis - dt) }
        if (jumpPressed()) { jumpBufferMillis = 140 }
        updatePlayerVelocity()
        updatePatrols(dt)
        let hits = physics.step(world, transforms, velocities, colliders, bodies, dt)
        onGround = false
        for (hit in hits) {
            if (hit.entity == player && hit.normal.y < 0.0) {
                onGround = true
                coyoteMillis = 90
            }
        }
        if (jumpBufferMillis > 0 && (onGround || coyoteMillis > 0)) {
            jump()
        }
        updateAnimations(dt)
        handleOverlaps()
        updateCamera()
        cleanupDead()
        input.beginFrame()
        _ = world.advanceFrame()
    }

    private func updatePlayerVelocity(): Unit {
        var velocity = match (velocities.get(player)) {
            case Some(v) => v
            case None => return
        }
        let axis = input.axis(KeyCode.Left, KeyCode.Right) + input.axis(KeyCode.Char(r'a'), KeyCode.Char(r'd'))
        velocity.value.x = fclamp(Float64(axis) * PLAYER_SPEED, -PLAYER_SPEED, PLAYER_SPEED)
        _ = velocities.set(player, velocity)
    }

    private func jump(): Unit {
        var velocity = match (velocities.get(player)) {
            case Some(v) => v
            case None => return
        }
        velocity.value.y = JUMP_SPEED
        _ = velocities.set(player, velocity)
        jumpBufferMillis = 0
        coyoteMillis = 0
        onGround = false
        message = "jump!"
    }

    private func jumpPressed(): Bool {
        input.justPressed(KeyCode.Up) || input.justPressed(KeyCode.Char(r'w')) || input.justPressed(KeyCode.Char(r' '))
    }

    private func updatePatrols(deltaMillis: Int64): Unit {
        let dt = Float64(deltaMillis) / 1000.0
        for (id in patrols.entities()) {
            var patrol = match (patrols.get(id)) {
                case Some(p) => p
                case None => continue
            }
            var transform = match (transforms.get(id)) {
                case Some(t) => t
                case None => continue
            }
            transform.position.x += patrol.dir * patrol.speed * dt
            if (transform.position.x <= patrol.minX) {
                transform.position.x = patrol.minX
                patrol.dir = 1.0
            }
            if (transform.position.x >= patrol.maxX) {
                transform.position.x = patrol.maxX
                patrol.dir = -1.0
            }
            _ = transforms.set(id, transform)
            _ = patrols.set(id, patrol)
        }
    }

    private func updateAnimations(deltaMillis: Int64): Unit {
        _ = sprites.set(player, playerAnim.advance(deltaMillis))
        let gemSprite = gemAnim.advance(deltaMillis)
        for (id in kinds.entities()) {
            match (kinds.get(id)) {
                case Some(kind) =>
                    if (kind == KIND_GEM) {
                        _ = sprites.set(id, gemSprite)
                    }
                case None => ()
            }
        }
    }

    private func handleOverlaps(): Unit {
        let overlaps = physics.overlaps(world, transforms, colliders, player)
        for (hit in overlaps) {
            let kind = match (kinds.get(hit.other)) {
                case Some(k) => k
                case None => continue
            }
            if (kind == KIND_GEM) {
                if (world.destroy(hit.other)) {
                    score++
                    message = "crystal ${score}/${totalGems}"
                }
            } else if (kind == KIND_KEY) {
                if (world.destroy(hit.other)) {
                    keys++
                    message = "gate key acquired"
                }
            } else if (kind == KIND_EXIT) {
                if (keys > 0) {
                    advanceLevel()
                    return
                } else {
                    message = "the gate needs a key"
                }
            } else if (kind == KIND_HAZARD || kind == KIND_ENEMY) {
                hurtPlayer()
            }
        }
        let t = match (transforms.get(player)) {
            case Some(value) => value
            case None => return
        }
        if (t.position.y > Float64(tileMap.height + 4)) { hurtPlayer(force: true) }
    }

    private func hurtPlayer(force!: Bool = false): Unit {
        if (!force && invulnerableMillis > 0) { return }
        lives--
        if (lives <= 0) {
            message = "lost in the caves - restarting"
            restartLevel()
            return
        }
        invulnerableMillis = 900
        message = "ouch! lives ${lives}"
        let starts = tileMap.find("P")
        if (starts.size > 0) {
            _ = transforms.set(player, Transform2D(position: Vec2(x: Float64(starts[0].x), y: Float64(starts[0].y - 1)), size: Vec2(x: 2.0, y: 2.0)))
            _ = velocities.set(player, Velocity2D())
        }
    }

    private func advanceLevel(): Unit {
        if (levelIndex + 1 >= LEVELS.size) {
            won = true
            message = "vault cleared: ${score}/${totalGems} crystals on final run"
        } else {
            loadLevel(levelIndex + 1)
        }
    }

    private func updateCamera(): Unit {
        let t = match (transforms.get(player)) {
            case Some(value) => value
            case None => return
        }
        camera.origin.x = fclamp(t.position.x - 24.0, 0.0, Float64(max(0, tileMap.width - VIEW_W + 2)))
        camera.origin.y = 0.0
    }

    private func cleanupDead(): Unit {
        transforms.clearDead(world)
        velocities.clearDead(world)
        colliders.clearDead(world)
        bodies.clearDead(world)
        sprites.clearDead(world)
        kinds.clearDead(world)
        patrols.clearDead(world)
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(CrystalScene(this), frame.area)
    }
}

class CrystalScene <: Widget {
    let app: CrystalCaves

    init(app: CrystalCaves) {
        this.app = app
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        let guard = SizeGuard(VIEW_W, VIEW_H)
        let fit = guard.fit(area)
        let canvas = Canvas(buffer, fit.content)
        canvas.fillRect(area, Style(bg: Color.Rgb(3, 6, 12)))
        if (fit.tooSmall) {
            canvas.drawText(area.x, area.y, "terminal too small for crystal_caves", Style(fg: Color.Yellow, bg: Color.Rgb(3, 6, 12)))
            return
        }
        let level = LEVELS[app.levelIndex]
        let hud = "Crystal Caves  ${app.levelIndex + 1}/${LEVELS.size} ${level.name}  lives:${app.lives} gems:${app.score}/${app.totalGems} keys:${app.keys}"
        canvas.drawText(fit.content.x, fit.content.y, clipText(hud, fit.content.width), Style(fg: Color.White, bg: Color.Rgb(9, 12, 20), modifier: Modifier.strong()))
        let worldArea = Rect(fit.content.x, fit.content.y + 2, VIEW_W, WORLD_VIEW_H)
        canvas.fillRect(worldArea, Style(bg: level.sky))
        renderBackground(canvas, worldArea, level)
        renderTiles(canvas, worldArea, level)
        app.camera.viewport = worldArea
        app.renderer.render(worldArea, buffer, app.transforms, app.sprites, camera: app.camera)
        canvas.drawText(fit.content.x, fit.content.y + 20, clipText(app.message, fit.content.width), Style(fg: level.accent, bg: Color.Rgb(5, 8, 14), modifier: Modifier.strong()))
        canvas.drawText(fit.content.x, fit.content.y + 21, "move arrows/a/d  jump up/w/space  restart r  quit q", Style(fg: Color.White, bg: Color.Black))
        DebugOverlay(app.metrics).render(Rect(fit.content.x, fit.content.y + 22, fit.content.width, 1), buffer)
    }

    private func renderBackground(canvas: Canvas, worldArea: Rect, level: LevelDef): Unit {
        for (i in 0..8) {
            let x = worldArea.x + ((i * 13 - (roundCell(app.camera.origin.x) / 3)) % max(1, worldArea.width))
            let y = worldArea.y + 1 + (i % 4)
            canvas.drawText(x, y, ".", Style(fg: level.accent, bg: level.sky))
        }
        canvas.drawText(worldArea.x + 2, worldArea.y + 1, "crystal wind", Style(fg: Color.Rgb(120, 150, 190), bg: level.sky))
    }

    private func renderTiles(canvas: Canvas, worldArea: Rect, level: LevelDef): Unit {
        let firstX = roundCell(app.camera.origin.x)
        for (screenY in 0..WORLD_VIEW_H) {
            let mapY = screenY
            for (screenX in 0..VIEW_W) {
                let mapX = firstX + screenX
                let symbol = app.tileMap.tileAt(mapX, mapY)
                let x = worldArea.x + screenX
                let y = worldArea.y + screenY
                if (symbol == "#") {
                    canvas.drawText(x, y, "#", Style(fg: level.rock, bg: Color.Rgb(22, 18, 30), modifier: Modifier.strong()))
                } else if (symbol == "^") {
                    canvas.drawText(x, y, "^", Style(fg: Color.Rgb(255, 84, 84), bg: level.sky, modifier: Modifier.strong()))
                } else if (symbol == "X") {
                    canvas.drawText(x, y, "=", Style(fg: Color.Rgb(112, 255, 173), bg: level.sky, modifier: Modifier.strong()))
                }
            }
        }
    }
}

func clampInt(value: Int64, minValue: Int64, maxValue: Int64): Int64 {
    min(max(value, minValue), maxValue)
}

func fmin(a: Float64, b: Float64): Float64 { if (a < b) { a } else { b } }
func fmax(a: Float64, b: Float64): Float64 { if (a > b) { a } else { b } }
func fclamp(value: Float64, minValue: Float64, maxValue: Float64): Float64 {
    fmin(fmax(value, minValue), maxValue)
}

func roundCell(value: Float64): Int64 {
    if (value >= 0.0) { Int64(value + 0.5) } else { Int64(value - 0.5) }
}

func clipText(text: String, width: Int64): String {
    if (width <= 0) { return "" }
    var out = ""
    var used: Int64 = 0
    for (r in text.runes()) {
        let w = max(1, displayWidth(r))
        if (used + w > width) { return out }
        out += r.toString()
        used += w
    }
    out
}

main(): Int64 {
    let game = CrystalCaves()
    App(targetFps: 60, metrics: Some(game.metrics)).runWithCommands(
        { frame => game.render(frame) },
        { event => game.update(event) }
    )
    0
}
