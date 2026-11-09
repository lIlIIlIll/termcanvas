package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(0, 0, 10, 5)
    let down = MouseEvent(MouseKind.Down, MouseButton.Left, 3, 2)
    let scroll = MouseEvent(MouseKind.Scroll, MouseButton.WheelDown, 3, 2)
    if (!widgetHitTest(down, area) || widgetRowAt(down, area, 4, 10).getOrThrow() != 6 ||
        mouseScrollDelta(scroll) != 1) { throw IllegalStateException("hit testing failed") }
    let capture = PointerCapture()
    if (!capture.begin("scrollbar", down, area, value: 7) || !capture.owns("scrollbar") ||
        capture.activeOwner().getOrThrow() != "scrollbar" || capture.origin().x != 3 ||
        capture.origin().y != 2 || capture.initialValue() != 7) { throw IllegalStateException("capture failed") }
    let up = MouseEvent(MouseKind.Up, MouseButton.None, 20, 20)
    if (!capture.release("scrollbar", up) || capture.activeOwner().isSome()) {
        throw IllegalStateException("capture release failed")
    }
    capture.begin("scrollbar", down, area)
    capture.cancel()
    let base = FocusManager()
    base.add("editor")
    let modal = ModalFocusState(base)
    let keys = KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.Enter)], "save")])
    if (!modal.open("save", ["cancel", "confirm"], keymap: keys) || modal.active().getOrThrow() != "save" ||
        modal.actionFor(KeyEvent(KeyCode.Enter)).getOrThrow() != "save") { throw IllegalStateException("modal open failed") }
    modal.handle(KeyEvent(KeyCode.Tab))
    if (modal.focus().current().getOrThrow() != "confirm" || modal.close().getOrThrow() != "save" ||
        modal.focus().current().getOrThrow() != "editor") { throw IllegalStateException("modal focus failed") }
    return 0
}
