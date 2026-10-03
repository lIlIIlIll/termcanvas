# Markdown Studio

`markdown_studio` opens one UTF-8 Markdown file, edits it with the default
`PieceTableTextModel`, and shows its preview and outline. Running it without a
file starts the original unsaved demonstration document.

From the repository root:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run -- /absolute/path/note.md

CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run -- --vim /absolute/path/note.md
```

The application accepts:

```text
markdown_studio [--vim] [--syntax-config PATH] [--osc52] [--] [FILE]
```

`--syntax-config=PATH` is also supported. A second `--` passed to the application
ends option parsing, allowing a file name such as `-draft.md`. Relative document
paths are resolved against the application's working directory; use an absolute
path when launching through `cjpm` from another directory.

A missing file starts an empty document and is created on its first successful
save. Its parent directory must already exist. Directories, symbolic links
(including dangling links), and invalid UTF-8 are rejected before the interactive
application starts. An opening failure prints a diagnostic and exits with code
2. It never replaces unreadable input with an empty buffer.

## Editing and saving

| Key | Action |
| --- | --- |
| Ctrl-S or F4 | Save to the opened path. |
| F5 | Copy the current selection. |
| F6 or Ctrl-X | Cut the selection after the clipboard write succeeds. |
| F7 or Ctrl-V | Paste after the clipboard read succeeds. |
| Ctrl-Shift-C | Copy, when the terminal delivers this key to the application. |
| Ctrl-C | Quit; if a file has unsaved edits, show a save/discard prompt. |
| Ctrl-Q, then Ctrl-Q | Explicitly discard unsaved changes and quit. |

The file name and `*` dirty marker appear in the status area. Successful save
clears the marker; failure leaves the editor content and dirty state intact and
shows the error. Saving retains editor undo history. The marker tracks edits
since the saved revision; an undo back to identical content can still show `*`
until another successful save.

The discard confirmation is canceled by another key or an edit. Holding Ctrl-Q
does not confirm discard through key-repeat events. The demonstration document
has no destination: save reports that a file path is required, and its existing
quit behavior remains unchanged.

In the default mode, Esc opens command mode: `e` returns to editing, `p` shows
preview navigation, `b` toggles bold, and `c` requests completion. With `--vim`,
use `i` for insert mode, Esc for normal mode, F2 to switch preview/editor, and F3
for completion while inserting. The save and clipboard keys work with both
editing behaviors.

## Clipboard behavior

The application uses `detectClipboard()` and displays the selected backend.
Native backends depend on the platform and available session tools; see
[clipboard.md](clipboard.md). A failed or unsupported copy does not delete a
selection. A failed or unsupported read inserts nothing. Backend errors remain
visible in the status area.

`--osc52` enables the optional terminal-output fallback, including remote SSH
sessions. OSC 52 is write-only here: the status area explicitly says `no paste`.
A successful copy means the sequence was emitted, not that the remote terminal
acknowledged or accepted it. Use terminal bracketed paste for input in that
case. OSC 52 fallback is disabled unless this option is supplied.

## File safety and boundaries

Save creates an exclusive temporary file in the destination directory, writes
the requested text, flushes and closes it, then renames it over the destination.
The original path is never opened with a truncating write mode. Write, flush,
close, conflict, or rename failures preserve the original target before commit;
temporary files are removed where cleanup is possible. A failed operation does
not clear the dirty marker.

The session retains the content last loaded or saved. It rereads and compares
the destination both before writing and immediately before replacement. An
external edit, deletion, or creation at a previously absent path causes a
conflict instead of an overwrite. Resolve the conflict outside the application
and reopen the document; there is no automatic merge or force-save operation.

These checks are not a filesystem compare-and-swap operation. An unrelated
writer can still change the path between the final check and rename. This
example does not provide cross-process locking, directory `fsync` durability
across power loss, or preservation of the original inode, hard-link identity,
ACLs, extended attributes, and complete permission bits. Replacement uses the
permissions of the newly created temporary file. Coordinate concurrent writers
and use a version-controlled working copy when those properties matter.

The editor's local text edits and undo use the persistent piece model. The
Markdown preview and outline still materialize and parse the complete document
when its revision changes. Loading, explicit saving, clipboard transfer, and
preview parsing are proportional to their input/output size; this example does
not claim a fully incremental Markdown pipeline.
