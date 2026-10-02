# Text editing in 0.0.1

`TextArea` and `TextBuffer` use `EditableTextModel`. Their default model is
`PieceTableTextModel`, a persistent AVL piece rope with a newline index for
each immutable source. Applications can supply a different model without
replacing the editor's keyboard, selection, rendering, or Vim behavior.

```cangjie
let model = PieceTableTextModel(text: "first line\nsecond line")
let editor = TextArea(model: Some(model), lineNumbers: true)
let secondLine = editor.textModel.line(1)
let excerpt = editor.textModel.slice(0, 5)
```

An explicit `value` supplied alongside `model` is ignored: the supplied model
is the source of truth. Reading `TextArea.value` or `TextBuffer.text()` produces
a whole-document string. Those convenience APIs remain useful for small
inputs, explicit export, and saving. A viewport should use `line`, `lineStart`,
`lineForOffset`, and `slice` instead. `setValue` / `setText` load a new document
and clear history; assigning the `value` property is an ordinary undoable edit.

## Coordinates and interaction

Model offsets, selections, completion ranges, decoration ranges, and
`TextPosition.column` are UTF-8 **byte** positions. They are not terminal cell
columns. Edits clamp backward to a UTF-8 rune boundary; reversed ranges are
normalized. LF separates lines, a final LF adds an empty line, and `line()`
excludes the LF. A CR in a CRLF pair remains part of that line's text.

Editor movement and hit testing use the existing Unicode grapheme and cell
width rules. Left/Right and deletion step over a grapheme. Shift extends a
selection; Ctrl+Shift+Left/Right selects words; Ctrl+Home/End targets the
whole document. Up/Down retain each caret's preferred display column across
short lines. Home/End or horizontal movement starts a new preferred column.
PageUp/PageDown use the last rendered or measured content viewport height,
excluding a block border. Before the first layout, this height is one row.

The horizontal viewport follows the primary caret and applies the same offset
to drawing, selection, mouse hit testing, and extra carets. A wide grapheme
that straddles a horizontal clip edge is left blank rather than split.
Click places the primary caret; Shift+click extends its selection; Alt+click
adds a caret; left-button drag extends the selection. Extra carets outside the
viewport are omitted from `cursorPositions`.

## History and model ownership

The model exposes `beginUndoGroup` / `endUndoGroup` for nested transactions.
Only the outermost end commits a history entry. Undo or redo seals an open
group. No-op replacements preserve revision and redo; each effective edit,
undo, and redo advances the revision. `clearHistory` discards undo/redo roots.

`TextArea` uses those same model transactions for multi-caret changes and Vim
insertion sessions, retaining cursor/selection snapshots alongside model
history. A multi-caret edit is one undo step. External changes through the
injected model are observed on the next editor operation: cursor offsets are
clamped, pending completions and editor-owned decoration caches are invalidated,
and model history remains authoritative. A model should have one active editor
owner; simultaneous edits from several views need application coordination.

## Revisioned decorations

Existing `setDecorations` arrays remain supported. A `TextDecorationProvider`
reports its revision and answers half-open byte-range queries for visible
lines. Results from a different revision are ignored. `onEdit` receives the
old range, inserted byte count, and before/after revisions; a provider may
translate safe ranges or mark its own parse results stale.

For asynchronous parsing, return `TextDecorationUpdate` to the application
and apply it in update, not from a worker mutating the editor:

```cangjie
let revision = editor.editRevision()
let end = editor.textModel.line(0).size
let result = TextDecorationUpdate(revision, 0, end,
    [TextDecoration(0, end, Style(fg: Color.Cyan))])
let accepted = editor.applyDecorationUpdate("syntax", result)
```

`applyDecorationUpdate` rejects stale revisions and ranges beyond the model.
Each named layer maintains a `TextDecorationStore`. Overlapping updates
replace affected cache chunks; edits invalidate overlapping chunks and
translate later chunks. Undo, redo, document load, and an unobserved external
edit clear editor-owned stores. A provider owns syntax-state propagation:
when a multiline lexical state changes, it must invalidate/reparse the
additional affected ranges rather than assume byte translation is sufficient.

Style order is the built-in Markdown line style (when enabled and no legacy
array is supplied), legacy array decorations, external providers in registration
order, named stores in creation order, and selection last. Styles are patched
in that order. A decoration intersecting part of a grapheme styles the whole
grapheme; combining marks and joined emoji retain one display unit.

## Work and memory limits

Initial loading/indexing is O(N). Editing k inserted bytes uses O(k + log P +
log L) work, where P is the piece count and L the newline count of a source.
Line lookup traverses O(log P) tree nodes and binary searches source newline
indexes as needed. Undo/redo retain and restore roots; they do not copy the
document. `metrics()` reports deterministic node visits, bytes scanned/copied,
materializations, and current tree size/height for regression checks.

Costs still follow the requested data. Returning a whole document or a very
long line must copy that output. Cell-column computation and grapheme movement
inspect the relevant line; this is not a horizontally virtualized megabyte-line
editor. Whole-document search and the legacy completion request's `value`
materialize the document explicitly. The folded visible-line map currently
rebuilds with document line count. Decoration queries locate chunks with a
binary search; edit translation visits cached chunks. These limits are
separate from local model splicing and ordinary unfolded viewport rendering.

Persistent histories share sources. Deleting most of a source can keep its
original storage alive while a surviving piece or history root references it.
Clearing history releases old roots but does not compact live sources. A
caller requiring compaction can create a replacement model at an explicit
checkpoint; the editor does not hide a whole-document rebuild in a keypress.
