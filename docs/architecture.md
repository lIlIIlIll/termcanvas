# Architecture

## Reader task

Use this page to choose the ownership boundary for a new termcanvas application. The
stable path is deliberately small:

> application-owned state → `App` / update → immediate Widget rendering

`docs/getting-started.md` shows the smallest runnable application. This page
explains why the boundary exists; `docs/app-runtime.md` is the reference for
commands, timers, waiting, and shutdown.

## Stable request-to-frame path

```text
application-owned state
          │
          ▼
      App / update
          │
   ┌──────┴────────┐
   │               │
  Event         Command
   │               │
   └──────┬────────┘
          ▼
   RuntimeQueue (internal)
   ordered, run-to-completion
          │
          ▼
       DirtyRects
   frame coalescing (internal)
          │
          ▼
   immediate Widget render
          │
          ▼
     Frame / Buffer
          │
          ▼
       Backend
```

The diagram describes one application loop, not a retained UI tree. Input,
timers, asynchronous completions, process results, and external deliveries all
return to the same `App` update owner before a frame is rendered.

## State ownership and update

The application/model owns persistent domain state, selection, filters, layout
inputs, and correlation IDs. An immediate widget may hold small interaction
state (for example `ListState`, `TableState`, `TextBuffer`, or a cursor), but it
is a renderer and interaction helper, not the canonical owner of application
data. Keep large or unbounded data in the application model, a virtual provider,
a ring buffer, or a paged store; render only the visible slice.

There are two update entry points:

- `App.run(render, update)` passes each `Event` to an update function returning
  `ControlFlow.Continue` or `ControlFlow.Exit`.
- `App.runWithCommands(render, update)` uses an update function returning
  `UpdateResult`. `UpdateResult.next()` continues, `UpdateResult.exit()` exits,
  and `UpdateResult.withCommand(command)` requests an ordered effect.

The update function is the only place that applies events and command
completions to application-owned state. Background work computes immutable
values and publishes a completion; it does not mutate application or widget
state directly. `Event.Message`, timer events, async events, PTY events, and
external events follow the same rule.

`RuntimeQueue` is an INTERNAL implementation boundary. It preserves accepted
event order and runs one update to completion before processing the next item;
it does not recursively invoke nested updates. `DirtyRects` and frame
coalescing reduce presentation work after update; they are not a second public
scheduler or event bus.

## Rendering and terminal ownership

Render derives `Rect` values with `Layout` and related geometry primitives, then
renders immediate widgets into the supplied `Frame`/`Buffer`:

```cj
func render(frame: Frame): Unit {
    let areas = Layout.horizontal([
        Constraint.Length(24),
        Constraint.Min(0)
    ]).withGap(1).split(frame.area)
    frame.renderWidget(Paragraph("left"), areas[0])
    frame.renderWidget(Paragraph("right"), areas[1])
}
```

A widget receives an area and paints current values. It is not a lifecycle host,
canonical state store, or retained DOM node. Application code may return
regional `DirtyRects` when using the relevant runtime APIs, but ordinary apps
only need to render the current state.

`Terminal` owns frame drawing, front/back buffer reuse, diff presentation, and
render metrics. `TerminalSession` owns terminal mode setup and restoration.
`Backend` is the public rendering boundary; the concrete default backends and
event waiters can be INTERNAL even when they are implemented in `core`.

Stable presentation primitives are `Style`, `Theme`, `Color`, `Modifier`,
`Layout`, `Rect`, and `Constraint`. They support immediate rendering and do not
imply a retained DOM/CSS runtime.

## API map by boundary

### Runtime and effects

- `App`: runs update/render and optional command loops.
- `Event`: carries input, lifecycle, timer, async, process, and data results.
- `Command`: requests messages, async work, timers, PTY operations, or process
  execution.
- `ControlFlow` / `UpdateResult`: choose continuation and ordered effects.
- `TimerSpec` / `TimerEvent`: schedule and receive one-shot or repeating timers.
- `ExternalPort`: stable advanced bounded ingress into the same `App` queue.

### Rendering and presentation

- `Widget`, `Frame`, `Buffer`, `Cell`: immediate rendering contracts.
- `Backend`, `Terminal`, `TerminalSession`: terminal output, lifecycle, and
  frame presentation.
- `Style`, `Theme`, `Color`, `Modifier`: visual values.
- `Layout`, `Grid`, `FlexLayout`, `Rect`, `Constraint`: area derivation.
- `TestBackend` and headless app helpers: deterministic test surfaces; check the
  generated inventory for their stability tier.

### Input and policy

- `KeyEvent`, `MouseEvent`, `InputState`: decoded input and held-key state.
- `KeyMap`: application-owned key-to-action policy.
- `EventParser`: deterministic byte-to-`Event` decoding; `TerminalProbe`
  consumes active capability probes before ordinary parsing.

### Content and specialized families

- `Document`, `RichSpan`, `DocumentLine`, `DocumentTheme`, `DocumentView`: the
  stable rich-document vocabulary and renderer.
- `TextBuffer`, `TextArea`, completion values, and Markdown editing declarations:
  stable editor primitives in `core` without an editor shell.
- `Canvas`: stable optional fill/text drawing over a caller/`Frame`-owned buffer;
  advanced transforms, surfaces, and policy helpers are experimental.
- Virtual transcript, media, diff, PTY runtime attachment, and game facilities:
  specialized families whose exact tier is defined by the generated inventory.

## Optional capabilities and stability

These capabilities attach to the primary model; none is a competing UI
architecture:

- `KeyMap` is STABLE application policy. `FocusManager` is an EXPERIMENTAL flat
  focus-ID helper with no second event loop, state model, lifecycle host, or
  overlay stack.
- `ExternalPort` is a STABLE advanced producer seam. `tryEnqueue` is bounded and
  non-blocking and reports `Accepted`, `Full`, or `Closed`; acceptance is not a
  guarantee that update has already run. Counters, readiness/drain machinery,
  lifecycle state, and latency diagnostics are nonstable surfaces.
- `Canvas` construction, clipping, fill, text, and `Frame.canvas` are STABLE.
  Transforms, line/rectangle/sprite helpers, Widget bridges, `Surface`
  composition, and viewport/resize policy remain EXPERIMENTAL.
- PTY and platform-specific terminal integrations use the same `Command`/
  `Event` route. The neutral PTY data protocol can be STABLE while runtime
  attachment and process lifecycle APIs remain EXPERIMENTAL.
- Virtual transcript, media, diff, and game facilities are specialized
  experimental families where the generated inventory says so.

The exact tier and owner of every declaration are defined by
[`api-inventory.json`](api-inventory.json), not by package location or this
summary. See [`api.md`](api.md), [`versioning.md`](versioning.md), and ADR-009
for the four-tier policy.

## Retired and historical architectures

Component, `ComponentHost`, `EventRouter`, and retained `ViewNode`/CSS
architectures were evaluated and retired. They are not current choices and
must not be presented as an alternative application path. ADR-008 retains the
historical decision, proof, and migration evidence.

The former experimental `document` / `packages/document` alias facade and
`packages/editor` facade (and the advanced editor shell) are also retired. Use
the stable core document and editor primitives directly. Format adapters remain
separate from editor behavior and parsing policy; see [`extensions.md`](extensions.md).

## Related documents

- [`getting-started.md`](getting-started.md): first stable application.
- [`app-runtime.md`](app-runtime.md): command, event, timer, waiting, and
  shutdown details.
- [`events.md`](events.md): event decoding and update-boundary behavior.
- [`widgets.md`](widgets.md): immediate widget composition and state holders.
- [`layout.md`](layout.md): area constraints and layout helpers.
- [`extensions.md`](extensions.md): parser and specialized package boundaries.
- [`api.md`](api.md): human API map and generated-contract pointers.
