# Selection, pointer interaction, and modal focus

These helpers keep the existing application-owned update/render model. They do not
install an event router, own a component lifecycle, execute commands, or render a
retained tree. The application chooses which visible surface may receive input.

## Selection viewports

`Menu`, `CommandPalette`, `Select`, `Dropdown`, `RadioGroup`, and `MultiSelect`
maintain a public `offset` in source-item indices (filtered-result indices for a
palette). Render clamps the selection and offset against the current content
height, keeping the selected item visible after a resize. `Up`, `Down`, `Home`,
`End`, `PageUp`, and `PageDown` navigate; page size is the most recently rendered
content height, excluding borders, titles, and the palette query/dropdown header.
Before the first render, page size is one row.

A palette query change resets the selected filtered-result row and offset to zero.
Rendering or accepting a choice also validates directly assigned query/selection
values. `MultiSelect.selectedIndices()` and selection return values still identify
the complete original item list, independent of the visible window.

Keep a widget instance or its explicit state alive when its scroll position should
survive updates. Recreating a widget preserves only values supplied by the caller.

## Local mouse handling

The ordinary control `handleMouse(mouse, area)` helpers receive the same rectangle
used to render that control. Framed controls hit-test their inner content; menus,
palettes, dropdowns, and tables also exclude headings from row selection. Disabled
buttons, checkboxes, and radio groups ignore activation. Left-button down activates
a button/choice; release does not activate it again. Wheel input changes selection
by one item and keeps it visible. Return values match the corresponding keyboard
helpers: action/value controls return an optional choice, while boolean controls
report whether they handled the input. Wheel navigation need not return a choice.

`List` and `Table` mouse helpers update the `ListState`/`TableState` supplied at
construction. A display-only instance without a supplied state ignores mouse
selection. `Input` maps a content click to the visible text cursor. `Tabs`,
`MenuBar`, `ColorPicker`, and `Dialog` expose their own geometry-aware mouse helpers.

The shared functions are deliberately small:

- `widgetHitTest(mouse, area)` tests geometry only; it does not imply activation.
- `widgetRowAt(mouse, area, offset, total)` maps a hit to a bounded original row.
- `mouseScrollDelta(mouse)` returns -1/1 for wheel up/down, otherwise zero.

Route only to the active/topmost surface. For example, an open confirmation dialog
consumes the application's pointer branch even if the click is outside its buttons;
that click must not fall through to the form beneath it. `form_studio` exercises
this policy through its real application update method.

## Owned pointer drags

Keep one application-owned `PointerCapture` shared by controls that can drag.
`begin(owner, mouse, area, value: ...)` accepts a left-button press within the area
only when no owner holds capture. It retains the press position and an initial
scalar value, useful for scrollbar offsets and column widths. Owners are nonempty
application-chosen unique strings.

`Scrollbar.handleMouse(mouse, area, scrollState, capture, owner)` updates a supplied
`ScrollState`. Its track is the last column of the render area. A thumb drag stays
owned when the pointer leaves the track or moves over another control; the owner
must still receive drag and release events. A competing control cannot acquire the
same capture. Release uses `capture.release(owner, mouse)`, and application focus
loss, control removal, or abandoned gestures call `capture.cancel()`.

`Scrollable.handleMouse(mouse, area, capture, owner)` combines content-wheel
scrolling and its scrollbar using the same supplied `ScrollState` as rendering.
Applications must route captured drag/up events to the owner before ordinary hit
selection, rather than testing only the latest pointer position.

## Application-owned modal focus and shortcut priority

`ModalFocusState(baseFocus, keymap: baseKeys)` holds a small stack of focus IDs and
key maps. It does not hold widgets. `open(id, focusIds, keymap: ...)` creates a new
active scope; `close()` removes only the top scope. The lower `FocusManager` is
left intact while covered, and opening saves its focused ID. Closing restores
that saved ID if it still exists and is enabled; otherwise it keeps the remaining
valid focus, including adjustments made by removing a no-longer-present control.

`focus()` returns the currently active focus manager. `handle(key)` consumes
Tab/Shift-Tab and, while a modal is open, Esc. Esc closes only the top scope.
`actionFor(key)` searches only the active scope's map; a missing modal binding does
not fall back to a background shortcut. Empty scopes still consume Tab. Duplicate
modal IDs and empty IDs are rejected.

The application's update order is explicit:

1. Handle truly global application policy, such as Ctrl-C, if desired.
2. Call `modal.handle(key)` and return when it consumes Tab/Esc.
3. If `modal.active()` is present, route to that modal's controls/key map and return
   even when no modal control recognizes the key.
4. Otherwise route to the base key map and focused application control.

`handle()` returning false does **not** authorize background delivery: it only means
that the key was not a focus-navigation/Esc key. Check `active()` before routing
other keys, pointer input, and paste. This keeps shortcut precedence visible in the
single application update function rather than hiding it in a second event loop.

Two real examples use this policy:

- `form_studio`: F2/Save opens confirmation; Tab remains among Cancel/Save; F1 opens
  nested help; Esc returns one layer; background edits, paste, and clicks stay
  blocked; confirming restores form focus.
- `assistant_console`: approval owns its two buttons and blocks composer input and
  background F2 delivery; closing restores composer focus. This uses the same
  small policy as the ordinary form, without a specialized agent runtime.

Regression suites are `InteractionViewportTest` and `InteractionPolicyTest`, plus
both examples' application-update tests. They cover filtered source values,
resize/paging, border/disabled hits, shared selection state, capture ownership and
out-of-region release, nested focus, shortcut isolation, and valid focus restore.
