# Versioning And Compatibility

`cjtui` follows the repository's four-tier pre-1.0 compatibility policy. Current
packages use `0.1.x` while APIs are tightened by real applications. The exact tier
of every declaration comes from `docs/api-inventory.json`; physical location in
`core`, another package, or a public declaration does not determine stability.

STABLE surface:

- Core data types: `Buffer`, `Cell`, `Style`, `Color`, `Modifier`, `Rect`, `Position`.
- Runtime basics: `App`, `ControlFlow`, `UpdateResult`, `HandleResult`, `InputSource`, `TerminalDriver`, `Command.Message`, `Command.Batch`, `Command.Quit`, `Command.Exec`, `Command.ExecArgs`, `Command.AsyncExec`, `Command.AsyncExecArgs`.
- Testing basics: `TestBackend`.
- Common widgets: `Block`, `Paragraph`, `Input`, `TextArea`, `DocumentView`, `List`, `Table`, `FilePicker`.
- Rich document model: `RichSpan`, `DocumentLine`, `Document`, `DocumentTheme`, `DocumentViewState`.
- PTY data protocol: `PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`,
  `PtyExitStatus`, and the existing `Command.Pty*` / `Event.Pty*` constructors.
- External delivery: `ExternalPort<A>`, `ExternalEnqueueResult` and its exact
  `Accepted` / `Full` / `Closed` cases, plus `App.runWithExternalPort`. The
  commitment covers positive capacity, non-blocking bounded enqueue,
  mutex-linearized successful ordering, level-visible wake, and idempotent close;
  `Accepted` does not promise eventual processing or shutdown durability.
- Low-level drawing: `Canvas` construction, both `fillRect` overloads,
  `drawText`, and `Frame.canvas`. The commitment covers translated
  terminal-cell coordinates, Canvas/Buffer clipping, styled blank fills,
  grapheme-atomic text clipping, and wide-cell-valid output.

EXPERIMENTAL surface:

- Async task runtime details beyond `Command.AsyncTask`, `Command.AsyncExecArgs`, and async completion events.
- Platform drivers other than Linux/glibc.
- PTY runtime/process attachment, readiness, and lifecycle details.
- `ExternalPort` instantaneous size, counters, wake counters, and latency
  measurement; `EventSource` readiness remains a separate runtime experiment.
- Advanced Canvas transforms and drawing conveniences, Widget bridging,
  `Surface`/composition, and `ResizePolicy`/`ViewportFit`/`SizeGuard` helpers.
- Terminal media protocol adapters.
- Game, media, and diff APIs unless a narrower document marks an entry point as stable candidate.
- Extension package APIs that adapt external content formats, except for documented conversion entry points.

INTERNAL surface:

- Runtime implementation details such as queue ownership, concrete default
  waiters/backends, and low-level scheduling helpers are contributor interfaces,
  not application compatibility promises.
- INTERNAL declarations remain in the complete machine inventory but are omitted
  from the normal user API path.

TEST_ONLY surface:

- `EventScript`, `EventScenario`, fake runtimes, deterministic counters, low-level dirty helpers, benchmark guards, and public symbols exported only so release-gate tests can observe behavior.
- Snapshot/golden-test helpers are supported for repository tests, but they do not imply that every observed implementation field is an application-facing API.

The human API map in `docs/api.md` summarizes these tiers. ADR-009 and the
generated stable/experimental contracts are the policy and structural authorities;
this page does not redefine their membership.

The former EXPERIMENTAL `editor` facade is retired. Its sixteen stable type
aliases map to the same-named STABLE `core` types; `markdownDecorations` and
`markdownLineHighlights` map to the same-named STABLE `core` functions. Its ten
advanced editor-shell aliases and their unadopted target declarations are also
retired. The stable editor path remains canonical, while multi-buffer metadata,
generic token highlighting, callback line views, search/replace presentation,
soft-wrap convenience, and the composite editor wrapper have no replacement API.

Compatibility rules:

- Prefer additive changes for public APIs.
- Keep legacy constructors and enum variants when practical.
- Breaking cleanup is allowed before 1.0, but the change must be intentional, documented, and covered by public behavior tests where practical.
- The current Phase 4E pre-1.0 consolidation window is an authorized breaking boundary. Phase 4E-4B-I used that authorization to remove `Event.ComponentTick` and its experimental payload after migrating component timers to host-localized `Event.Timer`; this authorization does not extend to other stable enum constructors.
- Phase 4E-5A-I retired the experimental `component_experimental` package after migrating its sole local example to application-owned App/update, core timers and async commands, and immediate regional rendering. No compatibility package or replacement lifecycle API remains.
- Phase 4E-5B-I retired the experimental retained ViewNode/CSS package after its
  review found no continuing adopter or hypothesis. This was a demand/adoption
  decision; core `Style` is not claimed to provide CSS selector/cascade parity.
  The package-specific `style_lab` example and orphan experimental
  `EventPropagation` surface retired, while `media_gallery` retained its direct
  media and `DocumentLine.image` paths.
- Enum constructors inherit the stability of their containing enum. The v1 source-contract extractor inventories them explicitly; removing or reordering a stable constructor is a stable contract change even when its payload type has a lower tier.
- New stable-to-nonstable dependencies are forbidden. Phase 5A-I resolved the
  five pre-existing PTY payload edges by hardening and stabilizing the exact
  runtime-free value cohort. It did not remove or rehome any stable `Command` or
  `Event` constructor and did not stabilize runtime integration.
- Before stabilization, `PtySpec` gained constructor input snapshots,
  `PtySignal.User(Int32)` was removed because it exposed raw native signal
  semantics, and `PtyExitStatus` became the exclusive `Exited(Int64)` /
  `Signaled(Int32)` enum. These were intentional source breaks to EXPERIMENTAL
  payload APIs; external users of their old shapes are unknown. ADR-011 records
  the owner decision and three-stage contract evidence.
- Phase 5C-I removed ExternalPort runtime-only methods from the language-public
  surface and separated latency capture from its constructor while the type was
  still EXPERIMENTAL. It then stabilized only the producer contract and App
  integration. Existing experimental callers of the old mixed surface may need
  migration; no compatibility shim or parallel sender/channel API was added.
- Phase 5G-I fixed the EXPERIMENTAL Canvas left-clip path to use grapheme-cluster
  byte offsets; the old Rune-length path could slice a wide UTF-8 glyph at an
  invalid byte boundary. Direct coordinate, clipping, fill, Unicode/wide-cell,
  and Frame integration tests were added before promoting only the narrow core.
  Existing advanced Canvas members and all Surface/fit/resize declarations
  remain EXPERIMENTAL; no parallel graphics abstraction was added.
- Phase 5L-I retired the EXPERIMENTAL `document.*` alias facade. Source users of
  a former `document.Name` alias use the exact same-named canonical
  `core.Name`; all twelve replacements preserve type identity and runtime
  behavior, and no compatibility shim remains.
- Treat `TerminalDriver` as the portability boundary for terminal mode, size, and capability behavior; do not require widgets or app tests to depend on Linux-only terminal internals.
- If behavior changes, document it in `docs/limitations.md` or the relevant feature doc.
- Do not move Markdown parsing into core; keep parser packages and adapters separate.
- New examples should build through `scripts/build_examples.sh`.
- Update `docs/api-index.txt` whenever public symbols are added, moved, or removed.
- `docs/api-index.txt` is an exported-symbol baseline, not a stability contract. A symbol can appear in the index and still be experimental or test/internal exported.
- Keep public symbol moves source-compatible where the governing tier requires it;
  pre-1.0 experimental removal still requires an intentional documented decision.

Release gate:

```bash
scripts/release_gate.sh
```

`scripts/run_regression_matrix.sh` delegates to the same release gate for compatibility with older local workflows. The gate also checks that generated Unicode 17.0.0 tables are current. A release is not ready if the gate fails.

The canonical verification toolchain is Cangjie
`1.1.0-alpha.20260817040003` with cjpm `1.1.3`. This exact verification pin is
separate from the manifests' `cjc-version = "1.1.0"` language compatibility
declaration and does not claim ABI compatibility with other compilers. The prior
20260803 compiler is rejected because its test-macro code generation crashes on
the repository's legal `@Bench` suite. Official verification also uses a
toolchain-specific target namespace; moving a local `daily` symlink cannot
change the accepted compiler or reuse objects from another SDK.
