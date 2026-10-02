package game

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003GameTest {
    @TestCase
    func physicsPersistsImplicitZeroVelocityBeforeTheNextStep(): Unit {
        let world = EntityWorld()
        let entity = world.create()
        let transforms = ComponentStore<Transform2D>()
        let velocities = ComponentStore<Velocity2D>()
        let colliders = ComponentStore<Collider2D>()
        let bodies = ComponentStore<RigidBody2D>()
        transforms.insert(entity, Transform2D())
        bodies.insert(entity, RigidBody2D())
        let physics = PhysicsWorld(gravity: Vec2(y: 10.0), maxSubSteps: 1)
        _ = physics.step(world, transforms, velocities, colliders, bodies, 100)
        _ = physics.step(world, transforms, velocities, colliders, bodies, 100)
        @Expect(velocities.has(entity))
        if (let Some(velocity) <- velocities.get(entity)) { @Expect(velocity.value.y, 2.0) }
        @Expect(transforms.get(entity).getOrThrow().position.y > 0.29)
    }

    @TestCase
    func tileMapUsesTheSameGraphemeColumnsForWidthLookupAndRender(): Unit {
        let text = "e\u{301}#"
        let map = TileMap([text])
        @Expect(map.width, 2)
        @Expect(map.tileAt(0, 0), "e\u{301}")
        @Expect(map.tileAt(1, 0), "#")
        @Assert(map.find("#").size, 1)
        @Expect(map.find("#")[0].x, 1)
        let buffer = Buffer(Rect(0, 0, 3, 1))
        map.render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "e\u{301}")
        @Expect(buffer.getCell(1, 0).symbol, "#")
    }

    @TestCase
    func spriteRendererKeepsJoinedEmojiAndFollowingColumnsIntact(): Unit {
        let buffer = Buffer(Rect(0, 0, 6, 1))
        SpriteRenderer().drawSprite(Canvas(buffer, buffer.area), Transform2D(),
            Sprite2D(["👩‍💻x"]), Camera2D(viewport: buffer.area))
        @Expect(buffer.getCell(0, 0).symbol, "👩‍💻")
        @Expect(buffer.getCell(2, 0).symbol, "x")
    }
}
