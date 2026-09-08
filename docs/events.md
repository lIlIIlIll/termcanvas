# Events

`EventParser` emits:

- `Event.KeyDown(KeyEvent)`
- `Event.KeyUp(KeyEvent)`
- `Event.KeyRepeat(KeyEvent)`
- `Event.KeyHeld(KeyEvent)` from `InputState`
- `Event.Mouse(MouseEvent)`
- `Event.FocusIn` / `Event.FocusOut`
- `Event.Capabilities(TerminalCapabilities)`
- `Event.Paste(String)`
- `Event.Tick(TickEvent)`
- `Event.Timer(TimerEvent)`
- `Event.Resize(Rect)`
- `Event.Unknown(Array<Byte>)`

`KeyEvent` includes the key code, modifiers, optional text, the source protocol (`Basic`, `ModifyOtherKeys`, or `Kitty`), and whether a repeat was native. Basic input recognizes common control bytes as Ctrl-modified keys while preserving Tab, Enter, and Backspace as their conventional key codes. `Esc` followed by a printable or control byte is parsed as an Alt-modified key; a bare `Esc` is emitted after the app loop's `KeyboardOptions.escDelayMillis` delay. `InputState` can be fed events to expose `pressedKeys()`, current modifiers, and held-key approximations when the terminal cannot report key-up.

`EventParser.push(bytes)` is the preferred deterministic entry point. `EventParser(inputSource: ...)` can also read available bytes from a provided `InputSource`; the default `StdinInputSource` is the only built-in source that reads from stdin.

Active terminal probe responses are intentionally consumed by `TerminalProbe` rather than emitted as `Event.Unknown` or key events. After probing, ordinary input flows through `EventParser`.

`MouseEvent` supports down, up, drag, move, scroll, modifiers, and terminal coordinates. Focus events are emitted when focus tracking is enabled by `TerminalSession`/`App`.

`TerminalSession` and `App` enable bracketed paste by default, so paste payloads arrive as `Event.Paste(String)` instead of a stream of key presses on terminals that support mode `?2004`. Mouse reporting remains opt-in through `mouse` or `mouseMove`.

`KeyMap` maps one or more `KeyEvent` values to action names. `HelpView` can render those bindings.

Widgets with `handle` methods consume relevant `KeyEvent` values and return `HandleResult`. Applications can combine this pattern with `FocusManager` in their update function while preserving consumed/ignored status and optional commands.
