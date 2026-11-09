package game

import core.*
import std.collection.*

/** 游戏世界中的实体标识。 */
public struct EntityId <: Equatable<EntityId> {
    /** 非负整数标识。 */
    public let value: Int64

    /** 创建实体标识；负值按零处理。
     * @param value 整数标识
     */
    public init(value: Int64) {
        this.value = max(0, value)
    }

    /** 比较实体标识值。
     * @param other 另一个实体标识
     * @return 标识值相同时为 true
     */
    public operator func ==(other: EntityId): Bool {
        value == other.value
    }
}

/** 分配实体标识并跟踪存活实体和帧序号。 */
public class EntityWorld {
    private var nextId: Int64 = 1
    private var frameValue: Int64 = 0
    private let alive = ArrayList<EntityId>()

    /** 创建空世界。 */
    public init() {}

    /** 创建新的存活实体。
     * @return 新实体标识
     */
    public func create(): EntityId {
        let id = EntityId(nextId)
        nextId++
        alive.add(id)
        id
    }

    /** 从世界中移除实体；组件存储需另行清理。
     * @param id 实体标识
     * @return 实体存在并被移除时为 true
     */
    public func destroy(id: EntityId): Bool {
        for (i in 0..alive.size) {
            if (alive[i] == id) {
                alive.remove(at: i)
                return true
            }
        }
        false
    }

    /** 查询实体是否仍在世界中。
     * @param id 实体标识
     * @return 存活时为 true
     */
    public func isAlive(id: EntityId): Bool {
        for (item in alive) {
            if (item == id) { return true }
        }
        false
    }

    /** 获取存活实体的快照。
     * @return 实体标识数组
     */
    public func entities(): Array<EntityId> {
        alive.toArray()
    }

    /** 获取当前帧序号。
     * @return 帧序号
     */
    public func frame(): Int64 { frameValue }

    /** 将帧序号增加一。
     * @return 增加后的帧序号
     */
    public func advanceFrame(): Int64 {
        frameValue++
        frameValue
    }
}

/** 按实体标识保存一种类型的组件；移除实体后可使用 clearDead 清理。 */
public class ComponentStore<T> {
    private let ids = ArrayList<EntityId>()
    private let values = ArrayList<T>()

    /** 创建空组件存储。 */
    public init() {}

    /** 插入组件；已有该实体时替换旧值。
     * @param id 实体标识
     * @param value 组件值
     */
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

    /** 移除实体对应的组件。
     * @param id 实体标识
     * @return 存在并移除组件时为 true
     */
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

    /** 判断实体是否有组件。
     * @param id 实体标识
     * @return 有组件时为 true
     */
    public func has(id: EntityId): Bool {
        indexOf(id) >= 0
    }

    /** 查询实体组件。
     * @param id 实体标识
     * @return 组件值；不存在时为 None
     */
    public func get(id: EntityId): ?T {
        let index = indexOf(id)
        if (index < 0) { return None }
        Some(values[index])
    }

    /** 更新已有组件，不会插入缺失的组件。
     * @param id 实体标识
     * @param value 新组件值
     * @return 成功更新时为 true
     */
    public func set(id: EntityId, value: T): Bool {
        let index = indexOf(id)
        if (index < 0) { return false }
        values[index] = value
        true
    }

    /** 获取带有组件的实体标识。
     * @return 实体标识数组
     */
    public func entities(): Array<EntityId> {
        ids.toArray()
    }

    /** 获取存储的组件数。
     * @return 组件数量
     */
    public func size(): Int64 { ids.size }

    /** 移除不在指定世界中的实体组件。
     * @param world 用于判断存活状态的世界
     */
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

/** 二维浮点向量。 */
public struct Vec2 <: Equatable<Vec2> {
    /** 横向分量。 */
    public var x: Float64
    /** 纵向分量。 */
    public var y: Float64

    /** 创建向量。
     * @param x 横向分量
     * @param y 纵向分量
     */
    public init(x!: Float64 = 0.0, y!: Float64 = 0.0) {
        this.x = x
        this.y = y
    }

    /** 逐分量比较向量。
     * @param other 另一个向量
     * @return 两个分量均相等时为 true
     */
    public operator func ==(other: Vec2): Bool {
        x == other.x && y == other.y
    }

    /** 计算向量和。
     * @param other 另一个向量
     * @return 相加后的向量
     */
    public func plus(other: Vec2): Vec2 { Vec2(x: x + other.x, y: y + other.y) }
    /** 计算向量差。
     * @param other 要减去的向量
     * @return 相减后的向量
     */
    public func minus(other: Vec2): Vec2 { Vec2(x: x - other.x, y: y - other.y) }
    /** 按标量缩放向量。
     * @param value 缩放倍数
     * @return 缩放后的向量
     */
    public func scale(value: Float64): Vec2 { Vec2(x: x * value, y: y * value) }
}

/** 二维轴对齐包围盒。 */
public struct Aabb <: Equatable<Aabb> {
    /** 左侧横坐标。 */
    public var x: Float64
    /** 顶部纵坐标。 */
    public var y: Float64
    /** 包围盒宽度。 */
    public var width: Float64
    /** 包围盒高度。 */
    public var height: Float64

    /** 创建包围盒；宽度和高度的负值按零处理。
     * @param x 左侧横坐标
     * @param y 顶部纵坐标
     * @param width 宽度
     * @param height 高度
     */
    public init(x!: Float64 = 0.0, y!: Float64 = 0.0, width!: Float64 = 0.0, height!: Float64 = 0.0) {
        this.x = x
        this.y = y
        this.width = fmax(0.0, width)
        this.height = fmax(0.0, height)
    }

    /** 逐字段比较包围盒。
     * @param other 另一个包围盒
     * @return 字段均相等时为 true
     */
    public operator func ==(other: Aabb): Bool {
        x == other.x && y == other.y && width == other.width && height == other.height
    }

    /** 右侧边界坐标。 */
    public prop right: Float64 { get() { x + width } }
    /** 底部边界坐标。 */
    public prop bottom: Float64 { get() { y + height } }

    /** 返回按向量平移后的包围盒。
     * @param delta 平移向量
     * @return 平移后的包围盒
     */
    public func moved(delta: Vec2): Aabb {
        Aabb(x: x + delta.x, y: y + delta.y, width: width, height: height)
    }

    /** 使用边界坐标的严格比较判断交叠；仅边界接触不算交叠。
     * @param other 另一个包围盒
     * @return 交叠时为 true
     */
    public func overlaps(other: Aabb): Bool {
        x < other.right && right > other.x && y < other.bottom && bottom > other.y
    }
}

/** 实体的二维位置和尺寸。 */
public struct Transform2D {
    /** 实体位置。 */
    public var position: Vec2
    /** 实体尺寸。 */
    public var size: Vec2

    /** 创建变换。
     * @param position 位置
     * @param size 尺寸
     */
    public init(position!: Vec2 = Vec2(), size!: Vec2 = Vec2(x: 1.0, y: 1.0)) {
        this.position = position
        this.size = size
    }

    /** 根据位置与尺寸创建包围盒。
     * @return 实体包围盒
     */
    public func bounds(): Aabb {
        Aabb(x: position.x, y: position.y, width: size.x, height: size.y)
    }
}

/** 实体的二维速度。 */
public struct Velocity2D {
    /** 速度向量。 */
    public var value: Vec2
    /** 创建速度。
     * @param value 速度向量
     */
    public init(value!: Vec2 = Vec2()) {
        this.value = value
    }
}

/** 由文本行组成的二维精灵。 */
public struct Sprite2D {
    /** 精灵文本行。 */
    public let rows: Array<String>
    /** 绘制样式。 */
    public let style: Style
    /** 绘制时跳过的字素簇。 */
    public let transparent: String

    /** 创建精灵。
     * @param rows 精灵文本行
     * @param style 绘制样式
     * @param transparent 透明字素簇
     */
    public init(rows: Array<String>, style!: Style = Style.default(), transparent!: String = " ") {
        this.rows = rows
        this.style = style
        this.transparent = transparent
    }
}

/** 精灵动画的一帧。 */
public struct SpriteFrame {
    /** 帧中的精灵。 */
    public let sprite: Sprite2D
    /** 帧持续时间，至少为一毫秒。 */
    public let durationMillis: Int64

    /** 创建精灵帧。
     * @param sprite 帧中的精灵
     * @param durationMillis 持续毫秒数，至少为一
     */
    public init(sprite: Sprite2D, durationMillis!: Int64 = 120) {
        this.sprite = sprite
        this.durationMillis = max(1, durationMillis)
    }
}

/** 按帧持续时间推进精灵的动画。 */
public class SpriteAnimation {
    private let frames: Array<SpriteFrame>
    private let loop: Bool
    private var index: Int64 = 0
    private var elapsedMillis: Int64 = 0

    /** 创建精灵动画。
     * @param frames 按顺序播放的帧
     * @param loop 是否循环播放
     */
    public init(frames: Array<SpriteFrame>, loop!: Bool = true) {
        this.frames = frames
        this.loop = loop
    }

    /** 将动画重置到第一帧和零经过时间。 */
    public func reset(): Unit {
        index = 0
        elapsedMillis = 0
    }

    /** 推进动画并返回当前精灵；空动画返回空精灵。
     * @param deltaMillis 增加的毫秒数，负值按零处理
     * @return 当前精灵
     */
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

    /** 获取当前精灵；空动画返回空精灵。
     * @return 当前精灵
     */
    public func current(): Sprite2D {
        if (frames.size == 0) { Sprite2D([]) } else { frames[index].sprite }
    }
}

/** 将世界位置映射到终端视口的相机。 */
public struct Camera2D {
    /** 世界坐标中的视口原点。 */
    public var origin: Vec2
    /** 终端中的视口区域。 */
    public var viewport: Rect

    /** 创建二维相机。
     * @param origin 世界坐标原点
     * @param viewport 终端视口区域
     */
    public init(origin!: Vec2 = Vec2(), viewport!: Rect = Rect(0, 0, 80, 24)) {
        this.origin = origin
        this.viewport = viewport
    }
}

/** 碰撞体的运动响应类型。 */
public enum ColliderKind {
    /** 参与运动阻挡。 */
    | Solid
    /** 用于重叠查询，不阻挡运动。 */
    | Sensor
}

/** 碰撞体的局部包围盒及过滤配置。 */
public struct Collider2D {
    /** 碰撞响应类型。 */
    public let kind: ColliderKind
    /** 相对实体位置的局部边界。 */
    public let bounds: Aabb
    /** 碰撞层位掩码。 */
    public let layer: Int64
    /** 允许交互的碰撞层位掩码。 */
    public let mask: Int64

    /** 创建碰撞体；两侧的 mask 与对方 layer 均匹配时才检测碰撞。
     * @param kind 碰撞响应类型
     * @param bounds 局部边界
     * @param layer 自身碰撞层
     * @param mask 允许交互的层
     */
    public init(kind!: ColliderKind = ColliderKind.Solid, bounds!: Aabb = Aabb(width: 1.0, height: 1.0), layer!: Int64 = 1, mask!: Int64 = Int64.Max) {
        this.kind = kind
        this.bounds = bounds
        this.layer = layer
        this.mask = mask
    }
}

/** 物理世界中实体的运动方式。 */
public enum BodyType {
    /** 不由物理步进移动。 */
    | Static
    /** 按速度移动，不受重力加速。 */
    | Kinematic
    /** 按速度及重力移动。 */
    | Dynamic
}

/** 实体物理运动参数。 */
public struct RigidBody2D {
    /** 实体运动方式。 */
    public let bodyType: BodyType
    /** 保存的质量，至少为 0.001；当前物理步进不使用该值。 */
    public let mass: Float64
    /** 动态实体的重力倍率。 */
    public let gravityScale: Float64
    /** 速度阻尼，范围为 0 到 1。 */
    public let damping: Float64

    /** 创建刚体参数。
     * @param bodyType 运动方式
     * @param mass 质量，至少为 0.001
     * @param gravityScale 重力倍率
     * @param damping 阻尼，限制在 0 到 1
     */
    public init(bodyType!: BodyType = BodyType.Dynamic, mass!: Float64 = 1.0, gravityScale!: Float64 = 1.0, damping!: Float64 = 0.0) {
        this.bodyType = bodyType
        this.mass = fmax(0.001, mass)
        this.gravityScale = gravityScale
        this.damping = fclamp(damping, 0.0, 1.0)
    }
}

/** 描述一个实体与另一实体的碰撞或重叠。 */
public struct CollisionEvent {
    /** 发起检测的实体。 */
    public let entity: EntityId
    /** 另一实体。 */
    public let other: EntityId
    /** 碰撞法向量。 */
    public let normal: Vec2
    /** 运动子步中的归一化碰撞时间，范围为 0 到 1。 */
    public let time: Float64
    /** 碰撞位置横坐标。 */
    public let hitX: Float64
    /** 碰撞位置纵坐标。 */
    public let hitY: Float64

    /** 创建碰撞事件。
     * @param entity 发起检测的实体
     * @param other 另一实体
     * @param normal 法向量
     * @param time 归一化碰撞时间，限制为 0 到 1
     * @param hitX 碰撞位置横坐标
     * @param hitY 碰撞位置纵坐标
     */
    public init(entity: EntityId, other: EntityId, normal: Vec2, time: Float64, hitX: Float64, hitY: Float64) {
        this.entity = entity
        this.other = other
        this.normal = normal
        this.time = fclamp(time, 0.0, 1.0)
        this.hitX = hitX
        this.hitY = hitY
    }
}

/** 地图中一个匹配符号的位置。 */
public struct TileMarker <: Equatable<TileMarker> {
    /** 横向格坐标。 */
    public let x: Int64
    /** 纵向格坐标。 */
    public let y: Int64
    /** 地图符号。 */
    public let symbol: String

    /** 创建地图标记。
     * @param x 横向格坐标
     * @param y 纵向格坐标
     * @param symbol 地图符号
     */
    public init(x: Int64, y: Int64, symbol: String) {
        this.x = x
        this.y = y
        this.symbol = symbol
    }

    /** 比较标记的位置与符号。
     * @param other 另一个标记
     * @return 所有字段相同时为 true
     */
    public operator func ==(other: TileMarker): Bool {
        x == other.x && y == other.y && symbol == other.symbol
    }
}

/** 按组件存储推进简单二维运动，并查询实体重叠。 */
public class PhysicsWorld {
    /** 动态实体使用的重力加速度。 */
    public var gravity: Vec2
    /** 每次步进的最大子步数；构造时至少为一。 */
    public var maxSubSteps: Int64
    /** 碰撞运动时间使用的回退量；构造时至少为零。 */
    public var skin: Float64
    private let collisions = ArrayList<CollisionEvent>()

    /** 创建物理世界。
     * @param gravity 重力加速度
     * @param maxSubSteps 最大子步数，至少为一
     * @param skin 碰撞回退量，至少为零
     */
    public init(gravity!: Vec2 = Vec2(x: 0.0, y: 30.0), maxSubSteps!: Int64 = 4, skin!: Float64 = 0.001) {
        this.gravity = gravity
        this.maxSubSteps = max(1, maxSubSteps)
        this.skin = fmax(0.0, skin)
    }

    /** 推进运动并更新变换和速度组件。非正时间不推进；传感器不阻挡运动。
     * @param world 实体世界
     * @param transforms 变换组件存储
     * @param velocities 速度组件存储
     * @param colliders 碰撞组件存储
     * @param bodies 刚体组件存储
     * @param deltaMillis 推进的毫秒数
     * @return 本次运动中检测到的碰撞事件
     */
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

    /** 查询指定存活实体与其他碰撞体的当前重叠。
     * @param world 实体世界
     * @param transforms 变换组件存储
     * @param colliders 碰撞组件存储
     * @param id 要查询的实体
     * @return 符合层过滤规则的重叠事件
     */
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
            velocities.insert(id, velocity)
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

/** 跟踪游戏按键的按住和本帧首次按下状态。 */
public class GameInputState {
    private let pressedKeys = ArrayList<KeyCode>()
    private let justPressedKeys = ArrayList<KeyCode>()

    /** 创建空输入状态。 */
    public init() {}

    /** 清除上一帧的首次按下记录；保持按住状态。 */
    public func beginFrame(): Unit {
        while (justPressedKeys.size > 0) {
            justPressedKeys.remove(at: 0)
        }
    }

    /** 更新按键状态；失焦时清空按键。
     * @param event 输入事件
     */
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

    /** 查询按键是否按住。
     * @param code 按键代码
     * @return 按住时为 true
     */
    public func pressed(code: KeyCode): Bool {
        containsKey(pressedKeys, code)
    }

    /** 查询按键是否在本帧首次按下。
     * @param code 按键代码
     * @return 本帧首次按下时为 true
     */
    public func justPressed(code: KeyCode): Bool {
        containsKey(justPressedKeys, code)
    }

    /** 根据一对按键计算方向。
     * @param negative 负方向按键
     * @param positive 正方向按键
     * @return 正方向减负方向，结果为 -1、0 或 1
     */
    public func axis(negative: KeyCode, positive: KeyCode): Int64 {
        let left = if (pressed(negative)) { 1 } else { 0 }
        let right = if (pressed(positive)) { 1 } else { 0 }
        right - left
    }
}

/** 将精灵和变换组件绘制到终端缓冲区。 */
public class SpriteRenderer {
    /** 创建精灵渲染器。 */
    public init() {}

    /** 绘制同时具有精灵和变换组件的实体。
     * @param area 画布区域
     * @param buffer 目标缓冲区
     * @param transforms 实体变换存储
     * @param sprites 实体精灵存储
     * @param camera 世界坐标到视口的映射
     */
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

    /** 将一个精灵绘制到画布，跳过透明字素簇。
     * @param canvas 目标画布
     * @param transform 实体变换
     * @param sprite 要绘制的精灵
     * @param camera 世界坐标到视口的映射
     */
    public func drawSprite(canvas: Canvas, transform: Transform2D, sprite: Sprite2D, camera: Camera2D): Unit {
        let x = roundCell(transform.position.x - camera.origin.x) + camera.viewport.x
        let y = roundCell(transform.position.y - camera.origin.y) + camera.viewport.y
        for (row in 0..sprite.rows.size) {
            drawSpriteRow(canvas, x, y + row, sprite.rows[row], sprite)
        }
    }

    private func drawSpriteRow(canvas: Canvas, x: Int64, y: Int64, row: String, sprite: Sprite2D): Unit {
        var cx = x
        for (cluster in graphemeClusters(row, options: canvas.textWidthOptions())) {
            if (cluster.text != sprite.transparent) {
                canvas.drawText(cx, y, cluster.text, sprite.style)
            }
            cx += cluster.width
        }
    }
}

/** 从文本行构建、查询和绘制的格子地图。 */
public class TileMap {
    /** 最长地图行的显示单元格宽度。 */
    public let width: Int64
    /** 地图行数。 */
    public let height: Int64
    private let rows: Array<String>
    private let solidSymbol: String
    private let widthOptions: TextWidthOptions

    /** 保存给定的地图行，以行数作为高度、按 widthOptions 测得的最长行宽作为宽度，并设置用于判断实心格的符号。查询与碰撞使用同一宽度策略；默认将宽度不确定的字符视为单列。
     * @param rows 地图文本行
     * @param solidSymbol 实心格符号
     * @param widthOptions 地图查询使用的文本宽度策略
     */
    public init(rows: Array<String>, solidSymbol!: String = "#", widthOptions!: TextWidthOptions = TextWidthOptions()) {
        this.rows = rows
        this.height = rows.size
        this.width = maxLineWidth(rows, options: widthOptions)
        this.solidSymbol = solidSymbol
        this.widthOptions = widthOptions
    }

    /** 判断格子的符号是否等于实心符号。
     * @param x 横向格坐标
     * @param y 纵向格坐标
     * @return 符号匹配时为 true
     */
    public func isSolid(x: Int64, y: Int64): Bool {
        tileAt(x, y) == solidSymbol
    }

    /** 获取指定格子的地图符号。
     * @param x 横向格坐标
     * @param y 纵向格坐标
     * @return 对应符号；坐标无效时为空字符串
     */
    public func tileAt(x: Int64, y: Int64): String {
        if (x < 0 || y < 0 || y >= rows.size) { return "" }
        symbolAt(rows[y], x, options: widthOptions)
    }

    /** 查找等于指定符号的格子。
     * @param symbol 要查找的符号
     * @return 匹配格子的标记
     */
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

    /** 查找符号属于给定集合的格子。
     * @param symbols 要查找的符号
     * @return 匹配格子的标记
     */
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

    /** 为每个实心格创建实体、变换和碰撞组件。
     * @param world 接收实体的世界
     * @param transforms 变换组件存储
     * @param colliders 碰撞组件存储
     * @return 创建的实体标识
     */
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

    /** 将地图中非空且非空格的符号绘制到缓冲区的指定区域；绘制坐标按相机原点的取整格坐标偏移，并加上视口偏移。绘制使用目标缓冲区的文本宽度策略；若游戏坐标需要与显示一致，构造时传入相同的宽度策略。
     * @param area 画布区域
     * @param buffer 目标缓冲区
     * @param camera 世界坐标到视口的映射
     * @param style 显式绘制样式
     */
    public func render(area: Rect, buffer: Buffer, camera!: Camera2D = Camera2D(), style!: Style): Unit {
        render(area, buffer, camera: camera, style: Some(style))
    }

    /** 使用可选样式绘制非空格地图符号。
     * @param area 画布区域
     * @param buffer 目标缓冲区
     * @param camera 世界坐标到视口的映射
     * @param style 可选样式，None 使用缓冲区主题或默认样式
     */
    public func render(area: Rect, buffer: Buffer, camera!: Camera2D = Camera2D(), style!: ?Style = None): Unit {
        let canvas = Canvas(buffer, area)
        let resolvedStyle = match (style) {
            case Some(value) => value
            case None => match (buffer.resolveTheme(Option<Theme>.None)) {
                case Some(theme) => theme.normal
                case None => Style(fg: Color.White)
            }
        }
        for (y in 0..height) {
            let screenY = y - roundCell(camera.origin.y) + camera.viewport.y
            var x: Int64 = 0
            for (cluster in graphemeClusters(rows[y], options: canvas.textWidthOptions())) {
                if (cluster.width <= 0) { continue }
                if (cluster.text != " ") {
                    canvas.drawText(x - roundCell(camera.origin.x) + camera.viewport.x, screenY, cluster.text, resolvedStyle)
                }
                x += cluster.width
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

func maxLineWidth(rows: Array<String>, options!: TextWidthOptions = TextWidthOptions()): Int64 {
    var width: Int64 = 0
    for (row in rows) {
        width = max(width, displayWidth(row, options: options))
    }
    width
}

func symbolAt(row: String, x: Int64, options!: TextWidthOptions = TextWidthOptions()): String {
    var cx: Int64 = 0
    for (cluster in graphemeClusters(row, options: options)) {
        if (cluster.width <= 0) { continue }
        if (cx == x) { return cluster.text }
        cx += cluster.width
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
