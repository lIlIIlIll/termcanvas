package cjtui_api_example

import core.*

main(): Int64 {
    let keys = [KeyCode.Char(r'a'), KeyCode.CtrlC, KeyCode.Esc, KeyCode.Tab, KeyCode.BackTab,
        KeyCode.Enter, KeyCode.Backspace, KeyCode.Delete, KeyCode.Insert, KeyCode.Up, KeyCode.Down,
        KeyCode.Left, KeyCode.Right, KeyCode.Home, KeyCode.End, KeyCode.PageUp, KeyCode.PageDown, KeyCode.F(2)]
    let protocols = [KeyProtocol.Basic, KeyProtocol.ModifyOtherKeys, KeyProtocol.Kitty]
    let modifiers = KeyModifier(shift: true, alt: true, ctrl: true, superKey: true, meta: true,
        hyper: true, capsLock: true, numLock: true)
    let decoded = KeyModifier.fromCsiParam(8)
    if (keys.size != 18 || protocols.size != 3 || !modifiers.shift || !modifiers.alt || !modifiers.ctrl ||
        !modifiers.superKey || !modifiers.meta || !modifiers.hyper || !modifiers.capsLock || !modifiers.numLock ||
        decoded == KeyModifier.none() || !(decoded != modifiers)) { throw IllegalStateException("incorrect key modifiers") }
    let key = KeyEvent(keys[0], modifiers: modifiers, text: "a", protocol: KeyProtocol.Kitty, nativeRepeat: true)
    let buttons = [MouseButton.Left, MouseButton.Middle, MouseButton.Right, MouseButton.WheelUp,
        MouseButton.WheelDown, MouseButton.None]
    let kinds = [MouseKind.Down, MouseKind.Up, MouseKind.Drag, MouseKind.Move, MouseKind.Scroll]
    let mouse = MouseEvent(MouseKind.Down, MouseButton.Left, 3, 4, modifiers: modifiers)
    match ((key.code, key.protocol, mouse.kind, mouse.button)) {
        case (KeyCode.Char(r'a'), KeyProtocol.Kitty, MouseKind.Down, MouseButton.Left) => ()
        case _ => throw IllegalStateException("incorrect input event")
    }
    if (key.modifiers != modifiers || key.text.getOrThrow() != "a" || !key.nativeRepeat ||
        buttons.size != 6 || kinds.size != 5 || mouse.x != 3 || mouse.y != 4 || mouse.modifiers != modifiers) {
        throw IllegalStateException("incorrect event fields")
    }
    return 0
}
