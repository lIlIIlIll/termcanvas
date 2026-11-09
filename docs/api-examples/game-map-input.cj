package cjtui_api_example

import core.*
import game.*

main(): Int64 {
    let input = GameInputState()
    input.handle(Event.KeyDown(KeyEvent(KeyCode.Right)))
    if (!input.pressed(KeyCode.Right) || !input.justPressed(KeyCode.Right) || input.axis(KeyCode.Left, KeyCode.Right) != 1) {
        throw IllegalStateException("game input failed")
    }
    input.beginFrame()
    if (input.justPressed(KeyCode.Right) || !input.pressed(KeyCode.Right)) { throw IllegalStateException("input frame failed") }
    let map = TileMap(["#P", " ."])
    let markers = map.find("P")
    if (map.width != 2 || map.height != 2 || !map.isSolid(0, 0) || map.tileAt(1, 1) != "." ||
        markers.size != 1 || markers[0] != TileMarker(1, 0, "P") || map.findAny(["P", "."]).size != 2) {
        throw IllegalStateException("tile lookup failed")
    }
    let world = EntityWorld()
    let transforms = ComponentStore<Transform2D>()
    let colliders = ComponentStore<Collider2D>()
    if (map.addStaticColliders(world, transforms, colliders).size != 1) { throw IllegalStateException("collider creation failed") }
    let buffer = Buffer(Rect(0, 0, 2, 2))
    map.render(buffer.area, buffer)
    map.render(buffer.area, buffer, style: Style.default())
    if (buffer.getCell(0, 0).symbol != "#") { throw IllegalStateException("map rendering failed") }
    return 0
}
