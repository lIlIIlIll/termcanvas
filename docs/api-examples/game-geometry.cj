package cjtui_api_example

import game.*

main(): Int64 {
    let position = Vec2(x: 2.0, y: 3.0)
    let velocity = Velocity2D(value: Vec2(x: 1.0, y: 0.0))
    let moved = position.plus(velocity.value.scale(2.0))
    if (moved != Vec2(x: 4.0, y: 3.0) || moved.minus(position).x != 2.0) {
        throw IllegalStateException("vector arithmetic failed")
    }
    let transform = Transform2D(position: position, size: Vec2(x: 3.0, y: 2.0))
    let bounds = transform.bounds()
    let other = Aabb(x: 4.0, y: 4.0, width: 2.0, height: 2.0)
    if (bounds.right != 5.0 || bounds.bottom != 5.0 || !bounds.overlaps(other) ||
        bounds.moved(Vec2(x: 1.0)).x != 3.0 || bounds == other) {
        throw IllegalStateException("bounds failed")
    }
    return 0
}
