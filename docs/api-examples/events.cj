package cjtui_api_example

import core.*

main(): Int64 {
    let parser = EventParser()
    let input = parser.push([b'a'])
    if (input.size != 1) { throw IllegalStateException("event parser failed") }
    let state = InputState(releaseAfterMillis: 100)
    let key = KeyEvent(KeyCode.Char(r'a'))
    _ = state.handle(Event.KeyDown(key))
    if (!state.isPressed(key) || state.advance(20).size != 1) { throw IllegalStateException("key state failed") }
    _ = state.handle(Event.FocusOut)
    if (state.isPressed(key)) { throw IllegalStateException("focus clear failed") }
    let result = Event.AsyncCompleted("job", Event.Message("done"))
    match (result) {
        case Event.AsyncCompleted(id, Event.Message(message)) => if (id != "job" || message != "done") { throw IllegalStateException("async event failed") }
        case _ => throw IllegalStateException("unexpected event")
    }
    _ = StdinInputSource()
    return 0
}
