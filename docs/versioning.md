# Versioning And Compatibility

`cjtui` follows a conservative pre-1.0 compatibility policy. Current packages use `0.1.x` versioning while public APIs are still being tightened by real applications. Breaking changes are allowed before 1.0 when they remove accidental API shape, clarify ownership boundaries, or keep the public surface small enough to maintain.

Stable surface:

- Core data types: `Buffer`, `Cell`, `Style`, `Color`, `Modifier`, `Rect`, `Position`.
- Runtime basics: `App`, `ControlFlow`, `UpdateResult`, `HandleResult`, `InputSource`, `TerminalDriver`, `Command.Message`, `Command.Batch`, `Command.Quit`, `Command.ExecArgs`, `Command.AsyncExecArgs`.
- Testing basics: `TestBackend`, `EventScript`, `EventScenario`.
- Common widgets: `Block`, `Paragraph`, `Input`, `TextArea`, `DocumentView`, `List`, `Table`, `FilePicker`.
- Rich document model: `RichSpan`, `DocumentLine`, `Document`, `DocumentTheme`, `DocumentViewState`.

Experimental surface:

- Async task runtime details beyond `Command.AsyncTask`, `Command.AsyncExecArgs`, and async completion events.
- String-splitting process helpers `Command.Exec` and `Command.AsyncExec`; these are convenience APIs for simple literal commands, not a shell-compatible command language.
- Platform drivers other than Linux/glibc.
- Component runtime layout and profiling details, including `ComponentHost`, `ComponentLayoutProvider`, datasource/poller internals, and profiler snapshots.
- DOM/CSS retained-tree APIs beyond the documented `ViewNode` and `StyleSheet` entry points.
- PTY process integration details.
- Terminal media protocol adapters.
- Game, media, diff, editor, document facade, DOM/CSS, and component profiler APIs unless a narrower document marks an entry point as stable candidate.
- Extension package APIs that adapt external content formats, except for documented conversion entry points.
- Advanced editor behaviors that may change as more real apps use them.

Test/internal exported surface:

- Fake runtimes, deterministic counters, low-level dirty helpers, benchmark guards, and public symbols exported only so release-gate tests can observe behavior.
- Snapshot/golden-test helpers are supported for repository tests, but they do not imply that every observed implementation field is an application-facing API.

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
- `docs/api-index.txt` is an exported-symbol baseline, not a stability contract. A symbol can appear in the index and still be experimental or test/internal exported.
- Keep public symbol moves source-compatible by preserving package names and exported identifiers.

Release gate:

```bash
scripts/release_gate.sh
```

`scripts/run_regression_matrix.sh` delegates to the same release gate for compatibility with older local workflows. The gate also checks that generated Unicode 17.0.0 tables are current. A release is not ready if the gate fails.
