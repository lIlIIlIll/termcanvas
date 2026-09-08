package game

import core.*
import std.collection.*

public struct EntityId <: Equatable<EntityId> {
    public let value: Int64

    public init(value: Int64) {
        this.value = max(0, value)
    }

    public operator func ==(other: EntityId): Bool {
        value == other.value
    }
}

public class EntityWorld {
    private var nextId: Int64 = 1
    private var frameValue: Int64 = 0
    private let alive = ArrayList<EntityId>()

    public init() {}

    public func create(): EntityId {
        let id = EntityId(nextId)
        nextId++
        alive.add(id)
        id
    }

    public func destroy(id: EntityId): Bool {
        for (i in 0..alive.size) {
            if (alive[i] == id) {
                alive.remove(at: i)
                return true
            }
        }
        false
    }

    public func isAlive(id: EntityId): Bool {
        for (item in alive) {
            if (item == id) { return true }
        }
        false
    }

    public func entities(): Array<EntityId> {
        alive.toArray()
    }

    public func frame(): Int64 { frameValue }

    public func advanceFrame(): Int64 {
        frameValue++
        frameValue
    }
}

public class ComponentStore<T> {
    private let ids = ArrayList<EntityId>()
    private let values = ArrayList<T>()

    public init() {}

    public func insert(id: EntityId, value: T): Unit {
        for (i in 0..ids.size) {
            if (ids[i] == id) {
                values[i] = value
                return
            }
        }
        ids.add(id)
        values.add(value)
    }

    public func remove(id: EntityId): Bool {
        for (i in 0..ids.size) {
            if (ids[i] == id) {
                ids.remove(at: i)
                values.remove(at: i)
                return true
            }
        }
        false
    }

    public func has(id: EntityId): Bool {
        indexOf(id) >= 0
    }

    public func get(id: EntityId): ?T {
        let index = indexOf(id)
        if (index < 0) { return None }
        Some(values[index])
    }

    public func set(id: EntityId, value: T): Bool {
        let index = indexOf(id)
        if (index < 0) { return false }
        values[index] = value
        true
    }

    public func entities(): Array<EntityId> {
        ids.toArray()
    }

    public func size(): Int64 { ids.size }

    public func clearDead(world: EntityWorld): Unit {
        var i: Int64 = 0
        while (i < ids.size) {
            if (!world.isAlive(ids[i])) {
                ids.remove(at: i)
                values.remove(at: i)
            } else {
                i++
            }
        }
    }

    private func indexOf(id: EntityId): Int64 {
        for (i in 0..ids.size) {
            if (ids[i] == id) { return i }
        }
        -1
    }
}

public struct Vec2 <: Equatable<Vec2> {
    public var x: Float64
    public var y: Float64

    public init(x!: Float64 = 0.0, y!: Float64 = 0.0) {
        this.x = x
        this.y = y
    }

    public operator func ==(other: Vec2): Bool {
        x == other.x && y == other.y
    }

    public func plus(other: Vec2): Vec2 { Vec2(x: x + other.x, y: y + other.y) }
    public func minus(other: Vec2): Vec2 { Vec2(x: x - other.x, y: y - other.y) }
    public func scale(value: Float64): Vec2 { Vec2(x: x * value, y: y * value) }
}

public struct Aabb <: Equatable<Aabb> {
    public var x: Float64
    public var y: Float64
    public var width: Float64
    public var height: Float64

    public init(x!: Float64 = 0.0, y!: Float64 = 0.0, width!: Float64 = 0.0, height!: Float64 = 0.0) {
        this.x = x
        this.y = y
        this.width = fmax(0.0, width)
        this.height = fmax(0.0, height)
    }

    public operator func ==(other: Aabb): Bool {
        x == other.x && y == other.y && width == other.width && height == other.height
    }

    public prop right: Float64 { get() { x + width } }
    public prop bottom: Float64 { get() { y + height } }

    public func moved(delta: Vec2): Aabb {
        Aabb(x: x + delta.x, y: y + delta.y, width: width, height: height)
    }

    public func overlaps(other: Aabb): Bool {
        x < other.right && right > other.x && y < other.bottom && bottom > other.y
    }
}

public struct Transform2D {
    public var position: Vec2
    public var size: Vec2

    public init(position!: Vec2 = Vec2(), size!: Vec2 = Vec2(x: 1.0, y: 1.0)) {
        this.position = position
        this.size = size
    }

    public func bounds(): Aabb {
        Aabb(x: position.x, y: position.y, width: size.x, height: size.y)
    }
}

public struct Velocity2D {
    public var value: Vec2
    public init(value!: Vec2 = Vec2()) {
        this.value = value
    }
}

public struct Sprite2D {
    public let rows: Array<String>
    public let style: Style
    public let transparent: String

    public init(rows: Array<String>, style!: Style = Style.default(), transparent!: String = " ") {
        this.rows = rows
        this.style = style
        this.transparent = transparent
    }
}

public struct SpriteFrame {
    public let sprite: Sprite2D
    public let durationMillis: Int64

    public init(sprite: Sprite2D, durationMillis!: Int64 = 120) {
        this.sprite = sprite
        this.durationMillis = max(1, durationMillis)
    }
}

public class SpriteAnimation {
    private let frames: Array<SpriteFrame>
    private let loop: Bool
    private var index: Int64 = 0
    private var elapsedMillis: Int64 = 0

    public init(frames: Array<SpriteFrame>, loop!: Bool = true) {
        this.frames = frames
        this.loop = loop
    }

    public func reset(): Unit {
        index = 0
        elapsedMillis = 0
    }

    public func advance(deltaMillis: Int64): Sprite2D {
        if (frames.size == 0) { return Sprite2D([]) }
        elapsedMillis += max(0, deltaMillis)
        var current = frames[index]
        while (elapsedMillis >= current.durationMillis && (loop || index < frames.size - 1)) {
            elapsedMillis -= current.durationMillis
            index++
            if (index >= frames.size) { index = 0 }
            current = frames[index]
        }
        current.sprite
    }

    public func current(): Sprite2D {
        if (frames.size == 0) { Sprite2D([]) } else { frames[index].sprite }
    }
}

public struct Camera2D {
    public var origin: Vec2
    public var viewport: Rect

    public init(origin!: Vec2 = Vec2(), viewport!: Rect = Rect(0, 0, 80, 24)) {
        this.origin = origin
        this.viewport = viewport
    }
}

public enum ColliderKind {
    | Solid
    | Sensor
}

public struct Collider2D {
    public let kind: ColliderKind
    public let bounds: Aabb
    public let layer: Int64
    public let mask: Int64

    public init(kind!: ColliderKind = ColliderKind.Solid, bounds!: Aabb = Aabb(width: 1.0, height: 1.0), layer!: Int64 = 1, mask!: Int64 = Int64.Max) {
        this.kind = kind
        this.bounds = bounds
        this.layer = layer
        this.mask = mask
    }
}

public enum BodyType {
    | Static
    | Kinematic
    | Dynamic
}

public struct RigidBody2D {
    public let bodyType: BodyType
    public let mass: Float64
    public let gravityScale: Float64
    public let damping: Float64

    public init(bodyType!: BodyType = BodyType.Dynamic, mass!: Float64 = 1.0, gravityScale!: Float64 = 1.0, damping!: Float64 = 0.0) {
        this.bodyType = bodyType
        this.mass = fmax(0.001, mass)
        this.gravityScale = gravityScale
        this.damping = fclamp(damping, 0.0, 1.0)
    }
}

public struct CollisionEvent {
    public let entity: EntityId
    public let other: EntityId
    public let normal: Vec2
    public let time: Float64
    public let hitX: Float64
    public let hitY: Float64

    public init(entity: EntityId, other: EntityId, normal: Vec2, time: Float64, hitX: Float64, hitY: Float64) {
        this.entity = entity
        this.other = other
        this.normal = normal
        this.time = fclamp(time, 0.0, 1.0)
        this.hitX = hitX
        this.hitY = hitY
    }
}

public struct TileMarker <: Equatable<TileMarker> {
    public let x: Int64
    public let y: Int64
    public let symbol: String

    public init(x: Int64, y: Int64, symbol: String) {
        this.x = x
        this.y = y
        this.symbol = symbol
    }

    public operator func ==(other: TileMarker): Bool {
        x == other.x && y == other.y && symbol == other.symbol
    }
}

public class PhysicsWorld {
    public var gravity: Vec2
    public var maxSubSteps: Int64
    public var skin: Float64
    private let collisions = ArrayList<CollisionEvent>()

    public init(gravity!: Vec2 = Vec2(x: 0.0, y: 30.0), maxSubSteps!: Int64 = 4, skin!: Float64 = 0.001) {
        this.gravity = gravity
        this.maxSubSteps = max(1, maxSubSteps)
        this.skin = fmax(0.0, skin)
    }

    public func step(
        world: EntityWorld,
        transforms: ComponentStore<Transform2D>,
        velocities: ComponentStore<Velocity2D>,
        colliders: ComponentStore<Collider2D>,
        bodies: ComponentStore<RigidBody2D>,
        deltaMillis: Int64
    ): Array<CollisionEvent> {
        clearCollisions()
        let dt = fmax(0.0, Float64(deltaMillis) / 1000.0)
        if (dt <= 0.0) { return [] }
        let substeps = max(1, min(maxSubSteps, Int64(dt / 0.016) + 1))
        let stepDt = dt / Float64(substeps)
        for (_ in 0..substeps) {
            stepOnce(world, transforms, velocities, colliders, bodies, stepDt)
        }
        collisions.toArray()
    }

    public func overlaps(
        world: EntityWorld,
        transforms: ComponentStore<Transform2D>,
        colliders: ComponentStore<Collider2D>,
        id: EntityId
    ): Array<CollisionEvent> {
        let out = ArrayList<CollisionEvent>()
        if (!world.isAlive(id)) { return [] }
        let selfCollider = match (colliders.get(id)) {
            case Some(value) => value
            case None => return []
        }
        let selfTransform = match (transforms.get(id)) {
            case Some(value) => value
            case None => return []
        }
        let selfBounds = offsetBounds(selfTransform.bounds(), selfCollider.bounds)
        for (other in colliders.entities()) {
            if (other == id || !world.isAlive(other)) { continue }
            let otherCollider = match (colliders.get(other)) {
                case Some(value) => value
                case None => continue
            }
            if (!canCollide(selfCollider, otherCollider)) { continue }
            let otherTransform = match (transforms.get(other)) {
                case Some(value) => value
                case None => continue
            }
            let otherBounds = offsetBounds(otherTransform.bounds(), otherCollider.bounds)
            if (selfBounds.overlaps(otherBounds)) {
                out.add(CollisionEvent(id, other, penetrationNormal(selfBounds, otherBounds), 0.0, selfBounds.x, selfBounds.y))
            }
        }
        out.toArray()
    }

    private func stepOnce(
        world: EntityWorld,
        transforms: ComponentStore<Transform2D>,
        velocities: ComponentStore<Velocity2D>,
        colliders: ComponentStore<Collider2D>,
        bodies: ComponentStore<RigidBody2D>,
        dt: Float64
    ): Unit {
        for (id in bodies.entities()) {
            if (!world.isAlive(id)) { continue }
            let body = match (bodies.get(id)) {
                case Some(value) => value
                case None => continue
            }
            match (body.bodyType) {
                case BodyType.Static => continue
                case _ => ()
            }
            var transform = match (transforms.get(id)) {
                case Some(value) => value
                case None => continue
            }
            var velocity = match (velocities.get(id)) {
                case Some(value) => value
                case None => Velocity2D()
            }
            match (body.bodyType) {
                case BodyType.Dynamic =>
                    velocity.value = velocity.value.plus(gravity.scale(body.gravityScale * dt))
                case _ => ()
            }
            if (body.damping > 0.0) {
                velocity.value = velocity.value.scale(fmax(0.0, 1.0 - body.damping * dt))
            }
            let motion = velocity.value.scale(dt)
            let resolved = resolveMotion(id, transform.bounds(), motion, world, transforms, colliders)
            transform.position = transform.position.plus(resolved.motion)
            if (resolved.normal.x != 0.0) { velocity.value.x = 0.0 }
            if (resolved.normal.y != 0.0) { velocity.value.y = 0.0 }
            _ = transforms.set(id, transform)
            _ = velocities.set(id, velocity)
        }
    }

    private func resolveMotion(
        id: EntityId,
        box: Aabb,
        motion: Vec2,
        world: EntityWorld,
        transforms: ComponentStore<Transform2D>,
        colliders: ComponentStore<Collider2D>
    ): MotionResult {
        var bestTime = 1.0
        var bestNormal = Vec2()
        var bestOther = EntityId(0)
        var hit = false
        let selfCollider = match (colliders.get(id)) {
            case Some(value) => value
            case None => return MotionResult(motion, Vec2())
        }
        match (selfCollider.kind) {
            case ColliderKind.Sensor => return MotionResult(motion, Vec2())
            case _ => ()
        }
        for (other in colliders.entities()) {
            if (other == id || !world.isAlive(other)) { continue }
            let otherCollider = match (colliders.get(other)) {
                case Some(value) => value
                case None => continue
            }
            if (!canCollide(selfCollider, otherCollider)) { continue }
            match (otherCollider.kind) {
                case ColliderKind.Sensor => continue
                case _ => ()
            }
            let otherTransform = match (transforms.get(other)) {
                case Some(value) => value
                case None => continue
            }
            let target = offsetBounds(otherTransform.bounds(), otherCollider.bounds)
            match (sweepAabb(offsetBounds(box, selfCollider.bounds), target, motion)) {
                case Some(hitInfo) =>
                    if (hitInfo.time < bestTime) {
                        bestTime = hitInfo.time
                        bestNormal = hitInfo.normal
                        bestOther = other
                        hit = true
                    }
                case None => ()
            }
        }
        if (!hit) { return MotionResult(motion, Vec2()) }
        let travel = fmax(0.0, bestTime - skin)
        let resolved = motion.scale(travel)
        collisions.add(CollisionEvent(id, bestOther, bestNormal, bestTime, box.x + resolved.x, box.y + resolved.y))
        MotionResult(resolved, bestNormal)
    }

    private func clearCollisions(): Unit {
        while (collisions.size > 0) {
            collisions.remove(at: 0)
        }
    }
}

struct MotionResult {
    let motion: Vec2
    let normal: Vec2

    init(motion: Vec2, normal: Vec2) {
        this.motion = motion
        this.normal = normal
    }
}

public class GameInputState {
    private let pressedKeys = ArrayList<KeyCode>()
    private let justPressedKeys = ArrayList<KeyCode>()

    public init() {}

    public func beginFrame(): Unit {
        while (justPressedKeys.size > 0) {
            justPressedKeys.remove(at: 0)
        }
    }

    public func handle(event: Event): Unit {
        match (event) {
            case Event.KeyDown(key) =>
                if (!containsKey(pressedKeys, key.code)) {
                    pressedKeys.add(key.code)
                    justPressedKeys.add(key.code)
                }
            case Event.KeyHeld(key) =>
                if (!containsKey(pressedKeys, key.code)) {
                    pressedKeys.add(key.code)
                }
            case Event.KeyRepeat(key) =>
                if (!containsKey(pressedKeys, key.code)) {
                    pressedKeys.add(key.code)
                }
            case Event.KeyUp(key) =>
                removeKey(pressedKeys, key.code)
            case Event.FocusOut =>
                clearKeys(pressedKeys)
                clearKeys(justPressedKeys)
            case _ => ()
        }
    }

    public func pressed(code: KeyCode): Bool {
        containsKey(pressedKeys, code)
    }

    public func justPressed(code: KeyCode): Bool {
        containsKey(justPressedKeys, code)
    }

    public func axis(negative: KeyCode, positive: KeyCode): Int64 {
        let left = if (pressed(negative)) { 1 } else { 0 }
        let right = if (pressed(positive)) { 1 } else { 0 }
        right - left
    }
}

public class SpriteRenderer {
    public init() {}

    public func render(
        area: Rect,
        buffer: Buffer,
        transforms: ComponentStore<Transform2D>,
        sprites: ComponentStore<Sprite2D>,
        camera!: Camera2D = Camera2D()
    ): Unit {
        let canvas = Canvas(buffer, area)
        for (id in sprites.entities()) {
            let sprite = match (sprites.get(id)) {
                case Some(value) => value
                case None => continue
            }
            let transform = match (transforms.get(id)) {
                case Some(value) => value
                case None => continue
            }
            drawSprite(canvas, transform, sprite, camera)
        }
    }

    public func drawSprite(canvas: Canvas, transform: Transform2D, sprite: Sprite2D, camera: Camera2D): Unit {
        let x = roundCell(transform.position.x - camera.origin.x) + camera.viewport.x
        let y = roundCell(transform.position.y - camera.origin.y) + camera.viewport.y
        for (row in 0..sprite.rows.size) {
            drawSpriteRow(canvas, x, y + row, sprite.rows[row], sprite)
        }
    }

    private func drawSpriteRow(canvas: Canvas, x: Int64, y: Int64, row: String, sprite: Sprite2D): Unit {
        var cx = x
        for (r in row.runes()) {
            let text = r.toString()
            if (text != sprite.transparent) {
                canvas.drawText(cx, y, text, sprite.style)
            }
            cx += max(1, displayWidth(r))
        }
    }
}

public class TileMap {
    public let width: Int64
    public let height: Int64
    private let rows: Array<String>
    private let solidSymbol: String

    public init(rows: Array<String>, solidSymbol!: String = "#") {
        this.rows = rows
        this.height = rows.size
        this.width = maxLineWidth(rows)
        this.solidSymbol = solidSymbol
    }

    public func isSolid(x: Int64, y: Int64): Bool {
        tileAt(x, y) == solidSymbol
    }

    public func tileAt(x: Int64, y: Int64): String {
        if (x < 0 || y < 0 || y >= rows.size) { return "" }
        symbolAt(rows[y], x)
    }

    public func find(symbol: String): Array<TileMarker> {
        let out = ArrayList<TileMarker>()
        for (y in 0..height) {
            for (x in 0..width) {
                if (tileAt(x, y) == symbol) {
                    out.add(TileMarker(x, y, symbol))
                }
            }
        }
        out.toArray()
    }

    public func findAny(symbols: Array<String>): Array<TileMarker> {
        let out = ArrayList<TileMarker>()
        for (y in 0..height) {
            for (x in 0..width) {
                let symbol = tileAt(x, y)
                if (containsString(symbols, symbol)) {
                    out.add(TileMarker(x, y, symbol))
                }
            }
        }
        out.toArray()
    }

    public func addStaticColliders(world: EntityWorld, transforms: ComponentStore<Transform2D>, colliders: ComponentStore<Collider2D>): Array<EntityId> {
        let out = ArrayList<EntityId>()
        for (y in 0..height) {
            for (x in 0..width) {
                if (isSolid(x, y)) {
                    let id = world.create()
                    transforms.insert(id, Transform2D(position: Vec2(x: Float64(x), y: Float64(y)), size: Vec2(x: 1.0, y: 1.0)))
                    colliders.insert(id, Collider2D(bounds: Aabb(width: 1.0, height: 1.0)))
                    out.add(id)
                }
            }
        }
        out.toArray()
    }

    public func render(area: Rect, buffer: Buffer, camera!: Camera2D = Camera2D(), style!: Style = Style(fg: Color.White)): Unit {
        let canvas = Canvas(buffer, area)
        for (y in 0..height) {
            let screenY = y - roundCell(camera.origin.y) + camera.viewport.y
            for (x in 0..width) {
                let symbol = symbolAt(rows[y], x)
                if (!symbol.isEmpty() && symbol != " ") {
                    canvas.drawText(x - roundCell(camera.origin.x) + camera.viewport.x, screenY, symbol, style)
                }
            }
        }
    }
}

struct SweepHit {
    let time: Float64
    let normal: Vec2
    init(time: Float64, normal: Vec2) {
        this.time = time
        this.normal = normal
    }
}

let INF: Float64 = 1000000000.0

func sweepAabb(moving: Aabb, target: Aabb, motion: Vec2): ?SweepHit {
    if (moving.overlaps(target)) {
        return Some(SweepHit(0.0, penetrationNormal(moving, target)))
    }
    if (motion.x == 0.0 && motion.y == 0.0) { return None }
    if (motion.x == 0.0 && (moving.right <= target.x || target.right <= moving.x)) { return None }
    if (motion.y == 0.0 && (moving.bottom <= target.y || target.bottom <= moving.y)) { return None }
    var xEntry: Float64
    var xExit: Float64
    if (motion.x > 0.0) {
        xEntry = target.x - moving.right
        xExit = target.right - moving.x
    } else {
        xEntry = target.right - moving.x
        xExit = target.x - moving.right
    }
    var yEntry: Float64
    var yExit: Float64
    if (motion.y > 0.0) {
        yEntry = target.y - moving.bottom
        yExit = target.bottom - moving.y
    } else {
        yEntry = target.bottom - moving.y
        yExit = target.y - moving.bottom
    }
    let xEntryTime = if (motion.x == 0.0) { -INF } else { xEntry / motion.x }
    let xExitTime = if (motion.x == 0.0) { INF } else { xExit / motion.x }
    let yEntryTime = if (motion.y == 0.0) { -INF } else { yEntry / motion.y }
    let yExitTime = if (motion.y == 0.0) { INF } else { yExit / motion.y }
    let entryTime = fmax(fmin(xEntryTime, xExitTime), fmin(yEntryTime, yExitTime))
    let exitTime = fmin(fmax(xEntryTime, xExitTime), fmax(yEntryTime, yExitTime))
    if (entryTime > exitTime || entryTime < 0.0 || entryTime > 1.0) { return None }
    var normal = Vec2()
    if (xEntryTime > yEntryTime) {
        normal = if (motion.x > 0.0) { Vec2(x: -1.0, y: 0.0) } else { Vec2(x: 1.0, y: 0.0) }
    } else {
        normal = if (motion.y > 0.0) { Vec2(x: 0.0, y: -1.0) } else { Vec2(x: 0.0, y: 1.0) }
    }
    Some(SweepHit(entryTime, normal))
}

func penetrationNormal(a: Aabb, b: Aabb): Vec2 {
    let left = a.right - b.x
    let right = b.right - a.x
    let top = a.bottom - b.y
    let bottom = b.bottom - a.y
    let minX = if (left < right) { -left } else { right }
    let minY = if (top < bottom) { -top } else { bottom }
    if (fabs(minX) < fabs(minY)) {
        Vec2(x: if (minX < 0.0) { -1.0 } else { 1.0 }, y: 0.0)
    } else {
        Vec2(x: 0.0, y: if (minY < 0.0) { -1.0 } else { 1.0 })
    }
}

func offsetBounds(base: Aabb, local: Aabb): Aabb {
    Aabb(x: base.x + local.x, y: base.y + local.y, width: if (local.width > 0.0) { local.width } else { base.width }, height: if (local.height > 0.0) { local.height } else { base.height })
}

func canCollide(left: Collider2D, right: Collider2D): Bool {
    (left.mask & right.layer) != 0 && (right.mask & left.layer) != 0
}

func containsKey(items: ArrayList<KeyCode>, code: KeyCode): Bool {
    for (item in items) {
        if (sameKeyCode(item, code)) { return true }
    }
    false
}

func removeKey(items: ArrayList<KeyCode>, code: KeyCode): Unit {
    var i: Int64 = 0
    while (i < items.size) {
        if (sameKeyCode(items[i], code)) {
            items.remove(at: i)
        } else {
            i++
        }
    }
}

func clearKeys(items: ArrayList<KeyCode>): Unit {
    while (items.size > 0) {
        items.remove(at: 0)
    }
}

func containsString(items: Array<String>, value: String): Bool {
    for (item in items) {
        if (item == value) { return true }
    }
    false
}

func sameKeyCode(left: KeyCode, right: KeyCode): Bool {
    match (left) {
        case KeyCode.Char(l) =>
            match (right) {
                case KeyCode.Char(r) => l == r
                case _ => false
            }
        case KeyCode.F(l) =>
            match (right) {
                case KeyCode.F(r) => l == r
                case _ => false
            }
        case KeyCode.CtrlC =>
            match (right) { case KeyCode.CtrlC => true; case _ => false }
        case KeyCode.Enter =>
            match (right) { case KeyCode.Enter => true; case _ => false }
        case KeyCode.Esc =>
            match (right) { case KeyCode.Esc => true; case _ => false }
        case KeyCode.Tab =>
            match (right) { case KeyCode.Tab => true; case _ => false }
        case KeyCode.BackTab =>
            match (right) { case KeyCode.BackTab => true; case _ => false }
        case KeyCode.Backspace =>
            match (right) { case KeyCode.Backspace => true; case _ => false }
        case KeyCode.Up =>
            match (right) { case KeyCode.Up => true; case _ => false }
        case KeyCode.Down =>
            match (right) { case KeyCode.Down => true; case _ => false }
        case KeyCode.Left =>
            match (right) { case KeyCode.Left => true; case _ => false }
        case KeyCode.Right =>
            match (right) { case KeyCode.Right => true; case _ => false }
        case KeyCode.Home =>
            match (right) { case KeyCode.Home => true; case _ => false }
        case KeyCode.End =>
            match (right) { case KeyCode.End => true; case _ => false }
        case KeyCode.PageUp =>
            match (right) { case KeyCode.PageUp => true; case _ => false }
        case KeyCode.PageDown =>
            match (right) { case KeyCode.PageDown => true; case _ => false }
        case KeyCode.Insert =>
            match (right) { case KeyCode.Insert => true; case _ => false }
        case KeyCode.Delete =>
            match (right) { case KeyCode.Delete => true; case _ => false }
    }
}

func maxLineWidth(rows: Array<String>): Int64 {
    var width: Int64 = 0
    for (row in rows) {
        width = max(width, displayWidth(row))
    }
    width
}

func symbolAt(row: String, x: Int64): String {
    var cx: Int64 = 0
    for (r in row.runes()) {
        if (cx == x) { return r.toString() }
        cx += max(1, displayWidth(r))
    }
    ""
}

func roundCell(value: Float64): Int64 {
    if (value >= 0.0) { Int64(value + 0.5) } else { Int64(value - 0.5) }
}

func fmin(a: Float64, b: Float64): Float64 { if (a < b) { a } else { b } }
func fmax(a: Float64, b: Float64): Float64 { if (a > b) { a } else { b } }
func fabs(a: Float64): Float64 { if (a < 0.0) { -a } else { a } }
func fclamp(value: Float64, minValue: Float64, maxValue: Float64): Float64 {
    fmin(fmax(value, minValue), maxValue)
}
