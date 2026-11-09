package cjtui_api_example

import game.*

main(): Int64 {
    let world = EntityWorld()
    let player = world.create()
    let wall = world.create()
    let transforms = ComponentStore<Transform2D>()
    let velocities = ComponentStore<Velocity2D>()
    let colliders = ComponentStore<Collider2D>()
    let bodies = ComponentStore<RigidBody2D>()
    transforms.insert(player, Transform2D())
    velocities.insert(player, Velocity2D(value: Vec2(x: 100.0)))
    colliders.insert(player, Collider2D())
    bodies.insert(player, RigidBody2D(bodyType: BodyType.Dynamic, gravityScale: 0.0))
    transforms.insert(wall, Transform2D(position: Vec2(x: 5.0)))
    colliders.insert(wall, Collider2D())
    bodies.insert(wall, RigidBody2D(bodyType: BodyType.Static))
    let physics = PhysicsWorld(gravity: Vec2(), maxSubSteps: 1, skin: 0.0)
    let hits = physics.step(world, transforms, velocities, colliders, bodies, 100)
    if (hits.size != 1 || hits[0].entity != player || hits[0].other != wall || hits[0].normal.x != -1.0 ||
        transforms.get(player).getOrThrow().position.x != 4.0 || velocities.get(player).getOrThrow().value.x != 0.0) {
        throw IllegalStateException("physics collision failed")
    }
    let sensor = world.create()
    transforms.insert(sensor, Transform2D(position: Vec2(x: 5.0)))
    colliders.insert(sensor, Collider2D(kind: ColliderKind.Sensor))
    if (physics.overlaps(world, transforms, colliders, sensor).size != 1) {
        throw IllegalStateException("sensor overlap failed")
    }
    let kinematic = RigidBody2D(bodyType: BodyType.Kinematic, mass: 2.0, damping: 0.2)
    if (kinematic.mass != 2.0 || kinematic.damping != 0.2 || kinematic.gravityScale != 1.0) {
        throw IllegalStateException("body configuration failed")
    }
    return 0
}
