# Migrating to 0.0.1

The next release is **0.0.1**. This is an explicitly authorized version reset
and breaking boundary from the previous 0.1.x development line. Pin the new
ref/version deliberately: a dependency range that accepts 0.1.x does not
automatically select 0.0.1. Historical tags and reports keep their original
version numbers; active first-party manifests are checked against `VERSION`.

The application architecture stays application-owned state → App/update →
immediate Widget rendering. Database access, language servers and model APIs
remain application or adapter responsibilities.

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
macOS and Windows; it still requires the pinned Cangjie/cjpm 1.1.3 toolchain.

API classifications and generated contracts record the exact 0.0.1 surface.
Optional platform adapters and advanced data/focus integration remain
EXPERIMENTAL; their presence is not a claim of independent production adoption.
