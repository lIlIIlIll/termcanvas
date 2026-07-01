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

`MouseEvent` supports down, up, drag, move, scroll, modifiers, and terminal coordinates. Focus events are emitted when focus tracking is enabled by `TerminalSession`/`App`.

`KeyMap` maps one or more `KeyEvent` values to action names. `HelpView` can render those bindings.

Widgets with `handle` methods consume relevant `KeyEvent` values and return `HandleResult`. Use this pattern with `FocusManager` or `EventRouter.handleResult()` to route events to the focused widget while preserving consumed/ignored status and optional commands.
