package cjtui_api_example

import core.*
import game.*

main(): Int64 {
    let first = Sprite2D(["@"], transparent: " ")
    let second = Sprite2D(["*"])
    let frame = SpriteFrame(first, durationMillis: 10)
    let animation = SpriteAnimation([frame, SpriteFrame(second, durationMillis: 10)])
    if (animation.current().rows[0] != "@" || animation.advance(10).rows[0] != "*") {
        throw IllegalStateException("sprite animation failed")
    }
    animation.reset()
    if (animation.current().rows[0] != "@" || frame.durationMillis != 10 || frame.sprite.transparent != " ") {
        throw IllegalStateException("sprite reset failed")
    }
    let buffer = Buffer(Rect(0, 0, 10, 2))
    let world = EntityWorld()
    let entity = world.create()
    let transforms = ComponentStore<Transform2D>()
    let sprites = ComponentStore<Sprite2D>()
    transforms.insert(entity, Transform2D(position: Vec2(x: 1.0, y: 0.0)))
    sprites.insert(entity, first)
    let camera = Camera2D(viewport: buffer.area)
    let renderer = SpriteRenderer()
    renderer.render(buffer.area, buffer, transforms, sprites, camera: camera)
    renderer.drawSprite(Canvas(buffer, buffer.area), Transform2D(position: Vec2(x: 2.0)), second, camera)
    if (buffer.getCell(1, 0).symbol != "@" || buffer.getCell(2, 0).symbol != "*") {
        throw IllegalStateException("sprite drawing failed")
    }
    return 0
}
