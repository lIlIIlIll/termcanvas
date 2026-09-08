# ADR-008: Component and ViewNode Disposition

## Status

Accepted; the stable Frame dependency was removed in Phase 4C-1, the retained component runtime was physically isolated in Phase 4D-1, ViewNode/CSS was physically isolated in Phase 4D-2, and Phase 4D-3 found no third competing focus/modal architecture. Phase 4E-1 retired unadopted focus/navigation helpers, Phase 4E-2 retired the unadopted RuntimeComponent Widget/control/container adapter cohort, Phase 4E-3A/3B removed both cross-package legacy Component bridges, Phase 4E-3C retired the remaining core-local legacy Component/EventRouter architecture, Phase 4E-5A-I retired the component experimental package, and Phase 4E-5B-I retired the retained-view package.

## Context

Historically `Widget`, legacy `Component`, `ViewNode`, `RuntimeComponent`, and `ComponentHost` coexisted. Only Widget plus App/update is used by the principal consumer, and fresh Phase 4E-3C scans found no functional adoption of the core-local legacy Component closure.

## Decision

Widget is the primary stable rendering abstraction. The legacy `Component`/`EventRouter` architecture, the optional `RuntimeComponent`/`ComponentHost`/DataSource package, and the optional `ViewNode`/CSS/DOM package are retired. No retained replacement was added to the primary architecture.

## Evidence

Principal consumer adoption of ComponentHost and ViewNode is zero. ComponentHost usage is limited to `btm_clone` and tests; ViewNode/CSS usage is limited to `style_lab`, `media_gallery`, and tests. Phase 4C-1 removed `Frame.renderComponent` and `Frame.renderNode`; the experimental models now invoke stable `Frame` primitives through their existing render entry points. Phase 4D-1 moved the retained component runtime to `packages/component_experimental`. Phase 4D-2 moved ViewNode, CSS parser/cascade/layout, component-style resolvers, and three focused tests to `packages/retained_view_experimental`. Both optional packages depend only on core and have no dependency on one another. Phase 4D-3 confirmed that `FocusManager` is a flat shared core primitive used independently by `form_studio` and ComponentHost, while `Modal` is only an immediate Widget. Phase 4E-1B retired the unadopted test-only `ModalFocusTrap`. Phase 4E-2 found no functional caller behind the internal `ComponentHost.addWidget` to `WidgetComponent` edge and no adoption for the List/Input/TextArea or nested-host container adapters; those convenience surfaces were removed while `DashboardGrid` retained direct coverage. Phase 4E-3A found that only the retained package self-test used ViewNode's legacy Component payload, so its constructor parameter and render/event delegates were removed without a replacement bridge; retained dirty/query/CSS/layout/media coverage remains. Phase 4E-3B found no caller behind `ComponentHost.addLegacy` and no independent use of `LegacyComponentAdapter`; both were retired together. Phase 4E-3C then found only internal closure edges and two self-tests for Component, EventRouter, FocusableWidget, ScopedKeyMap, EventPhase, and EventContext, so the complete legacy architecture was removed while shared FocusManager, KeyMap, HandleResult, and EventPropagation remained.

Phase 4E-5A found no production, principal, recommended-example, or concrete near-term adopter for `component_experimental`. Its sole nontrivial consumer is the self-contained experimental `btm_clone`, whose seven components demonstrate that synchronous component-local lifecycle, routing, datasource, timer, dirty-region, focus, and profiling composition is feasible. They do not demonstrate that this second lifecycle model is needed beyond the primary App/update plus application-owned state architecture: `btm_clone` itself keeps canonical state in its owning application object, while components mainly delegate regional update and rendering. The package remains healthy and downward-only, but its 23 experimental top-level declarations, 200 public declarations, package tests, docs, release steps, and example migration burden are not justified by a continuing experimental question or a concrete future owner. Sunset is therefore authorized; implementation and the explicit `btm_clone` migration remain separate Phase 4E-5A-I work.

Phase 4E-5A-I kept that ordering: `btm_clone` first moved timer and async effects into its App update path, retained application-owned canonical state, derived layout and regional dirty rectangles directly, rendered through immediate helpers, and preserved deterministic timer, async, focus, resize, stale-result, and dirty-isolation assertions. Only after the example had zero package dependency did the package, its 13 implementation tests, current API entries, and release step retire. No panel lifecycle host, replacement DataSource framework, or second event router was introduced.

Phase 4E-5B found that the retained package is architecturally clean and its CSS-like capabilities are genuinely distinct from core `Style`/`Theme`, but it is no longer answering an active repository hypothesis. `style_lab` rebuilds its tree and stylesheet on every render, handles input directly in `App`, and does not use retained dirty/query/event identity; `media_gallery` uses a transient retained image node beside independent direct and `Document` media paths. The three package tests prove feasibility, not production demand, and no real, principal, recommended, or concrete near-term adopter exists. Sunset is authorized for separate Phase 4E-5B-I work: retire `style_lab`, remove only the retained path from `media_gallery`, then retire the package and its current API/release ownership.

Phase 4E-5B-I implemented that disposition consumer-first. `style_lab` retired; `media_gallery` retained direct adapter placement and `DocumentLine.image`, removed its transient `ViewNode` column, and now has deterministic two-placement headless proof. After the functional retained-consumer census reached zero, the package and its three tests retired. The resulting zero-caller EXPERIMENTAL `EventPropagation` enum also retired as an exact direct orphan; no replacement tree, CSS, or propagation abstraction was introduced.

## Consequences

Both experimental architecture branches are absent from the current package/API/release surface. No focus/modal package, replacement lifecycle host, retained tree, CSS layer, or router was introduced; independently owned shared primitives stay in core. Legacy Component, EventRouter, FocusableWidget, ScopedKeyMap, EventPhase, EventContext, and EventPropagation also remain absent.

## Rejected alternatives

Universal retained Component graph and permanent adapter-based coexistence of all models.

## Revisit conditions

Introduce a retained/CSS architecture only after a real independent adopter demonstrates a concrete requirement unavailable through the primary model. Promotion still requires two independent real consumers and is not authorized by experimental examples.

## Fitness functions

Stable applications compile and run without either retired package; exact package-boundary guards prevent them from becoming hidden prerequisites.
