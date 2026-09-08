# Versioning and Compatibility

## Explanation: read this policy

`termcanvas` is pre-1.0. Current packages use `0.1.x` while APIs are tightened by real applications. Choose declarations marked `STABLE` for application code; treat `EXPERIMENTAL` declarations as evaluation or extension points whose shape and behavior may change; do not construct `INTERNAL` declarations or infer an application promise from `TEST_ONLY` exports.

The exact tier of every declaration comes from the generated [`api-inventory.json`](api-inventory.json). The generated [`stable-api-contract.txt`](stable-api-contract.txt) and [`experimental-api-contract.txt`](experimental-api-contract.txt) are the source-level contracts, including enum constructors and exact signatures. [`api-index.txt`](api-index.txt) is an exported-symbol baseline, not a stability contract. These outputs are maintained by scripts and must not be edited manually. Package location, `core` ownership, or language `public` visibility does not determine a tier. ADR-009 (`adr/009-api-and-package-stability.md`) records the governing decision; [`api.md`](api.md) is the human map.

## Reference: four compatibility tiers

### STABLE

The stable application surface currently includes:

- Core data types: `Buffer`, `Cell`, `Style`, `Color`, `Modifier`, `Rect`, and `Position`.
- Runtime basics: `App`, `ControlFlow`, `UpdateResult`, `HandleResult`, `InputSource`, `TerminalDriver`, `Command.Message`, `Command.Batch`, `Command.Quit`, `Command.Exec`, `Command.ExecArgs`, `Command.AsyncExec`, and `Command.AsyncExecArgs`.
- Testing basics: `TestBackend`.
- Common widgets: `Block`, `Paragraph`, `Input`, `TextArea`, `DocumentView`, `List`, `Table`, and `FilePicker`.
- Rich document model: `RichSpan`, `DocumentLine`, `Document`, `DocumentTheme`, and `DocumentViewState`.
- PTY data protocol: `PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, `PtyExitStatus`, and the existing `Command.Pty*` / `Event.Pty*` constructors.
- External delivery: `ExternalPort<A>`, `ExternalEnqueueResult` with its exact `Accepted` / `Full` / `Closed` cases, and `App.runWithExternalPort`. The commitment covers positive capacity, non-blocking bounded enqueue, mutex-linearized successful ordering, level-visible wake, and idempotent close. `Accepted` does not promise eventual processing or shutdown durability.
- Low-level drawing: `Canvas` construction, both `fillRect` overloads, `drawText`, and `Frame.canvas`. The commitment covers translated terminal-cell coordinates, Canvas/Buffer clipping, styled blank fills, grapheme-atomic text clipping, and wide-cell-valid output.

Stable application architecture remains application-owned state → `App` / `update` → immediate `Widget` rendering. `Event` values and command completions are applied by the update path; workers do not mutate canonical application or widget state directly.

### EXPERIMENTAL

Experimental declarations are exported for exploration and extension work, not as commitments or the default Quick Start path. Current categories are:

- Async task runtime details beyond `Command.AsyncTask`, `Command.AsyncExecArgs`, and async completion events.
- Platform drivers other than Linux/glibc.
- PTY runtime/process attachment, readiness, and lifecycle details.
- `ExternalPort` instantaneous size, counters, wake counters, and latency measurement; `EventSource` readiness remains a separate runtime experiment.
- Advanced Canvas transforms and drawing conveniences, Widget bridging, `Surface`/composition, and `ResizePolicy`/`ViewportFit`/`SizeGuard` helpers.
- Terminal media protocol adapters.
- Game, media, and diff APIs unless a narrower feature document marks an entry point as a stable candidate.
- Extension-package APIs that adapt external content formats, except for documented conversion entry points.

### INTERNAL

Runtime implementation details such as queue ownership, concrete default waiters/backends, and low-level scheduling helpers are contributor interfaces, not application compatibility promises. `INTERNAL` declarations remain in the complete machine inventory but are omitted from the normal user API path. This includes concrete platform implementations and implementation boundaries such as `RuntimeQueue`, `AsyncRuntime`, `TimerRuntime`, and concrete event waiters where the inventory assigns that tier.

### TEST_ONLY

`EventScript`, `EventScenario`, fake runtimes, deterministic counters, low-level dirty helpers, benchmark guards, and public symbols exported only so release-gate tests can observe behavior are `TEST_ONLY`. Snapshot/golden-test helpers are supported for repository tests, but an observed implementation field is not thereby an application-facing API.

## Reference: compatibility rules

1. Prefer additive changes for public APIs.
2. Keep legacy constructors and enum variants when practical.
3. Breaking cleanup is allowed before 1.0, but the change must be intentional, documented, and covered by public behavior tests where practical.
4. The current Phase 4E pre-1.0 consolidation window is an authorized breaking boundary. Phase 4E-4B-I used it to remove `Event.ComponentTick` and its experimental payload after migrating component timers to host-localized `Event.Timer`; this authorization does not extend to other stable enum constructors.
5. Enum constructors inherit the stability of their containing enum. The v1 source-contract extractor inventories them explicitly; removing or reordering a stable constructor is a stable contract change even when its payload type has a lower tier.
6. New stable-to-nonstable dependencies are forbidden. Phase 5A-I resolved the five pre-existing PTY payload edges by hardening and stabilizing the exact runtime-free value cohort. It did not remove or rehome any stable `Command` or `Event` constructor and did not stabilize runtime integration.
7. Treat `TerminalDriver` as the portability boundary for terminal mode, size, and capability behavior; widgets and application tests must not depend on Linux-only terminal internals.
8. If behavior changes, document it in [`limitations.md`](limitations.md) or the relevant feature document.
9. Do not move Markdown parsing into `core`; keep parser packages and adapters separate.
10. New examples should build through `scripts/build_examples.sh`.
11. Update `api-index.txt` whenever public symbols are added, moved, or removed. The index remains a baseline only; it does not promote an indexed symbol to stable.
12. Keep public symbol moves source-compatible where the governing tier requires it. Pre-1.0 experimental removal still requires an intentional documented decision.

## History: migration and retirement decisions

The following decisions are compatibility history, not promises for experimental consumers:

- The former experimental `editor` facade is retired. Its sixteen stable type aliases map to the same-named stable `core` types; `markdownDecorations` and `markdownLineHighlights` map to the same-named stable `core` functions. Its ten advanced editor-shell aliases and their unadopted target declarations are also retired. The stable editor path remains canonical; multi-buffer metadata, generic token highlighting, callback line views, search/replace presentation, soft-wrap convenience, and the composite editor wrapper have no replacement API.
- Phase 4E-5A reviewed the experimental `component_experimental` package without changing production source. Fresh package, manifest, example, documentation, fitness, and principal-consumer census found no real, principal, or recommended adopter; `btm_clone` and the package tests were its only functional adopters, and no concrete near-term owner was recorded. Sunset was authorized for Phase 4E-5A-I. Until implementation, its declarations remained legitimate `EXPERIMENTAL` APIs and its package boundary and release checks remained active.
- Phase 4E-5A-I implemented the authorized experimental break. `btm_clone` first migrated to application-owned `App`/`update`, core timer and async commands, direct layout, regional dirty rectangles, immediate rendering, shared `FocusManager`, and `DebugOverlay`; deterministic smoke retained its user-visible monitor behavior and stale-result protection. The 23 experimental top-level declarations, package tests, manifest, current documentation, and package-specific release step then retired without a shim or replacement package. The stable contract was unchanged; external experimental consumers remain unknown.
- Phase 4E-5B reviewed the independent retained-view sunset without changing source behavior or contracts. Fresh census found no production, principal, recommended, or concrete near-term adopter. `style_lab` and `media_gallery` were functional experimental demonstrations, but `style_lab` rebuilt rather than retained its tree and `media_gallery` used one transient retained placement beside independent media paths; neither exercised a continuing retained-lifecycle hypothesis. Sunset was authorized for Phase 4E-5B-I. Until implementation, all declarations remained legitimate `EXPERIMENTAL` APIs, both examples remained current, and package/release checks remained active.
- Phase 4E-5B-I implemented the authorized experimental break. `style_lab` retired, while `media_gallery` kept its direct and `DocumentLine.image` paths and removed only the transient retained placement. After the functional consumer census reached zero, the 16 retained-package top-level declarations, package tests, manifest, current documentation, and package-specific release step retired without a shim or replacement package. The resulting zero-caller experimental `EventPropagation` enum retired as a direct orphan. The stable source contract remained unchanged; external experimental consumers remain unknown.
- Phase 4E-4B-C corrected the v1 lexical contract's enum-constructor blind spot without changing production source. Constructors now inherit their containing enum's tier and expose payload dependencies to the architecture validator. It revealed six pre-existing stable-to-experimental edges, including `Event.ComponentTick` → `ComponentTickEvent`; they were baselined as newly observed debt. The conservative `0.1.x` policy and authorized Phase 4E boundary permitted the narrow contraction, while the other five PTY edges required a separate compatibility closure.
- Phase 4E-4B-I implemented that narrow authorization. `ComponentHost` consumes the encoded neutral timer, retains the component id as internal routing metadata, rebuilds a `TimerEvent` with the local id and unchanged timing fields, and directly dispatches `Event.Timer` to the target component. `Event.ComponentTick` and `ComponentTickEvent` were removed without a shim or replacement event algebra; the five unrelated PTY payload edges were the complete known debt set at that point.
- Phase 5A reviewed those five PTY enum-payload debts without changing production source or current tiers. The payloads formed a closed runtime-free value cohort, so stable values plus an experimental runtime seam was technically coherent. Governance still conditioned promotion on independent production and cross-platform evidence; no recommended or principal consumer adopted the API, and focused tests did not freeze every exact value semantic. Removing or replacing stable enum constructors was not authorized by the consumed Phase 4E boundary. ADR-011 records the owner decision.
- Phase 5A-I closed that decision. While the five payloads were experimental, `PtySpec` gained constructor input snapshots, the unused raw-native `PtySignal.User(Int32)` case was removed, and `PtyExitStatus` was narrowed to the exclusive runtime-truth states `Exited(Int64)` and `Signaled(Int32)`. The exact five-value cohort was promoted atomically to stable. `App.attachPtyRuntime`, `PtyRuntime`, `PtyProcess`, and `EventSource` remain experimental; concrete platform implementations remain internal; known stable-to-nonstable debt is now zero.
- Phase 5C-I removed ExternalPort runtime-only methods from the language-public surface and separated latency capture from its constructor while the type was experimental. It then stabilized only the producer contract and App integration. Existing experimental callers of the old mixed surface may need migration; no compatibility shim or parallel sender/channel API was added.
- Phase 5G-I fixed the experimental Canvas left-clip path to use grapheme-cluster byte offsets; the old Rune-length path could slice a wide UTF-8 glyph at an invalid byte boundary. Direct coordinate, clipping, fill, Unicode/wide-cell, and Frame integration tests were added before promoting only the narrow core. Advanced Canvas members and all Surface/fit/resize declarations remain experimental; no parallel graphics abstraction was added.
- Phase 5L-I retired the experimental `document.*` alias facade. Source users of a former `document.Name` alias use the exact same-named canonical `core.Name`; all twelve replacements preserve type identity and runtime behavior, and no compatibility shim remains.

The earlier Phase 4E history also includes these intentional experimental removals:

- Phase 4E-1A removed unadopted `FocusRing`, `TabOrder`, `InputCapturePriority`, `Screen`, and `ScreenStack`; the stable source contract did not change and no aliases or replacement abstractions were introduced.
- Phase 4E-1B removed test-only experimental `ModalFocusTrap`; focus-subset cycling remains expressible by application-owned IDs and the retained `FocusManager`, with no shim or replacement abstraction.
- Phase 4E-2 removed unadopted `WidgetComponent`, `ListComponent`, `InputComponent`, `TextAreaComponent`, and `ComponentContainer`, plus the callerless `ComponentHost.addWidget`. Direct `RuntimeComponent`, `ComponentHost`, and `DashboardGrid` contracts remain; no replacement adapter layer was added.
- Phase 4E-3A removed the optional legacy `Component` parameter from experimental `ViewNode` after finding only its package self-test; no shim or replacement payload abstraction was introduced.
- Phase 4E-3B removed the callerless experimental `ComponentHost.addLegacy` and `LegacyComponentAdapter` bridge. `btm_clone` and tests use direct `RuntimeComponent` implementations; no replacement bridge was introduced.
- Phase 4E-3C removed the remaining core-local legacy `Component`, `EventRouter`, `FocusableWidget`, `ScopedKeyMap`, `EventPhase`, and `EventContext` closure. Shared `FocusManager`, `KeyMap`, `HandleResult`, and `EventPropagation` remain independently owned; no replacement router was introduced.
- Phase 4E-4A removed experimental `StringState` and `IntState` classes from the production API. Minimal mutable-box helpers remain package-local in `lib_test.cj`; no production `MutableBox` replacement or compatibility shim was added.

## Reference: release verification

Run the release gate from the repository root when validating a release:

```bash
scripts/release_gate.sh
```

`scripts/run_regression_matrix.sh` delegates to the same release gate for compatibility with older local workflows. The gate also checks that generated Unicode 17.0.0 tables are current; a release is not ready if it fails.

The canonical verification toolchain is Cangjie `1.1.3` STS with cjpm `1.1.3`. This exact verification pin is separate from manifests' `cjc-version = "1.1.0"` language compatibility declaration and does not claim ABI compatibility with other compilers. The prior 20260817 nightly compiler is retained only as historical evidence; official verification uses the public STS archive and a version-specific target namespace, so moving a local `daily` symlink cannot change the accepted compiler or reuse objects from another SDK.

Revisit a tier only through reviewed evidence and an explicit contract diff. Actual removals require a separate compatibility census and migration phase. The fitness requirements are zero unclassified production public declarations, excluded test sources, inventoried enum constructors, deterministic generated outputs, and no new stable-to-nonstable edges beyond the exact lifecycle-owned baseline.
