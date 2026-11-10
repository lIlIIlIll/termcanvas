package cjtui_api_example

import core.*

main(): Int64 {
    let down = KeyEvent(KeyCode.Down)
    let binding = KeyBinding([KeyEvent(KeyCode.Char(r'j')), down], "down", description: "Move down")
    let map = KeyMap(bindings: [binding])
    map.add(KeyBinding([KeyEvent(KeyCode.Char(r'q'))], "quit"))
    if (!binding.matches(down) || binding.keys.size != 2 || binding.action != "down" ||
        binding.description != "Move down" || map.actionFor(down).getOrThrow() != "down" ||
        !map.actionFor(KeyEvent(KeyCode.Char(r'x'))).isNone() || map.all().size != 2) {
        throw IllegalStateException("incorrect key binding")
    }
    let buffer = Buffer(Rect(0, 0, 40, 1))
    HelpView(map, separator: " | ").render(buffer.area, buffer)
    if (buffer.getCell(0, 0).symbol != "j") { throw IllegalStateException("help did not render") }
    return 0
}
