# ADR-009: API and Package Stability

## Status

Accepted.

## Context

Cangjie language visibility currently exposes production implementation and proof helpers alongside application APIs. The prior lexical contract also included test-source members.

## Decision

Every production public declaration is classified STABLE, EXPERIMENTAL, INTERNAL, or TEST_ONLY. Language `public` does not imply stability. New production public symbols require classification. Stable declarations must not acquire new dependencies on nonstable declarations. Current exact violations are baselined for Phase 4C.

## Evidence

Phase 4A found 504 production top-level public declarations across mixed stable and experimental models. The old generator scanned test sources and unanchored members without architecture classification.

## Consequences

`architecture/api-classification.json` is hand-maintained; extracted inventory and stable/experimental contracts are generated. The contract is source-level, not an ABI claim.

Phase 4C-2A removed tracing and waiter machinery from the stable `App.init` signature. Detailed tracing remains an explicit experimental pre-run attachment; deterministic waiter injection remains package-only test/runtime support.

Phase 4C-2B completed the stable construction boundary. `App.init` retains stable `Backend` injection without naming the internal `AnsiBackend` default, and optional `PtyRuntime` support is an explicit experimental pre-run attachment. The stable-to-nonstable dependency baseline is now empty; stable implementation code may still use internal concrete defaults.

Phase 4D-1 established `packages/component_experimental` as an optional package depending only on core. Core and recommended examples are checked against importing or depending on it; the official release gate tests the package without promoting it to stable support.

Phase 4D-2 established `packages/retained_view_experimental` as a second independent optional package depending only on core. Stable packages and recommended examples are checked against depending on it; only the classified experimental `style_lab` and `media_gallery` examples opt in. The stable source contract is unchanged.

Phase 4D-3 separated physical ownership from API stability for focus/modal helpers. `FocusManager` remains an experimental shared core primitive used by the recommended `form_studio`; `Modal` remains an experimental immediate Widget. Legacy-bound and unadopted higher-level helpers were assigned to Phase 4E review; no optional package or new stable abstraction was introduced.

Phase 4E-1A removed the unadopted experimental `FocusRing`, `TabOrder`, `InputCapturePriority`, `Screen`, and `ScreenStack` APIs after fresh repository and consumer scans found no functional callers. The stable source contract did not change; no compatibility aliases or replacement abstractions were introduced.

Phase 4E-1B removed the test-only experimental `ModalFocusTrap` after fresh source, documentation, fitness, example, and consumer scans found no functional adoption or active contract. Its local focus-subset cycling remains expressible by application-owned IDs and the retained `FocusManager`; no shim or replacement abstraction was added, and the stable source contract remained unchanged.

Phase 4E-2 removed the unadopted experimental `WidgetComponent`, `ListComponent`, `InputComponent`, `TextAreaComponent`, and `ComponentContainer` classes together with the callerless `ComponentHost.addWidget` convenience entry point. The internal addWidget-to-WidgetComponent edge was not functional adoption, and the remaining adapter/container uses were declaration-only or self-tests. Direct `RuntimeComponent`, `ComponentHost`, and `DashboardGrid` contracts remain; no shim or replacement adapter layer was added, and the stable source contract remained unchanged.

Phase 4E-3A removed the optional legacy `Component` parameter from experimental `ViewNode` after fresh repository and consumer scans found only its package self-test. The experimental constructor signature changed without a shim or replacement payload abstraction; the stable source contract remained unchanged, and machine-readable ownership now rejects the exact retained-package-to-`core.Component` relationship.

Phase 4E-3B removed the callerless experimental `ComponentHost.addLegacy` and `LegacyComponentAdapter` bridge as one contract. `btm_clone` and tests use direct `RuntimeComponent` implementations; no shim or replacement bridge was introduced. The stable source contract remained unchanged, and machine-readable ownership now rejects the exact component-package-to-`core.Component` relationship.

Phase 4E-3C removed the remaining core-local legacy `Component`, `EventRouter`, `FocusableWidget`, `ScopedKeyMap`, `EventPhase`, and `EventContext` closure after fresh scans found only internal edges and two self-tests. Shared `FocusManager`, `KeyMap`, `HandleResult`, and `EventPropagation` remain independently owned. No shim or replacement router was introduced; the stable source contract remained unchanged, and machine-readable retirement metadata rejects silent reintroduction of the exact qualified top-level symbols.

Phase 4E-4A removed the experimental `StringState` and `IntState` classes from production API after fresh scans found no production, package, example, fitness, or consumer adoption. Minimal mutable-box helpers remain package-local in `lib_test.cj`, where all existing closure-driven test assertions continue to use independent instances; no production `MutableBox` replacement or compatibility shim was added.

Phase 4E-4B-C corrected the v1 lexical contract's enum-constructor blind spot without changing production source. Constructors now inherit their containing enum's tier and expose payload dependencies to the architecture validator. This revealed six pre-existing stable-to-experimental edges, including `Event.ComponentTick -> ComponentTickEvent`; they are baselined as newly observed debt rather than new regressions. The repository's conservative 0.1.x policy and the explicitly authorized Phase 4E breaking window permit the `Event.ComponentTick` contraction, but implementation remains isolated to Phase 4E-4B-I. The other five PTY-related edges are not authorized by that decision and require a separate compatibility closure.

Phase 4E-4B-I implemented that narrow authorization. `ComponentHost` now consumes the encoded neutral timer, retains the component id as internal routing metadata, rebuilds a `TimerEvent` with the local id and unchanged timing fields, and directly dispatches `Event.Timer` to the target component. `Event.ComponentTick` and `ComponentTickEvent` were removed without a shim or replacement event algebra; the five unrelated PTY payload edges remain the complete known debt set.

Phase 4E-5A completed the package-level sunset review without changing production source. Fresh package, manifest, example, documentation, fitness, and principal-consumer census found no real, principal, or recommended adopter for `component_experimental`; `btm_clone` and the package tests are its only functional adopters, and no concrete near-term owner is recorded. Sunset is authorized for Phase 4E-5A-I. Until implementation, its declarations remain legitimate EXPERIMENTAL APIs and its package boundary and release checks remain active.

Phase 4E-5A-I implemented the authorized experimental break. `btm_clone` migrated first to application-owned App/update, core timer and async commands, direct layout, regional dirty rectangles, immediate rendering, shared `FocusManager`, and `DebugOverlay`; deterministic smoke retained its user-visible monitor behavior and stale-result protection. The 23 EXPERIMENTAL top-level declarations, package tests, manifest, current documentation, and package-specific release step then retired without a shim or replacement package. The stable contract was unchanged; external experimental consumers remain unknown.

Phase 4E-5B completed the independent retained-view sunset review without changing source behavior or contracts. Fresh census found no production, principal, recommended, or concrete near-term adopter. `style_lab` and `media_gallery` are functional experimental demonstrations, but the former rebuilds rather than retains its tree and the latter uses only one transient retained placement beside independent media paths; neither exercises a continuing retained lifecycle hypothesis. Sunset is authorized for Phase 4E-5B-I. Until implementation, all declarations remain legitimate EXPERIMENTAL APIs, both examples remain current, and the package/release checks remain active.

Phase 4E-5B-I implemented the authorized experimental break. `style_lab` retired, while `media_gallery` kept its direct and `DocumentLine.image` paths and removed only the transient retained placement. After the functional consumer census reached zero, the 16 retained-package top-level declarations, their package tests, manifest, current documentation, and package-specific release step retired without a shim or replacement package. The resulting zero-caller EXPERIMENTAL `EventPropagation` enum retired as a direct orphan. The stable source contract remained unchanged; external experimental consumers remain unknown.

Phase 5A reviewed the five PTY enum-payload debts without changing production
source or current tiers. The five payloads form a closed runtime-free value
cohort, so stable values plus an experimental runtime seam is technically
coherent. However, current governance still conditions PTY promotion on
independent production and cross-platform evidence, no recommended or principal
consumer adopts the API, and focused tests do not freeze every exact value
semantic. The repository therefore does not yet prove intent to guarantee the
current data model. Removing or replacing the stable enum constructors is also
not authorized by the consumed Phase 4E boundary. ADR-011 records the required
owner compatibility decision; all five debts remain machine-visible.

Phase 5A-I closed that owner decision. The stable `Command.Pty*` and
`Event.Pty*` constructors remain unchanged. While the five payloads were still
EXPERIMENTAL, `PtySpec` gained constructor input snapshots, the unused raw-native
`PtySignal.User(Int32)` case was removed, and `PtyExitStatus` was narrowed to the
exclusive runtime-truth states `Exited(Int64)` and `Signaled(Int32)`. The exact
five-value cohort was then promoted atomically to STABLE. `App.attachPtyRuntime`,
`PtyRuntime`, `PtyProcess`, and `EventSource` remain EXPERIMENTAL, concrete
platform implementations remain INTERNAL, and known stable-to-nonstable debt is
now zero.

## Rejected alternatives

Treating all public declarations as stable, classifying entire core as stable, or maintaining independent hand-written symbol lists.

## Revisit conditions

Change tiers only through reviewed evidence and explicit contract diff. Actual removals require a separate compatibility census and migration phase.

## Fitness functions

Unclassified production public declarations equal zero; test sources are excluded; enum constructors are inventoried; generated outputs are deterministic; new stable-to-nonstable edges beyond the exact lifecycle-owned baseline equal zero.
