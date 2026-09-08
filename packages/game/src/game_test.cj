package game

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class GameExtensionTest {
    @TestCase
    func stationarySeparatedAxesDoNotBlockMotion(): Unit {
        for (vertical in [false, true]) {
            let world = EntityWorld()
            let mover = world.create()
            let wall = world.create()
            let transforms = ComponentStore<Transform2D>()
            let velocities = ComponentStore<Velocity2D>()
            let colliders = ComponentStore<Collider2D>()
            let bodies = ComponentStore<RigidBody2D>()
            transforms.insert(mover, Transform2D(size: Vec2(x: 1.0, y: 1.0)))
            velocities.insert(mover, Velocity2D(value: if (vertical) { Vec2(y: 100.0) } else { Vec2(x: 100.0) }))
            colliders.insert(mover, Collider2D())
            bodies.insert(mover, RigidBody2D(gravityScale: 0.0))
            transforms.insert(wall, Transform2D(position: if (vertical) { Vec2(x: 100.0, y: 5.0) } else { Vec2(x: 5.0, y: 100.0) }))
            colliders.insert(wall, Collider2D())
            bodies.insert(wall, RigidBody2D(bodyType: BodyType.Static))
            let hits = PhysicsWorld(gravity: Vec2(), maxSubSteps: 1, skin: 0.0).step(world, transforms, velocities, colliders, bodies, 100)
            @Expect(hits.size, 0)
            match (transforms.get(mover)) {
                case Some(t) => @Expect(if (vertical) { t.position.y } else { t.position.x }, 10.0)
                case None => @Expect(false)
            }
        }
    }

    @TestCase
    func movingSensorKeepsVelocityAndReportsOverlapSeparately(): Unit {
        let world = EntityWorld()
        let sensor = world.create()
        let wall = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        let colliders = ComponentStore<Collider2D>()
        let bodies = ComponentStore<RigidBody2D>()
        transforms.insert(sensor, Transform2D())
        velocities.insert(sensor, Velocity2D(value: Vec2(x: 50.0)))
        colliders.insert(sensor, Collider2D(kind: ColliderKind.Sensor))
        bodies.insert(sensor, RigidBody2D(gravityScale: 0.0))
        transforms.insert(wall, Transform2D(position: Vec2(x: 5.0)))
        colliders.insert(wall, Collider2D())
        bodies.insert(wall, RigidBody2D(bodyType: BodyType.Static))
        let physics = PhysicsWorld(gravity: Vec2(), maxSubSteps: 1, skin: 0.0)
        @Expect(physics.step(world, transforms, velocities, colliders, bodies, 100).size, 0)
        match (transforms.get(sensor)) { case Some(t) => @Expect(t.position.x, 5.0); case None => @Expect(false) }
        match (velocities.get(sensor)) { case Some(v) => @Expect(v.value.x, 50.0); case None => @Expect(false) }
        let overlaps = physics.overlaps(world, transforms, colliders, sensor)
        @Assert(overlaps.size, 1)
        @Expect(overlaps[0].other, wall)
    }

    @TestCase
    func entityWorldAndGenericStoresWork(): Unit {
        let world = EntityWorld()
        let player = world.create()
        let wall = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        transforms.insert(player, Transform2D(position: Vec2(x: 1.0, y: 2.0)))
        transforms.insert(wall, Transform2D(position: Vec2(x: 3.0, y: 2.0)))
        velocities.insert(player, Velocity2D(value: Vec2(x: 4.0, y: 0.0)))
        @Expect(world.isAlive(player))
        @Expect(transforms.size(), 2)
        match (velocities.get(player)) {
            case Some(v) => @Expect(v.value.x, 4.0)
            case None => @Expect(false)
        }
        @Expect(world.destroy(wall))
        transforms.clearDead(world)
        @Expect(transforms.size(), 1)
        @Expect(!transforms.has(wall))
    }

    @TestCase
    func gameInputTracksPressedJustPressedAndAxis(): Unit {
        let input = GameInputState()
        input.handle(Event.KeyDown(KeyEvent(KeyCode.Left)))
        @Expect(input.pressed(KeyCode.Left))
        @Expect(input.justPressed(KeyCode.Left))
        @Expect(input.axis(KeyCode.Left, KeyCode.Right), -1)
        input.beginFrame()
        @Expect(!input.justPressed(KeyCode.Left))
        input.handle(Event.KeyDown(KeyEvent(KeyCode.Right)))
        @Expect(input.axis(KeyCode.Left, KeyCode.Right), 0)
        input.handle(Event.KeyUp(KeyEvent(KeyCode.Left)))
        @Expect(input.axis(KeyCode.Left, KeyCode.Right), 1)
        input.handle(Event.FocusOut)
        @Expect(!input.pressed(KeyCode.Right))
    }

    @TestCase
    func sweptAabbStopsFastBodyAtWall(): Unit {
        let world = EntityWorld()
        let player = world.create()
        let wall = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        let colliders = ComponentStore<Collider2D>()
        let bodies = ComponentStore<RigidBody2D>()
        transforms.insert(player, Transform2D(position: Vec2(x: 0.0, y: 0.0), size: Vec2(x: 1.0, y: 1.0)))
        velocities.insert(player, Velocity2D(value: Vec2(x: 100.0, y: 0.0)))
        colliders.insert(player, Collider2D(bounds: Aabb(width: 1.0, height: 1.0)))
        bodies.insert(player, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 0.0))
        transforms.insert(wall, Transform2D(position: Vec2(x: 5.0, y: 0.0), size: Vec2(x: 1.0, y: 3.0)))
        colliders.insert(wall, Collider2D(bounds: Aabb(width: 1.0, height: 3.0)))
        bodies.insert(wall, RigidBody2D(bodyType: BodyType.Static))
        let physics = PhysicsWorld(gravity: Vec2(), maxSubSteps: 1, skin: 0.0)
        let hits = physics.step(world, transforms, velocities, colliders, bodies, 100)
        @Expect(hits.size, 1)
        match (transforms.get(player)) {
            case Some(t) => @Expect(t.position.x, 4.0)
            case None => @Expect(false)
        }
        match (velocities.get(player)) {
            case Some(v) => @Expect(v.value.x, 0.0)
            case None => @Expect(false)
        }
        @Expect(hits[0].normal.x, -1.0)
    }

    @TestCase
    func gravityDampingAndStaticBodiesBehave(): Unit {
        let world = EntityWorld()
        let body = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        let colliders = ComponentStore<Collider2D>()
        let bodies = ComponentStore<RigidBody2D>()
        transforms.insert(body, Transform2D(position: Vec2(x: 0.0, y: 0.0)))
        velocities.insert(body, Velocity2D())
        colliders.insert(body, Collider2D())
        bodies.insert(body, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 1.0, damping: 0.0))
        let physics = PhysicsWorld(gravity: Vec2(x: 0.0, y: 10.0), maxSubSteps: 1)
        _ = physics.step(world, transforms, velocities, colliders, bodies, 100)
        match (velocities.get(body)) {
            case Some(v) => @Expect(v.value.y, 1.0)
            case None => @Expect(false)
        }
    }

    @TestCase
    func tileMapCreatesSolidCollidersAndBlocksMotion(): Unit {
        let world = EntityWorld()
        let transforms = ComponentStore<Transform2D>()
        let colliders = ComponentStore<Collider2D>()
        let map = TileMap(["..#G", "###S"])
        let solids = map.addStaticColliders(world, transforms, colliders)
        @Expect(solids.size, 4)
        @Expect(map.isSolid(2, 0))
        @Expect(!map.isSolid(1, 0))
        @Expect(map.tileAt(3, 0), "G")
        @Expect(map.tileAt(99, 0), "")
        let gems = map.find("G")
        @Expect(gems.size, 1)
        @Expect(gems[0], TileMarker(3, 0, "G"))
        let markers = map.findAny(["G", "S"])
        @Expect(markers.size, 2)
    }

    @TestCase
    func spriteRendererClipsTransparencyAndCamera(): Unit {
        let world = EntityWorld()
        let entity = world.create()
        let transforms = ComponentStore<Transform2D>()
        let sprites = ComponentStore<Sprite2D>()
        transforms.insert(entity, Transform2D(position: Vec2(x: 2.0, y: 1.0)))
        sprites.insert(entity, Sprite2D(["@ @", "###"], style: Style(fg: Color.Green), transparent: " "))
        let buffer = Buffer(Rect(0, 0, 6, 3))
        SpriteRenderer().render(buffer.area, buffer, transforms, sprites, camera: Camera2D(viewport: buffer.area))
        @Expect(buffer.getCell(2, 1).symbol, "@")
        @Expect(buffer.getCell(3, 1).symbol, " ")
        @Expect(buffer.getCell(4, 2).symbol, "#")
        @Expect(buffer.getCell(2, 1).style, Style(fg: Color.Green))
    }

    @TestCase
    func physicsReportsSensorOverlapsWithoutBlockingMotion(): Unit {
        let world = EntityWorld()
        let player = world.create()
        let gem = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        let colliders = ComponentStore<Collider2D>()
        let bodies = ComponentStore<RigidBody2D>()
        transforms.insert(player, Transform2D(position: Vec2(x: 0.0, y: 0.0), size: Vec2(x: 1.0, y: 1.0)))
        velocities.insert(player, Velocity2D(value: Vec2(x: 20.0, y: 0.0)))
        colliders.insert(player, Collider2D(bounds: Aabb(width: 1.0, height: 1.0), layer: 1, mask: 3))
        bodies.insert(player, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 0.0))
        transforms.insert(gem, Transform2D(position: Vec2(x: 1.0, y: 0.0), size: Vec2(x: 1.0, y: 1.0)))
        colliders.insert(gem, Collider2D(kind: ColliderKind.Sensor, bounds: Aabb(width: 1.0, height: 1.0), layer: 2, mask: 1))
        let physics = PhysicsWorld(gravity: Vec2(), maxSubSteps: 1, skin: 0.0)
        let hits = physics.step(world, transforms, velocities, colliders, bodies, 100)
        @Expect(hits.size, 0)
        match (transforms.get(player)) {
            case Some(t) => @Expect(t.position.x, 2.0)
            case None => @Expect(false)
        }
        let overlaps = physics.overlaps(world, transforms, colliders, player)
        @Expect(overlaps.size, 0)
        _ = transforms.set(player, Transform2D(position: Vec2(x: 1.0, y: 0.0), size: Vec2(x: 1.0, y: 1.0)))
        let current = physics.overlaps(world, transforms, colliders, player)
        @Expect(current.size, 1)
        @Expect(current[0].other, gem)
    }

    @TestCase
    func spriteAnimationAdvancesAndStops(): Unit {
        let first = Sprite2D(["A"], style: Style(fg: Color.Red))
        let second = Sprite2D(["B"], style: Style(fg: Color.Blue))
        let looping = SpriteAnimation([
            SpriteFrame(first, durationMillis: 10),
            SpriteFrame(second, durationMillis: 10)
        ])
        @Expect(looping.current().rows[0], "A")
        @Expect(looping.advance(10).rows[0], "B")
        @Expect(looping.advance(10).rows[0], "A")

        let once = SpriteAnimation([
            SpriteFrame(first, durationMillis: 10),
            SpriteFrame(second, durationMillis: 10)
        ], loop: false)
        @Expect(once.advance(40).rows[0], "B")
        once.reset()
        @Expect(once.current().rows[0], "A")
    }
}
