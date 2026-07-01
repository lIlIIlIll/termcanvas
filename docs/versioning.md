# Versioning And Compatibility

`cjtui` follows a conservative pre-1.0 compatibility policy. Current packages use `0.1.x` versioning while public APIs are still being tightened by real applications. Breaking changes are allowed before 1.0 when they remove accidental API shape, clarify ownership boundaries, or keep the public surface small enough to maintain.

Stable surface:

- Core data types: `Buffer`, `Cell`, `Style`, `Color`, `Modifier`, `Rect`, `Position`.
- Runtime basics: `App`, `ControlFlow`, `UpdateResult`, `HandleResult`, `Command.Message`, `Command.Batch`, `Command.Quit`.
- Testing basics: `TestBackend`, `EventScript`, `EventScenario`.
- Common widgets: `Block`, `Paragraph`, `Input`, `TextArea`, `DocumentView`, `List`, `Table`, `FilePicker`.
- Rich document model: `RichSpan`, `DocumentLine`, `Document`, `DocumentTheme`, `DocumentViewState`.

Experimental surface:

- Async task runtime details beyond `Command.AsyncTask`, `Command.AsyncExec`, and async completion events.
- Platform drivers other than Linux/glibc.
- DOM/CSS retained-tree APIs beyond the documented `ViewNode` and `StyleSheet` entry points.
- PTY process integration details.
- Terminal media protocol adapters.
- Game extension internals beyond small helper types used by examples.
- Extension package APIs that adapt external content formats, except for documented conversion entry points.
- Advanced editor behaviors that may change as more real apps use them.

Compatibility rules:

- Prefer additive changes for public APIs.
- Keep legacy constructors and enum variants when practical.
- Breaking cleanup is allowed before 1.0, but the change must be intentional, documented, and covered by public behavior tests where practical.
- The `Component.handle(event): HandleResult` shape is a deliberate 0.x breaking cleanup so event propagation and command production are explicit before 1.0.
- Treat `TerminalDriver` as the portability boundary for terminal mode, size, and capability behavior; do not require widgets or app tests to depend on Linux-only terminal internals.
- If behavior changes, document it in `docs/limitations.md` or the relevant feature doc.
- Do not move Markdown parsing into core; keep parser packages and adapters separate.
- New examples should build through `scripts/build_examples.sh`.
- Update `docs/api-index.txt` whenever public symbols are added, moved, or removed.
- Keep public symbol moves source-compatible by preserving package names and exported identifiers.

Release gate:

```bash
scripts/release_gate.sh
```

`scripts/run_regression_matrix.sh` delegates to the same release gate for compatibility with older local workflows. A release is not ready if the gate fails.
