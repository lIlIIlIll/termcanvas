# Architecture

The current architecture has one primary application model: canonical state is
owned by the application, events enter one `App` update path, and immediate
widgets render the resulting state.

```text
                    application state
                           │
                           ▼
                    App / update
                           │
                ┌──────────┴──────────┐
                │                     │
             Command            Event/completion
                │                     │
                └──────────┬──────────┘
                           ▼
                    RuntimeQueue
                  ordered processing
                  run-to-completion
                           │
                           ▼
                     DirtyRects
                           │
                    frame coalescing
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

## Ownership and Update

The application/model owns persistent domain state, selection, filters, layout
inputs, and correlation IDs. `App.run()` supports a simple `Event -> ControlFlow`
loop; `App.runWithCommands()` supports `Event -> UpdateResult` and ordered effects.
Messages, timer events, async completions, process results, and external events all
re-enter the same update owner.

The INTERNAL `RuntimeQueue` preserves accepted-event order. It does not recurse
into nested updates: each update runs to completion before the next queued item is
processed. Background tasks compute values and publish completions; they do not
mutate application or widget state directly.

## Rendering and Presentation

Widgets are immediate renderers. They receive an area and render current state
into a `Frame`/`Buffer`; they are not lifecycle hosts or canonical state owners.
Applications derive layout with stable `Layout`, `Rect`, and `Constraint`
primitives, return `DirtyRects`, and may invalidate only affected regions. The
runtime coalesces presentation work without exposing a second public scheduler.

`Terminal` owns frame drawing, front/back buffer reuse, diff presentation, and
render metrics. `TerminalSession` owns terminal mode setup and restoration.
`Backend` is the public rendering boundary; concrete default backends and event
waiters may be INTERNAL even when they live in `core`.

## Optional and Specialized Capabilities

These capabilities attach to the primary model; none is a competing UI tree:

- `KeyMap` is STABLE application policy. `FocusManager` is an EXPERIMENTAL
  shared immediate-mode primitive.
- `ExternalPort` is a STABLE advanced producer seam for bounded, non-blocking,
  ordered external delivery into the same runtime. Readiness, drain, lifecycle
  state, and diagnostic instrumentation remain nonstable implementation surfaces.
- `Canvas` is a STABLE optional low-level terminal-cell drawing view over the
  current caller/Frame-owned Buffer. Only construction, fill, text, and
  `Frame.canvas` are stable; transforms, drawing conveniences, Surface
  composition, and fit/resize policy remain EXPERIMENTAL.
- PTY and platform-specific terminal integrations are optional/experimental and
  use the same `Command`/`Event` update route.
- Virtual transcript, media, diff, and game facilities
  are specialized experimental families where the generated inventory says so.
- Stable `Style`, `Theme`, `Color`, layout, document, and text primitives remain
  part of immediate rendering; they do not imply a retained DOM/CSS runtime.

## Stability Boundaries

The exact tier of every declaration is defined by `docs/api-inventory.json`, not
by its package name or by this diagram. See `docs/api.md` for the human map and
`docs/versioning.md`/ADR-009 for the four-tier policy.

Historical Component, ComponentHost, EventRouter, and retained ViewNode/CSS
architectures are not current choices. ADR-008 records why they were evaluated
and retired; architecture proof and migration evidence remain historical records.

## Related Documents

- `docs/getting-started.md`: stable primary-path introduction.
- `docs/app-runtime.md`: commands, events, waiting, timers, and shutdown.
- `docs/widgets.md`: immediate widget composition and state ownership.
- `docs/testing.md`: unit, headless, example, validator, and release verification.
