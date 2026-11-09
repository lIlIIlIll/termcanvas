package cjtui_api_example

import core.*

class ExampleInput <: InputSource {
    private var read = false
    public func readAvailable(maxBytes: Int64): Array<Byte> {
        if (read || maxBytes < 1) { return [] }
        read = true
        [b'a']
    }
}

main(): Int64 {
    let parser = EventParser(inputSource: ExampleInput())
    let events = parser.readEvents()
    if (events.size != 1 || parser.lastReadBytes() != 1 || parser.hasPendingInputDrain() ||
        parser.readEvent().isSome()) { throw IllegalStateException("input read failed") }
    let key = KeyEvent(KeyCode.Char(r'a'))
    let state = InputState(releaseAfterMillis: 100)
    state.handle(Event.KeyDown(key))
    if (!state.isPressed(key) || state.pressedKeys().size != 1 || state.modifiers() != KeyModifier.none()) {
        throw IllegalStateException("key state failed")
    }
    if (state.advance(30).size != 1 || state.pressedKeys()[0].heldMillis != 30) {
        throw IllegalStateException("key duration failed")
    }
    state.clear()
    if (state.isPressed(key)) { throw IllegalStateException("key clear failed") }
    let pressed = PressedKey(key, heldMillis: -1)
    let tick = TickEvent(deltaMillis: -1, elapsedMillis: 5, frameIndex: 2, droppedFrames: 1)
    let timer = TimerEvent("refresh", elapsedMillis: 20, firedCount: 0, droppedFrames: 2)
    let modes = [TimerMode.OneShot, TimerMode.Repeating]
    let policies = [FrameMissPolicy.Drop, FrameMissPolicy.CatchUp(2)]
    if (pressed.heldMillis != 0 || tick.deltaMillis != 0 || tick.elapsedMillis != 5 || tick.frameIndex != 2 ||
        tick.droppedFrames != 1 || timer.id != "refresh" || timer.elapsedMillis != 20 || timer.firedCount != 1 ||
        timer.droppedFrames != 2 || modes.size != 2 || policies.size != 2) {
        throw IllegalStateException("timer event failed")
    }
    let escape = EventParser(inputSource: ExampleInput())
    if (escape.push([0x1b]).size != 0 || escape.flushEscAfterPolls(2).size != 0 ||
        escape.flushEsc().size != 1) { throw IllegalStateException("escape parsing failed") }
    return 0
}
