# API Map

## Explanation: choose an entry point

Start with the runnable application in [`templates/basic_app`](../templates/basic_app), then follow [`getting-started.md`](getting-started.md) and the recommended examples in [`examples.md`](examples.md). Keep the main path simple:

> application-owned state → `App` / `update` → immediate `Widget` rendering

The application/model owns canonical state. `update` applies `Event` values and command completions to that state; widgets render the current state. Background workers publish immutable completion values and do not mutate widget or application state directly.

Use the stable sections below for application code. Before depending on an advanced declaration, check the generated inventory for its exact tier, owner, and signature. An API can be exported from `core` and still be experimental, internal, or test-only.

## Reference: authority and scope

This page is a human-oriented map, not the API contract. The generated [`api-inventory.json`](api-inventory.json) is authoritative for exhaustive membership, ownership, signatures, and stability. Its `counts.production_public_top_level` and `counts.top_level_by_stability` fields provide current totals; this page intentionally does not duplicate numbers that can drift when declarations change.

The generated [`stable-api-contract.txt`](stable-api-contract.txt) and [`experimental-api-contract.txt`](experimental-api-contract.txt) provide source-level contracts, including enum constructors and exact signatures. [`api-index.txt`](api-index.txt) is an exported-symbol baseline, not a stability contract: an indexed symbol may still be experimental, internal, or test-only. These generated files are maintained by repository scripts; do not edit them by hand. Physical location in `core` or another package, language `public` visibility, and package ownership do not determine stability.

## Reference: stable surface

### Runtime and update path

The stable runtime and effect surface includes `App`, `Event`, `Command`, `ControlFlow`, `UpdateResult`, `TimerSpec`, and `TimerEvent`. Runtime integrations use the same application-owned state and `App`/`update` path rather than a second lifecycle architecture.

Stable command/event basics include `Command.Message`, `Command.Batch`, `Command.Quit`, `Command.Exec`, `Command.ExecArgs`, `Command.AsyncExec`, and `Command.AsyncExecArgs`. `ExecArgs` and `AsyncExecArgs` are the structured-argv choices; the string forms use a simple command-line splitter and are not shell-compatible.

### Immediate rendering and presentation

The stable rendering surface includes `Widget`, `Frame`, `Buffer`, `Cell`, `Backend`, `TestBackend`, `Terminal`, and `TerminalSession`. Presentation primitives include `Style`, `Theme`, `Color`, `Modifier`, `Layout`, `Rect`, and `Constraint`.

Stable input and application-policy boundaries include `KeyEvent`, `MouseEvent`, `KeyMap`, `InputSource`, and `TerminalDriver`. Common stable content and controls include the core `Document`, `TextArea`, rich-document, widget, and Unicode-width surfaces listed by the generated inventory. Keep widgets, buffers, layout, document views, and text areas platform-neutral; platform-specific behavior belongs at the terminal/session and waiter boundaries described in [`platforms.md`](platforms.md).

### PTY data protocol

The neutral PTY request/result values are stable: `PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and `PtyExitStatus`, together with the existing `Command.Pty*` and `Event.Pty*` constructors. `PtySpec` snapshots its input argument/environment arrays. `PtySignal` exposes the portable `Interrupt`, `Terminate`, and `Kill` intents. `PtyExitStatus` is exactly `Exited(Int64)` or `Signaled(Int32)`.

This is a runtime-free data boundary. `App.attachPtyRuntime`, `PtyRuntime`, `PtyProcess`, and `EventSource` remain experimental, while concrete Linux and unsupported-platform implementations remain internal. See [`versioning.md`](versioning.md) and ADR-011 (`adr/011-pty-stable-enum-payload-compatibility-review.md`) for the compatibility decision.

### External delivery

`ExternalPort<A>`, `ExternalEnqueueResult`, its exact `Accepted` / `Full` / `Closed` cases, and `App.runWithExternalPort` form the stable advanced ingress contract. Producers use bounded, non-blocking `tryEnqueue`. Successful operations are mutex-linearized; sequential successful calls from one producer preserve program order. The required empty-to-nonempty wake is level-visible, and `close()` is idempotent. The same `App` runtime processes accepted values without reentrant `update` execution.

`Accepted` means that the port accepted the value and published the required wake. It does not mean that `App.update` has run, promise eventual processing, or promise durability across shutdown. Runtime draining, readiness, closing barriers, and `RuntimeState` are not part of the stable producer surface. Port counters, instantaneous size, wake counters, and latency measurement remain experimental diagnostics.

### Canvas drawing core

`Canvas` is an optional stable low-level terminal-cell drawing primitive over a caller-owned `Buffer`. The stable surface is construction with a `Rect` clip and translation, both `fillRect` overloads, `drawText`, and `Frame.canvas`.

Coordinates are translated before effective clipping by the Canvas clip and Buffer bounds. Fills write styled blanks. Text drawing clips whole grapheme clusters and preserves valid wide lead/continuation cells. A Canvas returned by `Frame.canvas` writes the current Frame-owned Buffer and does not allocate a second rendering surface.

The remaining Canvas transforms, line/rectangle/sprite helpers, Widget bridge, and composition conveniences are experimental. `Surface`, `ResizePolicy`, `ViewportFit`, `SizeGuard`, and `centeredViewport` are also experimental; their algorithms and policies are not part of the stable Canvas promise.

## Reference: experimental surface

Experimental declarations are visible for evaluation and extension work, but they are not the default Quick Start path and are not compatibility promises. The generated inventory is authoritative for each declaration; experimental status does not imply a recommendation, production adopter, or future stabilization.

Current families include:

- Runtime integration: observability hooks, `EventSource` readiness, and selected runtime attachment/configuration APIs.
- Focus: `FocusManager`, a shared immediate-mode primitive, not a second lifecycle or routing architecture.
- Terminal and PTY: runtime/process attachment and readiness APIs, platform-specific terminal facilities, and terminal extension helpers. The neutral PTY value protocol is stable; runtime lifecycle is not.
- Specialized rendering: virtual transcript, advanced Canvas and surface helpers, media, and diff facilities. Only the narrow Canvas fill/text core is stable.
- Rich applications: game and other extension-package surfaces.

## Reference: internal and test-only surface

`RuntimeQueue`, `AsyncRuntime`, `TimerRuntime`, concrete event waiters, `AnsiBackend`, and similar implementation declarations are internal. They may be documented for maintainers, but they are not normal construction points or application compatibility promises.

`AppTestRunner`, `HeadlessScript`, event-scenario fixtures, snapshot-diff helpers, fake runtimes, deterministic counters, and related exported probes are test-only wherever the inventory classifies them that way. Their public syntax does not create an application-facing compatibility promise.

## Reference: package ownership and retired paths

- `packages/core` owns the primary runtime, immediate rendering, common widgets, rich document model, and stable compatibility surfaces.
- `packages/core` owns the stable editor primitives. The former advanced editor shell and the `packages/editor` and `packages/document` alias facades are retired.
- `packages/markdown` converts Markdown into the core document model; `packages/cj_markdown` owns parsing and source diagnostics.
- `packages/terminal`, `packages/diff`, `packages/media`, and `packages/game` provide specialized extension capabilities without owning application state.

The former Component lifecycle package and retained ViewNode/CSS package are not current modules or API choices. Their history is recorded in ADR-008 (`adr/008-component-and-viewnode-disposition.md`).
