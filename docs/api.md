# API Overview

This page is a human-oriented map, not the API contract itself. The authoritative
current inventory is [`api-inventory.json`](api-inventory.json); the stable and
experimental source contracts are [`stable-api-contract.txt`](stable-api-contract.txt)
and [`experimental-api-contract.txt`](experimental-api-contract.txt). They include
enum constructors and exact signatures.

The generated inventory carries the current totals in
`counts.production_public_top_level` and `counts.top_level_by_stability`. Use
those fields for counts and exhaustive membership; this overview does not copy
numbers that can drift when declarations change. Physical location in `core`
does not determine stability.

## Stable Primary Path

The supported application path is application-owned state plus `App` update and
immediate `Widget` rendering:

- Runtime and effects: `App`, `Event`, `Command`, `ControlFlow`, `UpdateResult`,
  `TimerSpec`, and `TimerEvent`.
- Rendering: `Widget`, `Frame`, `Buffer`, `Cell`, `Backend`, `TestBackend`,
  `Terminal`, and `TerminalSession`.
- Presentation primitives: `Style`, `Theme`, `Color`, `Modifier`, `Layout`,
  `Rect`, and `Constraint`.
- Input and application policy: `KeyEvent`, `MouseEvent`, `KeyMap`, and the
  stable input-source and terminal-driver boundaries.
- Common content and controls: the stable core `Document`, `TextArea`, rich-text,
  widget, and Unicode-width surfaces listed by the generated inventory.
- PTY data protocol: `PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and
  `PtyExitStatus`, together with the existing `Command.Pty*` / `Event.Pty*`
  constructors.

Canonical state belongs to the application/model. Update handlers apply events
and completions to that state; widgets render it. Background workers do not
mutate widget or application state directly.

## Stable External Delivery

`ExternalPort<A>`, `ExternalEnqueueResult`, and `App.runWithExternalPort` form
the STABLE advanced ingress contract. Producers use bounded, non-blocking
`tryEnqueue` and observe `Accepted`, `Full`, or `Closed`; successful operations
are mutex-linearized and the same App runtime processes accepted values without
reentrant update execution. `Accepted` is port acceptance with the required
empty-to-nonempty wake publication, not an eventual-delivery guarantee.

The port's counters, instantaneous size, and latency switch remain EXPERIMENTAL
diagnostics. Runtime draining, closing barriers, readiness sources, and
`RuntimeState` are not part of the stable producer surface.

## Stable Canvas Drawing Core

`Canvas` is an optional STABLE low-level terminal-cell drawing primitive over a
caller-owned `Buffer`. Its stable surface is construction with a `Rect` clip and
translation, the two `fillRect` overloads, `drawText`, and `Frame.canvas`.
Coordinates are translated before effective clipping by the Canvas clip and
Buffer bounds. Fills write styled blanks; text drawing clips whole grapheme
clusters and preserves valid wide lead/continuation cells. A Canvas returned by
`Frame.canvas` writes the current Frame-owned Buffer and does not allocate a
second rendering surface.

The remaining Canvas transform, line/rectangle/sprite, Widget-bridge, and
composition conveniences are EXPERIMENTAL members. `Surface`, `ResizePolicy`,
`ViewportFit`, `SizeGuard`, and `centeredViewport` also remain EXPERIMENTAL.
Their algorithms and policies are not part of the stable Canvas promise.

## Current Experimental Families

Experimental APIs are visible rather than hidden, but they are not the default
Quick Start path:

- Runtime integration: observability hooks, `EventSource` readiness, and selected
  runtime attachment/configuration APIs.
- Focus: `FocusManager` is a shared immediate-mode primitive, not a second
  lifecycle or routing architecture.
- Terminal and PTY: runtime/process attachment and readiness APIs,
  platform-specific terminal facilities, and terminal extension helpers. The
  neutral PTY command/event value protocol is STABLE; runtime lifecycle is not.
- Specialized rendering: virtual transcript, advanced Canvas/surface helpers,
  media, and diff facilities. The narrow Canvas fill/text core is STABLE.
- Rich applications: game and other extension-package surfaces.

Each declaration's exact owner and tier is in `api-inventory.json`. An API being
experimental does not imply that it is recommended or has a production adopter.

## Internal and Test-only Surfaces

`RuntimeQueue`, `AsyncRuntime`, `TimerRuntime`, concrete event waiters,
`AnsiBackend`, and similar implementation declarations are INTERNAL. They may be
documented for maintainers but are not normal construction points.

`AppTestRunner`, `HeadlessScript`, event-scenario fixtures, snapshot-diff helpers,
fake runtimes, and related exported probes are TEST_ONLY where the inventory says
so. User code should not infer a compatibility promise from their public syntax.

## Module Boundaries

- `packages/core` owns the primary runtime, immediate rendering, common widgets,
  rich document model, and stable compatibility surfaces.
- `packages/core` owns the stable editor primitives. The former advanced editor
  shell and the `packages/editor` and `packages/document` alias facades are
  retired.
- `packages/markdown` converts Markdown into the core document model;
  `packages/cj_markdown` owns parsing and source diagnostics.
- `packages/terminal`, `packages/diff`, `packages/media`, and `packages/game`
  provide specialized extension capabilities without owning application state.

The former Component lifecycle package and retained ViewNode/CSS package are not
current modules or API choices. Their history is recorded in ADR-008.

## PTY Stability Boundary

The five neutral PTY request/result values are STABLE. `PtySpec` snapshots its
input argument/environment arrays, `PtySignal` exposes the portable
`Interrupt`/`Terminate`/`Kill` intents, and `PtyExitStatus` is exactly
`Exited(Int64)` or `Signaled(Int32)`. `App.attachPtyRuntime`, `PtyRuntime`,
`PtyProcess`, and `EventSource` remain EXPERIMENTAL; concrete Linux/unsupported
implementations remain INTERNAL. See [`versioning.md`](versioning.md) and
ADR-011 for the hardening and compatibility decision.

## Choosing an Entry Point

Start with the runnable basic application template in `templates/basic_app`, then
use [`getting-started.md`](getting-started.md) and the recommended examples in
[`examples.md`](examples.md). Consult the generated inventory before depending on
an advanced declaration; Quick Start code intentionally stays on the stable
primary path.
