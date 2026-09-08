# ADR-005: Rendering and Dirty Rects

## Status

Accepted.

## Context

The mature renderer already combines immediate Widgets, Frame/Buffer, physical DirtyRects, wide-cell normalization, and front/back cell diff.

## Decision

`Widget.render(Rect, Buffer)` remains the primary rendering abstraction. Logical updates emit `UpdateResult.dirtyRects`; `frame.isDirty` skips unaffected paint; DirtyRects define physical redraw/diff scope. Wide-cell closure is the terminal correctness boundary.

## Evidence

Step 2C proved full/partial Buffer equality. Step 3A found screen-level keyed Region added insufficient value over the existing Rect contract and returned STOP.

## Consequences

Stable identities and retained region trees are not required for screen-level selective paint. Specialized views may compute narrower Rects internally.

## Rejected alternatives

Screen Region tree, generic damage graph, and Component tree as rendering/layout ownership.

## Revisit conditions

Revisit Region only if Rect ownership repeatedly causes correctness or maintenance failures in multiple real consumers.

## Fitness functions

Partial and forced-full final Buffers match, including style, CellKind, continuation, and cleared cells.
