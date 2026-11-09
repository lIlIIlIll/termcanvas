package cjtui_api_example

import game.*

main(): Int64 {
    let world = EntityWorld()
    let player = world.create()
    let target = world.create()
    let components = ComponentStore<String>()
    components.insert(player, "player")
    components.insert(target, "target")
    if (player == target || player.value == 0 || !world.isAlive(player) || world.entities().size != 2 ||
        !components.has(player) || components.get(player).getOrThrow() != "player" || components.size() != 2) {
        throw IllegalStateException("entity creation failed")
    }
    if (!components.set(player, "hero") || components.get(player).getOrThrow() != "hero" ||
        components.entities().size != 2 || world.frame() != 0 || world.advanceFrame() != 1) {
        throw IllegalStateException("component update failed")
    }
    if (!world.destroy(target)) { throw IllegalStateException("entity destruction failed") }
    components.clearDead(world)
    if (components.has(target) || !components.remove(player) || components.size() != 0) {
        throw IllegalStateException("component cleanup failed")
    }
    return 0
}
