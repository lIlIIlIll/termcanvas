# Migrating to 0.0.1

The next release is **0.0.1**. This is an explicitly authorized version reset
and breaking boundary from the previous 0.1.x development line. Pin the new
ref/version deliberately: a dependency range that accepts 0.1.x does not
automatically select 0.0.1. Historical tags and reports keep their original
version numbers; active first-party manifests are checked against `VERSION`.

The application architecture stays application-owned state → App/update →
immediate Widget rendering. Database access, language servers and model APIs
remain application or adapter responsibilities.

## Visual themes and text width

`Theme.default()` and the `Theme()` constructor now use the Indigo palette.
A partial constructor such as `Theme(accent: customAccent)` also uses Indigo
for every omitted role. Set the other roles explicitly if your application
relies on the previous defaults. An application can set its theme with
`App.setTheme`, including from its update callback. A component's
explicit theme takes precedence over its parent's theme and the application
theme. Controls that receive input before their first render can pass the
known `layoutTheme` when calculating hit targets or cursor positions.

`StyleOverride` distinguishes an omitted attribute from an explicit reset:
`Some(Color.Reset)` restores the terminal default color, and `Some(false)`
clears a modifier. `StyledWidget` applies an override to the character cells
written by a child widget; it does not restyle media images.

Text measurement, rendering, hit testing and off-screen buffers should use the
same `TextWidthOptions`. `Canvas.createSurface` creates a surface with a
snapshot of its canvas's visual context. Copying non-empty cells between
buffers with different ambiguous-width policies now raises
`IllegalArgumentException` rather than silently misaligning text. Configure a
`TerminalScreen` or `TerminalTranscript` with the intended width policy before
feeding output; changing an already populated screen requires rebuilding and
replaying its input. `TerminalScreen.render` and `TerminalView.render` reject a
target with a different width policy, including an empty target.

`TileMap` accepts `widthOptions` when constructed. Pass the same options used
by its destination buffer when game coordinates must match displayed cells.
When no style is passed, `TileMap.render` uses the buffer's active theme, or
white if there is no theme. Pass `style: Style(fg: Color.White)` to retain the
previous default foreground.

`AsciiAnimationView` also uses the active theme when its style is omitted.
To request the previous unthemed colors explicitly, pass
`style: Style(fg: Color.White)` and `pausedStyle: Style(fg: Color.Yellow)`.
Frame colors still take precedence.

`GlyphCapabilitySession` is experimental. Close an unused session explicitly;
an attached session is closed when the application exits. An unavailable or
inconclusive font probe does not establish Nerd Font support.

## Editing

`TextArea.value` is now a mutable property backed by an indexed text model.
Reading it materializes the whole text; use `textModel` for line/range access
in a viewport or on every key. `TextBuffer` and `TextArea` accept an injected
`EditableTextModel`, and default to `PieceTableTextModel`. Local edits and
undo transactions retain persistent roots instead of copying the whole text.

Keyboard navigation now honors Shift extension, vertical preferred columns,
horizontal scrolling and the most recently rendered viewport height for
PageUp/PageDown. Consumers with custom key policies should route those keys
to the editor before interpreting global shortcuts.

Existing decoration arrays remain available. Revisioned decoration providers
allow range queries and reject stale asynchronous updates. Applications still
own the parser and the source revision used to produce each decoration update.
See [text editing](text-editing.md) for coordinate, model ownership and work
boundaries, and [Markdown Studio](markdown-studio.md) for real file open/save,
dirty-close handling and external-change detection.

## Interaction and clipboard

`Input` now treats an omitted `placeholderStyle` as a theme-aware default.
An explicit `Style(fg: Color.Indexed(8))` is now used as an explicit style;
it no longer requests the theme's disabled style. Pass
`placeholderStyle: theme.disabled` to keep that foreground when using a
custom theme. The input background and focus modifiers still follow the input
state. With no explicit placeholder style, an error state uses the error style.
The original `Input.handleMouse(mouse, area)` overload remains available,
including as a `(MouseEvent, Rect) -> Bool` method reference. The overload
with `layoutTheme` lets the caller supply a theme before the first render.

Explicit `Button` state styles are now honored without adding the built-in
state modifiers. For example, passing the former default `focusedStyle` of
black on white no longer adds bold and underline automatically. Add both
modifiers to the supplied style to retain them on the label. Likewise, an
explicit disabled style no longer gains italic automatically. Omit the state
style to use the theme or built-in state cues.

Selection controls keep the selected source item inside their viewport.
Applications may call the new mouse helpers from update and hold one
`PointerCapture` owner for a drag. `ModalFocusState` describes application-owned
focus/shortcut policy; it does not create an event loop or a retained tree.
See [interaction](interaction.md) for capture, overlay and focus restoration.

`Clipboard` gains observable capability/result methods. `MemoryClipboard`
continues to work without host integration. Optional `SystemClipboard` and
`Osc52Clipboard` adapters report unavailable operations; sending an OSC 52
sequence is not an acknowledgement that a remote terminal changed its clipboard.

## Data and processes

`Table` changes the stable `headerStyle` constructor parameter from
`Style` to `?Style`, with `None` as the default. When omitted, the header uses
the active theme's heading style and preserves the surface background. Without
an active theme, it uses the previous yellow, bold header style. To retain that
style explicitly, pass `headerStyle: Style(fg: Color.Yellow, modifier: Modifier.strong())`.
Explicit styles are honored, including `Style.default()` and a background of
`Color.Reset`.

The `Table` constructor's `style` parameter also changes from `Style` to
`?Style`, with `None` as the default. When omitted, ordinary unselected rows
preserve their existing surface backgrounds. An explicit style continues to
merge with the theme's normal style when a theme is active, or is used directly
when there is no theme. Selected rows continue to use the selection style.

`VirtualTable` also accepts optional styles for ordinary, selected, active
cell, and status text. Without an explicit style, the active theme supplies
the foreground and ordinary cells retain the surface background. For an
unthemed table, pass `selectedStyle: Style(fg: Color.Black, bg: Color.White)`,
`cellStyle: Style(fg: Color.Black, bg: Color.Cyan)`, and
`statusStyle: Style(fg: Color.Indexed(8))` to request the previous styles.

The existing `Style` arguments used in direct `Input`, `Block`, `List`,
`Table`, `VirtualTable`, and `TileMap.render` calls compile with the updated
signatures in a Cangjie 1.2.0 consumer probe. This is a check of those calls,
not a complete source compatibility guarantee. Rebuild applications against
the updated library. Binary compatibility with previously compiled callers is
not established.

The existing synchronous table provider remains valid. `PagedTableModel`
separates requests from drawing: request pages in update, fetch them through
application effects, then accept only matching request/revision results. Stable
row IDs retain selection across page changes. Sorting/filtering are part of the
provider query rather than an implicit scan of remote data.

`Command.ProcessStart` and `ProcessCancel` add ordinary pipe-based streaming
commands. Output events carry separate raw stdout/stderr bytes. Optional
`Utf8StreamDecoder` instances belong to each stream. Final results distinguish
normal exit, cancellation, deadline and output-limit termination. Existing
collecting Exec commands remain available for bounded short commands.
An inherited pipe that outlives the reaped process also has a finite drain
deadline; `ProcessResult.outputComplete` distinguishes complete delivery from
an explicit drain timeout. This is not a promise to reclaim a descendant that
deliberately escapes the owned process group.

Process runtime attachment and detailed resource metrics remain experimental;
unsupported native implementations report failure explicitly. Runtime turns
now bound work and process admission, so applications must handle rejection
and termination events rather than assuming unlimited queued work.

## Downstream development and verification

The `cjtui_testing` package provides supported `TestScenario`/`TestReport`
contracts for downstream applications. Its public signatures do not expose
the core package's internal/test-only headless implementation types.

See [downstream testing](downstream-testing.md) for generating and verifying an
independent application, and [platforms](platforms.md) for the native matrix.
`scripts/native_sdk.py` provides one argv-safe command entry point on Linux,
macOS and Windows; it still requires the pinned Cangjie/cjpm 1.2.0 toolchain.

POSIX consumers now also need `cc` and `ar`. The core package's automatic
`cjpm` build hook compiles a small native launcher that keeps the entire
fork-to-exec interval outside the managed runtime. This applies to external
path dependencies as well as repository examples; no manual library-copy or
extra runtime installation is required. Windows builds require no C compiler.

API classifications and generated contracts record the exact 0.0.1 surface.
Optional platform adapters and advanced data/focus integration remain
EXPERIMENTAL; their presence is not a claim of independent production adoption.
